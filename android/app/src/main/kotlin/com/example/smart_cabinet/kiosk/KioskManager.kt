package com.example.smart_cabinet.kiosk

import android.app.Activity
import android.app.ActivityManager
import android.app.admin.DevicePolicyManager
import android.content.pm.PackageManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.UserManager
import android.provider.Settings
import android.util.Log
import android.view.WindowManager
import com.pedro.common.ConnectChecker
import com.pedro.common.VideoCodec
import com.pedro.library.rtmp.RtmpCamera2

class KioskManager(private val activity: Activity) {
    private val cameraBindingPreferences =
        activity.getSharedPreferences("camera_bindings", Context.MODE_PRIVATE)

    private var outsideEnvironmentStream: GStreamerH265Stream? = null

    private var operationAreaStream: RtmpCamera2? = null

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
            Log.i(TAG, "start operation area H264 stream from saved binding, cameraId=$operationCameraId")
            startOperationAreaStream(operationCameraId)
        }
    }

    fun readOutsideEnvironmentStreamStatus(): Map<String, String> {
        return linkedMapOf(
            "status" to outsideEnvironmentStreamStatus,
            "url" to buildOutsideEnvironmentRtspUrl(),
            "cameraId" to (cameraBindingPreferences.getString(OUTSIDE_ENVIRONMENT_CAMERA_ROLE, null) ?: ""),
        )
    }

    fun readOperationAreaStreamStatus(): Map<String, String> {
        return linkedMapOf(
            "status" to operationAreaStreamStatus,
            "url" to buildOperationAreaRtmpUrl(),
            "cameraId" to (cameraBindingPreferences.getString(OPERATION_AREA_CAMERA_ROLE, null) ?: ""),
        )
    }

    fun readGStreamerStatus(): Map<String, String> {
        return runCatching {
            val initialized = gStreamerBridge.initialize()
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
            val stream = GStreamerH265Stream(activity.applicationContext, gStreamerBridge) { status ->
                outsideEnvironmentStreamStatus = status
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
                outsideEnvironmentStreamStatus = "GStreamer H265 推流启动失败"
                Log.e(TAG, "outside environment GStreamer RTSP H265 stream start returned false")
                scheduleOutsideEnvironmentReconnect(cameraId)
                return
            }

            outsideEnvironmentStream = stream
            outsideEnvironmentStreamStatus = "推流启动中"
        } catch (error: Throwable) {
            outsideEnvironmentStreamStatus = "推流启动失败：${error.message ?: error::class.java.simpleName}"
            Log.e(TAG, "outside environment GStreamer RTSP H265 stream start failed", error)
            stopOutsideEnvironmentStream()
            scheduleOutsideEnvironmentReconnect(cameraId)
        }
    }

    private fun stopOutsideEnvironmentStream() {
        val stream = outsideEnvironmentStream ?: return
        runCatching { stream.stop() }
        outsideEnvironmentStream = null
    }

    private fun scheduleOutsideEnvironmentReconnect(cameraId: String) {
        if (reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
            outsideEnvironmentStreamStatus = "推流重连失败，已达到最大次数"
            Log.e(TAG, "outside environment GStreamer RTSP H265 stream reconnect failed, max attempts reached")
            return
        }
        reconnectAttempts += 1
        reconnectingCameraId = cameraId
        streamHandler.removeCallbacks(reconnectRunnable)
        streamHandler.postDelayed(reconnectRunnable, RECONNECT_DELAY_MS)
        outsideEnvironmentStreamStatus = "推流断开，${RECONNECT_DELAY_MS / 1000} 秒后重连第 $reconnectAttempts 次"
        Log.w(TAG, "outside environment GStreamer RTSP H265 stream reconnect scheduled, cameraId=$cameraId, attempt=$reconnectAttempts")
    }

    private fun startOperationAreaStream(
        cameraId: String,
        resetReconnect: Boolean = false,
        triggeredByReconnect: Boolean = false,
    ) {
        if (operationAreaStream?.isStreaming == true &&
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
            val url = buildOperationAreaRtmpUrl()
            Log.i(TAG, "starting operation area H264 stream, cameraId=$cameraId, url=$url")
            val stream = RtmpCamera2(activity.applicationContext, operationAreaConnectChecker)
            stream.disableAudio()
            stream.setVideoCodec(VideoCodec.H264)
            val prepared = stream.prepareVideo(
                STREAM_WIDTH,
                STREAM_HEIGHT,
                STREAM_FPS,
                STREAM_VIDEO_BITRATE,
                STREAM_IFRAME_INTERVAL,
                STREAM_ROTATION,
            )
            if (!prepared) {
                operationAreaStreamStatus = "H264视频编码器初始化失败"
                Log.e(TAG, "operation area H264 video encoder prepare failed")
                scheduleOperationAreaReconnect(cameraId)
                return
            }

            stream.startPreview(cameraId, STREAM_WIDTH, STREAM_HEIGHT, STREAM_FPS, STREAM_ROTATION)
            Log.i(TAG, "operation area H264 preview started, cameraId=$cameraId")
            stream.startStream(url)
            operationAreaStream = stream
            operationAreaStreamStatus = "推流启动中"
        } catch (error: Throwable) {
            operationAreaStreamStatus = "推流启动失败：${error.message ?: error::class.java.simpleName}"
            Log.e(TAG, "operation area H264 stream start failed", error)
            stopOperationAreaStream()
            scheduleOperationAreaReconnect(cameraId)
        }
    }

    private fun stopOperationAreaStream() {
        val stream = operationAreaStream ?: return
        runCatching {
            if (stream.isStreaming) {
                stream.stopStream()
            }
        }
        runCatching {
            if (stream.isOnPreview) {
                stream.stopPreview()
            }
        }
        operationAreaStream = null
    }

    private fun scheduleOperationAreaReconnect(cameraId: String) {
        if (operationReconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
            operationAreaStreamStatus = "推流重连失败，已达到最大次数"
            Log.e(TAG, "operation area H264 stream reconnect failed, max attempts reached")
            return
        }
        operationReconnectAttempts += 1
        operationReconnectingCameraId = cameraId
        streamHandler.removeCallbacks(operationReconnectRunnable)
        streamHandler.postDelayed(operationReconnectRunnable, RECONNECT_DELAY_MS)
        operationAreaStreamStatus = "推流断开，${RECONNECT_DELAY_MS / 1000} 秒后重连第 $operationReconnectAttempts 次"
        Log.w(TAG, "operation area H264 stream reconnect scheduled, cameraId=$cameraId, attempt=$operationReconnectAttempts")
    }

    private fun buildOutsideEnvironmentRtspUrl(): String {
        val androidId = Settings.Secure.getString(
            activity.contentResolver,
            Settings.Secure.ANDROID_ID,
        ) ?: "unknown"
        return "rtsp://192.168.2.167/app/$androidId"
    }

    private fun buildOperationAreaRtmpUrl(): String {
        val androidId = Settings.Secure.getString(
            activity.contentResolver,
            Settings.Secure.ANDROID_ID,
        ) ?: "unknown"
        return "rtmp://192.168.2.167/app/$androidId-operation-h264"
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
        private const val STREAM_ROTATION = 0
        private const val RECONNECT_DELAY_MS = 3000L
        private const val MAX_RECONNECT_ATTEMPTS = 100
        private const val TAG = "SmartCabinetStream"

        private val CAMERA_ROLES = listOf(
            "faceRecognition",
            "outsideEnvironment",
            "operationArea",
            "certificateCapture",
        )
    }

    private val operationAreaConnectChecker = object : ConnectChecker {
        override fun onConnectionStarted(url: String) {
            operationAreaStreamStatus = "正在连接：$url"
            Log.i(TAG, "operation area H264 stream connection started, url=$url")
        }

        override fun onConnectionSuccess() {
            operationReconnectAttempts = 0
            operationReconnectingCameraId = null
            streamHandler.removeCallbacks(operationReconnectRunnable)
            operationAreaStreamStatus = "推流中"
            Log.i(TAG, "operation area H264 stream connection success")
        }

        override fun onConnectionFailed(reason: String) {
            operationAreaStreamStatus = "推流失败：$reason"
            Log.e(TAG, "operation area H264 stream connection failed: $reason")
            val cameraId = operationAreaStream?.currentCameraId
                ?: cameraBindingPreferences.getString(OPERATION_AREA_CAMERA_ROLE, null)
            stopOperationAreaStream()
            if (!cameraId.isNullOrBlank()) {
                scheduleOperationAreaReconnect(cameraId)
            }
        }

        override fun onNewBitrate(bitrate: Long) {
            operationAreaStreamStatus = "推流中，码率：$bitrate"
        }

        override fun onDisconnect() {
            operationAreaStreamStatus = "已断开"
            Log.w(TAG, "operation area H264 stream disconnected")
            val cameraId = operationAreaStream?.currentCameraId
                ?: cameraBindingPreferences.getString(OPERATION_AREA_CAMERA_ROLE, null)
            stopOperationAreaStream()
            if (!cameraId.isNullOrBlank()) {
                scheduleOperationAreaReconnect(cameraId)
            }
        }

        override fun onAuthError() {
            operationAreaStreamStatus = "RTMP 认证失败"
            Log.e(TAG, "operation area H264 stream auth error")
        }

        override fun onAuthSuccess() {
            operationAreaStreamStatus = "RTMP 认证成功"
            Log.i(TAG, "operation area H264 stream auth success")
        }
    }
}
