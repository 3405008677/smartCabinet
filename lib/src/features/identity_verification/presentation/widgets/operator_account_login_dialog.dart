import 'package:flutter/material.dart';

import 'package:smart_cabinet/src/app/localization/app_localizations.dart';
import 'package:smart_cabinet/src/app/theme/app_theme.dart';
import 'package:smart_cabinet/src/features/identity_verification/data/repositories/operator_identity_repository_impl.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_account.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/repositories/operator_identity_repository.dart';

/// 打开普通操作员账号登录弹窗，并在登录成功后返回账号。
Future<OperatorAccount?> showOperatorAccountLoginDialog(
  BuildContext context, {
  OperatorIdentityRepository? repository,
}) {
  return showDialog<OperatorAccount>(
    context: context,
    builder: (context) => OperatorAccountLoginDialog(
      repository: repository ?? operatorIdentityRepository,
    ),
  );
}

/// 普通操作员双栏账号登录弹窗。
///
/// 视觉延续管理员登录窗的插画/数字键盘与表单双栏布局，但登录数据完全依赖
/// 普通操作员身份仓库，不引用管理员模块。
class OperatorAccountLoginDialog extends StatefulWidget {
  /// 创建普通操作员账号登录弹窗。
  const OperatorAccountLoginDialog({required this.repository, super.key});

  /// 普通操作员身份仓库。
  final OperatorIdentityRepository repository;

  @override
  State<OperatorAccountLoginDialog> createState() =>
      _OperatorAccountLoginDialogState();
}

/// 普通操作员账号登录弹窗状态。
class _OperatorAccountLoginDialogState
    extends State<OperatorAccountLoginDialog> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  _OperatorLoginField? _activeField;
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 切换当前数字键盘输入目标。
  void _selectField(_OperatorLoginField field) {
    setState(() => _activeField = field);
  }

  /// 向当前输入框追加一个数字。
  void _appendDigit(String digit) {
    final controller = _activeController;
    if (controller == null || controller.text.length >= 24) {
      return;
    }
    controller.text += digit;
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
  }

  /// 删除当前输入框最后一个数字。
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

  /// 清空当前输入框。
  void _clearInput() {
    _activeController?.clear();
  }

  /// 提交普通操作员账号密码并返回登录结果。
  Future<void> _submit() async {
    if (_loading) {
      return;
    }
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = context.l10n.t('operatorLoginRequired', '请输入账号和密码');
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final account = await widget.repository.login(
        username: username,
        password: password,
      );
      if (!mounted) {
        return;
      }
      if (account == null) {
        setState(() {
          _loading = false;
          _errorMessage = context.l10n.t(
            'operatorLoginDenied',
            '账号或密码错误，请重新输入',
          );
        });
        return;
      }
      Navigator.of(context).pop(account);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorMessage = context.l10n.t('operatorLoginFailed', '账号登录失败，请稍后重试');
      });
    }
  }

  TextEditingController? get _activeController => switch (_activeField) {
    _OperatorLoginField.username => _usernameController,
    _OperatorLoginField.password => _passwordController,
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
                child: _OperatorLoginVisualPanel(
                  activeField: _activeField,
                  onDigit: _appendDigit,
                  onDelete: _deleteDigit,
                  onClear: _clearInput,
                  onBack: () => setState(() => _activeField = null),
                ),
              ),
              SizedBox(
                width: 344,
                child: _OperatorLoginForm(
                  usernameController: _usernameController,
                  passwordController: _passwordController,
                  activeField: _activeField,
                  loading: _loading,
                  errorMessage: _errorMessage,
                  onFieldSelected: _selectField,
                  onSubmit: _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 账号登录数字键盘当前绑定的输入字段。
enum _OperatorLoginField { username, password }

/// 登录弹窗左侧插画与数字键盘切换区。
class _OperatorLoginVisualPanel extends StatelessWidget {
  /// 创建登录弹窗左侧视觉区。
  const _OperatorLoginVisualPanel({
    required this.activeField,
    required this.onDigit,
    required this.onDelete,
    required this.onClear,
    required this.onBack,
  });

  final _OperatorLoginField? activeField;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback onClear;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      child: activeField == null
          ? const _OperatorLoginIllustration(
              key: ValueKey('operator_account_login_illustration'),
            )
          : _OperatorNumberKeyboard(
              key: const ValueKey('operator_account_login_keyboard'),
              activeField: activeField!,
              onDigit: onDigit,
              onDelete: onDelete,
              onClear: onClear,
              onBack: onBack,
            ),
    );
  }
}

