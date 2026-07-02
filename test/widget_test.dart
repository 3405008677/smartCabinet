import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_cabinet/src/app/localization/app_localizations.dart';
import 'package:smart_cabinet/src/app/app.dart';
import 'package:smart_cabinet/src/app/router/app_router.dart';
import 'package:smart_cabinet/src/app/startup/startup_media.dart';
import 'package:smart_cabinet/src/core/camera/index.dart';

const MethodChannel _kioskChannel = MethodChannel('smart_cabinet/kiosk');

const List<CameraDescription> _testCameras = [
  CameraDescription(
    name: 'cameraId_0',
    lensDirection: CameraLensDirection.front,
    sensorOrientation: 90,
  ),
  CameraDescription(
    name: 'cameraId_1',
    lensDirection: CameraLensDirection.external,
    sensorOrientation: 0,
  ),
  CameraDescription(
    name: 'cameraId_2',
    lensDirection: CameraLensDirection.external,
    sensorOrientation: 180,
  ),
  CameraDescription(
    name: 'cameraId_3',
    lensDirection: CameraLensDirection.back,
    sensorOrientation: 270,
  ),
];

/// 应用主流程 Widget 测试。
///
/// 这里覆盖首页、设置、多语言、取件、放件、飞检和管理员入口等关键链路，
/// 用于确认主要业务流程在重构后没有回归。
void main() {
  setUp(() {
    /// 为本地 Store 提供测试内存实现，避免读写真实设备 SharedPreferences。
    SharedPreferences.setMockInitialValues(<String, Object>{});

    /// 每个测试开始前都先恢复到简体中文，避免前一个用例修改全局语言造成串扰。
    appLocaleController.setLanguage(AppLanguage.simplifiedChinese);
    StartupMedia.minimumDisplayDuration = Duration.zero;
    CabinetCameraService.debugUseCameraData(cameras: _testCameras);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_kioskChannel, null);
  });

  tearDown(() {
    StartupMedia.minimumDisplayDuration = const Duration(milliseconds: 1200);
    CabinetCameraService.debugReset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_kioskChannel, null);
  });

  testWidgets('app renders new smart cabinet home page', (
    WidgetTester tester,
  ) async {
    StartupMedia.minimumDisplayDuration = const Duration(milliseconds: 1200);
    await _pumpSmartCabinetApp(tester);

    expect(find.byKey(const ValueKey('startup_media_image')), findsOneWidget);
    expect(find.text('智能文件保管柜'), findsOneWidget);
    expect(find.text('通知'), findsNothing);
    expect(find.text('进入旧首页选择流程'), findsNothing);
    expect(find.text('当前柜体'), findsOneWidget);
    expect(find.text('智能柜统计信息'), findsOneWidget);
    expect(find.text('存储统计'), findsOneWidget);
    expect(find.text('存取件'), findsOneWidget);
    expect(find.text('飞检操作'), findsOneWidget);
    expect(find.text('管理员模式'), findsNothing);
    expect(find.text('设置'), findsNothing);
    expect(find.text('v2.4.1'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('startup_media_image')), findsNothing);
  });

  testWidgets('version taps open settings dialog and change home language', (
    WidgetTester tester,
  ) async {
    await _pumpSmartCabinetApp(tester);

    for (var i = 0; i < 7; i += 1) {
      await tester.tap(find.text('v2.4.1'));
      await tester.pump();
    }

    expect(find.text('语言设置'), findsNothing);

    await _tapVersion(tester);
    await tester.pumpAndSettle();

    expect(find.text('语言设置'), findsOneWidget);
    expect(find.text('简体中文'), findsOneWidget);

    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    expect(find.text('语言设置'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings_language_dropdown')));
    await tester.pumpAndSettle();

    expect(find.text('繁體中文'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('日本語'), findsOneWidget);

    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Current Cabinet'), findsOneWidget);
    expect(find.text('Access'), findsOneWidget);
    expect(find.text('Inspection'), findsOneWidget);
    expect(find.text('Admin Mode'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Language'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data != null &&
            RegExp(
              r'^\d{4}-\d{2}-\d{2} (Mon|Tue|Wed|Thu|Fri|Sat|Sun)$',
            ).hasMatch(widget.data!),
      ),
      findsOneWidget,
    );
  });

  testWidgets('about device row shows board information', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.localState': jsonEncode(<String, Object>{
        'deviceInfo': <String, Object>{
          '唯一设备ID': 'a1b2c3d4e5f67890',
          '主板': 'rk3568',
          '厂商': 'SmartCabinet Labs',
          '型号': 'SC-Board-A1',
          'Android 版本': '13',
          'Android SDK': 33,
        },
      }),
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_kioskChannel, (call) async {
          if (call.method == 'getDeviceInfo') {
            throw StateError('关于设备弹窗不应直接调用原生设备信息接口');
          }
          return null;
        });

    await _pumpSmartCabinetApp(tester);
    await _openSettingsDialog(tester);

    expect(find.text('关于设备'), findsOneWidget);
    expect(find.text('查看当前主板与系统信息'), findsOneWidget);

    await tester.tap(find.text('关于设备'));
    await tester.pumpAndSettle();

    expect(find.text('唯一设备ID'), findsOneWidget);
    expect(find.text('a1b2c3d4e5f67890'), findsOneWidget);
    expect(find.text('主板'), findsOneWidget);
    expect(find.text('rk3568'), findsOneWidget);
    expect(find.text('厂商'), findsOneWidget);
    expect(find.text('SmartCabinet Labs'), findsOneWidget);
    expect(find.text('型号'), findsOneWidget);
    expect(find.text('SC-Board-A1'), findsOneWidget);
    expect(find.text('Android 版本'), findsOneWidget);
    expect(find.text('13'), findsOneWidget);
  });

  testWidgets('home page uses native cabinet preview without webview model', (
    WidgetTester tester,
  ) async {
    await _pumpSmartCabinetApp(tester);

    expect(
      find.byKey(const ValueKey('cabinet_native_preview')),
      findsOneWidget,
    );
    expect(find.byType(PlatformViewLink), findsNothing);
  });

  testWidgets('new access action opens preserved foundation home page', (
    WidgetTester tester,
  ) async {
    await _pumpSmartCabinetApp(tester);

    await tester.tap(find.text('存取件'));
    await tester.pumpAndSettle();

    expect(find.text('返回首页'), findsOneWidget);
    expect(find.text('请选择操作类型'), findsOneWidget);
    expect(find.text('SYSTEM ONLINE · 安全运行中'), findsOneWidget);
    expect(find.text('四重安全认证 · 全程加密保护 · 实名追溯存档'), findsOneWidget);
    expect(find.text('PICK UP'), findsOneWidget);
    expect(find.text('DROP OFF'), findsOneWidget);
    expect(
      tester.getCenter(find.text('SYSTEM ONLINE · 安全运行中')).dy,
      tester.getCenter(find.text('返回首页')).dy,
    );
    expect(
      tester.getCenter(find.text('SYSTEM ONLINE · 安全运行中')).dx,
      greaterThan(tester.getCenter(find.text('返回首页')).dx),
    );
    expect(
      tester.getCenter(find.text('SYSTEM ONLINE · 安全运行中')).dy,
      lessThan(tester.getTopLeft(find.text('请选择操作类型')).dy),
    );

    await tester.tap(find.text('返回首页'));
    await tester.pumpAndSettle();

    expect(find.text('存取件'), findsOneWidget);
    expect(find.text('请选择操作类型'), findsNothing);
  });

  testWidgets('pickup verification cards use unified step headers', (
    WidgetTester tester,
  ) async {
    await _pumpSmartCabinetApp(tester);

    await tester.tap(find.text('存取件'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取件'));
    await tester.pumpAndSettle();

    expect(find.text('安全身份验证'), findsOneWidget);
    expect(find.text('人脸识别'), findsOneWidget);
    expect(find.text('指纹识别'), findsOneWidget);
    expect(find.text('NFC识别'), findsOneWidget);
    expect(find.text('Face Recognition'), findsNothing);
    expect(find.text('Fingerprint Scan'), findsNothing);
    expect(find.text('NFC Card Scan'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pickup verification page switches to English copy', (
    WidgetTester tester,
  ) async {
    /// 先把全局语言切换到英文，再启动应用验证取件页文案是否同步刷新。
    appLocaleController.setLanguage(AppLanguage.english);
    await _pumpSmartCabinetApp(tester);
    await tester.pumpAndSettle();

    /// 直接从测试中拿到 Navigator，跳过首页点击路径，聚焦验证取件页文案。
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navigator.pushNamed(AppRoutes.pickupVerification);
    await tester.pumpAndSettle();

    expect(find.text('Security Verification'), findsOneWidget);
    expect(find.text('Four-Step Verification · Pickup'), findsOneWidget);
    expect(find.text('Face Recognition'), findsOneWidget);
    expect(find.text('Fingerprint Scan'), findsOneWidget);
    expect(find.text('NFC Scan'), findsOneWidget);
    expect(find.text('Pickup Code'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Pickup'), findsOneWidget);
    expect(find.text('Enter 8-digit pickup code'), findsOneWidget);
  });

  testWidgets('dropoff verification cards use same shell as pickup', (
    WidgetTester tester,
  ) async {
    await _pumpSmartCabinetApp(tester);

    await tester.tap(find.text('存取件'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放件'));
    await tester.pumpAndSettle();

    expect(find.text('放件人员认证'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Face Recognition'), findsNothing);
    expect(find.text('Fingerprint Scan'), findsNothing);
    expect(find.text('NFC Card Scan'), findsNothing);
    expect(find.text('人脸识别'), findsOneWidget);
    expect(find.text('指纹识别'), findsOneWidget);
    expect(find.text('NFC识别'), findsOneWidget);
  });

  testWidgets('dropoff flow completes with simulated verification', (
    WidgetTester tester,
  ) async {
    await _pumpSmartCabinetApp(tester);

    await tester.tap(find.text('存取件'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放件'));
    await tester.pumpAndSettle();

    expect(find.text('放件人员认证'), findsOneWidget);
    expect(find.text('人员认证中 · 放件'), findsOneWidget);
    expect(find.text('人脸识别'), findsOneWidget);
    expect(find.text('指纹识别'), findsOneWidget);
    expect(find.text('NFC识别'), findsOneWidget);
    expect(find.text('取件码'), findsNothing);
    expect(find.text('正在启动摄像头...'), findsWidgets);
    expect(find.text('确认并拍照校验'), findsOneWidget);
    expect(find.text('验证进度'), findsOneWidget);
    expect(find.text('0 / 3'), findsOneWidget);

    await tester.tap(find.text('确认并拍照校验'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);
    await tester.tap(find.text('确认指纹识别'));
    await tester.pump();
    expect(find.text('2 / 3'), findsOneWidget);
    await tester.tap(find.text('确认NFC识别'));
    await tester.pumpAndSettle();

    expect(find.text('文件认证'), findsOneWidget);
    expect(find.text('文件认证中 · 放件'), findsOneWidget);
    expect(find.text('请将文件放到指定识别区'), findsOneWidget);
    expect(find.text('FRC 文件识别'), findsOneWidget);
    expect(find.text('正面常规图'), findsOneWidget);
    expect(find.text('正面紫外荧光图'), findsOneWidget);
    expect(find.text('反面常规图'), findsOneWidget);

    /// 模拟文件识别过程中的异步步骤推进。
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('FRC 已识别'), findsOneWidget);

    await tester.tap(find.text('开始识别'));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('正面常规图已采集'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('正面紫外荧光图已采集'), findsOneWidget);
    expect(find.text('请翻转文件，保持放在识别区'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('放件信息确认'), findsOneWidget);
    expect(find.text('认证完成 · 待开柜'), findsOneWidget);
    expect(find.text('张晓明'), findsOneWidget);
    expect(find.text('FILE-2026-001'), findsOneWidget);
    expect(find.text('A-08'), findsWidgets);
    expect(find.text('认证完成，柜门即将打开...'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('放入文件'), findsOneWidget);
    expect(find.text('柜门已打开 · 放件'), findsOneWidget);
    expect(find.text('请将文件放入柜门并关闭'), findsOneWidget);

    await tester.tap(find.text('确认已关闭柜门'));
    await tester.pumpAndSettle();

    expect(find.text('放件成功'), findsOneWidget);
    expect(find.text('已存入 1 份文件 · 柜门 A-08 · 已写入审计日志'), findsOneWidget);

    await tester.tap(find.text('继续放件'));
    await tester.pumpAndSettle();

    expect(find.text('放件人员认证'), findsOneWidget);
  });

  testWidgets('flight inspection locks cabinet until return verified', (
    WidgetTester tester,
  ) async {
    await _pumpSmartCabinetApp(tester);

    await tester.tap(find.text('飞检操作'));
    await tester.pumpAndSettle();

    expect(find.text('飞检人员认证'), findsOneWidget);
    expect(find.textContaining('飞检员：李晨'), findsOneWidget);
    expect(find.text('人脸识别'), findsOneWidget);
    expect(find.text('指纹识别'), findsOneWidget);
    expect(find.text('NFC识别'), findsOneWidget);
    expect(find.text('验证进度'), findsOneWidget);
    expect(find.text('0 / 3'), findsOneWidget);

    await tester.tap(find.text('确认并拍照校验'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);
    await tester.tap(find.text('确认指纹识别'));
    await tester.pump();
    expect(find.text('2 / 3'), findsOneWidget);
    await tester.tap(find.text('确认NFC识别'));
    await tester.pumpAndSettle();

    expect(find.text('飞检柜门列表'), findsOneWidget);
    expect(find.text('后台随机任务 FI-20260616-01'), findsOneWidget);
    expect(find.text('A-03'), findsOneWidget);
    expect(find.text('A-08'), findsOneWidget);
    expect(find.text('B-02'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('open_inspection_A-03')));
    await tester.pumpAndSettle();

    expect(find.text('柜门 A-03 飞检中'), findsOneWidget);
    expect(find.text('其他柜门已锁定，请先完成当前柜门飞检'), findsWidgets);
    final disabledButton = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('open_inspection_A-08')),
    );
    expect(disabledButton.onPressed, isNull);

    expect(_buttonByText(tester, '完成本柜飞检').onPressed, isNull);

    await tester.tap(find.text('确认物品已放回'));
    await tester.pump();
    expect(find.text('物品已放回'), findsWidgets);
    expect(_buttonByText(tester, '完成本柜飞检').onPressed, isNull);

    await tester.tap(find.text('执行放回校验'));
    await tester.pumpAndSettle();
    expect(find.text('放回校验成功'), findsWidgets);

    await tester.tap(find.text('完成本柜飞检'));
    await tester.pumpAndSettle();

    expect(find.text('A-03 已飞检'), findsOneWidget);
    final unlockedButton = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('open_inspection_A-08')),
    );
    expect(unlockedButton.onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('open_inspection_A-08')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认物品已放回'));
    await tester.pump();
    await tester.tap(find.text('执行放回校验'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成本柜飞检'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open_inspection_B-02')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认物品已放回'));
    await tester.pump();
    await tester.tap(find.text('执行放回校验'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成本柜飞检'));
    await tester.pumpAndSettle();

    expect(find.text('本次飞检完成'), findsWidgets);
  });

  testWidgets('non-home pages switch to English copy', (
    WidgetTester tester,
  ) async {
    appLocaleController.setLanguage(AppLanguage.english);
    await _pumpSmartCabinetApp(tester);
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navigator.pushNamed(AppRoutes.dropoffPersonVerification);
    await tester.pumpAndSettle();

    expect(find.text('Drop-off Identity Verification'), findsOneWidget);
    expect(find.text('Identity Verification · Drop-off'), findsOneWidget);
    expect(find.text('Face Recognition'), findsOneWidget);
    expect(find.text('Fingerprint Scan'), findsOneWidget);
    expect(find.text('NFC Scan'), findsOneWidget);

    await tester.tap(find.text('Confirm and Capture'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm Fingerprint'));
    await tester.pump();
    await tester.tap(find.text('Confirm NFC'));
    await tester.pumpAndSettle();

    expect(find.text('Document Verification'), findsOneWidget);
    expect(find.text('Document Verification · Drop-off'), findsOneWidget);
    expect(
      find.text('Place the document in the designated scan area'),
      findsOneWidget,
    );
    expect(find.text('FRC Document Recognition'), findsOneWidget);
  });

  testWidgets('admin mode action opens admin login dialog', (
    WidgetTester tester,
  ) async {
    await _pumpSmartCabinetApp(tester);

    await _openAdminLoginDialog(tester);

    expect(find.text('管理员后台'), findsOneWidget);
    expect(find.text('用户名'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
    expect(find.text('记住密码'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
    final verticalScrollables = tester
        .widgetList<Scrollable>(find.byType(Scrollable))
        .where((scrollable) {
          final axisDirection = scrollable.axisDirection;
          return axisDirection == AxisDirection.down ||
              axisDirection == AxisDirection.up;
        });
    expect(verticalScrollables, isEmpty);
  });

  testWidgets('admin login dialog remains usable on compact screens', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(640, 440);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpSmartCabinetApp(tester);

    await _openAdminLoginDialog(tester);

    expect(find.text('管理员后台'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('admin_login_illustration')),
      findsOneWidget,
    );
    expect(find.text('用户名'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);

    await tester.tap(find.text('用户名'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('admin_keyboard_1')), findsOneWidget);
    expect(
      tester.getCenter(find.byKey(const ValueKey('admin_keyboard_1'))).dx,
      lessThan(tester.getCenter(find.text('用户名')).dx),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'admin login fields replace illustration with left number keyboard',
    (WidgetTester tester) async {
      await _pumpSmartCabinetApp(tester);

      await _openAdminLoginDialog(tester);

      await tester.tap(find.text('用户名'));
      await tester.pumpAndSettle();

      expect(find.text('输入用户名'), findsOneWidget);
      expect(find.text('使用左侧数字键盘录入'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('admin_login_illustration')),
        findsNothing,
      );
      expect(
        tester.getCenter(find.byKey(const ValueKey('admin_keyboard_1'))).dx,
        lessThan(tester.getCenter(find.text('用户名')).dx),
      );
      expect(find.byKey(const ValueKey('admin_keyboard_back')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('admin_keyboard_1')));
      await tester.tap(find.byKey(const ValueKey('admin_keyboard_2')));
      await tester.pump();

      var editableTexts = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .toList();
      expect(editableTexts[0].controller.text, '12');
      expect(editableTexts[1].controller.text, isEmpty);

      await tester.tap(find.text('密码'));
      await tester.pumpAndSettle();

      expect(find.text('输入密码'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('admin_keyboard_3')));
      await tester.tap(find.byKey(const ValueKey('admin_keyboard_删除')));
      await tester.tap(find.byKey(const ValueKey('admin_keyboard_4')));
      await tester.pump();

      editableTexts = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .toList();
      expect(editableTexts[0].controller.text, '12');
      expect(editableTexts[1].controller.text, '4');

      await tester.tap(find.byKey(const ValueKey('admin_keyboard_清空')));
      await tester.pump();

      editableTexts = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .toList();
      expect(editableTexts[0].controller.text, '12');
      expect(editableTexts[1].controller.text, isEmpty);

      await tester.tap(find.byKey(const ValueKey('admin_keyboard_back')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('admin_login_illustration')),
        findsOneWidget,
      );
      expect(find.text('使用左侧数字键盘录入'), findsNothing);
    },
  );

  testWidgets('admin number keyboard bottom row stays inside dialog', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(980, 440);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpSmartCabinetApp(tester);

    await _openAdminLoginDialog(tester);
    await tester.tap(find.text('用户名'));
    await tester.pumpAndSettle();

    final dialogBottom = tester.getBottomLeft(find.byType(Dialog)).dy;
    final clearBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('admin_keyboard_清空')))
        .dy;
    final zeroBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('admin_keyboard_0')))
        .dy;
    final deleteBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('admin_keyboard_删除')))
        .dy;

    expect(clearBottom, lessThanOrEqualTo(dialogBottom));
    expect(zeroBottom, lessThanOrEqualTo(dialogBottom));
    expect(deleteBottom, lessThanOrEqualTo(dialogBottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin login denies invalid account', (
    WidgetTester tester,
  ) async {
    await _pumpSmartCabinetApp(tester);

    await _openAdminLoginDialog(tester);
    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();

    expect(find.text('账号或密码错误，或没有管理员权限'), findsOneWidget);
    expect(find.text('管理员后台'), findsOneWidget);
  });

  testWidgets('admin login and verification open admin console', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.localState': jsonEncode(<String, Object>{
        'deviceInfo': <String, Object>{'唯一设备ID': 'cabinet-device-001'},
      }),
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_kioskChannel, (call) async {
          if (call.method == 'getHardwareStatus') {
            return <String, Object?>{
              'wifiConnected': true,
              'wifiName': 'Factory-WiFi',
              'ethernetConnected': true,
              'fingerprintAvailable': true,
              'nfcAvailable': false,
            };
          }
          return null;
        });

    await _pumpSmartCabinetApp(tester);

    await _openAdminLoginDialog(tester);
    await tester.tap(find.text('用户名'));
    await tester.pumpAndSettle();
    for (final digit in '666666'.split('')) {
      await tester.tap(find.byKey(ValueKey('admin_keyboard_$digit')).first);
    }
    await tester.tap(find.text('密码'));
    await tester.pumpAndSettle();
    for (final digit in '666666'.split('')) {
      await tester.tap(find.byKey(ValueKey('admin_keyboard_$digit')).first);
    }
    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();

    expect(find.text('管理员身份校验'), findsOneWidget);
    expect(find.text('请完成管理员安全身份认证'), findsOneWidget);

    await tester.tap(find.text('确认并拍照校验'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认指纹识别'));
    await tester.pump();
    await tester.tap(find.text('确认NFC识别'));
    await tester.pumpAndSettle();

    expect(find.text('管理员控制台'), findsOneWidget);
    expect(find.text('当前柜体所有信息'), findsOneWidget);
    expect(find.text('柜体编号'), findsOneWidget);
    expect(find.text('cabinet-device-001'), findsOneWidget);
    expect(find.text('连接 WiFi'), findsOneWidget);
    expect(find.text('Factory-WiFi'), findsOneWidget);
    expect(find.text('运行状态'), findsNothing);
    expect(find.text('RJ45连接'), findsOneWidget);
    expect(find.text('已连接'), findsOneWidget);
    expect(find.text('摄像头'), findsNothing);
    expect(find.text('正常 · 人脸预览可用'), findsNothing);
    await _expectAdminDeviceGridText(tester, '人脸识别摄像头');
    await _expectAdminDeviceGridText(tester, '柜外环境摄像头');
    await _expectAdminDeviceGridText(tester, '操作区摄像头');
    await _expectAdminDeviceGridText(tester, '合格证采集摄像头');
    await tester.drag(
      find.byKey(const ValueKey('admin_device_info_grid')),
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    expect(find.text('指纹模块'), findsOneWidget);
    expect(find.text('可用'), findsOneWidget);
    expect(find.text('NFC'), findsOneWidget);
    expect(find.text('不可用'), findsOneWidget);
    expect(find.text('1、初始化数据'), findsOneWidget);
    expect(find.text('2、重置设备'), findsOneWidget);
    expect(find.text('3、自动检测'), findsOneWidget);
  });

  testWidgets('admin pages switch to English copy', (
    WidgetTester tester,
  ) async {
    await _pumpSmartCabinetApp(tester);

    await _openSettingsDialog(tester);
    await tester.tap(find.byKey(const ValueKey('settings_language_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    await _openSettingsDialog(tester);
    await tester.tap(find.text('Admin Mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Username'));
    await tester.pumpAndSettle();
    for (final digit in '666666'.split('')) {
      await tester.tap(find.byKey(ValueKey('admin_keyboard_$digit')).first);
    }
    await tester.tap(find.text('Password'));
    await tester.pumpAndSettle();
    for (final digit in '666666'.split('')) {
      await tester.tap(find.byKey(ValueKey('admin_keyboard_$digit')).first);
    }
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(find.text('Admin Identity Verification'), findsOneWidget);
    expect(find.text('Complete admin security verification'), findsOneWidget);

    await tester.tap(find.text('Confirm and Capture'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm Fingerprint'));
    await tester.pump();
    await tester.tap(find.text('Confirm NFC'));
    await tester.pumpAndSettle();

    expect(find.text('Admin Console'), findsOneWidget);
    expect(find.text('Current Cabinet Information'), findsOneWidget);
    expect(find.text('Connected WiFi'), findsOneWidget);
    expect(find.text('Camera'), findsNothing);
    expect(find.text('Face Recognition Camera'), findsOneWidget);
    expect(find.text('Function List'), findsOneWidget);
    expect(find.text('1. Initialize Data'), findsOneWidget);
    expect(find.text('2. Reset Device'), findsOneWidget);
    expect(find.text('3. Auto Detect'), findsOneWidget);
  });

  testWidgets('admin console shows fixed camera roles without config dialog', (
    WidgetTester tester,
  ) async {
    await _pumpSmartCabinetApp(tester);
    await _openAdminConsole(tester);

    final certificateCamera = find.byKey(
      const ValueKey('admin_camera_role_certificateCapture'),
    );
    await tester.drag(
      find.byKey(const ValueKey('admin_device_info_grid')),
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    await tester.tap(certificateCamera);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('开发时指定'), findsWidgets);
    expect(find.text('配置 合格证采集摄像头'), findsNothing);
    expect(find.text('物理摄像头'), findsNothing);
    expect(
      find.byKey(const ValueKey('admin_camera_preview_panel')),
      findsNothing,
    );
  });

  testWidgets('admin stream profile controls expose single active mode', (
    WidgetTester tester,
  ) async {
    CabinetCameraService.debugUseCameraData(
      cameras: _testCameras,
      outsideEnvironmentStreamStatus: const CameraStreamStatus(
        status: '720p/1080p 双路推流中',
        url:
            'rtsp://183.56.183.39:8888/app/device-001_720p,rtsp://183.56.183.39:8888/app/device-001_1080p',
        cameraId: 'cameraId_1',
        profile: '720p,1080p',
        streamMode: 'dual_active_profiles',
      ),
    );

    await _pumpSmartCabinetApp(tester);
    await _openAdminConsole(tester);
    await _expectAdminDeviceGridText(tester, '柜外环境推流按需加载');

    expect(find.text('双路按需，同时推送720p和1080p'), findsOneWidget);
    expect(find.text('360p'), findsNothing);
    expect(find.text('720p运行中'), findsOneWidget);
    expect(find.text('1080p运行中'), findsOneWidget);

    final activeProfileButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('720p运行中'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(activeProfileButton.onPressed, isNotNull);
  });
}

/// 登录并完成管理员认证后进入管理员控制台。
Future<void> _openAdminConsole(WidgetTester tester) async {
  await _openAdminLoginDialog(tester);
  await tester.tap(find.text('用户名'));
  await tester.pumpAndSettle();
  for (final digit in '666666'.split('')) {
    await tester.tap(find.byKey(ValueKey('admin_keyboard_$digit')).first);
  }
  await tester.tap(find.text('密码'));
  await tester.pumpAndSettle();
  for (final digit in '666666'.split('')) {
    await tester.tap(find.byKey(ValueKey('admin_keyboard_$digit')).first);
  }
  await tester.tap(find.text('登录'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('确认并拍照校验'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('确认指纹识别'));
  await tester.pump();
  await tester.tap(find.text('确认NFC识别'));
  await tester.pumpAndSettle();
}

/// 在管理员设备信息网格中滚动查找指定文本。
Future<void> _expectAdminDeviceGridText(
  WidgetTester tester,
  String text,
) async {
  final finder = find.text(text);
  for (
    var attempt = 0;
    attempt < 6 && finder.evaluate().isEmpty;
    attempt += 1
  ) {
    await tester.drag(
      find.byKey(const ValueKey('admin_device_info_grid')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
  }
  expect(finder, findsOneWidget);
}

/// 从首页设置弹窗打开管理员登录弹窗。
Future<void> _openAdminLoginDialog(WidgetTester tester) async {
  await _openSettingsDialog(tester);
  await tester.tap(find.text('管理员模式'));
  await tester.pumpAndSettle();
}

/// 连续点击底部版本号 8 次打开首页设置弹窗。
Future<void> _openSettingsDialog(WidgetTester tester) async {
  await _waitStartupMediaGone(tester);
  for (var i = 0; i < 8; i += 1) {
    await _tapVersion(tester);
  }
  await tester.pumpAndSettle();
}

/// 等待启动媒体层消失，避免测试点击被启动图遮挡。
Future<void> _waitStartupMediaGone(WidgetTester tester) async {
  if (find.byKey(const ValueKey('startup_media_layer')).evaluate().isEmpty) {
    return;
  }

  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pumpAndSettle();
}

/// 渲染带 ProviderScope 的应用根组件。
Future<void> _pumpSmartCabinetApp(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: SmartCabinetApp()));
}

/// 点击底部版本号隐藏触发区域一次。
Future<void> _tapVersion(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('terminal_version_tap_target')));
  await tester.pump();
}

/// 通过按钮文本获取对应的 ElevatedButton。
ElevatedButton _buttonByText(WidgetTester tester, String text) {
  return tester.widget<ElevatedButton>(
    find.ancestor(of: find.text(text), matching: find.byType(ElevatedButton)),
  );
}
