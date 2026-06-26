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
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class KioskManager(private val activity: Activity) {
    private val cameraBindingPreferences =
        activity.getSharedPreferences("camera_bindings", Context.MODE_PRIVATE)

    private var outsideEnvironmentStream: RkMppH265Stream? = null

    private var operationAreaStream: RkMppH265Stream? = null

    private val gStreamerBridge by lazy { GStreamerBridge() }

    private var outsideEnvironmentStreamStatus: String = "未启动"

    private var operationAreaStreamStatus: String = "未启动"

    private val streamHandler = Handler(Looper.getMainLooper())

    private var reconnectAttempts = 0

    private var reconnectingCameraId: String? = null

    private var operationReconnectAttempts = 0

    private var operationReconnectingCameraId: String? = null

    private val reconnectRunnable = Runnable {
        val cameraId = reconnectingCameraId
            ?: cameraBindingPreferences.getString(OUTSIDE_ENVIRONMENT_CAMERA_ROLE, null)
        if (!cameraId.isNullOrBlank()) {
            startOutsideEnvironmentStream(cameraId, triggeredByReconnect = true)
        }
    }

    private val operationReconnectRunnable = Runnable {
        val cameraId = operationReconnectingCameraId
            ?: cameraBindingPreferences.getString(OPERATION_AREA_CAMERA_ROLE, null)
        if (!cameraId.isNullOrBlank()) {
            startOperationAreaStream(cameraId, triggeredByReconnect = true)
        }
    }

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

    fun readCameraBindings(): Map<String, String> {
        val bindings = linkedMapOf<String, String>()
        CAMERA_ROLES.forEach { role ->
            val cameraId = cameraBindingPreferences.getString(role, null)
            if (!cameraId.isNullOrBlank()) {
                bindings[role] = cameraId
            }
        }
        return bindings
    }

    fun writeCameraBinding(role: String, cameraId: String) {
        cameraBindingPreferences.edit().putString(role, cameraId).apply()
        if (role == OUTSIDE_ENVIRONMENT_CAMERA_ROLE) {
            Log.i(TAG, "outside environment camera binding saved, cameraId=$cameraId")
            startOutsideEnvironmentStream(cameraId, resetReconnect = true)
        }
        if (role == OPERATION_AREA_CAMERA_ROLE) {
            Log.i(TAG, "operation area camera binding saved, cameraId=$cameraId")
            startOperationAreaStream(cameraId, resetReconnect = true)
        }
    }

    fun startOutsideEnvironmentStreamIfConfigured() {
        val cameraId = cameraBindingPreferences.getString(OUTSIDE_ENVIRONMENT_CAMERA_ROLE, null)
        if (!cameraId.isNullOrBlank()) {
            Log.i(TAG, "start outside environment GStreamer RTSP H265 stream from saved binding, cameraId=$cameraId")
            startOutsideEnvironmentStream(cameraId)
        }
        val operationCameraId = cameraBindingPreferences.getString(OPERATION_AREA_CAMERA_ROLE, null)
        if (!operationCameraId.isNullOrBlank()) {
            Log.i(TAG, "start operation area RKMPP RTSP H265 stream from saved binding, cameraId=$operationCameraId")
            startOperationAreaStream(operationCameraId)
        }
    }

    fun readOutsideEnvironmentStreamStatus(): Map<String, String> {
        return linkedMapOf(
            "status" to outsideEnvironmentStreamStatus,
            "url" to buildOutsideEnvironmentRtspUrl(),
            "cameraId" to (cameraBindingPreferences.getString(OUTSIDE_ENVIRONMENT_CAMERA_ROLE, null) ?: ""),
            "logFile" to outsideEnvironmentLogFile().absolutePath,
            "downloadsLogFile" to DOWNLOADS_LOG_PATH,
        )
    }

    fun readOperationAreaStreamStatus(): Map<String, String> {
        return linkedMapOf(
            "status" to operationAreaStreamStatus,
            "url" to buildOperationAreaRtspUrl(),
            "cameraId" to (cameraBindingPreferences.getString(OPERATION_AREA_CAMERA_ROLE, null) ?: ""),
        )
    }

    fun readGStreamerStatus(): Map<String, String> {
        return runCatching {
            val initialized = gStreamerBridge.initialize(activity.applicationContext)
            linkedMapOf(
                "available" to initialized.toString(),
                "version" to gStreamerBridge.version(),
                "library" to "libgstreamer_android.so, libsmartcabinet_gstreamer.so",
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

    private fun startOutsideEnvironmentStream(
        cameraId: String,
        resetReconnect: Boolean = false,
        triggeredByReconnect: Boolean = false,
    ) {
        if (outsideEnvironmentStream?.isStreaming() == true) {
            outsideEnvironmentStreamStatus = "推流中"
            return
        }

        streamHandler.removeCallbacks(reconnectRunnable)
        if (resetReconnect) {
            reconnectAttempts = 0
        }
        if (triggeredByReconnect) {
            outsideEnvironmentStreamStatus = "正在重连第 $reconnectAttempts 次"
        }

        stopOutsideEnvironmentStream()

        try {
            val url = buildOutsideEnvironmentRtspUrl()
            Log.i(TAG, "starting outside environment GStreamer RTSP H265 stream, cameraId=$cameraId, url=$url")
            resetOutsideEnvironmentLog()
            appendOutsideEnvironmentLog("build=$H265_BUILD_MARK protocol=RTSP codec=H265 transport=TCP cameraId=$cameraId url=$url")
            appendOutsideEnvironmentLog("starting H265 RTSP stream, cameraId=$cameraId, url=$url")
            val stream = RkMppH265Stream(activity.applicationContext, gStreamerBridge) { status ->
                outsideEnvironmentStreamStatus = status
                appendOutsideEnvironmentLog("status=$status")
            }
            val started = stream.start(
                cameraId = cameraId,
                url = url,
                width = STREAM_WIDTH,
                height = STREAM_HEIGHT,
                fps = STREAM_FPS,
                bitrate = STREAM_VIDEO_BITRATE,
                iframeInterval = STREAM_IFRAME_INTERVAL,
            )
            if (!started) {
                val reason = outsideEnvironmentStreamStatus
                outsideEnvironmentStreamStatus = "GStreamer H265 推流启动失败：$reason"
                Log.e(TAG, "outside environment GStreamer RTSP H265 stream start returned false: $reason")
                appendOutsideEnvironmentLog("start returned false: $reason")
                scheduleOutsideEnvironmentReconnect(cameraId, reason)
                return
            }

            outsideEnvironmentStream = stream
            outsideEnvironmentStreamStatus = "推流启动中"
            appendOutsideEnvironmentLog("stream object started")
        } catch (error: Throwable) {
            outsideEnvironmentStreamStatus = "推流启动失败：${error.message ?: error::class.java.simpleName}"
            Log.e(TAG, "outside environment GStreamer RTSP H265 stream start failed", error)
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
        appendOutsideEnvironmentLog("stream stopped")
    }

    private fun scheduleOutsideEnvironmentReconnect(cameraId: String, reason: String) {
        if (reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
            outsideEnvironmentStreamStatus = "推流重连失败，已达到最大次数：$reason"
            Log.e(TAG, "outside environment GStreamer RTSP H265 stream reconnect failed, max attempts reached")
            appendOutsideEnvironmentLog("reconnect failed, max attempts reached, reason=$reason")
            return
        }
        reconnectAttempts += 1
        reconnectingCameraId = cameraId
        streamHandler.removeCallbacks(reconnectRunnable)
        streamHandler.postDelayed(reconnectRunnable, RECONNECT_DELAY_MS)
        outsideEnvironmentStreamStatus = "推流断开：$reason，${RECONNECT_DELAY_MS / 1000} 秒后重连第 $reconnectAttempts 次"
        Log.w(TAG, "outside environment GStreamer RTSP H265 stream reconnect scheduled, cameraId=$cameraId, attempt=$reconnectAttempts, reason=$reason")
        appendOutsideEnvironmentLog("reconnect scheduled, cameraId=$cameraId, attempt=$reconnectAttempts, reason=$reason")
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
            Log.e(TAG, "write outside environment downloads log failed", error)
        }
    }

    private fun uploadErrorLog(source: String, message: String, error: String, stackTrace: String, timestamp: String) {
        val reportUrl = readErrorReportUrl()
        if (reportUrl.isBlank() || !readErrorUploadEnabled()) {
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
                Log.e(TAG, "error log upload failed", uploadError)
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
            val url = buildOperationAreaRtspUrl()
            Log.i(TAG, "starting operation area RKMPP RTSP H265 stream, cameraId=$cameraId, url=$url")
            val stream = RkMppH265Stream(activity.applicationContext, GStreamerBridge()) { status ->
                operationAreaStreamStatus = status
            }
            val started = stream.start(
                cameraId = cameraId,
                url = url,
                width = STREAM_WIDTH,
                height = STREAM_HEIGHT,
                fps = STREAM_FPS,
                bitrate = STREAM_VIDEO_BITRATE,
                iframeInterval = STREAM_IFRAME_INTERVAL,
            )
            if (!started) {
                operationAreaStreamStatus = "RKMPP RTSP H265 推流启动失败：$operationAreaStreamStatus"
                Log.e(TAG, "operation area RKMPP RTSP H265 stream start returned false: $operationAreaStreamStatus")
                scheduleOperationAreaReconnect(cameraId)
                return
            }

            operationAreaStream = stream
            operationAreaStreamStatus = "推流启动中"
        } catch (error: Throwable) {
            operationAreaStreamStatus = "推流启动失败：${error.message ?: error::class.java.simpleName}"
            Log.e(TAG, "operation area RKMPP RTSP H265 stream start failed", error)
            stopOperationAreaStream()
            scheduleOperationAreaReconnect(cameraId)
        }
    }

    private fun stopOperationAreaStream() {
        val stream = operationAreaStream ?: return
        runCatching { stream.stop() }
        operationAreaStream = null
    }

    private fun scheduleOperationAreaReconnect(cameraId: String) {
        if (operationReconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
            operationAreaStreamStatus = "推流重连失败，已达到最大次数"
            Log.e(TAG, "operation area RKMPP RTSP H265 stream reconnect failed, max attempts reached")
            return
        }
        operationReconnectAttempts += 1
        operationReconnectingCameraId = cameraId
        streamHandler.removeCallbacks(operationReconnectRunnable)
        streamHandler.postDelayed(operationReconnectRunnable, RECONNECT_DELAY_MS)
        operationAreaStreamStatus = "推流断开，${RECONNECT_DELAY_MS / 1000} 秒后重连第 $operationReconnectAttempts 次"
        Log.w(TAG, "operation area RKMPP RTSP H265 stream reconnect scheduled, cameraId=$cameraId, attempt=$operationReconnectAttempts")
    }

    private fun buildOutsideEnvironmentRtspUrl(): String {
        val androidId = Settings.Secure.getString(
            activity.contentResolver,
            Settings.Secure.ANDROID_ID,
        ) ?: "unknown"
        return "rtsp://192.168.2.167/app/$androidId"
    }

    private fun buildOperationAreaRtspUrl(): String {
        val androidId = Settings.Secure.getString(
            activity.contentResolver,
            Settings.Secure.ANDROID_ID,
        ) ?: "unknown"
        return "rtsp://192.168.2.167/app/$androidId-operation"
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
        private const val OUTSIDE_ENVIRONMENT_CAMERA_ROLE = "outsideEnvironment"
        private const val OPERATION_AREA_CAMERA_ROLE = "operationArea"
        private const val STREAM_WIDTH = 640
        private const val STREAM_HEIGHT = 480
        private const val STREAM_FPS = 15
        private const val STREAM_VIDEO_BITRATE = 1200 * 1000
        private const val STREAM_IFRAME_INTERVAL = 1
        private const val RECONNECT_DELAY_MS = 3000L
        private const val MAX_RECONNECT_ATTEMPTS = 100
        private const val TAG = "SmartCabinetStream"
        private const val H265_BUILD_MARK = "rkmpp-h265-diagnostics-20260626-1718"
        private const val APP_LOCAL_STATE_KEY = "app.localState"
        private const val OUTSIDE_ENVIRONMENT_LOG_FILE_NAME = "smart_cabinet_rtsp_h265.log"
        private const val UNIFIED_ERROR_LOG_FILE_NAME = "smart_cabinet_error.log"
        private const val DEFAULT_ERROR_REPORT_URL = "http://192.168.1.100:3000/api/logs/error"
        private const val DOWNLOADS_LOG_PATH = "Download/SmartCabinetLogs/smart_cabinet_rtsp_h265.log"

        private val CAMERA_ROLES = listOf(
            "faceRecognition",
            "outsideEnvironment",
            "operationArea",
            "certificateCapture",
        )
    }

}
