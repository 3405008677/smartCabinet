import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:smart_cabinet/src/app/localization/app_localizations.dart';
import 'package:smart_cabinet/src/app/routing/app_routes.dart';
import 'package:smart_cabinet/src/app/shell/app_shell.dart';
import 'package:smart_cabinet/src/app/theme/app_theme.dart';
import 'package:smart_cabinet/src/core/config/app_config.dart';
import 'package:smart_cabinet/src/features/identity_verification/data/repositories/operator_identity_repository_impl.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_account.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_identity_navigation.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_identity_profile.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/repositories/operator_identity_repository.dart';
import 'package:smart_cabinet/src/features/identity_verification/presentation/operator_login_coordinator.dart';
import 'package:smart_cabinet/src/features/identity_verification/presentation/widgets/face_verification_card.dart';
import 'package:smart_cabinet/src/features/identity_verification/presentation/widgets/sensor_verification_card.dart';
import 'package:smart_cabinet/src/features/identity_verification/presentation/widgets/verification_progress_footer.dart';
import 'package:smart_cabinet/src/features/identity_verification/presentation/widgets/verification_step_card.dart';
import 'package:smart_cabinet/src/features/task_center/presentation/pages/task_center_page.dart';

/// 普通操作员统一身份校验页。
///
/// 人脸、指纹与 NFC 三项身份因子必须全部通过；同步或异常恢复场景也通过
/// 路由参数指定必须完成的因子。未带账号进入时，首个因子同时用于识别账号。
class OperatorVerificationPage extends StatefulWidget {
  /// 创建普通操作员身份校验页。
  const OperatorVerificationPage({
    this.arguments = const OperatorVerificationArguments(),
    this.repository,
    this.appConfig = AppConfig.current,
    super.key,
  });

  /// 路由传入的账号和初始认证因子。
  final OperatorVerificationArguments arguments;

  /// 测试或应用装配时可替换的身份仓库。
  final OperatorIdentityRepository? repository;

  /// 当前身份流程使用的运行配置。
  final AppConfig appConfig;

  @override
  State<OperatorVerificationPage> createState() =>
      _OperatorVerificationPageState();
}

