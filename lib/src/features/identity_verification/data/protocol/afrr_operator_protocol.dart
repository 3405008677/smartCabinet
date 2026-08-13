import 'dart:convert';
import 'dart:typed_data';

import 'package:smart_cabinet/src/core/network/protocol/tcp_protocol.dart';
import 'package:smart_cabinet/src/features/identity_verification/data/dtos/operator_login_dto.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_login_request.dart';

/// AFRR 智能监管柜协议格式或校验异常。
class AfrrOperatorProtocolException implements Exception {
  /// 创建带稳定错误说明的协议异常。
  const AfrrOperatorProtocolException(this.message);

  /// 可用于日志和登录错误映射的诊断说明。
  final String message;

  @override
  String toString() => message;
}

/// 已完成反转义、长度和异或校验的 AFRR 消息。
final class AfrrOperatorMessage {
  /// 创建一条解析后的协议消息。
  const AfrrOperatorMessage({
    required this.keyword,
    required this.shelfCode,
    required this.serialNumber,
    required this.items,
  });

  /// 两字节消息关键字，例如 B170。
  final int keyword;

  /// 由 8 字节 BCD 解码得到的 16 位货架编码。
  final String shelfCode;

  /// 当前消息头中的流水号。
  final int serialNumber;

  /// 消息体中的 KLV 数据项；同一个 Key 可以重复出现。
  final Map<int, List<Uint8List>> items;

  /// B170 回复中 `0x01` 项携带的原请求指令码。
  ///
  /// 文档标准专用回复只携带两字节原流水号；现场服务的精简回复使用五字节
  /// `原指令码 + 原流水号 + 结果码`，只有后一种格式能返回该字段。
  int? get replyToKeyword {
    final value = _replyMetadata;
    if (value == null || value.length != 5) {
      return null;
    }
    return _readUint16(value, 0);
  }

  /// B170 回复中 `0x01` 项携带的原请求流水号。
  ///
  /// 同时兼容文档规定的两字节格式和现场服务返回的五字节精简格式。
  int? get replyToSerialNumber {
    final value = _replyMetadata;
    return switch (value?.length) {
      2 => _readUint16(value!, 0),
      5 => _readUint16(value!, 2),
      _ => null,
    };
  }

  /// 五字节精简回复末字节携带的处理结果码。
  int? get compactReplyResultCode {
    final value = _replyMetadata;
    if (value == null || value.length != 5) {
      return null;
    }
    return value[4];
  }

  /// `0xA0` 数据项解码后的 JSON 对象。
  Map<String, Object?>? get jsonPayload {
    final values = items[0xA0];
    if (values == null || values.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(utf8.decode(values.first));
    if (decoded is! Map) {
      throw const AfrrOperatorProtocolException('AFRR JSON 根节点不是对象');
    }
    return decoded.map<String, Object?>((key, value) {
      return MapEntry<String, Object?>(key.toString(), value);
    });
  }

  Uint8List? get _replyMetadata {
    final values = items[0x01];
    if (values == null || values.isEmpty) {
      return null;
    }
    return values.first;
  }
}

/// 1 到 65535 循环使用的 AFRR 消息流水号。
final class AfrrOperatorMessageSequence {
  /// 创建流水号生成器；[initialValue] 表示下一次返回值。
  AfrrOperatorMessageSequence({int initialValue = 1})
    : _nextValue = _validateSerialNumber(initialValue);

  int _nextValue;

  /// 返回当前流水号并推进；65535 后回到 1。
  int next() {
    final value = _nextValue;
    _nextValue = value == 0xFFFF ? 1 : value + 1;
    return value;
  }
}

/// AFRR A170/B170 登录报文编解码器。
final class AfrrOperatorProtocolCodec {
  const AfrrOperatorProtocolCodec._();

  /// APP 上行登录消息关键字 A170。
  static const int loginRequestKeyword = 0xA170;

  /// 服务端登录专用回复关键字 B170。
  static const int loginResponseKeyword = 0xB170;

  /// 协议约定 `0xA0` JSON 单项最大 10 KiB。
  static const int maximumJsonBytes = 10 * 1024;

