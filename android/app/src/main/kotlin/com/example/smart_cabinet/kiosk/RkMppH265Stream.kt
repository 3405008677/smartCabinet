package com.example.smart_cabinet.kiosk

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.ImageFormat
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CaptureRequest
import android.media.Image
import android.media.ImageReader
import android.os.Handler
import android.os.HandlerThread
import android.util.Range
import android.util.Log
import android.view.Surface
import androidx.core.app.ActivityCompat
import java.util.concurrent.atomic.AtomicBoolean

class RkMppH265Stream(
    private val context: Context,
    private val bridge: RkMppBridge,
    private val statusListener: (String) -> Unit,
) : H265RtspStream {
    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var imageReader: ImageReader? = null
    private var workerThread: HandlerThread? = null
    private var workerHandler: Handler? = null
    // Kotlin RTSP publisher performs explicit ANNOUNCE/SETUP/RECORD against ZLMediaKit.
    private var rtspPublisher: RtspTcpH265Publisher? = null
    private var rtspUrl = ""
    // Active stream width mirrored into the RKMPP encoder configuration.
    private var streamWidth = 0
    // Active stream height mirrored into the RKMPP encoder configuration.
    private var streamHeight = 0
    // Active stream frame rate mirrored into the RKMPP encoder configuration.
    private var streamFps = 0
    // Tracks which RTSP sender owns the current encoded H265 stream.
    private var rtspSender: RtspSender? = null
    private val streaming = AtomicBoolean(false)
    private var encodedFrameCount = 0
    private var pushedFrameCount = 0
    private var pushedByteCount = 0L
    private var waitingParameterSetCount = 0
    private var lastAcceptedImageTimestampNs = 0L
    private val stopping = AtomicBoolean(false)
    override var currentCameraId: String? = null
        private set

    override fun start(cameraId: String, url: String, width: Int, height: Int, fps: Int, bitrate: Int, iframeInterval: Int): Boolean {
        if (streaming.get()) {
            statusListener("RKMPP H265 推流中")
            return true
        }
        if (ActivityCompat.checkSelfPermission(context, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            statusListener("缺少摄像头权限")
            return false
        }

        return runCatching {
            stopping.set(false)
            currentCameraId = cameraId
            rtspUrl = url
            streamWidth = width
            streamHeight = height
            streamFps = fps
            statusListener("正在初始化 RKMPP 依赖库")
            if (!bridge.initialize(context)) {
                statusListener("RKMPP 依赖库初始化失败：${bridge.lastError().ifBlank { "未知错误" }}")
                return false
            }

            statusListener("正在初始化 RKMPP：${bridge.rkMppStatus()}")
            if (!bridge.startRkMppH265(width, height, fps, bitrate, iframeInterval)) {
                statusListener("RKMPP H265 初始化失败：${bridge.lastError().ifBlank { bridge.rkMppStatus() }}")
                stop()
                return false
            }

            startWorkerThread()
            prepareImageReader(width, height)
            openCamera(cameraId)
            encodedFrameCount = 0
            pushedFrameCount = 0
            pushedByteCount = 0L
            waitingParameterSetCount = 0
            lastAcceptedImageTimestampNs = 0L
            streaming.set(true)
            true
        }.getOrElse { error ->
            Log.e(TAG, "RKMPP H265 stream start failed", error)
            statusListener("RKMPP H265 启动失败：${error.message ?: error::class.java.simpleName}")
            stop()
            false
        }
    }

    override fun stop() {
        if (!stopping.compareAndSet(false, true) && !streaming.get()) {
            return
        }
        streaming.set(false)
        currentCameraId = null
        runCatching { captureSession?.close() }
        captureSession = null
        runCatching { cameraDevice?.close() }
        cameraDevice = null
        runCatching { imageReader?.close() }
        imageReader = null
        bridge.stopRkMppH265()
        runCatching { rtspPublisher?.stop() }
        rtspPublisher = null
        rtspSender = null
        stopWorkerThread()
        statusListener("RKMPP H265 已停止")
    }

    override fun isStreaming(): Boolean = streaming.get()

    private fun startWorkerThread() {
        workerThread = HandlerThread("SmartCabinetRkMppCamera").also { thread ->
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
            name = "SmartCabinetRkMppSafeStop"
            start()
        }
    }

    private fun prepareImageReader(width: Int, height: Int) {
        imageReader = ImageReader.newInstance(width, height, ImageFormat.YUV_420_888, 2).also { reader ->
            reader.setOnImageAvailableListener({ availableReader ->
                runCatching {
                    val image = availableReader.acquireLatestImage() ?: return@setOnImageAvailableListener
                    image.use { currentImage ->
                        if (!streaming.get()) {
                            return@use
                        }
                        if (!shouldAcceptImage(currentImage.timestamp)) {
                            return@use
                        }
                        val encoded = currentImage.encodeWithNative(currentImage.timestamp / 1000)
                        if (encoded == null || encoded.isEmpty()) {
                            statusListener("RKMPP H265 转换编码失败：${bridge.lastError().ifBlank { "无输出帧" }}")
                            return@use
                        }
                        encodedFrameCount += 1
                        if (!ensureRtspPublisherStarted(encoded)) {
                            waitingParameterSetCount += 1
                            if (waitingParameterSetCount <= 3 || waitingParameterSetCount % 30 == 0) {
                                statusListener("RKMPP H265 等待 VPS/SPS/PPS：frames=$waitingParameterSetCount bytes=${encoded.size}")
                            }
                            return@use
                        }
                        if (!sendEncodedFrame(encoded, currentImage.timestamp / 1000, encodedFrameCount == 1)) {
                            statusListener("RKMPP H265 推流失败：${bridge.lastError().ifBlank { "发送链路不可用" }}")
                            return@use
                        }
                        pushedFrameCount += 1
                        pushedByteCount += encoded.size.toLong()
                        if (pushedFrameCount <= 3 || pushedFrameCount % 30 == 0) {
                            statusListener(
                                "RKMPP H265 推流中：encoded=$encodedFrameCount pushed=$pushedFrameCount bytes=$pushedByteCount last=${encoded.size}",
                            )
                        }
                    }
                }.onFailure { error ->
                    stopAfterRuntimeFailure(
                        "RKMPP H265 推流失败：${error.message ?: error::class.java.simpleName}",
                        error,
                    )
                }
            }, workerHandler)
        }
    }

    private fun ensureRtspPublisherStarted(codecConfig: ByteArray): Boolean {
        if (rtspSender != null) {
            return true
        }
        if (rtspUrl.isBlank()) {
            return false
        }
        val fallbackPublisher = RtspTcpH265Publisher(statusListener)
        if (!fallbackPublisher.canStart(codecConfig)) {
            return false
        }
        startKotlinPublisher(fallbackPublisher, codecConfig)
        statusListener("RKMPP H265 使用 Kotlin RTSP ANNOUNCE/RECORD 发送")
        return true
    }

    // Sends encoded H265 through the sender that successfully registered the stream.
    private fun sendEncodedFrame(encodedFrame: ByteArray, presentationTimeUs: Long, keyFrame: Boolean): Boolean {
        return when (rtspSender) {
            RtspSender.KOTLIN -> {
                rtspPublisher?.sendFrame(encodedFrame, presentationTimeUs, keyFrame)
                true
            }
            null -> false
        }
    }

    // Starts the existing Kotlin RTSP sender as a resilience fallback.
    private fun startKotlinPublisher(publisher: RtspTcpH265Publisher, codecConfig: ByteArray) {
        publisher.start(rtspUrl, codecConfig)
        rtspPublisher = publisher
        rtspSender = RtspSender.KOTLIN
        waitingParameterSetCount = 0
    }

    private fun openCamera(cameraId: String) {
        val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val targetSurface = imageReader?.surface ?: error("image reader surface is not ready")
        cameraManager.openCamera(
            cameraId,
            object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    runCatching {
                        cameraDevice = camera
                        createCaptureSession(camera, targetSurface)
                    }.onFailure { error ->
                        stopAfterRuntimeFailure(
                            "RKMPP H265 摄像头启动失败：${error.message ?: error::class.java.simpleName}",
                            error,
                        )
                    }
                }

                override fun onDisconnected(camera: CameraDevice) {
                    cameraDevice = camera
                    stopAfterRuntimeFailure("RKMPP H265 摄像头断开")
                }

                override fun onError(camera: CameraDevice, error: Int) {
                    cameraDevice = camera
                    stopAfterRuntimeFailure("RKMPP H265 摄像头错误：$error")
                }
            },
            workerHandler,
        )
        statusListener("RKMPP H265 摄像头打开中")
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
                            set(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, Range(streamFps, streamFps))
                        }
                        session.setRepeatingRequest(request.build(), null, workerHandler)
                        statusListener("RKMPP H265 推流启动中")
                    }.onFailure { error ->
                        stopAfterRuntimeFailure(
                            "RKMPP H265 摄像头会话启动失败：${error.message ?: error::class.java.simpleName}",
                            error,
                        )
                    }
                }

                override fun onConfigureFailed(session: CameraCaptureSession) {
                    stopAfterRuntimeFailure("RKMPP H265 摄像头会话配置失败")
                }
            },
            workerHandler,
        )
    }

    private fun shouldAcceptImage(timestampNs: Long): Boolean {
        val targetFps = streamFps.coerceAtLeast(1)
        val minFrameIntervalNs = 1_000_000_000L / targetFps
        val previousTimestampNs = lastAcceptedImageTimestampNs
        if (previousTimestampNs > 0L && timestampNs - previousTimestampNs < minFrameIntervalNs) {
            return false
        }
        lastAcceptedImageTimestampNs = timestampNs
        return true
    }

    private fun Image.encodeWithNative(presentationTimeUs: Long): ByteArray? {
        val yPlane = planes[0]
        val uPlane = planes[1]
        val vPlane = planes[2]
        return bridge.encodeRkMppH265Image(
            yBuffer = yPlane.buffer,
            uBuffer = uPlane.buffer,
            vBuffer = vPlane.buffer,
            width = width,
            height = height,
            yRowStride = yPlane.rowStride,
            yPixelStride = yPlane.pixelStride,
            uRowStride = uPlane.rowStride,
            uPixelStride = uPlane.pixelStride,
            vRowStride = vPlane.rowStride,
            vPixelStride = vPlane.pixelStride,
            presentationTimeUs = presentationTimeUs,
        )
    }

    companion object {
        private const val TAG = "SmartCabinetRkMpp"
    }

    private enum class RtspSender {
        // Kotlin publisher is the default because it explicitly performs ANNOUNCE/SETUP/RECORD.
        KOTLIN,
    }
}
