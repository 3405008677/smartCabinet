package com.example.smart_cabinet.upgrade

import android.app.PendingIntent
import android.app.admin.DevicePolicyManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.util.Log
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.security.MessageDigest

/** 可安全返回给 Flutter 或持久化展示的升级异常；message 不得包含本地路径。 */
internal class TerminalUpgradeException(
    message: String,
    cause: Throwable? = null,
) : Exception(message, cause)

/** 把未知平台异常收敛为不包含路径、Intent 或系统内部细节的公开文案。 */
internal fun terminalUpgradePublicMessage(error: Throwable): String {
    return (error as? TerminalUpgradeException)?.message
        ?: "升级原生能力执行失败，请查看设备日志"
}

/** 保留已脱敏业务异常，其它平台异常统一映射为不含路径的稳定失败说明。 */
private fun normalizedUpgradeException(
    error: Exception,
    fallbackMessage: String,
): TerminalUpgradeException {
    return error as? TerminalUpgradeException
        ?: TerminalUpgradeException(fallbackMessage, error)
}

/**
 * 校验并提交智能终端 APK 升级。
 *
 * 安装器只持有 Application Context，避免升级提交期间因 [android.app.Activity]
 * 销毁而泄漏页面。耗时的 APK 读取与 Session 写入由调用方放到后台线程执行。
 */
class TerminalUpgradeInstaller(context: Context) {
    private val appContext = context.applicationContext
    private val packageManager = appContext.packageManager
    private val packageInstaller = packageManager.packageInstaller
    private val statusStore = TerminalUpgradeStatusStore(appContext)

    /** 读取当前已安装应用的真实包名、版本名和版本号。 */
    fun getAppVersion(): Map<String, Any> {
        val packageInfo = getInstalledPackageInfo(signingCertificates = false)
        return linkedMapOf(
            "packageName" to packageInfo.packageName,
            "versionName" to packageInfo.versionName.orEmpty(),
            "versionCode" to packageInfo.compatLongVersionCode(),
        )
    }

    /** 读取最近一次升级安装提交或系统回调状态。 */
    fun getInstallStatus(): Map<String, Any?> {
        reconcileStaleInstallStatus()
        return statusStore.read()
    }

    /**
     * 校验本地 APK 后写入 [PackageInstaller.Session] 并提交安装。
     *
     * 返回值只表示安装请求已经交给系统；最终成功、失败或需要用户确认的状态由
     * [TerminalUpgradeInstallReceiver] 与进程重启后的状态对账共同写入独立状态存储。
     */
    fun installApk(
        apkPath: String,
        expectedTargetVersion: String,
        operationId: String,
    ): Map<String, Any> {
        val normalizedTargetVersion = TerminalUpgradeVersionPolicy.normalizeExpected(
            expectedTargetVersion,
        )
        if (normalizedTargetVersion.isEmpty()) {
            throw TerminalUpgradeException("目标版本不能为空")
        }
        val jobId = normalizeOperationId(operationId)
        var candidate: ValidatedUpgradeApk? = null
        return try {
            synchronized(INSTALL_REQUEST_LOCK) {
                throwIfOperationCancelled(jobId)
                ensureNoActiveInstall()
                statusStore.save(
                    TerminalUpgradeInstallStatus(
                        jobId = jobId,
                        status = STATUS_VALIDATING,
                        message = "正在校验升级包",
                        targetVersion = normalizedTargetVersion,
                    ),
                )
            }
            val validated = validateUpgradeApk(jobId, apkPath, normalizedTargetVersion)
            candidate = validated
            submitInstallSession(jobId, validated)
        } catch (error: Exception) {
            val normalized = normalizedUpgradeException(error, "升级包校验或安装提交失败")
            runCatching {
                statusStore.saveIfCurrent(
                    expectedJobId = jobId,
                    expectedSessionId = -1,
                    expectedStatuses = setOf(STATUS_VALIDATING),
                    status = TerminalUpgradeInstallStatus(
                        jobId = jobId,
                        status = STATUS_FAILURE,
                        message = normalized.message.orEmpty(),
                        targetVersion = normalizedTargetVersion,
                        diagnosticCode = if (candidate == null) {
                            DIAGNOSTIC_VALIDATION_FAILED
                        } else {
                            DIAGNOSTIC_SESSION_SUBMISSION_FAILED
                        },
                    ),
                )
            }
            throw normalized
        } finally {
            candidate?.file?.let(::deletePrivateSnapshot)
            finishInstallOperation(jobId)
        }
    }

    /**
     * 取消排队中或仍未执行 Session commit 的安装操作。
     *
     * 与最终 commit 共用 [INSTALL_REQUEST_LOCK]，因此返回 true 后同一 operation 不可能
     * 再跨过提交点；已经 commit 或已经结束的操作返回 false，只能继续等待系统终态。
     */
    fun cancelInstall(operationId: String): Boolean {
        val normalized = normalizeOperationId(operationId)
        return synchronized(INSTALL_REQUEST_LOCK) {
            if (normalized in COMMITTED_OPERATION_IDS ||
                normalized in FINISHED_OPERATION_IDS
            ) {
                false
            } else {
                CANCELLED_OPERATION_IDS.add(normalized)
                trimOperationHistory(CANCELLED_OPERATION_IDS)
                true
            }
        }
    }

    /** 拒绝仍在执行或刚提交的安装，防止多个 Session 的回调互相覆盖。 */
    private fun ensureNoActiveInstall() {
        reconcileStaleInstallStatus()
        val current = statusStore.readStatus()
        if (current != null && current.status in ACTIVE_INSTALL_STATUSES) {
            throw TerminalUpgradeException("已有升级安装任务正在执行")
        }
        resolveOrphanedUncommittedSessions()
    }

    /** 约束跨层 operation ID，避免空值、超长值或控制字符进入持久化状态。 */
    private fun normalizeOperationId(operationId: String): String {
        val normalized = operationId.trim()
        if (!OPERATION_ID_PATTERN.matches(normalized)) {
            throw TerminalUpgradeException("升级安装操作标识无效")
        }
        return normalized
    }

    /** 在每个可取消边界检查 stop、重配、dispose 或 Activity 销毁发出的取消标记。 */
    private fun throwIfOperationCancelled(operationId: String) {
        synchronized(INSTALL_REQUEST_LOCK) {
            if (operationId in CANCELLED_OPERATION_IDS) {
                throw TerminalUpgradeException("升级安装已在提交前取消")
            }
        }
    }

