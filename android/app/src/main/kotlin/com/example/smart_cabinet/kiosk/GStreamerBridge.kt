package com.example.smart_cabinet.kiosk

import android.content.Context
import android.util.Log
import org.freedesktop.gstreamer.GStreamer

class GStreamerBridge {
    fun initialize(context: Context): Boolean {
        if (!isSmartCabinetLibraryLoaded) {
            Log.e(TAG, "GStreamer native libraries unavailable", loadError)
            return false
        }
        return runCatching {
            GStreamer.init(context.applicationContext)
            nativeInitialize()
        }
            .onFailure { error -> Log.e(TAG, "GStreamer native initialize failed", error) }
            .getOrDefault(false)
    }

    fun version(): String {
        if (!isSmartCabinetLibraryLoaded) {
            return "不可用"
        }
        return runCatching { nativeVersion() }
            .getOrDefault("未知")
    }

    fun startH265Rtsp(url: String, width: Int, height: Int, fps: Int): Boolean {
        if (!isSmartCabinetLibraryLoaded) {
            Log.e(TAG, "GStreamer native libraries unavailable", loadError)
            return false
        }
        return runCatching { nativeStartH265Rtsp(url, width, height, fps) }
            .onFailure { error -> Log.e(TAG, "GStreamer H265 RTSP start failed", error) }
            .getOrDefault(false)
    }

    fun lastError(): String {
        if (!isSmartCabinetLibraryLoaded) {
            return loadError?.message ?: "GStreamer native libraries unavailable"
        }
        return runCatching { nativeLastError() }.getOrDefault("")
    }

    fun pushH265Frame(data: ByteArray, presentationTimeUs: Long, keyFrame: Boolean): Boolean {
        if (!isSmartCabinetLibraryLoaded) {
            return false
        }
        return runCatching { nativePushH265Frame(data, presentationTimeUs, keyFrame) }
            .onFailure { error -> Log.e(TAG, "GStreamer H265 frame push failed", error) }
            .getOrDefault(false)
    }

    fun stopH265Rtsp() {
        if (!isSmartCabinetLibraryLoaded) {
            return
        }
        runCatching { nativeStopH265Rtsp() }
            .onFailure { error -> Log.e(TAG, "GStreamer H265 RTSP stop failed", error) }
    }

    fun pollH265RtspDiagnostics(): String {
        if (!isSmartCabinetLibraryLoaded) {
            return loadError?.message ?: "GStreamer native libraries unavailable"
        }
        return runCatching { nativePollH265RtspDiagnostics() }
            .onFailure { error -> Log.e(TAG, "GStreamer H265 RTSP diagnostics poll failed", error) }
            .getOrDefault("")
    }

    fun rkMppStatus(): String {
        if (!isSmartCabinetLibraryLoaded) {
            return loadError?.message ?: "smartcabinet_gstreamer unavailable"
        }
        return runCatching { nativeRkMppStatus() }
            .getOrDefault("RKMPP 状态未知")
    }

    fun startRkMppH265(width: Int, height: Int, fps: Int, bitrate: Int, gop: Int): Boolean {
        if (!isSmartCabinetLibraryLoaded) {
            return false
        }
        return runCatching { nativeStartRkMppH265(width, height, fps, bitrate, gop) }
            .onFailure { error -> Log.e(TAG, "RKMPP H265 start failed", error) }
            .getOrDefault(false)
    }

    fun encodeRkMppH265Frame(nv12: ByteArray, presentationTimeUs: Long): ByteArray? {
        if (!isSmartCabinetLibraryLoaded) {
            return null
        }
        return runCatching { nativeEncodeRkMppH265Frame(nv12, presentationTimeUs) }
            .onFailure { error -> Log.e(TAG, "RKMPP H265 encode failed", error) }
            .getOrNull()
    }

    fun stopRkMppH265() {
        if (!isSmartCabinetLibraryLoaded) {
            return
        }
        runCatching { nativeStopRkMppH265() }
            .onFailure { error -> Log.e(TAG, "RKMPP H265 stop failed", error) }
    }

    private external fun nativeInitialize(): Boolean

    private external fun nativeVersion(): String

    private external fun nativeLastError(): String

    private external fun nativeStartH265Rtsp(url: String, width: Int, height: Int, fps: Int): Boolean

    private external fun nativePushH265Frame(data: ByteArray, presentationTimeUs: Long, keyFrame: Boolean): Boolean

    private external fun nativePollH265RtspDiagnostics(): String

    private external fun nativeStopH265Rtsp()

    private external fun nativeRkMppStatus(): String

    private external fun nativeStartRkMppH265(width: Int, height: Int, fps: Int, bitrate: Int, gop: Int): Boolean

    private external fun nativeEncodeRkMppH265Frame(nv12: ByteArray, presentationTimeUs: Long): ByteArray?

    private external fun nativeStopRkMppH265()

    companion object {
        private const val TAG = "SmartCabinetGst"
        private val loadError: Throwable?
        private val isSmartCabinetLibraryLoaded: Boolean

        init {
            val result = runCatching {
                System.loadLibrary("gstreamer_android")
                System.loadLibrary("smartcabinet_gstreamer")
            }
            loadError = result.exceptionOrNull()
            isSmartCabinetLibraryLoaded = result.isSuccess
            loadError?.let { error ->
                Log.e(TAG, "GStreamer native library load failed", error)
            }
        }
    }
}
