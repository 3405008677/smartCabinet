import 'package:flutter_test/flutter_test.dart';

import 'package:smart_cabinet/src/core/config/app_config.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/domain/entities/terminal_upgrade.dart';

void main() {
  test('uses the configured upgrade server for new and legacy settings', () {
    final fresh = TerminalUpgradeSettings.fromJson(
      const <String, Object?>{},
      defaultHost: AppConfig.terminalUpgradeHost,
      defaultPort: AppConfig.terminalUpgradePort,
    );
    final legacy = TerminalUpgradeSettings.fromJson(
      <String, Object?>{'host': '', 'port': 0},
      defaultHost: AppConfig.terminalUpgradeHost,
      defaultPort: AppConfig.terminalUpgradePort,
    );

    expect(fresh.host, AppConfig.terminalUpgradeHost);
    expect(fresh.port, AppConfig.terminalUpgradePort);
    expect(legacy.host, AppConfig.terminalUpgradeHost);
    expect(legacy.port, AppConfig.terminalUpgradePort);
    expect(AppConfig.terminalUpgradeHost, '47.107.40.88');
    expect(AppConfig.terminalUpgradePort, 21251);
    expect(AppConfig.current.afrrDeviceImei, '867282037661259');
    expect(AppConfig.current.terminalUpgradeDataProtocolIp, '47.107.40.88');
  });

  test('keeps a non-empty endpoint configured at the site', () {
    final settings = TerminalUpgradeSettings.fromJson(<String, Object?>{
      'host': '10.0.0.8',
      'port': 8001,
    });

    expect(settings.host, '10.0.0.8');
    expect(settings.port, 8001);
  });

  test('ignores and removes legacy persisted STUM login identity fields', () {
    final settings = TerminalUpgradeSettings.fromJson(const <String, Object?>{
      'moduleImei': '111111111111111',
      'dataProtocolIp': '10.0.0.8',
      'chipId': 'legacy-chip',
    });

    expect(settings.toJson().containsKey('moduleImei'), isFalse);
    expect(settings.toJson().containsKey('dataProtocolIp'), isFalse);
    expect(settings.toJson().containsKey('chipId'), isFalse);
  });
}
