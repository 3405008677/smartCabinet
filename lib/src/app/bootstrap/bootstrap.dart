import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:smart_cabinet/src/core/logging/app_logger.dart';
import 'package:smart_cabinet/src/core/monitoring/runtime_health_monitor.dart';
import 'package:smart_cabinet/src/app/app.dart';
import 'package:smart_cabinet/src/app/startup/startup_failure_app.dart';
import 'package:smart_cabinet/src/app/startup/startup_manager.dart';
import 'package:smart_cabinet/src/app/startup/startup_task.dart';
import 'package:smart_cabinet/src/app/startup/startup_tasks.dart';

/// 应用启动引导函数。
///
/// 这个函数负责完成 Flutter 应用真正显示界面前的基础准备工作：
/// - 初始化 Flutter 引擎绑定；
/// - 接管 Flutter 框架层异常；
/// - 接管平台层未捕获异常；
/// - 创建 Riverpod 的 [ProviderScope]；
/// - 最后调用 [runApp] 显示根组件 [SmartCabinetApp]。
Future<void> bootstrap() async {
  /// [runZonedGuarded] 可以捕获当前 Zone 内未被 try/catch 处理的异步异常。
  ///
  /// 简单理解：它是应用最外层的“安全网”，防止异步异常悄悄丢失。
  runZonedGuarded(
    () async {
      /// 确保 Flutter 框架初始化完成。
      ///
      /// 如果启动阶段需要使用插件、平台通道或其它依赖 Flutter 引擎的能力，
      /// 通常都要先调用这一句。
      WidgetsFlutterBinding.ensureInitialized();
      RuntimeHealthMonitor.instance.start();

      /// 捕获 Flutter 框架构建、布局、绘制过程中的错误。
      FlutterError.onError = (FlutterErrorDetails details) {
        AppLogger.error(
          'Flutter framework error',
          details.exception,
          details.stack,
        );

        /// 保留 Flutter 默认的错误展示行为，方便调试时在控制台看到红色错误信息。
        FlutterError.presentError(details);
      };

      /// 捕获平台层或引擎层抛出的未处理错误。
      ///
      /// 返回 true 表示这个错误已经被应用处理过了，Flutter 不需要继续抛出。
      PlatformDispatcher.instance.onError =
          (Object error, StackTrace stackTrace) {
            AppLogger.error('Uncaught platform error', error, stackTrace);
            return true;
          };

      final providerContainer = ProviderContainer();

      try {
        await StartupManager(
          tasks: [
            CacheLocalStoreStartupTask(providerContainer),
            const LoadCamerasStartupTask(),
            const ConnectMqttStartupTask(),
          ],
        ).start();
      } on StartupFailedException catch (error, stackTrace) {
        AppLogger.error('Application startup failed', error, stackTrace);
        runApp(StartupFailureApp(result: error.result));
        return;
      }

      /// 启动应用界面。
      ///
      /// [ProviderScope] 是 Riverpod 的根容器，后续所有 Provider 都需要在它下面使用。
      runApp(
        UncontrolledProviderScope(
          container: providerContainer,
          child: const SmartCabinetApp(),
        ),
      );
    },
    (Object error, StackTrace stackTrace) {
      /// 捕获 [runZonedGuarded] 保护范围内遗漏的异步异常。
      AppLogger.error('Uncaught zone error', error, stackTrace);
    },
  );
}
