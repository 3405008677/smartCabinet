import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// AFRR APP `logon` 请求的签名和 JSON 载荷生成器。
final class AfrrAppLogonProtocol {
  const AfrrAppLogonProtocol._();

  /// APP 建立 TCP 连接后必须发送的第一条功能码。
  static const String function = 'logon';

  /// 协议要求的随机码长度。
  static const int randomCodeLength = 30;

  static const String _randomAlphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';

  /// 生成 30 位小写字母和数字随机码。
  static String generateRandomCode([Random? random]) {
    final source = random ?? Random.secure();
    return List<String>.generate(
      randomCodeLength,
      (_) => _randomAlphabet[source.nextInt(_randomAlphabet.length)],
      growable: false,
    ).join();
  }

  /// 使用 appSecret 对协议规定的签名原文执行 HMAC-SHA256。
  ///
  /// 文档中的 `ts={ts}rc={rc}` 中间没有 `&`，这里严格按原文拼接。
  static String createSignature({
    required String appId,
    required String appSecret,
    required String imei,
    required int timestampMilliseconds,
    required String randomCode,
  }) {
    _validateCredentials(
      appId: appId,
      appSecret: appSecret,
      imei: imei,
      randomCode: randomCode,
    );
    final content =
        'appid=$appId&imei=$imei&ts=$timestampMilliseconds'
        'rc=$randomCode';
    return Hmac(
      sha256,
      utf8.encode(appSecret),
    ).convert(utf8.encode(content)).toString();
  }

  /// 生成放入 AFRR `0xA0` 数据项的完整 JSON 对象。
  static Map<String, Object?> createRequest({
    required String appId,
    required String appSecret,
    required String imei,
    required int timestampMilliseconds,
    required String randomCode,
  }) {
    return <String, Object?>{
      'func': function,
      'data': <String, Object?>{
        'ts': timestampMilliseconds,
        'rc': randomCode,
        'data': createSignature(
          appId: appId,
          appSecret: appSecret,
          imei: imei,
          timestampMilliseconds: timestampMilliseconds,
          randomCode: randomCode,
        ),
      },
    };
  }

  static void _validateCredentials({
    required String appId,
    required String appSecret,
    required String imei,
    required String randomCode,
  }) {
    if (appId.isEmpty || appSecret.isEmpty) {
      throw ArgumentError('AFRR APP 登录的 appId 和 appSecret 不能为空');
    }
    if (!RegExp(r'^\d{15}$').hasMatch(imei)) {
      throw ArgumentError.value(imei, 'imei', 'AFRR APP 登录 IMEI 必须是 15 位数字');
    }
    if (!RegExp(r'^[a-z0-9]{30}$').hasMatch(randomCode)) {
      throw ArgumentError.value(
        randomCode,
        'randomCode',
        'AFRR APP 登录随机码必须是 30 位小写字母或数字',
      );
    }
  }
}
