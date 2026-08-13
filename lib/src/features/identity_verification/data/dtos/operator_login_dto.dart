import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_account.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_login_request.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_login_session.dart';

/// AFRR 智能 APP 登录命令 DTO。
///
/// 账号密码转换为 40 位大写 SHA-1；人脸和指纹只传文件 ID，不把原始生物特征
/// 数据放入登录命令。
final class OperatorProtocolLoginRequestDto {
  /// 从统一领域请求创建 AFRR `userLogin` JSON。
  factory OperatorProtocolLoginRequestDto.fromRequest(
    OperatorLoginRequest request,
  ) {
    if (!request.hasProtocolIdentifier) {
      throw const FormatException('人脸或指纹登录缺少文件 ID');
    }
    final cypher = switch (request.method) {
      OperatorLoginMethod.account => _sha1UpperHex(request.secret!),
      OperatorLoginMethod.face || OperatorLoginMethod.fingerprint => '',
    };
    return OperatorProtocolLoginRequestDto._(
      method: request.method,
      account: request.identifier,
      cypher: cypher,
    );
  }

  const OperatorProtocolLoginRequestDto._({
    required this.method,
    required this.account,
    required this.cypher,
  });

  /// AFRR `logway` 对应的登录方式。
  final OperatorLoginMethod method;

  /// 用户账号，或人脸/指纹文件 ID。
  final String account;

  /// 账号密码摘要；生物特征登录固定为空字符串。
  final String cypher;

  /// 转换为 A170 消息中 `0xA0` 数据项承载的 JSON。
  Map<String, Object> toJson() {
    return <String, Object>{
      'func': 'userLogin',
      'data': <String, Object>{
        'logway': method.protocolValue,
        'accnt': account,
        'cypher': cypher,
      },
    };
  }
}

/// AFRR `userLogin` 成功回复映射后的操作员资料。
final class OperatorLoginResponseDto {
  /// 从 B170 回复的 `data` 对象创建操作员资料。
  factory OperatorLoginResponseDto.fromProtocolData({
    required Map<String, Object?> data,
    required OperatorLoginRequest request,
    required int protocolSerialNumber,
  }) {
    final userId = _firstText(data, const <String>['uid', 'userId']);
    final organizationName = _firstText(data, const <String>[
      'uorg',
      'organizationName',
    ]);
    if (userId.isEmpty || organizationName.isEmpty) {
      throw const FormatException('AFRR 登录回复缺少 uid 或 uorg');
    }

    final username = _firstText(
      data,
      const <String>['accnt', 'account', 'userAccount'],
      fallback: request.method == OperatorLoginMethod.account
          ? request.identifier
          : userId,
    );
    final organizationId = _firstText(
      data,
      const <String>['uorgId', 'organizationId', 'orgId'],
      // 当前协议只定义机构名称。后端未扩展机构 ID 时，以完整机构名称作为隔离键，
      // 避免把不同机构合并到空 ID；后端增加 ID 后会优先使用扩展字段。
      fallback: organizationName,
    );
    return OperatorLoginResponseDto(
      account: OperatorAccount(
        id: userId,
        username: username,
        name: _firstText(data, const <String>[
          'uname',
          'userName',
        ], fallback: username),
        organizationId: organizationId,
        organizationName: organizationName,
        position: _firstText(data, const <String>['rname', 'roleName']),
      ),
      protocolSerialNumber: protocolSerialNumber,
      loginMethod: request.method,
      faceFileId: _positiveId(_read(data, 'faceId')),
      fingerprintFileId: _positiveId(_read(data, 'fgerId')),
      serverTime: _intValue(_read(data, 'time')),
    );
  }

  /// 创建已映射的 AFRR 登录结果。
  const OperatorLoginResponseDto({
    required this.account,
    required this.protocolSerialNumber,
    required this.loginMethod,
    this.faceFileId,
    this.fingerprintFileId,
    this.serverTime,
  });

  /// 操作员领域账号。
  final OperatorAccount account;

  /// A170 请求流水号。
  final int protocolSerialNumber;

  /// 本次使用的登录方式。
  final OperatorLoginMethod loginMethod;

  /// 服务端返回的人脸文件 ID。
  final String? faceFileId;

  /// 服务端返回的指纹文件 ID。
  final String? fingerprintFileId;

  /// 服务端返回的秒级时间戳。
  final int? serverTime;

  /// 转换为身份仓库保存的当前 AFRR 会话。
  OperatorLoginSession toSession() {
    return OperatorLoginSession(
      account: account,
      loginMethod: loginMethod,
      protocolSerialNumber: protocolSerialNumber,
      serverTime: serverTime,
      faceFileId: faceFileId,
      fingerprintFileId: fingerprintFileId,
    );
  }
}

/// 不区分字段首字母大小写读取协议 JSON。
Object? _read(Map<String, Object?> source, String key) {
  final direct = source[key];
  if (direct != null || source.containsKey(key)) {
    return direct;
  }
  final normalizedKey = key.toLowerCase();
  for (final entry in source.entries) {
    if (entry.key.toLowerCase() == normalizedKey) {
      return entry.value;
    }
  }
  return null;
}

/// 从候选字段读取第一个非空文本。
String _firstText(
  Map<String, Object?> source,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = _stringValue(_read(source, key));
    if (value.isNotEmpty) {
      return value;
    }
  }
  return fallback;
}

String _stringValue(Object? value) => value?.toString().trim() ?? '';

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(_stringValue(value));
}

String? _positiveId(Object? value) {
  final id = _intValue(value);
  return id != null && id > 0 ? '$id' : null;
}

/// 把账号密码转换为 AFRR 登录 JSON 要求的 40 位大写 SHA-1。
String _sha1UpperHex(String password) {
  return sha1.convert(utf8.encode(password.trim())).toString().toUpperCase();
}