    /** 清理一次操作的临时取消状态，并保留有界完成历史隔离迟到取消。 */
    private fun finishInstallOperation(operationId: String) {
        synchronized(INSTALL_REQUEST_LOCK) {
            CANCELLED_OPERATION_IDS.remove(operationId)
            COMMITTED_OPERATION_IDS.remove(operationId)
            FINISHED_OPERATION_IDS.add(operationId)
            trimOperationHistory(FINISHED_OPERATION_IDS)
        }
    }

    /** 限制进程内迟到取消历史，Repository 同时只允许一个安装操作。 */
    private fun trimOperationHistory(operationIds: LinkedHashSet<String>) {
        while (operationIds.size > MAX_OPERATION_HISTORY) {
            val oldest = operationIds.firstOrNull() ?: return
            operationIds.remove(oldest)
        }
    }

    /** 应用自更新完成后立即按当前已安装包对账，避免等待普通陈旧状态宽限期。 */
    internal fun reconcileAfterPackageReplaced() {
        reconcileStaleInstallStatus(replacementObserved = true)
    }

    /**
     * 由超时 Alarm 精确关联仍在等待确认的任务，并立即执行恢复，不依赖页面轮询。
     * Alarm 先于 pending 落盘，因此也接受极小进程死亡窗口内仍停留在 submitted 的记录。
     */
    internal fun reconcileConfirmationTimeout(expectedJobId: String, expectedSessionId: Int) {
        val current = statusStore.readStatus() ?: return
        if (current.jobId != expectedJobId ||
            current.sessionId != expectedSessionId ||
            current.status !in setOf(STATUS_SUBMITTED, STATUS_PENDING_USER_ACTION)
        ) {
            return
        }
        val sessionInfo = try {
            packageInstaller.getSessionInfo(current.sessionId)
        } catch (error: Exception) {
            Log.w(TAG, "Unable to inspect timed-out confirmation session")
            val rescheduled = TerminalUpgradeConfirmationTimeoutScheduler.schedule(
                appContext,
                current.jobId,
                current.sessionId,
            )
            if (!rescheduled) {
                statusStore.saveIfCurrent(
                    expectedJobId = current.jobId,
                    expectedSessionId = current.sessionId,
                    expectedStatuses = setOf(current.status),
                    status = current.copy(
                        message = "安装确认超时检查失败，且无法重新调度恢复，请联系运维人员",
                        diagnosticCode = DIAGNOSTIC_CONFIRMATION_RECOVERY_SCHEDULE_FAILED,
                        updatedAtEpochMs = current.updatedAtEpochMs,
                    ),
                )
            }
            return
        }
        reconcilePendingUserAction(
            current = current,
            sessionInfo = sessionInfo,
            statusAgeMs = CONFIRMATION_TIMEOUT_MS,
        )
    }

