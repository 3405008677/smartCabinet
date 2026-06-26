import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/router/app_router.dart';
import '../../../models/dropoff_model.dart';
import '../../../repositories/dropoff_repository.dart';
import '../../../shared/widgets/terminal_shell.dart';

/// 文件图像采集阶段。
enum _CaptureStep { idle, frontNormalDone, frontUvDone, backNormalDone }

/// 放件文件认证页。
class DropoffFileVerificationPage extends StatefulWidget {
  /// 创建放件文件认证页。
  const DropoffFileVerificationPage({super.key});

  @override
  State<DropoffFileVerificationPage> createState() =>
      _DropoffFileVerificationPageState();
}

class _DropoffFileVerificationPageState
    extends State<DropoffFileVerificationPage> {
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

  /// FRC 是否已经识别文件。
  bool _frcVerified = false;

  /// 是否正在拍摄文件图像。
  bool _capturing = false;

  /// 当前拍摄进度。
  _CaptureStep _captureStep = _CaptureStep.idle;

  /// 定时器集合，用于页面销毁时取消模拟硬件事件。
  final List<Timer> _timers = [];

  /// 三张图是否都已采集完成。
  bool get _imagesDone => _captureStep == _CaptureStep.backNormalDone;

  /// 文件认证是否完成。
  bool get _allVerified => _frcVerified && _imagesDone;

  @override
  void initState() {
    super.initState();
    _loadDropoffData();
    _timers.add(
      Timer(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() => _frcVerified = true);
        }
      }),
    );
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
    for (final timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

  /// 启动三张图的模拟采集流程。
  void _startCapture() {
    if (_capturing || _imagesDone) {
      return;
    }
    setState(() => _capturing = true);
    _timers
      ..add(
        Timer(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() => _captureStep = _CaptureStep.frontNormalDone);
          }
        }),
      )
      ..add(
        Timer(const Duration(milliseconds: 650), () {
          if (mounted) {
            setState(() => _captureStep = _CaptureStep.frontUvDone);
          }
        }),
      )
      ..add(
        Timer(const Duration(milliseconds: 1000), () {
          if (mounted) {
            setState(() {
              _captureStep = _CaptureStep.backNormalDone;
              _capturing = false;
            });
          }
        }),
      );
  }

  /// 认证全部完成后进入信息确认页。
  void _goNextIfAllVerified() {
    if (!_allVerified) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacementNamed(AppRoutes.dropoffConfirmOpening);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    _goNextIfAllVerified();

    return TerminalShell(
      topBarLeading: _DropoffHeader(
        title: l10n.t('dropoffFileVerificationTitle', '文件认证'),
        onBack: () => Navigator.of(context).pop(),
      ),
      topRightBadge: FlowStatusBadge(
        text: l10n.t('dropoffFileVerificationBadge', '文件认证中 · 放件'),
      ),
      child: CustomPaint(
        painter: const _DropoffDotGridPainter(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(34, 28, 34, 26),
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: _CapturePanel(
                        capturing: _capturing,
                        imagesDone: _imagesDone,
                        onStart: _startCapture,
                      ),
                    ),
                    const SizedBox(width: 22),
                    Expanded(
                      flex: 4,
                      child: _FrcPanel(
                        frcVerified: _frcVerified,
                        fileCode: _dropoffData.fileCode,
                        fileName: _dropoffData.fileName,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _ImageStatusCard(
                      title: l10n.t('dropoffImageFrontNormal', '正面常规图'),
                      done:
                          _captureStep.index >=
                          _CaptureStep.frontNormalDone.index,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ImageStatusCard(
                      title: l10n.t('dropoffImageFrontUv', '正面紫外荧光图'),
                      done:
                          _captureStep.index >= _CaptureStep.frontUvDone.index,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ImageStatusCard(
                      title: l10n.t('dropoffImageBackNormal', '反面常规图'),
                      done:
                          _captureStep.index >=
                          _CaptureStep.backNormalDone.index,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _captureStep == _CaptureStep.frontUvDone
                    ? Text(
                        l10n.t('dropoffFlipHint', '请翻转文件，保持放在识别区'),
                        key: const ValueKey('flip_hint'),
                        style: TextStyle(
                          color: Color(0xFFC46A00),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : const SizedBox(key: ValueKey('empty_hint'), height: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 文件拍照操作面板。
class _CapturePanel extends StatelessWidget {
  const _CapturePanel({
    required this.capturing,
    required this.imagesDone,
    required this.onStart,
  });

  /// 是否正在采集图像。
  final bool capturing;

  /// 三张图片是否已采集完成。
  final bool imagesDone;

  /// 开始识别按钮回调。
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return _DropoffCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.t('dropoffPlaceFileHint', '请将文件放到指定识别区'),
            style: TextStyle(
              color: Color(0xFF111936),
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.t(
              'dropoffStartRecognitionHint',
              '点击开始识别后，系统将依次采集合格证正面常规图、正面紫外荧光图和反面常规图。',
            ),
            style: TextStyle(
              color: Color(0xFF6877A2),
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEAF0FF),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFC8D5FF)),
              ),
              child: const Center(
                child: Icon(
                  Icons.document_scanner_outlined,
                  color: Color(0xFF4664E9),
                  size: 86,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: capturing || imagesDone ? null : onStart,
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: Text(
                imagesDone
                    ? l10n.t('dropoffImageCaptured', '图像已采集')
                    : capturing
                    ? l10n.t('dropoffCapturing', '采集中...')
                    : l10n.t('dropoffStartRecognition', '开始识别'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4664E9),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// FRC 文件识别状态面板。
class _FrcPanel extends StatelessWidget {
  const _FrcPanel({
    required this.frcVerified,
    required this.fileCode,
    required this.fileName,
  });

  /// FRC 是否识别成功。
  final bool frcVerified;

  /// 文件编号。
  final String fileCode;

  /// 文件名称。
  final String fileName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return _DropoffCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.t('dropoffFrcTitle', 'FRC 文件识别'),
            style: TextStyle(
              color: Color(0xFF111936),
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 22),
          _InfoLine(
            label: l10n.t('dropoffRecognitionStatusLabel', '识别状态'),
            value: frcVerified
                ? l10n.t('dropoffFrcRecognized', 'FRC 已识别')
                : l10n.t('dropoffWaitingFilePlaced', '等待文件放入'),
          ),
          _InfoLine(
            label: l10n.t('dropoffFileCodeLabel', '文件编号'),
            value: fileCode,
          ),
          _InfoLine(
            label: l10n.t('dropoffFileNameLabel', '文件名称'),
            value: fileName,
          ),
          _InfoLine(
            label: l10n.t('dropoffMatchResultLabel', '匹配结果'),
            value: frcVerified
                ? l10n.t('dropoffMatched', '已匹配')
                : l10n.t('dropoffPendingMatch', '待匹配'),
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: frcVerified
                  ? const Color(0xFFEAFBF0)
                  : const Color(0xFFFFFAEF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: frcVerified
                    ? const Color(0xFFBEE8CC)
                    : const Color(0xFFF3D8A8),
              ),
            ),
            child: Text(
              frcVerified
                  ? l10n.t('dropoffTagReadHint', '文件标签已读取，等待图像采集完成。')
                  : l10n.t(
                      'dropoffPlaceFileForFrcHint',
                      '请将文件放入识别区，FRC 将自动检测。',
                    ),
              style: TextStyle(
                color: frcVerified
                    ? const Color(0xFF15803D)
                    : const Color(0xFFC46A00),
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 图像采集状态卡。
class _ImageStatusCard extends StatelessWidget {
  const _ImageStatusCard({required this.title, required this.done});

  /// 图像名称。
  final String title;

  /// 是否采集完成。
  final bool done;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      height: 104,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: done ? const Color(0xFFBEE8CC) : const Color(0xFFE1E8F8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF111936),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          Text(
            done
                ? l10n
                      .t('dropoffImageCapturedSuffix', '{title}已采集')
                      .replaceAll('{title}', title)
                : l10n.t('dropoffImageNotCaptured', '未采集'),
            style: TextStyle(
              color: done ? const Color(0xFF22A857) : const Color(0xFF8D99B8),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// 放件通用卡片容器。
class _DropoffCard extends StatelessWidget {
  const _DropoffCard({required this.child});

  /// 卡片内容。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
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
      ),
      child: child,
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
      height: 42,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEAF0FA))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 84,
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
