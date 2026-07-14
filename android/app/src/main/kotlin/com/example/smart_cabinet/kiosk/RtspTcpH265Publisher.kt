package com.example.smart_cabinet.kiosk

import android.util.Base64
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.ByteArrayOutputStream
import java.net.InetSocketAddress
import java.net.URI
import java.net.Socket
import java.util.ArrayDeque
import kotlin.random.Random

class RtspTcpH265Publisher(
    private val statusListener: (String) -> Unit,
) {
    private var socket: Socket? = null
    private var input: BufferedInputStream? = null
    private var output: BufferedOutputStream? = null
    private val transportLock = Any()
    private var cSeq = 1
    private var session = ""
    private var sequenceNumber = Random.nextInt(0, 0xffff)
    private val ssrc = Random.nextInt()
    private var firstPresentationTimeUs: Long = -1L
    private var parameterSets: H265ParameterSets? = null
    private val sendLock = Object()
    private val pendingFrames = ArrayDeque<PendingFrame>()
    @Volatile
    private var senderRunning = false
    private var senderThread: Thread? = null
    private var droppedFrameCount = 0
    private var framesSinceLastFlush = 0
    private var lastFlushAtMs = 0L
    private var lastQueueReportAtMs = 0L
    private var lastReportedDroppedFrameCount = 0

    fun canStart(codecConfig: ByteArray?): Boolean {
        return codecConfig?.let(::extractParameterSets)?.isComplete == true
    }

    fun start(url: String, codecConfig: ByteArray?) {
        if (socket?.let { current -> current.isConnected && !current.isClosed } == true) {
            return
        }
        val currentParameterSets = codecConfig?.let(::extractParameterSets)
            ?.takeIf(H265ParameterSets::isComplete)
            ?: error("H265 VPS/SPS/PPS is not ready")
        parameterSets = currentParameterSets
        val uri = URI(url)
        val host = uri.host ?: error("RTSP host is empty")
        val port = if (uri.port > 0) uri.port else 554
        val nextSocket = Socket().apply {
            tcpNoDelay = true
            keepAlive = true
            sendBufferSize = SOCKET_SEND_BUFFER_SIZE
            soTimeout = SOCKET_READ_TIMEOUT_MS
        }
        synchronized(transportLock) {
            check(socket == null) { "RTSP transport is already starting" }
            socket = nextSocket
        }
        try {
            nextSocket.connect(InetSocketAddress(host, port), SOCKET_CONNECT_TIMEOUT_MS)
            val nextInput = BufferedInputStream(nextSocket.getInputStream())
            val nextOutput = BufferedOutputStream(nextSocket.getOutputStream())
            synchronized(transportLock) {
                check(socket === nextSocket && !nextSocket.isClosed) { "RTSP start was cancelled" }
                input = nextInput
                output = nextOutput
            }
            statusListener("RTSP直推连接成功：$host:$port")
            request("OPTIONS", url)
            request(
                method = "ANNOUNCE",
                url = url,
                headers = linkedMapOf("Content-Type" to "application/sdp"),
                body = buildSdp(currentParameterSets),
            )
            val setup = request(
                method = "SETUP",
                url = "$url/trackID=0",
                headers = linkedMapOf("Transport" to "RTP/AVP/TCP;unicast;interleaved=0-1"),
            )
            session = setup.headers["session"]?.substringBefore(';')?.trim().orEmpty()
            request(
                method = "RECORD",
                url = url,
                headers = linkedMapOf("Session" to session, "Range" to "npt=0.000-"),
            )
            statusListener("RTSP直推已开始：session=$session")
            startSenderThread()
        } catch (error: Throwable) {
            closeTransport(nextSocket)
            session = ""
            parameterSets = null
            throw error
        }
    }

    fun sendFrame(data: ByteArray, presentationTimeUs: Long) {
        if (!senderRunning || socket?.let { current -> current.isConnected && !current.isClosed } != true) {
            return
        }
        var queueStatus: String? = null
        synchronized(sendLock) {
            while (pendingFrames.size >= MAX_PENDING_FRAMES) {
                pendingFrames.removeFirst()
                droppedFrameCount += 1
            }
            pendingFrames.addLast(PendingFrame(data, presentationTimeUs))
            val queuedFrames = pendingFrames.size
            val nowMs = System.currentTimeMillis()
            val droppedDelta = droppedFrameCount - lastReportedDroppedFrameCount
            val reportDueToDrops = droppedDelta > 0 &&
                (lastQueueReportAtMs == 0L || droppedDelta >= DROP_REPORT_INTERVAL || nowMs - lastQueueReportAtMs >= QUEUE_REPORT_INTERVAL_MS)
            val reportDueToFullQueue = queuedFrames >= MAX_PENDING_FRAMES && nowMs - lastQueueReportAtMs >= QUEUE_REPORT_INTERVAL_MS
            if (reportDueToDrops || reportDueToFullQueue) {
                lastQueueReportAtMs = nowMs
                lastReportedDroppedFrameCount = droppedFrameCount
                queueStatus = "RTSP发送队列：queued=$queuedFrames dropped=$droppedFrameCount"
            }
            sendLock.notifyAll()
        }
        queueStatus?.let(statusListener)
    }

    fun stop() {
        senderRunning = false
        synchronized(sendLock) {
            pendingFrames.clear()
            sendLock.notifyAll()
        }
        closeTransport()
        val currentSenderThread = senderThread
        if (currentSenderThread != null && Thread.currentThread() != currentSenderThread) {
            runCatching { currentSenderThread.join(SENDER_JOIN_TIMEOUT_MS) }
        }
        senderThread = null
        session = ""
        firstPresentationTimeUs = -1L
        parameterSets = null
        droppedFrameCount = 0
        framesSinceLastFlush = 0
        lastFlushAtMs = 0L
        lastQueueReportAtMs = 0L
        lastReportedDroppedFrameCount = 0
    }

    private fun startSenderThread() {
        senderRunning = true
        senderThread = Thread {
            runCatching {
                while (senderRunning) {
                    val frame = synchronized(sendLock) {
                        while (senderRunning && pendingFrames.isEmpty()) {
                            sendLock.wait(200)
                        }
                        if (!senderRunning || pendingFrames.isEmpty()) null else pendingFrames.removeFirst()
                    } ?: continue
                    sendFrameNow(frame)
                }
            }.onFailure { error ->
                val shouldReportFailure = senderRunning
                senderRunning = false
                closeTransport()
                if (shouldReportFailure) {
                    statusListener("RTSP异步发送失败：${error.message ?: error::class.java.simpleName}")
                }
            }
        }.apply {
            name = "SmartCabinetRtspSender"
            isDaemon = true
            start()
        }
    }

    private fun sendFrameNow(frame: PendingFrame) {
        if (firstPresentationTimeUs < 0) {
            firstPresentationTimeUs = frame.presentationTimeUs
        }
        val timestamp = (((frame.presentationTimeUs - firstPresentationTimeUs) * 90L / 1000L) and 0xffffffffL).toInt()
        val nals = splitAnnexB(frame.data)
        nals.forEachIndexed { index, nal ->
            val isLastNal = index == nals.lastIndex
            packetizeNal(nal, timestamp, isLastNal)
        }
        flushOutputIfNeeded()
    }

    private fun flushOutputIfNeeded() {
        framesSinceLastFlush += 1
        val nowMs = System.currentTimeMillis()
        if (lastFlushAtMs <= 0L || framesSinceLastFlush >= FLUSH_FRAME_INTERVAL || nowMs - lastFlushAtMs >= FLUSH_TIME_INTERVAL_MS) {
            output?.flush()
            framesSinceLastFlush = 0
            lastFlushAtMs = nowMs
        }
    }

    private fun request(
        method: String,
        url: String,
        headers: Map<String, String> = emptyMap(),
        body: String = "",
    ): RtspResponse {
        val requestHeaders = linkedMapOf<String, String>()
        requestHeaders["CSeq"] = (cSeq++).toString()
        requestHeaders.putAll(headers)
        if (body.isNotEmpty()) {
            requestHeaders["Content-Length"] = body.toByteArray(Charsets.UTF_8).size.toString()
        }
        val raw = buildString {
            append(method)
            append(' ')
            append(url)
            append(" RTSP/1.0\r\n")
            requestHeaders.forEach { (key, value) -> append("$key: $value\r\n") }
            append("\r\n")
            append(body)
        }
        val currentOutput = output ?: error("RTSP output is not ready")
        currentOutput.write(raw.toByteArray(Charsets.UTF_8))
        currentOutput.flush()
        val response = readResponse()
        if (response.code !in 200..299) {
            error("RTSP $method failed: code=${response.code}, text=${response.statusLine}")
        }
        return response
    }

    private fun readResponse(): RtspResponse {
        val currentInput = input ?: error("RTSP input is not ready")
        val bytes = ByteArrayOutputStream()
        var matched = 0
        val end = byteArrayOf('\r'.code.toByte(), '\n'.code.toByte(), '\r'.code.toByte(), '\n'.code.toByte())
        while (true) {
            val value = currentInput.read()
            if (value < 0) {
                error("RTSP server closed connection")
            }
            val byte = value.toByte()
            if (bytes.size() >= MAX_RTSP_RESPONSE_HEADER_BYTES) {
                error("RTSP response header is too large")
            }
            bytes.write(value)
            matched = if (byte == end[matched]) matched + 1 else if (byte == end[0]) 1 else 0
            if (matched == end.size) {
                break
            }
        }
        val text = bytes.toByteArray().toString(Charsets.UTF_8)
        val lines = text.split("\r\n").filter { it.isNotEmpty() }
        val statusLine = lines.firstOrNull().orEmpty()
        val code = statusLine.split(' ').getOrNull(1)?.toIntOrNull() ?: 0
        val headers = lines.drop(1).mapNotNull { line ->
            val index = line.indexOf(':')
            if (index <= 0) null else line.substring(0, index).lowercase() to line.substring(index + 1).trim()
        }.toMap()
        val contentLength = headers["content-length"]?.toIntOrNull()?.coerceAtLeast(0) ?: 0
        if (contentLength > MAX_RTSP_RESPONSE_BODY_BYTES) {
            error("RTSP response body is too large: $contentLength")
        }
        var remaining = contentLength
        val discardBuffer = ByteArray(minOf(remaining.coerceAtLeast(1), RESPONSE_DISCARD_BUFFER_SIZE))
        while (remaining > 0) {
            val read = currentInput.read(discardBuffer, 0, minOf(remaining, discardBuffer.size))
            if (read < 0) {
                error("RTSP server closed connection while reading response body")
            }
            remaining -= read
        }
        return RtspResponse(code, statusLine, headers)
    }

    private fun buildSdp(params: H265ParameterSets): String {
        val fmtp = "a=fmtp:96 sprop-vps=${params.vps};sprop-sps=${params.sps};sprop-pps=${params.pps}\r\n"
        return "v=0\r\n" +
            "o=- 0 0 IN IP4 127.0.0.1\r\n" +
            "s=SmartCabinet\r\n" +
            "c=IN IP4 0.0.0.0\r\n" +
            "t=0 0\r\n" +
            "m=video 0 RTP/AVP 96\r\n" +
            "a=rtpmap:96 H265/90000\r\n" +
            fmtp +
            "a=control:trackID=0\r\n"
    }

    private fun extractParameterSets(codecConfig: ByteArray): H265ParameterSets {
        var vps = ""
        var sps = ""
        var pps = ""
        splitAnnexB(codecConfig).forEach { nal ->
            if (nal.size < 2) return@forEach
            val type = (nal[0].toInt() ushr 1) and 0x3f
            val encoded = Base64.encodeToString(nal, Base64.NO_WRAP)
            when (type) {
                32 -> vps = encoded
                33 -> sps = encoded
                34 -> pps = encoded
            }
        }
        return H265ParameterSets(vps = vps, sps = sps, pps = pps)
    }

    private fun splitAnnexB(data: ByteArray): List<ByteArray> {
        val starts = mutableListOf<Pair<Int, Int>>()
        var index = 0
        while (index < data.size - 3) {
            val length = startCodeLength(data, index)
            if (length > 0) {
                starts += index to length
                index += length
            } else {
                index += 1
            }
        }
        if (starts.isEmpty()) {
            return listOf(data)
        }
        return starts.mapIndexedNotNull { i, start ->
            val nalStart = start.first + start.second
            val nalEnd = starts.getOrNull(i + 1)?.first ?: data.size
            if (nalEnd <= nalStart) null else data.copyOfRange(nalStart, nalEnd)
        }
    }

    private fun startCodeLength(data: ByteArray, index: Int): Int {
        if (index + 3 <= data.size && data[index] == 0.toByte() && data[index + 1] == 0.toByte() && data[index + 2] == 1.toByte()) {
            return 3
        }
        if (index + 4 <= data.size && data[index] == 0.toByte() && data[index + 1] == 0.toByte() && data[index + 2] == 0.toByte() && data[index + 3] == 1.toByte()) {
            return 4
        }
        return 0
    }

    private fun packetizeNal(nal: ByteArray, timestamp: Int, marker: Boolean) {
        if (nal.size <= MAX_RTP_PAYLOAD) {
            writeInterleavedRtp(buildRtpPacket(nal, timestamp, marker))
            return
        }
        val originalType = (nal[0].toInt() ushr 1) and 0x3f
        val fuIndicator = byteArrayOf(((nal[0].toInt() and 0x81) or (49 shl 1)).toByte(), nal[1])
        var offset = 2
        var first = true
        while (offset < nal.size) {
            val payloadSize = minOf(MAX_RTP_PAYLOAD - 3, nal.size - offset)
            val end = offset + payloadSize >= nal.size
            val fuHeader = ((if (first) 0x80 else 0) or (if (end) 0x40 else 0) or originalType).toByte()
            val payload = ByteArray(3 + payloadSize)
            payload[0] = fuIndicator[0]
            payload[1] = fuIndicator[1]
            payload[2] = fuHeader
            nal.copyInto(payload, 3, offset, offset + payloadSize)
            writeInterleavedRtp(buildRtpPacket(payload, timestamp, marker && end))
            offset += payloadSize
            first = false
        }
    }

    private fun buildRtpPacket(payload: ByteArray, timestamp: Int, marker: Boolean): ByteArray {
        val packet = ByteArray(12 + payload.size)
        packet[0] = 0x80.toByte()
        packet[1] = ((if (marker) 0x80 else 0) or 96).toByte()
        packet[2] = (sequenceNumber ushr 8).toByte()
        packet[3] = sequenceNumber.toByte()
        sequenceNumber = (sequenceNumber + 1) and 0xffff
        packet[4] = (timestamp ushr 24).toByte()
        packet[5] = (timestamp ushr 16).toByte()
        packet[6] = (timestamp ushr 8).toByte()
        packet[7] = timestamp.toByte()
        packet[8] = (ssrc ushr 24).toByte()
        packet[9] = (ssrc ushr 16).toByte()
        packet[10] = (ssrc ushr 8).toByte()
        packet[11] = ssrc.toByte()
        payload.copyInto(packet, 12)
        return packet
    }

    private fun writeInterleavedRtp(packet: ByteArray) {
        val header = byteArrayOf('$'.code.toByte(), 0, (packet.size ushr 8).toByte(), packet.size.toByte())
        val currentOutput = output ?: error("RTSP output is not ready")
        currentOutput.write(header)
        currentOutput.write(packet)
    }

    private fun closeTransport(expectedSocket: Socket? = null) {
        val transport = synchronized(transportLock) {
            if (expectedSocket != null && socket !== expectedSocket) {
                return
            }
            val current = Transport(socket, input, output)
            socket = null
            input = null
            output = null
            current
        }
        runCatching { transport.socket?.close() }
        runCatching { transport.input?.close() }
        runCatching { transport.output?.close() }
    }

    private data class RtspResponse(
        val code: Int,
        val statusLine: String,
        val headers: Map<String, String>,
    )

    private data class PendingFrame(
        val data: ByteArray,
        val presentationTimeUs: Long,
    )

    private data class Transport(
        val socket: Socket?,
        val input: BufferedInputStream?,
        val output: BufferedOutputStream?,
    )

    private data class H265ParameterSets(
        val vps: String,
        val sps: String,
        val pps: String,
    ) {
        val isComplete: Boolean
            get() = vps.isNotBlank() && sps.isNotBlank() && pps.isNotBlank()
    }

    companion object {
        private const val MAX_RTP_PAYLOAD = 1200
        private const val MAX_PENDING_FRAMES = 4
        private const val DROP_REPORT_INTERVAL = 30
        private const val QUEUE_REPORT_INTERVAL_MS = 5_000L
        private const val SOCKET_CONNECT_TIMEOUT_MS = 3_000
        private const val SOCKET_READ_TIMEOUT_MS = 3_000
        private const val SENDER_JOIN_TIMEOUT_MS = 1_000L
        private const val MAX_RTSP_RESPONSE_HEADER_BYTES = 64 * 1024
        private const val MAX_RTSP_RESPONSE_BODY_BYTES = 1024 * 1024
        private const val RESPONSE_DISCARD_BUFFER_SIZE = 8 * 1024
        private const val SOCKET_SEND_BUFFER_SIZE = 1024 * 1024
        private const val FLUSH_FRAME_INTERVAL = 3
        private const val FLUSH_TIME_INTERVAL_MS = 100L
    }
}