    /**
     * 对账进程重启后遗留的非终态记录。
     *
     * 已安装版本达到目标时立即确认成功；仍有活动 Session 时继续等待；状态库记录已陈旧且
     * 长时间未提交的 Session 会在确认归本应用所有后 abandon。已提交但无结果、以及等待
     * 用户确认超时的 Session 也会安全取消并转为可诊断失败，避免永久阻塞下一次升级。
     */
    private fun reconcileStaleInstallStatus(replacementObserved: Boolean = false) {
        val current = statusStore.readStatus() ?: return
        if ((replacementObserved || current.status in ACTIVE_INSTALL_STATUSES) &&
            isRecordedTargetInstalled(current)
        ) {
            val reconciled = statusStore.saveIfCurrent(
                expectedJobId = current.jobId,
                expectedSessionId = current.sessionId,
                expectedStatuses = if (replacementObserved) {
                    setOf(current.status)
                } else {
                    ACTIVE_INSTALL_STATUSES
                },
                status = current.copy(
                    status = STATUS_SUCCESS,
                    message = if (replacementObserved) {
                        "应用已替换，并确认目标版本安装成功"
                    } else {
                        "已根据当前应用版本确认升级安装成功"
                    },
                    installerStatus = PackageInstaller.STATUS_SUCCESS,
                    requiresUserAction = false,
                    confirmationLaunchFailed = false,
                    diagnosticCode = DIAGNOSTIC_NONE,
                    updatedAtEpochMs = System.currentTimeMillis(),
                ),
            )
            if (reconciled) {
                TerminalUpgradeConfirmationTimeoutScheduler.cancel(
                    appContext,
                    current.jobId,
                    current.sessionId,
                )
            }
            return
        }
        if (current.status !in ACTIVE_INSTALL_STATUSES) {
            return
        }

        val now = System.currentTimeMillis()
        val statusAgeMs = elapsedSince(current.updatedAtEpochMs, now)
        if (current.status == STATUS_VALIDATING && current.sessionId < 0) {
            if (statusAgeMs >= ACTIVE_STATUS_GRACE_PERIOD_MS) {
                saveReconciledFailure(
                    current = current,
                    message = "升级包校验任务已超时，请重新发起升级",
                    diagnosticCode = DIAGNOSTIC_VALIDATION_FAILED,
                )
            }
            return
        }

        val sessionInfo = try {
            if (current.sessionId >= 0) {
                packageInstaller.getSessionInfo(current.sessionId)
            } else {
                null
            }
        } catch (error: Exception) {
            Log.w(TAG, "Unable to inspect terminal upgrade PackageInstaller session")
            return
        }

        if (current.status == STATUS_PENDING_USER_ACTION) {
            reconcilePendingUserAction(current, sessionInfo, statusAgeMs)
            return
        }

        if (sessionInfo == null) {
            if (statusAgeMs >= ACTIVE_STATUS_GRACE_PERIOD_MS) {
                saveReconciledFailure(
                    current = current,
                    message = "系统安装会话已失效，且目标版本尚未安装",
                    diagnosticCode = DIAGNOSTIC_SESSION_MISSING,
                )
            }
            return
        }
        if (sessionInfo.isActive) {
            return
        }

        val sessionUpdatedAt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            maxOf(current.updatedAtEpochMs, sessionInfo.updatedMillis)
        } else {
            current.updatedAtEpochMs
        }
        val sessionAgeMs = elapsedSince(sessionUpdatedAt, now)
        val committed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            sessionInfo.isCommitted
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // API 26-28 无 isCommitted，但 commit 会 seal Session，可据此识别仍可写入的会话。
            sessionInfo.isSealed
        } else {
            // API 21-25 连 isSealed 也不可用；submitting 明确尚未提交，其余采用更长超时。
            current.status != STATUS_SUBMITTING
        }
        if (!committed && sessionAgeMs >= ACTIVE_STATUS_GRACE_PERIOD_MS) {
            recoverTimedOutSession(
                current = current,
                message = "检测到陈旧且未提交的安装会话，已取消，请重新发起升级",
                diagnosticCode = DIAGNOSTIC_STALE_UNCOMMITTED_SESSION,
            )
            return
        }
        if (committed && sessionAgeMs >= COMMITTED_SESSION_TIMEOUT_MS) {
            recoverTimedOutSession(
                current = current,
                message = "系统安装会话长时间没有结果，已取消，请重新发起升级",
                diagnosticCode = DIAGNOSTIC_STALE_COMMITTED_SESSION,
            )
        }
    }

    /** 当前包名、versionCode 与 versionName 必须精确对应本次已校验目标。 */
    internal fun isRecordedTargetInstalled(current: TerminalUpgradeInstallStatus): Boolean {
        if (current.packageName != appContext.packageName) {
            return false
        }
        if (current.versionCode <= 0L) {
            return false
        }
        val installed = try {
            getInstalledPackageInfo(signingCertificates = false)
        } catch (error: Exception) {
            Log.w(TAG, "Unable to inspect installed version during upgrade reconciliation")
            return false
        }
        return TerminalUpgradeVersionPolicy.matchesInstalledTarget(
            expectedVersionName = current.versionName,
            expectedVersionCode = current.versionCode,
            actualVersionName = installed.versionName.orEmpty(),
            actualVersionCode = installed.compatLongVersionCode(),
        )
    }

    /** 等待系统确认超过阈值后安全 abandon；即使系统仍标记 active，也不能永久阻塞后续升级。 */
    private fun reconcilePendingUserAction(
        current: TerminalUpgradeInstallStatus,
        sessionInfo: PackageInstaller.SessionInfo?,
        statusAgeMs: Long,
    ) {
        if (statusAgeMs < CONFIRMATION_TIMEOUT_MS) {
            val scheduled = TerminalUpgradeConfirmationTimeoutScheduler.schedule(
                context = appContext,
                jobId = current.jobId,
                sessionId = current.sessionId,
                delayMs = CONFIRMATION_TIMEOUT_MS - statusAgeMs,
            )
            val recoveredScheduler = scheduled &&
                current.diagnosticCode == DIAGNOSTIC_CONFIRMATION_RECOVERY_SCHEDULE_FAILED
            if (!scheduled || recoveredScheduler) {
                statusStore.saveIfCurrent(
                    expectedJobId = current.jobId,
                    expectedSessionId = current.sessionId,
                    expectedStatuses = setOf(current.status),
                    status = current.copy(
                        message = when {
                            !scheduled ->
                                "等待用户确认安装；超时恢复调度失败，请联系运维人员"
                            current.confirmationLaunchFailed ->
                                "等待用户确认安装；确认页面启动失败，将在超时后自动恢复"
                            else -> "等待用户确认安装"
                        },
                        diagnosticCode = when {
                            !scheduled -> DIAGNOSTIC_CONFIRMATION_RECOVERY_SCHEDULE_FAILED
                            current.confirmationLaunchFailed ->
                                DIAGNOSTIC_CONFIRMATION_LAUNCH_FAILED
                            else -> DIAGNOSTIC_CONFIRMATION_REQUIRED
                        },
                        updatedAtEpochMs = current.updatedAtEpochMs,
                    ),
                )
            }
            return
        }
        if (sessionInfo == null || abandonOwnedSession(current.sessionId)) {
            saveReconciledFailure(
                current = current,
                message = "安装确认等待超时，系统会话已取消，请重新发起升级",
                diagnosticCode = DIAGNOSTIC_CONFIRMATION_TIMEOUT,
                confirmationLaunchFailed = current.confirmationLaunchFailed,
            )
            return
        }
        val retryScheduled = TerminalUpgradeConfirmationTimeoutScheduler.schedule(
            appContext,
            current.jobId,
            current.sessionId,
        )
        val retained = statusStore.saveIfCurrent(
            expectedJobId = current.jobId,
            expectedSessionId = current.sessionId,
            expectedStatuses = setOf(current.status),
            status = current.copy(
                message = if (retryScheduled) {
                    "安装确认已超时，但无法安全取消系统会话，将继续重试恢复"
                } else {
                    "安装确认已超时，且无法安全取消或重新调度恢复，请联系运维人员"
                },
                diagnosticCode = if (retryScheduled) {
                    DIAGNOSTIC_CONFIRMATION_TIMEOUT
                } else {
                    DIAGNOSTIC_CONFIRMATION_RECOVERY_SCHEDULE_FAILED
                },
                // 保留原时间戳，使下一次状态刷新继续尝试安全恢复。
                updatedAtEpochMs = current.updatedAtEpochMs,
            ),
        )
        if (!retained && retryScheduled) {
            TerminalUpgradeConfirmationTimeoutScheduler.cancel(
                appContext,
                current.jobId,
                current.sessionId,
            )
        }
    }

    /**
     * 回收状态库未记录、且本应用拥有的陈旧未提交 Session。
     *
     * `createSession` 与首次持久化 sessionId 之间若进程终止，系统会留下孤儿 Session。
     * 这里只处理目标为本应用且尚未 commit/seal 的会话；仍 active 或位于 API 29+
     * 十分钟宽限期内的会话会阻止新安装，避免极端多进程调度下误取消刚创建的会话。
     */
    private fun resolveOrphanedUncommittedSessions() {
        val now = System.currentTimeMillis()
        val ownedSelfSessions = try {
            packageInstaller.mySessions.filter { sessionInfo ->
                sessionInfo.appPackageName == appContext.packageName
            }
        } catch (error: Exception) {
            throw TerminalUpgradeException("无法检查系统遗留安装会话", error)
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O && ownedSelfSessions.isNotEmpty()) {
            // API 21-25 无公开 commit/seal 标记，不能在不确定状态下安全 abandon。
            throw TerminalUpgradeException("旧版系统存在未完成安装会话，无法安全确认提交状态")
        }
        val candidates = ownedSelfSessions.filter(::isSessionUncommitted)

        candidates.forEach { sessionInfo ->
            if (sessionInfo.isActive) {
                throw TerminalUpgradeException("检测到状态库未记录的活动安装会话，请稍后重试")
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val ageMs = elapsedSince(sessionInfo.updatedMillis, now)
                if (ageMs < ACTIVE_STATUS_GRACE_PERIOD_MS) {
                    throw TerminalUpgradeException("检测到尚在宽限期内的未提交安装会话，请稍后重试")
                }
            }
            if (!abandonOwnedSession(sessionInfo.sessionId)) {
                throw TerminalUpgradeException("检测到陈旧的未提交安装会话，但无法安全取消")
            }
        }
    }

    /** API 29+ 使用明确的 commit 标记；API 26-28 用 seal 状态区分仍可写入的 Session。 */
    private fun isSessionUncommitted(sessionInfo: PackageInstaller.SessionInfo): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            !sessionInfo.isCommitted
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            !sessionInfo.isSealed
        } else {
            false
        }
    }

    /** 只取消本应用拥有的 Session；若 Session 已自然消失也视为恢复成功。 */
    private fun abandonOwnedSession(sessionId: Int): Boolean {
        if (sessionId < 0) {
            return true
        }
        return try {
            val owned = packageInstaller.mySessions.any { it.sessionId == sessionId }
            if (!owned) {
                packageInstaller.getSessionInfo(sessionId) == null
            } else {
                packageInstaller.abandonSession(sessionId)
                true
            }
        } catch (error: Exception) {
            Log.w(TAG, "Unable to abandon owned terminal upgrade session")
            false
        }
    }

    /** 安全取消超时 Session，并仅在当前记录仍匹配时释放安装互斥。 */
    private fun recoverTimedOutSession(
        current: TerminalUpgradeInstallStatus,
        message: String,
        diagnosticCode: String,
    ) {
        if (abandonOwnedSession(current.sessionId)) {
            saveReconciledFailure(current, message, diagnosticCode)
            return
        }
        statusStore.saveIfCurrent(
            expectedJobId = current.jobId,
            expectedSessionId = current.sessionId,
            expectedStatuses = ACTIVE_INSTALL_STATUSES,
            status = current.copy(
                message = "检测到异常安装会话，但无法安全取消，请联系运维人员",
                diagnosticCode = diagnosticCode,
                updatedAtEpochMs = current.updatedAtEpochMs,
            ),
        )
    }

    /** 把当前非终态原子转为失败，允许后续重新发起升级。 */
    private fun saveReconciledFailure(
        current: TerminalUpgradeInstallStatus,
        message: String,
        diagnosticCode: String,
        confirmationLaunchFailed: Boolean = false,
    ) {
        val saved = statusStore.saveIfCurrent(
            expectedJobId = current.jobId,
            expectedSessionId = current.sessionId,
            expectedStatuses = ACTIVE_INSTALL_STATUSES,
            status = current.copy(
                status = STATUS_FAILURE,
                message = message,
                installerStatus = PackageInstaller.STATUS_FAILURE_ABORTED,
                requiresUserAction = false,
                confirmationLaunchFailed = confirmationLaunchFailed,
                diagnosticCode = diagnosticCode,
                updatedAtEpochMs = System.currentTimeMillis(),
            ),
        )
        if (saved) {
            TerminalUpgradeConfirmationTimeoutScheduler.cancel(
                appContext,
                current.jobId,
                current.sessionId,
            )
        }
    }

    private fun elapsedSince(timestamp: Long, now: Long): Long {
        return (now - timestamp).coerceAtLeast(0L)
    }

    /**
     * 把调用方文件固定为应用私有快照并记录摘要。
     *
     * 后续包信息解析和 Session 写入都只读取此快照；写入时再次计算摘要，避免路径文件在
     * 校验与提交之间被替换。进程异常退出遗留的快照会在下一次升级时按时间清理。
     */
    private fun createPrivateApkSnapshot(jobId: String, apkPath: String): PrivateApkSnapshot {
        val source = try {
            File(apkPath).canonicalFile
        } catch (error: Exception) {
            throw TerminalUpgradeException("无法读取升级包", error)
        }
        if (!source.isFile || !source.canRead() || source.length() <= 0L) {
            throw TerminalUpgradeException("升级包不存在、不可读或内容为空")
        }
        if (source.length() > MAX_APK_SIZE_BYTES) {
            throw TerminalUpgradeException("升级包超过允许的最大大小")
        }

        val stagingDirectory = File(appContext.noBackupFilesDir, PRIVATE_STAGING_DIRECTORY)
        if ((!stagingDirectory.exists() && !stagingDirectory.mkdirs()) ||
            !stagingDirectory.isDirectory
        ) {
            throw TerminalUpgradeException("无法创建升级包私有暂存目录")
        }
        cleanupExpiredPrivateSnapshots(stagingDirectory)

        val snapshotFile = File(stagingDirectory, "$jobId.apk")
        val digest = MessageDigest.getInstance("SHA-256")
        var copiedBytes = 0L
        try {
            FileInputStream(source).use { input ->
                FileOutputStream(snapshotFile, false).use { output ->
                    val buffer = ByteArray(COPY_BUFFER_SIZE)
                    while (true) {
                        throwIfOperationCancelled(jobId)
                        val count = input.read(buffer)
                        if (count < 0) {
                            break
                        }
                        if (count == 0) {
                            continue
                        }
                        if (copiedBytes + count > MAX_APK_SIZE_BYTES) {
                            throw TerminalUpgradeException("升级包超过允许的最大大小")
                        }
                        output.write(buffer, 0, count)
                        digest.update(buffer, 0, count)
                        copiedBytes += count
                    }
                    output.fd.sync()
                }
            }
        } catch (error: Exception) {
            snapshotFile.delete()
            throw normalizedUpgradeException(error, "无法固定升级包私有副本")
        }
        if (copiedBytes <= 0L) {
            snapshotFile.delete()
            throw TerminalUpgradeException("升级包内容为空")
        }

        // 目录本身仅本应用可访问；再移除文件写权限以减少同进程误改，提交时仍会复核摘要。
        snapshotFile.setReadable(true, true)
        snapshotFile.setWritable(false, false)
        return PrivateApkSnapshot(
            file = snapshotFile,
            sizeBytes = copiedBytes,
            sha256 = digest.digest(),
        )
    }

    /** 清理一天前的进程崩溃遗留快照，不触碰正在处理的新文件。 */
    private fun cleanupExpiredPrivateSnapshots(directory: File) {
        val cutoff = System.currentTimeMillis() - PRIVATE_SNAPSHOT_RETENTION_MS
        directory.listFiles()?.forEach { file ->
            val lastModified = file.lastModified()
            if (file.isFile && lastModified > 0L && lastModified < cutoff) {
                file.delete()
            }
        }
    }

    /** 删除已复制进 PackageInstaller 的私有快照；失败只记录类别，不记录本地路径。 */
    private fun deletePrivateSnapshot(file: File) {
        if (file.exists() && !file.delete()) {
            Log.w(TAG, "Unable to delete terminal upgrade private snapshot")
        }
    }

    /** 校验文件、协议目标版本、目标包名、签名证书和严格递增的 versionCode。 */
    private fun validateUpgradeApk(
        jobId: String,
        apkPath: String,
        expectedTargetVersion: String,
    ): ValidatedUpgradeApk {
        val snapshot = createPrivateApkSnapshot(jobId, apkPath)
        try {
            throwIfOperationCancelled(jobId)
            val archiveInfo = getArchivePackageInfo(snapshot.file)
                ?: throw TerminalUpgradeException("无法解析升级包，请确认文件是完整 APK")
            val archiveVersionName = archiveInfo.versionName.orEmpty()
            if (!TerminalUpgradeVersionPolicy.matchesApkVersionName(
                    expected = expectedTargetVersion,
                    actual = archiveVersionName,
                )
            ) {
                // 不把 APK 路径或版本值写入状态/MethodChannel 错误，避免泄露本地缓存信息。
                throw TerminalUpgradeException("升级包版本与服务端目标版本不一致")
            }
            val installedInfo = getInstalledPackageInfo(signingCertificates = true)
            if (archiveInfo.packageName != appContext.packageName) {
                throw TerminalUpgradeException("升级包包名与当前应用不一致")
            }

            val installedVersionCode = installedInfo.compatLongVersionCode()
            val targetVersionCode = archiveInfo.compatLongVersionCode()
            if (targetVersionCode <= installedVersionCode) {
                throw TerminalUpgradeException("升级包版本号必须严格高于当前版本")
            }

            if (!signaturesAreCompatible(installedInfo, archiveInfo)) {
                throw TerminalUpgradeException("升级包签名证书与当前应用不一致")
            }
            throwIfOperationCancelled(jobId)

            return ValidatedUpgradeApk(
                file = snapshot.file,
                sizeBytes = snapshot.sizeBytes,
                sha256 = snapshot.sha256,
                packageName = archiveInfo.packageName,
                targetVersion = expectedTargetVersion,
                versionName = archiveVersionName,
                versionCode = targetVersionCode,
            )
        } catch (error: Exception) {
            deletePrivateSnapshot(snapshot.file)
            throw normalizedUpgradeException(error, "升级包校验失败")
        }
    }

    /** 创建、写入并提交一个完整 APK 安装 Session。 */
    private fun submitInstallSession(
        jobId: String,
        candidate: ValidatedUpgradeApk,
    ): Map<String, Any> {
        throwIfOperationCancelled(jobId)
        val devicePolicyManager =
            appContext.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val isDeviceOwner = devicePolicyManager.isDeviceOwnerApp(appContext.packageName)
        val requestsSilentInstall = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S || isDeviceOwner
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL).apply {
            setAppPackageName(candidate.packageName)
            setSize(candidate.sizeBytes)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // UPDATE_PACKAGES_WITHOUT_USER_ACTION 只表示允许请求；系统不满足静默条件时
                // 仍会回调 STATUS_PENDING_USER_ACTION，由 Receiver 打开确认页。
                setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
            }
        }
        val sessionId = try {
            packageInstaller.createSession(params)
        } catch (error: Exception) {
            throw TerminalUpgradeException("无法创建系统安装会话", error)
        }

        try {
            val submittingRecorded = statusStore.saveIfCurrent(
                expectedJobId = jobId,
                expectedSessionId = -1,
                expectedStatuses = setOf(STATUS_VALIDATING),
                status = TerminalUpgradeInstallStatus(
                    jobId = jobId,
                    status = STATUS_SUBMITTING,
                    message = "正在向系统提交升级包",
                    packageName = candidate.packageName,
                    targetVersion = candidate.targetVersion,
                    versionName = candidate.versionName,
                    versionCode = candidate.versionCode,
                    sessionId = sessionId,
                    silentInstallRequested = requestsSilentInstall,
                ),
            )
            if (!submittingRecorded) {
                throw TerminalUpgradeException("升级任务状态已变化，已取消本次安装")
            }

            packageInstaller.openSession(sessionId).use { session ->
                writeVerifiedSnapshotToSession(session, candidate, jobId)
                throwIfOperationCancelled(jobId)
                // 必须在 commit 前记录 submitted；系统回调可能非常快，若 commit 后再写会把
                // Receiver 已保存的 success/failure 错误覆盖回 submitted。
                val submittedRecorded = statusStore.saveIfCurrent(
                    expectedJobId = jobId,
                    expectedSessionId = sessionId,
                    expectedStatuses = setOf(STATUS_SUBMITTING),
                    status = TerminalUpgradeInstallStatus(
                        jobId = jobId,
                        status = STATUS_SUBMITTED,
                        message = "升级包已提交，正在等待系统安装结果",
                        packageName = candidate.packageName,
                        targetVersion = candidate.targetVersion,
                        versionName = candidate.versionName,
                        versionCode = candidate.versionCode,
                        sessionId = sessionId,
                        silentInstallRequested = requestsSilentInstall,
                    ),
                )
                if (!submittedRecorded) {
                    throw TerminalUpgradeException("升级任务状态已变化，已取消本次安装")
                }
                // 取消与 commit 使用同一把锁，消除最后一次检查和不可逆提交之间的竞态。
                synchronized(INSTALL_REQUEST_LOCK) {
                    throwIfOperationCancelled(jobId)
                    session.commit(createStatusIntentSender(jobId, sessionId, candidate))
                    COMMITTED_OPERATION_IDS.add(jobId)
                    trimOperationHistory(COMMITTED_OPERATION_IDS)
                }
            }
        } catch (error: Exception) {
            val normalized = normalizedUpgradeException(error, "系统安装会话处理失败")
            val abandoned = abandonOwnedSession(sessionId)
            runCatching {
                statusStore.saveIfCurrent(
                    expectedJobId = jobId,
                    expectedSessionId = sessionId,
                    expectedStatuses = ACTIVE_INSTALL_STATUSES,
                    status = TerminalUpgradeInstallStatus(
                        jobId = jobId,
                        status = STATUS_FAILURE,
                        message = if (abandoned) {
                            normalized.message.orEmpty()
                        } else {
                            "系统安装会话处理失败，且未能安全取消会话"
                        },
                        packageName = candidate.packageName,
                        targetVersion = candidate.targetVersion,
                        versionName = candidate.versionName,
                        versionCode = candidate.versionCode,
                        sessionId = sessionId,
                        installerStatus = PackageInstaller.STATUS_FAILURE,
                        silentInstallRequested = requestsSilentInstall,
                        diagnosticCode = DIAGNOSTIC_SESSION_SUBMISSION_FAILED,
                    ),
                )
            }
            throw normalized
        }

        return linkedMapOf(
            "jobId" to jobId,
            "sessionId" to sessionId,
            "state" to STATUS_SUBMITTED,
            "status" to STATUS_SUBMITTED,
            "packageName" to candidate.packageName,
            "targetVersion" to candidate.targetVersion,
            "versionName" to candidate.versionName,
            "versionCode" to candidate.versionCode,
            "silentInstallRequested" to requestsSilentInstall,
            "requiresUserAction" to false,
        )
    }

    /** 写入私有快照并复核大小与 SHA-256；不一致时在 commit 前中止并 abandon Session。 */
    private fun writeVerifiedSnapshotToSession(
        session: PackageInstaller.Session,
        candidate: ValidatedUpgradeApk,
        operationId: String,
    ) {
        val digest = MessageDigest.getInstance("SHA-256")
        var copiedBytes = 0L
        try {
            FileInputStream(candidate.file).use { input ->
                session.openWrite(APK_SESSION_NAME, 0L, candidate.sizeBytes).use { output ->
                    val buffer = ByteArray(COPY_BUFFER_SIZE)
                    while (true) {
                        throwIfOperationCancelled(operationId)
                        val count = input.read(buffer)
                        if (count < 0) {
                            break
                        }
                        if (count == 0) {
                            continue
                        }
                        output.write(buffer, 0, count)
                        digest.update(buffer, 0, count)
                        copiedBytes += count
                    }
                    session.fsync(output)
                }
            }
        } catch (error: Exception) {
            throw TerminalUpgradeException("无法写入系统安装会话", error)
        }
        if (copiedBytes != candidate.sizeBytes ||
            !MessageDigest.isEqual(candidate.sha256, digest.digest())
        ) {
            throw TerminalUpgradeException("升级包在校验后发生变化，已取消安装")
        }
    }

    /** 创建显式安装结果广播，允许系统补充 PackageInstaller 状态字段。 */
    private fun createStatusIntentSender(
        jobId: String,
        sessionId: Int,
        candidate: ValidatedUpgradeApk,
    ): android.content.IntentSender {
        val statusIntent = Intent(appContext, TerminalUpgradeInstallReceiver::class.java).apply {
            action = ACTION_INSTALL_STATUS
            setPackage(appContext.packageName)
            // PendingIntent identity 不包含 extras；唯一 data 可防止 sessionId 复用时
            // FLAG_UPDATE_CURRENT 把旧 IntentSender 的 job/version 更新成新任务字段。
            data = Uri.Builder()
                .scheme("smartcabinet")
                .authority("upgrade-install-status")
                .appendPath(jobId)
                .appendPath(sessionId.toString())
                .build()
            putExtra(EXTRA_JOB_ID, jobId)
            putExtra(EXTRA_TARGET_PACKAGE, candidate.packageName)
            putExtra(EXTRA_TARGET_VERSION_NAME, candidate.versionName)
            putExtra(EXTRA_TARGET_VERSION_CODE, candidate.versionCode)
            putExtra(EXTRA_EXPECTED_SESSION_ID, sessionId)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
        return PendingIntent.getBroadcast(appContext, sessionId, statusIntent, flags).intentSender
    }

    /** 按当前 Android 版本读取已安装包信息。 */
    private fun getInstalledPackageInfo(signingCertificates: Boolean): PackageInfo {
        val flags = if (signingCertificates) signingInfoFlag() else 0
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageInfo(
                appContext.packageName,
                PackageManager.PackageInfoFlags.of(flags.toLong()),
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageInfo(appContext.packageName, flags)
        }
    }

    /** 按当前 Android 版本解析尚未安装的 APK 包信息。 */
    private fun getArchivePackageInfo(apkFile: File): PackageInfo? {
        val flags = signingInfoFlag()
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageArchiveInfo(
                apkFile.absolutePath,
                PackageManager.PackageInfoFlags.of(flags.toLong()),
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageArchiveInfo(apkFile.absolutePath, flags)
        }
    }

    /** 返回当前系统读取 APK 签名信息所需的 PackageManager 标记。 */
    private fun signingInfoFlag(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            @Suppress("DEPRECATION")
            PackageManager.GET_SIGNATURES
        }
    }

    /**
     * 校验当前签名一致性，并允许 Android P+ 单签名 APK 按 v3 证书谱系向前轮换。
     *
     * 多签名包仍要求当前 signer 集合完全相同；单签名包只接受候选证书历史包含当前
     * 已安装 signer 的方向，避免把已经轮换到新证书的应用回滚到旧证书。
     */
    private fun signaturesAreCompatible(installed: PackageInfo, candidate: PackageInfo): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            @Suppress("DEPRECATION")
            val installedSigners = digestSignatures(installed.signatures.orEmpty())
            @Suppress("DEPRECATION")
            val candidateSigners = digestSignatures(candidate.signatures.orEmpty())
            return installedSigners.isNotEmpty() && installedSigners == candidateSigners
        }

        val installedSigningInfo = installed.signingInfo ?: return false
        val candidateSigningInfo = candidate.signingInfo ?: return false
        val installedCurrent = digestSignatures(installedSigningInfo.apkContentsSigners.orEmpty())
        val candidateCurrent = digestSignatures(candidateSigningInfo.apkContentsSigners.orEmpty())
        if (installedCurrent.isEmpty() || candidateCurrent.isEmpty()) {
            return false
        }
        if (installedSigningInfo.hasMultipleSigners() || candidateSigningInfo.hasMultipleSigners()) {
            return installedCurrent == candidateCurrent
        }

        val candidateHistory = digestSignatures(
            candidateSigningInfo.signingCertificateHistory.orEmpty(),
        )
        val installedSigner = installedCurrent.singleOrNull() ?: return false
        return installedSigner in candidateHistory
    }

    /** 把签名证书转换成稳定的 SHA-256 摘要集合。 */
    private fun digestSignatures(
        signatures: Array<out android.content.pm.Signature>,
    ): Set<String> {
        return signatures.mapTo(linkedSetOf()) { signature ->
            MessageDigest.getInstance("SHA-256")
                .digest(signature.toByteArray())
                .joinToString(separator = "") { byte -> "%02X".format(byte) }
        }
    }

    /** 兼容读取 Android P 前后的长版本号。 */
    private fun PackageInfo.compatLongVersionCode(): Long {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            longVersionCode
        } else {
            @Suppress("DEPRECATION")
            versionCode.toLong()
        }
    }

    /** 已完成全部安装前校验的 APK 信息。 */
    private data class ValidatedUpgradeApk(
        val file: File,
        val sizeBytes: Long,
        val sha256: ByteArray,
        val packageName: String,
        val targetVersion: String,
        val versionName: String,
        val versionCode: Long,
    )

    /** 应用私有 APK 快照及其在固定时计算的完整性信息。 */
    private data class PrivateApkSnapshot(
        val file: File,
        val sizeBytes: Long,
        val sha256: ByteArray,
    )

    companion object {
        internal const val ACTION_INSTALL_STATUS =
            "com.example.smart_cabinet.action.TERMINAL_UPGRADE_INSTALL_STATUS"
        internal const val ACTION_CONFIRMATION_TIMEOUT =
            "com.example.smart_cabinet.action.TERMINAL_UPGRADE_CONFIRMATION_TIMEOUT"
        internal const val EXTRA_JOB_ID = "terminal_upgrade_job_id"
        internal const val EXTRA_TARGET_PACKAGE = "terminal_upgrade_target_package"
        internal const val EXTRA_TARGET_VERSION_NAME = "terminal_upgrade_target_version_name"
        internal const val EXTRA_TARGET_VERSION_CODE = "terminal_upgrade_target_version_code"
        internal const val EXTRA_EXPECTED_SESSION_ID = "terminal_upgrade_expected_session_id"

        internal const val STATUS_VALIDATING = "validating"
        internal const val STATUS_SUBMITTING = "submitting"
        internal const val STATUS_SUBMITTED = "submitted"
        internal const val STATUS_PENDING_USER_ACTION = "pending_user_action"
        internal const val STATUS_SUCCESS = "success"
        internal const val STATUS_FAILURE = "failed"

        internal const val DIAGNOSTIC_NONE = ""
        internal const val DIAGNOSTIC_VALIDATION_FAILED = "validation_failed"
        internal const val DIAGNOSTIC_SESSION_SUBMISSION_FAILED = "session_submission_failed"
        internal const val DIAGNOSTIC_SESSION_MISSING = "session_missing"
        internal const val DIAGNOSTIC_STALE_UNCOMMITTED_SESSION =
            "stale_uncommitted_session"
        internal const val DIAGNOSTIC_STALE_COMMITTED_SESSION = "stale_committed_session"
        internal const val DIAGNOSTIC_CONFIRMATION_REQUIRED = "confirmation_required"
        internal const val DIAGNOSTIC_CONFIRMATION_LAUNCH_FAILED =
            "confirmation_launch_failed"
        internal const val DIAGNOSTIC_CONFIRMATION_RECOVERY_SCHEDULE_FAILED =
            "confirmation_recovery_schedule_failed"
        internal const val DIAGNOSTIC_CONFIRMATION_TIMEOUT = "confirmation_timeout"
        internal const val DIAGNOSTIC_INSTALLER_FAILURE = "package_installer_failure"

        internal val ACTIVE_INSTALL_STATUSES = setOf(
            STATUS_VALIDATING,
            STATUS_SUBMITTING,
            STATUS_SUBMITTED,
            STATUS_PENDING_USER_ACTION,
        )

        private const val APK_SESSION_NAME = "base.apk"
        private const val PRIVATE_STAGING_DIRECTORY = "terminal_upgrade_staging"
        private const val COPY_BUFFER_SIZE = 64 * 1024
        // 与 Dart 下载层的 512 MiB 上限一致；原生边界仍独立复核，避免绕过上层耗尽磁盘。
        private const val MAX_APK_SIZE_BYTES = 512L * 1024 * 1024
        private const val PRIVATE_SNAPSHOT_RETENTION_MS = 24 * 60 * 60 * 1000L
        private const val ACTIVE_STATUS_GRACE_PERIOD_MS = 10 * 60 * 1000L
        private const val COMMITTED_SESSION_TIMEOUT_MS = 60 * 60 * 1000L
        internal const val CONFIRMATION_TIMEOUT_MS = 15 * 60 * 1000L
        private const val MAX_OPERATION_HISTORY = 64
        private const val TAG = "SmartCabinetUpgrade"
        private val OPERATION_ID_PATTERN = Regex("^[A-Za-z0-9._:-]{1,160}$")
        private val INSTALL_REQUEST_LOCK = Any()
        private val CANCELLED_OPERATION_IDS = linkedSetOf<String>()
        private val COMMITTED_OPERATION_IDS = linkedSetOf<String>()
        private val FINISHED_OPERATION_IDS = linkedSetOf<String>()
    }
}

