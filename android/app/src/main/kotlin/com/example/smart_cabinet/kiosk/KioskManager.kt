package com.example.smart_cabinet.kiosk

import android.app.Activity
import android.app.ActivityManager
import android.app.admin.DevicePolicyManager
import android.content.ContentValues
import android.content.pm.PackageManager
import android.content.ComponentName
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
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class KioskManager(private val activity: Activity) {
    private var outsideEnvironmentStream: DualMediaCodecH265Stream? = null

    private var operationAreaStream: H265RtspStream? = null

    private val rkMppBridge by lazy { RkMppBridge() }

    private var outsideEnvironmentStreamStatus: String = "未启动"

    private var operationAreaStreamStatus: String = "未启动"

    private var activeOutsideEnvironmentProfiles: List<StreamProfile> = emptyList()

    private var enabledOutsideEnvironmentProfiles: Set<String> = emptySet()

    private var outsideEnvironmentCameraId: String = ""

    private var operationAreaCameraId: String = ""

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

    @Volatile
    private var errorUploadMutedUntilMs = 0L

    private val reconnectRunnable = Runnable {
        val cameraId = reconnectingCameraId
            ?: outsideEnvironmentCameraId
        startOutsideEnvironmentStream(cameraId, triggeredByReconnect = true)
    }

    private val operationReconnectRunnable = Runnable {
        val cameraId = operationReconnectingCameraId
            ?: operationAreaCameraId
        if (!cameraId.isNullOrBlank()) {
            startOperationAreaStream(cameraId, triggeredByReconnect = true)
        }
    }

    private val devicePolicyManager: DevicePolicyManager =
        activity.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager

    private val activityManager: ActivityManager =
        activity.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager

    init {
        enabledOutsideEnvironmentProfiles = readEnabledVideoStreamSwitches()
    }

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

    fun startStreamProfile(profileName: String, cameraId: String) {
        val profile = findStreamProfile(profileName)
            ?: throw IllegalArgumentException("unsupported stream profile: $profileName")
        outsideEnvironmentCameraId = cameraId
        enabledOutsideEnvironmentProfiles = enabledOutsideEnvironmentProfiles + profile.name
        updateVideoStreamSwitch(profile.name, true)
        Log.i(TAG, "start outside environment stream profile on demand, requestedProfile=$profileName, enabled=$enabledOutsideEnvironmentProfiles, cameraId=$cameraId")
        startOutsideEnvironmentStream(cameraId, resetReconnect = true)
    }

    fun startCameraStream(role: String, profiles: List<String>) {
        when (role) {
            ROLE_OUTSIDE_ENVIRONMENT -> {
                val cameraId = OUTSIDE_ENVIRONMENT_CAMERA_ID
                val requestedProfiles = profiles.mapNotNull(::findStreamProfile)
                require(requestedProfiles.isNotEmpty()) { "no supported stream profiles requested" }
                outsideEnvironmentCameraId = cameraId
                enabledOutsideEnvironmentProfiles = enabledOutsideEnvironmentProfiles + requestedProfiles.map { profile -> profile.name }
                requestedProfiles.forEach { profile -> updateVideoStreamSwitch(profile.name, true) }
                Log.i(TAG, "start camera stream by role, role=$role, profiles=${requestedProfiles.map { it.name }}, cameraId=$cameraId")
                startOutsideEnvironmentStream(cameraId, resetReconnect = true)
            }
            ROLE_OPERATION_AREA -> {
                val cameraId = OPERATION_AREA_CAMERA_ID
                require(cameraId.isNotBlank()) { "operation area camera is not configured" }
                operationAreaCameraId = cameraId
                startOperationAreaStream(cameraId, resetReconnect = true)
            }
            else -> throw IllegalArgumentException("unsupported camera stream role: $role")
        }
    }

    fun stopStreamProfile(profileName: String, cameraId: String) {
        val profile = findStreamProfile(profileName)
            ?: throw IllegalArgumentException("unsupported stream profile: $profileName")
        outsideEnvironmentCameraId = cameraId
        enabledOutsideEnvironmentProfiles = enabledOutsideEnvironmentProfiles - profile.name
        updateVideoStreamSwitch(profile.name, false)
        streamHandler.removeCallbacks(reconnectRunnable)
        reconnectAttempts = 0
        reconnectingCameraId = null
        if (enabledOutsideEnvironmentProfiles.isEmpty()) {
            stopOutsideEnvironmentStream()
            outsideEnvironmentStreamStatus = "720p/1080p 已停止"
            return
        }
        Log.i(TAG, "stop outside environment stream profile on demand, requestedProfile=$profileName, remaining=$enabledOutsideEnvironmentProfiles, cameraId=$cameraId")
        startOutsideEnvironmentStream(cameraId, resetReconnect = true)
    }

    fun stopCameraStream(role: String, profiles: List<String>) {
        when (role) {
            ROLE_OUTSIDE_ENVIRONMENT -> {
                val cameraId = OUTSIDE_ENVIRONMENT_CAMERA_ID
                outsideEnvironmentCameraId = cameraId
                val requestedProfiles = if (profiles.isEmpty()) {
                    STREAM_PROFILES
                } else {
                    profiles.mapNotNull(::findStreamProfile)
                }
                requestedProfiles.forEach { profile ->
                    enabledOutsideEnvironmentProfiles = enabledOutsideEnvironmentProfiles - profile.name
                    updateVideoStreamSwitch(profile.name, false)
                }
                streamHandler.removeCallbacks(reconnectRunnable)
                reconnectAttempts = 0
                reconnectingCameraId = null
                if (enabledOutsideEnvironmentProfiles.isEmpty()) {
                    stopOutsideEnvironmentStream()
                    outsideEnvironmentStreamStatus = "720p/1080p 已停止"
                    return
                }
                Log.i(TAG, "stop camera stream by role, role=$role, stopped=${requestedProfiles.map { it.name }}, remaining=$enabledOutsideEnvironmentProfiles, cameraId=$cameraId")
                startOutsideEnvironmentStream(cameraId, resetReconnect = true)
            }
            ROLE_OPERATION_AREA -> {
                streamHandler.removeCallbacks(operationReconnectRunnable)
                operationReconnectAttempts = 0
                operationReconnectingCameraId = null
                stopOperationAreaStream()
                operationAreaStreamStatus = "已停止"
            }
            else -> throw IllegalArgumentException("unsupported camera stream role: $role")
        }
    }

    fun applyConfiguredStreamSwitches() {
        enabledOutsideEnvironmentProfiles = readEnabledVideoStreamSwitches()
        if (enabledOutsideEnvironmentProfiles.isEmpty()) {
            outsideEnvironmentStreamStatus = "720p/1080p 已停止"
            return
        }
        val cameraId = outsideEnvironmentCameraId
        val resolvedCameraId = cameraId.ifBlank { OUTSIDE_ENVIRONMENT_CAMERA_ID }
        outsideEnvironmentCameraId = resolvedCameraId
        if (resolvedCameraId.isBlank()) {
            outsideEnvironmentStreamStatus = "未指定柜外环境摄像头"
            return
        }
        Log.i(TAG, "apply configured outside environment stream switches, enabled=$enabledOutsideEnvironmentProfiles, cameraId=$resolvedCameraId")
        startOutsideEnvironmentStream(resolvedCameraId, resetReconnect = true)
    }

    fun readOutsideEnvironmentStreamStatus(): Map<String, String> {
        return linkedMapOf(
            "status" to outsideEnvironmentStreamStatus,
            "state" to streamStateName(outsideEnvironmentStreamStatus),
            "role" to ROLE_OUTSIDE_ENVIRONMENT,
            "recoverable" to outsideEnvironmentStreamStatus.isRecoverableStreamFailure().toString(),
            "reconnectAttempts" to reconnectAttempts.toString(),
            "url" to activeOutsideEnvironmentProfiles.joinToString(",") { profile -> buildOutsideEnvironmentRtspUrl(profile) },
            "cameraId" to outsideEnvironmentCameraId,
            "profile" to activeOutsideEnvironmentProfiles.joinToString(",") { profile -> profile.name },
            "enabledProfiles" to enabledOutsideEnvironmentProfiles.joinToString(","),
            "streamMode" to if (activeOutsideEnvironmentProfiles.size > 1) OUTSIDE_ENVIRONMENT_STREAM_MODE else "profile_active",
            "logFile" to outsideEnvironmentLogFile().absolutePath,
            "downloadsLogFile" to DOWNLOADS_LOG_PATH,
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
            )
        }
        return linkedMapOf(
            "status" to operationAreaStreamStatus,
            "state" to streamStateName(operationAreaStreamStatus),
            "role" to ROLE_OPERATION_AREA,
            "recoverable" to operationAreaStreamStatus.isRecoverableStreamFailure().toString(),
            "reconnectAttempts" to operationReconnectAttempts.toString(),
            "url" to buildOperationAreaRtspUrl(),
            "cameraId" to operationAreaCameraId,
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

    private fun handleStreamControlSocket(socket: Socket) {
        socket.use { clientSocket ->
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
            writeHttpJsonResponse(clientSocket, response.first, response.second)
        }
    }

    private fun handleStreamControlRequest(requestLine: String, body: String): Pair<Int, JSONObject> {
        val parts = requestLine.split(' ')
        val method = parts.getOrNull(0).orEmpty().uppercase(Locale.US)
        val path = parts.getOrNull(1).orEmpty().substringBefore('?')
        return runCatching {
            when {
                method == "GET" && path == "/stream/status" -> 200 to streamControlStatusJson()
                method == "POST" && path == "/stream/profile" -> {
                    val payload = JSONObject(body.ifBlank { "{}" })
                    val profileName = payload.optString("profile")
                    if (findStreamProfile(profileName) == null) {
                        return 400 to streamControlErrorJson("unsupported profile: $profileName")
                    }
                    400 to streamControlErrorJson("stream profile changes must be requested from Flutter with a cameraId")
                }
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

    private fun updateVideoStreamSwitch(profileName: String, enabled: Boolean) {
        runCatching {
            val preferences = activity.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val rawState = preferences.getString("flutter.$APP_LOCAL_STATE_KEY", null)
            val stateJson = if (rawState.isNullOrBlank()) JSONObject() else JSONObject(rawState)
            val videoJson = stateJson.optJSONObject("video") ?: JSONObject()
            val switchJson = videoJson.optJSONObject("streamSwitches") ?: JSONObject()
            switchJson.put(profileName, enabled)
            videoJson.put("streamSwitches", switchJson)
            stateJson.put("video", videoJson)
            preferences.edit().putString("flutter.$APP_LOCAL_STATE_KEY", stateJson.toString()).apply()
        }.onFailure { error ->
            Log.e(TAG, "update video stream switch failed, profile=$profileName, enabled=$enabled", error)
        }
    }

    private fun readEnabledVideoStreamSwitches(): Set<String> {
        val switchJson = readVideoConfig().optJSONObject("streamSwitches") ?: JSONObject()
        return STREAM_PROFILES
            .filter { profile -> switchJson.optBoolean(profile.name, false) }
            .map { profile -> profile.name }
            .toSet()
    }

    private fun startOutsideEnvironmentStream(
        cameraId: String,
        resetReconnect: Boolean = false,
        triggeredByReconnect: Boolean = false,
    ) {
        streamHandler.removeCallbacks(reconnectRunnable)
        if (resetReconnect) {
            reconnectAttempts = 0
        }
        if (triggeredByReconnect) {
            outsideEnvironmentStreamStatus = "正在重连第 $reconnectAttempts 次"
        }

        stopOutsideEnvironmentStream()

        val profiles = STREAM_PROFILES.filter { profile -> enabledOutsideEnvironmentProfiles.contains(profile.name) }
        if (profiles.isEmpty()) {
            outsideEnvironmentStreamStatus = "720p/1080p 已停止"
            appendOutsideEnvironmentLog("stream start skipped, no enabled profiles")
            return
        }

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
            Log.i(TAG, "starting outside environment RKMPP RTSP H265 streams, cameraId=$cameraId, profiles=${profiles.map { it.name }}, videoConfig=$videoConfig")
            resetOutsideEnvironmentLog()
            requests.forEach { request ->
                appendOutsideEnvironmentLog("profile=${request.profile} build=$H265_BUILD_MARK encoder=rkmpp protocol=RTSP codec=H265 transport=TCP cameraId=$cameraId url=${request.url} size=${request.width}x${request.height} fps=${request.fps} bitrate=${request.bitrate} gop=${request.iframeInterval}s")
            }
            appendOutsideEnvironmentLog("starting H265 RTSP streams, cameraId=$cameraId, profiles=${profiles.joinToString(",") { it.name }}")
            val stream = DualMediaCodecH265Stream(activity.applicationContext, rkMppBridge) { status ->
                outsideEnvironmentStreamStatus = "${profiles.joinToString(",") { it.name }} $status"
                Log.i(TAG, "outside environment H265 status: $status")
                appendOutsideEnvironmentLog("status=$status")
                handleOutsideEnvironmentRuntimeStatus(cameraId, status)
            }
            val started = stream.start(cameraId, requests)
            if (!started) {
                val reason = outsideEnvironmentStreamStatus
                outsideEnvironmentStreamStatus = "H265 推流启动失败：$reason"
                Log.e(TAG, "outside environment RKMPP RTSP H265 stream start returned false: $reason")
                appendOutsideEnvironmentLog("start returned false: $reason")
                scheduleOutsideEnvironmentReconnect(cameraId, reason)
                return
            }

            outsideEnvironmentStream = stream
            activeOutsideEnvironmentProfiles = profiles
            outsideEnvironmentStreamStatus = "${profiles.joinToString(",") { it.name }} 推流启动中"
            appendOutsideEnvironmentLog("stream object started")
        } catch (error: Throwable) {
            outsideEnvironmentStreamStatus = "${enabledOutsideEnvironmentProfiles.joinToString(",")} 推流启动失败：${error.message ?: error::class.java.simpleName}"
            Log.e(TAG, "outside environment RKMPP RTSP H265 stream start failed", error)
            appendOutsideEnvironmentLog("start failed", error)
            stopOutsideEnvironmentStream()
            scheduleOutsideEnvironmentReconnect(cameraId, outsideEnvironmentStreamStatus)
        }
    }

    private fun stopOutsideEnvironmentStream() {
        val stream = outsideEnvironmentStream ?: return
        runCatching { stream.stop() }
            .onFailure { error -> appendOutsideEnvironmentLog("stop failed", error) }
        outsideEnvironmentStream = null
        activeOutsideEnvironmentProfiles = emptyList()
        appendOutsideEnvironmentLog("stream stopped")
    }

    private fun scheduleOutsideEnvironmentReconnect(cameraId: String, reason: String) {
        if (reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
            outsideEnvironmentStreamStatus = "推流重连失败，已达到最大次数：$reason"
            Log.e(TAG, "outside environment RKMPP RTSP H265 stream reconnect failed, max attempts reached")
            appendOutsideEnvironmentLog("reconnect failed, max attempts reached, reason=$reason")
            return
        }
        reconnectAttempts += 1
        reconnectingCameraId = cameraId
        streamHandler.removeCallbacks(reconnectRunnable)
        streamHandler.postDelayed(reconnectRunnable, RECONNECT_DELAY_MS)
        outsideEnvironmentStreamStatus = "推流断开：$reason，${RECONNECT_DELAY_MS / 1000} 秒后重连第 $reconnectAttempts 次"
        Log.w(TAG, "outside environment RKMPP RTSP H265 stream reconnect scheduled, cameraId=$cameraId, attempt=$reconnectAttempts, reason=$reason")
        appendOutsideEnvironmentLog("reconnect scheduled, cameraId=$cameraId, attempt=$reconnectAttempts, reason=$reason")
    }

    private fun handleOutsideEnvironmentRuntimeStatus(cameraId: String, status: String) {
        if (!status.isRecoverableStreamFailure()) {
            return
        }
        streamHandler.post {
            if (outsideEnvironmentStreamStatus.startsWith("推流断开")) {
                return@post
            }
            stopOutsideEnvironmentStream()
            scheduleOutsideEnvironmentReconnect(cameraId, status)
        }
    }

    private fun appendOutsideEnvironmentLog(message: String, error: Throwable? = null) {
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
            appendUnifiedErrorLog(
                source = "android-h265",
                message = message,
                error = error?.message ?: "",
                stackTrace = error?.let(Log::getStackTraceString) ?: "",
                timestamp = timestamp,
            )
        }
    }

    private fun resetOutsideEnvironmentLog() {
        runCatching { logFile(OUTSIDE_ENVIRONMENT_LOG_FILE_NAME).writeText("") }
            .onFailure { fileError -> Log.e(TAG, "reset H265 log file failed", fileError) }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return
        }
        runCatching {
            val resolver = activity.contentResolver
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
                }
            }
        }.onFailure { fileError -> Log.e(TAG, "reset downloads H265 log failed", fileError) }
    }

    private fun outsideEnvironmentLogFile(): File {
        return logFile(OUTSIDE_ENVIRONMENT_LOG_FILE_NAME)
    }

    private fun appendUnifiedErrorLog(
        source: String,
        message: String,
        error: String,
        stackTrace: String,
        timestamp: String = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US).format(Date()),
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
        uploadErrorLog(source, message, error, stackTrace, timestamp)
    }

    private fun appendLogFile(fileName: String, details: String) {
        runCatching {
            logFile(fileName).appendText(details)
        }.onFailure { fileError ->
            Log.e(TAG, "write log file failed: $fileName", fileError)
        }
    }

    private fun logFile(fileName: String): File {
        val logDir = File(activity.getExternalFilesDir(null) ?: activity.filesDir, "logs")
        if (!logDir.exists()) {
            logDir.mkdirs()
        }
        return File(logDir, fileName)
    }

    private fun writeDownloadsLog(fileName: String, details: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return
        }
        if (failedDownloadsLogNames.contains(fileName)) {
            return
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
            resolver.openOutputStream(uri, "wa")?.use { output ->
                output.write(details.toByteArray(Charsets.UTF_8))
            }
        }.onFailure { error ->
            if (failedDownloadsLogNames.add(fileName)) {
                Log.w(TAG, "write downloads log disabled for $fileName: ${error.message ?: error::class.java.simpleName}")
            }
        }
    }

    private fun uploadErrorLog(source: String, message: String, error: String, stackTrace: String, timestamp: String) {
        val reportUrl = readErrorReportUrl()
        if (reportUrl.isBlank() || !readErrorUploadEnabled()) {
            return
        }
        val now = System.currentTimeMillis()
        if (now < errorUploadMutedUntilMs) {
            return
        }
        Thread {
            runCatching {
                val androidId = Settings.Secure.getString(activity.contentResolver, Settings.Secure.ANDROID_ID) ?: "unknown"
                val payload = JSONObject().apply {
                    put("time", timestamp)
                    put("source", source)
                    put("message", message)
                    put("error", error)
                    put("stackTrace", stackTrace)
                    put("deviceId", androidId)
                    put("packageName", activity.packageName)
                }.toString()
                val connection = (URL(reportUrl).openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    connectTimeout = 5000
                    readTimeout = 5000
                    doOutput = true
                    setRequestProperty("Content-Type", "application/json; charset=utf-8")
                }
                connection.outputStream.use { output ->
                    output.write(payload.toByteArray(Charsets.UTF_8))
                }
                val code = connection.responseCode
                if (code !in 200..299) {
                    Log.e(TAG, "error log upload failed, code=$code, url=$reportUrl")
                }
                connection.disconnect()
            }.onFailure { uploadError ->
                errorUploadMutedUntilMs = System.currentTimeMillis() + ERROR_UPLOAD_FAILURE_COOLDOWN_MS
                Log.w(TAG, "error log upload muted for ${ERROR_UPLOAD_FAILURE_COOLDOWN_MS / 1000}s: ${uploadError.message ?: uploadError::class.java.simpleName}")
            }
        }.apply { name = "SmartCabinetErrorLogUpload" }.start()
    }

    private fun readErrorReportUrl(): String {
        return readLoggingConfig().optString("errorReportUrl", DEFAULT_ERROR_REPORT_URL)
            .ifBlank { DEFAULT_ERROR_REPORT_URL }
    }

    private fun readErrorUploadEnabled(): Boolean {
        return readLoggingConfig().optBoolean("uploadEnabled", true)
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
        resetReconnect: Boolean = false,
        triggeredByReconnect: Boolean = false,
    ) {
        if (operationAreaStream?.isStreaming() == true &&
            operationAreaStream?.currentCameraId == cameraId
        ) {
            operationAreaStreamStatus = "推流中"
            return
        }

        streamHandler.removeCallbacks(operationReconnectRunnable)
        if (resetReconnect) {
            operationReconnectAttempts = 0
        }
        if (triggeredByReconnect) {
            operationAreaStreamStatus = "正在重连第 $operationReconnectAttempts 次"
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
            Log.i(TAG, "starting operation area RTSP H265 stream, cameraId=$cameraId, url=$url, videoConfig=$videoConfig")
            appendOutsideEnvironmentLog("role=operationArea build=$H265_BUILD_MARK encoder=${selectH265EncoderName()} protocol=RTSP codec=H265 transport=TCP cameraId=$cameraId url=$url size=${streamWidth}x$streamHeight fps=$streamFps bitrate=$streamBitrate gop=${streamGopSeconds}s")
            appendOutsideEnvironmentLog("role=operationArea starting H265 RTSP stream, cameraId=$cameraId, url=$url")
            val stream = createH265Stream(RkMppBridge()) { status ->
                operationAreaStreamStatus = status
                Log.i(TAG, "operation area H265 status: $status")
                appendOutsideEnvironmentLog("role=operationArea status=$status")
                handleOperationAreaRuntimeStatus(cameraId, status)
            }
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
                operationAreaStreamStatus = "RTSP H265 推流启动失败：$operationAreaStreamStatus"
                Log.e(TAG, "operation area RTSP H265 stream start returned false: $operationAreaStreamStatus")
                appendOutsideEnvironmentLog("role=operationArea start returned false: $operationAreaStreamStatus")
                scheduleOperationAreaReconnect(cameraId)
                return
            }

            operationAreaStream = stream
            operationAreaStreamStatus = "推流启动中"
            appendOutsideEnvironmentLog("role=operationArea stream object started")
        } catch (error: Throwable) {
            operationAreaStreamStatus = "推流启动失败：${error.message ?: error::class.java.simpleName}"
            Log.e(TAG, "operation area RTSP H265 stream start failed", error)
            appendOutsideEnvironmentLog("role=operationArea start failed", error)
            stopOperationAreaStream()
            scheduleOperationAreaReconnect(cameraId)
        }
    }

    private fun stopOperationAreaStream() {
        val stream = operationAreaStream ?: return
        runCatching { stream.stop() }
            .onFailure { error -> appendOutsideEnvironmentLog("role=operationArea stop failed", error) }
        operationAreaStream = null
        appendOutsideEnvironmentLog("role=operationArea stream stopped")
    }

    private fun scheduleOperationAreaReconnect(cameraId: String) {
        if (operationReconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
            operationAreaStreamStatus = "推流重连失败，已达到最大次数"
            Log.e(TAG, "operation area RTSP H265 stream reconnect failed, max attempts reached")
            appendOutsideEnvironmentLog("role=operationArea reconnect failed, max attempts reached")
            return
        }
        operationReconnectAttempts += 1
        operationReconnectingCameraId = cameraId
        streamHandler.removeCallbacks(operationReconnectRunnable)
        streamHandler.postDelayed(operationReconnectRunnable, RECONNECT_DELAY_MS)
        operationAreaStreamStatus = "推流断开，${RECONNECT_DELAY_MS / 1000} 秒后重连第 $operationReconnectAttempts 次"
        Log.w(TAG, "operation area RTSP H265 stream reconnect scheduled, cameraId=$cameraId, attempt=$operationReconnectAttempts")
        appendOutsideEnvironmentLog("role=operationArea reconnect scheduled, cameraId=$cameraId, attempt=$operationReconnectAttempts")
    }

    private fun handleOperationAreaRuntimeStatus(cameraId: String, status: String) {
        if (!status.isRecoverableStreamFailure()) {
            return
        }
        streamHandler.post {
            if (operationAreaStreamStatus.startsWith("推流断开")) {
                return@post
            }
            stopOperationAreaStream()
            scheduleOperationAreaReconnect(cameraId)
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

    private fun String.isRecoverableStreamFailure(): Boolean {
        return contains("推流失败") ||
            contains("发送失败") ||
            contains("异步发送失败") ||
            contains("摄像头断开") ||
            contains("摄像头错误") ||
            contains("Broken pipe", ignoreCase = true) ||
            contains("failed", ignoreCase = true) ||
            contains("error", ignoreCase = true)
    }

    private fun streamStateName(status: String): String {
        return when {
            status.contains("未配置") || status.contains("未指定") -> STREAM_STATE_UNCONFIGURED
            status.contains("重连") || status.contains("reconnect", ignoreCase = true) -> STREAM_STATE_RECONNECTING
            status.isRecoverableStreamFailure() || status.contains("失败") || status.contains("错误") -> STREAM_STATE_FAILED
            status.contains("启动中") || status.contains("打开中") -> STREAM_STATE_STARTING
            status.contains("停止") || status.contains("未启动") -> STREAM_STATE_STOPPED
            status.contains("推流中") || status.contains("已开始") -> STREAM_STATE_STREAMING
            else -> STREAM_STATE_UNKNOWN
        }
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
        return "${deviceStreamUrl.substringBeforeLast('/')}/${androidId}_${profile.name}"
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
            StreamProfile("720p", 1280, 720, 20, 3000 * 1000, 1),
            StreamProfile("1080p", 1920, 1080, 15, 5000 * 1000, 1),
        )
        private val DEFAULT_STREAM_PROFILE = STREAM_PROFILES.first { profile -> profile.name == "720p" }
        private const val RECONNECT_DELAY_MS = 3000L
        private const val MAX_RECONNECT_ATTEMPTS = 100
        private const val ERROR_UPLOAD_FAILURE_COOLDOWN_MS = 60_000L
        private const val TAG = "SmartCabinetStream"
        private const val H265_BUILD_MARK = "rkmpp-h265-diagnostics-20260626-1718"
        private const val APP_LOCAL_STATE_KEY = "app.localState"
        private const val OUTSIDE_ENVIRONMENT_LOG_FILE_NAME = "smart_cabinet_rtsp_h265.log"
        private const val UNIFIED_ERROR_LOG_FILE_NAME = "smart_cabinet_error.log"
        private const val DEFAULT_ERROR_REPORT_URL = "http://192.168.1.100:3000/api/logs/error"
        private const val DEFAULT_STREAM_BASE_URL = "rtsp://183.56.183.39:8888/app"
        private const val STREAM_CONTROL_PORT = 18080
        private const val STREAM_CONTROL_TIMEOUT_MS = 15_000L
        private const val DOWNLOADS_LOG_PATH = "Download/SmartCabinetLogs/smart_cabinet_rtsp_h265.log"
        private const val OUTSIDE_ENVIRONMENT_STREAM_MODE = "dual_active_profiles"
        private const val ROLE_OUTSIDE_ENVIRONMENT = "outsideEnvironment"
        private const val ROLE_OPERATION_AREA = "operationArea"
        private const val OUTSIDE_ENVIRONMENT_CAMERA_ID = "0"
        private const val OPERATION_AREA_CAMERA_ID = ""
        private const val STREAM_STATE_STOPPED = "stopped"
        private const val STREAM_STATE_STARTING = "starting"
        private const val STREAM_STATE_STREAMING = "streaming"
        private const val STREAM_STATE_RECONNECTING = "reconnecting"
        private const val STREAM_STATE_FAILED = "failed"
        private const val STREAM_STATE_UNCONFIGURED = "unconfigured"
        private const val STREAM_STATE_UNKNOWN = "unknown"
    }

}
