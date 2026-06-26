import 'package:flutter/material.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/router/app_router.dart';
import '../../../shared/widgets/identity_verification/face_verification_card.dart';
import '../../../shared/widgets/identity_verification/sensor_verification_card.dart';
import '../../../shared/widgets/terminal_shell.dart';
import '../../../shared/widgets/verification_progress_footer.dart';
import '../../../shared/widgets/verification_step_card.dart';

/// 取件身份验证页面。
///
/// 当前页面包含四种验证方式：人脸、指纹、NFC 和取件码。
class PickupVerificationPage extends StatefulWidget {
  /// 创建取件验证页面。
  const PickupVerificationPage({super.key});

  @override
  State<PickupVerificationPage> createState() => _PickupVerificationPageState();
}

class _PickupVerificationPageState extends State<PickupVerificationPage> {
  /// 人脸是否已验证通过。
  bool _faceVerified = false;

  /// 指纹是否已验证通过。
  bool _fingerprintVerified = false;

  /// NFC 是否已验证通过。
  bool _nfcVerified = false;

  /// 用户输入的取件码。
  String _pickupCode = '';

  /// 取件码是否满足 8 位长度。
  ///
  /// 当前产品逻辑中以 8 位作为取件码完成校验的最小条件。
  bool get _codeVerified => _pickupCode.length == 8;

  /// 当前已经通过的验证项数量。
  int get _verifiedCount {
    return [
      _faceVerified,
      _fingerprintVerified,
      _nfcVerified,
      _codeVerified,
    ].where((verified) => verified).length;
  }

  /// 四个验证项是否全部通过。
  bool get _allVerified => _verifiedCount == 4;

  /// 如果四重认证全部完成，则进入证据信息加载页。
  ///
  /// 这里使用 `addPostFrameCallback`，避免在当前 build 过程中直接触发路由跳转。
  void _goNextIfAllVerified() {
    if (!_allVerified) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacementNamed(AppRoutes.verificationLoading);
      }
    });
  }

  /// 在取件码末尾追加一个数字。
  ///
  /// 超过 8 位后不再继续追加，保持输入长度与业务规则一致。
  void _appendCode(String value) {
    if (_pickupCode.length >= 8) {
      return;
    }
    setState(() => _pickupCode += value);
  }

  /// 删除取件码最后一位。
  void _deleteCode() {
    if (_pickupCode.isEmpty) {
      return;
    }
    setState(
      () => _pickupCode = _pickupCode.substring(0, _pickupCode.length - 1),
    );
  }

  /// 清空当前输入的取件码。
  void _clearCode() {
    if (_pickupCode.isEmpty) {
      return;
    }
    setState(() => _pickupCode = '');
  }

  @override
  Widget build(BuildContext context) {
    _goNextIfAllVerified();

    /// 多语言文案入口，统一读取当前语言下的界面文字。
    final l10n = context.l10n;

    return TerminalShell(
      topBarLeading: _PickupHeader(onBack: () => Navigator.of(context).pop()),
      topRightBadge: FlowStatusBadge(
        text: l10n.t('pickupVerificationBadge', '四重认证中 · 取件'),
      ),
      child: _PickupFrame(
        verifiedCount: _verifiedCount,
        faceVerified: _faceVerified,
        fingerprintVerified: _fingerprintVerified,
        nfcVerified: _nfcVerified,
        pickupCode: _pickupCode,
        codeVerified: _codeVerified,
        onFaceVerified: () => setState(() => _faceVerified = true),
        onFingerprintConfirm: () => setState(() => _fingerprintVerified = true),
        onNfcConfirm: () => setState(() => _nfcVerified = true),
        onCodePressed: _appendCode,
        onCodeDelete: _deleteCode,
        onCodeClear: _clearCode,
      ),
    );
  }
}

