package com.example.smart_cabinet.kiosk

/**
 * 单路摄像头 H265/RTSP 管线的统一生命周期契约。
 *
 * [start] 返回 `true` 只表示同步初始化已被接受；摄像头打开、编码首帧和 RTSP
 * RECORD 均为异步阶段，最终状态由实现类构造时注入的监听器上报。[stop] 必须可重复
 * 调用，并使旧一轮异步回调失效。
 */
interface H265RtspStream {
    /** 当前管线绑定的 Camera2 ID；停止或同步启动失败后应恢复为 `null`。 */
    val currentCameraId: String?

    /** 最近一次同步启动产生的首个具体失败，供上层决定重连还是终止。 */
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