/** 可持久化的最近一次 APK 安装状态。 */
internal data class TerminalUpgradeInstallStatus(
    val jobId: String,
    val status: String,
    val message: String,
    val packageName: String = "",
    val targetVersion: String = "",
    val versionName: String = "",
    val versionCode: Long = 0L,
    val sessionId: Int = -1,
    val installerStatus: Int = Int.MIN_VALUE,
    val silentInstallRequested: Boolean = false,
    val requiresUserAction: Boolean = false,
    val confirmationLaunchFailed: Boolean = false,
    val diagnosticCode: String = TerminalUpgradeInstaller.DIAGNOSTIC_NONE,
    val updatedAtEpochMs: Long = System.currentTimeMillis(),
)

/**
 * 使用独立 SharedPreferences 保存 PackageInstaller 最终状态。
 *
 * 该存储不改写 Flutter 的 app.localState，避免原生回调与 Dart 状态并发覆盖。
 */
internal class TerminalUpgradeStatusStore(context: Context) {
    private val preferences = context.applicationContext.getSharedPreferences(
        PREFERENCES_NAME,
        Context.MODE_PRIVATE,
    )

    /** 原子替换最近一次安装状态，清除上一任务遗留字段。 */
    fun save(status: TerminalUpgradeInstallStatus) {
        synchronized(STATUS_LOCK) {
            writeStatus(status)
        }
    }

