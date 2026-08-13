import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:smart_cabinet/src/core/config/app_config.dart';
import 'package:smart_cabinet/src/core/device/device_info_service.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/data/repositories/terminal_upgrade_repository_impl.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/domain/repositories/terminal_upgrade_repository.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/presentation/terminal_upgrade_offer_notifier.dart';

/// 应用进程内唯一的终端升级 Repository。
///
/// Provider 本身不会主动联网；启动任务或管理员页面显式调用 start 后才建立 Socket，
/// 因此普通 Widget 测试创建 ProviderScope 时不会误连现场服务。
final terminalUpgradeRepositoryProvider = Provider<TerminalUpgradeRepository>((
  ref,
) {
  // IM 与 AFRR 共用 DEVICE_IMEI，确保 T01.IM 能匹配后台绑定的终端；DP 固定
  // 读取构建配置。CD 延迟到 start 时读取当前 Android ID。
  final repository = TerminalUpgradeRepositoryImpl(
    moduleId: AppConfig.current.afrrDeviceImei,
    dataProtocolIp: AppConfig.current.terminalUpgradeDataProtocolIp,
    versionDate: AppConfig.current.terminalUpgradeVersionDate,
    uniqueDeviceIdLoader: const DeviceInfoService().fetchUniqueDeviceId,
    onOfferAvailable: globalTerminalUpgradeOfferNotifier.show,
  );
  final offerLifecycleSubscription = repository.states.listen((snapshot) {
    if (snapshot.offer == null) {
      // 停止、重配、失败清理或安装终态都会使旧 offer 失效；全局提示必须同步
      // 消失，不能继续把管理员引向一份 Repository 已经拒绝的 URL。
      globalTerminalUpgradeOfferNotifier.dismiss();
    }
  });
  ref.onDispose(() {
    unawaited(offerLifecycleSubscription.cancel());
    unawaited(repository.dispose());
  });
  return repository;
});
