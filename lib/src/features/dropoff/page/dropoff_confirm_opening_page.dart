import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/router/app_router.dart';
import '../../../models/dropoff_model.dart';
import '../../../repositories/dropoff_repository.dart';
import '../../../shared/widgets/terminal_shell.dart';

/// 放件信息确认倒计时页。
class DropoffConfirmOpeningPage extends StatefulWidget {
  /// 创建放件信息确认页。
  const DropoffConfirmOpeningPage({super.key});

  @override
  State<DropoffConfirmOpeningPage> createState() =>
      _DropoffConfirmOpeningPageState();
}

class _DropoffConfirmOpeningPageState extends State<DropoffConfirmOpeningPage> {
  /// 放件展示数据。
  DropoffModel _dropoffData = DropoffModel.fromMap(const {
    'personName': '张晓明',
    'employeeCode': 'EMP-2026-0612',
    'department': '法务合规部',
    'permissionLevel': 'L3 · 文件存放权限',
    'fileCode': 'FILE-2026-001',
    'fileName': '合格证原件',
    'frcResult': '已匹配',
    'doorNo': 'A-08',
    'doorLocation': 'A区第2列第4格 · 标准文件柜 · 待开门',
    'openDoorTitle': '柜门 A-08 已打开',
    'successSummary': '已存入 1 份文件 · 柜门 A-08 · 已写入审计日志',
  });

  /// 自动开柜前剩余秒数。
  int _seconds = 2;

  /// 倒计时定时器。
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadDropoffData();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      if (_seconds <= 1) {
        Navigator.of(
          context,
        ).pushReplacementNamed(AppRoutes.dropoffOpenCabinet);
        return;
      }
      setState(() => _seconds -= 1);
    });
  }

  /// 加载放件展示数据。
  Future<void> _loadDropoffData() async {
    final data = await dropoffRepository.fetchDropoffData();
    if (!mounted) {
      return;
    }
    setState(() => _dropoffData = data);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return TerminalShell(
      topBarLeading: _DropoffHeader(
        title: l10n.t('dropoffConfirmTitle', '放件信息确认'),
        onBack: () => Navigator.of(context).pop(),
      ),
      topRightBadge: FlowStatusBadge(
        text: l10n.t('dropoffConfirmBadge', '认证完成 · 待开柜'),
      ),
      child: CustomPaint(
        painter: const _DropoffDotGridPainter(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(40, 28, 40, 28),
          child: Column(
            children: [
              Text(
                l10n.t('dropoffOpeningHint', '认证完成，柜门即将打开...'),
                style: const TextStyle(
                  color: Color(0xFF111936),
                  fontSize: 34,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n
                    .t('dropoffOpeningCountdown', '{seconds}s 后自动打开柜门')
                    .replaceAll('{seconds}', '$_seconds'),
                style: const TextStyle(
                  color: Color(0xFF4664E9),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _InfoPanel(
                        title: l10n.t('dropoffDepositorInfo', '存放人信息'),
                        lines: [
                          _InfoPair(
                            l10n.t('dropoffNameLabel', '姓名'),
                            _dropoffData.personName,
                          ),
                          _InfoPair(
                            l10n.t('dropoffEmployeeCodeLabel', '工号'),
                            _dropoffData.employeeCode,
                          ),
                          _InfoPair(
                            l10n.t('dropoffDepartmentLabel', '部门'),
                            _dropoffData.department,
                          ),
                          _InfoPair(
                            l10n.t('dropoffPermissionLabel', '权限'),
                            _dropoffData.permissionLevel,
                          ),
                          _InfoPair(
                            l10n.t('dropoffVerificationLabel', '认证'),
                            l10n.t(
                              'dropoffVerificationPassed',
                              '人脸/指纹/NFC 已通过',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _InfoPanel(
                        title: l10n.t('dropoffDocumentInfo', '文件信息'),
                        lines: [
                          _InfoPair(
                            l10n.t('dropoffFileCodeLabel', '文件编号'),
                            _dropoffData.fileCode,
                          ),
                          _InfoPair(
                            l10n.t('dropoffFileNameLabel', '文件名称'),
                            _dropoffData.fileName,
                          ),
                          _InfoPair(
                            l10n.t('dropoffFrcLabel', 'FRC识别'),
                            _dropoffData.frcResult,
                          ),
                          _InfoPair(
                            l10n.t('dropoffImageFrontNormal', '正面常规图'),
                            l10n.t('dropoffImageCaptured', '已采集'),
                          ),
                          _InfoPair(
                            l10n.t('dropoffImageFrontUv', '正面紫外荧光图'),
                            l10n.t('dropoffImageCaptured', '已采集'),
                          ),
                          _InfoPair(
                            l10n.t('dropoffImageBackNormal', '反面常规图'),
                            l10n.t('dropoffImageCaptured', '已采集'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _DoorSummaryPanel(
                doorNo: _dropoffData.doorNo,
                doorLocation: _dropoffData.doorLocation,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 信息字段。
class _InfoPair {
  const _InfoPair(this.label, this.value);

  /// 字段名。
  final String label;

  /// 字段值。
  final String value;
}

/// 信息面板。
class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.title, required this.lines});

  /// 面板标题。
  final String title;

  /// 信息行。
  final List<_InfoPair> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF111936),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          for (final line in lines)
            _InfoLine(label: line.label, value: line.value),
        ],
      ),
    );
  }
}

/// 柜门摘要面板。
class _DoorSummaryPanel extends StatelessWidget {
  const _DoorSummaryPanel({required this.doorNo, required this.doorLocation});

  /// 柜门编号。
  final String doorNo;

  /// 柜门位置说明。
  final String doorLocation;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 94,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          const Icon(
            Icons.meeting_room_outlined,
            color: Color(0xFF4664E9),
            size: 34,
          ),
          const SizedBox(width: 18),
          Text(
            context.l10n.t('pickupDoorNoSectionTitle', '柜门信息'),
            style: TextStyle(
              color: Color(0xFF111936),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          Text(
            doorNo,
            style: TextStyle(
              color: Color(0xFF4664E9),
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 22),
          Text(
            doorLocation,
            style: const TextStyle(
              color: Color(0xFF53658F),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// 信息展示行。
class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  /// 字段名。
  final String label;

  /// 字段值。
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEAF0FA))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 102,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF9AA6C2),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF233158),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 通用卡片装饰。
BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: const Color(0xFFE1E8F8)),
    boxShadow: const [
      BoxShadow(
        color: Color(0x0D1B2E5A),
        blurRadius: 20,
        offset: Offset(0, 10),
      ),
    ],
  );
}

/// 放件顶部左侧标题区。
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

/// 放件背景点阵。
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