/// 普通操作员身份校验页状态。
class _OperatorVerificationPageState extends State<OperatorVerificationPage> {
  late final OperatorIdentityRepository _repository;
  OperatorAccount? _account;
  late final Set<IdentityFactor> _verifiedFactors;
  final Set<IdentityFactor> _busyFactors = <IdentityFactor>{};
  final Set<IdentityFactor> _failedRequiredFactors = <IdentityFactor>{};
  String? _statusMessage;
  bool _hasNavigated = false;
  bool _reportingAbnormal = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? operatorIdentityRepository;
    _account = widget.arguments.account;
    _verifiedFactors = <IdentityFactor>{
      ...widget.arguments.initialVerifiedFactors,
      ...?widget.arguments.account?.verifiedFactors,
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _goToTaskCenterIfReady();
    });
  }

  /// 当前流程指定的必选因子；为空时使用人脸、指纹与 NFC 三项全验策略。
  Set<IdentityFactor> get _requiredFactors {
    final factors = widget.arguments.requiredFactors;
    return <IdentityFactor>{...requiredOperatorIdentityFactors, ...?factors};
  }

  /// 当前流程完成所需的因子数量。
  int get _requiredFactorCount => _requiredFactors.length;

  /// 当前已经完成的必选因子数量。
  int get _completedRequiredFactorCount {
    final requiredFactors = _requiredFactors;
    return _verifiedFactors.where(requiredFactors.contains).length;
  }

  /// 当前认证结果是否满足本次流程策略。
  bool get _requirementsSatisfied {
    return _verifiedFactors.containsAll(_requiredFactors);
  }

  /// 使用一个身份因子识别账号并完成认证。
  Future<void> _verifyFactor(IdentityFactor factor) async {
    if (_hasNavigated ||
        _busyFactors.contains(factor) ||
        _verifiedFactors.contains(factor)) {
      return;
    }
    setState(() {
      _busyFactors.add(factor);
      _statusMessage = context.l10n.t(
        'operatorFactorVerifying',
        '正在识别身份，请稍候...',
      );
    });

    try {
      var account = _account;
      if (account == null) {
        account = await _repository.identifyAccount(factor: factor);
        if (!mounted) {
          return;
        }
        if (account == null) {
          setState(() {
            _busyFactors.remove(factor);
            _statusMessage = context.l10n.t(
              'operatorAccountNotRecognized',
              '未识别到账号，请重试或使用账号登录',
            );
          });
          return;
        }

        final profile = await _repository.loadProfile(account);
        if (!mounted) {
          return;
        }
        if (profile.status != OperatorIdentityProfileStatus.ready &&
            profile.status != OperatorIdentityProfileStatus.synced) {
          setState(() => _busyFactors.remove(factor));
          await continueOperatorAccountLogin(
            context,
            account: account,
            replaceCurrent: true,
            repository: _repository,
          );
          return;
        }
        setState(() => _account = account);
      }

      if (widget.appConfig.isTestMode) {
        setState(() {
          _busyFactors.remove(factor);
          _failedRequiredFactors.remove(factor);
          _verifiedFactors.add(factor);
          _statusMessage = context.l10n.t(
            'operatorFactorSimulated',
            '测试模式：身份模拟认证已完成',
          );
        });
        _goToTaskCenterIfReady();
        return;
      }

      final result = await _repository.verifyFactor(
        account: account,
        factor: factor,
      );
      if (!mounted) {
        return;
      }
      if (!result.success) {
        setState(() {
          _busyFactors.remove(factor);
          if (widget.arguments.abnormalRecovery &&
              _requiredFactors.contains(factor)) {
            _failedRequiredFactors.add(factor);
          }
          _statusMessage = result.message;
        });
        unawaited(_reportAbnormalAfterRequiredFactorsAttempted());
        return;
      }

      setState(() {
        _busyFactors.remove(factor);
        _failedRequiredFactors.remove(factor);
        _verifiedFactors.add(factor);
        _statusMessage = result.message;
      });
      unawaited(_reportAbnormalAfterRequiredFactorsAttempted());
      _goToTaskCenterIfReady();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busyFactors.remove(factor);
        _statusMessage = context.l10n.t(
          'operatorFactorVerificationFailed',
          '身份识别失败，请重试或改用其他方式',
        );
      });
    }
  }

  /// 异常恢复模式下，必选因子均已复核且仍有失败时才报备并进入重新录入。
  Future<void> _reportAbnormalAfterRequiredFactorsAttempted() async {
    final account = _account;
    final requiredFactors = _requiredFactors;
    final attemptedFactors = <IdentityFactor>{
      ..._verifiedFactors,
      ..._failedRequiredFactors,
    };
    if (!widget.arguments.abnormalRecovery ||
        account == null ||
        _reportingAbnormal ||
        _hasNavigated ||
        _requirementsSatisfied ||
        !attemptedFactors.containsAll(requiredFactors)) {
      return;
    }

    _reportingAbnormal = true;
    setState(() {
      _statusMessage = context.l10n.t(
        'operatorAbnormalReporting',
        '人脸与指纹复核后仍有异常，正在向平台报备...',
      );
    });
    try {
      final profile = await _repository.reportAbnormalProfile(account);
      if (!mounted) {
        return;
      }
      _hasNavigated = true;
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.identityEnrollment,
        arguments: IdentityEnrollmentArguments(
          account: account,
          factors: profile.enrollmentFactors,
          abnormalReported: true,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _reportingAbnormal = false;
        _statusMessage = context.l10n.t(
          'operatorAbnormalReportFailed',
          '异常报备失败，请重新验证后再试',
        );
      });
    }
  }

  /// 满足本次全部必选因子策略后携带认证账号进入任务中心。
  void _goToTaskCenterIfReady() {
    final account = _account;
    if (_hasNavigated || account == null || !_requirementsSatisfied) {
      return;
    }
    _hasNavigated = true;
    final verifiedAccount = account.copyWith(verifiedFactors: _verifiedFactors);
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.taskCenter,
      arguments: TaskCenterArguments(account: verifiedAccount),
    );
  }

  /// 打开普通账号登录，并用结果替换当前未识别账号的页面。
  Future<void> _useAccountLogin() async {
    await coordinateOperatorAccountLogin(
      context,
      replaceCurrent: true,
      repository: _repository,
      appConfig: widget.appConfig,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final account = _account;
    final hasExplicitRequiredFactors =
        widget.arguments.requiredFactors?.isNotEmpty == true;
    final abnormalRecovery = widget.arguments.abnormalRecovery;

    return TerminalShell(
      topBarLeading: _OperatorVerificationHeader(
        title: l10n.t('operatorVerificationTitle', '操作员身份校验'),
        onBack: () => Navigator.of(context).pop(),
        onAccountLogin: _useAccountLogin,
      ),
      topRightBadge: FlowStatusBadge(
        text: abnormalRecovery
            ? l10n.t('operatorAbnormalVerificationBadge', '异常复核 · 人脸与指纹')
            : hasExplicitRequiredFactors
            ? l10n.t('operatorRequiredVerificationBadge', '身份校验中 · 三项必选')
            : l10n.t('operatorVerificationBadge', '身份校验中 · 三项必选'),
      ),
      child: Column(
        children: [
          Expanded(
            child: CustomPaint(
              painter: const _OperatorVerificationDotGridPainter(),
              child: Padding(
                padding: identityVerificationContentPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      hasExplicitRequiredFactors
                          ? l10n.t(
                              'operatorRequiredVerificationHeading',
                              '请完成人脸、指纹与 NFC 认证',
                            )
                          : l10n.t(
                              'operatorVerificationHeading',
                              '请完成人脸、指纹与 NFC 三项身份认证',
                            ),
                      textAlign: TextAlign.center,
                      style: identityVerificationHeadingStyle,
                    ),
                    const SizedBox(height: 9),
                    Text(
                      account == null
                          ? l10n.t(
                              'operatorVerificationIdentifyHint',
                              '首个身份因子用于识别账号，其余两项用于完成本人确认',
                            )
                          : abnormalRecovery
                          ? l10n.t(
                              'operatorAbnormalVerificationHint',
                              '本机资料存在异常，请完成人脸、指纹与 NFC 复核；三项均尝试后若仍有异常将报备重录',
                            )
                          : hasExplicitRequiredFactors
                          ? l10n.t(
                              'operatorSyncedVerificationHint',
                              '服务端资料已同步，本次必须完成人脸、指纹与 NFC 三项认证',
                            )
                          : l10n
                                .t(
                                  'operatorVerificationAccountInfo',
                                  '当前账号：{name} · {organization}',
                                )
                                .replaceAll('{name}', account.name)
                                .replaceAll(
                                  '{organization}',
                                  account.organizationName,
                                ),
                      textAlign: TextAlign.center,
                      style: identityVerificationDescriptionStyle,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n
                          .t(
                            'operatorVerificationProgress',
                            '已完成 {count} / {total} 项认证',
                          )
                          .replaceAll(
                            '{count}',
                            '$_completedRequiredFactorCount',
                          )
                          .replaceAll('{total}', '$_requiredFactorCount'),
                      textAlign: TextAlign.center,
                      style: identityVerificationProgressStyle,
                    ),
                    if (_statusMessage != null) ...[
                      const SizedBox(height: 7),
                      Text(
                        _statusMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildFaceStep(l10n),
                          const SizedBox(width: 16),
                          _buildSensorStep(
                            l10n: l10n,
                            index: 2,
                            factor: IdentityFactor.fingerprint,
                            title: l10n.t('operatorFingerprintTitle', '指纹识别'),
                            icon: Icons.fingerprint_rounded,
                          ),
                          const SizedBox(width: 16),
                          _buildSensorStep(
                            l10n: l10n,
                            index: 3,
                            factor: IdentityFactor.nfc,
                            title: l10n.t('operatorNfcTitle', 'NFC识别'),
                            icon: Icons.contactless_rounded,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          VerificationProgressFooter(
            completedCount: _completedRequiredFactorCount,
            totalCount: _requiredFactorCount,
          ),
        ],
      ),
    );
  }

  /// 创建人脸认证步骤卡片。
  Widget _buildFaceStep(AppLocalizations l10n) {
    final verified = _verifiedFactors.contains(IdentityFactor.face);
    return VerificationStepCard(
      index: 1,
      title: _factorTitle(
        l10n,
        factor: IdentityFactor.face,
        title: l10n.t('operatorFaceTitle', '人脸识别'),
      ),
      icon: Icons.center_focus_strong_rounded,
      accentColor: AppTheme.primaryColor,
      verified: verified,
      width: identityVerificationCardWidth,
      height: identityVerificationCardHeight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
        child: FaceVerificationCard(
          verified: verified,
          allowFallbackWithoutCamera: widget.appConfig.isTestMode || kDebugMode,
          simulateVerification: widget.appConfig.isTestMode,
          compact: true,
          showHeader: false,
          onVerified: () => unawaited(_verifyFactor(IdentityFactor.face)),
        ),
      ),
    );
  }

  /// 创建指纹或 NFC 认证步骤卡片。
  Widget _buildSensorStep({
    required AppLocalizations l10n,
    required int index,
    required IdentityFactor factor,
    required String title,
    required IconData icon,
  }) {
    final verified = _verifiedFactors.contains(factor);
    final busy = _busyFactors.contains(factor);
    final effectiveTitle = _factorTitle(l10n, factor: factor, title: title);
    return VerificationStepCard(
      index: index,
      title: effectiveTitle,
      icon: icon,
      accentColor: AppTheme.primaryColor,
      verified: verified,
      width: identityVerificationCardWidth,
      height: identityVerificationCardHeight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
        child: SensorVerificationCard(
          title: effectiveTitle,
          subtitle: effectiveTitle,
          icon: icon,
          verified: verified,
          actionText: busy
              ? l10n.t('operatorFactorBusy', '识别中...')
              : l10n.t('operatorConfirmFactor', '确认识别'),
          verifiedText: l10n.t('operatorFactorDone', '身份识别已完成'),
          compact: true,
          showHeader: false,
          onConfirm: () => unawaited(_verifyFactor(factor)),
        ),
      ),
    );
  }

  /// 为受约束流程的身份因子追加“必选”或“可选”说明。
  String _factorTitle(
    AppLocalizations l10n, {
    required IdentityFactor factor,
    required String title,
  }) {
    final requiredFactors = _requiredFactors;
    final suffix = requiredFactors.contains(factor)
        ? l10n.t('operatorRequiredFactorSuffix', '必选')
        : l10n.t('operatorOptionalFactorSuffix', '可选');
    return '$title · $suffix';
  }
}

/// 普通操作员身份校验页顶部返回区。
class _OperatorVerificationHeader extends StatelessWidget {
  /// 创建身份校验页顶部返回区。
  const _OperatorVerificationHeader({
    required this.title,
    required this.onBack,
    required this.onAccountLogin,
  });

  final String title;

  final VoidCallback onBack;

  final VoidCallback onAccountLogin;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimaryColor,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 12),
        TextButton.icon(
          key: const ValueKey('operator_verification_account_fallback'),
          onPressed: onAccountLogin,
          icon: const Icon(Icons.account_circle_outlined, size: 18),
          label: Text(
            context.l10n.t('operatorVerificationUseAccount', '识别不到账号？使用账号登录'),
          ),
        ),
      ],
    );
  }
}

/// 普通操作员身份校验页点阵背景。
class _OperatorVerificationDotGridPainter extends CustomPainter {
  /// 创建身份校验页点阵背景。
  const _OperatorVerificationDotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppTheme.primaryColor.withValues(alpha: .08);
    for (double x = 14; x < size.width; x += 28) {
      for (double y = 14; y < size.height; y += 28) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
