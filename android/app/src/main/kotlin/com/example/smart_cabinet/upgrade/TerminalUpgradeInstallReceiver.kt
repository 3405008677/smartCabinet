package com.example.smart_cabinet.upgrade

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.util.Log
import com.example.smart_cabinet.logging.NativeCommunicationDirection
import com.example.smart_cabinet.logging.NativeCommunicationLogStore
import com.example.smart_cabinet.logging.NativeCommunicationTargetType
import java.util.concurrent.Executors

/** 接收 PackageInstaller 状态变化，并在自更新后对账版本、尝试恢复柜机主界面。 */
class TerminalUpgradeInstallReceiver : BroadcastReceiver() {
    /** 把 Binder 查询、同步落盘和 Session 恢复移出广播主线程，并保证最终 finish。 */
    override fun onReceive(context: Context, intent: Intent) {
        val pendingResult = goAsync()
        val appContext = context.applicationContext
        val receivedIntent = Intent(intent)
        val requestTime = System.currentTimeMillis()
        val communicationCallback = buildCommunicationCallback(receivedIntent)
        try {
            RECEIVER_EXECUTOR.execute {
                try {
                    handleReceive(appContext, receivedIntent)
                    communicationCallback?.let { (operation, messageBody) ->
                        recordCommunicationCallback(
                            operation = operation,
                            messageBody = messageBody,
                            result = "回调处理完成",
                            requestTime = requestTime,
                        )
                    }
                } catch (error: Exception) {
                    communicationCallback?.let { (operation, messageBody) ->
                        recordCommunicationCallback(
                            operation = operation,
                            messageBody = messageBody,
                            result = "回调处理失败：${error::class.java.simpleName}",
                            requestTime = requestTime,
                        )
                    }
                    Log.e(
                        TAG,
                        "Terminal upgrade receiver failed: ${error::class.java.simpleName}",
                    )
                } finally {
                    pendingResult.finish()
                }
            }
        } catch (error: Exception) {
            communicationCallback?.let { (operation, messageBody) ->
                recordCommunicationCallback(
                    operation = operation,
                    messageBody = messageBody,
                    result = "回调调度失败：${error::class.java.simpleName}",
                    requestTime = requestTime,
                )
            }
            Log.e(
                TAG,
                "Unable to dispatch terminal upgrade receiver: ${error::class.java.simpleName}",
            )
            pendingResult.finish()
        }
    }

