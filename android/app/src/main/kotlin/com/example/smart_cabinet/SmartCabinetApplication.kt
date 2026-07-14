package com.example.smart_cabinet

import android.app.Application
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.util.Log
import androidx.camera.camera2.Camera2Config
import androidx.camera.core.CameraSelector
import androidx.camera.core.CameraXConfig

/** Supplies a CameraX configuration compatible with cabinet camera boards. */
class SmartCabinetApplication : Application(), CameraXConfig.Provider {
    override fun getCameraXConfig(): CameraXConfig {
        val builder = CameraXConfig.Builder.fromConfig(Camera2Config.defaultConfig())
        val lensFacings = readLensFacings()

        // Some cabinet ROMs advertise a front-camera feature even though every
        // physical Camera2 device is reported as back-facing. The back selector
        // retains every matching camera (IDs 0 and 1 on the target cabinet).
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