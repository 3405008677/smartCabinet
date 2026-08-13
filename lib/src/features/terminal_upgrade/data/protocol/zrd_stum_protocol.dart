import 'package:smart_cabinet/src/core/network/protocol/tcp_protocol.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/domain/entities/terminal_upgrade.dart';

/// ZRD STUM 标准消息中的终端或服务端方向。
enum ZrdStumDirection {
  /// 终端上行消息，关键字以 T 开头。
  terminal,

  /// 服务端下行消息，关键字以 S 开头。
  server,
}

/// 已解析的 STUM 标准消息。
class ZrdStumMessage {
  /// 创建一条解析后的消息。
  const ZrdStumMessage({
    required this.direction,
    required this.commandCode,
    required this.segments,
    required this.serialNumber,
  });

  /// 消息方向。
  final ZrdStumDirection direction;

  /// 去掉 T/S 后的两位命令码。
  final String commandCode;

  /// 除关键字外的全部键值段。
  final Map<String, String> segments;

  /// SN 消息序号。
  ///
  /// 仅协议明确列出的未登录特殊回复 `<S00>|00:NG0` 可以没有 SN，此时为 null。
  final int? serialNumber;

  /// 读取必需属性，不存在时抛出协议 NG2 错误。
  String require(String key) {
    final value = segments[key];
    if (value == null) {
      throw ZrdStumProtocolException.missingKey(key);
    }
    return value;
  }
}

/// 可映射为 T00 NG1/NG2/NG3 的协议异常。
class ZrdStumProtocolException implements Exception {
  /// 创建协议异常。
  const ZrdStumProtocolException({
    required this.errorCode,
    required this.message,
    this.attributeKey = '',
  });

  /// NG 后的一位错误码。
  final String errorCode;

  /// 本地诊断说明。
  final String message;

  /// NG2/NG3 可附带的属性键。
  final String attributeKey;

  /// 创建消息格式或关键字错误。
  factory ZrdStumProtocolException.format(String message) {
    return ZrdStumProtocolException(errorCode: '1', message: message);
  }

  /// 创建缺少属性键错误。
  factory ZrdStumProtocolException.missingKey(String key) {
    return ZrdStumProtocolException(
      errorCode: '2',
      attributeKey: key,
      message: '缺少属性 $key',
    );
  }

  /// 创建属性值解析错误。
  factory ZrdStumProtocolException.invalidValue(String key, String message) {
    return ZrdStumProtocolException(
      errorCode: '3',
      attributeKey: key,
      message: message,
    );
  }

  /// 按协议组合 NG 值，例如 NG3AD。
  String get responseValue => 'NG$errorCode$attributeKey';

  @override
  String toString() => message;
}

/// 1 到 9999 循环使用的消息序号生成器。
class ZrdStumMessageSequence {
  /// 创建消息序号生成器；[initialValue] 表示下一次返回值。
  ZrdStumMessageSequence({int initialValue = 1})
    : _nextValue = _validateInitialValue(initialValue);

  int _nextValue;

  /// 返回当前序号并推进到下一位，9999 后回到 1。
  int next() {
    final value = _nextValue;
    _nextValue = value == 9999 ? 1 : value + 1;
    return value;
  }

  static int _validateInitialValue(int value) {
    if (value < 1 || value > 9999) {
      throw ArgumentError.value(value, 'initialValue', '必须在 1 到 9999 之间');
    }
    return value;
  }
}

/// ZRD STUM V1.01.0428 ASCII 报文编解码器。
class ZrdStumProtocolCodec {
  const ZrdStumProtocolCodec._();

