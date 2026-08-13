/// AFRR APP `heartbeat` 请求的 JSON 载荷生成器。
final class AfrrAppHeartbeatProtocol {
  const AfrrAppHeartbeatProtocol._();

  /// 智能 APP 向服务端发送心跳使用的功能码。
  static const String function = 'heartbeat';

  /// 协议约定的 APP 心跳间隔。
  static const Duration interval = Duration(minutes: 1);

  /// 生成放入 AFRR `0xA0` 数据项的完整 JSON 对象。
  ///
  /// [terminalFramePayload] 是终端 A101/A102 原始报文去掉头尾各两个字节后的
  /// 内容。尚未收到终端心跳时必须传 null，避免用空数组伪造终端在线状态。
  static Map<String, Object?> createRequest({
    required DateTime timestamp,
    List<int>? terminalFramePayload,
  }) {
    final payload = terminalFramePayload == null
        ? null
        : List<int>.unmodifiable(
            terminalFramePayload.map((byte) {
              if (byte < 0 || byte > 0xFF) {
                throw ArgumentError.value(
                  terminalFramePayload,
                  'terminalFramePayload',
                  'AFRR 心跳透传内容必须是字节数组',
                );
              }
              return byte;
            }),
          );
    return <String, Object?>{
      'func': function,
      'data': <String, Object?>{
        'time': formatTimestamp(timestamp),
        'data': payload,
      },
    };
  }

  /// 按协议输出 `yyyyMMddHHmmssZZmm` 形式的 18 位本地时间。
  ///
  /// `ZZ` 的高半字节表示时区方向，0 为东时区、1 为西时区，低半字节表示
  /// 小时；最后两位表示时区分钟，与外层 AFRR BCD 时间项保持同一语义。
  static String formatTimestamp(DateTime timestamp) {
    final offsetMinutes = timestamp.timeZoneOffset.inMinutes;
    final absoluteMinutes = offsetMinutes.abs();
    final offsetHours = absoluteMinutes ~/ 60;
    if (offsetHours > 15) {
      throw ArgumentError.value(
        timestamp.timeZoneOffset,
        'timestamp',
        'AFRR 心跳时区小时超过 15',
      );
    }
    final timezoneByte = (offsetMinutes < 0 ? 0x10 : 0) | offsetHours;
    final timezoneMinutes = absoluteMinutes % 60;
    return '${timestamp.year.toString().padLeft(4, '0')}'
        '${timestamp.month.toString().padLeft(2, '0')}'
        '${timestamp.day.toString().padLeft(2, '0')}'
        '${timestamp.hour.toString().padLeft(2, '0')}'
        '${timestamp.minute.toString().padLeft(2, '0')}'
        '${timestamp.second.toString().padLeft(2, '0')}'
        '${timezoneByte.toRadixString(16).padLeft(2, '0').toUpperCase()}'
        '${timezoneMinutes.toString().padLeft(2, '0')}';
  }
}
