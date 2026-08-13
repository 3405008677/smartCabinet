import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_account.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_login_request.dart';

/// AFRR 登录成功后保存在当前应用进程中的操作员会话。
///
/// 当前会话保留请求流水号、服务端时间和生物特征文件 ID，供后续 AFRR 协议
/// 请求关联，并在安全退出时统一清除。
final class OperatorLoginSession {
  /// 创建操作员登录会话。
  const OperatorLoginSession({
    required this.account,
    required this.loginMethod,
    required this.protocolSerialNumber,
    this.serverTime,
    this.faceFileId,
    this.fingerprintFileId,
  });

  /// 本次会话对应的操作员账号。
  final OperatorAccount account;

  /// 建立当前会话时使用的账号、人脸或指纹登录方式。
  final OperatorLoginMethod loginMethod;

  /// 本次 A170 登录请求使用的 16 位流水号。
  final int protocolSerialNumber;

  /// 服务端回复的秒级时间戳；协议未返回时为 null。
  final int? serverTime;

  /// 服务端返回的人脸文件 ID；没有人脸资料时为 null。
  final String? faceFileId;

  /// 服务端返回的指纹文件 ID；没有指纹资料时为 null。
  final String? fingerprintFileId;
}
