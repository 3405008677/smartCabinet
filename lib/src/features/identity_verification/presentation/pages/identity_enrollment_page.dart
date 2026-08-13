import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:smart_cabinet/src/app/localization/app_localizations.dart';
import 'package:smart_cabinet/src/app/routing/app_routes.dart';
import 'package:smart_cabinet/src/app/shell/app_shell.dart';
import 'package:smart_cabinet/src/app/theme/app_theme.dart';
import 'package:smart_cabinet/src/features/identity_verification/data/repositories/operator_identity_repository_impl.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_account.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_identity_navigation.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/repositories/operator_identity_repository.dart';
import 'package:smart_cabinet/src/features/identity_verification/presentation/identity_result_localizer.dart';
import 'package:smart_cabinet/src/features/identity_verification/presentation/widgets/face_verification_card.dart';
import 'package:smart_cabinet/src/features/identity_verification/presentation/widgets/sensor_verification_card.dart';
import 'package:smart_cabinet/src/features/identity_verification/presentation/widgets/verification_progress_footer.dart';
import 'package:smart_cabinet/src/features/identity_verification/presentation/widgets/verification_step_card.dart';

/// 操作员人脸、指纹资料录入页。
///
/// 页面只展示账号缺失或异常的可录入因子。全部录入成功后等待 3 秒，或由操作员
/// 点击按钮，清空当前导航栈并返回首页重新登录。
class IdentityEnrollmentPage extends StatefulWidget {
  /// 创建身份资料录入页。
  const IdentityEnrollmentPage({
    required this.arguments,
    this.repository,
    super.key,
  });

  /// 账号及本次需要录入的身份因子。
  final IdentityEnrollmentArguments arguments;

  /// 测试或应用装配时可替换的身份仓库。
  final OperatorIdentityRepository? repository;

  @override
  State<IdentityEnrollmentPage> createState() => _IdentityEnrollmentPageState();
}

/// 身份资料录入页状态。
class _IdentityEnrollmentPageState extends State<IdentityEnrollmentPage> {
  late final OperatorIdentityRepository _repository;
  late final Set<IdentityFactor> _requestedFactors;
  final Set<IdentityFactor> _completedFactors = <IdentityFactor>{};

  /// 正在录入的因子集合；按因子防重入，允许人脸与指纹维护各自的按钮状态。
  final Set<IdentityFactor> _busyFactors = <IdentityFactor>{};
  _EnrollmentPageStatus _status = _EnrollmentPageStatus.inProgress;
  String? _resultMessage;
  Timer? _returnTimer;

