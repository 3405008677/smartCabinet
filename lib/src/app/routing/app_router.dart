import 'package:flutter/material.dart';

import '../../views/business/Admin/Console/index.dart';
import '../../views/business/Admin/Verification/index.dart';
import '../../views/business/FlightInspection/Task/index.dart';
import '../../views/business/FlightInspection/Verification/index.dart';
import '../../views/business/Home/index.dart';
import '../../views/business/Storage/CabinetDoorInfo/index.dart';
import '../../views/business/Storage/DropoffConfirmOpening/index.dart';
import '../../views/business/Storage/DropoffFileVerification/index.dart';
import '../../views/business/Storage/DropoffOpenCabinet/index.dart';
import '../../views/business/Storage/DropoffPersonVerification/index.dart';
import '../../views/business/Storage/DropoffSuccess/index.dart';
import '../../views/business/Storage/FoundationHome/index.dart';
import '../../views/business/Storage/OpenCabinetDoor/index.dart';
import '../../views/business/Storage/PickupVerification/index.dart';
import '../../views/business/Storage/VerificationLoading/index.dart';

/// 应用内所有路由名称的集中定义。
///
/// 使用常量统一管理路由路径，可以避免在多个地方手写字符串导致拼写错误。
class AppRoutes {
  const AppRoutes._();

  /// 新首页路由。
  static const String home = '/';

  /// 旧版取/放件入口首页路由。
  static const String foundationHome = '/foundation-home';

  /// 取件身份验证页路由。
  static const String pickupVerification = '/pickup/verification';

  /// 安全认证加载页路由。
  static const String verificationLoading = '/pickup/verification-loading';

  /// 柜门信息页路由。
  static const String cabinetDoorInfo = '/pickup/cabinet-door-info';

  /// 打开柜门/取件成功页路由。
  static const String openCabinetDoor = '/pickup/open-cabinet-door';

  /// 放件人员认证页路由。
  static const String dropoffPersonVerification =
      '/dropoff/person-verification';

  /// 放件文件认证页路由。
  static const String dropoffFileVerification = '/dropoff/file-verification';

  /// 放件信息确认倒计时页路由。
  static const String dropoffConfirmOpening = '/dropoff/confirm-opening';

  /// 放件柜门打开页路由。
  static const String dropoffOpenCabinet = '/dropoff/open-cabinet';

  /// 放件成功页路由。
  static const String dropoffSuccess = '/dropoff/success';

  /// 飞检人员认证页路由。
  static const String flightInspectionVerification =
      '/flight-inspection/verification';

  /// 飞检柜门任务页路由。
  static const String flightInspectionTasks = '/flight-inspection/tasks';

  /// 管理员身份校验页路由。
  static const String adminVerification = '/admin/verification';

  /// 管理员控制台页路由。
  static const String adminConsole = '/admin/console';
}

/// 应用路由生成器。
///
/// [MaterialApp.onGenerateRoute] 会把用户要跳转的路由信息传进来，
/// 这里根据 [RouteSettings.name] 返回对应的页面路由。
class AppRouter {
  const AppRouter._();

  /// 根据路由设置创建页面。
  ///
  /// [settings] 中包含目标路由名称和可选参数。
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final page = switch (settings.name) {
      /// 新首页。settings.name 为 null 时也回到新首页，提升容错性。
      AppRoutes.home || null => const SmartCabinetHomePage(),

      /// 旧版取/放件入口首页。
      AppRoutes.foundationHome => const FoundationHomePage(),

      /// 取件验证页。
      AppRoutes.pickupVerification => const PickupVerificationPage(),

      /// 安全认证加载页。
      AppRoutes.verificationLoading => const VerificationLoadingPage(),

      /// 柜门信息页。
      AppRoutes.cabinetDoorInfo => const CabinetDoorInfoPage(),

      /// 打开柜门/取件成功页。
      AppRoutes.openCabinetDoor => const OpenCabinetDoorPage(),

      /// 放件人员认证页。
      AppRoutes.dropoffPersonVerification =>
        const DropoffPersonVerificationPage(),

      /// 放件文件认证页。
      AppRoutes.dropoffFileVerification => const DropoffFileVerificationPage(),

      /// 放件信息确认倒计时页。
      AppRoutes.dropoffConfirmOpening => const DropoffConfirmOpeningPage(),

      /// 放件柜门打开页。
      AppRoutes.dropoffOpenCabinet => const DropoffOpenCabinetPage(),

      /// 放件成功页。
      AppRoutes.dropoffSuccess => const DropoffSuccessPage(),

      /// 飞检人员认证页。
      AppRoutes.flightInspectionVerification =>
        const FlightInspectionVerificationPage(),

      /// 飞检柜门任务页。
      AppRoutes.flightInspectionTasks => const FlightInspectionTaskPage(),

      /// 管理员身份校验页。
      AppRoutes.adminVerification => const AdminVerificationPage(),

      /// 管理员控制台页。
      AppRoutes.adminConsole => const AdminConsolePage(),

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
