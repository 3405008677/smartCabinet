import 'package:smart_cabinet/src/app/localization/app_localizations.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/repositories/operator_identity_repository.dart';

/// 将 AFRR 连接、配置和响应解析错误转换为当前界面语言。
///
/// 服务端返回的业务原因保持原样，仅替换应用自身生成的固定错误。
String localizeOperatorLoginError(
  AppLocalizations l10n,
  OperatorLoginException error,
) {
  return switch (error.code) {
    'invalid_login_response' || 'invalid_protocol_result' => l10n.t(
      'operatorLoginInvalidResponse',
      'AFRR 登录回复无效，请联系平台管理员',
    ),
    'invalid_server_config' || 'invalid_device_config' => l10n.t(
      'operatorLoginInvalidServerConfig',
      'AFRR 登录参数无效，请联系管理员检查终端配置',
    ),
    'timeout' => l10n.t('operatorLoginTimeout', '连接 AFRR 登录服务超时，请检查柜机网络后重试'),
    'network_unavailable' => l10n.t(
      'operatorLoginNetworkUnavailable',
      '无法连接 AFRR 登录服务，请检查柜机网络和服务状态',
    ),
    _ => error.message,
  };
}
