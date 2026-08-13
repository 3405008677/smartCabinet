package com.example.smart_cabinet

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import com.example.smart_cabinet.kiosk.KioskManager
import com.example.smart_cabinet.logging.NativeCommunicationLogEntry
import com.example.smart_cabinet.logging.NativeCommunicationLogStore
import com.example.smart_cabinet.upgrade.TerminalUpgradeInstaller
import com.example.smart_cabinet.upgrade.terminalUpgradePublicMessage
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Flutter 与 Android 柜机能力之间的进程内边界。
 *
 * [KIOSK_CHANNEL]、[UPGRADE_CHANNEL] 与 [COMMUNICATION_LOG_CHANNEL] 上的方法名、参数名、
 * 错误码和返回 Map 字段均由 Dart 侧消费，属于跨层稳定契约；新增能力应保持旧调用
 * 仍可解析，未知方法交由 [MethodChannel.Result.notImplemented]。
 */
class MainActivity : FlutterActivity() {
    private lateinit var kioskManager: KioskManager
    private lateinit var upgradeInstaller: TerminalUpgradeInstaller
    private var kioskChannel: MethodChannel? = null
    private var upgradeChannel: MethodChannel? = null
    private var communicationLogChannel: MethodChannel? = null
    private var communicationLogEventChannel: EventChannel? = null
    private var communicationLogListener: ((NativeCommunicationLogEntry) -> Unit)? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val activityReleased = AtomicBoolean(false)
    private val activeUpgradeOperationIds = ConcurrentHashMap.newKeySet<String>()

