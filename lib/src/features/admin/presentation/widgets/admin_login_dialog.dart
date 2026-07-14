import 'package:flutter/material.dart';

import 'package:smart_cabinet/src/app/theme/app_theme.dart';

import 'package:smart_cabinet/src/app/localization/app_localizations.dart';

import 'package:smart_cabinet/src/app/routing/app_routes.dart';
import 'package:smart_cabinet/src/features/admin/data/repositories/admin_repository_impl.dart';

// 首页管理员登录模块。
//
// 普通用户入口不展示该弹窗，只有隐藏设置中的“管理员模式”会触发。
// 登录成功后还会进入管理员三项身份校验页，不会直接打开控制台。

/// 打开管理员登录弹窗。
void showAdminLoginDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => const _AdminLoginDialog(),
  );
}

/// 管理员登录弹窗。
class _AdminLoginDialog extends StatefulWidget {
  const _AdminLoginDialog();

  @override
  State<_AdminLoginDialog> createState() => _AdminLoginDialogState();
}

class _AdminLoginDialogState extends State<_AdminLoginDialog> {
  /// 管理员账号输入框控制器。
  final _usernameController = TextEditingController();

  /// 管理员密码输入框控制器。
  final _passwordController = TextEditingController();

  /// 当前数字键盘正在输入的字段。
  _AdminLoginFieldType? _activeField;

  /// 是否正在提交管理员登录请求。
  bool _loginLoading = false;

  /// 登录失败时展示在弹窗内的错误文案。
  String? _loginError;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _selectField(_AdminLoginFieldType fieldType) {
    setState(() => _activeField = fieldType);
  }

  /// 向当前选中的输入框追加一个数字键。
  void _appendDigit(String value) {
    final controller = _activeController;
    if (controller == null) {
      return;
    }

    controller.text += value;
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
  }

  /// 删除当前选中输入框的最后一位数字。
  void _deleteDigit() {
    final controller = _activeController;
    if (controller == null || controller.text.isEmpty) {
      return;
    }

    controller.text = controller.text.substring(0, controller.text.length - 1);
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
  }

  /// 清空当前选中的输入框。
  void _clearInput() {
    _activeController?.clear();
  }

  /// 取消数字键盘输入状态，恢复左侧插画展示。
  void _returnToIllustration() {
    setState(() => _activeField = null);
  }

  /// 调用假 API 校验管理员权限，成功后进入管理员身份校验页。
  Future<void> _login() async {
    if (_loginLoading) {
      return;
    }
    setState(() {
      _loginLoading = true;
      _loginError = null;
    });
    try {
      final result = await adminRepository.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      if (!result.authorized) {
        setState(() {
          _loginLoading = false;
          _loginError = context.l10n.t(
            'adminLoginDeniedMessage',
            result.message,
          );
        });
        return;
      }
      Navigator.of(context).pop();
      Navigator.of(context).pushNamed(AppRoutes.adminVerification);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loginLoading = false;
        _loginError = context.l10n.t(
          'adminLoginFailureMessage',
          '管理员权限校验失败，请稍后重试',
        );
      });
    }
  }

  TextEditingController? get _activeController => switch (_activeField) {
    _AdminLoginFieldType.username => _usernameController,
    _AdminLoginFieldType.password => _passwordController,
    null => null,
  };

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final availableWidth = mediaSize.width - 48;
    final availableHeight = mediaSize.height - 48;
    final dialogWidth = availableWidth.clamp(592.0, 820.0);

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: availableHeight,
        ),
        child: Container(
          height: availableHeight.clamp(360.0, 454.0),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE3BD),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white, width: 5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2E1B1730),
                blurRadius: 24,
                offset: Offset(0, 14),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              Expanded(
                child: _AdminLoginVisualPanel(
                  activeField: _activeField,
                  onDigitPressed: _appendDigit,
                  onDelete: _deleteDigit,
                  onClear: _clearInput,
                  onBack: _returnToIllustration,
                ),
              ),
              SizedBox(
                width: 344,
                child: _AdminLoginPanel(
                  usernameController: _usernameController,
                  passwordController: _passwordController,
                  activeField: _activeField,
                  onFieldSelected: _selectField,
                  loginLoading: _loginLoading,
                  loginError: _loginError,
                  onLogin: _login,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 管理员登录当前选中的输入字段。
enum _AdminLoginFieldType { username, password }

/// 管理员登录左侧视觉区，输入框聚焦后由插画过渡为数字键盘。
class _AdminLoginVisualPanel extends StatelessWidget {
  const _AdminLoginVisualPanel({
    required this.activeField,
    required this.onDigitPressed,
    required this.onDelete,
    required this.onClear,
    required this.onBack,
  });

  /// 当前数字键盘绑定的输入字段；为空时显示插画。
  final _AdminLoginFieldType? activeField;

  /// 点击数字键时回调。
  final ValueChanged<String> onDigitPressed;

  /// 点击删除键时回调。
  final VoidCallback onDelete;

  /// 点击清空键时回调。
  final VoidCallback onClear;

  /// 点击返回时切回插画区域。
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(-.04, 0),
          end: Offset.zero,
        ).animate(animation);

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offsetAnimation, child: child),
        );
      },
      child: activeField == null
          ? const _AdminLoginIllustration(
              key: ValueKey('admin_login_illustration'),
            )
          : _AdminNumberKeyboardPanel(
              key: const ValueKey('admin_login_number_keyboard_panel'),
              activeField: activeField!,
              onDigitPressed: onDigitPressed,
              onDelete: onDelete,
              onClear: onClear,
              onBack: onBack,
            ),
    );
  }
}

