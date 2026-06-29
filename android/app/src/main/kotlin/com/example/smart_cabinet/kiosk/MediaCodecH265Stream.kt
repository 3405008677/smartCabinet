package com.example.smart_cabinet.kiosk

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CaptureRequest
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaFormat
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import android.util.Range
import android.view.Surface
import androidx.core.app.ActivityCompat
import java.util.concurrent.atomic.AtomicBoolean

class MediaCodecH265Stream(
    private val context: Context,
    private val bridge: GStreamerBridge,
    private val statusListener: (String) -> Unit,
) : H265RtspStream {
    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var encoder: MediaCodec? = null
    private var encoderInputSurface: Surface? = null
    private var workerThread: HandlerThread? = null
    private var workerHandler: Handler? = null
    private var diagnosticsRunnable: Runnable? = null
    private var drainThread: Thread? = null
    private var rtspPublisher: RtspTcpH265Publisher? = null
    private var rtspUrl = ""
    private val streaming = AtomicBoolean(false)
    private var pushedFrameCount = 0
    private var pushedByteCount = 0L
    private var streamFps = 0
    private var codecConfig: ByteArray? = null
    private var waitingParameterSetCount = 0
    private val stopping = AtomicBoolean(false)
    override var currentCameraId: String? = null
        private set

    override fun start(cameraId: String, url: String, width: Int, height: Int, fps: Int, bitrate: Int, iframeInterval: Int): Boolean {
        if (streaming.get()) {
            statusListener("MediaCodec H265 推流中")
            return true
        }
        if (ActivityCompat.checkSelfPermission(context, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            statusListener("缺少摄像头权限")
            return false
        }

        return runCatching {
            stopping.set(false)
            val codecName = findHevcEncoderName()
            if (codecName.isNullOrBlank()) {
                statusListener("MediaCodec H265 初始化失败：设备无 HEVC 编码器")
                return false
            }
            currentCameraId = cameraId
            rtspUrl = url
            streamFps = fps

            statusListener("正在初始化 MediaCodec H265：$codecName")
            startWorkerThread()
            prepareEncoder(codecName, width, height, fps, bitrate, iframeInterval)
            streaming.set(true)
            openCamera(cameraId)
            startDrainThread()
            startDiagnosticsPolling()
            pushedFrameCount = 0
            pushedByteCount = 0L
            waitingParameterSetCount = 0
            true
        }.getOrElse { error ->
            Log.e(TAG, "MediaCodec H265 stream start failed", error)
            statusListener("MediaCodec H265 启动失败：${error.message ?: error::class.java.simpleName}")
            stop()
            false
        }
    }

    override fun stop() {
        if (!stopping.compareAndSet(false, true) && !streaming.get()) {
            return
        }
        streaming.set(false)
        diagnosticsRunnable?.let { runnable -> workerHandler?.removeCallbacks(runnable) }
        diagnosticsRunnable = null
        currentCameraId = null
        runCatching { captureSession?.close() }
        captureSession = null
        runCatching { cameraDevice?.close() }
        cameraDevice = null
        val currentDrainThread = drainThread
        if (currentDrainThread != null && Thread.currentThread() != currentDrainThread) {
            currentDrainThread.join(1000)
        }
        drainThread = null
        runCatching { encoderInputSurface?.release() }
        encoderInputSurface = null
        runCatching { encoder?.stop() }
        runCatching { encoder?.release() }
        encoder = null
        runCatching { rtspPublisher?.stop() }
        rtspPublisher = null
        stopWorkerThread()
        statusListener("MediaCodec H265 已停止")
    }

    override fun isStreaming(): Boolean = streaming.get()

    private fun prepareEncoder(codecName: String, width: Int, height: Int, fps: Int, bitrate: Int, iframeInterval: Int) {
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_HEVC, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, bitrate)
            setInteger(MediaFormat.KEY_FRAME_RATE, fps)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, iframeInterval.coerceAtLeast(1))
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                setInteger(MediaFormat.KEY_BITRATE_MODE, MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_CBR)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                setInteger(MediaFormat.KEY_LATENCY, 0)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                setInteger(MediaFormat.KEY_PRIORITY, 0)
            }
        }
        encoder = MediaCodec.createByCodecName(codecName).also { codec ->
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                codec.setParameters(Bundle().apply {
                    putInt(MediaCodec.PARAMETER_KEY_VIDEO_BITRATE, bitrate)
                })
            }
            encoderInputSurface = codec.createInputSurface()
            codec.start()
        }
    }

    private fun openCamera(cameraId: String) {
        val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        cameraManager.openCamera(
            cameraId,
            object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    runCatching {
                        cameraDevice = camera
                        createCaptureSession(camera, encoderInputSurface ?: error("encoder input surface is not ready"))
                    }.onFailure { error ->
                        stopAfterRuntimeFailure(
                            "MediaCodec H265 摄像头启动失败：${error.message ?: error::class.java.simpleName}",
                            error,
                        )
                    }
                }

                override fun onDisconnected(camera: CameraDevice) {
                    cameraDevice = camera
                    stopAfterRuntimeFailure("MediaCodec H265 摄像头断开")
                }

                override fun onError(camera: CameraDevice, error: Int) {
                    cameraDevice = camera
                    stopAfterRuntimeFailure("MediaCodec H265 摄像头错误：$error")
                }
            },
            workerHandler,
        )
        statusListener("MediaCodec H265 摄像头打开中")
    }

    private fun createCaptureSession(camera: CameraDevice, targetSurface: Surface) {
        camera.createCaptureSession(
            listOf(targetSurface),
            object : CameraCaptureSession.StateCallback() {
                override fun onConfigured(session: CameraCaptureSession) {
                    runCatching {
                        captureSession = session
                        val request = camera.createCaptureRequest(CameraDevice.TEMPLATE_RECORD).apply {
                            addTarget(targetSurface)
                            set(CaptureRequest.CONTROL_MODE, CaptureRequest.CONTROL_MODE_AUTO)
                            set(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, Range(streamFps.coerceAtLeast(1), streamFps.coerceAtLeast(1)))
                        }
                        session.setRepeatingRequest(request.build(), null, workerHandler)
                        statusListener("MediaCodec H265 推流启动中")
                    }.onFailure { error ->
                        stopAfterRuntimeFailure(
                            "MediaCodec H265 摄像头会话启动失败：${error.message ?: error::class.java.simpleName}",
                            error,
                        )
                    }
                }

                override fun onConfigureFailed(session: CameraCaptureSession) {
                    stopAfterRuntimeFailure("MediaCodec H265 摄像头会话配置失败")
                }
            },
            workerHandler,
        )
    }

    private fun startDrainThread() {
        drainThread = Thread {
            val bufferInfo = MediaCodec.BufferInfo()
            val codec = encoder ?: return@Thread
            while (streaming.get()) {
                runCatching {
                    val outputIndex = codec.dequeueOutputBuffer(bufferInfo, ENCODER_TIMEOUT_US)
                    when {
                        outputIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> Unit
                        outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> readCodecConfig(codec.outputFormat)
                        outputIndex >= 0 -> drainOutputBuffer(codec, outputIndex, bufferInfo)
                    }
                }.onFailure { error ->
                    stopAfterRuntimeFailure(
                        "MediaCodec H265 推流失败：${error.message ?: error::class.java.simpleName}",
                        error,
                    )
                }
            }
        }.apply {
            name = "SmartCabinetMediaCodecH265Drain"
            start()
        }
    }

    private fun startDiagnosticsPolling() {
        val handler = workerHandler ?: return
        diagnosticsRunnable = object : Runnable {
            override fun run() {
                if (!streaming.get()) {
                    return
                }
                val diagnostics = bridge.pollH265RtspDiagnostics()
                if (diagnostics.isNotBlank()) {
                    diagnostics.lineSequence()
                        .filter { it.isNotBlank() }
                        .forEach { line -> statusListener("RTSP诊断：$line") }
                }
                handler.postDelayed(this, DIAGNOSTICS_INTERVAL_MS)
            }
        }.also { runnable -> handler.postDelayed(runnable, DIAGNOSTICS_INTERVAL_MS) }
    }

    private fun drainOutputBuffer(codec: MediaCodec, outputIndex: Int, bufferInfo: MediaCodec.BufferInfo) {
        val outputBuffer = codec.getOutputBuffer(outputIndex)
        if (outputBuffer == null || bufferInfo.size <= 0) {
            codec.releaseOutputBuffer(outputIndex, false)
            return
        }
        outputBuffer.position(bufferInfo.offset)
        outputBuffer.limit(bufferInfo.offset + bufferInfo.size)
        val data = ByteArray(bufferInfo.size)
        outputBuffer.get(data)
        codec.releaseOutputBuffer(outputIndex, false)

        if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) != 0) {
            codecConfig = data
            statusListener("MediaCodec H265 参数集已生成：bytes=${data.size}")
            return
        }

        val keyFrame = (bufferInfo.flags and MediaCodec.BUFFER_FLAG_KEY_FRAME) != 0
        val frame = if (keyFrame && codecConfig != null && !data.hasStartCodeAt(0)) {
            codecConfig!! + data
        } else {
            data
        }
        if (!ensureRtspPublisherStarted(frame)) {
            waitingParameterSetCount += 1
            if (waitingParameterSetCount <= 3 || waitingParameterSetCount % 30 == 0) {
                statusListener("MediaCodec H265 等待 VPS/SPS/PPS：frames=$waitingParameterSetCount bytes=${frame.size}")
            }
            return
        }
        rtspPublisher?.sendFrame(frame, bufferInfo.presentationTimeUs, keyFrame)
        pushedFrameCount += 1
        pushedByteCount += frame.size.toLong()
        if (pushedFrameCount <= 3 || pushedFrameCount % 30 == 0) {
            statusListener("MediaCodec H265 推流中：pushed=$pushedFrameCount bytes=$pushedByteCount last=${frame.size}")
        }
    }

    private fun readCodecConfig(format: MediaFormat) {
        codecConfig = format.getByteBuffer("csd-0")?.let { buffer ->
            val bytes = ByteArray(buffer.remaining())
            buffer.get(bytes)
            bytes
        }
        codecConfig?.let { statusListener("MediaCodec H265 输出格式就绪：csd=${it.size}") }
    }

    private fun ensureRtspPublisherStarted(codecConfig: ByteArray?): Boolean {
        val publisher = rtspPublisher
        if (publisher != null) {
            return true
        }
        if (rtspUrl.isBlank()) {
            return false
        }
        val nextPublisher = RtspTcpH265Publisher(statusListener)
        if (!nextPublisher.canStart(codecConfig)) {
            return false
        }
        nextPublisher.start(rtspUrl, codecConfig)
        rtspPublisher = nextPublisher
        waitingParameterSetCount = 0
        return true
    }

    private fun startWorkerThread() {
        workerThread = HandlerThread("SmartCabinetMediaCodecCamera").also { thread ->
            thread.start()
            workerHandler = Handler(thread.looper)
        }
    }

    private fun stopWorkerThread() {
        val thread = workerThread
        thread?.quitSafely()
        if (thread != null && Thread.currentThread() != thread) {
            thread.join(1000)
        }
        workerThread = null
        workerHandler = null
    }

    private fun stopAfterRuntimeFailure(status: String, error: Throwable? = null) {
        if (!streaming.getAndSet(false)) {
            return
        }
        statusListener(status)
        if (error != null) {
            Log.e(TAG, status, error)
        } else {
            Log.w(TAG, status)
        }
        Thread {
            stop()
        }.apply {
            name = "SmartCabinetMediaCodecSafeStop"
            start()
        }
    }

    private fun findHevcEncoderName(): String? {
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_HEVC, 640, 480)
        return MediaCodecList(MediaCodecList.REGULAR_CODECS).findEncoderForFormat(format)
    }

    private fun ByteArray.hasStartCodeAt(index: Int): Boolean {
        return size >= index + 4 && this[index] == 0.toByte() && this[index + 1] == 0.toByte() &&
            (this[index + 2] == 1.toByte() || (this[index + 2] == 0.toByte() && this[index + 3] == 1.toByte()))
    }

    companion object {
        private const val TAG = "SmartCabinetMediaCodec"
        private const val ENCODER_TIMEOUT_US = 10000L
        private const val DIAGNOSTICS_INTERVAL_MS = 1000L
    }
}
