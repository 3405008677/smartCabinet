import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_cabinet/src/core/device/app_version_service.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/data/datasources/method_channel_terminal_upgrade_device.dart';

/// 终端升级 MethodChannel 数据源的方法、参数和结果映射测试。
void main() {
  const upgradeChannel = MethodChannel('smart_cabinet/upgrade');
  late MethodChannelTerminalUpgradeDevice device;

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    device = MethodChannelTerminalUpgradeDevice(
      appVersionService: AppVersionService(),
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(upgradeChannel, null);
  });

  test('reads the Android app version', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(upgradeChannel, (call) async {
          expect(call.method, 'getAppVersion');
          return <String, Object?>{'versionName': '1.2.3', 'versionCode': 23};
        });

    final version = await device.getAppVersion();

    expect(version.name, '1.2.3');
    expect(version.code, 23);
  });

  test('reads the persisted PackageInstaller status', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(upgradeChannel, (call) async {
          expect(call.method, 'getInstallStatus');
          return <String, Object?>{
            'status': 'pending_user_action',
            'message': 'confirmation required',
            'diagnosticCode': 'confirmation_timeout',
            'sessionId': 17,
            'versionName': '1.2.3',
            'silentInstallRequested': true,
            'requiresUserAction': true,
            'confirmationLaunchFailed': false,
          };
        });

    final status = await device.getInstallStatus();

    expect(status.state, 'pending_user_action');
    expect(status.message, 'confirmation required');
    expect(status.diagnosticCode, 'confirmation_timeout');
    expect(status.sessionId, 17);
    expect(status.targetVersion, '1.2.3');
    expect(status.silentInstallRequested, isTrue);
    expect(status.requiresUserAction, isTrue);
    expect(status.confirmationLaunchFailed, isFalse);
  });

  test('submits an APK path and target version', () async {
    MethodCall? capturedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(upgradeChannel, (call) async {
          capturedCall = call;
          return <String, Object?>{'sessionId': 18, 'status': 'submitted'};
        });

    final submission = await device.installApk(
      r'C:\cache\update.apk',
      targetVersion: '1.2.3',
      operationId: 'terminal-upgrade:1:1',
    );

    expect(capturedCall?.method, 'installApk');
    expect(capturedCall?.arguments, <String, Object?>{
      'apkPath': r'C:\cache\update.apk',
      'targetVersion': '1.2.3',
      'operationId': 'terminal-upgrade:1:1',
    });
    expect(submission.sessionId, 18);
    expect(submission.state, 'submitted');
  });

  test('rejects an incomplete native install response', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(upgradeChannel, (call) async {
          return <String, Object?>{'status': 'submitted'};
        });

    expect(
      () => device.installApk(
        'update.apk',
        targetVersion: '1.2.3',
        operationId: 'terminal-upgrade:1:1',
      ),
      throwsStateError,
    );
  });

  test(
    'rejects null, unknown and incomplete active install statuses',
    () async {
      for (final response in <Map<String, Object?>?>[
        null,
        <String, Object?>{'status': 'unknown'},
        <String, Object?>{'status': 'submitted'},
      ]) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(upgradeChannel, (call) async => response);

        await expectLater(device.getInstallStatus(), throwsStateError);
      }
    },
  );

  test('forwards pre-commit cancellation with the same operation ID', () async {
    MethodCall? capturedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(upgradeChannel, (call) async {
          capturedCall = call;
          return true;
        });

    expect(await device.cancelInstall('terminal-upgrade:1:1'), isTrue);
    expect(capturedCall?.method, 'cancelInstall');
    expect(capturedCall?.arguments, <String, Object?>{
      'operationId': 'terminal-upgrade:1:1',
    });
  });
}
