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
import android.util.Log
import android.util.Range
import android.view.Surface
import androidx.core.app.ActivityCompat
import java.util.concurrent.atomic.AtomicBoolean

class DualMediaCodecH265Stream(
    private val context: Context,
    private val bridge: RkMppBridge,
    private val statusListener: (String) -> Unit,
) {
    data class StreamRequest(
        val profile: String,
        val url: String,
        val width: Int,
        val height: Int,
        val fps: Int,
        val bitrate: Int,
        val iframeInterval: Int,
    )

    private class EncoderLane(val request: StreamRequest) {
        var encoderHandle = 0L
        var imageReader: ImageReader? = null
        var rtspPublisher: RtspTcpH265Publisher? = null
        var encodedFrameCount = 0
        var pushedFrameCount = 0
        var pushedByteCount = 0L
        var waitingParameterSetCount = 0
        var lastAcceptedImageTimestampNs = 0L
    }

    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var workerThread: HandlerThread? = null
    private var workerHandler: Handler? = null
    private var lanes = emptyList<EncoderLane>()
    private val streaming = AtomicBoolean(false)
    private val stopping = AtomicBoolean(false)
    var currentCameraId: String? = null
        private set

    fun start(cameraId: String, requests: List<StreamRequest>): Boolean {
        if (streaming.get()) {
            statusListener("RKMPP H265 推流中")
            return true
        }
        if (ActivityCompat.checkSelfPermission(context, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            statusListener("缺少摄像头权限")
            return false
        }
        if (requests.isEmpty()) {
            statusListener("RKMPP H265 至少需要一个 profile")
            return false
        }

        return runCatching {
            stopping.set(false)
            currentCameraId = cameraId
            statusListener("正在初始化 RKMPP H265：profiles=${requests.joinToString(",") { request -> request.profile }}，${bridge.rkMppStatus()}")
            if (!bridge.initialize(context)) {
                statusListener("RKMPP 依赖库初始化失败：${bridge.lastError().ifBlank { "未知错误" }}")
                return false
            }
            startWorkerThread()
            lanes = requests.map { request -> createEncoderLane(request) }
            openCamera(cameraId)
            streaming.set(true)
            true
        }.getOrElse { error ->
            Log.e(TAG, "RKMPP H265 stream start failed", error)
            statusListener("RKMPP H265 启动失败：${error.message ?: error::class.java.simpleName}")
            stop()
            false
        }
    }

    fun stop() {
        if (!stopping.compareAndSet(false, true) && !streaming.get()) {
            return
        }
        streaming.set(false)
        currentCameraId = null
        runCatching { captureSession?.close() }
        captureSession = null
        runCatching { cameraDevice?.close() }
        cameraDevice = null
        lanes.forEach { lane ->
            runCatching { lane.imageReader?.close() }
            lane.imageReader = null
            runCatching { lane.rtspPublisher?.stop() }
            lane.rtspPublisher = null
            bridge.destroyRkMppH265Encoder(lane.encoderHandle)
            lane.encoderHandle = 0L
        }
        lanes = emptyList()
        stopWorkerThread()
        statusListener("RKMPP H265 已停止")
    }

    fun isStreaming(): Boolean = streaming.get()

    private fun createEncoderLane(request: StreamRequest): EncoderLane {
        val handle = bridge.createRkMppH265Encoder(
            request.width,
            request.height,
            request.fps,
            request.bitrate,
            request.iframeInterval,
        )
        if (handle == 0L) {
            error("${request.profile} RKMPP H265 初始化失败：${bridge.lastError().ifBlank { bridge.rkMppStatus() }}")
        }
        val lane = EncoderLane(request)
        lane.encoderHandle = handle
        lane.imageReader = ImageReader.newInstance(request.width, request.height, ImageFormat.YUV_420_888, 2).also { reader ->
            reader.setOnImageAvailableListener({ availableReader -> handleImageAvailable(lane, availableReader) }, workerHandler)
        }
        statusListener("${request.profile} RKMPP H265 编码器已启动：${request.width}x${request.height}@${request.fps}")
        return lane
    }

    private fun openCamera(cameraId: String) {
        val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        cameraManager.openCamera(
            cameraId,
            object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    runCatching {
                        cameraDevice = camera
                        createCaptureSession(camera)
                    }.onFailure { error ->
                        stopAfterRuntimeFailure("RKMPP H265 摄像头启动失败：${error.message ?: error::class.java.simpleName}", error)
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

    private fun createCaptureSession(camera: CameraDevice) {
        val targetSurfaces = lanes.mapNotNull { lane -> lane.imageReader?.surface }
        camera.createCaptureSession(
            targetSurfaces,
            object : CameraCaptureSession.StateCallback() {
                override fun onConfigured(session: CameraCaptureSession) {
                    runCatching {
                        captureSession = session
                        val maxFps = lanes.maxOf { lane -> lane.request.fps }.coerceAtLeast(1)
                        val request = camera.createCaptureRequest(CameraDevice.TEMPLATE_RECORD).apply {
                            targetSurfaces.forEach(::addTarget)
                            set(CaptureRequest.CONTROL_MODE, CaptureRequest.CONTROL_MODE_AUTO)
                            set(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, Range(maxFps, maxFps))
                        }
                        session.setRepeatingRequest(request.build(), null, workerHandler)
                        statusListener("RKMPP H265 摄像头会话已启动：profiles=${lanes.joinToString(",") { lane -> lane.request.profile }}")
                    }.onFailure { error ->
                        stopAfterRuntimeFailure("RKMPP H265 摄像头会话启动失败：${error.message ?: error::class.java.simpleName}", error)
                    }
                }

                override fun onConfigureFailed(session: CameraCaptureSession) {
                    stopAfterRuntimeFailure("RKMPP H265 摄像头会话配置失败")
                }
            },
            workerHandler,
        )
    }

    private fun handleImageAvailable(lane: EncoderLane, availableReader: ImageReader) {
        runCatching {
            val image = availableReader.acquireLatestImage() ?: return
            image.use { currentImage ->
                if (!streaming.get() || !shouldAcceptImage(lane, currentImage.timestamp)) {
                    return@use
                }
                val encoded = currentImage.encodeWithNative(lane, currentImage.timestamp / 1000)
                if (encoded == null || encoded.isEmpty()) {
                    statusListener("${lane.request.profile} RKMPP H265 转换编码失败：${bridge.lastError().ifBlank { "无输出帧" }}")
                    return@use
                }
                lane.encodedFrameCount += 1
                if (!ensureRtspPublisherStarted(lane, encoded)) {
                    lane.waitingParameterSetCount += 1
                    if (lane.waitingParameterSetCount <= 3 || lane.waitingParameterSetCount % 30 == 0) {
                        statusListener("${lane.request.profile} RKMPP H265 等待 VPS/SPS/PPS：frames=${lane.waitingParameterSetCount} bytes=${encoded.size}")
                    }
                    return@use
                }
                lane.rtspPublisher?.sendFrame(encoded, currentImage.timestamp / 1000, lane.encodedFrameCount == 1)
                lane.pushedFrameCount += 1
                lane.pushedByteCount += encoded.size.toLong()
                if (lane.pushedFrameCount <= 3 || lane.pushedFrameCount % 30 == 0) {
                    statusListener("${lane.request.profile} RKMPP H265 推流中：encoded=${lane.encodedFrameCount} pushed=${lane.pushedFrameCount} bytes=${lane.pushedByteCount} last=${encoded.size}")
                }
            }
        }.onFailure { error ->
            stopAfterRuntimeFailure("${lane.request.profile} RKMPP H265 推流失败：${error.message ?: error::class.java.simpleName}", error)
        }
    }

    private fun ensureRtspPublisherStarted(lane: EncoderLane, codecConfig: ByteArray): Boolean {
        val publisher = lane.rtspPublisher
        if (publisher != null) {
            return true
        }
        val nextPublisher = RtspTcpH265Publisher(statusListener)
        if (!nextPublisher.canStart(codecConfig)) {
            return false
        }
        nextPublisher.start(lane.request.url, codecConfig)
        lane.rtspPublisher = nextPublisher
        lane.waitingParameterSetCount = 0
        statusListener("${lane.request.profile} RKMPP H265 RTSP 已启动：${lane.request.url}")
        return true
    }

    private fun shouldAcceptImage(lane: EncoderLane, timestampNs: Long): Boolean {
        val minFrameIntervalNs = 1_000_000_000L / lane.request.fps.coerceAtLeast(1)
        val previousTimestampNs = lane.lastAcceptedImageTimestampNs
        if (previousTimestampNs > 0L && timestampNs - previousTimestampNs < minFrameIntervalNs) {
            return false
        }
        lane.lastAcceptedImageTimestampNs = timestampNs
        return true
    }

    private fun Image.encodeWithNative(lane: EncoderLane, presentationTimeUs: Long): ByteArray? {
        val yPlane = planes[0]
        val uPlane = planes[1]
        val vPlane = planes[2]
        return bridge.encodeRkMppH265ImageWithHandle(
            handle = lane.encoderHandle,
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

    private fun startWorkerThread() {
        workerThread = HandlerThread("SmartCabinetDualRkMppCamera").also { thread ->
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
        Thread { stop() }.apply {
            name = "SmartCabinetDualRkMppSafeStop"
            start()
        }
    }

    companion object {
        private const val TAG = "SmartCabinetDualRkMpp"
    }
}
