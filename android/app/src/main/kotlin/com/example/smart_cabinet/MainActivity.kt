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
        runKioskAction("start stream control server") { kioskManager.startStreamControlServer() }
    }

    override fun onDestroy() {
        runKioskAction("stop stream control server") { kioskManager.stopStreamControlServer() }
        super.onDestroy()
    }

    override fun onResume() {
        super.onResume()
        runKioskAction("hide system bars") { kioskManager.hideSystemBars() }
        runKioskAction("enter kiosk mode") { kioskManager.enterKioskMode() }
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
                "readOutsideEnvironmentStreamStatus" -> result.success(
                    kioskManager.readOutsideEnvironmentStreamStatus(),
                )
                "readOperationAreaStreamStatus" -> result.success(
                    kioskManager.readOperationAreaStreamStatus(),
                )
                "readRkMppStatus" -> result.success(kioskManager.readRkMppStatus())
                "recordErrorLog" -> {
                    kioskManager.recordErrorLog(
                        source = call.argument<String>("source") ?: "flutter",
                        message = call.argument<String>("message") ?: "",
                        error = call.argument<String>("error") ?: "",
                        stackTrace = call.argument<String>("stackTrace") ?: "",
                    )
                    result.success(null)
                }
                "openSystemSettings" -> {
                    kioskManager.openSystemSettings()
                    result.success(null)
                }
                "startCameraStream" -> {
                    val role = call.argument<String>("role")
                    val profiles = call.argument<List<String>>("profiles") ?: emptyList()
                    if (role.isNullOrBlank() || profiles.isEmpty()) {
                        result.error("invalid_camera_stream", "role or profiles is empty", null)
                    } else {
                        kioskManager.startCameraStream(role, profiles)
                        result.success(null)
                    }
                }
                "stopCameraStream" -> {
                    val role = call.argument<String>("role")
                    val profiles = call.argument<List<String>>("profiles") ?: emptyList()
                    if (role.isNullOrBlank()) {
                        result.error("invalid_camera_stream", "role is empty", null)
                    } else {
                        kioskManager.stopCameraStream(role, profiles)
                        result.success(null)
                    }
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
