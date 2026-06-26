import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/router/app_router.dart';
import '../../../shared/widgets/identity_verification/face_verification_card.dart';
import '../../../shared/widgets/identity_verification/sensor_verification_card.dart';
import '../../../shared/widgets/terminal_shell.dart';
import '../../../shared/widgets/verification_progress_footer.dart';
import '../../../shared/widgets/verification_step_card.dart';

/// 管理员身份校验页。
class AdminVerificationPage extends StatefulWidget {
  /// 创建管理员身份校验页。
  const AdminVerificationPage({super.key});

  @override
  State<AdminVerificationPage> createState() => _AdminVerificationPageState();
}

class _AdminVerificationPageState extends State<AdminVerificationPage> {
  /// 人脸认证是否通过。
  bool _faceVerified = false;

  /// 指纹认证是否通过。
  bool _fingerprintVerified = false;

  /// NFC 认证是否通过。
  bool _nfcVerified = false;

  /// 已完成认证项数量。
  int get _verifiedCount => [
    _faceVerified,
    _fingerprintVerified,
    _nfcVerified,
  ].where((verified) => verified).length;

  /// 是否完成所有管理员身份认证。
  bool get _allVerified => _verifiedCount == 3;

  /// 三项认证完成后进入管理员控制台。
  void _goNextIfAllVerified() {
    if (!_allVerified) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.adminConsole);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _goNextIfAllVerified();

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
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.t('adminVerificationHeading', '请完成管理员安全身份认证'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF111936),
                        fontSize: 34,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.t(
                        'adminVerificationDescription',
                        '登录权限已通过，请继续完成人脸、指纹与 NFC 三项校验',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF6877A2),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n
                          .t('adminVerificationProgress', '已完成 {count} / 3 项认证')
                          .replaceAll('{count}', '$_verifiedCount'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF8A2364),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 26),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          VerificationStepCard(
                            index: 1,
                            title: l10n.t('pickupFaceTitle', '人脸识别'),
                            icon: Icons.center_focus_strong_rounded,
                            accentColor: const Color(0xFF8A2364),
                            verified: _faceVerified,
                            width: 295,
                            height: 619,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                              child: FaceVerificationCard(
                                verified: _faceVerified,
                                accentColor: const Color(0xFF8A2364),
                                allowFallbackWithoutCamera: true,
                                compact: true,
                                showHeader: false,
                                onVerified: () =>
                                    setState(() => _faceVerified = true),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          VerificationStepCard(
                            index: 2,
                            title: l10n.t('pickupFingerprintTitle', '指纹识别'),
                            icon: Icons.fingerprint_rounded,
                            accentColor: const Color(0xFF8A2364),
                            verified: _fingerprintVerified,
                            width: 295,
                            height: 619,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                              child: SensorVerificationCard(
                                title: l10n.t('pickupFingerprintTitle', '指纹识别'),
                                subtitle: 'Fingerprint Scan',
                                icon: Icons.fingerprint_rounded,
                                verified: _fingerprintVerified,
                                actionText: l10n.t(
                                  'pickupConfirmFingerprint',
                                  '确认指纹识别',
                                ),
                                verifiedText: l10n.t(
                                  'pickupFingerprintDone',
                                  '指纹识别已完成',
                                ),
                                accentColor: const Color(0xFF8A2364),
                                compact: true,
                                showHeader: false,
                                onConfirm: () =>
                                    setState(() => _fingerprintVerified = true),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          VerificationStepCard(
                            index: 3,
                            title: l10n.t('pickupNfcTitle', 'NFC识别'),
                            icon: Icons.contactless_rounded,
                            accentColor: const Color(0xFF8A2364),
                            verified: _nfcVerified,
                            width: 295,
                            height: 619,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                              child: SensorVerificationCard(
                                title: l10n.t('pickupNfcTitle', 'NFC识别'),
                                subtitle: 'NFC Card Scan',
                                icon: Icons.contactless_rounded,
                                verified: _nfcVerified,
                                actionText: l10n.t(
                                  'pickupConfirmNfc',
                                  '确认NFC识别',
                                ),
                                verifiedText: l10n.t(
                                  'pickupNfcDone',
                                  'NFC识别已完成',
                                ),
                                accentColor: const Color(0xFF8A2364),
                                compact: true,
                                showHeader: false,
                                onConfirm: () =>
                                    setState(() => _nfcVerified = true),
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
            accentColor: const Color(0xFF8A2364),
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
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF17213D)),
        ),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF17213D),
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
    final paint = Paint()..color = const Color(0x148A2364);
    for (double x = 14; x < size.width; x += 28) {
      for (double y = 14; y < size.height; y += 28) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