/// 管理员登录左侧插画区域。
class _AdminLoginIllustration extends StatelessWidget {
  const _AdminLoginIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(painter: const _AdminIllustrationPainter()),
        ),
        Align(
          alignment: const Alignment(0, -.46),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SpeechBubble(width: 104),
              const SizedBox(height: 8),
              const Icon(
                Icons.sentiment_satisfied_alt_rounded,
                color: AppTheme.primaryColor,
                size: 96,
              ),
              const SizedBox(height: 2),
              Container(
                width: 118,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryBorderColor),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: AppTheme.primaryColor,
                  size: 38,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 48,
          right: 48,
          bottom: 30,
          child: Column(
            children: [
              Text(
                context.l10n.t('adminLoginSubtitleTitle', '智能柜管理后台'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.primaryStrongColor,
                  fontSize: 18,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                context.l10n.t(
                  'adminLoginSubtitleDescription',
                  '设备状态、格口权限与业务记录统一管控',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.primaryStrongColor,
                  fontSize: 11,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 管理员登录右侧面板。
class _AdminLoginPanel extends StatelessWidget {
  const _AdminLoginPanel({
    required this.usernameController,
    required this.passwordController,
    required this.activeField,
    required this.onFieldSelected,
    required this.loginLoading,
    required this.loginError,
    required this.onLogin,
  });

  /// 用户名输入控制器。
  final TextEditingController usernameController;

  /// 密码输入控制器。
  final TextEditingController passwordController;

  /// 当前正在通过数字键盘输入的字段。
  final _AdminLoginFieldType? activeField;

  /// 输入框获得焦点时切换数字键盘目标字段。
  final ValueChanged<_AdminLoginFieldType> onFieldSelected;

  /// 是否正在提交登录校验。
  final bool loginLoading;

  /// 登录失败或无权限时的提示文本。
  final String? loginError;

  /// 点击登录按钮时执行的动作。
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return LayoutBuilder(
      builder: (context, constraints) {
        final panelWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 344.0;
        final compactPadding = panelWidth < 340;
        final panelHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 454.0;
        final compactHeight = panelHeight < 420;
        final titleGap = compactHeight ? 20.0 : 29.0;
        final fieldGap = compactHeight ? 12.0 : 16.0;
        final buttonGap = compactHeight ? 16.0 : 22.0;

        return Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(
            compactPadding ? 28 : 54,
            compactHeight ? 30 : (compactPadding ? 34 : 70),
            compactPadding ? 28 : 54,
            compactHeight ? 28 : (compactPadding ? 30 : 52),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _AdminLoginMark(),
              SizedBox(height: compactHeight ? 12 : 24),
              Text(
                l10n.t('adminLoginTitle', '管理员后台'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 21,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: titleGap),
              _AdminLoginField(
                labelText: l10n.t('adminUsernameLabel', '用户名'),
                hintText: 'mail@abc.com',
                controller: usernameController,
                selected: activeField == _AdminLoginFieldType.username,
                onTap: () => onFieldSelected(_AdminLoginFieldType.username),
              ),
              SizedBox(height: fieldGap),
              _AdminLoginField(
                labelText: l10n.t('adminPasswordLabel', '密码'),
                hintText: '••••••••••••',
                controller: passwordController,
                selected: activeField == _AdminLoginFieldType.password,
                onTap: () => onFieldSelected(_AdminLoginFieldType.password),
                obscureText: true,
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  SizedBox(
                    width: 13,
                    height: 13,
                    child: Checkbox(
                      value: true,
                      onChanged: (_) {},
                      activeColor: AppTheme.primaryColor,
                      side: const BorderSide(
                        color: AppTheme.primaryBorderColor,
                        width: 1,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.t('adminRememberPassword', '记住密码'),
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 10,
                      height: 1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: buttonGap),
              if (loginError != null) ...[
                Text(
                  loginError!,
                  key: const ValueKey('admin_login_error'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 11,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              _AdminPrimaryButton(
                compact: compactHeight,
                loading: loginLoading,
                onPressed: onLogin,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 管理员登录标识。
class _AdminLoginMark extends StatelessWidget {
  const _AdminLoginMark();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.scatter_plot_rounded,
        color: AppTheme.primaryColor,
        size: 38,
      ),
    );
  }
}

/// 管理员登录主按钮。
class _AdminPrimaryButton extends StatelessWidget {
  const _AdminPrimaryButton({
    required this.compact,
    required this.loading,
    required this.onPressed,
  });

  /// 是否使用紧凑高度，避免小屏高度下底部溢出。
  final bool compact;

  /// 是否正在登录校验。
  final bool loading;

  /// 点击登录按钮时执行的动作。
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SizedBox(
      height: compact ? 32 : 35,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                l10n.t('adminLoginButton', '登录'),
                style: TextStyle(
                  fontSize: 13,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
      ),
    );
  }
}

/// 管理员登录数字键盘面板。
class _AdminNumberKeyboardPanel extends StatelessWidget {
  const _AdminNumberKeyboardPanel({
    super.key,
    required this.activeField,
    required this.onDigitPressed,
    required this.onDelete,
    required this.onClear,
    required this.onBack,
  });

  /// 当前数字键盘绑定的输入字段。
  final _AdminLoginFieldType activeField;

  /// 点击数字键时回调。
  final ValueChanged<String> onDigitPressed;

  /// 点击删除键时回调。
  final VoidCallback onDelete;

  /// 点击清空键时回调。
  final VoidCallback onClear;

  /// 点击返回时切回插画区域。
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = switch (activeField) {
      _AdminLoginFieldType.username => l10n.t('adminInputUsername', '输入用户名'),
      _AdminLoginFieldType.password => l10n.t('adminInputPassword', '输入密码'),
    };

    return Container(
      color: AppTheme.primarySoftColor,
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 15,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton.icon(
                key: const ValueKey('admin_keyboard_back'),
                onPressed: onBack,
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 15),
                label: Text(l10n.t('adminKeyboardBack', '返回')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.t('adminKeyboardHint', '使用左侧数字键盘录入'),
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 11,
              height: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: _AdminNumberKeyboard(
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

/// 管理员登录数字键盘。
class _AdminNumberKeyboard extends StatelessWidget {
  const _AdminNumberKeyboard({
    required this.onDigitPressed,
    required this.onDelete,
    required this.onClear,
  });

  /// 点击数字键时回调。
  final ValueChanged<String> onDigitPressed;

  /// 点击删除键时回调。
  final VoidCallback onDelete;

  /// 点击清空键时回调。
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final clearLabel = l10n.t('adminKeyboardClear', '清空');
    final deleteLabel = l10n.t('adminKeyboardDelete', '删除');
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final keyboardWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 256.0;
        final keyboardHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 300.0;
        const crossAxisSpacing = 9.0;
        const mainAxisSpacing = 9.0;
        const rowCount = 4;
        const columnCount = 3;
        final buttonWidth =
            (keyboardWidth - crossAxisSpacing * (columnCount - 1)) /
            columnCount;
        final buttonHeight =
            (keyboardHeight - mainAxisSpacing * (rowCount - 1)) / rowCount;
        final buttonAspectRatio = buttonWidth / buttonHeight.clamp(1.0, 80.0);

        return GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: keys.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnCount,
            mainAxisSpacing: mainAxisSpacing,
            crossAxisSpacing: crossAxisSpacing,
            childAspectRatio: buttonAspectRatio,
          ),
          itemBuilder: (context, index) {
            final key = keys[index];
            return _AdminKeyboardButton(
              key: ValueKey('admin_keyboard_$key'),
              label: key,
              onPressed: switch (key) {
                var label when label == clearLabel => onClear,
                var label when label == deleteLabel => onDelete,
                _ => () => onDigitPressed(key),
              },
            );
          },
        );
      },
    );
  }
}

/// 管理员数字键盘上的单个按键。
class _AdminKeyboardButton extends StatelessWidget {
  const _AdminKeyboardButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  /// 按键显示文本。
  final String label;

  /// 点击按键时执行的动作。
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isAction =
        label == l10n.t('adminKeyboardClear', '清空') ||
        label == l10n.t('adminKeyboardDelete', '删除');

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: isAction ? AppTheme.primarySoftColor : Colors.white,
        foregroundColor: isAction
            ? AppTheme.textSecondaryColor
            : AppTheme.primaryColor,
        side: const BorderSide(color: AppTheme.primaryBorderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: TextStyle(
          fontSize: isAction ? 12 : 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      child: Text(label),
    );
  }
}

/// 管理员登录输入框。
class _AdminLoginField extends StatelessWidget {
  const _AdminLoginField({
    required this.labelText,
    required this.hintText,
    required this.controller,
    required this.selected,
    required this.onTap,
    this.obscureText = false,
  });

  /// 输入框标签。
  final String labelText;

  /// 输入框占位提示。
  final String hintText;

  /// 输入框文本控制器。
  final TextEditingController controller;

  /// 是否为当前数字键盘输入目标。
  final bool selected;

  /// 点击输入框时触发，用于展示并绑定右侧数字键盘。
  final VoidCallback onTap;

  /// 是否隐藏输入内容。
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            labelText,
            style: const TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 10,
              height: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 31,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.none,
              obscureText: obscureText,
              onTap: onTap,
              readOnly: true,
              style: const TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 0,
                ),
                hintStyle: const TextStyle(
                  color: AppTheme.outlineColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(
                    color: selected
                        ? AppTheme.primaryColor
                        : AppTheme.primaryBorderColor,
                    width: selected ? 1.2 : 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(
                    color: AppTheme.primaryColor,
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 登录页左侧气泡。
class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.width});

  /// 气泡宽度，外层插画根据可用空间传入不同尺寸。
  final double width;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _SpeechBubblePainter(),
      child: SizedBox(
        width: width,
        height: 42,
        child: const Center(
          child: Text(
            '•••••••',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}

/// 登录页左侧气泡绘制器。
class _SpeechBubblePainter extends CustomPainter {
  const _SpeechBubblePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppTheme.primaryStrongColor;
    final path = Path()
      ..moveTo(4, 0)
      ..lineTo(size.width - 4, 0)
      ..quadraticBezierTo(size.width, 0, size.width, 4)
      ..lineTo(size.width, size.height - 16)
      ..quadraticBezierTo(
        size.width,
        size.height - 12,
        size.width - 4,
        size.height - 12,
      )
      ..lineTo(size.width - 16, size.height - 12)
      ..lineTo(size.width - 9, size.height)
      ..lineTo(size.width - 28, size.height - 12)
      ..lineTo(4, size.height - 12)
      ..quadraticBezierTo(0, size.height - 12, 0, size.height - 16)
      ..lineTo(0, 4)
      ..quadraticBezierTo(0, 0, 4, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 登录页左侧背景装饰绘制器。
class _AdminIllustrationPainter extends CustomPainter {
  const _AdminIllustrationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final peach = Paint()..color = const Color(0xFFFFE3BD);
    canvas.drawRect(Offset.zero & size, peach);

    canvas.drawCircle(
      Offset(size.width * .46, size.height * .42),
      142,
      Paint()..color = const Color(0xFFF7CDA8).withValues(alpha: .42),
    );
    canvas.drawCircle(
      const Offset(16, 18),
      74,
      Paint()..color = AppTheme.primaryStrongColor.withValues(alpha: .94),
    );
    canvas.drawCircle(
      Offset(size.width - 52, size.height + 4),
      40,
      Paint()..color = AppTheme.primaryLightColor.withValues(alpha: .48),
    );

    final dotPaint = Paint()..color = AppTheme.primaryStrongColor;
    const points = [
      Offset(76, 64),
      Offset(142, 112),
      Offset(92, 248),
      Offset(232, 84),
      Offset(318, 136),
      Offset(388, 58),
      Offset(420, 284),
      Offset(138, 360),
    ];
    for (final point in points) {
      canvas.drawCircle(point, 1.4, dotPaint);
    }

    final linePaint = Paint()
      ..color = AppTheme.primaryLightColor.withValues(alpha: .65)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(112, 300), const Offset(144, 278), linePaint);
    canvas.drawLine(
      Offset(size.width - 116, 64),
      Offset(size.width - 88, 42),
      linePaint,
    );
    canvas.drawLine(
      Offset(size.width - 170, 150),
      Offset(size.width - 136, 128),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 首页通用白色卡片容器。
///
/// 统一提供圆角、边框、阴影以及可选顶部强调色条。
