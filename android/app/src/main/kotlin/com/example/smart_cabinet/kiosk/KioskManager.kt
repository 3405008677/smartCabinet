package com.example.smart_cabinet.kiosk

import android.app.Activity
import android.app.ActivityManager
import android.app.admin.DevicePolicyManager
import android.content.ContentValues
import android.content.pm.PackageManager
import android.content.ComponentName
import android.graphics.ImageFormat
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.UserManager
import android.provider.Settings
import android.util.Log
import android.view.WindowManager
import com.example.smart_cabinet.logging.NativeCommunicationDirection
import com.example.smart_cabinet.logging.NativeCommunicationLogStore
import com.example.smart_cabinet.logging.NativeCommunicationTargetType
import org.json.JSONObject
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.ServerSocket
import java.net.Socket
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CountDownLatch
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import android.net.Uri

/**
 * 统一编排柜机模式、摄像头推流、18080 控制服务和原生错误上报。
 * 通讯诊断只在各协议边界记录脱敏元数据，不复制视频帧、身份信息或文件内容。
 */
class KioskManager(private val activity: Activity) {
    private var outsideEnvironmentStream: DualMediaCodecH265Stream? = null

    private var operationAreaStream: H265RtspStream? = null

    private val rkMppBridge by lazy { RkMppBridge() }

    @Volatile
    private var outsideEnvironmentStreamStatus: String = "未启动"

    @Volatile
    private var operationAreaStreamStatus: String = "未启动"

    @Volatile
    private var outsideEnvironmentLastErrorCode: String = ""

    @Volatile
    private var outsideEnvironmentLastErrorMessage: String = ""

    @Volatile
    private var outsideEnvironmentFailureStage: String = ""

    @Volatile
    private var operationAreaLastErrorCode: String = ""

    @Volatile
    private var operationAreaLastErrorMessage: String = ""

    @Volatile
    private var operationAreaFailureStage: String = ""

    @Volatile
    private var outsideEnvironmentFailureClearLocked: Boolean = false

    @Volatile
    private var operationAreaFailureClearLocked: Boolean = false

    @Volatile
    private var activeOutsideEnvironmentProfiles: List<StreamProfile> = emptyList()

    @Volatile
    private var confirmedOutsideEnvironmentProfiles: Set<String> = emptySet()

    private var enabledOutsideEnvironmentProfiles: Set<String> = emptySet()

    private var outsideEnvironmentCameraId: String = ""

    private var operationAreaCameraId: String = ""

    private var outsideEnvironmentStreamEpoch = 0L

    private var outsideEnvironmentDesired = false

    private var operationAreaStreamEpoch = 0L

    private var operationAreaDesired = false

    @Volatile
    private var streamControlServerSocket: ServerSocket? = null

    @Volatile
    private var streamControlServerThread: Thread? = null

    private val streamHandler = Handler(Looper.getMainLooper())

    private var reconnectAttempts = 0

    private var reconnectingCameraId: String? = null

    private var operationReconnectAttempts = 0

    private var operationReconnectingCameraId: String? = null

    private val failedDownloadsLogNames = mutableSetOf<String>()

    private val logDir: File by lazy(LazyThreadSafetyMode.SYNCHRONIZED) {
        File(activity.getExternalFilesDir(null) ?: activity.filesDir, "logs").also { directory ->
            if (!directory.exists() && !directory.mkdirs()) {
                Log.w(TAG, "failed to create log directory: ${directory.absolutePath}")
            }
        }
    }

    private val released = AtomicBoolean(false)

    private val errorUploadInFlight = AtomicBoolean(false)

    private val downloadsLogUris = ConcurrentHashMap<String, Uri>()

    private val logExecutor = ThreadPoolExecutor(
        1,
        1,
        0L,
        TimeUnit.MILLISECONDS,
        ArrayBlockingQueue<Runnable>(LOG_QUEUE_CAPACITY),
        { runnable -> Thread(runnable, "SmartCabinetLogWriter").apply { isDaemon = true } },
        ThreadPoolExecutor.DiscardOldestPolicy(),
    )

    private val uploadExecutor = ThreadPoolExecutor(
        1,
        1,
        0L,
        TimeUnit.MILLISECONDS,
        ArrayBlockingQueue<Runnable>(1),
        { runnable -> Thread(runnable, "SmartCabinetErrorLogUpload").apply { isDaemon = true } },
        ThreadPoolExecutor.DiscardPolicy(),
    )

    @Volatile
    private var errorUploadMutedUntilMs = 0L

    private var reconnectRunnable: Runnable? = null

    private var operationReconnectRunnable: Runnable? = null

    private val devicePolicyManager: DevicePolicyManager =
        activity.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager

    private val activityManager: ActivityManager =
        activity.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager

    private val adminComponent: ComponentName =
        ComponentName(activity, KioskDeviceAdminReceiver::class.java)

    fun isDeviceOwner(): Boolean {
        return devicePolicyManager.isDeviceOwnerApp(activity.packageName)
    }

