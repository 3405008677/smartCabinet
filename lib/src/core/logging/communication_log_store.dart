import 'dart:async';
import 'dart:convert';

/// 通讯日志的目标类型。
enum CommunicationTargetType {
  /// 与平台、协议服务或 MQTT broker 的通讯。
  server,

  /// 与 Android 原生层或终端外设的通讯。
  hardware,

  /// ZRD STUM 终端升级协议的登录、检查、应答与服务端下发指令。
  upgradeCommand,
}

/// 以柜机软件为观察点的通讯方向。
enum CommunicationDirection {
  /// 软件发送，界面展示为“上报”。
  outbound,

  /// 软件接收，界面展示为“下发”。
  inbound,
}

/// 单条已经脱敏、可供管理员查看的通讯日志。
class CommunicationLogEntry {
  /// 创建一条不可变通讯日志。
  const CommunicationLogEntry({
    required this.id,
    required this.targetType,
    required this.direction,
    required this.channel,
    required this.operation,
    required this.messageBody,
    required this.requestTime,
    required this.result,
    required this.completeInformation,
  });

  /// 进程内单调递增标识。
  final int id;

  /// 服务器、硬件或升级指令。
  final CommunicationTargetType targetType;

  /// 上报或下发。
  final CommunicationDirection direction;

  /// TCP、MQTT、HTTP 或 MethodChannel 等通讯通道。
  final String channel;

  /// 当前通讯动作名称。
  final String operation;

  /// 已脱敏的消息体文本。
  final String messageBody;

  /// 发起发送或收到消息的本地时间。
  final DateTime requestTime;

  /// 当前请求结果。
  final String result;

  /// 弹窗展示的完整已脱敏诊断快照。
  final String completeInformation;
}

