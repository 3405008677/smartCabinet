package com.example.smart_cabinet.kiosk

import android.content.Context
import android.util.Log
import java.nio.ByteBuffer

/**
 * Kotlin 到 RKMPP 原生编码桥的窄边界。
 *
 * `false`、`0L` 和 `null` 分别是初始化、句柄创建和帧编码失败的稳定哨兵，具体原因
 * 通过 [lastError] 获取。桥接层不会把库缺失或 JNI 异常抛到摄像头回调线程，便于上层
 * 记录状态或执行重连；编码器选型由 [KioskManager] 创建管线时完成，并非此处运行时回退。
 */
class RkMppBridge {
    fun initialize(context: Context): Boolean {
        if (!isRkMppLibraryLoaded) {
            Log.e(TAG, "RKMPP native library unavailable", loadError)
            return false
        }
        return runCatching { nativeInitialize() }
            .onFailure { error -> Log.e(TAG, "RKMPP native initialize failed", error) }
            .getOrDefault(false)
    }

    fun version(): String {
        if (!isRkMppLibraryLoaded) {
            return "不可用"
        }
        return runCatching { nativeVersion() }
            .getOrDefault("未知")
    }

    fun lastError(): String {
        if (!isRkMppLibraryLoaded) {
            return loadError?.message ?: "RKMPP native library unavailable"
        }
        return runCatching { nativeLastError() }.getOrDefault("")
    }

    fun rkMppStatus(): String {
        if (!isRkMppLibraryLoaded) {
            return loadError?.message ?: "smartcabinet_rkmpp unavailable"
        }
        return runCatching { nativeRkMppStatus() }
            .getOrDefault("RKMPP 状态未知")
    }

    fun startRkMppH265(width: Int, height: Int, fps: Int, bitrate: Int, gop: Int): Boolean {
        if (!isRkMppLibraryLoaded) {
            return false
        }
        return runCatching { nativeStartRkMppH265(width, height, fps, bitrate, gop) }
            .onFailure { error -> Log.e(TAG, "RKMPP H265 start failed", error) }
            .getOrDefault(false)
    }

    /** 创建多路编码使用的不透明原生句柄；`0L` 无效，成功句柄须由 [destroyRkMppH265Encoder] 释放。 */
    fun createRkMppH265Encoder(width: Int, height: Int, fps: Int, bitrate: Int, gop: Int): Long {
        if (!isRkMppLibraryLoaded) {
            return 0L
        }
        return runCatching { nativeCreateRkMppH265Encoder(width, height, fps, bitrate, gop) }
            .onFailure { error -> Log.e(TAG, "RKMPP H265 handle create failed", error) }
            .getOrDefault(0L)
    }

    fun encodeRkMppH265Frame(nv12: ByteArray, presentationTimeUs: Long): ByteArray? {
        if (!isRkMppLibraryLoaded) {
            return null
        }
        return runCatching { nativeEncodeRkMppH265Frame(nv12, presentationTimeUs) }
            .onFailure { error -> Log.e(TAG, "RKMPP H265 encode failed", error) }
            .getOrNull()
    }

    fun encodeRkMppH265Image(
        yBuffer: ByteBuffer,
        uBuffer: ByteBuffer,
        vBuffer: ByteBuffer,
        width: Int,
        height: Int,
        yRowStride: Int,
        yPixelStride: Int,
        uRowStride: Int,
        uPixelStride: Int,
        vRowStride: Int,
        vPixelStride: Int,
        presentationTimeUs: Long,
    ): ByteArray? {
        if (!isRkMppLibraryLoaded) {
            return null
        }
        return runCatching {
            nativeEncodeRkMppH265Image(
                yBuffer,
                uBuffer,
                vBuffer,
                width,
                height,
                yRowStride,
                yPixelStride,
                uRowStride,
                uPixelStride,
                vRowStride,
                vPixelStride,
                presentationTimeUs,
            )
        }
            .onFailure { error -> Log.e(TAG, "RKMPP H265 image encode failed", error) }
            .getOrNull()
    }

    /**
     * 使用指定原生编码器同步消费 Camera2 的三个 YUV plane。
     *
     * ByteBuffer 必须是 direct buffer，且仅保证在本次调用返回前有效；调用方应在
     * `Image.use` 作用域内完成编码，并与句柄销毁互斥，避免 JNI 保存失效地址。
     */
    fun encodeRkMppH265ImageWithHandle(
        handle: Long,
        yBuffer: ByteBuffer,
        uBuffer: ByteBuffer,
        vBuffer: ByteBuffer,
        width: Int,
        height: Int,
        yRowStride: Int,
        yPixelStride: Int,
        uRowStride: Int,
        uPixelStride: Int,
        vRowStride: Int,
        vPixelStride: Int,
        presentationTimeUs: Long,
    ): ByteArray? {
        if (!isRkMppLibraryLoaded || handle == 0L) {
            return null
        }
        return runCatching {
            nativeEncodeRkMppH265ImageWithHandle(
                handle,
                yBuffer,
                uBuffer,
                vBuffer,
                width,
                height,
                yRowStride,
                yPixelStride,
                uRowStride,
                uPixelStride,
                vRowStride,
                vPixelStride,
                presentationTimeUs,
            )
        }
            .onFailure { error -> Log.e(TAG, "RKMPP H265 handle image encode failed", error) }
            .getOrNull()
    }

