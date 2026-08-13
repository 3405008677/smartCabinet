package com.example.smart_cabinet

import android.app.Application
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.util.Log
import androidx.camera.camera2.Camera2Config
import androidx.camera.core.CameraSelector
import androidx.camera.core.CameraXConfig

/**
 * 为柜机摄像头板提供 CameraX 配置，并修正部分定制 ROM 的镜头方向声明偏差。
 * Camera2 枚举失败时保留 CameraX 默认配置，避免一次能力探测异常阻断应用启动。
 */
class SmartCabinetApplication : Application(), CameraXConfig.Provider {
    override fun getCameraXConfig(): CameraXConfig {
        val builder = CameraXConfig.Builder.fromConfig(Camera2Config.defaultConfig())
        val lensFacings = readLensFacings()

        // 某些柜机 ROM 声明了前置摄像头 feature，但所有物理 Camera2 设备实际都标记为后置。
        // 此时限定为后置 selector 仍会保留所有匹配设备（目标柜机上的 ID 0 和 1）。
        if (CameraCharacteristics.LENS_FACING_BACK in lensFacings &&
            CameraCharacteristics.LENS_FACING_FRONT !in lensFacings
        ) {
            builder.setAvailableCamerasLimiter(CameraSelector.DEFAULT_BACK_CAMERA)
            Log.i(TAG, "CameraX limited to actual back-facing cabinet cameras")
        }

        return builder.build()
    }

    private fun readLensFacings(): Set<Int> {
        val cameraManager = getSystemService(CameraManager::class.java)
        return runCatching {
            cameraManager.cameraIdList.mapNotNullTo(mutableSetOf()) { cameraId ->
                cameraManager.getCameraCharacteristics(cameraId)
                    .get(CameraCharacteristics.LENS_FACING)
            }
        }.onFailure { error ->
            Log.w(
                TAG,
                "Unable to inspect lens facings; using default CameraX config",
                error,
            )
        }.getOrDefault(emptySet())
    }

    private companion object {
        const val TAG = "SmartCabinetCamera"
    }
}