/// 进程内通讯日志环形存储。
///
/// 日志只用于当前运行周期的现场诊断，不写入业务数据库。所有消息在进入内存前
/// 都会经过脱敏和长度限制，避免口令、令牌、生物资料、设备唯一标识或超大二进制
/// 数据因为诊断功能被二次保存。
class CommunicationLogStore {
  /// 创建独立日志存储；生产代码通常使用 [instance]，测试可创建隔离实例。
  CommunicationLogStore({this.maximumEntries = 500, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    if (maximumEntries <= 0) {
      throw ArgumentError.value(maximumEntries, 'maximumEntries', '必须大于 0');
    }
  }

  /// 应用级通讯日志存储。
  static final CommunicationLogStore instance = CommunicationLogStore();

  /// 最多保留的日志条数。
  final int maximumEntries;
  final DateTime Function() _clock;
  final List<CommunicationLogEntry> _entries = <CommunicationLogEntry>[];
  final StreamController<List<CommunicationLogEntry>> _changesController =
      StreamController<List<CommunicationLogEntry>>.broadcast(sync: true);
  int _nextId = 0;

  /// 当前日志，按时间从新到旧排列。
  List<CommunicationLogEntry> get entries =>
      List<CommunicationLogEntry>.unmodifiable(_entries);

  /// 每次新增或更新日志后发布的完整只读快照。
  Stream<List<CommunicationLogEntry>> get changes => _changesController.stream;

  /// 记录一条通讯消息并返回其进程内标识。
  int record({
    required CommunicationTargetType targetType,
    required CommunicationDirection direction,
    required String channel,
    required String operation,
    required Object? messageBody,
    required String result,
    DateTime? requestTime,
  }) {
    final time = requestTime ?? _clock();
    final safeBody = _CommunicationLogSanitizer.sanitize(messageBody);
    final bodyText = _encodeSafely(safeBody, pretty: true);
    final safeResult = _CommunicationLogSanitizer.sanitizeText(result);
    _nextId += 1;
    final entry = _buildEntry(
      id: _nextId,
      targetType: targetType,
      direction: direction,
      channel: channel.trim(),
      operation: operation.trim(),
      messageBody: bodyText,
      requestTime: time,
      result: safeResult,
    );
    final insertionIndex = _entries.indexWhere(
      (current) => current.requestTime.isBefore(entry.requestTime),
    );
    if (insertionIndex < 0) {
      _entries.add(entry);
    } else {
      _entries.insert(insertionIndex, entry);
    }
    if (_entries.length > maximumEntries) {
      _entries.removeRange(maximumEntries, _entries.length);
    }
    _publish();
    return entry.id;
  }

  /// 尝试记录一条通讯消息；诊断功能自身异常时返回 null，不影响真实通讯。
  int? tryRecord({
    required CommunicationTargetType targetType,
    required CommunicationDirection direction,
    required String channel,
    required String operation,
    required Object? messageBody,
    required String result,
    DateTime? requestTime,
  }) {
    try {
      return record(
        targetType: targetType,
        direction: direction,
        channel: channel,
        operation: operation,
        messageBody: messageBody,
        result: result,
        requestTime: requestTime,
      );
    } catch (_) {
      return null;
    }
  }

  /// 更新一条已发送消息的请求结果。
  void updateResult(int id, String result) {
    final index = _entries.indexWhere((entry) => entry.id == id);
    if (index < 0) {
      return;
    }
    final current = _entries[index];
    _entries[index] = _buildEntry(
      id: current.id,
      targetType: current.targetType,
      direction: current.direction,
      channel: current.channel,
      operation: current.operation,
      messageBody: current.messageBody,
      requestTime: current.requestTime,
      result: _CommunicationLogSanitizer.sanitizeText(result),
    );
    _publish();
  }

  /// 尝试更新请求结果；日志已淘汰或诊断功能异常时静默忽略。
  void tryUpdateResult(int? id, String result) {
    if (id == null) {
      return;
    }
    try {
      updateResult(id, result);
    } catch (_) {
      // 通讯日志是旁路诊断能力，任何展示或监听异常都不能改变业务结果。
    }
  }

  /// 记录一次请求应答通讯，并把原异常原样抛回业务调用方。
  ///
  /// 上报日志会先以“处理中”出现；调用完成后更新发送结果，并额外记录软件收到的
  /// 下发结果。该包装只观察通讯，不改变原调用的返回值、异常或执行顺序。
  Future<T> traceExchange<T>({
    required CommunicationTargetType targetType,
    required String channel,
    required String operation,
    required Object? requestBody,
    required Future<T> Function() action,
    Object? Function(T value)? responseBody,
  }) async {
    DateTime? startedAt;
    try {
      startedAt = _clock();
    } catch (_) {
      // 自定义测试时钟或平台时间异常只会让本条日志缺失，不能阻止真实 action。
    }
    final requestId = tryRecord(
      targetType: targetType,
      direction: CommunicationDirection.outbound,
      channel: channel,
      operation: operation,
      messageBody: requestBody,
      result: '处理中',
      requestTime: startedAt,
    );

    late final T value;
    try {
      value = await action();
    } catch (error, stackTrace) {
      tryUpdateResult(requestId, '失败：${error.runtimeType}');
      Error.throwWithStackTrace(error, stackTrace);
    }

    tryUpdateResult(requestId, '成功');
    Object? safeResponseBody;
    try {
      safeResponseBody = responseBody == null
          ? _defaultResponseBody(value)
          : responseBody(value);
    } catch (_) {
      safeResponseBody = <String, Object?>{
        'responseType': value.runtimeType.toString(),
      };
    }
    tryRecord(
      targetType: targetType,
      direction: CommunicationDirection.inbound,
      channel: channel,
      operation: operation,
      messageBody: safeResponseBody,
      result: '成功',
    );
    return value;
  }

  /// 清空当前实例，供测试隔离使用。
  void clear() {
    _entries.clear();
    _publish();
  }

  /// 释放独立测试实例持有的流；应用级 [instance] 不应释放。
  Future<void> dispose() => _changesController.close();

  /// 用统一元数据构建消息体和详情弹窗共用的不可变记录。
  CommunicationLogEntry _buildEntry({
    required int id,
    required CommunicationTargetType targetType,
    required CommunicationDirection direction,
    required String channel,
    required String operation,
    required String messageBody,
    required DateTime requestTime,
    required String result,
  }) {
    final completeInformation = const JsonEncoder.withIndent('  ')
        .convert(<String, Object?>{
          'channel': channel,
          'operation': operation,
          'requestTime': requestTime.toIso8601String(),
          'result': result,
          'messageBody': _tryDecodeJson(messageBody),
        });
    return CommunicationLogEntry(
      id: id,
      targetType: targetType,
      direction: direction,
      channel: channel,
      operation: operation,
      messageBody: messageBody,
      requestTime: requestTime,
      result: result,
      completeInformation: completeInformation,
    );
  }

  /// 向当前监听者发布最新的只读快照。
  void _publish() {
    if (!_changesController.isClosed) {
      _changesController.add(entries);
    }
  }
}

/// 为没有显式响应格式化器的调用生成安全默认摘要。
Object? _defaultResponseBody(Object? value) {
  if (value == null) {
    return const <String, Object?>{'acknowledged': true};
  }
  return value;
}

/// 尝试恢复已编码的 JSON，失败时保留脱敏文本。
Object? _tryDecodeJson(String value) {
  try {
    return jsonDecode(value);
  } catch (_) {
    return value;
  }
}

/// 把已脱敏对象编码为受长度限制的 JSON 文本。
String _encodeSafely(Object? value, {required bool pretty}) {
  late final String encoded;
  try {
    encoded = pretty
        ? const JsonEncoder.withIndent('  ').convert(value)
        : jsonEncode(value);
  } catch (_) {
    encoded = value?.toString() ?? 'null';
  }
  return _truncate(encoded);
}

/// 限制单条诊断文本大小，避免异常负载无界占用内存。
String _truncate(String value) {
  const maximumCharacters = 32 * 1024;
  if (value.length <= maximumCharacters) {
    return value;
  }
  return '${value.substring(0, maximumCharacters)}\n<内容已截断>';
}

/// 通讯日志脱敏器，只返回可安全留在诊断内存中的副本。
abstract final class _CommunicationLogSanitizer {
  static const String _redacted = '<已脱敏>';
  static const String _redactedEndpoint = '<地址已脱敏>';
  static const int _maximumDepth = 10;
  static final RegExp _sensitiveKey = RegExp(
    r'(password|passwd|pwd|token|secret|signature|authorization|cookie|cypher|'
    r'appid|clientid|deviceid|cameraid|terminalid|shelfcode|imei|operationid|apkpath|path|logfile|'
    r'finger|fger|face|rfid|nfc|credential|certificate|document|idcard|'
    r'userid|username|account|accnt|uname|rname|uorg|realname|wifi(name)?|'
    r'唯一设备|设备id|序列号|身份证|证件|指纹|人脸)',
    caseSensitive: false,
  );
  static const Set<String> _sensitiveExactKeys = <String>{
    'id',
    'im',
    'dp',
    'cd',
    'rc',
  };