    /** 读取完整的强类型状态，供安装互锁和 Receiver 回调关联校验。 */
    fun readStatus(): TerminalUpgradeInstallStatus? {
        return synchronized(STATUS_LOCK) { readStatusLocked() }
    }

    /** 仅当回调仍属于当前任务和允许的前置状态时写入，拒绝迟到的旧 Session 回调。 */
    fun saveIfCurrent(
        expectedJobId: String,
        expectedSessionId: Int,
        expectedStatuses: Set<String>,
        status: TerminalUpgradeInstallStatus,
    ): Boolean {
        return synchronized(STATUS_LOCK) {
            val current = readStatusLocked() ?: return@synchronized false
            if (current.jobId != expectedJobId ||
                current.sessionId != expectedSessionId ||
                current.status !in expectedStatuses
            ) {
                return@synchronized false
            }
            writeStatus(status)
            true
        }
    }

    /** 同步写入少量关键字段，并在存储失败时立即中止安装流程。 */
    private fun writeStatus(status: TerminalUpgradeInstallStatus) {
        val committed = preferences.edit()
            .clear()
            .putString(KEY_JOB_ID, status.jobId)
            .putString(KEY_STATUS, status.status)
            .putString(KEY_MESSAGE, status.message)
            .putString(KEY_PACKAGE_NAME, status.packageName)
            .putString(KEY_TARGET_VERSION, status.targetVersion)
            .putString(KEY_VERSION_NAME, status.versionName)
            .putLong(KEY_VERSION_CODE, status.versionCode)
            .putInt(KEY_SESSION_ID, status.sessionId)
            .putInt(KEY_INSTALLER_STATUS, status.installerStatus)
            .putBoolean(KEY_SILENT_INSTALL_REQUESTED, status.silentInstallRequested)
            .putBoolean(KEY_REQUIRES_USER_ACTION, status.requiresUserAction)
            .putBoolean(KEY_CONFIRMATION_LAUNCH_FAILED, status.confirmationLaunchFailed)
            .putString(KEY_DIAGNOSTIC_CODE, status.diagnosticCode)
            .putLong(KEY_UPDATED_AT, status.updatedAtEpochMs)
            // APK 更新可能紧接着终止当前进程，必须在返回前同步落盘，不能依赖 apply 的
            // 异步刷盘时机；该方法只写少量状态字段，且调用方已位于后台线程或 Receiver。
            .commit()
        if (!committed) {
            throw TerminalUpgradeException("升级安装状态持久化失败")
        }
    }

