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
Future<void> bootstrap() {
  final completer = Completer<void>();

  /// [runZonedGuarded] 可以捕获当前 Zone 内未被 try/catch 处理的异步异常。
  ///
  /// 简单理解：它是应用最外层的“安全网”，防止异步异常悄悄丢失。
  runZonedGuarded<Future<void>>(
    () async {
      try {
        await retryBootstrap();
      } finally {
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    },
    (Object error, StackTrace stackTrace) {
      /// 捕获 [runZonedGuarded] 保护范围内遗漏的异步异常。
      AppLogger.error('Uncaught zone error', error, stackTrace);
      if (!completer.isCompleted) {
        completer.complete();
      }
    },
  );
  return completer.future;
}

/// Re-runs startup work inside the error Zone installed by [bootstrap].
///
/// The failure UI must call this function instead of nesting another guarded
/// Zone, because Flutter requires binding initialization and [runApp] to use
/// the same Zone.
Future<void> retryBootstrap() => _bootstrapInCurrentZone();

Future<void> _bootstrapInCurrentZone() async {
  WidgetsFlutterBinding.ensureInitialized();
  RuntimeHealthMonitor.instance.start();

  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.error(
      'Flutter framework error',
      details.exception,
      details.stack,
    );
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
    AppLogger.error('Uncaught platform error', error, stackTrace);
    return true;
  };

  final providerContainer = ProviderContainer();

  try {
    await StartupManager(tasks: [const LoadCamerasStartupTask()]).start();
  } on StartupFailedException catch (error, stackTrace) {
    AppLogger.error('Application startup failed', error, stackTrace);
    providerContainer.dispose();
    runApp(StartupFailureApp(result: error.result));
    return;
  }

  runApp(
    UncontrolledProviderScope(
      container: providerContainer,
      child: const SmartCabinetApp(),
    ),
  );

  // Local cache refresh and MQTT are optional. Let the first frame render
  // before doing disk/network work so a slow device or unavailable broker
  // cannot hold the kiosk on its launch screen.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      StartupManager(
        tasks: [CacheLocalStoreStartupTask(providerContainer)],
      ).start(),
    );
    unawaited(StartupManager(tasks: const [ConnectMqttStartupTask()]).start());
  });
}