    /**
     * 把系统 Intent 收敛为不含 job、session、包名或版本标识的通讯摘要。
     * 未知 action 不进入管理员通讯日志，避免把其它广播字段误当成安装协议公开。
     */
    private fun buildCommunicationCallback(
        intent: Intent,
    ): Pair<String, Map<String, Any?>>? {
        return when (intent.action) {
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                "应用包替换回调" to mapOf("callback" to "package_replaced")
            }
            TerminalUpgradeInstaller.ACTION_CONFIRMATION_TIMEOUT -> {
                "安装确认超时回调" to mapOf("callback" to "confirmation_timeout")
            }
            TerminalUpgradeInstaller.ACTION_INSTALL_STATUS -> {
                val installerStatus = intent.getIntExtra(
                    PackageInstaller.EXTRA_STATUS,
                    PackageInstaller.STATUS_FAILURE,
                )
                "安装状态回调" to mapOf(
                    "callback" to "install_status",
                    "installerStatus" to installerStatus,
                )
            }
            else -> null
        }
    }

    /** 记录一条 PackageInstaller 侧下发回调，不参与安装状态机和错误日志上传。 */
    private fun recordCommunicationCallback(
        operation: String,
        messageBody: Map<String, Any?>,
        result: String,
        requestTime: Long,
    ) {
        NativeCommunicationLogStore.tryRecord(
            targetType = NativeCommunicationTargetType.HARDWARE,
            direction = NativeCommunicationDirection.INBOUND,
            channel = "PackageInstaller",
            operation = operation,
            messageBody = messageBody,
            result = result,
            requestTimeEpochMs = requestTime,
        )
    }

    /** 区分系统包替换、确认超时和安装回调，关联当前任务后再更新持久化状态。 */
    private fun handleReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            runCatching {
                TerminalUpgradeInstaller(context).reconcileAfterPackageReplaced()
            }.onFailure { error ->
                Log.e(
                    TAG,
                    "Unable to reconcile upgrade after package replacement: ${error::class.java.simpleName}",
                )
            }
            relaunchCabinet(context)
            return
        }
        if (intent.action == TerminalUpgradeInstaller.ACTION_CONFIRMATION_TIMEOUT) {
            val jobId = intent.getStringExtra(TerminalUpgradeInstaller.EXTRA_JOB_ID).orEmpty()
            val sessionId = intent.getIntExtra(
                TerminalUpgradeInstaller.EXTRA_EXPECTED_SESSION_ID,
                -1,
            )
            runCatching {
                TerminalUpgradeInstaller(context).reconcileConfirmationTimeout(jobId, sessionId)
            }.onFailure { error ->
                Log.e(
                    TAG,
                    "Unable to reconcile confirmation timeout: ${error::class.java.simpleName}",
                )
            }
            return
        }
        if (intent.action != TerminalUpgradeInstaller.ACTION_INSTALL_STATUS) {
            return
        }

        val installerStatus = intent.getIntExtra(
            PackageInstaller.EXTRA_STATUS,
            PackageInstaller.STATUS_FAILURE,
        )
        val jobId = intent.getStringExtra(TerminalUpgradeInstaller.EXTRA_JOB_ID).orEmpty()
        val packageName = intent.getStringExtra(
            TerminalUpgradeInstaller.EXTRA_TARGET_PACKAGE,
        ).orEmpty()
        val versionName = intent.getStringExtra(
            TerminalUpgradeInstaller.EXTRA_TARGET_VERSION_NAME,
        ).orEmpty()
        val versionCode = intent.getLongExtra(
            TerminalUpgradeInstaller.EXTRA_TARGET_VERSION_CODE,
            0L,
        )
        val sessionId = intent.getIntExtra(
            PackageInstaller.EXTRA_SESSION_ID,
            intent.getIntExtra(TerminalUpgradeInstaller.EXTRA_EXPECTED_SESSION_ID, -1),
        )
        val store = TerminalUpgradeStatusStore(context)
        val current = store.readStatus()
        if (current == null ||
            jobId.isBlank() ||
            current.jobId != jobId ||
            current.sessionId != sessionId ||
            current.packageName != packageName ||
            current.versionName != versionName ||
            current.versionCode != versionCode
        ) {
            Log.w(
                TAG,
                "Ignore stale install callback: jobId=$jobId sessionId=$sessionId package=$packageName versionCode=$versionCode",
            )
            return
        }

        when (installerStatus) {
            PackageInstaller.STATUS_SUCCESS -> {
                val systemPackageName = intent.getStringExtra(
                    PackageInstaller.EXTRA_PACKAGE_NAME,
                ).orEmpty()
                // 自定义 extras 由 Mutable PendingIntent 携带，不能单独作为成功证据；
                // 还要核对系统报告的包名和 PackageManager 当前精确版本。
                val targetInstalled = systemPackageName == packageName &&
                    TerminalUpgradeInstaller(context).isRecordedTargetInstalled(current)
                saveCallbackStatus(
                    context = context,
                    store = store,
                    current = current,
                    status = buildStatus(
                        jobId = jobId,
                        status = if (targetInstalled) {
                            TerminalUpgradeInstaller.STATUS_SUCCESS
                        } else {
                            TerminalUpgradeInstaller.STATUS_FAILURE
                        },
                        message = if (targetInstalled) {
                            "升级安装成功，并已确认目标包与版本"
                        } else {
                            "系统报告安装成功，但实际包名或版本与目标不一致"
                        },
                        packageName = packageName,
                        targetVersion = current.targetVersion,
                        versionName = versionName,
                        versionCode = versionCode,
                        sessionId = sessionId,
                        installerStatus = installerStatus,
                        silentInstallRequested = current.silentInstallRequested,
                        diagnosticCode = if (targetInstalled) {
                            TerminalUpgradeInstaller.DIAGNOSTIC_NONE
                        } else {
                            TerminalUpgradeInstaller.DIAGNOSTIC_VALIDATION_FAILED
                        },
                    ),
                )
            }

            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                val confirmationIntent = readConfirmationIntent(intent)
                val pendingMessage = "等待用户确认安装"
                val now = System.currentTimeMillis()
                val pendingStartedAt = if (
                    current.status == TerminalUpgradeInstaller.STATUS_PENDING_USER_ACTION
                ) {
                    current.updatedAtEpochMs
                } else {
                    now
                }
                val elapsedPendingMs = (now - pendingStartedAt).coerceAtLeast(0L)
                val remainingTimeoutMs =
                    (TerminalUpgradeInstaller.CONFIRMATION_TIMEOUT_MS - elapsedPendingMs)
                        .coerceAtLeast(1L)
                // 先注册超时 Alarm，再原子保存 pending；即使进程在落盘后立即终止，也不会
                // 留下没有唤醒源的永久 pending。重复回调沿用首次时间，不能延长 15 分钟门禁。
                val timeoutScheduled = TerminalUpgradeConfirmationTimeoutScheduler.schedule(
                    context = context,
                    jobId = jobId,
                    sessionId = sessionId,
                    delayMs = remainingTimeoutMs,
                )
                val pendingSaved = saveCallbackStatus(
                    context = context,
                    store = store,
                    current = current,
                    status = buildStatus(
                        jobId = jobId,
                        status = TerminalUpgradeInstaller.STATUS_PENDING_USER_ACTION,
                        message = if (timeoutScheduled) {
                            pendingMessage
                        } else {
                            "$pendingMessage；超时恢复调度失败，请联系运维人员"
                        },
                        packageName = packageName,
                        targetVersion = current.targetVersion,
                        versionName = versionName,
                        versionCode = versionCode,
                        sessionId = sessionId,
                        installerStatus = installerStatus,
                        silentInstallRequested = current.silentInstallRequested,
                        requiresUserAction = true,
                        confirmationLaunchFailed = current.confirmationLaunchFailed,
                        diagnosticCode = if (!timeoutScheduled) {
                            TerminalUpgradeInstaller
                                .DIAGNOSTIC_CONFIRMATION_RECOVERY_SCHEDULE_FAILED
                        } else if (current.confirmationLaunchFailed) {
                            current.diagnosticCode
                        } else {
                            TerminalUpgradeInstaller.DIAGNOSTIC_CONFIRMATION_REQUIRED
                        },
                        updatedAtEpochMs = pendingStartedAt,
                    ),
                )
                if (!pendingSaved) {
                    if (timeoutScheduled) {
                        TerminalUpgradeConfirmationTimeoutScheduler.cancel(
                            context,
                            jobId,
                            sessionId,
                        )
                    }
                    return
                }
                val launchError = confirmationIntent?.let { confirmation ->
                    confirmation.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    runCatching { context.startActivity(confirmation) }.exceptionOrNull()
                } ?: IllegalStateException("系统未返回安装确认页面")
                if (launchError != null) {
                    val recoveryMessage = if (timeoutScheduled) {
                        "$pendingMessage；确认页面启动失败，将在超时后自动恢复"
                    } else {
                        "$pendingMessage；确认页面启动失败，且超时恢复调度失败，请联系运维人员"
                    }
                    store.saveIfCurrent(
                        expectedJobId = jobId,
                        expectedSessionId = sessionId,
                        expectedStatuses = setOf(
                            TerminalUpgradeInstaller.STATUS_PENDING_USER_ACTION,
                        ),
                        status = buildStatus(
                            jobId = jobId,
                            status = TerminalUpgradeInstaller.STATUS_PENDING_USER_ACTION,
                            message = recoveryMessage,
                            packageName = packageName,
                            targetVersion = current.targetVersion,
                            versionName = versionName,
                            versionCode = versionCode,
                            sessionId = sessionId,
                            installerStatus = installerStatus,
                            silentInstallRequested = current.silentInstallRequested,
                            requiresUserAction = true,
                            confirmationLaunchFailed = true,
                            diagnosticCode = if (!timeoutScheduled) {
                                TerminalUpgradeInstaller
                                    .DIAGNOSTIC_CONFIRMATION_RECOVERY_SCHEDULE_FAILED
                            } else {
                                TerminalUpgradeInstaller.DIAGNOSTIC_CONFIRMATION_LAUNCH_FAILED
                            },
                            updatedAtEpochMs = pendingStartedAt,
                        ),
                    )
                    Log.e(
                        TAG,
                        "Unable to open package installer confirmation: " +
                            launchError::class.java.simpleName,
                    )
                }
            }

            else -> saveCallbackStatus(
                context = context,
                store = store,
                current = current,
                status = buildStatus(
                    jobId = jobId,
                    status = TerminalUpgradeInstaller.STATUS_FAILURE,
                    message = "系统安装失败，状态码：$installerStatus",
                    packageName = packageName,
                    targetVersion = current.targetVersion,
                    versionName = versionName,
                    versionCode = versionCode,
                    sessionId = sessionId,
                    installerStatus = installerStatus,
                    silentInstallRequested = current.silentInstallRequested,
                    diagnosticCode = TerminalUpgradeInstaller.DIAGNOSTIC_INSTALLER_FAILURE,
                ),
            )
        }
    }

    /** 从不同 Android 版本的 PackageInstaller 回调中读取确认页 Intent。 */
    private fun readConfirmationIntent(intent: Intent): Intent? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_INTENT)
        }
    }

    /** 应用被自身新版本替换后尝试恢复主界面；后台启动限制失败时交给现场 watchdog。 */
    private fun relaunchCabinet(context: Context) {
        val launchIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
        if (launchIntent == null) {
            Log.e(TAG, "Unable to find cabinet launch activity after package replacement")
            return
        }
        launchIntent.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED,
        )
        runCatching { context.startActivity(launchIntent) }
            .onFailure { error ->
                Log.e(
                    TAG,
                    "Unable to relaunch cabinet after package replacement: " +
                        error::class.java.simpleName,
                )
            }
    }

    /** 统一补齐一次 PackageInstaller 回调对应的持久化状态。 */
    private fun buildStatus(
        jobId: String,
        status: String,
        message: String,
        packageName: String,
        targetVersion: String,
        versionName: String,
        versionCode: Long,
        sessionId: Int,
        installerStatus: Int,
        silentInstallRequested: Boolean = false,
        requiresUserAction: Boolean = false,
        confirmationLaunchFailed: Boolean = false,
        diagnosticCode: String = TerminalUpgradeInstaller.DIAGNOSTIC_NONE,
        updatedAtEpochMs: Long = System.currentTimeMillis(),
    ): TerminalUpgradeInstallStatus {
        return TerminalUpgradeInstallStatus(
            jobId = jobId,
            status = status,
            message = message,
            packageName = packageName,
            targetVersion = targetVersion,
            versionName = versionName,
            versionCode = versionCode,
            sessionId = sessionId,
            installerStatus = installerStatus,
            silentInstallRequested = silentInstallRequested,
            requiresUserAction = requiresUserAction,
            confirmationLaunchFailed = confirmationLaunchFailed,
            diagnosticCode = diagnosticCode,
            updatedAtEpochMs = updatedAtEpochMs,
        )
    }

    /** 仅在当前任务仍处于非终态时保存系统回调，避免迟到结果覆盖新任务。 */
    private fun saveCallbackStatus(
        context: Context,
        store: TerminalUpgradeStatusStore,
        current: TerminalUpgradeInstallStatus,
        status: TerminalUpgradeInstallStatus,
    ): Boolean {
        val saved = store.saveIfCurrent(
            expectedJobId = current.jobId,
            expectedSessionId = current.sessionId,
            expectedStatuses = TerminalUpgradeInstaller.ACTIVE_INSTALL_STATUSES,
            status = status,
        )
        if (!saved) {
            Log.w(
                TAG,
                "Ignore install callback after state changed: jobId=${current.jobId} sessionId=${current.sessionId}",
            )
        } else if (status.status != TerminalUpgradeInstaller.STATUS_PENDING_USER_ACTION) {
            TerminalUpgradeConfirmationTimeoutScheduler.cancel(
                context,
                status.jobId,
                status.sessionId,
            )
        }
        return saved
    }

    private companion object {
        const val TAG = "SmartCabinetUpgrade"
        val RECEIVER_EXECUTOR = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "smart-cabinet-upgrade-receiver").apply { isDaemon = true }
        }
    }
}