    /** 读取可由 Flutter MethodChannel 直接传输的状态 Map。 */
    fun read(): Map<String, Any?> {
        val status = readStatus()
        if (status == null) {
            return linkedMapOf(
                "state" to "idle",
                "status" to "idle",
                "updatedAtEpochMs" to 0L,
            )
        }
        return linkedMapOf(
            "jobId" to status.jobId,
            "state" to status.status,
            "status" to status.status,
            "message" to status.message,
            "packageName" to status.packageName,
            "versionName" to status.versionName,
            "targetVersion" to status.targetVersion,
            "versionCode" to status.versionCode,
            "sessionId" to status.sessionId,
            "installerStatus" to status.installerStatus,
            "silentInstallRequested" to status.silentInstallRequested,
            "requiresUserAction" to status.requiresUserAction,
            "confirmationLaunchFailed" to status.confirmationLaunchFailed,
            "diagnosticCode" to status.diagnosticCode,
            "updatedAtEpochMs" to status.updatedAtEpochMs,
        )
    }

    /** 在持有状态锁时从 SharedPreferences 还原完整记录。 */
    private fun readStatusLocked(): TerminalUpgradeInstallStatus? {
        if (!preferences.contains(KEY_STATUS)) {
            return null
        }
        return TerminalUpgradeInstallStatus(
            jobId = preferences.getString(KEY_JOB_ID, "").orEmpty(),
            status = preferences.getString(KEY_STATUS, "idle").orEmpty(),
            message = preferences.getString(KEY_MESSAGE, "").orEmpty(),
            packageName = preferences.getString(KEY_PACKAGE_NAME, "").orEmpty(),
            targetVersion = preferences.getString(
                KEY_TARGET_VERSION,
                preferences.getString(KEY_VERSION_NAME, ""),
            ).orEmpty(),
            versionName = preferences.getString(KEY_VERSION_NAME, "").orEmpty(),
            versionCode = preferences.getLong(KEY_VERSION_CODE, 0L),
            sessionId = preferences.getInt(KEY_SESSION_ID, -1),
            installerStatus = preferences.getInt(KEY_INSTALLER_STATUS, Int.MIN_VALUE),
            silentInstallRequested = preferences.getBoolean(
                KEY_SILENT_INSTALL_REQUESTED,
                false,
            ),
            requiresUserAction = preferences.getBoolean(KEY_REQUIRES_USER_ACTION, false),
            confirmationLaunchFailed = preferences.getBoolean(
                KEY_CONFIRMATION_LAUNCH_FAILED,
                false,
            ),
            diagnosticCode = preferences.getString(KEY_DIAGNOSTIC_CODE, "").orEmpty(),
            updatedAtEpochMs = preferences.getLong(KEY_UPDATED_AT, 0L),
        )
    }

    private companion object {
        const val PREFERENCES_NAME = "smart_cabinet_upgrade"
        const val KEY_JOB_ID = "job_id"
        const val KEY_STATUS = "status"
        const val KEY_MESSAGE = "message"
        const val KEY_PACKAGE_NAME = "package_name"
        const val KEY_TARGET_VERSION = "target_version"
        const val KEY_VERSION_NAME = "version_name"
        const val KEY_VERSION_CODE = "version_code"
        const val KEY_SESSION_ID = "session_id"
        const val KEY_INSTALLER_STATUS = "installer_status"
        const val KEY_SILENT_INSTALL_REQUESTED = "silent_install_requested"
        const val KEY_REQUIRES_USER_ACTION = "requires_user_action"
        const val KEY_CONFIRMATION_LAUNCH_FAILED = "confirmation_launch_failed"
        const val KEY_DIAGNOSTIC_CODE = "diagnostic_code"
        const val KEY_UPDATED_AT = "updated_at_epoch_ms"
        val STATUS_LOCK = Any()
    }
}
