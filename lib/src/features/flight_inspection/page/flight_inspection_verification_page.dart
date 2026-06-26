import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/router/app_router.dart';
import '../../../models/flight_inspection_model.dart';
import '../../../repositories/flight_inspection_repository.dart';
import '../../../shared/widgets/identity_verification/face_verification_card.dart';
import '../../../shared/widgets/identity_verification/sensor_verification_card.dart';
import '../../../shared/widgets/terminal_shell.dart';
import '../../../shared/widgets/verification_progress_footer.dart';
import '../../../shared/widgets/verification_step_card.dart';

/// 飞检人员认证页。
class FlightInspectionVerificationPage extends StatefulWidget {
  /// 创建飞检人员认证页。
  const FlightInspectionVerificationPage({super.key});

  @override
  State<FlightInspectionVerificationPage> createState() =>
      _FlightInspectionVerificationPageState();
}

class _FlightInspectionVerificationPageState
    extends State<FlightInspectionVerificationPage> {
  /// 飞检人员展示数据。
  FlightInspectionModel _inspectionData = FlightInspectionModel.fromMap(const {
    'inspectorName': '李晨',
    'employeeCode': 'INS-2026-014',
    'permissionLevel': 'L3',
    'batchNo': 'FI-20260616-01',
    'tasks': [],
  });

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

  /// 是否完成所有飞检人员认证。
  bool get _allVerified => _verifiedCount == 3;

  /// 三项认证完成后进入飞检柜门列表。
  void _goNextIfAllVerified() {
    if (!_allVerified) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacementNamed(AppRoutes.flightInspectionTasks);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadInspectionData();
  }

  /// 加载飞检人员展示数据。
  Future<void> _loadInspectionData() async {
    final data = await flightInspectionRepository.fetchFlightInspectionData();
    if (!mounted) {
      return;
    }
    setState(() => _inspectionData = data);
  }

  @override
  Widget build(BuildContext context) {
    _goNextIfAllVerified();

    final l10n = context.l10n;

    return TerminalShell(
      topBarLeading: _InspectionHeader(
        title: l10n.t('inspectionVerificationTitle', '飞检人员认证'),
        onBack: () => Navigator.of(context).pop(),
      ),
      topRightBadge: FlowStatusBadge(
        text: l10n.t('inspectionVerificationBadge', '人员认证中 · 飞检'),
      ),
      child: Column(
        children: [
          Expanded(
            child: CustomPaint(
              painter: const _InspectionDotGridPainter(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.t('inspectionVerificationHeading', '请完成飞检人员身份认证'),
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
                            'inspectionVerifierInfo',
                            '飞检员：{name} · 工号 {code} · 权限 {permission}',
                          )
                          .replaceAll('{name}', _inspectionData.inspectorName)
                          .replaceAll('{code}', _inspectionData.employeeCode)
                          .replaceAll(
                            '{permission}',
                            _inspectionData.permissionLevel,
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
                          .t(
                            'inspectionVerificationProgress',
                            '已完成 {count} / 3 项认证',
                          )
                          .replaceAll('{count}', '$_verifiedCount'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF0891B2),
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
                            accentColor: const Color(0xFF0891B2),
                            verified: _faceVerified,
                            width: 295,
                            height: 619,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                              child: FaceVerificationCard(
                                verified: _faceVerified,
                                accentColor: const Color(0xFF0891B2),
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
                            accentColor: const Color(0xFF0891B2),
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
                                accentColor: const Color(0xFF0891B2),
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
                            accentColor: const Color(0xFF0891B2),
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
                                accentColor: const Color(0xFF0891B2),
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
            accentColor: const Color(0xFF0891B2),
          ),
        ],
      ),
    );
  }
}

/// 飞检页面顶部左侧标题区。
class _InspectionHeader extends StatelessWidget {
  const _InspectionHeader({required this.title, required this.onBack});

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
          label: Text(context.l10n.t('inspectionBack', '返回')),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF0891B2),
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

/// 飞检页面背景点阵。
class _InspectionDotGridPainter extends CustomPainter {
  /// 创建点阵绘制器。
  const _InspectionDotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0891B2).withValues(alpha: .06)
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