  /// 编码 T01 登录消息。
  ///
  /// [identity] 必须由 Repository 绑定当前监控代际，协议设置不保存第二份身份。
  static String encodeLogin(
    TerminalUpgradeSettings settings, {
    required TerminalUpgradeLoginIdentity identity,
    required int serialNumber,
  }) {
    _validateSerialNumber(serialNumber);
    final validationError = settings.validate() ?? identity.validate();
    if (validationError != null) {
      throw ArgumentError(validationError);
    }
    return _encode(
      direction: ZrdStumDirection.terminal,
      commandCode: '01',
      segments: <MapEntry<String, String>>[
        MapEntry<String, String>('ID', settings.terminalId.trim()),
        MapEntry<String, String>('IM', identity.moduleId.trim()),
        MapEntry<String, String>('DP', identity.dataProtocolIp.trim()),
        MapEntry<String, String>('CD', identity.chipId.trim()),
        MapEntry<String, String>('SN', '$serialNumber'),
      ],
    );
  }

  /// 编码 T03 URL 升级请求。
  ///
  /// Android `versionName` 会按现场服务端约定编码为
  /// `SL_V{versionName}_{versionDate}`；日期必须是当前 APK 的构建批次日期，
  /// 不能在每次请求时读取系统当天日期。
  static String encodeUpgradeRequest({
    required String currentVersion,
    String versionDate = '20260812',
    required String packageTag,
    required int serialNumber,
  }) {
    _validateSerialNumber(serialNumber);
    final version = formatUpgradeRequestVersion(
      currentVersion: currentVersion,
      versionDate: versionDate,
    );
    if (!_isProtocolValue(version)) {
      throw ArgumentError.value(
        currentVersion,
        'currentVersion',
        '版本号不是有效 ASCII 值',
      );
    }
    final tag = packageTag.trim();
    if (!_isProtocolValue(tag)) {
      throw ArgumentError.value(packageTag, 'packageTag', 'PT 不是有效 ASCII 值');
    }
    return _encode(
      direction: ZrdStumDirection.terminal,
      commandCode: '03',
      segments: <MapEntry<String, String>>[
        const MapEntry<String, String>('DT', '1'),
        MapEntry<String, String>('VE', version),
        if (tag.isNotEmpty) MapEntry<String, String>('PT', tag),
        MapEntry<String, String>('SN', '$serialNumber'),
      ],
    );
  }

  /// 把 Android `versionName` 转换为现场服务端识别的 T03 `VE`。
  static String formatUpgradeRequestVersion({
    required String currentVersion,
    required String versionDate,
  }) {
    var appVersion = currentVersion.trim();
    if (RegExp(r'^V[0-9]').hasMatch(appVersion)) {
      appVersion = appVersion.substring(1);
    }
    if (appVersion.isEmpty || !_isProtocolValue(appVersion)) {
      throw ArgumentError.value(
        currentVersion,
        'currentVersion',
        '版本号不是有效 ASCII 值',
      );
    }
    final date = versionDate.trim();
    if (!_isValidCompactDate(date)) {
      throw ArgumentError.value(
        versionDate,
        'versionDate',
        '版本日期必须是有效的 yyyyMMdd',
      );
    }
    return 'SL_V${appVersion}_$date';
  }

  /// 编码 T00 对服务端消息的通用应答。
  static String encodeTerminalReply({
    required String serverCommandCode,
    required String result,
    required int serialNumber,
  }) {
    _validateSerialNumber(serialNumber);
    if (!RegExp(r'^\d{2}$').hasMatch(serverCommandCode)) {
      throw ArgumentError.value(serverCommandCode, 'serverCommandCode');
    }
    // 协议为错误码预留 0-9、A-Z；NG2/NG3 等当前定义允许继续带两位属性键。
    if (result != 'OK' &&
        !RegExp(r'^NG[0-9A-Z](?:[A-Z]{2})?$').hasMatch(result)) {
      throw ArgumentError.value(result, 'result', '应答必须为 OK 或合法 NG 错误');
    }
    return _encode(
      direction: ZrdStumDirection.terminal,
      commandCode: '00',
      segments: <MapEntry<String, String>>[
        MapEntry<String, String>(serverCommandCode, result),
        MapEntry<String, String>('SN', '$serialNumber'),
      ],
    );
  }