  /// 编码一条未启用 AES 的 A170 登录请求。
  static Uint8List encodeLogin({
    required OperatorLoginRequest request,
    required String shelfCode,
    required int serialNumber,
    required DateTime timestamp,
    Duration? timezoneOffset,
  }) {
    _validateSerialNumber(serialNumber);
    return encodeJsonRequest(
      jsonPayload: OperatorProtocolLoginRequestDto.fromRequest(
        request,
      ).toJson(),
      shelfCode: shelfCode,
      serialNumber: serialNumber,
      timestamp: timestamp,
      timezoneOffset: timezoneOffset,
    );
  }

  /// 编码一条携带 `0xA0` JSON 数据项的 A170 请求。
  ///
  /// APP `logon` 和后续业务命令共用同一套 AFRR 外层帧格式。
  static Uint8List encodeJsonRequest({
    required Map<String, Object?> jsonPayload,
    required String shelfCode,
    required int serialNumber,
    required DateTime timestamp,
    Duration? timezoneOffset,
  }) {
    _validateSerialNumber(serialNumber);
    final jsonBytes = utf8.encode(jsonEncode(jsonPayload));
    if (jsonBytes.length > maximumJsonBytes) {
      throw ArgumentError.value(
        jsonBytes.length,
        'jsonPayload',
        'AFRR JSON 超过 10 KiB',
      );
    }

    final body = BytesBuilder(copy: false)
      ..addByte(0x00)
      ..addByte(0x09)
      ..add(
        _encodeTimestamp(timestamp, timezoneOffset ?? timestamp.timeZoneOffset),
      )
      ..addByte(0xA0)
      ..add(_uint16Bytes(jsonBytes.length))
      ..add(jsonBytes);
    return encodeFrame(
      keyword: loginRequestKeyword,
      shelfCode: shelfCode,
      serialNumber: serialNumber,
      body: body.takeBytes(),
    );
  }

  /// 编码一条未启用 AES 的通用 AFRR 帧。
  ///
  /// 此入口用于协议复用和确定性测试；调用方负责按命令语义组织 KLV 消息体。
  static Uint8List encodeFrame({
    required int keyword,
    required String shelfCode,
    required int serialNumber,
    required List<int> body,
  }) {
    if (keyword < 0 || keyword > 0xFFFF) {
      throw RangeError.range(keyword, 0, 0xFFFF, 'keyword');
    }
    _validateSerialNumber(serialNumber);
    if (body.length > 0xFFFF) {
      throw ArgumentError.value(body.length, 'body', 'AFRR 消息体超过 65535 字节');
    }

    final raw = BytesBuilder(copy: false)
      ..addByte(0x7F)
      ..addByte(0x00)
      ..add(_uint16Bytes(keyword))
      ..add(_encodeShelfCode(shelfCode))
      ..add(_uint16Bytes(serialNumber))
      ..add(_uint16Bytes(body.length))
      ..add(body);
    final withoutTail = raw.takeBytes();
    var checksum = 0;
    for (var index = 2; index < withoutTail.length; index += 1) {
      checksum ^= withoutTail[index];
    }
    return _escapeFrame(<int>[...withoutTail, checksum, 0x7F]);
  }