    fun isKioskModeActive(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            activityManager.lockTaskModeState == ActivityManager.LOCK_TASK_MODE_LOCKED
        } else {
            @Suppress("DEPRECATION")
            activityManager.isInLockTaskMode
        }
    }

    fun enterKioskMode(): Boolean {
        keepScreenOn()
        hideSystemBars()

        if (!isDeviceOwner()) {
            return false
        }

        devicePolicyManager.setLockTaskPackages(adminComponent, arrayOf(activity.packageName))

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            devicePolicyManager.setLockTaskFeatures(
                adminComponent,
                DevicePolicyManager.LOCK_TASK_FEATURE_NONE,
            )
        }

        addUserRestrictions()

        if (devicePolicyManager.isLockTaskPermitted(activity.packageName) && !isKioskModeActive()) {
            activity.startLockTask()
        }
        return isKioskModeActive()
    }

    fun exitKioskMode(): Boolean {
        if (isKioskModeActive()) {
            activity.stopLockTask()
        }

        if (isDeviceOwner()) {
            clearUserRestrictions()
        }

        return !isKioskModeActive()
    }

    fun openSystemSettings() {
        val intent = Intent(Settings.ACTION_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        activity.startActivity(intent)
    }

    fun getDeviceInfo(): Map<String, String> {
        val androidId = Settings.Secure.getString(
            activity.contentResolver,
            Settings.Secure.ANDROID_ID,
        ) ?: "未知"

        return linkedMapOf(
            "唯一设备ID" to androidId,
            "主板" to Build.BOARD,
            "启动加载器" to Build.BOOTLOADER,
            "品牌" to Build.BRAND,
            "设备" to Build.DEVICE,
            "显示版本" to Build.DISPLAY,
            "指纹" to Build.FINGERPRINT,
            "硬件" to Build.HARDWARE,
            "主机" to Build.HOST,
            "构建 ID" to Build.ID,
            "厂商" to Build.MANUFACTURER,
            "型号" to Build.MODEL,
            "产品" to Build.PRODUCT,
            "标签" to Build.TAGS,
            "构建时间" to Build.TIME.toString(),
            "构建类型" to Build.TYPE,
            "用户" to Build.USER,
            "Android 版本" to Build.VERSION.RELEASE,
            "Android SDK" to Build.VERSION.SDK_INT.toString(),
            "安全补丁" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Build.VERSION.SECURITY_PATCH
            } else {
                "不支持"
            },
        )
    }

    fun getHardwareStatus(): Map<String, Any> {
        val connectivityManager =
            activity.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val activeNetwork = connectivityManager.activeNetwork
        val networkCapabilities = activeNetwork?.let(connectivityManager::getNetworkCapabilities)
        val wifiConnected = networkCapabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
        val ethernetConnected =
            networkCapabilities?.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) == true
        val wifiName = if (wifiConnected) readWifiName() else ""

        return linkedMapOf(
            "wifiConnected" to wifiConnected,
            "wifiName" to wifiName,
            "ethernetConnected" to ethernetConnected,
            "fingerprintAvailable" to activity.packageManager.hasSystemFeature(
                PackageManager.FEATURE_FINGERPRINT,
            ),
            "nfcAvailable" to activity.packageManager.hasSystemFeature(PackageManager.FEATURE_NFC),
        )
    }

    private fun readWifiName(): String {
        val wifiManager =
            activity.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                ?: return "已连接 WiFi"
        val ssid = wifiManager.connectionInfo?.ssid?.trim('"') ?: ""
        return if (ssid.isBlank() || ssid == WifiManager.UNKNOWN_SSID) {
            "已连接 WiFi"
        } else {
            ssid
        }
    }

    fun startCameraStream(role: String, profiles: List<String>) {
        require(role == ROLE_OUTSIDE_ENVIRONMENT || role == ROLE_OPERATION_AREA) {
            "unsupported camera stream role: $role"
        }
        when (role) {
            ROLE_OUTSIDE_ENVIRONMENT -> {
                val cameraId = OUTSIDE_ENVIRONMENT_CAMERA_ID
                val requestedProfiles = profiles.mapNotNull(::findStreamProfile)
                require(requestedProfiles.isNotEmpty()) { "no supported stream profiles requested" }
                if (isOutsideEnvironmentStreamAlreadyActive(cameraId, requestedProfiles)) {
                    outsideEnvironmentFailureClearLocked = false
                    clearStreamFailure(ROLE_OUTSIDE_ENVIRONMENT)
                    reconnectAttempts = 0
                    outsideEnvironmentStreamStatus =
                        "${activeOutsideEnvironmentProfiles.joinToString(",") { profile -> profile.name }} 推流中"
                    Log.i(TAG, "start camera stream skipped, already active, role=$role, profiles=${requestedProfiles.map { it.name }}, cameraId=$cameraId")
                    appendOutsideEnvironmentLog("start skipped, already active, cameraId=$cameraId, profiles=${requestedProfiles.joinToString(",") { it.name }}")
                    return
                }

                outsideEnvironmentFailureClearLocked = true
                clearStreamFailure(ROLE_OUTSIDE_ENVIRONMENT)
                val effectiveProfileNames = enabledOutsideEnvironmentProfiles +
                    requestedProfiles.map { profile -> profile.name }
                val profilesToValidate = STREAM_PROFILES.filter { profile ->
                    effectiveProfileNames.contains(profile.name)
                }
                val preflight = validateConfiguredCameraForStart(role, profilesToValidate)
                if (!preflight.allowed) {
                    recordStreamFailure(
                        role = ROLE_OUTSIDE_ENVIRONMENT,
                        code = preflight.errorCode,
                        message = preflight.failureStatus,
                        stage = FAILURE_STAGE_CAMERA_PREFLIGHT,
                        replaceExisting = true,
                    )
                }
                if (!preflight.allowed && !preflight.recoverable) {
                    abandonOutsideEnvironmentDesiredProfilesAfterTerminalFailure(
                        reason = preflight.failureStatus,
                    )
                    return
                }

                outsideEnvironmentCameraId = cameraId
                enabledOutsideEnvironmentProfiles = enabledOutsideEnvironmentProfiles + requestedProfiles.map { profile -> profile.name }
                outsideEnvironmentDesired = enabledOutsideEnvironmentProfiles.isNotEmpty()
                outsideEnvironmentStreamEpoch += 1
                val epoch = outsideEnvironmentStreamEpoch
                cancelOutsideEnvironmentReconnect()
                reconnectAttempts = 0
                outsideEnvironmentFailureClearLocked = false
                if (!preflight.allowed) {
                    val expectedStream = outsideEnvironmentStream
                    runCatching { expectedStream?.stop() }
                        .onFailure { error -> appendOutsideEnvironmentLog("preflight retry stop failed, epoch=$epoch", error) }
                    activeOutsideEnvironmentProfiles = emptyList()
                    scheduleOutsideEnvironmentReconnect(
                        cameraId = cameraId,
                        epoch = epoch,
                        expectedStream = expectedStream,
                        reason = preflight.failureStatus,
                    )
                    return
                }
                Log.i(TAG, "start camera stream by role, role=$role, profiles=${requestedProfiles.map { it.name }}, cameraId=$cameraId, epoch=$epoch")
                startOutsideEnvironmentStream(cameraId, epoch)
            }
            ROLE_OPERATION_AREA -> {
                val cameraId = OPERATION_AREA_CAMERA_ID
                require(cameraId.isNotBlank()) { "operation area camera is not configured" }
                if (operationAreaDesired && operationAreaStream?.isStreaming() == true && operationAreaStream?.currentCameraId == cameraId && streamStateName(operationAreaStreamStatus) == STREAM_STATE_STREAMING) {
                    operationAreaFailureClearLocked = false
                    clearStreamFailure(ROLE_OPERATION_AREA)
                    operationReconnectAttempts = 0
                    operationAreaStreamStatus = "推流中"
                    return
                }

                operationAreaFailureClearLocked = true
                clearStreamFailure(ROLE_OPERATION_AREA)
                val preflight = validateConfiguredCameraForStart(role, listOf(DEFAULT_STREAM_PROFILE))
                if (!preflight.allowed) {
                    recordStreamFailure(
                        role = ROLE_OPERATION_AREA,
                        code = preflight.errorCode,
                        message = preflight.failureStatus,
                        stage = FAILURE_STAGE_CAMERA_PREFLIGHT,
                        replaceExisting = true,
                    )
                }
                if (!preflight.allowed && !preflight.recoverable) {
                    return
                }

                operationAreaCameraId = cameraId
                operationAreaDesired = true
                operationAreaStreamEpoch += 1
                val epoch = operationAreaStreamEpoch
                cancelOperationAreaReconnect()
                operationReconnectAttempts = 0
                operationAreaFailureClearLocked = false
                if (!preflight.allowed) {
                    val expectedStream = operationAreaStream
                    runCatching { expectedStream?.stop() }
                        .onFailure { error -> appendOutsideEnvironmentLog("role=operationArea preflight retry stop failed, epoch=$epoch", error) }
                    scheduleOperationAreaReconnect(
                        cameraId = cameraId,
                        epoch = epoch,
                        expectedStream = expectedStream,
                        reason = preflight.failureStatus,
                    )
                    return
                }
                startOperationAreaStream(cameraId, epoch)
            }
            else -> throw IllegalArgumentException("unsupported camera stream role: $role")
        }
    }

    fun stopCameraStream(role: String, profiles: List<String>) {
        when (role) {
            ROLE_OUTSIDE_ENVIRONMENT -> {
                outsideEnvironmentFailureClearLocked = false
                clearStreamFailure(ROLE_OUTSIDE_ENVIRONMENT)
                val cameraId = OUTSIDE_ENVIRONMENT_CAMERA_ID
                outsideEnvironmentCameraId = cameraId
                val requestedProfiles = if (profiles.isEmpty()) {
                    STREAM_PROFILES
                } else {
                    profiles.mapNotNull(::findStreamProfile)
                }
                requestedProfiles.forEach { profile ->
                    enabledOutsideEnvironmentProfiles = enabledOutsideEnvironmentProfiles - profile.name
                }
                outsideEnvironmentDesired = enabledOutsideEnvironmentProfiles.isNotEmpty()
                outsideEnvironmentStreamEpoch += 1
                val epoch = outsideEnvironmentStreamEpoch
                cancelOutsideEnvironmentReconnect()
                reconnectAttempts = 0
                if (!outsideEnvironmentDesired) {
                    stopOutsideEnvironmentStream()
                    outsideEnvironmentStreamStatus = "720p/1080p 已停止"
                    return
                }
                Log.i(TAG, "stop camera stream by role, role=$role, stopped=${requestedProfiles.map { it.name }}, remaining=$enabledOutsideEnvironmentProfiles, cameraId=$cameraId, epoch=$epoch")
                startOutsideEnvironmentStream(cameraId, epoch)
            }
            ROLE_OPERATION_AREA -> {
                operationAreaFailureClearLocked = false
                clearStreamFailure(ROLE_OPERATION_AREA)
                operationAreaDesired = false
                operationAreaStreamEpoch += 1
                cancelOperationAreaReconnect()
                operationReconnectAttempts = 0
                stopOperationAreaStream()
                operationAreaStreamStatus = "已停止"
            }
            else -> throw IllegalArgumentException("unsupported camera stream role: $role")
        }
    }

    fun retryCameraStream(role: String): List<String> {
        val profiles = when (role) {
            ROLE_OUTSIDE_ENVIRONMENT -> STREAM_PROFILES
                .filter { profile -> enabledOutsideEnvironmentProfiles.contains(profile.name) }
                .map { profile -> profile.name }
            ROLE_OPERATION_AREA -> if (operationAreaDesired) {
                listOf(DEFAULT_STREAM_PROFILE.name)
            } else {
                emptyList()
            }
            else -> throw IllegalArgumentException("unsupported camera stream role: $role")
        }
        require(profiles.isNotEmpty()) { "no enabled stream profiles to retry for role: $role" }

        // Keep the desired-profile snapshot, stop, and restart in one platform call.
        // MQTT commands are delivered on the same main thread, so they cannot interleave
        // and reintroduce an obsolete profile between these two operations.
        stopCameraStream(role, profiles)
        startCameraStream(role, profiles)
        return profiles
    }

    fun readOutsideEnvironmentStreamStatus(): Map<String, String> {
        val activeProfileNames = activeOutsideEnvironmentProfiles.map { profile -> profile.name }.toSet()
        val allProfilesStreaming = activeProfileNames.isNotEmpty() &&
            confirmedOutsideEnvironmentProfiles.containsAll(activeProfileNames)
        val reportedState = streamStateName(outsideEnvironmentStreamStatus)
        val state = if (reportedState == STREAM_STATE_STREAMING && !allProfilesStreaming) {
            STREAM_STATE_STARTING
        } else {
            reportedState
        }
        return linkedMapOf(
            "status" to outsideEnvironmentStreamStatus,
            "state" to state,
            "role" to ROLE_OUTSIDE_ENVIRONMENT,
            "recoverable" to isStreamFailureRecoverable(outsideEnvironmentStreamStatus, outsideEnvironmentLastErrorCode).toString(),
            "reconnectAttempts" to reconnectAttempts.toString(),
            "url" to activeOutsideEnvironmentProfiles.joinToString(",") { profile -> buildOutsideEnvironmentRtspUrl(profile) },
            "cameraId" to outsideEnvironmentCameraId,
            "profile" to activeOutsideEnvironmentProfiles.joinToString(",") { profile -> profile.name },
            "enabledProfiles" to enabledOutsideEnvironmentProfiles.joinToString(","),
            "streamingProfiles" to confirmedOutsideEnvironmentProfiles.joinToString(","),
            "allProfilesStreaming" to allProfilesStreaming.toString(),
            "streamMode" to if (activeOutsideEnvironmentProfiles.size > 1) OUTSIDE_ENVIRONMENT_STREAM_MODE else "profile_active",
            "logFile" to outsideEnvironmentLogFile().absolutePath,
            "downloadsLogFile" to DOWNLOADS_LOG_PATH,
            "lastErrorCode" to outsideEnvironmentLastErrorCode,
            "lastErrorMessage" to outsideEnvironmentLastErrorMessage,
            "failureStage" to outsideEnvironmentFailureStage,
        )
    }

    fun readOperationAreaStreamStatus(): Map<String, String> {
        if (OPERATION_AREA_CAMERA_ID.isBlank()) {
            return linkedMapOf(
                "status" to "未配置操作区摄像头",
                "state" to STREAM_STATE_UNCONFIGURED,
                "role" to ROLE_OPERATION_AREA,
                "recoverable" to "false",
                "reconnectAttempts" to operationReconnectAttempts.toString(),
                "url" to "",
                "cameraId" to "",
                "profile" to "",
                "enabledProfiles" to "",
                "streamingProfiles" to "",
                "allProfilesStreaming" to "false",
                "lastErrorCode" to operationAreaLastErrorCode,
                "lastErrorMessage" to operationAreaLastErrorMessage,
                "failureStage" to operationAreaFailureStage,
            )
        }
        val allProfilesStreaming = operationAreaDesired &&
            operationAreaStream?.isStreaming() == true &&
            streamStateName(operationAreaStreamStatus) == STREAM_STATE_STREAMING
        return linkedMapOf(
            "status" to operationAreaStreamStatus,
            "state" to streamStateName(operationAreaStreamStatus),
            "role" to ROLE_OPERATION_AREA,
            "recoverable" to isStreamFailureRecoverable(operationAreaStreamStatus, operationAreaLastErrorCode).toString(),
            "reconnectAttempts" to operationReconnectAttempts.toString(),
            "url" to buildOperationAreaRtspUrl(),
            "cameraId" to operationAreaCameraId,
            "profile" to if (operationAreaDesired) DEFAULT_STREAM_PROFILE.name else "",
            "enabledProfiles" to if (operationAreaDesired) DEFAULT_STREAM_PROFILE.name else "",
            "streamingProfiles" to if (allProfilesStreaming) DEFAULT_STREAM_PROFILE.name else "",
            "allProfilesStreaming" to allProfilesStreaming.toString(),
            "lastErrorCode" to operationAreaLastErrorCode,
            "lastErrorMessage" to operationAreaLastErrorMessage,
            "failureStage" to operationAreaFailureStage,
        )
    }

    fun readCameraStreamCapability(role: String): Map<String, Any?> {
        val snapshot = probeCameraCapability(role)
        val supportedSizeKeys = snapshot.yuvSupportedSizes
            .mapTo(mutableSetOf()) { size -> "${size.width}x${size.height}" }
        val compatibilityKnown = snapshot.available &&
            (snapshot.errorCode.isBlank() || snapshot.errorCode == "YUV_OUTPUT_UNAVAILABLE")
        val configuredProfiles = configuredProfilesForRole(role).map { profile ->
            linkedMapOf<String, Any?>(
                "name" to profile.name,
                "width" to profile.width,
                "height" to profile.height,
                "compatible" to if (compatibilityKnown) {
                    supportedSizeKeys.contains("${profile.width}x${profile.height}")
                } else {
                    null
                },
            )
        }
        return linkedMapOf(
            "role" to role,
            "configuredCameraId" to snapshot.configuredCameraId,
            "availableCameraIds" to snapshot.availableCameraIds,
            "available" to snapshot.available,
            "supportedYuvSizes" to snapshot.yuvSupportedSizes.map { size ->
                linkedMapOf<String, Any>("width" to size.width, "height" to size.height)
            },
            "configuredProfiles" to configuredProfiles,
            "errorCode" to snapshot.errorCode,
            "errorMessage" to snapshot.errorMessage,
        )
    }

    fun readRkMppStatus(): Map<String, String> {
        return runCatching {
            val initialized = rkMppBridge.initialize(activity.applicationContext)
            linkedMapOf(
                "available" to initialized.toString(),
                "version" to rkMppBridge.version(),
                "status" to rkMppBridge.rkMppStatus(),
                "library" to "libsmartcabinet_rkmpp.so",
            )
        }.getOrElse { error ->
            linkedMapOf(
                "available" to "false",
                "version" to "",
                "error" to (error.message ?: error::class.java.simpleName),
            )
        }
    }

    fun recordErrorLog(source: String, message: String, error: String, stackTrace: String) {
        appendUnifiedErrorLog(
            source = source,
            message = message,
            error = error,
            stackTrace = stackTrace,
        )
    }

    fun release() {
        if (!released.compareAndSet(false, true)) {
            return
        }
        outsideEnvironmentDesired = false
        operationAreaDesired = false
        outsideEnvironmentStreamEpoch += 1
        operationAreaStreamEpoch += 1
        streamHandler.removeCallbacksAndMessages(null)
        reconnectRunnable = null
        operationReconnectRunnable = null
        reconnectingCameraId = null
        operationReconnectingCameraId = null
        stopOutsideEnvironmentStream()
        stopOperationAreaStream()
        stopStreamControlServer()
        logExecutor.shutdownNow()
        uploadExecutor.shutdownNow()
        downloadsLogUris.clear()
    }

    fun startStreamControlServer() {
        if (streamControlServerThread?.isAlive == true) {
            return
        }
        streamControlServerThread = Thread {
            runCatching {
                ServerSocket(STREAM_CONTROL_PORT).use { serverSocket ->
                    streamControlServerSocket = serverSocket
                    Log.i(TAG, "stream control HTTP server started, port=$STREAM_CONTROL_PORT")
                    while (!Thread.currentThread().isInterrupted) {
                        val socket = runCatching { serverSocket.accept() }.getOrNull() ?: break
                        socket.soTimeout = STREAM_CONTROL_CLIENT_READ_TIMEOUT_MS
                        Thread { handleStreamControlSocket(socket) }.apply {
                            name = "SmartCabinetStreamControlClient"
                            start()
                        }
                    }
                }
            }.onFailure { error ->
                if (streamControlServerThread?.isInterrupted != true) {
                    Log.e(TAG, "stream control HTTP server failed", error)
                }
            }
            streamControlServerSocket = null
        }.apply {
            name = "SmartCabinetStreamControlServer"
            start()
        }
    }

    fun stopStreamControlServer() {
        streamControlServerThread?.interrupt()
        runCatching { streamControlServerSocket?.close() }
        streamControlServerSocket = null
        streamControlServerThread = null
    }

    /**
     * 处理一个 18080 HTTP 控制连接，并只记录归一化方法、命令类别和响应码。
     * 请求 path、query、header 与 body 都不会复制到通讯日志。
     */
    private fun handleStreamControlSocket(socket: Socket) {
        socket.use { clientSocket ->
            val requestTime = System.currentTimeMillis()
            val input = BufferedReader(InputStreamReader(clientSocket.getInputStream(), Charsets.UTF_8))
            val requestLine = input.readLine().orEmpty()
            val headers = mutableMapOf<String, String>()
            while (true) {
                val line = input.readLine() ?: break
                if (line.isEmpty()) {
                    break
                }
                val separatorIndex = line.indexOf(':')
                if (separatorIndex > 0) {
                    headers[line.substring(0, separatorIndex).trim().lowercase(Locale.US)] = line.substring(separatorIndex + 1).trim()
                }
            }
            val contentLength = headers["content-length"]?.toIntOrNull() ?: 0
            val body = if (contentLength > 0) {
                CharArray(contentLength).also { chars -> input.read(chars, 0, contentLength) }.concatToString()
            } else {
                ""
            }
            val response = handleStreamControlRequest(requestLine, body)
            val requestParts = requestLine.split(' ')
            val method = requestParts.getOrNull(0)
                ?.uppercase(Locale.US)
                ?.takeIf { value -> value.matches(HTTP_METHOD_PATTERN) }
                ?: "UNKNOWN"
            val path = requestParts.getOrNull(1).orEmpty().substringBefore('?')
            val requestKind = if (method == "GET" && path == "/stream/status") {
                "读取推流状态"
            } else {
                "不支持的控制请求"
            }
            val requestSummary = linkedMapOf<String, Any?>(
                "method" to method,
                "requestKind" to requestKind,
                "endpoint" to "http://127.0.0.1:$STREAM_CONTROL_PORT",
            )
            try {
                writeHttpJsonResponse(clientSocket, response.first, response.second)
                NativeCommunicationLogStore.tryRecord(
                    targetType = NativeCommunicationTargetType.SERVER,
                    direction = NativeCommunicationDirection.INBOUND,
                    channel = "HTTP",
                    operation = "推流控制请求",
                    messageBody = requestSummary,
                    result = if (response.first in 200..299) {
                        "成功：HTTP ${response.first}"
                    } else {
                        "失败：HTTP ${response.first}"
                    },
                    requestTimeEpochMs = requestTime,
                )
            } catch (error: Throwable) {
                NativeCommunicationLogStore.tryRecord(
                    targetType = NativeCommunicationTargetType.SERVER,
                    direction = NativeCommunicationDirection.INBOUND,
                    channel = "HTTP",
                    operation = "推流控制请求",
                    messageBody = requestSummary,
                    result = "响应失败：${error::class.java.simpleName}",
                    requestTimeEpochMs = requestTime,
                )
                throw error
            }
        }
    }

    private fun handleStreamControlRequest(requestLine: String, body: String): Pair<Int, JSONObject> {
        val parts = requestLine.split(' ')
        val method = parts.getOrNull(0).orEmpty().uppercase(Locale.US)
        val path = parts.getOrNull(1).orEmpty().substringBefore('?')
        return runCatching {
            when {
                method == "GET" && path == "/stream/status" -> 200 to runStreamControlOnMainThread(::streamControlStatusJson)
                else -> 404 to streamControlErrorJson("unsupported endpoint: $method $path")
            }
        }.getOrElse { error ->
            Log.e(TAG, "stream control request failed", error)
            500 to streamControlErrorJson(error.message ?: error::class.java.simpleName)
        }
    }

    private fun runStreamControlOnMainThread(action: () -> JSONObject): JSONObject {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            return action()
        }
        var resultJson: JSONObject? = null
        var resultError: Throwable? = null
        val latch = CountDownLatch(1)
        streamHandler.post {
            runCatching(action)
                .onSuccess { value -> resultJson = value }
                .onFailure { error -> resultError = error }
            latch.countDown()
        }
        if (!latch.await(STREAM_CONTROL_TIMEOUT_MS, TimeUnit.MILLISECONDS)) {
            error("stream control timed out")
        }
        resultError?.let { error -> throw error }
        return resultJson ?: JSONObject()
    }

    private fun streamControlStatusJson(): JSONObject {
        val switchJson = JSONObject()
        STREAM_PROFILES.forEach { profile ->
            switchJson.put(profile.name, enabledOutsideEnvironmentProfiles.contains(profile.name))
        }
        val statusJson = JSONObject()
        readOutsideEnvironmentStreamStatus().forEach { (key, value) -> statusJson.put(key, value) }
        return JSONObject()
            .put("ok", true)
            .put("switches", switchJson)
            .put("stream", statusJson)
    }

    private fun streamControlErrorJson(message: String): JSONObject {
        return JSONObject().put("ok", false).put("error", message)
    }

    private fun writeHttpJsonResponse(socket: Socket, statusCode: Int, body: JSONObject) {
        val statusText = if (statusCode in 200..299) "OK" else "Error"
        val bodyText = body.toString()
        OutputStreamWriter(socket.getOutputStream(), Charsets.UTF_8).use { writer ->
            writer.write("HTTP/1.1 $statusCode $statusText\r\n")
            writer.write("Content-Type: application/json; charset=utf-8\r\n")
            writer.write("Content-Length: ${bodyText.toByteArray(Charsets.UTF_8).size}\r\n")
            writer.write("Connection: close\r\n")
            writer.write("\r\n")
            writer.write(bodyText)
            writer.flush()
        }
    }

    private fun startOutsideEnvironmentStream(
        cameraId: String,
        epoch: Long,
        triggeredByReconnect: Boolean = false,
    ) {
        if (!isOutsideEnvironmentRequestCurrent(cameraId, epoch)) {
            return
        }
        cancelOutsideEnvironmentReconnect()
        if (triggeredByReconnect) {
            outsideEnvironmentStreamStatus = "正在重连第 $reconnectAttempts 次"
        }

        val profiles = STREAM_PROFILES.filter { profile -> enabledOutsideEnvironmentProfiles.contains(profile.name) }
        if (profiles.isEmpty()) {
            stopOutsideEnvironmentStream()
            outsideEnvironmentStreamStatus = "720p/1080p 已停止"
            appendOutsideEnvironmentLog("stream start skipped, no enabled profiles")
            return
        }

        val preflight = validateConfiguredCameraForStart(ROLE_OUTSIDE_ENVIRONMENT, profiles)
        if (!preflight.allowed) {
            outsideEnvironmentStreamStatus = preflight.failureStatus
            recordStreamFailure(
                role = ROLE_OUTSIDE_ENVIRONMENT,
                code = preflight.errorCode,
                message = preflight.failureStatus,
                stage = FAILURE_STAGE_CAMERA_PREFLIGHT,
                replaceExisting = true,
            )
            if (preflight.recoverable) {
                scheduleOutsideEnvironmentReconnect(
                    cameraId = cameraId,
                    epoch = epoch,
                    expectedStream = outsideEnvironmentStream,
                    reason = preflight.failureStatus,
                )
            } else {
                abandonOutsideEnvironmentDesiredProfilesAfterTerminalFailure(
                    reason = preflight.failureStatus,
                )
            }
            return
        }

        stopOutsideEnvironmentStream()

        try {
            val videoConfig = readVideoConfig()
            val requests = profiles.map { profile ->
                DualMediaCodecH265Stream.StreamRequest(
                    profile = profile.name,
                    url = buildOutsideEnvironmentRtspUrl(profile),
                    width = profile.width,
                    height = profile.height,
                    fps = profile.fps,
                    bitrate = profile.bitrate,
                    iframeInterval = profile.gopSeconds,
                )
            }
            Log.i(TAG, "starting outside environment RKMPP RTSP H265 streams, cameraId=$cameraId, profiles=${profiles.map { it.name }}, videoConfig=$videoConfig, epoch=$epoch")
            resetOutsideEnvironmentLog()
            requests.forEach { request ->
                appendOutsideEnvironmentLog("profile=${request.profile} build=$H265_BUILD_MARK encoder=rkmpp protocol=RTSP codec=H265 transport=TCP cameraId=$cameraId url=${request.url} size=${request.width}x${request.height} fps=${request.fps} bitrate=${request.bitrate} gop=${request.iframeInterval}s epoch=$epoch")
            }
            appendOutsideEnvironmentLog("starting H265 RTSP streams, cameraId=$cameraId, profiles=${profiles.joinToString(",") { it.name }}, epoch=$epoch")
            val requiredProfileNames = profiles.mapTo(mutableSetOf()) { profile -> profile.name }
            val pushedProfileNames = mutableSetOf<String>()
            confirmedOutsideEnvironmentProfiles = emptySet()
            lateinit var stream: DualMediaCodecH265Stream
            stream = DualMediaCodecH265Stream(activity.applicationContext, rkMppBridge) { status ->
                streamHandler.post {
                    if (!isOutsideEnvironmentStreamCurrent(cameraId, epoch, stream) || reconnectRunnable != null) {
                        return@post
                    }
                    val sustainedProgress = status.isSustainedStreamProgress()
                    if (sustainedProgress) {
                        requiredProfileNames.firstOrNull { profileName ->
                            status.startsWith("$profileName ")
                        }?.let { profileName ->
                            pushedProfileNames.add(profileName)
                            confirmedOutsideEnvironmentProfiles = pushedProfileNames.toSet()
                        }
                        if (pushedProfileNames.containsAll(requiredProfileNames)) {
                            reconnectAttempts = 0
                            if (!outsideEnvironmentFailureClearLocked) {
                                clearStreamFailure(ROLE_OUTSIDE_ENVIRONMENT)
                            }
                        }
                    } else if (status.isAnyStreamFailure()) {
                        pushedProfileNames.clear()
                        confirmedOutsideEnvironmentProfiles = emptySet()
                        recordStreamFailure(
                            role = ROLE_OUTSIDE_ENVIRONMENT,
                            code = streamFailureCode(status),
                            message = status,
                            stage = streamFailureStage(status),
                        )
                    }
                    outsideEnvironmentStreamStatus = "${profiles.joinToString(",") { it.name }} $status"
                    Log.i(TAG, "outside environment H265 status: $status, epoch=$epoch")
                    appendOutsideEnvironmentLog("status=$status epoch=$epoch")
                    handleOutsideEnvironmentRuntimeStatus(cameraId, epoch, stream, status)
                }
            }
            outsideEnvironmentStream = stream
            activeOutsideEnvironmentProfiles = profiles
            val started = stream.start(cameraId, requests)
            if (!started) {
                val reason = stream.startFailureReason
                    ?.takeIf { failure -> failure.isNotBlank() }
                    ?: outsideEnvironmentStreamStatus
                if (outsideEnvironmentStream === stream) {
                    outsideEnvironmentStream = null
                    activeOutsideEnvironmentProfiles = emptyList()
                }
                val failureStatus = ensureFailureStatus(reason)
                outsideEnvironmentStreamStatus = "${profiles.joinToString(",") { it.name }} $failureStatus"
                recordStreamFailure(
                    role = ROLE_OUTSIDE_ENVIRONMENT,
                    code = streamFailureCode(failureStatus),
                    message = failureStatus,
                    stage = FAILURE_STAGE_STREAM_START,
                )
                Log.e(TAG, "outside environment RKMPP RTSP H265 stream start returned false: $failureStatus, epoch=$epoch")
                appendOutsideEnvironmentLog("start returned false: $failureStatus epoch=$epoch")
                if (failureStatus.isRecoverableStreamFailure()) {
                    scheduleOutsideEnvironmentReconnect(cameraId, epoch, null, failureStatus)
                } else {
                    abandonOutsideEnvironmentDesiredProfilesAfterTerminalFailure(
                        reason = failureStatus,
                    )
                }
                return
            }

            if (!isOutsideEnvironmentStreamCurrent(cameraId, epoch, stream)) {
                stream.stop()
                return
            }
            outsideEnvironmentStreamStatus = "${profiles.joinToString(",") { it.name }} 推流启动中"
            appendOutsideEnvironmentLog("stream object started, epoch=$epoch")
        } catch (error: Throwable) {
            val failedStream = outsideEnvironmentStream
            runCatching { failedStream?.stop() }
            if (outsideEnvironmentStream === failedStream) {
                outsideEnvironmentStream = null
                activeOutsideEnvironmentProfiles = emptyList()
            }
            if (!isOutsideEnvironmentRequestCurrent(cameraId, epoch)) {
                return
            }
            val reason = "${enabledOutsideEnvironmentProfiles.joinToString(",")} 推流启动失败：${error.message ?: error::class.java.simpleName}"
            outsideEnvironmentStreamStatus = reason
            recordStreamFailure(
                role = ROLE_OUTSIDE_ENVIRONMENT,
                code = streamFailureCode(reason),
                message = reason,
                stage = FAILURE_STAGE_STREAM_START,
            )
            Log.e(TAG, "outside environment RKMPP RTSP H265 stream start failed, epoch=$epoch", error)
            appendOutsideEnvironmentLog("start failed, epoch=$epoch", error)
            if (reason.isRecoverableStreamFailure()) {
                scheduleOutsideEnvironmentReconnect(cameraId, epoch, null, reason)
            } else {
                abandonOutsideEnvironmentDesiredProfilesAfterTerminalFailure(
                    reason = reason,
                )
            }
        }
    }

    private fun isOutsideEnvironmentStreamAlreadyActive(
        cameraId: String,
        requestedProfiles: List<StreamProfile>,
    ): Boolean {
        val stream = outsideEnvironmentStream ?: return false
        if (!outsideEnvironmentDesired || !stream.isStreaming() || outsideEnvironmentCameraId != cameraId) {
            return false
        }
        if (streamStateName(outsideEnvironmentStreamStatus) != STREAM_STATE_STREAMING) {
            return false
        }
        val activeProfileNames = activeOutsideEnvironmentProfiles.map { profile -> profile.name }.toSet()
        val requestedProfileNames = requestedProfiles.map { profile -> profile.name }.toSet()
        return activeProfileNames.isNotEmpty() &&
            confirmedOutsideEnvironmentProfiles.containsAll(activeProfileNames) &&
            activeProfileNames.containsAll(requestedProfileNames)
    }

    private fun stopOutsideEnvironmentStream() {
        confirmedOutsideEnvironmentProfiles = emptySet()
        val stream = outsideEnvironmentStream ?: return
        runCatching { stream.stop() }
            .onFailure { error -> appendOutsideEnvironmentLog("stop failed", error) }
        if (outsideEnvironmentStream === stream) {
            outsideEnvironmentStream = null
            activeOutsideEnvironmentProfiles = emptyList()
        }
        appendOutsideEnvironmentLog("stream stopped")
    }

    private fun abandonOutsideEnvironmentDesiredProfilesAfterTerminalFailure(reason: String) {
        outsideEnvironmentStreamEpoch += 1
        outsideEnvironmentDesired = false
        enabledOutsideEnvironmentProfiles = emptySet()
        cancelOutsideEnvironmentReconnect()
        reconnectAttempts = 0
        outsideEnvironmentFailureClearLocked = false
        stopOutsideEnvironmentStream()
        activeOutsideEnvironmentProfiles = emptyList()
        appendOutsideEnvironmentLog("terminal failure cleared desired profiles, reason=$reason")
    }

    private fun scheduleOutsideEnvironmentReconnect(
        cameraId: String,
        epoch: Long,
        expectedStream: DualMediaCodecH265Stream?,
        reason: String,
    ) {
        if (!isOutsideEnvironmentRequestCurrent(cameraId, epoch) || outsideEnvironmentStream !== expectedStream) {
            return
        }
        cancelOutsideEnvironmentReconnect()
        if (reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
            outsideEnvironmentStreamStatus = "推流重连失败，已达到最大次数：$reason"
            runCatching { expectedStream?.stop() }
                .onFailure { error -> appendOutsideEnvironmentLog("max-retry stop failed, epoch=$epoch", error) }
            outsideEnvironmentStream = null
            activeOutsideEnvironmentProfiles = emptyList()
            Log.e(TAG, "outside environment RKMPP RTSP H265 stream reconnect failed, max attempts reached")
            appendOutsideEnvironmentLog("reconnect failed, max attempts reached, reason=$reason, epoch=$epoch")
            return
        }
        reconnectAttempts += 1
        reconnectingCameraId = cameraId
        val reconnectDelayMs = reconnectDelayMs(reconnectAttempts)
        lateinit var task: Runnable
        task = Runnable {
            if (reconnectRunnable !== task) {
                return@Runnable
            }
            reconnectRunnable = null
            reconnectingCameraId = null
            if (!isOutsideEnvironmentRequestCurrent(cameraId, epoch) || outsideEnvironmentStream !== expectedStream) {
                return@Runnable
            }
            startOutsideEnvironmentStream(cameraId, epoch, triggeredByReconnect = true)
        }
        reconnectRunnable = task
        streamHandler.postDelayed(task, reconnectDelayMs)
        outsideEnvironmentStreamStatus = "推流断开：$reason，${reconnectDelayMs / 1000} 秒后重连第 $reconnectAttempts 次"
        Log.w(TAG, "outside environment RKMPP RTSP H265 stream reconnect scheduled, cameraId=$cameraId, attempt=$reconnectAttempts, reason=$reason, epoch=$epoch")
        appendOutsideEnvironmentLog("reconnect scheduled, cameraId=$cameraId, attempt=$reconnectAttempts, reason=$reason, epoch=$epoch")
    }

    private fun handleOutsideEnvironmentRuntimeStatus(
        cameraId: String,
        epoch: Long,
        stream: DualMediaCodecH265Stream,
        status: String,
    ) {
        if (!status.isAnyStreamFailure() ||
            !isOutsideEnvironmentStreamCurrent(cameraId, epoch, stream) ||
            reconnectRunnable != null
        ) {
            return
        }
        val recoverable = status.isRecoverableStreamFailure()
        runCatching { stream.stop() }
            .onFailure { error -> appendOutsideEnvironmentLog("runtime stop failed, epoch=$epoch", error) }
        if (recoverable) {
            scheduleOutsideEnvironmentReconnect(cameraId, epoch, stream, status)
        } else {
            abandonOutsideEnvironmentDesiredProfilesAfterTerminalFailure(
                reason = status,
            )
        }
    }

    private fun isOutsideEnvironmentRequestCurrent(cameraId: String, epoch: Long): Boolean {
        return !released.get() && outsideEnvironmentDesired && enabledOutsideEnvironmentProfiles.isNotEmpty() &&
            outsideEnvironmentStreamEpoch == epoch && outsideEnvironmentCameraId == cameraId
    }

    private fun isOutsideEnvironmentStreamCurrent(
        cameraId: String,
        epoch: Long,
        stream: DualMediaCodecH265Stream,
    ): Boolean {
        return isOutsideEnvironmentRequestCurrent(cameraId, epoch) && outsideEnvironmentStream === stream
    }

    private fun cancelOutsideEnvironmentReconnect() {
        reconnectRunnable?.let(streamHandler::removeCallbacks)
        reconnectRunnable = null
        reconnectingCameraId = null
    }

    private fun enqueueLogWrite(block: () -> Unit) {
        if (released.get() || logExecutor.isShutdown) {
            return
        }
        runCatching { logExecutor.execute(block) }
    }

    private fun appendOutsideEnvironmentLogNow(message: String, error: Throwable?) {
        val timestamp = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US).format(Date())
        val details = buildString {
            append(timestamp)
            append(" | ")
            append(message)
            if (error != null) {
                append('\n')
                append(Log.getStackTraceString(error))
            }
            append('\n')
        }
        appendLogFile(OUTSIDE_ENVIRONMENT_LOG_FILE_NAME, details)
        writeDownloadsLog(OUTSIDE_ENVIRONMENT_LOG_FILE_NAME, details)
        if (error != null || message.isErrorLikeLog()) {
            appendUnifiedErrorLogNow(
                source = "android-h265",
                message = message,
                error = error?.message ?: "",
                stackTrace = error?.let(Log::getStackTraceString) ?: "",
                timestamp = timestamp,
            )
        }
    }

    private fun appendUnifiedErrorLogNow(
        source: String,
        message: String,
        error: String,
        stackTrace: String,
        timestamp: String,
    ) {
        val details = buildString {
            append(timestamp)
            append(" | source=")
            append(source)
            append(" | message=")
            append(message)
            if (error.isNotBlank()) {
                append(" | error=")
                append(error)
            }
            if (stackTrace.isNotBlank()) {
                append('\n')
                append(stackTrace)
            }
            append('\n')
        }
        appendLogFile(UNIFIED_ERROR_LOG_FILE_NAME, details)
        writeDownloadsLog(UNIFIED_ERROR_LOG_FILE_NAME, details)
        scheduleErrorUpload(source, message, error, stackTrace, timestamp)
    }

    private fun appendOutsideEnvironmentLog(message: String, error: Throwable? = null) {
        enqueueLogWrite { appendOutsideEnvironmentLogNow(message, error) }
    }

    private fun resetOutsideEnvironmentLog() {
        enqueueLogWrite(::resetOutsideEnvironmentLogNow)
    }

    private fun resetOutsideEnvironmentLogNow() {
        runCatching { outsideEnvironmentLogFile().writeText("") }
            .onFailure { fileError -> Log.e(TAG, "reset H265 log file failed", fileError) }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return
        }
        val resolver = activity.contentResolver
        val cachedUri = downloadsLogUris[OUTSIDE_ENVIRONMENT_LOG_FILE_NAME]
        if (cachedUri != null) {
            val resetCached = runCatching {
                val output = resolver.openOutputStream(cachedUri, "wt")
                    ?: error("cannot open cached downloads log URI")
                output.use { it.write(ByteArray(0)) }
            }.isSuccess
            if (resetCached) {
                return
            }
            downloadsLogUris.remove(OUTSIDE_ENVIRONMENT_LOG_FILE_NAME, cachedUri)
        }
        runCatching {
            val collection = android.provider.MediaStore.Downloads.EXTERNAL_CONTENT_URI
            val relativePath = "${Environment.DIRECTORY_DOWNLOADS}/SmartCabinetLogs"
            val projection = arrayOf(android.provider.MediaStore.Downloads._ID)
            val selection = "${android.provider.MediaStore.Downloads.DISPLAY_NAME}=? AND ${android.provider.MediaStore.Downloads.RELATIVE_PATH}=?"
            val selectionArgs = arrayOf(OUTSIDE_ENVIRONMENT_LOG_FILE_NAME, "$relativePath/")
            resolver.query(collection, projection, selection, selectionArgs, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val id = cursor.getLong(cursor.getColumnIndexOrThrow(android.provider.MediaStore.Downloads._ID))
                    val uri = android.content.ContentUris.withAppendedId(collection, id)
                    resolver.openOutputStream(uri, "wt")?.use { output -> output.write(ByteArray(0)) }
                    downloadsLogUris[OUTSIDE_ENVIRONMENT_LOG_FILE_NAME] = uri
                }
            }
        }.onFailure { fileError -> Log.e(TAG, "reset downloads H265 log failed", fileError) }
    }

    private fun outsideEnvironmentLogFile(): File {
        return File(logDir, OUTSIDE_ENVIRONMENT_LOG_FILE_NAME)
    }

    private fun appendUnifiedErrorLog(
        source: String,
        message: String,
        error: String,
        stackTrace: String,
        timestamp: String = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US).format(Date()),
    ) {
        enqueueLogWrite {
            appendUnifiedErrorLogNow(
                source = source,
                message = message,
                error = error,
                stackTrace = stackTrace,
                timestamp = timestamp,
            )
        }
    }

    private fun appendLogFile(fileName: String, details: String) {
        runCatching {
            logFile(fileName).appendText(details)
        }.onFailure { fileError ->
            Log.e(TAG, "write log file failed: $fileName", fileError)
        }
    }

    private fun logFile(fileName: String): File {
        return File(logDir, fileName)
    }

    private fun writeDownloadsLog(fileName: String, details: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return
        }
        if (failedDownloadsLogNames.contains(fileName)) {
            return
        }
        downloadsLogUris[fileName]?.let { cachedUri ->
            val written = runCatching {
                val output = activity.contentResolver.openOutputStream(cachedUri, "wa")
                    ?: error("cannot open cached downloads log URI")
                output.use { it.write(details.toByteArray(Charsets.UTF_8)) }
            }.isSuccess
            if (written) {
                return
            }
            downloadsLogUris.remove(fileName, cachedUri)
        }
        runCatching {
            val resolver = activity.contentResolver
            val collection = android.provider.MediaStore.Downloads.EXTERNAL_CONTENT_URI
            val relativePath = "${Environment.DIRECTORY_DOWNLOADS}/SmartCabinetLogs"
            val projection = arrayOf(android.provider.MediaStore.Downloads._ID)
            val selection = "${android.provider.MediaStore.Downloads.DISPLAY_NAME}=? AND ${android.provider.MediaStore.Downloads.RELATIVE_PATH}=?"
            val selectionArgs = arrayOf(fileName, "$relativePath/")
            val existingUri = resolver.query(collection, projection, selection, selectionArgs, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val id = cursor.getLong(cursor.getColumnIndexOrThrow(android.provider.MediaStore.Downloads._ID))
                    android.content.ContentUris.withAppendedId(collection, id)
                } else {
                    null
                }
            }
            val uri = existingUri ?: resolver.insert(
                collection,
                ContentValues().apply {
                    put(android.provider.MediaStore.Downloads.DISPLAY_NAME, fileName)
                    put(android.provider.MediaStore.Downloads.MIME_TYPE, "text/plain")
                    put(android.provider.MediaStore.Downloads.RELATIVE_PATH, relativePath)
                },
            ) ?: return
            downloadsLogUris[fileName] = uri
            resolver.openOutputStream(uri, "wa")?.use { output ->
                output.write(details.toByteArray(Charsets.UTF_8))
            }
        }.onFailure { error ->
            if (failedDownloadsLogNames.add(fileName)) {
                Log.w(TAG, "write downloads log disabled for $fileName: ${error.message ?: error::class.java.simpleName}")
            }
        }
    }

    /**
     * 调度一次错误日志 HTTP POST。
     * 通讯日志仅观察脱敏 endpoint 和 HTTP 结果，不复制错误正文、设备 ID 或堆栈。
     */
    private fun scheduleErrorUpload(
        source: String,
        message: String,
        error: String,
        stackTrace: String,
        timestamp: String,
    ) {
        val reportUrl = readErrorReportUrl()
        if (released.get() || reportUrl.isBlank() || !readErrorUploadEnabled()) {
            return
        }
        val now = System.currentTimeMillis()
        if (now < errorUploadMutedUntilMs || !errorUploadInFlight.compareAndSet(false, true)) {
            return
        }
        val requestTime = System.currentTimeMillis()
        val endpoint = NativeCommunicationLogStore.sanitizeEndpoint(reportUrl)
        val requestSummary = linkedMapOf<String, Any?>(
            "method" to "POST",
            "endpoint" to endpoint,
            "contentType" to "application/json",
            "requestKind" to "错误日志上报",
        )
        try {
            uploadExecutor.execute {
                var connection: HttpURLConnection? = null
                var requestSent = false
                try {
                    val androidId = Settings.Secure.getString(
                        activity.contentResolver,
                        Settings.Secure.ANDROID_ID,
                    ) ?: "unknown"
                    val payload = JSONObject().apply {
                        put("time", timestamp)
                        put("source", source)
                        put("message", message)
                        put("error", error)
                        put("stackTrace", stackTrace)
                        put("deviceId", androidId)
                        put("packageName", activity.packageName)
                    }.toString()
                    connection = (URL(reportUrl).openConnection() as HttpURLConnection).apply {
                        requestMethod = "POST"
                        connectTimeout = 5000
                        readTimeout = 5000
                        doOutput = true
                        setRequestProperty("Content-Type", "application/json; charset=utf-8")
                    }
                    connection?.outputStream?.use { output ->
                        output.write(payload.toByteArray(Charsets.UTF_8))
                    }
                    requestSent = true
                    NativeCommunicationLogStore.tryRecord(
                        targetType = NativeCommunicationTargetType.SERVER,
                        direction = NativeCommunicationDirection.OUTBOUND,
                        channel = "HTTP",
                        operation = "错误日志上报",
                        messageBody = requestSummary,
                        result = "发送成功",
                        requestTimeEpochMs = requestTime,
                    )
                    val code = connection?.responseCode ?: -1
                    NativeCommunicationLogStore.tryRecord(
                        targetType = NativeCommunicationTargetType.SERVER,
                        direction = NativeCommunicationDirection.INBOUND,
                        channel = "HTTP",
                        operation = "错误日志上报",
                        messageBody = requestSummary + ("responseCode" to code),
                        result = if (code in 200..299) {
                            "成功：HTTP $code"
                        } else {
                            "失败：HTTP $code"
                        },
                    )
                    if (code !in 200..299) {
                        errorUploadMutedUntilMs = System.currentTimeMillis() + ERROR_UPLOAD_FAILURE_COOLDOWN_MS
                        Log.e(TAG, "error log upload failed, code=$code, endpoint=$endpoint")
                    }
                } catch (uploadError: Throwable) {
                    NativeCommunicationLogStore.tryRecord(
                        targetType = NativeCommunicationTargetType.SERVER,
                        direction = if (requestSent) {
                            NativeCommunicationDirection.INBOUND
                        } else {
                            NativeCommunicationDirection.OUTBOUND
                        },
                        channel = "HTTP",
                        operation = "错误日志上报",
                        messageBody = requestSummary,
                        result = if (requestSent) {
                            "接收失败：${uploadError::class.java.simpleName}"
                        } else {
                            "发送失败：${uploadError::class.java.simpleName}"
                        },
                        requestTimeEpochMs = requestTime,
                    )
                    errorUploadMutedUntilMs = System.currentTimeMillis() + ERROR_UPLOAD_FAILURE_COOLDOWN_MS
                    Log.w(
                        TAG,
                        "error log upload muted for " +
                            "${ERROR_UPLOAD_FAILURE_COOLDOWN_MS / 1000}s: " +
                            uploadError::class.java.simpleName,
                    )
                } finally {
                    connection?.disconnect()
                    errorUploadInFlight.set(false)
                }
            }
        } catch (rejected: Throwable) {
            errorUploadInFlight.set(false)
            NativeCommunicationLogStore.tryRecord(
                targetType = NativeCommunicationTargetType.SERVER,
                direction = NativeCommunicationDirection.OUTBOUND,
                channel = "HTTP",
                operation = "错误日志上报",
                messageBody = requestSummary,
                result = "发送调度失败：${rejected::class.java.simpleName}",
                requestTimeEpochMs = requestTime,
            )
            if (!released.get()) {
                Log.w(TAG, "error log upload scheduling failed", rejected)
            }
        }
    }


    private fun readErrorReportUrl(): String {
        return readLoggingConfig().optString("errorReportUrl", DEFAULT_ERROR_REPORT_URL)
            .ifBlank { DEFAULT_ERROR_REPORT_URL }
    }

    private fun readErrorUploadEnabled(): Boolean {
        return readLoggingConfig().optBoolean("uploadEnabled", false)
    }

    private fun readLoggingConfig(): JSONObject {
        return runCatching {
            val preferences = activity.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val rawState = preferences.getString("flutter.$APP_LOCAL_STATE_KEY", null)
            if (rawState.isNullOrBlank()) {
                JSONObject()
            } else {
                JSONObject(rawState).optJSONObject("logging") ?: JSONObject()
            }
        }.getOrDefault(JSONObject())
    }

    private fun String.isErrorLikeLog(): Boolean {
        return contains("失败") ||
            contains("错误") ||
            contains("断开") ||
            contains("不支持") ||
            contains("failed", ignoreCase = true) ||
            contains("error", ignoreCase = true) ||
            contains("reconnect", ignoreCase = true)
    }

    private fun startOperationAreaStream(
        cameraId: String,
        epoch: Long,
        triggeredByReconnect: Boolean = false,
    ) {
        if (!isOperationAreaRequestCurrent(cameraId, epoch)) {
            return
        }
        cancelOperationAreaReconnect()
        if (triggeredByReconnect) {
            operationAreaStreamStatus = "正在重连第 $operationReconnectAttempts 次"
        }

        val preflight = validateConfiguredCameraForStart(
            ROLE_OPERATION_AREA,
            listOf(DEFAULT_STREAM_PROFILE),
        )
        if (!preflight.allowed) {
            operationAreaStreamStatus = preflight.failureStatus
            recordStreamFailure(
                role = ROLE_OPERATION_AREA,
                code = preflight.errorCode,
                message = preflight.failureStatus,
                stage = FAILURE_STAGE_CAMERA_PREFLIGHT,
                replaceExisting = true,
            )
            if (preflight.recoverable) {
                scheduleOperationAreaReconnect(
                    cameraId = cameraId,
                    epoch = epoch,
                    expectedStream = operationAreaStream,
                    reason = preflight.failureStatus,
                )
            } else {
                stopOperationAreaStream()
            }
            return
        }

        stopOperationAreaStream()

        try {
            val videoConfig = readVideoConfig()
            val url = buildOperationAreaRtspUrl()
            val profile = DEFAULT_STREAM_PROFILE
            val streamWidth = profile.width
            val streamHeight = profile.height
            val streamFps = profile.fps
            val streamBitrate = profile.bitrate
            val streamGopSeconds = profile.gopSeconds
            Log.i(TAG, "starting operation area RTSP H265 stream, cameraId=$cameraId, url=$url, videoConfig=$videoConfig, epoch=$epoch")
            appendOutsideEnvironmentLog("role=operationArea build=$H265_BUILD_MARK encoder=${selectH265EncoderName()} protocol=RTSP codec=H265 transport=TCP cameraId=$cameraId url=$url size=${streamWidth}x$streamHeight fps=$streamFps bitrate=$streamBitrate gop=${streamGopSeconds}s epoch=$epoch")
            appendOutsideEnvironmentLog("role=operationArea starting H265 RTSP stream, cameraId=$cameraId, url=$url, epoch=$epoch")
            lateinit var stream: H265RtspStream
            stream = createH265Stream(RkMppBridge()) { status ->
                streamHandler.post {
                    if (!isOperationAreaStreamCurrent(cameraId, epoch, stream) || operationReconnectRunnable != null) {
                        return@post
                    }
                    if (status.isSustainedStreamProgress()) {
                        operationReconnectAttempts = 0
                        if (!operationAreaFailureClearLocked) {
                            clearStreamFailure(ROLE_OPERATION_AREA)
                        }
                    } else if (status.isAnyStreamFailure()) {
                        recordStreamFailure(
                            role = ROLE_OPERATION_AREA,
                            code = streamFailureCode(status),
                            message = status,
                            stage = streamFailureStage(status),
                        )
                    }
                    operationAreaStreamStatus = status
                    Log.i(TAG, "operation area H265 status: $status, epoch=$epoch")
                    appendOutsideEnvironmentLog("role=operationArea status=$status epoch=$epoch")
                    handleOperationAreaRuntimeStatus(cameraId, epoch, stream, status)
                }
            }
            operationAreaStream = stream
            val started = stream.start(
                cameraId = cameraId,
                url = url,
                width = streamWidth,
                height = streamHeight,
                fps = streamFps,
                bitrate = streamBitrate,
                iframeInterval = streamGopSeconds,
            )
            if (!started) {
                val reason = stream.startFailureReason
                    ?.takeIf { failure -> failure.isNotBlank() }
                    ?: operationAreaStreamStatus
                if (operationAreaStream === stream) {
                    operationAreaStream = null
                }
                val failureStatus = ensureFailureStatus(reason)
                operationAreaStreamStatus = failureStatus
                recordStreamFailure(
                    role = ROLE_OPERATION_AREA,
                    code = streamFailureCode(failureStatus),
                    message = failureStatus,
                    stage = FAILURE_STAGE_STREAM_START,
                )
                Log.e(TAG, "operation area RTSP H265 stream start returned false: $failureStatus, epoch=$epoch")
                appendOutsideEnvironmentLog("role=operationArea start returned false: $failureStatus epoch=$epoch")
                if (failureStatus.isRecoverableStreamFailure()) {
                    scheduleOperationAreaReconnect(cameraId, epoch, null, failureStatus)
                }
                return
            }

            if (!isOperationAreaStreamCurrent(cameraId, epoch, stream)) {
                stream.stop()
                return
            }
            operationAreaStreamStatus = "推流启动中"
            appendOutsideEnvironmentLog("role=operationArea stream object started, epoch=$epoch")
        } catch (error: Throwable) {
            val failedStream = operationAreaStream
            runCatching { failedStream?.stop() }
            if (operationAreaStream === failedStream) {
                operationAreaStream = null
            }
            if (!isOperationAreaRequestCurrent(cameraId, epoch)) {
                return
            }
            val reason = "推流启动失败：${error.message ?: error::class.java.simpleName}"
            operationAreaStreamStatus = reason
            recordStreamFailure(
                role = ROLE_OPERATION_AREA,
                code = streamFailureCode(reason),
                message = reason,
                stage = FAILURE_STAGE_STREAM_START,
            )
            Log.e(TAG, "operation area RTSP H265 stream start failed, epoch=$epoch", error)
            appendOutsideEnvironmentLog("role=operationArea start failed, epoch=$epoch", error)
            if (reason.isRecoverableStreamFailure()) {
                scheduleOperationAreaReconnect(cameraId, epoch, null, reason)
            }
        }
    }

    private fun stopOperationAreaStream() {
        val stream = operationAreaStream ?: return
        runCatching { stream.stop() }
            .onFailure { error -> appendOutsideEnvironmentLog("role=operationArea stop failed", error) }
        if (operationAreaStream === stream) {
            operationAreaStream = null
        }
        appendOutsideEnvironmentLog("role=operationArea stream stopped")
    }

    private fun scheduleOperationAreaReconnect(
        cameraId: String,
        epoch: Long,
        expectedStream: H265RtspStream?,
        reason: String,
    ) {
        if (!isOperationAreaRequestCurrent(cameraId, epoch) || operationAreaStream !== expectedStream) {
            return
        }
        cancelOperationAreaReconnect()
        if (operationReconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
            operationAreaStreamStatus = "推流重连失败，已达到最大次数：$reason"
            runCatching { expectedStream?.stop() }
                .onFailure { error -> appendOutsideEnvironmentLog("role=operationArea max-retry stop failed, epoch=$epoch", error) }
            operationAreaStream = null
            Log.e(TAG, "operation area RTSP H265 stream reconnect failed, max attempts reached")
            appendOutsideEnvironmentLog("role=operationArea reconnect failed, max attempts reached, reason=$reason, epoch=$epoch")
            return
        }
        operationReconnectAttempts += 1
        operationReconnectingCameraId = cameraId
        val reconnectDelayMs = reconnectDelayMs(operationReconnectAttempts)
        lateinit var task: Runnable
        task = Runnable {
            if (operationReconnectRunnable !== task) {
                return@Runnable
            }
            operationReconnectRunnable = null
            operationReconnectingCameraId = null
            if (!isOperationAreaRequestCurrent(cameraId, epoch) || operationAreaStream !== expectedStream) {
                return@Runnable
            }
            startOperationAreaStream(cameraId, epoch, triggeredByReconnect = true)
        }
        operationReconnectRunnable = task
        streamHandler.postDelayed(task, reconnectDelayMs)
        operationAreaStreamStatus = "推流断开：$reason，${reconnectDelayMs / 1000} 秒后重连第 $operationReconnectAttempts 次"
        Log.w(TAG, "operation area RTSP H265 stream reconnect scheduled, cameraId=$cameraId, attempt=$operationReconnectAttempts, epoch=$epoch")
        appendOutsideEnvironmentLog("role=operationArea reconnect scheduled, cameraId=$cameraId, attempt=$operationReconnectAttempts, epoch=$epoch")
    }

    private fun handleOperationAreaRuntimeStatus(
        cameraId: String,
        epoch: Long,
        stream: H265RtspStream,
        status: String,
    ) {
        if (!status.isAnyStreamFailure() ||
            !isOperationAreaStreamCurrent(cameraId, epoch, stream) ||
            operationReconnectRunnable != null
        ) {
            return
        }
        val recoverable = status.isRecoverableStreamFailure()
        runCatching { stream.stop() }
            .onFailure { error -> appendOutsideEnvironmentLog("role=operationArea runtime stop failed, epoch=$epoch", error) }
        if (recoverable) {
            scheduleOperationAreaReconnect(cameraId, epoch, stream, status)
        } else if (operationAreaStream === stream) {
            operationAreaStream = null
        }
    }

    private fun isOperationAreaRequestCurrent(cameraId: String, epoch: Long): Boolean {
        return !released.get() && operationAreaDesired && operationAreaStreamEpoch == epoch &&
            operationAreaCameraId == cameraId
    }

    private fun isOperationAreaStreamCurrent(
        cameraId: String,
        epoch: Long,
        stream: H265RtspStream,
    ): Boolean {
        return isOperationAreaRequestCurrent(cameraId, epoch) && operationAreaStream === stream
    }

    private fun cancelOperationAreaReconnect() {
        operationReconnectRunnable?.let(streamHandler::removeCallbacks)
        operationReconnectRunnable = null
        operationReconnectingCameraId = null
    }

    private fun validateConfiguredCameraForStart(role: String, profiles: List<StreamProfile>): CameraPreflightResult {
        val snapshot = probeCameraCapability(role)
        val supportedSizeKeys = snapshot.yuvSupportedSizes
            .mapTo(mutableSetOf()) { size -> "${size.width}x${size.height}" }
        val unsupportedProfiles = profiles.filterNot { profile ->
            supportedSizeKeys.contains("${profile.width}x${profile.height}")
        }
        if (snapshot.available && unsupportedProfiles.isEmpty()) {
            return CameraPreflightResult(
                allowed = true,
                recoverable = false,
                errorCode = "",
                failureStatus = "",
            )
        }
        val unsupportedSizeMessage = if (unsupportedProfiles.isNotEmpty() && snapshot.yuvSupportedSizes.isNotEmpty()) {
            val requested = unsupportedProfiles.joinToString(",") { profile ->
                "${profile.name}(${profile.width}x${profile.height})"
            }
            val supported = snapshot.yuvSupportedSizes.joinToString(",") { size ->
                "${size.width}x${size.height}"
            }
            "推流分辨率不支持：请求 $requested，摄像头 ID ${snapshot.configuredCameraId} 支持 $supported"
        } else {
            ""
        }
        val errorCode = when {
            unsupportedSizeMessage.isNotBlank() -> "UNSUPPORTED_STREAM_SIZE"
            snapshot.errorCode.isNotBlank() -> snapshot.errorCode
            else -> "CAMERA_UNAVAILABLE"
        }
        val message = unsupportedSizeMessage.ifBlank {
            snapshot.errorMessage.ifBlank {
                "摄像头不可用：配置 ID ${snapshot.configuredCameraId}"
            }
        }
        val status = ensureFailureStatus(message)
        when (role) {
            ROLE_OUTSIDE_ENVIRONMENT -> {
                outsideEnvironmentCameraId = snapshot.configuredCameraId
                outsideEnvironmentStreamStatus = status
            }
            ROLE_OPERATION_AREA -> {
                operationAreaCameraId = snapshot.configuredCameraId
                operationAreaStreamStatus = status
            }
        }
        recordStreamFailure(
            role = role,
            code = errorCode,
            message = message,
            stage = FAILURE_STAGE_CAMERA_PREFLIGHT,
        )
        Log.e(
            TAG,
            "camera stream preflight failed, role=$role, configured=${snapshot.configuredCameraId}, " +
                "available=${snapshot.availableCameraIds}, code=$errorCode, message=$message",
        )
        appendOutsideEnvironmentLog(
            "role=$role camera preflight failed, configured=${snapshot.configuredCameraId}, " +
                "available=${snapshot.availableCameraIds}, code=$errorCode, message=$message",
        )
        return CameraPreflightResult(
            allowed = false,
            recoverable = isPreflightFailureRecoverable(errorCode),
            errorCode = errorCode,
            failureStatus = status,
        )
    }

    private fun isPreflightFailureRecoverable(errorCode: String): Boolean {
        return when (errorCode) {
            "CAMERA_IN_USE",
            "MAX_CAMERAS_IN_USE",
            "CAMERA_DISCONNECTED",
            "CAMERA_OFFLINE",
            "CAMERA_DEVICE",
            "CAMERA_SERVICE",
            "CAMERA_ERROR",
            "CAMERA_ACCESS_FAILED" -> true
            else -> false
        }
    }

    private fun probeCameraCapability(role: String): CameraCapabilitySnapshot {
        val configuredCameraId = configuredCameraIdForRole(role)
        val cameraManager = activity.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val availableCameraIds = try {
            cameraManager.cameraIdList.toList()
        } catch (error: Throwable) {
            return CameraCapabilitySnapshot(
                configuredCameraId = configuredCameraId,
                availableCameraIds = emptyList(),
                available = false,
                yuvSupportedSizes = emptyList(),
                errorCode = cameraAccessFailureCode(error),
                errorMessage = describeCameraAccessFailure(configuredCameraId, error),
            )
        }
        if (!availableCameraIds.contains(configuredCameraId)) {
            val noCameras = availableCameraIds.isEmpty()
            return CameraCapabilitySnapshot(
                configuredCameraId = configuredCameraId,
                availableCameraIds = availableCameraIds,
                available = false,
                yuvSupportedSizes = emptyList(),
                errorCode = if (noCameras) "CAMERA_OFFLINE" else "UNKNOWN_CAMERA_ID",
                errorMessage = if (noCameras) {
                    "摄像头离线：未检测到任何可用摄像头（配置 ID：$configuredCameraId）"
                } else {
                    "未知摄像头 ID $configuredCameraId，当前可用 ID：${availableCameraIds.joinToString(",")}"
                },
            )
        }
        val yuvSupportedSizes = try {
            val characteristics = cameraManager.getCameraCharacteristics(configuredCameraId)
            val streamMap = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
            streamMap?.getOutputSizes(ImageFormat.YUV_420_888).orEmpty()
                .sortedWith(
                    compareByDescending<android.util.Size> { size ->
                        size.width.toLong() * size.height.toLong()
                    }.thenByDescending { size -> size.width },
                )
                .map { size -> CameraOutputSize(size.width, size.height) }
                .distinct()
        } catch (error: Throwable) {
            return CameraCapabilitySnapshot(
                configuredCameraId = configuredCameraId,
                availableCameraIds = availableCameraIds,
                available = true,
                yuvSupportedSizes = emptyList(),
                errorCode = cameraAccessFailureCode(error),
                errorMessage = describeCameraAccessFailure(configuredCameraId, error),
            )
        }
        return CameraCapabilitySnapshot(
            configuredCameraId = configuredCameraId,
            availableCameraIds = availableCameraIds,
            available = true,
            yuvSupportedSizes = yuvSupportedSizes,
            errorCode = if (yuvSupportedSizes.isEmpty()) "YUV_OUTPUT_UNAVAILABLE" else "",
            errorMessage = if (yuvSupportedSizes.isEmpty()) {
                "摄像头 ID $configuredCameraId 未报告 YUV_420_888 输出尺寸"
            } else {
                ""
            },
        )
    }

    private fun configuredCameraIdForRole(role: String): String {
        return when (role) {
            ROLE_FACE_RECOGNITION -> FACE_RECOGNITION_CAMERA_ID
            ROLE_OUTSIDE_ENVIRONMENT -> OUTSIDE_ENVIRONMENT_CAMERA_ID
            ROLE_OPERATION_AREA -> OPERATION_AREA_CAMERA_ID
            ROLE_CERTIFICATE_CAPTURE -> CERTIFICATE_CAPTURE_CAMERA_ID
            else -> throw IllegalArgumentException("unsupported camera role: $role")
        }
    }

    private fun configuredProfilesForRole(role: String): List<StreamProfile> {
        return when (role) {
            ROLE_OUTSIDE_ENVIRONMENT -> STREAM_PROFILES
            ROLE_OPERATION_AREA -> listOf(DEFAULT_STREAM_PROFILE)
            ROLE_FACE_RECOGNITION, ROLE_CERTIFICATE_CAPTURE -> emptyList()
            else -> throw IllegalArgumentException("unsupported camera role: $role")
        }
    }

    private fun createH265Stream(bridge: RkMppBridge, statusListener: (String) -> Unit): H265RtspStream {
        return if (shouldUseRkMppH265()) {
            RkMppH265Stream(activity.applicationContext, bridge, statusListener)
        } else {
            MediaCodecH265Stream(activity.applicationContext, statusListener)
        }
    }

    private fun selectH265EncoderName(): String {
        return if (shouldUseRkMppH265()) "rkmpp" else "mediacodec"
    }

    private fun recordStreamFailure(
        role: String,
        code: String,
        message: String,
        stage: String,
        replaceExisting: Boolean = false,
    ) {
        when (role) {
            ROLE_OUTSIDE_ENVIRONMENT -> {
                if (replaceExisting || outsideEnvironmentLastErrorMessage.isBlank()) {
                    outsideEnvironmentLastErrorCode = code
                    outsideEnvironmentLastErrorMessage = message
                    outsideEnvironmentFailureStage = stage
                }
            }
            ROLE_OPERATION_AREA -> {
                if (replaceExisting || operationAreaLastErrorMessage.isBlank()) {
                    operationAreaLastErrorCode = code
                    operationAreaLastErrorMessage = message
                    operationAreaFailureStage = stage
                }
            }
        }
    }

    private fun clearStreamFailure(role: String) {
        when (role) {
            ROLE_OUTSIDE_ENVIRONMENT -> {
                outsideEnvironmentLastErrorCode = ""
                outsideEnvironmentLastErrorMessage = ""
                outsideEnvironmentFailureStage = ""
            }
            ROLE_OPERATION_AREA -> {
                operationAreaLastErrorCode = ""
                operationAreaLastErrorMessage = ""
                operationAreaFailureStage = ""
            }
        }
    }

    private fun streamFailureCode(status: String): String {
        return when {
            status.contains("UNSUPPORTED_STREAM_SIZE", ignoreCase = true) || status.contains("分辨率不支持") ||
                status.contains("image size mismatch", ignoreCase = true) || status.contains("尺寸不匹配") -> "UNSUPPORTED_STREAM_SIZE"
            status.contains("UNSUPPORTED_STREAM_COMBINATION", ignoreCase = true) || status.contains("会话配置失败") -> "UNSUPPORTED_STREAM_COMBINATION"
            status.contains("YUV_OUTPUT_UNAVAILABLE", ignoreCase = true) || status.contains("未报告 YUV_420_888") -> "YUV_OUTPUT_UNAVAILABLE"
            status.contains("MAX_CAMERAS_IN_USE", ignoreCase = true) -> "MAX_CAMERAS_IN_USE"
            status.contains("CAMERA_IN_USE", ignoreCase = true) || status.contains("被占用") -> "CAMERA_IN_USE"
            status.contains("UNKNOWN_CAMERA_ID", ignoreCase = true) || status.contains("未知摄像头") -> "UNKNOWN_CAMERA_ID"
            status.contains("CAMERA_DISCONNECTED", ignoreCase = true) || status.contains("离线") || status.contains("断开") -> "CAMERA_DISCONNECTED"
            status.contains("CAMERA_DISABLED", ignoreCase = true) || status.contains("系统策略禁用") -> "CAMERA_DISABLED"
            status.contains("CAMERA_PERMISSION_DENIED", ignoreCase = true) || status.contains("缺少摄像头权限") -> "CAMERA_PERMISSION_DENIED"
            status.contains("CAMERA_DEVICE", ignoreCase = true) -> "CAMERA_DEVICE"
            status.contains("CAMERA_SERVICE", ignoreCase = true) -> "CAMERA_SERVICE"
            status.contains("CAMERA_ERROR", ignoreCase = true) || status.contains("摄像头错误") -> "CAMERA_ERROR"
            status.containsRtspClientErrorCode() -> "RTSP_CLIENT_ERROR"
            status.contains("RTSP host is empty", ignoreCase = true) ||
                status.contains("URI syntax", ignoreCase = true) ||
                status.contains("URISyntaxException", ignoreCase = true) ||
                status.contains("Illegal character in", ignoreCase = true) -> "INVALID_RTSP_URL"
            status.contains("RTSP", ignoreCase = true) || status.contains("Broken pipe", ignoreCase = true) -> "RTSP_ERROR"
            status.contains("编码") || status.contains("RKMPP", ignoreCase = true) -> "ENCODER_ERROR"
            else -> "STREAM_FAILED"
        }
    }

    private fun streamFailureStage(status: String): String {
        return when {
            status.contains("摄像头") || status.contains("CAMERA_", ignoreCase = true) -> FAILURE_STAGE_CAMERA_RUNTIME
            status.contains("RTSP", ignoreCase = true) || status.contains("Broken pipe", ignoreCase = true) -> FAILURE_STAGE_RTSP
            status.contains("编码") || status.contains("RKMPP", ignoreCase = true) -> FAILURE_STAGE_ENCODER
            else -> FAILURE_STAGE_STREAM_RUNTIME
        }
    }

    private fun ensureFailureStatus(reason: String): String {
        return if (reason.contains("失败") || reason.contains("错误")) reason else "推流失败：$reason"
    }

    private fun String.isAnyStreamFailure(): Boolean {
        return isRecoverableStreamFailure() || contains("失败") || contains("错误") ||
            contains("被占用") || contains("离线") || contains("未知摄像头") ||
            contains("缺少摄像头权限") || contains("系统策略禁用")
    }

    private fun String.isRecoverableStreamFailure(): Boolean {
        if (contains("重连失败") || contains("达到最大次数")) {
            return false
        }
        val failureCode = streamFailureCode(this)
        if (!isFailureCodeRecoverable(failureCode)) {
            return false
        }
        return contains("失败") ||
            contains("错误") ||
            contains("被占用") ||
            contains("离线") ||
            contains("断开") ||
            contains("异常") ||
            contains("Broken pipe", ignoreCase = true) ||
            contains("failed", ignoreCase = true) ||
            contains("error", ignoreCase = true)
    }

    private fun isFailureCodeRecoverable(errorCode: String): Boolean {
        return when (errorCode) {
            "UNSUPPORTED_STREAM_SIZE",
            "UNSUPPORTED_STREAM_COMBINATION",
            "YUV_OUTPUT_UNAVAILABLE",
            "UNKNOWN_CAMERA_ID",
            "CAMERA_PERMISSION_DENIED",
            "CAMERA_DISABLED",
            "CAMERA_UNAVAILABLE",
            "RTSP_CLIENT_ERROR",
            "INVALID_RTSP_URL" -> false
            else -> true
        }
    }

    private fun isStreamFailureRecoverable(status: String, lastErrorCode: String): Boolean {
        if (status.contains("重连失败") || status.contains("达到最大次数")) {
            return false
        }
        if (lastErrorCode.isNotBlank() && !isFailureCodeRecoverable(lastErrorCode)) {
            return false
        }
        if (status.isRecoverableStreamFailure()) {
            return true
        }
        return status.contains("重连") && lastErrorCode.isNotBlank() &&
            isFailureCodeRecoverable(lastErrorCode)
    }

    private fun String.containsRtspClientErrorCode(): Boolean {
        val markerIndex = indexOf("code=", ignoreCase = true)
        if (markerIndex < 0) {
            return false
        }
        val code = substring(markerIndex + "code=".length)
            .takeWhile(Char::isDigit)
            .toIntOrNull()
        return code != null && code in 400..499
    }

    private fun String.isSustainedStreamProgress(): Boolean {
        val pushedFrames = Regex("""\bpushed=(\d+)""")
            .find(this)
            ?.groupValues
            ?.getOrNull(1)
            ?.toLongOrNull()
        return pushedFrames != null && pushedFrames > 0L && !isRecoverableStreamFailure()
    }

    private fun streamStateName(status: String): String {
        return when {
            status.contains("未配置") || status.contains("未指定") -> STREAM_STATE_UNCONFIGURED
            status.contains("重连失败") || status.contains("达到最大次数") -> STREAM_STATE_FAILED
            status.contains("重连") || status.contains("reconnect", ignoreCase = true) -> STREAM_STATE_RECONNECTING
            status.isRecoverableStreamFailure() || status.contains("失败") || status.contains("错误") -> STREAM_STATE_FAILED
            status.contains("启动中") || status.contains("打开中") -> STREAM_STATE_STARTING
            status.contains("停止") || status.contains("未启动") -> STREAM_STATE_STOPPED
            status.contains("推流中") || status.contains("已开始") -> STREAM_STATE_STREAMING
            else -> STREAM_STATE_UNKNOWN
        }
    }

    private fun reconnectDelayMs(attempt: Int): Long {
        val exponent = (attempt - 1).coerceIn(0, 5)
        return minOf(MAX_RECONNECT_DELAY_MS, RECONNECT_DELAY_MS * (1L shl exponent))
    }

    private fun shouldUseRkMppH265(): Boolean {
        val hardware = Build.HARDWARE.orEmpty().lowercase(Locale.US)
        val board = Build.BOARD.orEmpty().lowercase(Locale.US)
        val manufacturer = Build.MANUFACTURER.orEmpty().lowercase(Locale.US)
        return hardware.contains("rk") || board.contains("rk") ||
            manufacturer.contains("rockchip")
    }

    private fun buildOutsideEnvironmentRtspUrl(profile: StreamProfile): String {
        val androidId = Settings.Secure.getString(
            activity.contentResolver,
            Settings.Secure.ANDROID_ID,
        ) ?: "unknown"
        val deviceStreamUrl = normalizeRtspStreamUrl(readVideoStreamUrl(), androidId)
        return "${deviceStreamUrl.trimEnd('/')}/${profile.name}"
    }

    private fun buildOperationAreaRtspUrl(): String {
        val androidId = Settings.Secure.getString(
            activity.contentResolver,
            Settings.Secure.ANDROID_ID,
        ) ?: "unknown"
        return "${normalizeRtspStreamUrl(readVideoStreamUrl(), androidId).trimEnd('/')}-operation"
    }

    private fun findStreamProfile(profileName: String): StreamProfile? {
        return STREAM_PROFILES.firstOrNull { profile ->
            profile.name.equals(profileName.trim(), ignoreCase = true)
        }
    }

    private fun readVideoStreamUrl(): String {
        return readVideoConfig().optString("streamUrl", DEFAULT_STREAM_BASE_URL)
            .ifBlank { DEFAULT_STREAM_BASE_URL }
    }

    private fun readVideoConfig(): JSONObject {
        return runCatching {
            val preferences = activity.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val rawState = preferences.getString("flutter.$APP_LOCAL_STATE_KEY", null)
            if (rawState.isNullOrBlank()) {
                JSONObject()
            } else {
                JSONObject(rawState).optJSONObject("video") ?: JSONObject()
            }
        }.getOrDefault(JSONObject())
    }

    private fun normalizeRtspStreamUrl(rawUrl: String, androidId: String): String {
        val trimmed = rawUrl.trim().trimEnd('/')
        val rtspUrl = when {
            trimmed.startsWith("rtsp://", ignoreCase = true) -> trimmed
            trimmed.equals("http://127.0.0.1", ignoreCase = true) -> DEFAULT_STREAM_BASE_URL
            trimmed.equals("https://127.0.0.1", ignoreCase = true) -> DEFAULT_STREAM_BASE_URL
            trimmed.startsWith("http://", ignoreCase = true) -> "rtsp://${trimmed.removePrefixIgnoreCase("http://")}"
            trimmed.startsWith("https://", ignoreCase = true) -> "rtsp://${trimmed.removePrefixIgnoreCase("https://")}"
            trimmed.isNotBlank() -> "rtsp://$trimmed"
            else -> DEFAULT_STREAM_BASE_URL
        }.trimEnd('/')

        return if (rtspUrl.substringAfterLast('/').equals(androidId, ignoreCase = false) ||
            rtspUrl.substringAfterLast('/').endsWith("-operation")
        ) {
            rtspUrl
        } else {
            "$rtspUrl/app/$androidId".replace("/app/app/", "/app/")
        }
    }

    private fun String.removePrefixIgnoreCase(prefix: String): String {
        return if (startsWith(prefix, ignoreCase = true)) substring(prefix.length) else this
    }

    fun keepScreenOn() {
        activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    fun hideSystemBars() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            activity.window.insetsController?.hide(
                android.view.WindowInsets.Type.statusBars() or
                    android.view.WindowInsets.Type.navigationBars(),
            )
        } else {
            @Suppress("DEPRECATION")
            activity.window.decorView.systemUiVisibility =
                android.view.View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                    android.view.View.SYSTEM_UI_FLAG_FULLSCREEN or
                    android.view.View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                    android.view.View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                    android.view.View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                    android.view.View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        }
    }

    private fun addUserRestrictions() {
        listOf(
            UserManager.DISALLOW_FACTORY_RESET,
            UserManager.DISALLOW_SAFE_BOOT,
            UserManager.DISALLOW_ADD_USER,
            UserManager.DISALLOW_MOUNT_PHYSICAL_MEDIA,
            UserManager.DISALLOW_ADJUST_VOLUME,
            UserManager.DISALLOW_SYSTEM_ERROR_DIALOGS,
            UserManager.DISALLOW_CREATE_WINDOWS,
        ).forEach { restriction ->
            devicePolicyManager.addUserRestriction(adminComponent, restriction)
        }
    }

    private fun clearUserRestrictions() {
        listOf(
            UserManager.DISALLOW_ADJUST_VOLUME,
            UserManager.DISALLOW_SYSTEM_ERROR_DIALOGS,
            UserManager.DISALLOW_CREATE_WINDOWS,
        ).forEach { restriction ->
            devicePolicyManager.clearUserRestriction(adminComponent, restriction)
        }
    }

    private data class CameraOutputSize(
        val width: Int,
        val height: Int,
    )

    private data class CameraCapabilitySnapshot(
        val configuredCameraId: String,
        val availableCameraIds: List<String>,
        val available: Boolean,
        val yuvSupportedSizes: List<CameraOutputSize>,
        val errorCode: String,
        val errorMessage: String,
    )

    private data class CameraPreflightResult(
        val allowed: Boolean,
        val recoverable: Boolean,
        val errorCode: String,
        val failureStatus: String,
    )

    companion object {
        private data class StreamProfile(
            val name: String,
            val width: Int,
            val height: Int,
            val fps: Int,
            val bitrate: Int,
            val gopSeconds: Int,
        )

        private val STREAM_PROFILES = listOf(
            StreamProfile("720p", 1280, 720, 15, 2000 * 1000, 1),
            StreamProfile("1080p", 1920, 1080, 15, 5000 * 1000, 1),
        )
        private val HTTP_METHOD_PATTERN = Regex("[A-Z]{1,16}")
        private val DEFAULT_STREAM_PROFILE = STREAM_PROFILES.first { profile -> profile.name == "720p" }
        private const val RECONNECT_DELAY_MS = 3000L
        private const val MAX_RECONNECT_DELAY_MS = 60_000L
        private const val LOG_QUEUE_CAPACITY = 256
        private const val MAX_RECONNECT_ATTEMPTS = 100
        private const val ERROR_UPLOAD_FAILURE_COOLDOWN_MS = 60_000L
        private const val TAG = "SmartCabinetStream"
        private const val H265_BUILD_MARK = "rkmpp-h265-stability-20260713"
        private const val APP_LOCAL_STATE_KEY = "app.localState"
        private const val OUTSIDE_ENVIRONMENT_LOG_FILE_NAME = "smart_cabinet_rtsp_h265.log"
        private const val UNIFIED_ERROR_LOG_FILE_NAME = "smart_cabinet_error.log"
        private const val DEFAULT_ERROR_REPORT_URL = "http://192.168.1.100:3000/api/logs/error"
        private const val DEFAULT_STREAM_BASE_URL = "rtsp://183.56.183.39:8888/app"
        private const val STREAM_CONTROL_PORT = 18080
        private const val STREAM_CONTROL_TIMEOUT_MS = 15_000L
        private const val STREAM_CONTROL_CLIENT_READ_TIMEOUT_MS = 3_000
        private const val DOWNLOADS_LOG_PATH = "Download/SmartCabinetLogs/smart_cabinet_rtsp_h265.log"
        private const val OUTSIDE_ENVIRONMENT_STREAM_MODE = "dual_active_profiles"
        private const val ROLE_FACE_RECOGNITION = "faceRecognition"
        private const val ROLE_OUTSIDE_ENVIRONMENT = "outsideEnvironment"
        private const val ROLE_OPERATION_AREA = "operationArea"
        private const val ROLE_CERTIFICATE_CAPTURE = "certificateCapture"
        private const val FACE_RECOGNITION_CAMERA_ID = "0"
        private const val OUTSIDE_ENVIRONMENT_CAMERA_ID = "1"
        private const val OPERATION_AREA_CAMERA_ID = "2"
        private const val CERTIFICATE_CAPTURE_CAMERA_ID = "3"
        private const val FAILURE_STAGE_CAMERA_PREFLIGHT = "camera_preflight"
        private const val FAILURE_STAGE_CAMERA_RUNTIME = "camera_runtime"
        private const val FAILURE_STAGE_STREAM_START = "stream_start"
        private const val FAILURE_STAGE_STREAM_RUNTIME = "stream_runtime"
        private const val FAILURE_STAGE_ENCODER = "encoder"
        private const val FAILURE_STAGE_RTSP = "rtsp"
        private const val STREAM_STATE_STOPPED = "stopped"
        private const val STREAM_STATE_STARTING = "starting"
        private const val STREAM_STATE_STREAMING = "streaming"
        private const val STREAM_STATE_RECONNECTING = "reconnecting"
        private const val STREAM_STATE_FAILED = "failed"
        private const val STREAM_STATE_UNCONFIGURED = "unconfigured"
        private const val STREAM_STATE_UNKNOWN = "unknown"
    }

}
