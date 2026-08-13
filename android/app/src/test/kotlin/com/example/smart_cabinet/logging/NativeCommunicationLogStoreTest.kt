package com.example.smart_cabinet.logging

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/** 验证原生通讯日志的有界、脱敏和实时通知契约。 */
class NativeCommunicationLogStoreTest {
    /** 每个用例前清空进程单例，避免顺序依赖。 */
    @Before
    fun setUp() {
        NativeCommunicationLogStore.clearForTesting()
    }

    /** 每个用例后移除监听器，避免后续用例收到旧回调。 */
    @After
    fun tearDown() {
        NativeCommunicationLogStore.clearForTesting()
    }

    /** endpoint 不得保留认证、资源路径或查询参数。 */
    @Test
    fun sanitizeEndpoint_removesUserInfoPathQueryAndFragment() {
        val endpoint = NativeCommunicationLogStore.sanitizeEndpoint(
            "rtsp://operator:secret@example.test:8554/live/device?token=value#fragment",
        )

        assertEquals("rtsp://example.test:8554", endpoint)
    }

    /** 敏感字段和二进制内容不得通过消息 Map 泄漏。 */
    @Test
    fun record_redactsSensitiveFieldsAndOmitsBinaryContent() {
        NativeCommunicationLogStore.record(
            targetType = NativeCommunicationTargetType.SERVER,
            direction = NativeCommunicationDirection.OUTBOUND,
            channel = "HTTP",
            operation = "测试请求",
            messageBody = mapOf(
                "endpoint" to "https://user:secret@example.test/api/log?token=value",
                "token" to "plain-token",
                "apkPath" to "/data/private/update.apk",
                "payload" to byteArrayOf(1, 2, 3),
            ),
            result = "成功",
        )

        val serialized = NativeCommunicationLogStore.snapshot().single().toString()
        assertTrue(serialized.contains("https://example.test"))
        assertFalse(serialized.contains("plain-token"))
        assertFalse(serialized.contains("/data/private"))
        assertFalse(serialized.contains("operator"))
        assertFalse(serialized.contains("byteArray"))
    }

    /** 有界队列只保留最近 500 条原生记录。 */
    @Test
    fun record_keepsOnlyLatestFiveHundredEntries() {
        repeat(520) { index ->
            NativeCommunicationLogStore.record(
                targetType = NativeCommunicationTargetType.HARDWARE,
                direction = NativeCommunicationDirection.INBOUND,
                channel = "PackageInstaller",
                operation = "状态回调",
                messageBody = mapOf("sequence" to index),
                result = "已处理",
            )
        }

        val snapshot = NativeCommunicationLogStore.snapshot()
        assertEquals(500, snapshot.size)
        assertEquals(21L, snapshot.first()["nativeId"])
        assertEquals(520L, snapshot.last()["nativeId"])
    }

    /** 实时监听只收到订阅期间新增的记录。 */
    @Test
    fun listener_receivesOnlyNewEntriesUntilRemoved() {
        val received = mutableListOf<Long>()
        val listener: (NativeCommunicationLogEntry) -> Unit = { entry ->
            received += entry.nativeId
        }
        NativeCommunicationLogStore.addListener(listener)

        NativeCommunicationLogStore.record(
            targetType = NativeCommunicationTargetType.SERVER,
            direction = NativeCommunicationDirection.INBOUND,
            channel = "RTSP",
            operation = "OPTIONS",
            messageBody = mapOf("cSeq" to 1),
            result = "成功",
        )
        NativeCommunicationLogStore.removeListener(listener)
        NativeCommunicationLogStore.record(
            targetType = NativeCommunicationTargetType.SERVER,
            direction = NativeCommunicationDirection.INBOUND,
            channel = "RTSP",
            operation = "ANNOUNCE",
            messageBody = mapOf("cSeq" to 2),
            result = "成功",
        )

        assertEquals(listOf(1L), received)
    }
}
