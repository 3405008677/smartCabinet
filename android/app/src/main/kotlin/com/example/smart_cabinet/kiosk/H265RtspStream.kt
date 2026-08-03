package com.example.smart_cabinet.kiosk

interface H265RtspStream {
    val currentCameraId: String?

    /** First concrete failure produced by the most recent synchronous start. */
    val startFailureReason: String?

    fun start(
        cameraId: String,
        url: String,
        width: Int,
        height: Int,
        fps: Int,
        bitrate: Int,
        iframeInterval: Int,
    ): Boolean

    fun stop()

    fun isStreaming(): Boolean
}
