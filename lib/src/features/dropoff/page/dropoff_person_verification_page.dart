import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/router/app_router.dart';
import '../../../shared/widgets/identity_verification/face_verification_card.dart';
import '../../../shared/widgets/identity_verification/sensor_verification_card.dart';
import '../../../shared/widgets/terminal_shell.dart';
import '../../../shared/widgets/verification_progress_footer.dart';
import '../../../shared/widgets/verification_step_card.dart';

/// 放件人员认证页。
///
/// 用于在放件前完成存放人的人脸、指纹和 NFC 三项认证。
class DropoffPersonVerificationPage extends StatefulWidget {
  /// 创建放件人员认证页。
  const DropoffPersonVerificationPage({super.key});

  @override
  State<DropoffPersonVerificationPage> createState() =>
      _DropoffPersonVerificationPageState();
}

class _DropoffPersonVerificationPageState
    extends State<DropoffPersonVerificationPage> {
  /// 人脸认证是否通过。
  bool _faceVerified = false;

  /// 指纹认证是否通过。
  bool _fingerprintVerified = false;

  /// NFC 认证是否通过。
  bool _nfcVerified = false;

  /// 已通过认证项数量。
  int get _verifiedCount => [
    _faceVerified,
    _fingerprintVerified,
    _nfcVerified,
  ].where((verified) => verified).length;

  /// 是否已经完成所有人员认证。
  bool get _allVerified => _verifiedCount == 3;

  /// 如果三项人员认证完成，则进入文件认证页。
  void _goNextIfAllVerified() {
    if (!_allVerified) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacementNamed(AppRoutes.dropoffFileVerification);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _goNextIfAllVerified();

    final l10n = context.l10n;

    return TerminalShell(
      topBarLeading: _DropoffHeader(
        title: l10n.t('dropoffPersonVerificationTitle', '放件人员认证'),
        onBack: () => Navigator.of(context).pop(),
      ),
      topRightBadge: FlowStatusBadge(
        text: l10n.t('dropoffPersonVerificationBadge', '人员认证中 · 放件'),
      ),
      child: Column(
        children: [
          Expanded(
            child: CustomPaint(
              painter: const _DropoffDotGridPainter(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.t('dropoffPersonVerificationHeading', '请完成存放人身份认证'),
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
                      l10n
                          .t(
                            'dropoffPersonVerificationProgress',
                            '已完成 {count} / 3 项认证',
                          )
                          .replaceAll('{count}', '$_verifiedCount'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF6877A2),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
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
                            accentColor: const Color(0xFF4664E9),
                            verified: _faceVerified,
                            width: 295,
                            height: 619,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                              child: FaceVerificationCard(
                                verified: _faceVerified,
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
                            accentColor: const Color(0xFF4664E9),
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
                            accentColor: const Color(0xFF4664E9),
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
          ),
        ],
      ),
    );
  }
}

/// 放件页面顶部左侧标题区。
class _DropoffHeader extends StatelessWidget {
  const _DropoffHeader({required this.title, required this.onBack});

  /// 页面标题。
  final String title;

  /// 返回按钮点击回调。
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: Text(context.l10n.t('dropoffBack', '返回')),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF4664E9),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF111936),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

/// 放件页面背景点阵。
class _DropoffDotGridPainter extends CustomPainter {
  const _DropoffDotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD8E1F4)
      ..style = PaintingStyle.fill;

    const spacing = 32.0;
    for (double y = 17; y < size.height; y += spacing) {
      for (double x = 16; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.05, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