/// 取件验证页的固定尺寸外框。
///
/// 页面被设计为 1280x800，再由外层 [FittedBox] 缩放适配屏幕。
class _PickupFrame extends StatelessWidget {
  const _PickupFrame({
    required this.verifiedCount,
    required this.faceVerified,
    required this.fingerprintVerified,
    required this.nfcVerified,
    required this.pickupCode,
    required this.codeVerified,
    required this.onFaceVerified,
    required this.onFingerprintConfirm,
    required this.onNfcConfirm,
    required this.onCodePressed,
    required this.onCodeDelete,
    required this.onCodeClear,
  });

  /// 当前已完成的认证步骤数量。
  final int verifiedCount;

  /// 人脸识别是否通过。
  final bool faceVerified;

  /// 指纹识别是否通过。
  final bool fingerprintVerified;

  /// NFC 识别是否通过。
  final bool nfcVerified;

  /// 当前已输入的取件码内容。
  final String pickupCode;

  /// 取件码是否校验通过。
  final bool codeVerified;

  /// 人脸识别成功后的回调。
  final VoidCallback onFaceVerified;

  /// 点击确认指纹识别时的回调。
  final VoidCallback onFingerprintConfirm;

  /// 点击确认 NFC 识别时的回调。
  final VoidCallback onNfcConfirm;

  /// 点击数字键时的回调。
  final ValueChanged<String> onCodePressed;

  /// 删除取件码最后一位时的回调。
  final VoidCallback onCodeDelete;

  /// 清空取件码时的回调。
  final VoidCallback onCodeClear;

