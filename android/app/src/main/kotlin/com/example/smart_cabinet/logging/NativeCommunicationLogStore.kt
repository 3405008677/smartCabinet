package com.example.smart_cabinet.logging

import java.net.URI
import java.util.ArrayDeque
import java.util.concurrent.atomic.AtomicLong

/** 通讯对象类型，对应管理员界面的“服务器”和“硬件”。 */
enum class NativeCommunicationTargetType(val wireValue: String) {
    SERVER("server"),
    HARDWARE("hardware"),
}

/** 以柜机软件为观察点的通讯方向。 */
enum class NativeCommunicationDirection(val wireValue: String) {
    OUTBOUND("outbound"),
    INBOUND("inbound"),
}

/** 一条仅保留当前进程、已经脱敏的原生通讯记录。 */
data class NativeCommunicationLogEntry(
    val nativeId: Long,
    val targetType: NativeCommunicationTargetType,
    val direction: NativeCommunicationDirection,
    val channel: String,
    val operation: String,
    val messageBody: Map<String, Any?>,
    val requestTimeEpochMs: Long,
    val result: String,
) {
    /** 转换为 Flutter StandardMessageCodec 可直接传输的只读快照。 */
    fun toMethodChannelMap(): Map<String, Any?> {
        return linkedMapOf(
            "nativeId" to nativeId,
            "targetType" to targetType.wireValue,
            "direction" to direction.wireValue,
            "channel" to channel,
            "operation" to operation,
            "messageBody" to messageBody,
            "requestTimeEpochMs" to requestTimeEpochMs,
            "result" to result,
        )
    }
}

/**
 * 保存 Dart 尚未启动或暂时未监听时产生的原生通讯日志。
 *
 * 队列按进程生命周期工作且有固定上限，不落盘、不复用错误日志链路。写入前会再次
 * 脱敏并丢弃二进制内容，防止 RTSP 帧、升级路径或设备唯一标识进入管理员诊断页。
 */
object NativeCommunicationLogStore {
    private val lock = Any()
    private val sequence = AtomicLong(0L)
    private val entries = ArrayDeque<NativeCommunicationLogEntry>()
    private val listeners = linkedSetOf<(NativeCommunicationLogEntry) -> Unit>()

    /** 记录一条原生通讯，并把同一份安全快照推送给当前监听者。 */
    fun record(
        targetType: NativeCommunicationTargetType,
        direction: NativeCommunicationDirection,
        channel: String,
        operation: String,
        messageBody: Map<String, Any?>,
        result: String,
        requestTimeEpochMs: Long = System.currentTimeMillis(),
    ): NativeCommunicationLogEntry {
        val entry = NativeCommunicationLogEntry(
            nativeId = sequence.incrementAndGet(),
            targetType = targetType,
            direction = direction,
            channel = sanitizeText(channel),
            operation = sanitizeText(operation),
            messageBody = sanitizeMap(messageBody),
            requestTimeEpochMs = requestTimeEpochMs,
            result = sanitizeText(result),
        )
        val listenerSnapshot = synchronized(lock) {
            entries.addLast(entry)
            while (entries.size > MAX_ENTRIES) {
                entries.removeFirst()
            }
            listeners.toList()
        }
        // 监听器异常不能改变通讯线程的业务结果，且不写入 AppLogger 以避免日志递归。
        listenerSnapshot.forEach { listener -> runCatching { listener(entry) } }
        return entry
    }

    /**
     * 尝试记录一条原生通讯；诊断存储或监听异常时返回 null，不改变真实协议线程结果。
     */
    fun tryRecord(
        targetType: NativeCommunicationTargetType,
        direction: NativeCommunicationDirection,
        channel: String,
        operation: String,
        messageBody: Map<String, Any?>,
        result: String,
        requestTimeEpochMs: Long = System.currentTimeMillis(),
    ): NativeCommunicationLogEntry? {
        return runCatching {
            record(
                targetType = targetType,
                direction = direction,
                channel = channel,
                operation = operation,
                messageBody = messageBody,
                result = result,
                requestTimeEpochMs = requestTimeEpochMs,
            )
        }.getOrNull()
    }

    /** 返回按产生顺序排列的当前进程快照，用于 Flutter 导入启动期事件。 */
    fun snapshot(): List<Map<String, Any?>> {
        return synchronized(lock) {
            entries.map(NativeCommunicationLogEntry::toMethodChannelMap)
        }
    }

    /** 订阅后续新增记录；历史记录仍应通过 [snapshot] 单独读取。 */
    fun addListener(listener: (NativeCommunicationLogEntry) -> Unit) {
        synchronized(lock) { listeners.add(listener) }
    }

    /** 移除一个不再有效的 Flutter Engine 监听器。 */
    fun removeListener(listener: (NativeCommunicationLogEntry) -> Unit) {
        synchronized(lock) { listeners.remove(listener) }
    }

