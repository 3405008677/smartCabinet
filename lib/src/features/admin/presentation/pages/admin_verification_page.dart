import 'package:flutter/material.dart';

import 'package:smart_cabinet/src/app/theme/app_theme.dart';

import 'package:smart_cabinet/src/app/localization/app_localizations.dart';

import 'package:smart_cabinet/src/app/routing/app_routes.dart';
import 'package:smart_cabinet/src/app/shell/app_shell.dart';
import 'package:smart_cabinet/src/core/config/app_config.dart';
import 'package:smart_cabinet/src/features/identity_verification/presentation/widgets/face_verification_card.dart';
import 'package:smart_cabinet/src/features/identity_verification/presentation/widgets/verification_progress_footer.dart';
import 'package:smart_cabinet/src/features/identity_verification/presentation/widgets/sensor_verification_card.dart';
import 'package:smart_cabinet/src/features/identity_verification/presentation/widgets/verification_step_card.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/verification_state.dart';

/// 管理员身份校验页。
class AdminVerificationPage extends StatefulWidget {
  /// 创建管理员身份校验页。
  const AdminVerificationPage({
    this.postVerificationRoute = AppRoutes.adminConsole,
    super.key,
  });

  /// 完成三因子认证后进入的受限管理员页面。
  final String postVerificationRoute;

  @override
  State<AdminVerificationPage> createState() => _AdminVerificationPageState();
}

class _AdminVerificationPageState extends State<AdminVerificationPage> {
  /// 当前验证状态。
  VerificationState _verification = const VerificationState();

  /// 已完成认证项数量。
  int get _verifiedCount => _verification.identityVerifiedCount;

  /// 是否完成所有管理员身份认证。
  bool get _allVerified => _verification.allIdentityVerified;

  /// 是否已经触发下一步跳转。
  bool _hasNavigated = false;

  /// 三项认证完成后进入路由层白名单允许的管理员页面。
  void _goNextIfAllVerified() {
    if (_hasNavigated || !_allVerified) {
      return;
    }
    _hasNavigated = true;
    final destination =
        widget.postVerificationRoute == AppRoutes.adminTerminalUpgrade
        ? AppRoutes.adminTerminalUpgrade
        : AppRoutes.adminConsole;
    Navigator.of(context).pushReplacementNamed(destination);
  }

  /// 更新验证状态并在全部完成后进入下一步。
  void _updateVerification(VerificationState verification) {
    setState(() => _verification = verification);
    _goNextIfAllVerified();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return TerminalShell(
      topBarLeading: _AdminHeader(
        title: l10n.t('adminVerificationTitle', '管理员身份校验'),
        onBack: () => Navigator.of(context).pop(),
      ),
      topRightBadge: FlowStatusBadge(
        text: l10n.t('adminVerificationBadge', '身份校验中 · 管理员'),
      ),
      child: Column(
        children: [
          Expanded(
            child: CustomPaint(
              painter: const _AdminDotGridPainter(),
              child: Padding(
                padding: identityVerificationContentPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.t('adminVerificationHeading', '请完成管理员安全身份认证'),
                      textAlign: TextAlign.center,
                      style: identityVerificationHeadingStyle,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.t(
                        'adminVerificationDescription',
                        '登录权限已通过，请继续完成人脸、指纹与 NFC 三项校验',
                      ),
                      textAlign: TextAlign.center,
                      style: identityVerificationDescriptionStyle,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n
                          .t('adminVerificationProgress', '已完成 {count} / 3 项认证')
                          .replaceAll('{count}', '$_verifiedCount'),
                      textAlign: TextAlign.center,
                      style: identityVerificationProgressStyle,
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          VerificationStepCard(
                            index: 1,
                            title: l10n.t('identityFaceTitle', '人脸识别'),
                            icon: Icons.center_focus_strong_rounded,
                            accentColor: AppTheme.primaryColor,
                            verified: _verification.face,
                            width: identityVerificationCardWidth,
                            height: identityVerificationCardHeight,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                              child: FaceVerificationCard(
                                verified: _verification.face,
                                accentColor: AppTheme.primaryColor,
                                allowFallbackWithoutCamera: true,
                                simulateVerification:
                                    AppConfig.current.isTestMode,
                                compact: true,
                                showHeader: false,
                                onVerified: () => _updateVerification(
                                  _verification.copyWith(face: true),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          VerificationStepCard(
                            index: 2,
                            title: l10n.t('identityFingerprintTitle', '指纹识别'),
                            icon: Icons.fingerprint_rounded,
                            accentColor: AppTheme.primaryColor,
                            verified: _verification.fingerprint,
                            width: identityVerificationCardWidth,
                            height: identityVerificationCardHeight,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                              child: SensorVerificationCard(
                                title: l10n.t(
                                  'identityFingerprintTitle',
                                  '指纹识别',
                                ),
                                subtitle: l10n.t(
                                  'identityFingerprintTitle',
                                  '指纹识别',
                                ),
                                icon: Icons.fingerprint_rounded,
                                verified: _verification.fingerprint,
                                actionText: l10n.t(
                                  'identityConfirmFingerprint',
                                  '确认指纹识别',
                                ),
                                verifiedText: l10n.t(
                                  'identityFingerprintDone',
                                  '指纹识别已完成',
                                ),
                                accentColor: AppTheme.primaryColor,
                                compact: true,
                                showHeader: false,
                                onConfirm: () => _updateVerification(
                                  _verification.copyWith(fingerprint: true),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          VerificationStepCard(
                            index: 3,
                            title: l10n.t('identityNfcTitle', 'NFC识别'),
                            icon: Icons.contactless_rounded,
                            accentColor: AppTheme.primaryColor,
                            verified: _verification.nfc,
                            width: identityVerificationCardWidth,
                            height: identityVerificationCardHeight,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                              child: SensorVerificationCard(
                                title: l10n.t('identityNfcTitle', 'NFC识别'),
                                subtitle: l10n.t('identityNfcTitle', 'NFC识别'),
                                icon: Icons.contactless_rounded,
                                verified: _verification.nfc,
                                actionText: l10n.t(
                                  'identityConfirmNfc',
                                  '确认NFC识别',
                                ),
                                verifiedText: l10n.t(
                                  'identityNfcDone',
                                  'NFC识别已完成',
                                ),
                                accentColor: AppTheme.primaryColor,
                                compact: true,
                                showHeader: false,
                                onConfirm: () => _updateVerification(
                                  _verification.copyWith(nfc: true),
                                ),
                              ),
                            ),
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
            completedCount: _verifiedCount,
            totalCount: 3,
            accentColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }
}

/// 管理员页面头部返回区。
class _AdminHeader extends StatelessWidget {
  /// 创建管理员页面头部。
  const _AdminHeader({required this.title, required this.onBack});

  /// 头部标题。
  final String title;

  /// 返回按钮回调。
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onBack,
          tooltip: context.l10n.t('adminBackTooltip', '返回'),
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
      ],
    );
  }
}

/// 管理员页面点阵背景。
class _AdminDotGridPainter extends CustomPainter {
  /// 创建管理员页面点阵背景绘制器。
  const _AdminDotGridPainter();

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