  /// 解码单条包含头尾标记的完整 AFRR 帧。
  static AfrrOperatorMessage decodeFrame(List<int> escapedFrame) {
    final raw = _unescapeFrame(escapedFrame);
    if (raw.length < 18 || raw.first != 0x7F || raw.last != 0x7F) {
      throw const AfrrOperatorProtocolException('AFRR 帧头、帧尾或最小长度无效');
    }
    if (raw[1] != 0x00) {
      throw const AfrrOperatorProtocolException('当前登录链路尚未配置 AFRR AES 密钥');
    }

    final bodyLength = _readUint16(raw, 14);
    final expectedLength = 18 + bodyLength;
    if (raw.length != expectedLength) {
      throw AfrrOperatorProtocolException(
        'AFRR 消息体长度不匹配：声明 $bodyLength，实际 ${raw.length - 18}',
      );
    }
    var checksum = 0;
    for (var index = 2; index < 16 + bodyLength; index += 1) {
      checksum ^= raw[index];
    }
    if (checksum != raw[16 + bodyLength]) {
      throw const AfrrOperatorProtocolException('AFRR 异或校验失败');
    }

    final body = raw.sublist(16, 16 + bodyLength);
    return AfrrOperatorMessage(
      keyword: _readUint16(raw, 2),
      shelfCode: _decodeShelfCode(raw.sublist(4, 12)),
      serialNumber: _readUint16(raw, 12),
      items: _decodeItems(body),
    );
  }
}

/// 增量拆分粘包、半包并输出强类型 AFRR 消息。
final class AfrrOperatorFrameDecoder
    implements TcpFrameDecoder<AfrrOperatorMessage> {
  /// 创建帧解码器。
  AfrrOperatorFrameDecoder({this.maximumBufferedBytes = 24 * 1024}) {
    if (maximumBufferedBytes <= 0) {
      throw ArgumentError.value(
        maximumBufferedBytes,
        'maximumBufferedBytes',
        'AFRR 最大缓存长度必须大于 0',
      );
    }
  }

  /// 防止对端持续发送无帧尾数据造成缓存无限增长。
  final int maximumBufferedBytes;

  final List<int> _buffer = <int>[];

  @override
  List<AfrrOperatorMessage> add(List<int> bytes) {
    if (bytes.any((byte) => byte < 0 || byte > 255)) {
      throw ArgumentError.value(bytes, 'bytes', 'AFRR 输入必须是字节');
    }
    _buffer.addAll(bytes);
    final messages = <AfrrOperatorMessage>[];

    while (true) {
      final start = _buffer.indexOf(0x7F);
      if (start < 0) {
        if (_buffer.length > maximumBufferedBytes) {
          _buffer.clear();
          throw const AfrrOperatorProtocolException('AFRR 缓存中长期没有帧头');
        }
        return messages;
      }
      if (start > 0) {
        _buffer.removeRange(0, start);
      }
      final end = _buffer.indexOf(0x7F, 1);
      if (end < 0) {
        if (_buffer.length > maximumBufferedBytes) {
          _buffer.clear();
          throw const AfrrOperatorProtocolException('AFRR 未完成帧超过最大长度');
        }
        return messages;
      }
      if (end == 1) {
        _buffer.removeAt(0);
        continue;
      }

      final frame = _buffer.sublist(0, end + 1);
      _buffer.removeRange(0, end + 1);
      messages.add(AfrrOperatorProtocolCodec.decodeFrame(frame));
    }
  }

  @override
  void reset() => _buffer.clear();
}

Map<int, List<Uint8List>> _decodeItems(List<int> body) {
  final items = <int, List<Uint8List>>{};
  var offset = 0;
  while (offset < body.length) {
    final key = body[offset];
    offset += 1;
    final lengthBytes = key == 0xA0 ? 2 : 1;
    if (offset + lengthBytes > body.length) {
      throw const AfrrOperatorProtocolException('AFRR KLV 缺少长度字段');
    }
    final length = lengthBytes == 2 ? _readUint16(body, offset) : body[offset];
    offset += lengthBytes;
    if (offset + length > body.length) {
      throw const AfrrOperatorProtocolException('AFRR KLV 内容长度越界');
    }
    final value = Uint8List.fromList(body.sublist(offset, offset + length));
    offset += length;
    items.putIfAbsent(key, () => <Uint8List>[]).add(value);
  }
  return Map<int, List<Uint8List>>.unmodifiable(
    items.map((key, values) {
      return MapEntry<int, List<Uint8List>>(
        key,
        List<Uint8List>.unmodifiable(values),
      );
    }),
  );
}

Uint8List _escapeFrame(List<int> raw) {
  final escaped = BytesBuilder(copy: false)..addByte(0x7F);
  for (final byte in raw.skip(1).take(raw.length - 2)) {
    if (byte == 0x7F) {
      escaped
        ..addByte(0x7E)
        ..addByte(0x02);
    } else if (byte == 0x7E) {
      escaped
        ..addByte(0x7E)
        ..addByte(0x01);
    } else {
      escaped.addByte(byte);
    }
  }
  escaped.addByte(0x7F);
  return escaped.takeBytes();
}

Uint8List _unescapeFrame(List<int> escaped) {
  if (escaped.length < 2 || escaped.first != 0x7F || escaped.last != 0x7F) {
    throw const AfrrOperatorProtocolException('AFRR 待反转义数据缺少头尾标记');
  }
  final raw = BytesBuilder(copy: false)..addByte(0x7F);
  var index = 1;
  while (index < escaped.length - 1) {
    final byte = escaped[index];
    if (byte != 0x7E) {
      raw.addByte(byte);
      index += 1;
      continue;
    }
    if (index + 1 >= escaped.length - 1) {
      throw const AfrrOperatorProtocolException('AFRR 转义标记缺少后续字节');
    }
    final marker = escaped[index + 1];
    if (marker == 0x01) {
      raw.addByte(0x7E);
    } else if (marker == 0x02) {
      raw.addByte(0x7F);
    } else {
      throw const AfrrOperatorProtocolException('AFRR 转义序列无效');
    }
    index += 2;
  }
  raw.addByte(0x7F);
  return raw.takeBytes();
}

Uint8List _encodeShelfCode(String value) {
  final normalized = value.trim();
  final digits = switch (normalized.length) {
    15 when RegExp(r'^\d{15}$').hasMatch(normalized) => '0$normalized',
    16 when RegExp(r'^\d{16}$').hasMatch(normalized) => normalized,
    _ => throw ArgumentError.value(
      value,
      'shelfCode',
      'AFRR 货架编码必须是 15 位 IMEI 或 16 位 BCD 数字',
    ),
  };
  return Uint8List.fromList(<int>[
    for (var index = 0; index < digits.length; index += 2)
      int.parse(digits.substring(index, index + 2), radix: 16),
  ]);
}

String _decodeShelfCode(List<int> bytes) {
  if (bytes.length != 8) {
    throw const AfrrOperatorProtocolException('AFRR 货架编码不是 8 字节');
  }
  final buffer = StringBuffer();
  for (final byte in bytes) {
    final high = byte >> 4;
    final low = byte & 0x0F;
    if (high > 9 || low > 9) {
      throw const AfrrOperatorProtocolException('AFRR 货架编码不是有效 BCD');
    }
    buffer
      ..write(high)
      ..write(low);
  }
  return buffer.toString();
}

Uint8List _encodeTimestamp(DateTime value, Duration timezoneOffset) {
  final offsetMinutes = timezoneOffset.inMinutes;
  final absoluteMinutes = offsetMinutes.abs();
  final offsetHours = absoluteMinutes ~/ 60;
  final remainingMinutes = absoluteMinutes % 60;
  if (offsetHours > 15) {
    throw ArgumentError.value(
      value.timeZoneOffset,
      'timestamp',
      'AFRR 时区小时超过 15',
    );
  }
  final offsetByte = (offsetMinutes < 0 ? 0x10 : 0x00) | offsetHours;
  return Uint8List.fromList(<int>[
    _bcd(value.year ~/ 100),
    _bcd(value.year % 100),
    _bcd(value.month),
    _bcd(value.day),
    _bcd(value.hour),
    _bcd(value.minute),
    _bcd(value.second),
    offsetByte,
    _bcd(remainingMinutes),
  ]);
}

int _bcd(int value) {
  if (value < 0 || value > 99) {
    throw RangeError.range(value, 0, 99, 'value');
  }
  return ((value ~/ 10) << 4) | (value % 10);
}

Uint8List _uint16Bytes(int value) {
  return Uint8List.fromList(<int>[(value >> 8) & 0xFF, value & 0xFF]);
}

int _readUint16(List<int> bytes, int offset) {
  return (bytes[offset] << 8) | bytes[offset + 1];
}

int _validateSerialNumber(int value) {
  if (value < 1 || value > 0xFFFF) {
    throw ArgumentError.value(
      value,
      'serialNumber',
      'AFRR 流水号必须在 1 到 65535 之间',
    );
  }
  return value;
}