  /// 递归复制并脱敏任意 JSON 风格消息。
  static Object? sanitize(Object? value, [int depth = 0]) {
    if (depth >= _maximumDepth) {
      return '<嵌套层级已省略>';
    }
    if (value == null || value is num || value is bool) {
      return value;
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is Uri) {
      return _sanitizeUri(value);
    }
    if (value is String) {
      return _sanitizeStringValue(value, depth);
    }
    if (value is List<int>) {
      return '<${value.length} 字节二进制数据>';
    }
    if (value is Iterable<Object?>) {
      return <Object?>[for (final item in value) sanitize(item, depth + 1)];
    }
    if (value is Map) {
      final result = <String, Object?>{};
      for (final entry in value.entries) {
        final key = entry.key.toString();
        final normalized = key.toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9\u4e00-\u9fff]'),
          '',
        );
        if ((_sensitiveExactKeys.contains(normalized) ||
                _sensitiveKey.hasMatch(normalized)) &&
            !_isSafeCapabilityFlag(normalized, entry.value)) {
          result[key] = _redacted;
        } else if (normalized.contains('url') || normalized == 'uri') {
          result[key] = _sanitizePossibleUri(entry.value?.toString() ?? '');
        } else {
          result[key] = sanitize(entry.value, depth + 1);
        }
      }
      return result;
    }
    if (value is Enum) {
      return value.name;
    }
    return sanitizeText(value.toString());
  }

  /// 对错误文本和非结构化协议内容进行兜底脱敏。
  static String sanitizeText(String value) {
    var result = value;
    result = result.replaceAllMapped(
      RegExp(
        r'((?:password|passwd|pwd|token|secret|signature|authorization|'
        r'cypher|imei|clientId|deviceId|terminalId|operationId|apkPath|'
        r'filePath|logFile|downloadsLogFile|path)\s*'
        r'[:=]\s*)([^\s,;|}]+)',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}$_redacted',
    );
    result = result.replaceAllMapped(
      RegExp(r'\b(?:https?|rtsp)://[^\s|,}\]]+', caseSensitive: false),
      (match) => _sanitizePossibleUri(match.group(0)!),
    );
    return _truncate(result);
  }

  /// JSON 文本先按结构脱敏，其它字符串走非结构化文本兜底规则。
  static Object? _sanitizeStringValue(String value, int depth) {
    final trimmed = value.trim();
    if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
      try {
        return sanitize(jsonDecode(trimmed), depth + 1);
      } catch (_) {
        // 不是合法 JSON 时继续按普通文本处理。
      }
    }
    return sanitizeText(value);
  }

  /// 尝试解析地址并仅公开 origin；非地址文本继续走普通脱敏。
  static String _sanitizePossibleUri(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) {
      return sanitizeText(value);
    }
    return _sanitizeUri(uri);
  }

  /// 地址只保留 scheme、host 和显式 port，不公开认证、路径或参数。
  static String _sanitizeUri(Uri uri) {
    if (!uri.hasScheme || uri.host.isEmpty) {
      return _redactedEndpoint;
    }
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
    ).toString();
  }

  /// 硬件是否可用、是否连接等布尔诊断不包含生物模板或设备标识，可以保留。
  static bool _isSafeCapabilityFlag(String key, Object? value) {
    if (value is! bool) {
      return false;
    }
    return key.endsWith('available') ||
        key.endsWith('connected') ||
        key.endsWith('active') ||
        key.endsWith('enabled') ||
        key.endsWith('supported');
  }
}
