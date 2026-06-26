package com.example.smart_cabinet

import android.os.Bundle
import com.example.smart_cabinet.kiosk.KioskManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var kioskManager: KioskManager

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        kioskManager = KioskManager(this)
        kioskManager.keepScreenOn()
        kioskManager.hideSystemBars()
    }

    override fun onResume() {
        super.onResume()
        kioskManager.hideSystemBars()
        kioskManager.enterKioskMode()
        kioskManager.startOutsideEnvironmentStreamIfConfigured()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            KIOSK_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enterKioskMode" -> result.success(kioskManager.enterKioskMode())
                "exitKioskMode" -> result.success(kioskManager.exitKioskMode())
                "isKioskModeActive" -> result.success(kioskManager.isKioskModeActive())
                "isDeviceOwner" -> result.success(kioskManager.isDeviceOwner())
                "getDeviceInfo" -> result.success(kioskManager.getDeviceInfo())
                "getHardwareStatus" -> result.success(kioskManager.getHardwareStatus())
                "readCameraBindings" -> result.success(kioskManager.readCameraBindings())
                "readOutsideEnvironmentStreamStatus" -> result.success(
                    kioskManager.readOutsideEnvironmentStreamStatus(),
                )
                "readOperationAreaStreamStatus" -> result.success(
                    kioskManager.readOperationAreaStreamStatus(),
                )
                "readGStreamerStatus" -> result.success(kioskManager.readGStreamerStatus())
                "writeCameraBinding" -> {
                    val role = call.argument<String>("role")
                    val cameraId = call.argument<String>("cameraId")
                    if (role.isNullOrBlank() || cameraId.isNullOrBlank()) {
                        result.error("invalid_camera_binding", "role or cameraId is empty", null)
                    } else {
                        kioskManager.writeCameraBinding(role, cameraId)
                        result.success(null)
                    }
                }
                "openSystemSettings" -> {
                    kioskManager.openSystemSettings()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    companion object {
        private const val KIOSK_CHANNEL = "smart_cabinet/kiosk"
    }
}