    // Camera2/系统服务能力读取可能阻塞 Binder；串行后台执行可避免卡住 Flutter 主线程，
    // 最终 MethodChannel.Result 仍统一切回主线程完成。
    private val kioskReadExecutor: ExecutorService =
        Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "smart-cabinet-kiosk-read").apply { isDaemon = true }
        }

    // APK 解析、签名校验与 PackageInstaller Session 写入都可能包含磁盘 I/O；
    // 独立串行执行器避免阻塞 Flutter 主线程，也避免重复安装请求并发写 Session。
    private val upgradeInstallExecutor: ExecutorService =
        Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "smart-cabinet-upgrade-install").apply { isDaemon = true }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        kioskManager = KioskManager(this)
        upgradeInstaller = TerminalUpgradeInstaller(applicationContext)
        runKioskAction("initialize window flags") {
            kioskManager.keepScreenOn()
            kioskManager.hideSystemBars()
        }
        runKioskAction("start stream control server") { kioskManager.startStreamControlServer() }
    }

    override fun onDestroy() {
        // 先断开 Flutter 回调入口并清除待回主线程任务，再释放摄像头、网络和执行器，
        // 防止 Activity 销毁后异步读取仍尝试回复已经失效的 Engine。
        activityReleased.set(true)
        kioskChannel?.setMethodCallHandler(null)
        kioskChannel = null
        upgradeChannel?.setMethodCallHandler(null)
        upgradeChannel = null
        communicationLogChannel?.setMethodCallHandler(null)
        communicationLogChannel = null
        communicationLogEventChannel?.setStreamHandler(null)
        communicationLogEventChannel = null
        communicationLogListener?.let(NativeCommunicationLogStore::removeListener)
        communicationLogListener = null
        mainHandler.removeCallbacksAndMessages(null)
        kioskReadExecutor.shutdownNow()
        // Activity/Engine 释放等同 Dart dispose：已 commit 的系统会话继续收敛，
        // 排队中或仍在原生预提交阶段的 operation 必须先标记取消。
        activeUpgradeOperationIds.forEach { operationId ->
            runCatching { upgradeInstaller.cancelInstall(operationId) }
        }
        upgradeInstallExecutor.shutdown()
        if (::kioskManager.isInitialized) {
            kioskManager.release()
        }
        super.onDestroy()
    }

    override fun onResume() {
        super.onResume()
        // 外部设置页或系统对话框可能恢复系统栏并退出锁定任务，回前台时重新收敛柜机状态。
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

        configureUpgradeChannel(flutterEngine)
        configureCommunicationLogChannels(flutterEngine)
    }

    /**
     * 暴露原生有界队列快照和实时事件。
     *
     * Dart 应先订阅事件再读取 `snapshot`，并按 `nativeId` 去重，从而覆盖 Engine 创建前
     * 产生的 RTSP、HTTP 或 PackageInstaller 回调，又不遗漏订阅切换窗口的新事件。
     */
    private fun configureCommunicationLogChannels(flutterEngine: FlutterEngine) {
        val methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            COMMUNICATION_LOG_CHANNEL,
        )
        communicationLogChannel = methodChannel
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "snapshot" -> result.success(NativeCommunicationLogStore.snapshot())
                else -> result.notImplemented()
            }
        }

        val eventChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            COMMUNICATION_LOG_EVENT_CHANNEL,
        )
        communicationLogEventChannel = eventChannel
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                communicationLogListener?.let(NativeCommunicationLogStore::removeListener)
                lateinit var listener: (NativeCommunicationLogEntry) -> Unit
                listener = { entry ->
                    mainHandler.post {
                        if (!activityReleased.get() && communicationLogListener === listener) {
                            // Engine 切换边界上的诊断事件允许丢弃，不能反向中断原生通讯线程。
                            runCatching { events.success(entry.toMethodChannelMap()) }
                        }
                    }
                }
                communicationLogListener = listener
                NativeCommunicationLogStore.addListener(listener)
            }

            override fun onCancel(arguments: Any?) {
                communicationLogListener?.let(NativeCommunicationLogStore::removeListener)
                communicationLogListener = null
            }
        })
    }

    /** 注册独立升级通道，并把耗时安装提交调度到专用后台执行器。 */
    private fun configureUpgradeChannel(flutterEngine: FlutterEngine) {
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            UPGRADE_CHANNEL,
        )
        upgradeChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getAppVersion" -> runUpgradeMethod(result) {
                    upgradeInstaller.getAppVersion()
                }
                "getInstallStatus" -> runUpgradeMethod(result) {
                    upgradeInstaller.getInstallStatus()
                }
                "installApk" -> {
                    val apkPath = call.argument<String>("apkPath")
                        ?: call.argument<String>("path")
                    val targetVersion = call.argument<String>("targetVersion")
                    val operationId = call.argument<String>("operationId")
                    if (apkPath.isNullOrBlank()) {
                        result.error(
                            "invalid_upgrade_apk",
                            "apkPath is empty",
                            null,
                        )
                    } else if (targetVersion.isNullOrBlank()) {
                        result.error(
                            "invalid_upgrade_target_version",
                            "targetVersion is empty",
                            null,
                        )
                    } else if (operationId.isNullOrBlank()) {
                        result.error(
                            "invalid_upgrade_operation",
                            "operationId is empty",
                            null,
                        )
                    } else {
                        runUpgradeInstallMethod(
                            apkPath,
                            targetVersion,
                            operationId,
                            result,
                        )
                    }
                }
                "cancelInstall" -> {
                    val operationId = call.argument<String>("operationId")
                    if (operationId.isNullOrBlank()) {
                        result.error(
                            "invalid_upgrade_operation",
                            "operationId is empty",
                            null,
                        )
                    } else {
                        runCatching { upgradeInstaller.cancelInstall(operationId) }
                            .onSuccess(result::success)
                            .onFailure { error ->
                                result.error(
                                    "upgrade_cancel_failed",
                                    terminalUpgradePublicMessage(error),
                                    null,
                                )
                            }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /** 串行执行版本/状态读取，避免 PackageManager、Session 对账或同步落盘阻塞界面线程。 */
    private fun <T> runUpgradeMethod(result: MethodChannel.Result, block: () -> T) {
        runCatching {
            upgradeInstallExecutor.execute {
                val outcome = runCatching(block)
                if (activityReleased.get()) {
                    return@execute
                }
                mainHandler.post {
                    if (activityReleased.get()) {
                        return@post
                    }
                    outcome
                        .onSuccess(result::success)
                        .onFailure { error ->
                            Log.e(
                                TAG,
                                "Upgrade method failed: ${error::class.java.simpleName}",
                            )
                            result.error(
                                "upgrade_method_failed",
                                terminalUpgradePublicMessage(error),
                                null,
                            )
                        }
                }
            }
        }.onFailure { error ->
            Log.e(TAG, "Upgrade method dispatch failed: ${error::class.java.simpleName}")
            result.error(
                "upgrade_method_failed",
                terminalUpgradePublicMessage(error),
                null,
            )
        }
    }

    /** 在独立串行线程校验并提交 APK，Activity 销毁后不再回复失效的 Flutter Engine。 */
    private fun runUpgradeInstallMethod(
        apkPath: String,
        targetVersion: String,
        operationId: String,
        result: MethodChannel.Result,
    ) {
        activeUpgradeOperationIds.add(operationId)
        runCatching {
            upgradeInstallExecutor.execute {
                val outcome = try {
                    runCatching {
                        upgradeInstaller.installApk(apkPath, targetVersion, operationId)
                    }
                } finally {
                    activeUpgradeOperationIds.remove(operationId)
                }
                if (activityReleased.get()) {
                    return@execute
                }
                mainHandler.post {
                    if (activityReleased.get()) {
                        return@post
                    }
                    outcome
                        .onSuccess(result::success)
                        .onFailure { error ->
                            Log.e(
                                TAG,
                                "Upgrade install submission failed: ${error::class.java.simpleName}",
                            )
                            result.error(
                                "upgrade_install_failed",
                                terminalUpgradePublicMessage(error),
                                null,
                            )
                        }
                }
            }
        }.onFailure { error ->
            activeUpgradeOperationIds.remove(operationId)
            runCatching { upgradeInstaller.cancelInstall(operationId) }
            Log.e(TAG, "Upgrade install dispatch failed: ${error::class.java.simpleName}")
            result.error(
                "upgrade_install_failed",
                terminalUpgradePublicMessage(error),
                null,
            )
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
        private const val UPGRADE_CHANNEL = "smart_cabinet/upgrade"
        private const val COMMUNICATION_LOG_CHANNEL = "smart_cabinet/communication_log"
        private const val COMMUNICATION_LOG_EVENT_CHANNEL =
            "smart_cabinet/communication_log/events"
    }
}
