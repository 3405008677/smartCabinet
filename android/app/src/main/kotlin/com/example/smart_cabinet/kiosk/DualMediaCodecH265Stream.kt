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
import android.util.Log
import android.util.Range
import android.view.Surface
import androidx.core.app.ActivityCompat
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

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
        val encoderLock = ReentrantLock()
        @Volatile var encoderDetached = false
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
    private val streamGeneration = AtomicLong(0L)
    var currentCameraId: String? = null
        private set
    @Volatile
    var startFailureReason: String? = null
        private set

    fun start(cameraId: String, requests: List<StreamRequest>): Boolean {
        startFailureReason = null
        if (streaming.get()) {
            statusListener("RKMPP H265 推流中")
            return true
        }
        if (ActivityCompat.checkSelfPermission(context, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            reportStartFailure("RKMPP H265 启动失败：缺少摄像头权限")
            return false
        }
        if (requests.isEmpty()) {
            reportStartFailure("RKMPP H265 启动失败：至少需要一个 profile")
            return false
        }

        return runCatching {
            val generation = streamGeneration.incrementAndGet()
            stopping.set(false)
            currentCameraId = cameraId
            statusListener("正在初始化 RKMPP H265：profiles=${requests.joinToString(",") { request -> request.profile }}，${bridge.rkMppStatus()}")
            if (!bridge.initialize(context)) {
                reportStartFailure("RKMPP H265 启动失败：依赖库初始化失败：${bridge.lastError().ifBlank { "未知错误" }}")
                currentCameraId = null
                return false
            }
            startWorkerThread()
            lanes = emptyList()
            requests.forEach { request ->
                lanes = lanes + createEncoderLane(request, generation)
            }
            val activeLanes = lanes
            streaming.set(true)
            openCamera(cameraId, generation, activeLanes)
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

    fun stop() {
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
        val cleanupHandler = workerHandler
        val lanesToDestroy = lanes
        lanes = emptyList()
        lanesToDestroy.forEach { lane ->
            lane.encoderDetached = true
            runCatching { lane.imageReader?.setOnImageAvailableListener(null, null) }
            runCatching { lane.imageReader?.close() }
            lane.imageReader = null
            runCatching { lane.rtspPublisher?.stop() }
            lane.rtspPublisher = null
            scheduleEncoderDestroy(lane, cleanupHandler)
        }
        stopWorkerThread()
        statusListener("RKMPP H265 已停止")
    }

    fun isStreaming(): Boolean = streaming.get()

    private fun createEncoderLane(request: StreamRequest, generation: Long): EncoderLane {
        val lane = EncoderLane(request)
        try {
            lane.encoderHandle = bridge.createRkMppH265Encoder(
                request.width,
                request.height,
                request.fps,
                request.bitrate,
                request.iframeInterval,
            )
            if (lane.encoderHandle == 0L) {
                error("${request.profile} RKMPP H265 初始化失败：${bridge.lastError().ifBlank { bridge.rkMppStatus() }}")
            }
            lane.imageReader = ImageReader.newInstance(
                request.width,
                request.height,
                ImageFormat.YUV_420_888,
                2,
            ).also { reader ->
                reader.setOnImageAvailableListener(
                    { availableReader -> handleImageAvailable(lane, availableReader, generation) },
                    workerHandler,
                )
            }
        } catch (error: Throwable) {
            runCatching { lane.imageReader?.setOnImageAvailableListener(null, null) }
            runCatching { lane.imageReader?.close() }
            lane.imageReader = null
            lane.encoderDetached = true
            scheduleEncoderDestroy(lane, workerHandler)
            throw error
        }
        statusListener("${request.profile} RKMPP H265 编码器已启动：${request.width}x${request.height}@${request.fps}")
        return lane
    }


    private fun openCamera(cameraId: String, generation: Long, activeLanes: List<EncoderLane>) {
        val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
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
                        createCaptureSession(camera, generation, activeLanes)
                    }.onFailure { error ->
                        if (isGenerationActive(generation)) {
                            val detail = when (error) {
                                is CameraAccessException, is IllegalArgumentException, is SecurityException ->
                                    describeCameraAccessFailure(cameraId, error)
                                else -> error.message ?: error::class.java.simpleName
                            }
                            stopAfterRuntimeFailure("RKMPP H265 推流失败：摄像头启动失败：$detail", error)
                        } else {
                            camera.close()
                        }
                    }
                }

                override fun onDisconnected(camera: CameraDevice) {
                    camera.close()
                    if (cameraDevice === camera) {
                        cameraDevice = null
                    }
                    if (isGenerationActive(generation)) {
                        stopAfterRuntimeFailure("RKMPP H265 推流失败：${describeCameraDisconnected(cameraId)}")
                    }
                }

                override fun onError(camera: CameraDevice, error: Int) {
                    camera.close()
                    if (cameraDevice === camera) {
                        cameraDevice = null
                    }
                    if (isGenerationActive(generation)) {
                        stopAfterRuntimeFailure("RKMPP H265 推流失败：[${cameraDeviceFailureCode(error)}] ${describeCameraDeviceFailure(cameraId, error)}")
                    }
                }
            },
            workerHandler,
        )
        if (isGenerationActive(generation)) {
            statusListener("RKMPP H265 摄像头打开中")
        }
    }


    private fun createCaptureSession(camera: CameraDevice, generation: Long, activeLanes: List<EncoderLane>) {
        val targetSurfaces = activeLanes.mapNotNull { lane -> lane.imageReader?.surface }
        camera.createCaptureSession(
            targetSurfaces,
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
                        val maxFps = activeLanes.maxOf { lane -> lane.request.fps }.coerceAtLeast(1)
                        val request = camera.createCaptureRequest(CameraDevice.TEMPLATE_RECORD).apply {
                            targetSurfaces.forEach(::addTarget)
                            set(CaptureRequest.CONTROL_MODE, CaptureRequest.CONTROL_MODE_AUTO)
                            set(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, Range(maxFps, maxFps))
                        }
                        session.setRepeatingRequest(request.build(), null, workerHandler)
                        if (isGenerationActive(generation)) {
                            statusListener("RKMPP H265 摄像头会话已启动：profiles=${activeLanes.joinToString(",") { lane -> lane.request.profile }}")
                        }
                    }.onFailure { error ->
                        session.close()
                        if (isGenerationActive(generation)) {
                            stopAfterRuntimeFailure("RKMPP H265 推流失败：摄像头会话启动失败：${error.message ?: error::class.java.simpleName}", error)
                        }
                    }
                }

                override fun onConfigureFailed(session: CameraCaptureSession) {
                    session.close()
                    if (isGenerationActive(generation)) {
                        stopAfterRuntimeFailure("RKMPP H265 推流失败：摄像头会话配置失败")
                    }
                }
            },
            workerHandler,
        )
    }


    private fun handleImageAvailable(lane: EncoderLane, availableReader: ImageReader, generation: Long) {
        runCatching {
            val image = availableReader.acquireLatestImage() ?: return
            image.use { currentImage ->
                if (!isGenerationActive(generation) || !shouldAcceptImage(lane, currentImage.timestamp)) {
                    return@use
                }
                val encoded = currentImage.encodeWithNative(lane, currentImage.timestamp / 1000)
                if (!isGenerationActive(generation)) {
                    return@use
                }
                if (encoded == null || encoded.isEmpty()) {
                    statusListener("${lane.request.profile} RKMPP H265 转换编码失败：${bridge.lastError().ifBlank { "无输出帧" }}")
                    return@use
                }
                lane.encodedFrameCount += 1
                if (!ensureRtspPublisherStarted(lane, encoded, generation)) {
                    if (!isGenerationActive(generation)) {
                        return@use
                    }
                    lane.waitingParameterSetCount += 1
                    if (shouldReportProgress(lane.waitingParameterSetCount)) {
                        statusListener("${lane.request.profile} RKMPP H265 等待 VPS/SPS/PPS：frames=${lane.waitingParameterSetCount} bytes=${encoded.size}")
                    }
                    return@use
                }
                if (!isGenerationActive(generation)) {
                    return@use
                }
                lane.rtspPublisher?.sendFrame(encoded, currentImage.timestamp / 1000)
                lane.pushedFrameCount += 1
                lane.pushedByteCount += encoded.size.toLong()
                if (shouldReportProgress(lane.pushedFrameCount)) {
                    statusListener("${lane.request.profile} RKMPP H265 推流中：encoded=${lane.encodedFrameCount} pushed=${lane.pushedFrameCount} bytes=${lane.pushedByteCount} last=${encoded.size}")
                }
            }
        }.onFailure { error ->
            if (isGenerationActive(generation)) {
                stopAfterRuntimeFailure("${lane.request.profile} RKMPP H265 推流失败：${error.message ?: error::class.java.simpleName}", error)
            }
        }
    }


    private fun ensureRtspPublisherStarted(
        lane: EncoderLane,
        codecConfig: ByteArray,
        generation: Long,
    ): Boolean {
        lane.rtspPublisher?.let { return true }
        if (!isGenerationActive(generation)) {
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
            nextPublisher.start(lane.request.url, codecConfig)
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
        lane.rtspPublisher = nextPublisher
        if (!isGenerationActive(generation)) {
            lane.rtspPublisher = null
            nextPublisher.stop()
            return false
        }
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
        return lane.encoderLock.withLock {
            if (lane.encoderDetached || lane.encoderHandle == 0L) {
                return@withLock null
            }
            bridge.encodeRkMppH265ImageWithHandle(
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
    }

    private fun scheduleEncoderDestroy(lane: EncoderLane, cleanupHandler: Handler?) {
        val cleanup = Runnable {
            lane.encoderLock.withLock {
                val handle = lane.encoderHandle
                lane.encoderHandle = 0L
                if (handle != 0L) {
                    bridge.destroyRkMppH265Encoder(handle)
                }
            }
        }
        if (cleanupHandler?.post(cleanup) == true) {
            return
        }
        Thread(cleanup, "SmartCabinetRkMppEncoderCleanup").apply {
            isDaemon = true
            start()
        }
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
        streamGeneration.incrementAndGet()
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
        private const val TAG = "SmartCabinetDualRkMpp"
    }
}
