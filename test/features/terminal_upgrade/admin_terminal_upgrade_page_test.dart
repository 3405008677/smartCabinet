import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_cabinet/src/app/localization/app_localizations.dart';
import 'package:smart_cabinet/src/app/overlays/terminal_upgrade_offer_overlay.dart';
import 'package:smart_cabinet/src/app/routing/app_router.dart';
import 'package:smart_cabinet/src/app/routing/app_routes.dart';
import 'package:smart_cabinet/src/app/theme/app_theme.dart';
import 'package:smart_cabinet/src/core/config/app_config.dart';
import 'package:smart_cabinet/src/core/device/device_info_service.dart';
import 'package:smart_cabinet/src/core/storage/app_local_store.dart';
import 'package:smart_cabinet/src/core/storage/app_local_store_provider.dart';
import 'package:smart_cabinet/src/core/storage/key_value_storage.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/domain/entities/terminal_upgrade.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/domain/repositories/terminal_upgrade_repository.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/presentation/pages/admin_terminal_upgrade_page.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/presentation/terminal_upgrade_offer_notifier.dart';
import 'package:smart_cabinet/src/features/terminal_upgrade/terminal_upgrade_providers.dart';

void main() {
  setUp(globalTerminalUpgradeOfferNotifier.resetForTesting);
  tearDown(globalTerminalUpgradeOfferNotifier.resetForTesting);

  testWidgets('admin route opens an upgrade page that is disabled by default', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = AppLocalStore(_MemoryKeyValueStorage());
    final repository = _FakeTerminalUpgradeRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLocalStoreProvider.overrideWith((ref) async => store),
          terminalUpgradeRepositoryProvider.overrideWith((ref) => repository),
        ],
        child: AppLocalizationsScope(
          localizations: const AppLocalizations(AppLanguage.simplifiedChinese),
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            initialRoute: AppRoutes.adminTerminalUpgrade,
            onGenerateRoute: AppRouter.onGenerateRoute,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('admin_terminal_upgrade_page')), findsOne);
    expect(find.text('终端升级'), findsOne);
    expect(find.textContaining('只在当前 T03 请求窗口处理 S03'), findsOne);
    expect(find.text(AppConfig.current.afrrDeviceImei), findsOne);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText &&
            widget.data == AppConfig.current.terminalUpgradeDataProtocolIp,
      ),
      findsOne,
    );
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    expect(repository.refreshCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'check saves silently and reports that it is waiting for the server result',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = AppLocalStore(_MemoryKeyValueStorage());
      await store.setState(
        const AppLocalState(
          deviceInfo: <String, Object?>{
            DeviceInfoService.uniqueDeviceIdLabel: 'AABBCIID33',
          },
          upgrade: <String, Object?>{
            'enabled': true,
            'host': AppConfig.terminalUpgradeHost,
            'port': AppConfig.terminalUpgradePort,
            'terminalId': '867282037661259',
            'packageTag': '',
          },
        ),
      );
      final repository = _FakeTerminalUpgradeRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLocalStoreProvider.overrideWith((ref) async => store),
            terminalUpgradeRepositoryProvider.overrideWith((ref) => repository),
          ],
          child: AppLocalizationsScope(
            localizations: const AppLocalizations(
              AppLanguage.simplifiedChinese,
            ),
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              initialRoute: AppRoutes.adminTerminalUpgrade,
              onGenerateRoute: AppRouter.onGenerateRoute,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final checkButton = find.widgetWithText(FilledButton, '检查升级');
      await tester.ensureVisible(checkButton);
      await tester.pumpAndSettle();
      await tester.tap(checkButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repository.requestCheckCount, 1);
      expect(find.text('升级配置已保存'), findsNothing);
      expect(find.text('正在检查新版本，等待服务端结果'), findsOne);
      expect(tester.takeException(), isNull);

      // 消耗轻提示的自动关闭计时器，避免测试结束后遗留异步任务。
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('VE zero is shown as no package instead of proven latest', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = AppLocalStore(_MemoryKeyValueStorage());
    final repository = _FakeTerminalUpgradeRepository(
      snapshot: const TerminalUpgradeSnapshot(
        phase: TerminalUpgradePhase.upToDate,
        message: TerminalUpgradeMessage(
          TerminalUpgradeMessageCode.alreadyLatest,
        ),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLocalStoreProvider.overrideWith((ref) async => store),
          terminalUpgradeRepositoryProvider.overrideWith((ref) => repository),
        ],
        child: AppLocalizationsScope(
          localizations: const AppLocalizations(AppLanguage.simplifiedChinese),
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            initialRoute: AppRoutes.adminTerminalUpgrade,
            onGenerateRoute: AppRouter.onGenerateRoute,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('无可用升级包'), findsOne);
    expect(find.text('服务端当前没有可下发升级包（VE=0）'), findsOne);
    expect(find.textContaining('当前已经是最新版本'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('structured upgrade messages render in all supported languages', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final expectedTexts = <AppLanguage, List<String>>{
      AppLanguage.simplifiedChinese: <String>[
        '发现新版本 2.0.0，请管理员确认安装',
        '升级检查被服务端拒绝：NG3PT',
      ],
      AppLanguage.traditionalChinese: <String>[
        '發現新版本 2.0.0，請管理員確認安裝',
        '升級檢查被服務端拒絕：NG3PT',
      ],
      AppLanguage.english: <String>[
        'Version 2.0.0 is available; administrator confirmation is required',
        'The server rejected the upgrade check: NG3PT',
      ],
      AppLanguage.japanese: <String>[
        '新しいバージョン 2.0.0 があります。管理者がインストールを確認してください',
        'サーバーがアップグレード確認を拒否しました：NG3PT',
      ],
    };

    for (final language in AppLanguage.values) {
      final store = AppLocalStore(_MemoryKeyValueStorage());
      final repository = _FakeTerminalUpgradeRepository(
        snapshot: const TerminalUpgradeSnapshot(
          phase: TerminalUpgradePhase.failed,
          message: TerminalUpgradeMessage(
            TerminalUpgradeMessageCode.updateAvailable,
            arguments: <String, String>{'version': '2.0.0'},
          ),
          errorMessage: TerminalUpgradeMessage(
            TerminalUpgradeMessageCode.serverCheckRejected,
            detail: 'NG3PT',
          ),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLocalStoreProvider.overrideWith((ref) async => store),
            terminalUpgradeRepositoryProvider.overrideWith((ref) => repository),
          ],
          child: AppLocalizationsScope(
            localizations: AppLocalizations(language),
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              initialRoute: AppRoutes.adminTerminalUpgrade,
              onGenerateRoute: AppRouter.onGenerateRoute,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final text in expectedTexts[language]!) {
        expect(find.text(text), findsOne, reason: language.name);
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('administrator cancel does not install and confirm binds offer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final offer = TerminalUpgradeOffer(
      targetVersion: '2.0.0',
      downloadUrl: Uri.parse('https://updates.example.com/app.apk'),
      md5: '0123456789abcdef0123456789abcdef',
      packageTag: 'APP',
      serialNumber: 10,
    );
    final store = AppLocalStore(_MemoryKeyValueStorage());
    await store.setState(
      const AppLocalState(
        deviceInfo: <String, Object?>{
          DeviceInfoService.uniqueDeviceIdLabel: 'AABBCIID33',
        },
        upgrade: <String, Object?>{
          'enabled': false,
          'terminalId': '12345678901',
          'moduleImei': '867282033775202',
        },
      ),
    );
    final repository = _FakeTerminalUpgradeRepository(
      snapshot: TerminalUpgradeSnapshot(
        phase: TerminalUpgradePhase.updateAvailable,
        offer: offer,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLocalStoreProvider.overrideWith((ref) async => store),
          terminalUpgradeRepositoryProvider.overrideWith((ref) => repository),
        ],
        child: AppLocalizationsScope(
          localizations: const AppLocalizations(AppLanguage.simplifiedChinese),
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            initialRoute: AppRoutes.adminTerminalUpgrade,
            onGenerateRoute: AppRouter.onGenerateRoute,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final secureFields = tester
        .widgetList<TextField>(find.byType(TextField))
        .where((field) => field.obscureText);
    expect(secureFields, hasLength(1));
    expect(find.text(AppConfig.current.afrrDeviceImei), findsOne);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText &&
            widget.data == AppConfig.current.terminalUpgradeDataProtocolIp,
      ),
      findsOne,
    );
    expect(find.text('AABBCIID33'), findsOne);
    expect(find.text('867282033775202'), findsNothing);

    await tester.tap(find.text('下载并安装'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(repository.installCount, 0);

    await tester.tap(find.text('下载并安装'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '下载并安装').last);
    await tester.pumpAndSettle();

    expect(repository.installCount, 1);
    expect(identical(repository.confirmedOffer, offer), isTrue);
    expect(repository.administratorConfirmed, isTrue);
  });

  testWidgets('leaving upgrade page restores an idle pending offer prompt', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final offer = TerminalUpgradeOffer(
      targetVersion: '2.0.0',
      downloadUrl: Uri.parse('https://updates.example.com/app.apk'),
      md5: '0123456789abcdef0123456789abcdef',
      packageTag: 'APP',
      serialNumber: 10,
    );
    final repository = _FakeTerminalUpgradeRepository(
      snapshot: TerminalUpgradeSnapshot(
        phase: TerminalUpgradePhase.updateAvailable,
        offer: offer,
      ),
    );
    final store = AppLocalStore(_MemoryKeyValueStorage());
    await store.setState(
      const AppLocalState(
        deviceInfo: <String, Object?>{
          DeviceInfoService.uniqueDeviceIdLabel: 'AABBCIID33',
        },
      ),
    );
    final navigatorKey = GlobalKey<NavigatorState>();
    globalTerminalUpgradeOfferNotifier.show(offer);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLocalStoreProvider.overrideWith((ref) async => store),
          terminalUpgradeRepositoryProvider.overrideWith((ref) => repository),
        ],
        child: AppLocalizationsScope(
          localizations: const AppLocalizations(AppLanguage.simplifiedChinese),
          child: MaterialApp(
            navigatorKey: navigatorKey,
            theme: AppTheme.lightTheme,
            builder: (context, child) => TerminalUpgradeOfferOverlay(
              navigatorKey: navigatorKey,
              child: child ?? const SizedBox.shrink(),
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    key: const ValueKey('open_upgrade_page'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AdminTerminalUpgradePage(),
                      ),
                    ),
                    child: const Text('打开升级页'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('发现终端新版本'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('open_upgrade_page')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('admin_terminal_upgrade_page')), findsOne);
    expect(find.text('发现终端新版本'), findsNothing);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open_upgrade_page')), findsOneWidget);
    expect(find.text('发现终端新版本'), findsOneWidget);
    expect(globalTerminalUpgradeOfferNotifier.currentOffer, same(offer));
  });
}

final class _FakeTerminalUpgradeRepository
    implements TerminalUpgradeRepository {
  _FakeTerminalUpgradeRepository({
    this.snapshot = const TerminalUpgradeSnapshot(),
  });

  final TerminalUpgradeSnapshot snapshot;
  int refreshCount = 0;
  int requestCheckCount = 0;
  int installCount = 0;
  TerminalUpgradeOffer? confirmedOffer;
  bool? administratorConfirmed;

  @override
  TerminalUpgradeSnapshot get current => snapshot;

  @override
  Stream<TerminalUpgradeSnapshot> get states => const Stream.empty();

  @override
  Future<void> refreshInstallStatus() async {
    refreshCount += 1;
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<void> installAvailableUpdate({
    required TerminalUpgradeOffer confirmedOffer,
    required bool administratorConfirmed,
  }) async {
    installCount += 1;
    this.confirmedOffer = confirmedOffer;
    this.administratorConfirmed = administratorConfirmed;
  }

  @override
  Future<void> requestCheck() async {
    requestCheckCount += 1;
  }

  @override
  Future<void> start(TerminalUpgradeSettings settings) async {}

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