  @override
  Widget build(BuildContext context) {
    /// 当前页面的多语言文案集合。
    final l10n = context.l10n;

    return Column(
      children: [
        Expanded(
          child: CustomPaint(
            painter: const _DotGridPainter(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
              child: Row(
                children: [
                  VerificationStepCard(
                    index: 1,
                    title: l10n.t('pickupFaceTitle', '人脸识别'),
                    icon: Icons.center_focus_strong_rounded,
                    accentColor: const Color(0xFF7048F4),
                    verified: faceVerified,
                    width: 295,
                    height: 619,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                      child: FaceVerificationCard(
                        verified: faceVerified,
                        allowFallbackWithoutCamera: true,
                        accentColor: const Color(0xFF7048F4),
                        compact: true,
                        showHeader: false,
                        onVerified: onFaceVerified,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  VerificationStepCard(
                    index: 2,
                    title: l10n.t('pickupFingerprintTitle', '指纹识别'),
                    icon: Icons.fingerprint_rounded,
                    accentColor: const Color(0xFF4D64EA),
                    verified: fingerprintVerified,
                    width: 295,
                    height: 619,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                      child: SensorVerificationCard(
                        title: l10n.t('pickupFingerprintTitle', '指纹识别'),
                        subtitle: 'Fingerprint Scan',
                        icon: Icons.fingerprint_rounded,
                        verified: fingerprintVerified,
                        actionText: l10n.t(
                          'pickupConfirmFingerprint',
                          '确认指纹识别',
                        ),
                        verifiedText: l10n.t(
                          'pickupFingerprintDone',
                          '指纹识别已完成',
                        ),
                        accentColor: const Color(0xFF4D64EA),
                        compact: true,
                        showHeader: false,
                        onConfirm: onFingerprintConfirm,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  VerificationStepCard(
                    index: 3,
                    title: l10n.t('pickupNfcTitle', 'NFC识别'),
                    icon: Icons.contactless_rounded,
                    accentColor: const Color(0xFF5791B6),
                    verified: nfcVerified,
                    width: 295,
                    height: 619,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                      child: SensorVerificationCard(
                        title: l10n.t('pickupNfcTitle', 'NFC识别'),
                        subtitle: 'NFC Card Scan',
                        icon: Icons.contactless_rounded,
                        verified: nfcVerified,
                        actionText: l10n.t('pickupConfirmNfc', '确认NFC识别'),
                        verifiedText: l10n.t('pickupNfcDone', 'NFC识别已完成'),
                        accentColor: const Color(0xFF5791B6),
                        compact: true,
                        showHeader: false,
                        onConfirm: onNfcConfirm,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  VerificationStepCard(
                    index: 4,
                    title: l10n.t('pickupCodeTitle', '取件码'),
                    icon: Icons.pin_outlined,
                    accentColor: const Color(0xFF4664E9),
                    verified: codeVerified,
                    width: 295,
                    height: 619,
                    child: _PickupCodeContent(
                      code: pickupCode,
                      verified: codeVerified,
                      onDigitPressed: onCodePressed,
                      onDelete: onCodeDelete,
                      onClear: onCodeClear,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        VerificationProgressFooter(
          completedCount: verifiedCount,
          totalCount: 4,
        ),
      ],
    );
  }
}

/// 取件验证页顶部栏。
///
/// 包含返回按钮和当前业务标签。
class _PickupHeader extends StatelessWidget {
  const _PickupHeader({required this.onBack});

  /// 点击返回按钮时触发。
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    /// 顶部栏文案来源。
    final l10n = context.l10n;

    return Row(
      children: [
        SizedBox(
          width: 78,
          height: 34,
          child: OutlinedButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 17),
            label: Text(l10n.t('pickupBack', '返回')),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6877A2),
              side: const BorderSide(color: Color(0xFFDDE5F7)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: EdgeInsets.zero,
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Container(width: 1, height: 18, color: const Color(0xFFE0E6F4)),
        const SizedBox(width: 16),
        Text(
          l10n.t('pickupVerificationHeader', '安全身份验证'),
          style: TextStyle(
            color: Color(0xFF111936),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          height: 20,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF0FF),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            l10n.t('pickupFlowTag', '取件'),
            style: TextStyle(
              color: Color(0xFF4664E9),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// 获取摄像头预览在当前竖屏卡片中展示时使用的宽高比。
///
/// `camera` 插件返回的 [CameraValue.aspectRatio] 常来自横向传感器画面，
/// 直接用于竖屏预览时会把画面算成过窄的尺寸。这里优先使用
/// [CameraValue.previewSize] 的 `height / width` 作为显示比例。
///
/// 真机上前置摄像头返回过 `previewSize=720x480`、`aspectRatio=1.5`。
/// 如果直接用 1.5，会把竖向预览当成横向画面计算；这里反转为
/// `480 / 720 = 0.6667`，再交给 `facePreviewCoverSize` 按 cover 规则铺满容器。
@visibleForTesting
double facePreviewDisplayAspectRatio(Size? rawPreviewSize) {
  if (rawPreviewSize == null ||
      rawPreviewSize.width <= 0 ||
      rawPreviewSize.height <= 0) {
    return 1;
  }

  return rawPreviewSize.height / rawPreviewSize.width;
}

/// 计算摄像头预览以 cover 方式铺满容器时应该使用的尺寸。
///
/// 实时预览和拍照图片都按同一套 cover 规则显示，避免摄像头初始化、
/// 拍照定格、后端校验后在不同宽高比布局之间反复跳变。
@visibleForTesting
Size facePreviewCoverSize({
  required Size containerSize,
  required double previewAspectRatio,
}) {
  if (containerSize.width <= 0 ||
      containerSize.height <= 0 ||
      previewAspectRatio <= 0) {
    return containerSize;
  }

  final containerAspectRatio = containerSize.width / containerSize.height;
  if (containerAspectRatio > previewAspectRatio) {
    return Size(containerSize.width, containerSize.width / previewAspectRatio);
  }

  return Size(containerSize.height * previewAspectRatio, containerSize.height);
}

/// 取件码验证内容。
///
/// 包含取件码显示区域、输入进度提示和数字键盘。
class _PickupCodeContent extends StatelessWidget {
  const _PickupCodeContent({
    required this.code,
    required this.verified,
    required this.onDigitPressed,
    required this.onDelete,
    required this.onClear,
  });

  /// 当前已输入的取件码。
  final String code;

  /// 当前取件码是否已经满足校验条件。
  final bool verified;

  /// 点击数字键时触发。
  final ValueChanged<String> onDigitPressed;

  /// 点击删除时触发。
  final VoidCallback onDelete;

  /// 点击清空时触发。
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    /// 当前页面文案集合。
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.t('pickupCodeHint', '请输入8位取件码'),
              style: TextStyle(
                color: Color(0xFF647197),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _CodeDisplay(code: code),
          const SizedBox(height: 12),
          SizedBox(
            height: 20,
            child: Text(
              verified
                  ? l10n.t('pickupCodeVerified', '取件码校验完成')
                  : l10n
                        .t('pickupCodeProgress', '已输入 {count} / 8 位')
                        .replaceAll('{count}', '${code.length}'),
              style: TextStyle(
                color: verified
                    ? const Color(0xFF59BE5A)
                    : const Color(0xFFA6B0CC),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: _NumberKeyboard(
              onDigitPressed: onDigitPressed,
              onDelete: onDelete,
              onClear: onClear,
            ),
          ),
        ],
      ),
    );
  }
}

/// 取件码显示框。
///
/// 固定显示 8 个格子，已输入的位置显示对应数字。
class _CodeDisplay extends StatelessWidget {
  const _CodeDisplay({required this.code});

  /// 当前完整取件码字符串。
  final String code;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(8, (index) {
        /// 当前格子是否已有输入值。
        final hasValue = index < code.length;
        return Expanded(
          child: Container(
            height: 42,
            margin: EdgeInsets.only(right: index == 7 ? 0 : 5),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F7FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasValue
                    ? const Color(0xFF4664E9)
                    : const Color(0xFFD7E0F4),
              ),
            ),
            child: Text(
              hasValue ? code[index] : '',
              style: const TextStyle(
                color: Color(0xFF243264),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// 数字键盘。
///
/// 提供 0-9 数字输入，以及清空和删除操作。
class _NumberKeyboard extends StatelessWidget {
  const _NumberKeyboard({
    required this.onDigitPressed,
    required this.onDelete,
    required this.onClear,
  });

  /// 点击数字键后的回调。
  final ValueChanged<String> onDigitPressed;

  /// 点击删除键后的回调。
  final VoidCallback onDelete;

  /// 点击清空键后的回调。
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    /// 读取当前语言下的按钮文案。
    final l10n = context.l10n;

    /// 清空键的显示文字。
    final clearLabel = l10n.t('pickupActionClear', '清空');

    /// 删除键的显示文字。
    final deleteLabel = l10n.t('pickupActionDelete', '删除');

    /// 键盘上的全部按键顺序，采用三列网格布局展示。
    final keys = [
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      clearLabel,
      '0',
      deleteLabel,
    ];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: keys.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 9,
        crossAxisSpacing: 9,
        childAspectRatio: 1.48,
      ),
      itemBuilder: (context, index) {
        final key = keys[index];
        return _KeyboardButton(
          label: key,
          onPressed: switch (key) {
            var label when label == clearLabel => onClear,
            var label when label == deleteLabel => onDelete,
            _ => () => onDigitPressed(key),
          },
        );
      },
    );
  }
}

/// 数字键盘上的单个按钮。
class _KeyboardButton extends StatelessWidget {
  const _KeyboardButton({required this.label, required this.onPressed});

  /// 按钮上显示的文字。
  final String label;

  /// 点击按钮时触发的操作。
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    /// 用于判断当前按钮是否属于“清空/删除”这类操作按钮。
    final l10n = context.l10n;
    final isAction =
        label == l10n.t('pickupActionClear', '清空') ||
        label == l10n.t('pickupActionDelete', '删除');

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: isAction ? const Color(0xFFF4F7FF) : Colors.white,
        foregroundColor: isAction
            ? const Color(0xFF7580A8)
            : const Color(0xFF4664E9),
        side: const BorderSide(color: Color(0xFFD7E0F4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: TextStyle(
          fontSize: isAction ? 13 : 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      child: Text(label),
    );
  }
}

/// 背景点阵绘制器。
///
/// 用规则排列的小圆点作为页面背景装饰。
class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    /// 页面背景点阵绘制使用的统一画笔。
    final paint = Paint()
      ..color = const Color(0xFFD8E1F4)
      ..style = PaintingStyle.fill;

    /// 相邻点之间的水平和垂直间距。
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