/// 登录弹窗左侧的普通操作员插画提示。
class _OperatorLoginIllustration extends StatelessWidget {
  /// 创建普通操作员登录插画。
  const _OperatorLoginIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE8C8), Color(0xFFFFD59C)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 118,
                height: 118,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .82),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: .2),
                    width: 3,
                  ),
                ),
                child: const Icon(
                  Icons.badge_outlined,
                  color: AppTheme.primaryColor,
                  size: 58,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.t('operatorLoginVisualTitle', '操作员账号登录'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.primaryStrongColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.t(
                  'operatorLoginVisualDescription',
                  '确认账号后继续完成人脸、指纹与 NFC 三项身份认证',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.primaryStrongColor,
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.t('operatorLoginDemoHint', '演示账号 666666 / 666666'),
                style: TextStyle(
                  color: AppTheme.primaryStrongColor.withValues(alpha: .68),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 登录弹窗右侧账号密码表单。
class _OperatorLoginForm extends StatelessWidget {
  /// 创建普通操作员登录表单。
  const _OperatorLoginForm({
    required this.usernameController,
    required this.passwordController,
    required this.activeField,
    required this.loading,
    required this.errorMessage,
    required this.onFieldSelected,
    required this.onSubmit,
  });

  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final _OperatorLoginField? activeField;
  final bool loading;
  final String? errorMessage;
  final ValueChanged<_OperatorLoginField> onFieldSelected;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(42, 38, 42, 34),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: AppTheme.primaryColor,
            size: 42,
          ),
          const SizedBox(height: 14),
          Text(
            l10n.t('operatorLoginTitle', '账号登录'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 24),
          _OperatorLoginTextField(
            key: const ValueKey('operator_account_username'),
            controller: usernameController,
            label: l10n.t('operatorUsernameLabel', '账号'),
            selected: activeField == _OperatorLoginField.username,
            onTap: () => onFieldSelected(_OperatorLoginField.username),
          ),
          const SizedBox(height: 14),
          _OperatorLoginTextField(
            key: const ValueKey('operator_account_password'),
            controller: passwordController,
            label: l10n.t('operatorPasswordLabel', '密码'),
            selected: activeField == _OperatorLoginField.password,
            obscureText: true,
            onTap: () => onFieldSelected(_OperatorLoginField.password),
          ),
          const SizedBox(height: 14),
          if (errorMessage != null) ...[
            Text(
              errorMessage!,
              key: const ValueKey('operator_account_login_error'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFB91C1C),
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            height: 52,
            child: ElevatedButton(
              key: const ValueKey('operator_account_login_submit'),
              onPressed: loading ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(l10n.t('operatorLoginAction', '登录')),
            ),
          ),
        ],
      ),
    );
  }
}

/// 普通操作员登录使用的只读数字输入框。
class _OperatorLoginTextField extends StatelessWidget {
  /// 创建账号或密码输入框。
  const _OperatorLoginTextField({
    required this.controller,
    required this.label,
    required this.selected,
    required this.onTap,
    this.obscureText = false,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: true,
      obscureText: obscureText,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: selected
            ? AppTheme.primaryColor.withValues(alpha: .06)
            : AppTheme.surfaceColor,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: selected
                ? AppTheme.primaryColor
                : AppTheme.primaryBorderColor,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
      ),
    );
  }
}

/// 普通操作员登录左侧数字键盘。
class _OperatorNumberKeyboard extends StatelessWidget {
  /// 创建普通操作员登录数字键盘。
  const _OperatorNumberKeyboard({
    required this.activeField,
    required this.onDigit,
    required this.onDelete,
    required this.onClear,
    required this.onBack,
    super.key,
  });

  final _OperatorLoginField activeField;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback onClear;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = activeField == _OperatorLoginField.username
        ? l10n.t('operatorInputUsername', '输入账号')
        : l10n.t('operatorInputPassword', '输入密码');
    return Container(
      color: const Color(0xFFFFDEAF),
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 24),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                key: const ValueKey('operator_keyboard_back'),
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                color: AppTheme.primaryStrongColor,
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.primaryStrongColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              childAspectRatio: 1.65,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                for (final digit in const [
                  '1',
                  '2',
                  '3',
                  '4',
                  '5',
                  '6',
                  '7',
                  '8',
                  '9',
                ])
                  _OperatorKeyboardButton(
                    key: ValueKey('operator_keyboard_$digit'),
                    text: digit,
                    onPressed: () => onDigit(digit),
                  ),
                _OperatorKeyboardButton(
                  key: const ValueKey('operator_keyboard_clear'),
                  text: l10n.t('operatorKeyboardClear', '清空'),
                  onPressed: onClear,
                  secondary: true,
                ),
                _OperatorKeyboardButton(
                  key: const ValueKey('operator_keyboard_0'),
                  text: '0',
                  onPressed: () => onDigit('0'),
                ),
                _OperatorKeyboardButton(
                  key: const ValueKey('operator_keyboard_delete'),
                  text: l10n.t('operatorKeyboardDelete', '删除'),
                  onPressed: onDelete,
                  secondary: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 普通操作员数字键盘的单个按键。
class _OperatorKeyboardButton extends StatelessWidget {
  /// 创建数字键盘按键。
  const _OperatorKeyboardButton({
    required this.text,
    required this.onPressed,
    this.secondary = false,
    super.key,
  });

  final String text;
  final VoidCallback onPressed;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: secondary ? const Color(0xFFFFF3E3) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: secondary
                  ? AppTheme.primaryStrongColor
                  : AppTheme.textPrimaryColor,
              fontSize: secondary ? 13 : 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
