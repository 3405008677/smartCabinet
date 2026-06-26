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
import android.media.MediaFormat
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import android.view.Surface
import androidx.core.app.ActivityCompat
import java.nio.ByteBuffer
import java.util.concurrent.atomic.AtomicBoolean

class GStreamerH265Stream(
    private val context: Context,
    private val bridge: GStreamerBridge,
    private val statusListener: (String) -> Unit,
) {
    private var cameraDevice: CameraDevice? = null

    private var captureSession: CameraCaptureSession? = null

    private var encoder: MediaCodec? = null

    private var encoderSurface: Surface? = null

    private var workerThread: HandlerThread? = null

    private var workerHandler: Handler? = null

    private var encoderThread: Thread? = null

    private val streaming = AtomicBoolean(false)

    fun start(cameraId: String, url: String, width: Int, height: Int, fps: Int, bitrate: Int, iframeInterval: Int): Boolean {
        if (streaming.get()) {
            statusListener("GStreamer H265 推流中")
            return true
        }
        if (ActivityCompat.checkSelfPermission(context, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            statusListener("缺少摄像头权限")
            return false
        }

        return runCatching {
            statusListener("正在初始化 GStreamer")
            if (!bridge.initialize()) {
                statusListener("GStreamer 初始化失败")
                return false
            }
            if (!bridge.startH265Rtsp(url, width, height, fps)) {
                statusListener("GStreamer RTSP pipeline 启动失败")
                return false
            }

            startWorkerThread()
            prepareEncoder(width, height, fps, bitrate, iframeInterval)
            openCamera(cameraId)
            streaming.set(true)
            startEncoderDrain()
            true
        }.getOrElse { error ->
            Log.e(TAG, "GStreamer H265 stream start failed", error)
            statusListener("GStreamer H265 启动失败：${error.message ?: error::class.java.simpleName}")
            stop()
            false
        }
    }

    fun stop() {
        streaming.set(false)
        encoderThread?.join(1000)
        encoderThread = null
        runCatching { captureSession?.close() }
        captureSession = null
        runCatching { cameraDevice?.close() }
        cameraDevice = null
        runCatching { encoder?.signalEndOfInputStream() }
        runCatching { encoder?.stop() }
        runCatching { encoder?.release() }
        encoder = null
        runCatching { encoderSurface?.release() }
        encoderSurface = null
        bridge.stopH265Rtsp()
        stopWorkerThread()
        statusListener("GStreamer H265 已停止")
    }

    fun isStreaming(): Boolean = streaming.get()

    private fun startWorkerThread() {
        workerThread = HandlerThread("SmartCabinetGstCamera").also { thread ->
            thread.start()
            workerHandler = Handler(thread.looper)
        }
    }

    private fun stopWorkerThread() {
        workerThread?.quitSafely()
        workerThread?.join(1000)
        workerThread = null
        workerHandler = null
    }

    private fun prepareEncoder(width: Int, height: Int, fps: Int, bitrate: Int, iframeInterval: Int) {
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_HEVC, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, bitrate)
            setInteger(MediaFormat.KEY_FRAME_RATE, fps)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, iframeInterval)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                setInteger(MediaFormat.KEY_PROFILE, MediaCodecInfo.CodecProfileLevel.HEVCProfileMain)
            }
        }
        encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_HEVC).also { codec ->
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            encoderSurface = codec.createInputSurface()
            codec.start()
        }
    }

    private fun openCamera(cameraId: String) {
        val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val targetSurface = encoderSurface ?: error("encoder surface is not ready")
        cameraManager.openCamera(
            cameraId,
            object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    runCatching {
                        cameraDevice = camera
                        createCaptureSession(camera, targetSurface)
                    }.onFailure { error ->
                        statusListener("GStreamer H265 摄像头启动失败：${error.message ?: error::class.java.simpleName}")
                        Log.e(TAG, "GStreamer H265 camera open callback failed", error)
                        stop()
                    }
                }

                override fun onDisconnected(camera: CameraDevice) {
                    statusListener("GStreamer H265 摄像头断开")
                    camera.close()
                    stop()
                }

                override fun onError(camera: CameraDevice, error: Int) {
                    statusListener("GStreamer H265 摄像头错误：$error")
                    camera.close()
                    stop()
                }
            },
            workerHandler,
        )
        statusListener("GStreamer H265 摄像头打开中")
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
                        }
                        session.setRepeatingRequest(request.build(), null, workerHandler)
                        statusListener("GStreamer H265 推流启动中")
                    }.onFailure { error ->
                        statusListener("GStreamer H265 摄像头会话启动失败：${error.message ?: error::class.java.simpleName}")
                        Log.e(TAG, "GStreamer H265 camera session configure callback failed", error)
                        stop()
                    }
                }

                override fun onConfigureFailed(session: CameraCaptureSession) {
                    statusListener("GStreamer H265 摄像头会话配置失败")
                    stop()
                }
            },
            workerHandler,
        )
    }

    private fun startEncoderDrain() {
        val codec = encoder ?: error("encoder is not ready")
        encoderThread = Thread {
            val bufferInfo = MediaCodec.BufferInfo()
            while (streaming.get()) {
                val outputIndex = codec.dequeueOutputBuffer(bufferInfo, 10_000)
                if (outputIndex >= 0) {
                    val outputBuffer = codec.getOutputBuffer(outputIndex)
                    if (outputBuffer != null && bufferInfo.size > 0) {
                        val frame = readFrame(outputBuffer, bufferInfo)
                        val keyFrame = bufferInfo.flags and MediaCodec.BUFFER_FLAG_KEY_FRAME != 0
                        if (!bridge.pushH265Frame(frame, bufferInfo.presentationTimeUs, keyFrame)) {
                            statusListener("GStreamer H265 帧推送失败")
                        } else {
                            statusListener("GStreamer H265 推流中")
                        }
                    }
                    codec.releaseOutputBuffer(outputIndex, false)
                }
            }
        }.also { thread ->
            thread.name = "SmartCabinetGstEncoder"
            thread.start()
        }
    }

    private fun readFrame(buffer: ByteBuffer, info: MediaCodec.BufferInfo): ByteArray {
        val frame = ByteArray(info.size)
        buffer.position(info.offset)
        buffer.limit(info.offset + info.size)
        buffer.get(frame)
        return frame
    }

    companion object {
        private const val TAG = "SmartCabinetGst"
    }
}
