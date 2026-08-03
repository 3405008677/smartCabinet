package com.example.smart_cabinet.kiosk

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.ImageFormat
import android.hardware.camera2.CameraAccessException
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
import java.util.concurrent.atomic.AtomicLong

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
    private val streamGeneration = AtomicLong(0L)
    override var currentCameraId: String? = null
        private set
    @Volatile
    override var startFailureReason: String? = null
        private set

    override fun start(cameraId: String, url: String, width: Int, height: Int, fps: Int, bitrate: Int, iframeInterval: Int): Boolean {
        startFailureReason = null
        if (streaming.get()) {
            statusListener("RKMPP H265 推流中")
            return true
        }
        if (ActivityCompat.checkSelfPermission(context, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            reportStartFailure("RKMPP H265 启动失败：缺少摄像头权限")
            return false
        }

        return runCatching {
            val generation = streamGeneration.incrementAndGet()
            stopping.set(false)
            currentCameraId = cameraId
            rtspUrl = url
            streamWidth = width
            streamHeight = height
            streamFps = fps
            statusListener("正在初始化 RKMPP 依赖库")
            if (!bridge.initialize(context)) {
                currentCameraId = null
                reportStartFailure("RKMPP H265 启动失败：依赖库初始化失败：${bridge.lastError().ifBlank { "未知错误" }}")
                return false
            }

            statusListener("正在初始化 RKMPP：${bridge.rkMppStatus()}")
            if (!bridge.startRkMppH265(width, height, fps, bitrate, iframeInterval)) {
                reportStartFailure("RKMPP H265 初始化失败：${bridge.lastError().ifBlank { bridge.rkMppStatus() }}")
                stop()
                return false
            }

            startWorkerThread()
            prepareImageReader(width, height, generation)
            streaming.set(true)
            openCamera(cameraId, generation)
            encodedFrameCount = 0
            pushedFrameCount = 0
            pushedByteCount = 0L
            waitingParameterSetCount = 0
            lastAcceptedImageTimestampNs = 0L
            true
        }.getOrElse { error ->
            Log.e(TAG, "RKMPP H265 stream start failed", error)
            val detail = when (error) {
                is CameraAccessException, is IllegalArgumentException, is SecurityException ->
                    describeCameraAccessFailure(cameraId, error)
                else -> error.message ?: error::class.java.simpleName
            }
            reportStartFailure("RKMPP H265 启动失败：$detail")
            stop()
            false
        }
    }

    override fun stop() {
        if (!stopping.compareAndSet(false, true) && !streaming.get()) {
            return
        }
        streamGeneration.incrementAndGet()
        streaming.set(false)
        currentCameraId = null
        runCatching { captureSession?.close() }
        captureSession = null
        runCatching { cameraDevice?.close() }
        cameraDevice = null
        runCatching { imageReader?.setOnImageAvailableListener(null, null) }
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
        streamGeneration.incrementAndGet()
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

    private fun prepareImageReader(width: Int, height: Int, generation: Long) {
        imageReader = ImageReader.newInstance(width, height, ImageFormat.YUV_420_888, 2).also { reader ->
            reader.setOnImageAvailableListener({ availableReader ->
                runCatching {
                    val image = availableReader.acquireLatestImage() ?: return@setOnImageAvailableListener
                    image.use { currentImage ->
                        if (!isGenerationActive(generation)) {
                            return@use
                        }
                        if (!streaming.get()) {
                            return@use
                        }
                        if (!shouldAcceptImage(currentImage.timestamp)) {
                            return@use
                        }
                        val encoded = currentImage.encodeWithNative(currentImage.timestamp / 1000)
                        if (!isGenerationActive(generation)) {
                            return@use
                        }
                        if (encoded == null || encoded.isEmpty()) {
                            statusListener("RKMPP H265 转换编码失败：${bridge.lastError().ifBlank { "无输出帧" }}")
                            return@use
                        }
                        encodedFrameCount += 1
                        if (!ensureRtspPublisherStarted(encoded, generation)) {
                            if (isGenerationActive(generation)) {
                                waitingParameterSetCount += 1
                                if (shouldReportProgress(waitingParameterSetCount)) {
                                    statusListener("RKMPP H265 等待 VPS/SPS/PPS：frames=$waitingParameterSetCount bytes=${encoded.size}")
                                }
                            }
                            return@use
                        }
                        if (!sendEncodedFrame(encoded, currentImage.timestamp / 1000, generation)) {
                            statusListener("RKMPP H265 推流失败：${bridge.lastError().ifBlank { "发送链路不可用" }}")
                            return@use
                        }
                        pushedFrameCount += 1
                        pushedByteCount += encoded.size.toLong()
                        if (shouldReportProgress(pushedFrameCount)) {
                            statusListener(
                                "RKMPP H265 推流中：encoded=$encodedFrameCount pushed=$pushedFrameCount bytes=$pushedByteCount last=${encoded.size}",
                            )
                        }
                    }
                }.onFailure { error ->
                    if (isGenerationActive(generation)) {
                        stopAfterRuntimeFailure(
                            "RKMPP H265 推流失败：${error.message ?: error::class.java.simpleName}",
                            error,
                        )
                    }
                }
            }, workerHandler)
        }
    }

    private fun ensureRtspPublisherStarted(codecConfig: ByteArray, generation: Long): Boolean {
        if (!isGenerationActive(generation)) {
            return false
        }
        if (rtspSender != null) {
            return true
        }
        if (rtspUrl.isBlank()) {
            return false
        }
        val nextPublisher = RtspTcpH265Publisher { status ->
            if (isGenerationActive(generation)) {
                statusListener(status)
            }
        }
        if (!nextPublisher.canStart(codecConfig)) {
            return false
        }
        try {
            nextPublisher.start(rtspUrl, codecConfig)
        } catch (error: Throwable) {
            throw IllegalStateException(
                "RTSP 启动失败：${error.message ?: error::class.java.simpleName}",
                error,
            )
        }
        if (!isGenerationActive(generation)) {
            nextPublisher.stop()
            return false
        }
        rtspPublisher = nextPublisher
        rtspSender = RtspSender.KOTLIN
        if (!isGenerationActive(generation)) {
            if (rtspPublisher === nextPublisher) {
                rtspPublisher = null
                rtspSender = null
            }
            nextPublisher.stop()
            return false
        }
        waitingParameterSetCount = 0
        statusListener("RKMPP H265 使用 Kotlin RTSP ANNOUNCE/RECORD 发送")
        return true
    }

    // Sends encoded H265 through the sender that successfully registered the stream.
    private fun sendEncodedFrame(encodedFrame: ByteArray, presentationTimeUs: Long, generation: Long): Boolean {
        val publisher = rtspPublisher ?: return false
        if (!isGenerationActive(generation) || rtspSender != RtspSender.KOTLIN) {
            return false
        }
        publisher.sendFrame(encodedFrame, presentationTimeUs)
        return true
    }

    private fun openCamera(cameraId: String, generation: Long) {
        val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val targetSurface = imageReader?.surface ?: error("image reader surface is not ready")
        cameraManager.openCamera(
            cameraId,
            object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    if (!isGenerationActive(generation)) {
                        camera.close()
                        return
                    }
                    runCatching {
                        cameraDevice = camera
                        if (!isGenerationActive(generation)) {
                            if (cameraDevice === camera) {
                                cameraDevice = null
                            }
                            camera.close()
                            return
                        }
                        createCaptureSession(camera, targetSurface, generation)
                    }.onFailure { error ->
                        camera.close()
                        if (isGenerationActive(generation)) {
                            stopAfterRuntimeFailure(
                                "RKMPP H265 推流失败：摄像头启动失败：${error.message ?: error::class.java.simpleName}",
                                error,
                            )
                        }
                    }
                }

                override fun onDisconnected(camera: CameraDevice) {
                    camera.close()
                    if (!isGenerationActive(generation)) {
                        return
                    }
                    if (cameraDevice === camera) {
                        cameraDevice = null
                    }
                    stopAfterRuntimeFailure("RKMPP H265 推流失败：${describeCameraDisconnected(cameraId)}")
                }

                override fun onError(camera: CameraDevice, error: Int) {
                    camera.close()
                    if (!isGenerationActive(generation)) {
                        return
                    }
                    if (cameraDevice === camera) {
                        cameraDevice = null
                    }
                    stopAfterRuntimeFailure("RKMPP H265 推流失败：[${cameraDeviceFailureCode(error)}] ${describeCameraDeviceFailure(cameraId, error)}")
                }
            },
            workerHandler,
        )
        if (isGenerationActive(generation)) {
            statusListener("RKMPP H265 摄像头打开中")
        }
    }

    private fun createCaptureSession(camera: CameraDevice, targetSurface: Surface, generation: Long) {
        camera.createCaptureSession(
            listOf(targetSurface),
            object : CameraCaptureSession.StateCallback() {
                override fun onConfigured(session: CameraCaptureSession) {
                    if (!isGenerationActive(generation)) {
                        session.close()
                        return
                    }
                    runCatching {
                        captureSession = session
                        if (!isGenerationActive(generation)) {
                            if (captureSession === session) {
                                captureSession = null
                            }
                            session.close()
                            return
                        }
                        val request = camera.createCaptureRequest(CameraDevice.TEMPLATE_RECORD).apply {
                            addTarget(targetSurface)
                            set(CaptureRequest.CONTROL_MODE, CaptureRequest.CONTROL_MODE_AUTO)
                            set(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, Range(streamFps, streamFps))
                        }
                        session.setRepeatingRequest(request.build(), null, workerHandler)
                        statusListener("RKMPP H265 推流启动中")
                    }.onFailure { error ->
                        session.close()
                        if (isGenerationActive(generation)) {
                            stopAfterRuntimeFailure(
                                "RKMPP H265 推流失败：摄像头会话启动失败：${error.message ?: error::class.java.simpleName}",
                                error,
                            )
                        }
                    }
                }

                override fun onConfigureFailed(session: CameraCaptureSession) {
                    session.close()
                    if (!isGenerationActive(generation)) {
                        return
                    }
                    stopAfterRuntimeFailure("RKMPP H265 推流失败：摄像头会话配置失败")
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

    private fun isGenerationActive(generation: Long): Boolean {
        return streaming.get() && streamGeneration.get() == generation
    }

    private fun reportStartFailure(status: String) {
        if (startFailureReason.isNullOrBlank()) {
            startFailureReason = status
        }
        statusListener(status)
    }

    private fun shouldReportProgress(frameCount: Int): Boolean {
        return frameCount <= 3 || frameCount % 300 == 0
    }

    companion object {
        private const val TAG = "SmartCabinetRkMpp"
    }

    private enum class RtspSender {
        // Kotlin publisher is the default because it explicitly performs ANNOUNCE/SETUP/RECORD.
        KOTLIN,
    }
}
