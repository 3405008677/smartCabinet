import 'package:flutter/material.dart';

import 'package:smart_cabinet/src/app/routing/app_routes.dart';

import 'package:smart_cabinet/src/features/admin/presentation/pages/admin_console_page.dart';
import 'package:smart_cabinet/src/features/admin/presentation/pages/admin_communication_log_page.dart';
import 'package:smart_cabinet/src/features/admin/presentation/pages/admin_verification_page.dart';
import 'package:smart_cabinet/src/features/home/presentation/pages/home_page.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_account.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_identity_navigation.dart';
import 'package:smart_cabinet/src/features/identity_verification/presentation/pages/identity_enrollment_page.dart';
import 'package:smart_cabinet/src/features/identity_verification/presentation/pages/operator_verification_page.dart';
import 'package:smart_cabinet/src/features/task_center/presentation/pages/task_center_page.dart';
import 'package:smart_cabinet/src/features/task_center/presentation/pages/task_execution_page.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/presentation/pages/admin_terminal_upgrade_page.dart';

/// 应用路由生成器。
///
/// [MaterialApp.onGenerateRoute] 会把用户要跳转的路由信息传进来，
/// 这里根据 [RouteSettings.name] 返回对应的页面路由。
///
/// 路由层只负责入口参数和三项身份因子的第一层校验；Repository 仍需在每次
/// 业务读写时重新执行身份、机构、任务和箱格授权，不能把路由通过视为最终授权。
class AppRouter {
  const AppRouter._();

  /// 根据路由设置创建页面。
  ///
  /// [settings] 中包含目标路由名称和可选参数。受保护路由的参数类型或身份因子
  /// 不满足约束时会落入首页，避免命名路由或深链直接打开任务页面。
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final page = switch (settings.name) {
      /// 新首页。settings.name 为 null 时也回到新首页，提升容错性。
      AppRoutes.home || null => const SmartCabinetHomePage(),

      /// 操作员人脸、指纹、NFC 三项全部认证页。
      AppRoutes.operatorVerification => OperatorVerificationPage(
        arguments: settings.arguments is OperatorVerificationArguments
            ? settings.arguments! as OperatorVerificationArguments
            : const OperatorVerificationArguments(),
      ),

      /// 账号资料缺失或异常时的人脸、指纹录入页。
      AppRoutes.identityEnrollment
          when settings.arguments is IdentityEnrollmentArguments =>
        IdentityEnrollmentPage(
          arguments: settings.arguments! as IdentityEnrollmentArguments,
        ),

      /// 身份认证通过后的任务工作台。
      AppRoutes.taskCenter
          when settings.arguments is TaskCenterArguments &&
              (settings.arguments! as TaskCenterArguments)
                  .account
                  .verifiedFactors
                  .containsAll(requiredOperatorIdentityFactors) =>
        TaskCenterPage(arguments: settings.arguments! as TaskCenterArguments),

      /// 存证、取证、借证、还证和盘点共用的任务执行页。
      AppRoutes.taskExecution
          when settings.arguments is TaskExecutionArguments &&
              (settings.arguments! as TaskExecutionArguments)
                  .account
                  .verifiedFactors
                  .containsAll(requiredOperatorIdentityFactors) =>
        TaskExecutionPage(
          arguments: settings.arguments! as TaskExecutionArguments,
        ),

      /// 管理员身份校验页。
      AppRoutes.adminVerification => AdminVerificationPage(
        postVerificationRoute:
            settings.arguments == AppRoutes.adminTerminalUpgrade
            ? AppRoutes.adminTerminalUpgrade
            : AppRoutes.adminConsole,
      ),

      /// 管理员控制台页。
      AppRoutes.adminConsole => const AdminConsolePage(),

      /// 管理员终端升级配置与执行页。
      AppRoutes.adminTerminalUpgrade => const AdminTerminalUpgradePage(),

      /// 管理员查看服务器与硬件通讯记录的页面。
      AppRoutes.adminCommunicationLog => const AdminCommunicationLogPage(),

      /// 未匹配到的路由统一回到新首页，避免应用打开空白页。
      _ => const SmartCabinetHomePage(),
    };

    return _fadeSlideRoute(settings: settings, page: page);
  }

  /// 创建带过渡动画的页面路由。
  ///
  /// 所有页面跳转都会有轻微淡入和上滑效果，避免页面切换太生硬。
  static PageRouteBuilder<void> _fadeSlideRoute({
    required RouteSettings settings,
    required Widget page,
  }) {
    return PageRouteBuilder<void>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 360),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.035, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}
