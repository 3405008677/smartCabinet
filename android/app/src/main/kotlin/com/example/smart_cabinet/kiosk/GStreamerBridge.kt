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

    private external fun nativeInitialize(): Boolean

    private external fun nativeVersion(): String

    private external fun nativeLastError(): String

    private external fun nativeStartH265Rtsp(url: String, width: Int, height: Int, fps: Int): Boolean

    private external fun nativePushH265Frame(data: ByteArray, presentationTimeUs: Long, keyFrame: Boolean): Boolean

    private external fun nativeStopH265Rtsp()

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
