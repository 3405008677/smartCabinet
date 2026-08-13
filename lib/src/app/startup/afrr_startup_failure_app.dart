import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:smart_cabinet/src/app/bootstrap/bootstrap.dart';
import 'package:smart_cabinet/src/app/localization/app_localizations.dart';
import 'package:smart_cabinet/src/app/startup/startup_task.dart';

/// AFRR APP 登录失败时显示的不可关闭阻断弹窗。
///
/// 正式业务应用尚未创建，因此用户无法通过返回键、点击遮罩或路由操作绕过提示。
class AfrrStartupFailureApp extends StatefulWidget {
  /// 创建监管服务登录失败页。
  const AfrrStartupFailureApp({required this.result, super.key});

  /// 包含具体连接或登录错误的启动结果。
  final StartupResult result;

  @override
  State<AfrrStartupFailureApp> createState() => _AfrrStartupFailureAppState();
}

class _AfrrStartupFailureAppState extends State<AfrrStartupFailureApp> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) {
      return;
    }
    setState(() => _retrying = true);
    try {
      await retryBootstrap();
    } finally {
      if (mounted) {
        setState(() => _retrying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = appLocaleController.language;
    final localizations = AppLocalizations(language);
    final error = widget.result.firstRequiredFailure?.error.toString().trim();
    final detail = error == null || error.isEmpty
        ? _unknownServiceError(language)
        : error;

    return AppLocalizationsScope(
      localizations: localizations,
      child: MaterialApp(
        title: localizations.t('startupFailureTitle', '系统启动失败'),
        debugShowCheckedModeBanner: false,
        locale: appLocaleController.locale,
        supportedLocales: AppLanguage.values
            .map((item) => item.locale)
            .toList(growable: false),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: PopScope(
          canPop: false,
          child: Scaffold(
            backgroundColor: const Color(0xFF111827),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: AlertDialog(
                  key: const ValueKey('afrr_startup_blocking_dialog'),
                  icon: const Icon(
                    Icons.cloud_off_rounded,
                    size: 52,
                    color: Color(0xFFB91C1C),
                  ),
                  title: Text(
                    localizations.t('startupFailureTitle', '系统启动失败'),
                    textAlign: TextAlign.center,
                  ),
                  content: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _blockedDescription(language),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 17, height: 1.5),
                        ),
                        const SizedBox(height: 20),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  detail,
                                  key: const ValueKey(
                                    'afrr_startup_error_message',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF7F1D1D),
                                    fontSize: 15,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _contactAdministrator(language),
                                  key: const ValueKey(
                                    'afrr_startup_contact_administrator',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF991B1B),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actionsAlignment: MainAxisAlignment.center,
                  actions: [
                    FilledButton.icon(
                      onPressed: _retrying ? null : _retry,
                      icon: _retrying
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded),
                      label: Text(localizations.t('startupRetry', '重新启动检测')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _blockedDescription(AppLanguage language) => switch (language) {
  AppLanguage.simplifiedChinese => '监管服务连接或登录失败，系统已锁定，当前无法进行任何业务操作。',
  AppLanguage.traditionalChinese => '監管服務連線或登入失敗，系統已鎖定，目前無法進行任何業務操作。',
  AppLanguage.english =>
    'The regulatory service connection or login failed. The system is locked and no business operation is available.',
  AppLanguage.japanese => '監督サービスへの接続またはログインに失敗しました。システムはロックされ、業務操作は利用できません。',
};

String _contactAdministrator(AppLanguage language) => switch (language) {
  AppLanguage.simplifiedChinese => '请联系管理员',
  AppLanguage.traditionalChinese => '請聯絡管理員',
  AppLanguage.english => 'Contact an administrator',
  AppLanguage.japanese => '管理者に連絡してください',
};

String _unknownServiceError(AppLanguage language) => switch (language) {
  AppLanguage.simplifiedChinese => '监管服务连接或登录失败。',
  AppLanguage.traditionalChinese => '監管服務連線或登入失敗。',
  AppLanguage.english => 'The regulatory service connection or login failed.',
  AppLanguage.japanese => '監督サービスへの接続またはログインに失敗しました。',
};