  /// 解析不含末尾 CRLF 的一条标准消息。
  static ZrdStumMessage decode(String frame) {
    if (frame.isEmpty ||
        frame.contains('\r') ||
        frame.contains('\n') ||
        frame.codeUnits.any((unit) => unit > 0x7f)) {
      throw ZrdStumProtocolException.format('消息包含空内容、非 ASCII 字符或换行');
    }
    final parts = frame.split('|');
    if (parts.length < 2) {
      throw ZrdStumProtocolException.format('消息缺少属性段');
    }
    final keywordMatch = RegExp(
      r'^<([TS])(\d{2})>$',
      caseSensitive: false,
    ).firstMatch(parts.first);
    if (keywordMatch == null) {
      throw ZrdStumProtocolException.format('关键字格式错误');
    }
    final direction = keywordMatch.group(1)!.toUpperCase() == 'T'
        ? ZrdStumDirection.terminal
        : ZrdStumDirection.server;
    final commandCode = keywordMatch.group(2)!;
    final segments = <String, String>{};

    for (var index = 1; index < parts.length; index += 1) {
      final segment = parts[index];
      var delimiterIndex = segment.indexOf(':');
      // 协议示例分别把 S00 回复段写成“03,OK”、把 S03 版本段写成
      // “VE,V1...” 。仅兼容这两个已知首段笔误，其它属性仍严格要求冒号。
      final isDocumentedCommaVariant =
          index == 1 &&
          ((direction == ZrdStumDirection.server &&
                  commandCode == '00' &&
                  RegExp(r'^\d{2},').hasMatch(segment)) ||
              (direction == ZrdStumDirection.server &&
                  commandCode == '03' &&
                  segment.startsWith('VE,')));
      if (delimiterIndex < 0 && isDocumentedCommaVariant) {
        delimiterIndex = segment.indexOf(',');
      }
      if (delimiterIndex != 2) {
        throw ZrdStumProtocolException.format('属性段格式错误');
      }
      final key = segment.substring(0, delimiterIndex);
      final value = segment.substring(delimiterIndex + 1);
      final isReplyKey =
          commandCode == '00' && index == 1 && RegExp(r'^\d{2}$').hasMatch(key);
      if (!isReplyKey && !RegExp(r'^[A-Z]{2}$').hasMatch(key)) {
        throw ZrdStumProtocolException.format('属性键格式错误');
      }
      if (segments.containsKey(key)) {
        throw ZrdStumProtocolException.format('属性键 $key 重复');
      }
      segments[key] = value;
    }

    final serialText = segments['SN'];
    final allowsMissingSerial =
        direction == ZrdStumDirection.server &&
        commandCode == '00' &&
        segments.length == 1 &&
        segments['00'] == 'NG0';
    int? serialNumber;
    if (serialText == null) {
      if (!allowsMissingSerial) {
        throw ZrdStumProtocolException.missingKey('SN');
      }
    } else {
      serialNumber = RegExp(r'^[0-9]{1,4}$').hasMatch(serialText)
          ? int.tryParse(serialText)
          : null;
      if (serialNumber == null || serialNumber < 1 || serialNumber > 9999) {
        throw ZrdStumProtocolException.invalidValue('SN', 'SN 必须在 1 到 9999 之间');
      }
    }

    return ZrdStumMessage(
      direction: direction,
      commandCode: commandCode,
      segments: Map<String, String>.unmodifiable(segments),
      serialNumber: serialNumber,
    );
  }

