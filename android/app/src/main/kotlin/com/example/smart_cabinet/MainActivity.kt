package com.example.smart_cabinet

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import com.example.smart_cabinet.kiosk.KioskManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private lateinit var kioskManager: KioskManager
    private var kioskChannel: MethodChannel? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val kioskReadExecutor: ExecutorService =
        Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "smart-cabinet-kiosk-read").apply { isDaemon = true }
        }

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
        kioskChannel?.setMethodCallHandler(null)
        kioskChannel = null
        mainHandler.removeCallbacksAndMessages(null)
        kioskReadExecutor.shutdownNow()
        if (::kioskManager.isInitialized) {
            kioskManager.release()
        }
        super.onDestroy()
    }

    override fun onResume() {
        super.onResume()
        runKioskAction("hide system bars") { kioskManager.hideSystemBars() }
        runKioskAction("enter kiosk mode") { kioskManager.enterKioskMode() }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            KIOSK_CHANNEL,
        )
        kioskChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "enterKioskMode" -> runKioskMethod(result) { kioskManager.enterKioskMode() }
                "exitKioskMode" -> runKioskMethod(result) { kioskManager.exitKioskMode() }
                "isKioskModeActive" -> runKioskMethod(result) { kioskManager.isKioskModeActive() }
                "isDeviceOwner" -> runKioskMethod(result) { kioskManager.isDeviceOwner() }
                "getDeviceInfo" -> runKioskReadMethod("getDeviceInfo", result) {
                    kioskManager.getDeviceInfo()
                }
                "getHardwareStatus" -> runKioskReadMethod("getHardwareStatus", result) {
                    kioskManager.getHardwareStatus()
                }
                "readOutsideEnvironmentStreamStatus" -> result.success(
                    kioskManager.readOutsideEnvironmentStreamStatus(),
                )
                "readOperationAreaStreamStatus" -> result.success(
                    kioskManager.readOperationAreaStreamStatus(),
                )
                "readCameraStreamCapability" -> {
                    val role = call.argument<String>("role")
                    if (role.isNullOrBlank()) {
                        result.error("invalid_camera_role", "role is empty", null)
                    } else {
                        runKioskReadMethod("readCameraStreamCapability", result) {
                            kioskManager.readCameraStreamCapability(role)
                        }
                    }
                }
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
                        runKioskMethod(result) {
                            kioskManager.startCameraStream(role, profiles)
                            null
                        }
                    }
                }
                "stopCameraStream" -> {
                    val role = call.argument<String>("role")
                    val profiles = call.argument<List<String>>("profiles") ?: emptyList()
                    if (role.isNullOrBlank()) {
                        result.error("invalid_camera_stream", "role is empty", null)
                    } else {
                        runKioskMethod(result) {
                            kioskManager.stopCameraStream(role, profiles)
                            null
                        }
                    }
                }
                "retryCameraStream" -> {
                    val role = call.argument<String>("role")
                    if (role.isNullOrBlank()) {
                        result.error("invalid_camera_stream", "role is empty", null)
                    } else {
                        runKioskMethod(result) {
                            kioskManager.retryCameraStream(role)
                        }
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

    private fun <T> runKioskReadMethod(
        action: String,
        result: MethodChannel.Result,
        block: () -> T,
    ) {
        val startedAt = SystemClock.elapsedRealtime()
        runCatching {
            kioskReadExecutor.execute {
                val outcome = runCatching(block)
                val elapsedMs = SystemClock.elapsedRealtime() - startedAt
                mainHandler.post {
                    outcome
                        .onSuccess { value ->
                            Log.i(TAG, "Kiosk read completed: $action, ${elapsedMs}ms")
                            result.success(value)
                        }
                        .onFailure { error ->
                            Log.e(TAG, "Kiosk read failed: $action", error)
                            result.error(
                                "kiosk_method_failed",
                                error.message ?: error::class.java.simpleName,
                                null,
                            )
                        }
                }
            }
        }.onFailure { error ->
            Log.e(TAG, "Kiosk read dispatch failed: $action", error)
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