  /// 自动倒计时与手动按钮共用的一次性返回闩锁。
  bool _hasReturnedHome = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? operatorIdentityRepository;
    _requestedFactors = widget.arguments.factors
        .where((factor) => factor != IdentityFactor.nfc)
        .toSet();
    if (_requestedFactors.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _markAllSucceeded());
    }
  }

  @override
  void dispose() {
    _returnTimer?.cancel();
    super.dispose();
  }

  /// 录入或重录指定的人脸、指纹因子。
  ///
  /// 同一因子在请求完成前不会重复提交；只有全部请求因子成功后才启动返回首页计时。
  Future<void> _enrollFactor(IdentityFactor factor) async {
    if (_status == _EnrollmentPageStatus.success ||
        _busyFactors.contains(factor) ||
        _completedFactors.contains(factor)) {
      return;
    }
    setState(() {
      _busyFactors.add(factor);
      _status = _EnrollmentPageStatus.inProgress;
      _resultMessage = context.l10n.t(
        'operatorEnrollmentInProgress',
        '正在采集身份资料，请保持姿势稳定...',
      );
    });

    try {
      final result = await _repository.enrollFactor(
        account: widget.arguments.account,
        factor: factor,
      );
      if (!mounted) {
        return;
      }
      if (!result.success) {
        setState(() {
          _busyFactors.remove(factor);
          _status = _EnrollmentPageStatus.failure;
          _resultMessage = localizeIdentityEnrollmentResult(
            context.l10n,
            factor: factor,
            result: result,
          );
        });
        return;
      }

      setState(() {
        _busyFactors.remove(factor);
        _completedFactors.add(factor);
        _resultMessage = localizeIdentityEnrollmentResult(
          context.l10n,
          factor: factor,
          result: result,
        );
      });
      if (_completedFactors.containsAll(_requestedFactors)) {
        _markAllSucceeded();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busyFactors.remove(factor);
        _status = _EnrollmentPageStatus.failure;
        _resultMessage = context.l10n.t(
          'operatorEnrollmentFailed',
          '身份资料录入失败，请检查设备后重试',
        );
      });
    }
  }

  /// 标记本次所有录入成功，并启动 3 秒返回首页倒计时。
  void _markAllSucceeded() {
    if (!mounted || _status == _EnrollmentPageStatus.success) {
      return;
    }
    setState(() {
      _status = _EnrollmentPageStatus.success;
      _resultMessage = context.l10n.t(
        'operatorEnrollmentSucceeded',
        '身份资料录入成功，3 秒后返回首页重新登录',
      );
    });
    _returnTimer?.cancel();
    _returnTimer = Timer(const Duration(seconds: 3), _returnHome);
  }

  /// 清空身份流程导航栈并返回首页。
  void _returnHome() {
    if (!mounted || _hasReturnedHome) {
      return;
    }
    _hasReturnedHome = true;
    _returnTimer?.cancel();
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final account = widget.arguments.account;

    return PopScope(
      canPop: false,
      child: TerminalShell(
        topBarLeading: TextButton.icon(
          onPressed: _returnHome,
          icon: const Icon(Icons.close_rounded, size: 18),
          label: Text(l10n.t('operatorEnrollmentCancel', '结束并返回首页')),
        ),
        topRightBadge: FlowStatusBadge(
          text: l10n.t('operatorEnrollmentBadge', '身份资料录入'),
        ),
        child: Column(
          children: [
            Expanded(
              child: CustomPaint(
                painter: const _EnrollmentDotGridPainter(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 22, 28, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.t('operatorEnrollmentHeading', '请录入缺失的身份资料'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.textPrimaryColor,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n
                            .t(
                              'operatorEnrollmentAccountInfo',
                              '账号：{name} · {organization}',
                            )
                            .replaceAll('{name}', account.name)
                            .replaceAll(
                              '{organization}',
                              account.organizationName,
                            ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (widget.arguments.abnormalReported) ...[
                        const SizedBox(height: 10),
                        _EnrollmentNotice(
                          icon: Icons.cloud_done_outlined,
                          color: const Color(0xFFE68A00),
                          text: l10n.t(
                            'operatorEnrollmentReportedNotice',
                            '本机资料异常已报备，本次将重新录入异常项目',
                          ),
                        ),
                      ],
                      if (_resultMessage != null) ...[
                        const SizedBox(height: 10),
                        _EnrollmentNotice(
                          key: const ValueKey('identity_enrollment_result'),
                          icon: switch (_status) {
                            _EnrollmentPageStatus.inProgress =>
                              Icons.hourglass_top_rounded,
                            _EnrollmentPageStatus.success =>
                              Icons.check_circle_outline_rounded,
                            _EnrollmentPageStatus.failure =>
                              Icons.error_outline_rounded,
                          },
                          color: switch (_status) {
                            _EnrollmentPageStatus.inProgress =>
                              AppTheme.primaryColor,
                            _EnrollmentPageStatus.success => const Color(
                              0xFF22A857,
                            ),
                            _EnrollmentPageStatus.failure => const Color(
                              0xFFE05252,
                            ),
                          },
                          text: _resultMessage!,
                        ),
                      ],
                      const SizedBox(height: 18),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: _buildEnrollmentCards(l10n),
                        ),
                      ),
                      if (_status == _EnrollmentPageStatus.success) ...[
                        const SizedBox(height: 14),
                        Center(
                          child: FilledButton.icon(
                            key: const ValueKey(
                              'identity_enrollment_return_home',
                            ),
                            onPressed: _returnHome,
                            icon: const Icon(Icons.home_outlined),
                            label: Text(
                              l10n.t('operatorEnrollmentReturnHome', '立即返回首页'),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            VerificationProgressFooter(
              completedCount: _completedFactors.length,
              totalCount: _requestedFactors.length,
            ),
          ],
        ),
      ),
    );
  }

  /// 根据缺失或异常项目创建录入卡片列表。
  List<Widget> _buildEnrollmentCards(AppLocalizations l10n) {
    final cards = <Widget>[];
    if (_requestedFactors.contains(IdentityFactor.face)) {
      cards.add(_buildFaceEnrollment(l10n));
    }
    if (_requestedFactors.contains(IdentityFactor.fingerprint)) {
      if (cards.isNotEmpty) {
        cards.add(const SizedBox(width: 24));
      }
      cards.add(_buildFingerprintEnrollment(l10n));
    }
    if (cards.isEmpty) {
      cards.add(
        Center(
          child: Text(
            l10n.t('operatorEnrollmentNothingMissing', '当前没有需要录入的身份资料'),
            style: const TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }
    return cards;
  }

  /// 创建人脸录入卡片。
  Widget _buildFaceEnrollment(AppLocalizations l10n) {
    final verified = _completedFactors.contains(IdentityFactor.face);
    return VerificationStepCard(
      index: 1,
      title: l10n.t('operatorEnrollFaceTitle', '录入人脸'),
      icon: Icons.center_focus_strong_rounded,
      accentColor: AppTheme.primaryColor,
      verified: verified,
      width: 360,
      height: 500,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        child: FaceVerificationCard(
          verified: verified,
          allowFallbackWithoutCamera: kDebugMode,
          compact: true,
          showHeader: false,
          onVerified: () => unawaited(_enrollFactor(IdentityFactor.face)),
        ),
      ),
    );
  }

  /// 创建指纹录入卡片。
  Widget _buildFingerprintEnrollment(AppLocalizations l10n) {
    final factor = IdentityFactor.fingerprint;
    final verified = _completedFactors.contains(factor);
    final busy = _busyFactors.contains(factor);
    return VerificationStepCard(
      index: _requestedFactors.contains(IdentityFactor.face) ? 2 : 1,
      title: l10n.t('operatorEnrollFingerprintTitle', '录入指纹'),
      icon: Icons.fingerprint_rounded,
      accentColor: AppTheme.primaryColor,
      verified: verified,
      width: 360,
      height: 500,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        child: SensorVerificationCard(
          title: l10n.t('operatorEnrollFingerprintTitle', '录入指纹'),
          subtitle: l10n.t('operatorEnrollFingerprintTitle', '录入指纹'),
          icon: Icons.fingerprint_rounded,
          verified: verified,
          actionText: busy
              ? l10n.t('operatorEnrollmentBusy', '录入中...')
              : l10n.t('operatorEnrollmentStart', '开始录入'),
          verifiedText: l10n.t('operatorEnrollmentFactorSucceeded', '身份资料录入成功'),
          compact: true,
          showHeader: false,
          onConfirm: () => unawaited(_enrollFactor(factor)),
        ),
      ),
    );
  }
}

/// 录入页当前结果状态。
enum _EnrollmentPageStatus { inProgress, success, failure }

/// 录入页顶部的过程或结果提示条。
class _EnrollmentNotice extends StatelessWidget {
  /// 创建录入过程提示条。
  const _EnrollmentNotice({
    required this.icon,
    required this.color,
    required this.text,
    super.key,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 760),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: .24)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 身份资料录入页点阵背景。
class _EnrollmentDotGridPainter extends CustomPainter {
  /// 创建录入页点阵背景。
  const _EnrollmentDotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryColor.withValues(alpha: .06)
      ..style = PaintingStyle.fill;
    for (double x = 18; x < size.width; x += 28) {
      for (double y = 18; y < size.height; y += 28) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