    /**
     * 只保留 endpoint 的协议、主机和端口。
     *
     * userInfo、路径、查询参数和 fragment 均不会进入通讯日志；无法安全解析时返回固定值。
     */
    fun sanitizeEndpoint(rawEndpoint: String): String {
        return runCatching {
            val uri = URI(rawEndpoint)
            val scheme = uri.scheme?.lowercase().orEmpty()
            val host = uri.host.orEmpty()
            if (scheme.isBlank() || host.isBlank()) {
                return@runCatching REDACTED_ENDPOINT
            }
            buildString {
                append(scheme)
                append("://")
                append(host)
                if (uri.port >= 0) {
                    append(':')
                    append(uri.port)
                }
            }
        }.getOrDefault(REDACTED_ENDPOINT)
    }

    /** 清空单例状态，供同进程 JVM 单元测试隔离。 */
    internal fun clearForTesting() {
        synchronized(lock) {
            entries.clear()
            listeners.clear()
        }
        sequence.set(0L)
    }

    /** 复制一层消息 Map，并在递归前先按字段名阻断敏感值。 */
    private fun sanitizeMap(source: Map<String, Any?>): Map<String, Any?> {
        val result = linkedMapOf<String, Any?>()
        source.forEach { (key, value) ->
            val safeKey = sanitizeText(key)
            result[safeKey] = if (isSensitiveKey(key)) {
                REDACTED
            } else {
                sanitizeValue(value, depth = 0)
            }
        }
        return result
    }

    /** 把任意原生对象压缩为 StandardMessageCodec 支持的安全标量、List 或 Map。 */
    private fun sanitizeValue(value: Any?, depth: Int): Any? {
        if (depth >= MAX_NESTING_DEPTH) {
            return OMITTED
        }
        return when (value) {
            null, is Boolean, is Number -> value
            is ByteArray -> BINARY_OMITTED
            is String -> sanitizeText(value)
            is Map<*, *> -> {
                val safeMap = linkedMapOf<String, Any?>()
                value.entries.forEach { (rawKey, rawValue) ->
                    val key = rawKey?.toString().orEmpty()
                    safeMap[sanitizeText(key)] = if (isSensitiveKey(key)) {
                        REDACTED
                    } else {
                        sanitizeValue(rawValue, depth + 1)
                    }
                }
                safeMap
            }
            is Iterable<*> -> value.take(MAX_COLLECTION_ITEMS).map { item ->
                sanitizeValue(item, depth + 1)
            }
            else -> sanitizeText(value::class.java.simpleName)
        }
    }

    /** 判断字段名是否可能携带设备标识、认证信息、文件位置或视频数据。 */
    private fun isSensitiveKey(key: String): Boolean {
        val normalized = key.lowercase().replace(NON_ALPHANUMERIC, "")
        return SENSITIVE_KEYS.any(normalized::contains)
    }

    /** 对非结构化文本中的 URL 兜底脱敏，并限制单字段占用。 */
    private fun sanitizeText(value: String): String {
        val withoutUrls = URL_PATTERN.replace(value) { match ->
            sanitizeEndpoint(match.value)
        }
        val safeText = SENSITIVE_ASSIGNMENT_PATTERN.replace(withoutUrls) { match ->
            "${match.groupValues[1]}=$REDACTED"
        }
        val clipped = if (safeText.length > MAX_TEXT_LENGTH) {
            safeText.take(MAX_TEXT_LENGTH) + OMITTED
        } else {
            safeText
        }
        return clipped
    }

    private const val MAX_ENTRIES = 500
    private const val MAX_NESTING_DEPTH = 8
    private const val MAX_COLLECTION_ITEMS = 100
    private const val MAX_TEXT_LENGTH = 4_096
    private const val REDACTED = "<已脱敏>"
    private const val REDACTED_ENDPOINT = "<endpoint 已脱敏>"
    private const val BINARY_OMITTED = "<二进制内容已省略>"
    private const val OMITTED = "<内容已省略>"
    private val NON_ALPHANUMERIC = Regex("[^a-z0-9]")
    private val URL_PATTERN = Regex("(?i)\\b(?:https?|rtsp)://[^\\s]+")
    private val SENSITIVE_ASSIGNMENT_PATTERN = Regex(
        "(?i)\\b(id|imei|token|secret|password|authorization|path|userinfo|" +
            "deviceid|terminalid|operationid|jobid|session)\\s*[:=]\\s*[^\\s,;|}]+",
    )
    private val SENSITIVE_KEYS = setOf(
        "id",
        "imei",
        "token",
        "secret",
        "password",
        "authorization",
        "cookie",
        "path",
        "url",
        "uri",
        "userinfo",
        "session",
        "sdp",
        "vps",
        "sps",
        "pps",
        "rtp",
        "h265",
        "frame",
        "payload",
        "device",
        "terminal",
        "operation",
        "job",
        "package",
    )
}