    fun convertYuv420ToNv12(
        yBuffer: ByteBuffer,
        uBuffer: ByteBuffer,
        vBuffer: ByteBuffer,
        width: Int,
        height: Int,
        yRowStride: Int,
        yPixelStride: Int,
        uRowStride: Int,
        uPixelStride: Int,
        vRowStride: Int,
        vPixelStride: Int,
    ): ByteArray? {
        if (!isRkMppLibraryLoaded) {
            return null
        }
        return runCatching {
            nativeConvertYuv420ToNv12(
                yBuffer,
                uBuffer,
                vBuffer,
                width,
                height,
                yRowStride,
                yPixelStride,
                uRowStride,
                uPixelStride,
                vRowStride,
                vPixelStride,
            )
        }
            .onFailure { error -> Log.e(TAG, "native YUV420 to NV12 conversion failed", error) }
            .getOrNull()
    }

    fun stopRkMppH265() {
        if (!isRkMppLibraryLoaded) {
            return
        }
        runCatching { nativeStopRkMppH265() }
            .onFailure { error -> Log.e(TAG, "RKMPP H265 stop failed", error) }
    }

    /** 释放 [createRkMppH265Encoder] 返回的句柄；调用方负责确保每个非零句柄恰好销毁一次。 */
    fun destroyRkMppH265Encoder(handle: Long) {
        if (!isRkMppLibraryLoaded || handle == 0L) {
            return
        }
        runCatching { nativeDestroyRkMppH265Encoder(handle) }
            .onFailure { error -> Log.e(TAG, "RKMPP H265 handle destroy failed", error) }
    }

    // 以下签名与 rkmpp_bridge.cpp 导出的 JNI 名称严格绑定；调整包名、方法名或参数顺序时
    // 必须同步更新原生入口，否则会在首次调用时得到 UnsatisfiedLinkError。
    private external fun nativeInitialize(): Boolean

    private external fun nativeVersion(): String

    private external fun nativeLastError(): String

    private external fun nativeRkMppStatus(): String

    private external fun nativeStartRkMppH265(width: Int, height: Int, fps: Int, bitrate: Int, gop: Int): Boolean

    private external fun nativeCreateRkMppH265Encoder(width: Int, height: Int, fps: Int, bitrate: Int, gop: Int): Long

    private external fun nativeEncodeRkMppH265Frame(nv12: ByteArray, presentationTimeUs: Long): ByteArray?

    private external fun nativeEncodeRkMppH265Image(
        yBuffer: ByteBuffer,
        uBuffer: ByteBuffer,
        vBuffer: ByteBuffer,
        width: Int,
        height: Int,
        yRowStride: Int,
        yPixelStride: Int,
        uRowStride: Int,
        uPixelStride: Int,
        vRowStride: Int,
        vPixelStride: Int,
        presentationTimeUs: Long,
    ): ByteArray?

    private external fun nativeEncodeRkMppH265ImageWithHandle(
        handle: Long,
        yBuffer: ByteBuffer,
        uBuffer: ByteBuffer,
        vBuffer: ByteBuffer,
        width: Int,
        height: Int,
        yRowStride: Int,
        yPixelStride: Int,
        uRowStride: Int,
        uPixelStride: Int,
        vRowStride: Int,
        vPixelStride: Int,
        presentationTimeUs: Long,
    ): ByteArray?

    private external fun nativeConvertYuv420ToNv12(
        yBuffer: ByteBuffer,
        uBuffer: ByteBuffer,
        vBuffer: ByteBuffer,
        width: Int,
        height: Int,
        yRowStride: Int,
        yPixelStride: Int,
        uRowStride: Int,
        uPixelStride: Int,
        vRowStride: Int,
        vPixelStride: Int,
    ): ByteArray?

    private external fun nativeStopRkMppH265()

    private external fun nativeDestroyRkMppH265Encoder(handle: Long)

    companion object {
        private const val TAG = "SmartCabinetRkMpp"
        private val loadError: Throwable?
        private val isRkMppLibraryLoaded: Boolean

        init {
            // 共享库只在类初始化时装载一次；失败状态被缓存，后续调用快速返回稳定哨兵。
            val result = runCatching {
                System.loadLibrary("smartcabinet_rkmpp")
            }
            loadError = result.exceptionOrNull()
            isRkMppLibraryLoaded = result.isSuccess
            loadError?.let { error ->
                Log.e(TAG, "RKMPP native library load failed", error)
            }
        }
    }
}