  /// 把当前 T03 请求窗口内的 S03 解析为可安装的 URL 升级包。
  ///
  /// `VE=0` 或目标版本与当前应用相同会返回 null；其它新版本必须提供有效的
  /// HTTP/HTTPS `AD`、完整文件 `MD`，并在请求配置了 `PT` 时严格匹配。
  /// 协议没有定义 `AD=2` 的分包规则，因此会抛出可回执为 `NG3AD` 的异常。
  static TerminalUpgradeOffer? parseUpgradeOffer(
    ZrdStumMessage message, {
    required String currentVersion,
    required String expectedPackageTag,
  }) {
    if (message.direction != ZrdStumDirection.server ||
        message.commandCode != '03') {
      throw ZrdStumProtocolException.format('升级包消息必须是服务端 S03');
    }

    final targetVersion = message.require('VE').trim();
    if (targetVersion.isEmpty) {
      throw ZrdStumProtocolException.invalidValue('VE', 'VE 不能为空');
    }
    if (targetVersion == '0' ||
        _sameProtocolVersion(targetVersion, currentVersion)) {
      // 协议无升级示例允许省略 PT/MD，且 AD 可以为空，必须在新包字段前识别。
      return null;
    }

    final expectedTag = expectedPackageTag.trim();
    final actualTag = message.segments['PT']?.trim() ?? '';
    if (expectedTag.isNotEmpty && !message.segments.containsKey('PT')) {
      throw ZrdStumProtocolException.missingKey('PT');
    }
    if (expectedTag.isNotEmpty && actualTag != expectedTag) {
      throw ZrdStumProtocolException.invalidValue('PT', 'S03 的 PT 与 T03 请求不一致');
    }

    final address = message.require('AD').trim();
    if (address == '2') {
      throw ZrdStumProtocolException.invalidValue(
        'AD',
        '协议未定义 AD=2 的分包帧，当前版本不支持',
      );
    }
    if (address.isEmpty || address == '0') {
      throw ZrdStumProtocolException.invalidValue('AD', '存在目标版本时 AD 必须是下载地址');
    }
    final uri = Uri.tryParse(address);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw ZrdStumProtocolException.invalidValue(
        'AD',
        'AD 不是有效 HTTP/HTTPS 地址',
      );
    }

    final md5 = message.require('MD').trim();
    if (!RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(md5)) {
      throw ZrdStumProtocolException.invalidValue('MD', 'MD 必须是 32 位十六进制值');
    }
    return TerminalUpgradeOffer(
      targetVersion: targetVersion,
      downloadUrl: uri,
      md5: md5,
      packageTag: actualTag,
      serialNumber: message.serialNumber!,
    );
  }

  /// 编码一条完整标准消息并补齐 CRLF。
  static String _encode({
    required ZrdStumDirection direction,
    required String commandCode,
    required List<MapEntry<String, String>> segments,
  }) {
    if (!RegExp(r'^\d{2}$').hasMatch(commandCode)) {
      throw ArgumentError.value(commandCode, 'commandCode', '命令码必须是两位数字');
    }
    final prefix = direction == ZrdStumDirection.terminal ? 'T' : 'S';
    final body = segments
        .map((entry) {
          if (!RegExp(r'^[A-Z0-9]{2}$').hasMatch(entry.key) ||
              !_isProtocolValue(entry.value)) {
            throw ArgumentError('非法 STUM 属性：${entry.key}');
          }
          return '${entry.key}:${entry.value}';
        })
        .join('|');
    return '<$prefix$commandCode>|$body\r\n';
  }

  /// 编码前约束 SN，避免公共编码入口生成自身解码器会拒绝的报文。
  static void _validateSerialNumber(int serialNumber) {
    if (serialNumber < 1 || serialNumber > 9999) {
      throw ArgumentError.value(
        serialNumber,
        'serialNumber',
        '必须在 1 到 9999 之间',
      );
    }
  }
}

/// 检查内容是否可安全放入协议 ASCII 消息。
bool _isProtocolValue(String value) {
  return !value.contains('|') &&
      !value.contains('\r') &&
      !value.contains('\n') &&
      value.codeUnits.every((unit) => unit <= 0x7f);
}

