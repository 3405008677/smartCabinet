import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:smart_cabinet/src/core/logging/app_logger.dart';
import 'package:smart_cabinet/src/core/monitoring/runtime_health_monitor.dart';
import 'package:smart_cabinet/src/app/app.dart';
import 'package:smart_cabinet/src/app/localization/app_localizations.dart';
import 'package:smart_cabinet/src/app/startup/afrr_startup_failure_app.dart';
import 'package:smart_cabinet/src/app/startup/startup_failure_app.dart';
import 'package:smart_cabinet/src/app/startup/startup_manager.dart';
import 'package:smart_cabinet/src/app/startup/startup_task.dart';
import 'package:smart_cabinet/src/app/startup/startup_tasks.dart';
import 'package:smart_cabinet/src/core/storage/app_local_store_provider.dart';

/// 应用启动引导函数。
///
/// 这个函数负责完成 Flutter 应用真正显示界面前的基础准备工作：
/// - 初始化 Flutter 引擎绑定；
/// - 接管 Flutter 框架层异常；
/// - 接管平台层未捕获异常；
/// - 创建 Riverpod 的 [ProviderScope]；
/// - 最后调用 [runApp] 显示根组件 [SmartCabinetApp]。
Future<void> bootstrap() {
  // 统一向入口调用方报告“本次启动尝试已经结束”，包括 Zone 捕获到异常的路径。
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

/// 在 [bootstrap] 建立的异常 Zone 内重新执行启动流程。
///
/// 失败页必须调用此函数，不能再嵌套新的受保护 Zone；Flutter 要求绑定初始化与
/// [runApp] 处于同一个 Zone，否则重试时会触发 Zone 不一致错误。
Future<void> retryBootstrap() => _bootstrapInCurrentZone();

/// 执行一次完整启动尝试，并根据关键任务结果选择正式应用或失败页。
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
    // 返回 true 表示异常已经记录，避免同一平台异常继续按“未处理”路径传播。
    return true;
  };

  // 成功路径由 UncontrolledProviderScope 持有该容器；启动失败时必须在展示
  // 兜底应用前主动释放，避免重试累积 Provider 资源。
  final providerContainer = ProviderContainer();

  // 在创建正式应用或启动失败页之前恢复用户上次选择的语言，避免首帧先显示
  // 简体中文、随后再切换造成闪烁。存储损坏不应阻止柜机启动，失败时回退简中并留痕。
  appLocaleController.clearPersistence();
  try {
    final store = await providerContainer.read(appLocalStoreProvider.future);
    final state = await store.state();
    appLocaleController.setLanguage(
      AppLanguage.fromCode(state.languageCode),
      persist: false,
    );
    appLocaleController.bindPersistence(
      persistLanguage: (language) async {
        await store.update(
          (current) => current.copyWith(languageCode: language.code),
        );
      },
      onError: (error, stackTrace) {
        AppLogger.error(
          'Failed to persist selected language',
          error,
          stackTrace,
        );
      },
    );
  } catch (error, stackTrace) {
    AppLogger.error('Failed to restore saved language', error, stackTrace);
    appLocaleController.setLanguage(
      AppLanguage.simplifiedChinese,
      persist: false,
    );
  }

  try {
    await StartupManager(
      tasks: [
        RestoreTerminalUpgradeInstallSafetyTask(providerContainer),
        const ConnectAfrrAppStartupTask(),
        const LoadCamerasStartupTask(),
      ],
    ).start();
  } on StartupFailedException catch (error, stackTrace) {
    AppLogger.error('Application startup failed', error, stackTrace);
    providerContainer.dispose();
    final failure = error.result.firstRequiredFailure;
    runApp(
      failure?.name == '登录监管服务'
          ? AfrrStartupFailureApp(result: error.result)
          : StartupFailureApp(result: error.result),
    );
    return;
  }

  runApp(
    UncontrolledProviderScope(
      container: providerContainer,
      child: const SmartCabinetApp(),
    ),
  );

  // 活动安装的柜门维护租约已在首帧前恢复；这里只调度非关键缓存和网络能力，
  // 避免慢速磁盘或不可用服务端将终端长期阻塞在启动画面。
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      StartupManager(
        tasks: [
          CacheLocalStoreStartupTask(providerContainer),
          StartTerminalUpgradeMonitorTask(providerContainer),
        ],
      ).start(),
    );
    unawaited(StartupManager(tasks: const [ConnectMqttStartupTask()]).start());
  });
}