/**
 * 用系统 Alarm 驱动等待确认的超时恢复，进程被杀或页面不再轮询时仍能唤醒显式 Receiver。
 * 采用 inexact alarm，避免 Android 12+ 精确闹钟权限；触发可能晚于、但不会早于超时阈值。
 */
internal object TerminalUpgradeConfirmationTimeoutScheduler {
    /** 为同一 job/session 安排剩余等待时间，重复调用会更新而不会创建平行 Alarm。 */
    fun schedule(
        context: Context,
        jobId: String,
        sessionId: Int,
        delayMs: Long = TerminalUpgradeInstaller.CONFIRMATION_TIMEOUT_MS,
    ): Boolean {
        if (jobId.isBlank() || sessionId < 0) {
            return false
        }
        return runCatching {
            val alarmManager = context.applicationContext.getSystemService(
                Context.ALARM_SERVICE,
            ) as AlarmManager
            val pendingIntent = timeoutPendingIntent(
                context = context.applicationContext,
                jobId = jobId,
                sessionId = sessionId,
                flags = PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag(),
            ) ?: throw IllegalStateException("Unable to create confirmation timeout PendingIntent")
            val triggerAt = SystemClock.elapsedRealtime() + delayMs.coerceAtLeast(1L)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    triggerAt,
                    pendingIntent,
                )
            } else {
                alarmManager.set(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    triggerAt,
                    pendingIntent,
                )
            }
        }.onFailure { error ->
            Log.e(
                TAG,
                "Unable to schedule confirmation timeout: ${error::class.java.simpleName}",
            )
        }.isSuccess
    }

    /** 只取消由同一 job/session 唯一 data URI 创建的确认超时 Alarm。 */
    fun cancel(context: Context, jobId: String, sessionId: Int) {
        if (jobId.isBlank() || sessionId < 0) {
            return
        }
        runCatching {
            val appContext = context.applicationContext
            val pendingIntent = timeoutPendingIntent(
                context = appContext,
                jobId = jobId,
                sessionId = sessionId,
                flags = PendingIntent.FLAG_NO_CREATE or immutableFlag(),
            )
            if (pendingIntent != null) {
                val alarmManager = appContext.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                alarmManager.cancel(pendingIntent)
                pendingIntent.cancel()
            }
        }.onFailure { error ->
            Log.w(
                TAG,
                "Unable to cancel confirmation timeout: ${error::class.java.simpleName}",
            )
        }
    }

    /** 构造身份包含 jobId 与 sessionId 的不可变显式超时广播。 */
    private fun timeoutPendingIntent(
        context: Context,
        jobId: String,
        sessionId: Int,
        flags: Int,
    ): PendingIntent? {
        val timeoutIntent = Intent(context, TerminalUpgradeInstallReceiver::class.java).apply {
            action = TerminalUpgradeInstaller.ACTION_CONFIRMATION_TIMEOUT
            setPackage(context.packageName)
            data = Uri.Builder()
                .scheme("smartcabinet")
                .authority("upgrade-confirmation-timeout")
                .appendPath(jobId)
                .appendPath(sessionId.toString())
                .build()
            putExtra(TerminalUpgradeInstaller.EXTRA_JOB_ID, jobId)
            putExtra(TerminalUpgradeInstaller.EXTRA_EXPECTED_SESSION_ID, sessionId)
        }
        return PendingIntent.getBroadcast(context, sessionId, timeoutIntent, flags)
    }

    /** Android M+ 显式声明 Alarm PendingIntent 不允许系统或其它调用方改写。 */
    private fun immutableFlag(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE
        } else {
            0
        }
    }

    private const val TAG = "SmartCabinetUpgrade"
}
