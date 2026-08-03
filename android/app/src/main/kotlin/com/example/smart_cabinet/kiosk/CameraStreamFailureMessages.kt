package com.example.smart_cabinet.kiosk

import android.hardware.camera2.CameraAccessException
import android.hardware.camera2.CameraDevice

/**
 * Converts Camera2 failures into stable, user-readable stream status text.
 *
 * Keep the symbolic Camera2 reason in the message so field logs remain
 * searchable even when the Android framework only supplies a numeric code.
 */
internal fun describeCameraAccessFailure(cameraId: String, error: Throwable): String {
    return when (error) {
        is CameraAccessException -> when (error.reason) {
            CameraAccessException.CAMERA_IN_USE ->
                "摄像头被占用：ID $cameraId 正被其他应用或功能使用（CAMERA_IN_USE）"
            CameraAccessException.MAX_CAMERAS_IN_USE ->
                "摄像头被占用：系统同时打开的摄像头数量已达上限（MAX_CAMERAS_IN_USE）"
            CameraAccessException.CAMERA_DISCONNECTED ->
                "摄像头离线或已断开：ID $cameraId（CAMERA_DISCONNECTED）"
            CameraAccessException.CAMERA_DISABLED ->
                "摄像头已被系统策略禁用：ID $cameraId（CAMERA_DISABLED）"
            CameraAccessException.CAMERA_ERROR ->
                "摄像头服务异常：ID $cameraId（CAMERA_ERROR）"
            else ->
                "摄像头访问失败：ID $cameraId，reason=${error.reason}"
        }
        is IllegalArgumentException ->
            "未知摄像头 ID $cameraId，设备可能已离线或摄像头配置已失效"
        is SecurityException ->
            "缺少摄像头权限，无法打开摄像头 ID $cameraId"
        else ->
            "摄像头启动异常：ID $cameraId，${error.message ?: error::class.java.simpleName}"
    }
}

/** Stable code paired with [describeCameraAccessFailure]. */
internal fun cameraAccessFailureCode(error: Throwable): String {
    return when (error) {
        is CameraAccessException -> when (error.reason) {
            CameraAccessException.CAMERA_IN_USE -> "CAMERA_IN_USE"
            CameraAccessException.MAX_CAMERAS_IN_USE -> "MAX_CAMERAS_IN_USE"
            CameraAccessException.CAMERA_DISCONNECTED -> "CAMERA_DISCONNECTED"
            CameraAccessException.CAMERA_DISABLED -> "CAMERA_DISABLED"
            CameraAccessException.CAMERA_ERROR -> "CAMERA_ERROR"
            else -> "CAMERA_ACCESS_FAILED"
        }
        is IllegalArgumentException -> "UNKNOWN_CAMERA_ID"
        is SecurityException -> "CAMERA_PERMISSION_DENIED"
        else -> "CAMERA_START_FAILED"
    }
}

/** Converts [CameraDevice.StateCallback.onError] codes into readable text. */
internal fun describeCameraDeviceFailure(cameraId: String, errorCode: Int): String {
    return when (errorCode) {
        CameraDevice.StateCallback.ERROR_CAMERA_IN_USE ->
            "摄像头被占用：ID $cameraId 正被其他应用或功能使用（CAMERA_IN_USE）"
        CameraDevice.StateCallback.ERROR_MAX_CAMERAS_IN_USE ->
            "摄像头被占用：系统同时打开的摄像头数量已达上限（MAX_CAMERAS_IN_USE）"
        CameraDevice.StateCallback.ERROR_CAMERA_DISABLED ->
            "摄像头已被系统策略禁用：ID $cameraId（CAMERA_DISABLED）"
        CameraDevice.StateCallback.ERROR_CAMERA_DEVICE ->
            "摄像头设备异常：ID $cameraId（CAMERA_DEVICE）"
        CameraDevice.StateCallback.ERROR_CAMERA_SERVICE ->
            "摄像头服务异常：ID $cameraId（CAMERA_SERVICE）"
        else ->
            "摄像头错误：ID $cameraId，code=$errorCode"
    }
}

/** Stable code paired with [describeCameraDeviceFailure]. */
internal fun cameraDeviceFailureCode(errorCode: Int): String {
    return when (errorCode) {
        CameraDevice.StateCallback.ERROR_CAMERA_IN_USE -> "CAMERA_IN_USE"
        CameraDevice.StateCallback.ERROR_MAX_CAMERAS_IN_USE -> "MAX_CAMERAS_IN_USE"
        CameraDevice.StateCallback.ERROR_CAMERA_DISABLED -> "CAMERA_DISABLED"
        CameraDevice.StateCallback.ERROR_CAMERA_DEVICE -> "CAMERA_DEVICE"
        CameraDevice.StateCallback.ERROR_CAMERA_SERVICE -> "CAMERA_SERVICE"
        else -> "CAMERA_ERROR"
    }
}

/** Text used when Camera2 reports an asynchronous disconnect. */
internal fun describeCameraDisconnected(cameraId: String): String {
    return "摄像头离线或已断开：ID $cameraId"
}