/// 协议示例同时使用 `V1.2.3` 与 `1.2.3`，只兼容数字前单个大写 V。
bool _sameProtocolVersion(String left, String right) {
  String normalize(String value) {
    var trimmed = value.trim();
    final appMatch = RegExp(r'^SL_APP_V(.+)$').firstMatch(trimmed);
    if (appMatch != null) {
      trimmed = appMatch.group(1)!;
    }
    final slMatch = RegExp(r'^SL_V(.+)_([0-9]{8})$').firstMatch(trimmed);
    if (slMatch != null && _isValidCompactDate(slMatch.group(2)!)) {
      trimmed = slMatch.group(1)!;
    }
    if (RegExp(r'^V[0-9]').hasMatch(trimmed)) {
      return trimmed.substring(1);
    }
    return trimmed;
  }

  return normalize(left) == normalize(right);
}

/// 校验 STUM 版本批次日期，拒绝被 DateTime 自动进位的无效日期。
bool _isValidCompactDate(String value) {
  if (!RegExp(r'^[0-9]{8}$').hasMatch(value)) {
    return false;
  }
  final year = int.parse(value.substring(0, 4));
  final month = int.parse(value.substring(4, 6));
  final day = int.parse(value.substring(6, 8));
  final parsed = DateTime.utc(year, month, day);
  return parsed.year == year && parsed.month == month && parsed.day == day;
}

/// 增量拆分 TCP 字节流中的 CRLF 标准消息。
class ZrdStumFrameDecoder {
  /// 创建帧解码器。
  ZrdStumFrameDecoder({this.maxFrameBytes = 16 * 1024}) {
    if (maxFrameBytes <= 0) {
      throw ArgumentError.value(maxFrameBytes, 'maxFrameBytes', '最大帧长度必须大于 0');
    }
  }

  /// 防止服务端持续发送无 CRLF 数据造成内存无限增长。
  final int maxFrameBytes;

  final List<int> _buffer = <int>[];

  /// 追加一段 Socket 数据并返回其中全部完整帧。
  List<String> add(List<int> bytes) {
    if (bytes.any((byte) => byte < 0 || byte > 0x7f)) {
      _buffer.clear();
      throw ZrdStumProtocolException.format('服务端消息包含非 ASCII 字节');
    }
    _buffer.addAll(bytes);
    final frames = <String>[];
    var frameStart = 0;
    for (var index = 0; index + 1 < _buffer.length; index += 1) {
      if (_buffer[index] != 13 || _buffer[index + 1] != 10) {
        continue;
      }
      final length = index - frameStart;
      if (length <= 0 || length > maxFrameBytes) {
        _buffer.clear();
        throw ZrdStumProtocolException.format('服务端消息长度无效');
      }
      frames.add(String.fromCharCodes(_buffer.sublist(frameStart, index)));
      frameStart = index + 2;
      index += 1;
    }
    if (frameStart > 0) {
      _buffer.removeRange(0, frameStart);
    }
    // 允许长度刚好达到上限的帧把 CR 与 LF 分在两个 TCP 数据块中。
    final bufferedLimit =
        maxFrameBytes + (_buffer.isNotEmpty && _buffer.last == 13 ? 1 : 0);
    if (_buffer.length > bufferedLimit) {
      _buffer.clear();
      throw ZrdStumProtocolException.format('服务端消息超过最大帧长度');
    }
    return frames;
  }

  /// 清除断线前未完成的残帧，避免污染新连接。
  void reset() => _buffer.clear();
}

/// 把通用 TCP 字节流直接转换为强类型 STUM 消息的适配器。
///
/// 通用 [TcpProtocolClient] 只依赖 [TcpFrameDecoder]，后续协议可以提供自己的
/// 帧适配器，而不需要复制连接、串行写入、请求超时和断线清理逻辑。
final class ZrdStumMessageFrameDecoder
    implements TcpFrameDecoder<ZrdStumMessage> {
  final ZrdStumFrameDecoder _frameDecoder = ZrdStumFrameDecoder();

  @override
  List<ZrdStumMessage> add(List<int> bytes) {
    return _frameDecoder
        .add(bytes)
        .map(ZrdStumProtocolCodec.decode)
        .toList(growable: false);
  }

  @override
  void reset() => _frameDecoder.reset();
}
