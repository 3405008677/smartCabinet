package com.example.smart_cabinet

import android.os.Bundle
import android.util.Log
import com.example.smart_cabinet.kiosk.KioskManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var kioskManager: KioskManager

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        kioskManager = KioskManager(this)
        runKioskAction("initialize window flags") {
            kioskManager.keepScreenOn()
            kioskManager.hideSystemBars()
        }
    }

    override fun onResume() {
        super.onResume()
        runKioskAction("hide system bars") { kioskManager.hideSystemBars() }
        runKioskAction("enter kiosk mode") { kioskManager.enterKioskMode() }
        runKioskAction("start configured streams") {
            kioskManager.startOutsideEnvironmentStreamIfConfigured()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            KIOSK_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enterKioskMode" -> runKioskMethod(result) { kioskManager.enterKioskMode() }
                "exitKioskMode" -> runKioskMethod(result) { kioskManager.exitKioskMode() }
                "isKioskModeActive" -> runKioskMethod(result) { kioskManager.isKioskModeActive() }
                "isDeviceOwner" -> runKioskMethod(result) { kioskManager.isDeviceOwner() }
                "getDeviceInfo" -> runKioskMethod(result) { kioskManager.getDeviceInfo() }
                "getHardwareStatus" -> runKioskMethod(result) { kioskManager.getHardwareStatus() }
                "readCameraBindings" -> runKioskMethod(result) { kioskManager.readCameraBindings() }
                "readOutsideEnvironmentStreamStatus" -> result.success(
                    kioskManager.readOutsideEnvironmentStreamStatus(),
                )
                "readOperationAreaStreamStatus" -> result.success(
                    kioskManager.readOperationAreaStreamStatus(),
                )
                "readGStreamerStatus" -> result.success(kioskManager.readGStreamerStatus())
                "recordErrorLog" -> {
                    kioskManager.recordErrorLog(
                        source = call.argument<String>("source") ?: "flutter",
                        message = call.argument<String>("message") ?: "",
                        error = call.argument<String>("error") ?: "",
                        stackTrace = call.argument<String>("stackTrace") ?: "",
                    )
                    result.success(null)
                }
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
                "startConfiguredStreams" -> {
                    kioskManager.startConfiguredStreamsFromFlutter()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun runKioskAction(action: String, block: () -> Unit) {
        runCatching(block).onFailure { error ->
            Log.e(TAG, "Kiosk action failed: $action", error)
        }
    }

    private fun <T> runKioskMethod(result: MethodChannel.Result, block: () -> T) {
        runCatching(block)
            .onSuccess(result::success)
            .onFailure { error ->
                Log.e(TAG, "Kiosk method failed", error)
                result.error(
                    "kiosk_method_failed",
                    error.message ?: error::class.java.simpleName,
                    null,
                )
            }
    }

    companion object {
        private const val TAG = "SmartCabinetMain"
        private const val KIOSK_CHANNEL = "smart_cabinet/kiosk"
    }
}
