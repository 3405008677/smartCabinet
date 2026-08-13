package com.example.smart_cabinet.upgrade

/** 与 Dart/STUM 协议一致的目标版本语义。 */
internal object TerminalUpgradeVersionPolicy {
    /** Dart 解析 S03/VE 时只去除两端空白，不改写 V 前缀或版本格式。 */
    fun normalizeExpected(rawVersion: String): String = rawVersion.trim()

    /**
     * APK versionName 必须与协议 VE 一致。
     *
     * 协议样例同时存在 `V1.2`，现场请求使用 `SL_V1.2_yyyyMMdd`，服务端响应
     * 使用 `SL_APP_V1.2`，而 Android build-name 通常是 `1.2`。这里只兼容这些
     * 明确外壳；其它大小写、分段和后缀仍精确匹配，不能用模糊包含关系放宽安装门禁。
     */
    fun matchesApkVersionName(expected: String, actual: String): Boolean {
        val normalizedExpected = normalizeExpected(expected)
        val normalizedActual = actual.trim()
        if (normalizedExpected == normalizedActual) {
            return true
        }
        return withoutProtocolEnvelope(normalizedExpected) ==
            withoutProtocolEnvelope(normalizedActual)
    }

    /**
     * 判断当前已安装应用是否正是本次已校验的目标，而不是更高版本的其它任务。
     *
     * versionCode 必须精确相等，versionName 继续只兼容协议允许的单个大写 V 前缀。
     */
    fun matchesInstalledTarget(
        expectedVersionName: String,
        expectedVersionCode: Long,
        actualVersionName: String,
        actualVersionCode: Long,
    ): Boolean {
        return expectedVersionCode > 0L &&
            actualVersionCode == expectedVersionCode &&
            matchesApkVersionName(expectedVersionName, actualVersionName)
    }

    /** 只移除已明确约定的 V 或 SL_V..._yyyyMMdd 外壳。 */
    private fun withoutProtocolEnvelope(version: String): String {
        if (version.length >= 2 && version[0] == 'V' && version[1] in '0'..'9') {
            return version.substring(1)
        }
        val appMatch = SL_APP_VERSION_PATTERN.matchEntire(version)
        if (appMatch != null) {
            return appMatch.groupValues[1]
        }
        val match = SL_VERSION_PATTERN.matchEntire(version) ?: return version
        return match.groupValues[1]
    }

    private val SL_APP_VERSION_PATTERN = Regex("^SL_APP_V(.+)$")
    private val SL_VERSION_PATTERN = Regex("^SL_V(.+)_([0-9]{8})$")
}
