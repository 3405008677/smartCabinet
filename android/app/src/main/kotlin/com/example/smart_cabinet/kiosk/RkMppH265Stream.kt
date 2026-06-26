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
import android.view.Surface
import androidx.core.app.ActivityCompat
import java.util.concurrent.atomic.AtomicBoolean

class RkMppH265Stream(
    private val context: Context,
    private val bridge: GStreamerBridge,
    private val statusListener: (String) -> Unit,
) {
    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var imageReader: ImageReader? = null
    private var workerThread: HandlerThread? = null
    private var workerHandler: Handler? = null
    private val streaming = AtomicBoolean(false)
    private var encodedFrameCount = 0
    private var pushedFrameCount = 0
    private var pushedByteCount = 0L

    fun start(cameraId: String, url: String, width: Int, height: Int, fps: Int, bitrate: Int, iframeInterval: Int): Boolean {
        if (streaming.get()) {
            statusListener("RKMPP H265 推流中")
            return true
        }
        if (ActivityCompat.checkSelfPermission(context, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            statusListener("缺少摄像头权限")
            return false
        }

        return runCatching {
            statusListener("正在初始化 GStreamer")
            if (!bridge.initialize(context)) {
                statusListener("GStreamer 初始化失败：${bridge.lastError().ifBlank { "未知错误" }}")
                return false
            }
            if (!bridge.startH265Rtsp(url, width, height, fps)) {
                statusListener("GStreamer RTSP pipeline 启动失败：${bridge.lastError().ifBlank { "未知错误" }}")
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
        streaming.set(false)
        runCatching { captureSession?.close() }
        captureSession = null
        runCatching { cameraDevice?.close() }
        cameraDevice = null
        runCatching { imageReader?.close() }
        imageReader = null
        bridge.stopRkMppH265()
        bridge.stopH265Rtsp()
        stopWorkerThread()
        statusListener("RKMPP H265 已停止")
    }

    fun isStreaming(): Boolean = streaming.get()

    private fun startWorkerThread() {
        workerThread = HandlerThread("SmartCabinetRkMppCamera").also { thread ->
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

    private fun prepareImageReader(width: Int, height: Int) {
        imageReader = ImageReader.newInstance(width, height, ImageFormat.YUV_420_888, 2).also { reader ->
            reader.setOnImageAvailableListener({ availableReader ->
                val image = availableReader.acquireLatestImage() ?: return@setOnImageAvailableListener
                image.use { currentImage ->
                    if (!streaming.get()) {
                        return@use
                    }
                    val nv12 = currentImage.toNv12()
                    val encoded = bridge.encodeRkMppH265Frame(nv12, currentImage.timestamp / 1000)
                    if (encoded == null || encoded.isEmpty()) {
                        statusListener("RKMPP H265 编码失败：${bridge.lastError().ifBlank { "无输出帧" }}")
                        return@use
                    }
                    encodedFrameCount += 1
                    if (!bridge.pushH265Frame(encoded, currentImage.timestamp / 1000, false)) {
                        statusListener("RKMPP H265 帧推送失败：${bridge.lastError().ifBlank { "GStreamer 未返回具体错误" }}")
                    } else {
                        pushedFrameCount += 1
                        pushedByteCount += encoded.size.toLong()
                        if (pushedFrameCount <= 3 || pushedFrameCount % 30 == 0) {
                            statusListener(
                                "RKMPP H265 推流中：encoded=$encodedFrameCount pushed=$pushedFrameCount bytes=$pushedByteCount last=${encoded.size}",
                            )
                        }
                    }
                }
            }, workerHandler)
        }
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
                        statusListener("RKMPP H265 摄像头启动失败：${error.message ?: error::class.java.simpleName}")
                        Log.e(TAG, "RKMPP H265 camera open callback failed", error)
                        stop()
                    }
                }

                override fun onDisconnected(camera: CameraDevice) {
                    statusListener("RKMPP H265 摄像头断开")
                    camera.close()
                    stop()
                }

                override fun onError(camera: CameraDevice, error: Int) {
                    statusListener("RKMPP H265 摄像头错误：$error")
                    camera.close()
                    stop()
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
                        }
                        session.setRepeatingRequest(request.build(), null, workerHandler)
                        statusListener("RKMPP H265 推流启动中")
                    }.onFailure { error ->
                        statusListener("RKMPP H265 摄像头会话启动失败：${error.message ?: error::class.java.simpleName}")
                        Log.e(TAG, "RKMPP H265 camera session configure callback failed", error)
                        stop()
                    }
                }

                override fun onConfigureFailed(session: CameraCaptureSession) {
                    statusListener("RKMPP H265 摄像头会话配置失败")
                    stop()
                }
            },
            workerHandler,
        )
    }

    private fun Image.toNv12(): ByteArray {
        val output = ByteArray(width * height * 3 / 2)
        copyPlane(planes[0], width, height, output, 0, 1)
        val chromaOffset = width * height
        val uPlane = planes[1]
        val vPlane = planes[2]
        val uBuffer = uPlane.buffer
        val vBuffer = vPlane.buffer
        var out = chromaOffset
        for (row in 0 until height / 2) {
            for (col in 0 until width / 2) {
                val uIndex = row * uPlane.rowStride + col * uPlane.pixelStride
                val vIndex = row * vPlane.rowStride + col * vPlane.pixelStride
                output[out++] = uBuffer.get(uIndex)
                output[out++] = vBuffer.get(vIndex)
            }
        }
        return output
    }

    private fun copyPlane(plane: Image.Plane, width: Int, height: Int, output: ByteArray, offset: Int, pixelStride: Int) {
        val buffer = plane.buffer
        var out = offset
        for (row in 0 until height) {
            for (col in 0 until width) {
                output[out] = buffer.get(row * plane.rowStride + col * plane.pixelStride)
                out += pixelStride
            }
        }
    }

    companion object {
        private const val TAG = "SmartCabinetRkMpp"
    }
}
