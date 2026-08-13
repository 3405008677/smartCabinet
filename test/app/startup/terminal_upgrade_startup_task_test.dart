import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_cabinet/src/app/startup/startup_tasks.dart';
import 'package:smart_cabinet/src/core/config/app_config.dart';
import 'package:smart_cabinet/src/core/device/cabinet_door_guard.dart';
import 'package:smart_cabinet/src/core/storage/app_local_store.dart';
import 'package:smart_cabinet/src/core/storage/app_local_store_provider.dart';
import 'package:smart_cabinet/src/core/storage/key_value_storage.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/data/datasources/terminal_upgrade_device.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/data/repositories/terminal_upgrade_repository_impl.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/domain/entities/terminal_upgrade.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/domain/repositories/terminal_upgrade_repository.dart';

void main() {
  test(
    'restores an active native install lease before optional monitoring',
    () async {
      final container = ProviderContainer();
      final doorGuard = CabinetDoorGuard();
      final device = _PendingInstallTerminalUpgradeDevice();
      final repository = TerminalUpgradeRepositoryImpl(
        moduleId: AppConfig.current.afrrDeviceImei,
        dataProtocolIp: AppConfig.current.terminalUpgradeDataProtocolIp,
        uniqueDeviceIdLoader: () async => 'AABBCIID33',
        device: device,
        doorGuard: doorGuard,
        installStatusPollInterval: const Duration(hours: 1),
      );
      addTearDown(container.dispose);
      addTearDown(repository.dispose);

      final task = RestoreTerminalUpgradeInstallSafetyTask(
        container,
        repository: repository,
      );
      await task.run();

      expect(task.required, isTrue);
      expect(
        task.order,
        lessThan(
          StartTerminalUpgradeMonitorTask(
            container,
            repository: repository,
          ).order,
        ),
      );
      expect(repository.current.phase, TerminalUpgradePhase.awaitingRestart);
      expect(doorGuard.maintenanceOperationId, 'terminal-upgrade:restore:42');

      // 明确终态才能解除首帧前恢复的维护租约。
      device.status = const TerminalInstallStatus(
        state: 'success',
        sessionId: 42,
        targetVersion: '2.0.0',
      );
      await repository.refreshInstallStatus();
      expect(doorGuard.maintenanceOperationId, isNull);
    },
  );

  test('does not connect when upgrade monitoring is disabled', () async {
    final store = AppLocalStore(_MemoryKeyValueStorage());
    final repository = _RecordingTerminalUpgradeRepository();
    final container = ProviderContainer(
      overrides: [appLocalStoreProvider.overrideWith((ref) async => store)],
    );
    addTearDown(container.dispose);

    await StartTerminalUpgradeMonitorTask(
      container,
      repository: repository,
    ).run();

    expect(repository.startedWith, isNull);
  });

  test('starts the repository with the persisted enabled settings', () async {
    final settings = TerminalUpgradeSettings(
      enabled: true,
      host: '10.0.0.8',
      port: 8001,
      terminalId: '12345678901',
      packageTag: 'APP',
    );
    final store = AppLocalStore(_MemoryKeyValueStorage());
    await store.setState(
      AppLocalState(
        upgrade: <String, Object?>{
          ...settings.toJson(),
          // 模拟旧版本遗留值，启动时必须由 AppConfig 覆盖。
          'moduleImei': '111111111111111',
        },
      ),
    );
    final repository = _RecordingTerminalUpgradeRepository();
    final container = ProviderContainer(
      overrides: [appLocalStoreProvider.overrideWith((ref) async => store)],
    );
    addTearDown(container.dispose);

    await StartTerminalUpgradeMonitorTask(
      container,
      repository: repository,
    ).run();

    expect(repository.startedWith, settings);
  });
}

final class _PendingInstallTerminalUpgradeDevice
    implements TerminalUpgradeDevice {
  TerminalInstallStatus status = const TerminalInstallStatus(
    state: 'submitted',
    sessionId: 42,
    targetVersion: '2.0.0',
  );

  @override
  Future<TerminalAppVersion> getAppVersion() async {
    return const TerminalAppVersion(name: '1.0.0', code: 1);
  }

  @override
  Future<TerminalInstallStatus> getInstallStatus() async => status;

  @override
  Future<TerminalInstallSubmission> installApk(
    String apkPath, {
    required String targetVersion,
    required String operationId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<bool> cancelInstall(String operationId) async => false;
}

final class _RecordingTerminalUpgradeRepository
    implements TerminalUpgradeRepository {
  TerminalUpgradeSettings? startedWith;

  @override
  TerminalUpgradeSnapshot get current => const TerminalUpgradeSnapshot();

  @override
  Stream<TerminalUpgradeSnapshot> get states => const Stream.empty();

  @override
  Future<void> start(TerminalUpgradeSettings settings) async {
    startedWith = settings;
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<void> installAvailableUpdate({
    required TerminalUpgradeOffer confirmedOffer,
    required bool administratorConfirmed,
  }) async {}

  @override
  Future<void> refreshInstallStatus() async {}

  @override
  Future<void> requestCheck() async {}

  @override
  Future<void> stop() async {}
}

final class _MemoryKeyValueStorage implements KeyValueStorage {
  final Map<String, Object?> _values = <String, Object?>{};

  @override
  Future<Set<String>> keys() async => _values.keys.toSet();

  @override
  Future<Map<String, Object?>> readAll() async => Map.unmodifiable(_values);

  @override
  Future<String?> readString(String key) async => _values[key] as String?;

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> writeString(String key, String value) async {
    _values[key] = value;
  }
}
