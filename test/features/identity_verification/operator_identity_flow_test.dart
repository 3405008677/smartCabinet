import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_cabinet/src/app/routing/app_routes.dart';
import 'package:smart_cabinet/src/app/theme/app_theme.dart';
import 'package:smart_cabinet/src/core/config/app_config.dart';
import 'package:smart_cabinet/src/features/identity_verification/data/repositories/operator_identity_repository_impl.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_account.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_identity_navigation.dart';
import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_identity_profile.dart';
import 'package:smart_cabinet/src/features/identity_verification/presentation/operator_login_coordinator.dart';
import 'package:smart_cabinet/src/features/identity_verification/presentation/pages/operator_verification_page.dart';
import 'package:smart_cabinet/src/features/task_center/presentation/pages/task_center_page.dart';

/// 普通操作员账号资料分支与三项全验认证流程测试。
const _productionConfig = AppConfig(appName: '测试终端', apiBaseUrl: '');

void main() {
  setUp(resetOperatorIdentityRepositoryForTesting);

  testWidgets('all three identity factors are required for task center', (
    WidgetTester tester,
  ) async {
    final account = await _login('666666', '666666');
    TaskCenterArguments? taskArguments;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: OperatorVerificationPage(
          appConfig: _productionConfig,
          arguments: OperatorVerificationArguments(
            account: account,
            initialVerifiedFactors: const <IdentityFactor>{IdentityFactor.face},
          ),
        ),
        onGenerateRoute: (settings) {
          if (settings.name != AppRoutes.taskCenter) {
            return null;
          }
          taskArguments = settings.arguments! as TaskCenterArguments;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('任务中心测试页')),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('确认识别').first);
    await tester.pumpAndSettle();

    expect(find.text('任务中心测试页'), findsNothing);
    expect(taskArguments, isNull);

    await tester.tap(find.text('确认识别').first);
    await tester.pumpAndSettle();

    expect(find.text('任务中心测试页'), findsOneWidget);
    expect(taskArguments, isNotNull);
    expect(taskArguments!.account.verifiedFactors, <IdentityFactor>{
      IdentityFactor.face,
      IdentityFactor.fingerprint,
      IdentityFactor.nfc,
    });
  });

  testWidgets('test mode account login skips identity verification', (
    WidgetTester tester,
  ) async {
    TaskCenterArguments? taskArguments;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => unawaited(
                coordinateOperatorAccountLogin(
                  context,
                  appConfig: const AppConfig(
                    appName: '测试终端',
                    apiBaseUrl: '',
                    isTestMode: true,
                  ),
                ),
              ),
              child: const Text('测试账号登录'),
            ),
          ),
        ),
        onGenerateRoute: (settings) {
          if (settings.name != AppRoutes.taskCenter) {
            return null;
          }
          taskArguments = settings.arguments! as TaskCenterArguments;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('测试任务中心')),
          );
        },
      ),
    );

    await tester.tap(find.text('测试账号登录'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('operator_account_username')));
    await tester.pumpAndSettle();
    for (var index = 0; index < 6; index += 1) {
      await tester.tap(find.byKey(const ValueKey('operator_keyboard_6')));
    }
    await tester.tap(find.byKey(const ValueKey('operator_account_password')));
    await tester.pumpAndSettle();
    for (var index = 0; index < 6; index += 1) {
      await tester.tap(find.byKey(const ValueKey('operator_keyboard_6')));
    }
    await tester.tap(
      find.byKey(const ValueKey('operator_account_login_submit')),
    );
    await tester.pumpAndSettle();

    expect(find.text('测试任务中心'), findsOneWidget);
    expect(
      taskArguments?.account.verifiedFactors,
      requiredOperatorIdentityFactors,
    );
  });

  testWidgets('account 100001 routes to missing profile enrollment', (
    WidgetTester tester,
  ) async {
    final account = await _login('100001', '123456');
    Object? routedArguments;

    await tester.pumpWidget(
      _CoordinatorHarness(
        account: account,
        onRoute: (arguments) => routedArguments = arguments,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('continue_account_login')));
    await tester.pumpAndSettle();

    expect(find.text(AppRoutes.identityEnrollment), findsOneWidget);
    final arguments = routedArguments! as IdentityEnrollmentArguments;
    expect(arguments.factors, <IdentityFactor>{
      IdentityFactor.face,
      IdentityFactor.fingerprint,
    });

    await operatorIdentityRepository.enrollFactor(
      account: account,
      factor: IdentityFactor.face,
    );
    await operatorIdentityRepository.enrollFactor(
      account: account,
      factor: IdentityFactor.fingerprint,
    );
    final profile = await operatorIdentityRepository.loadProfile(account);
    expect(profile.status, OperatorIdentityProfileStatus.ready);
  });

  testWidgets('account 100002 syncs local profile before verification', (
    WidgetTester tester,
  ) async {
    final account = await _login('100002', '123456');
    Object? routedArguments;

    await tester.pumpWidget(
      _CoordinatorHarness(
        account: account,
        onRoute: (arguments) => routedArguments = arguments,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('continue_account_login')));
    await tester.pumpAndSettle();

    expect(find.text(AppRoutes.operatorVerification), findsOneWidget);
    final arguments = routedArguments! as OperatorVerificationArguments;
    expect(arguments.account?.id, account.id);
    expect(arguments.requiredFactors, <IdentityFactor>{
      IdentityFactor.face,
      IdentityFactor.fingerprint,
      IdentityFactor.nfc,
    });
    expect(arguments.abnormalRecovery, isFalse);
    final profile = await operatorIdentityRepository.loadProfile(account);
    expect(profile.status, OperatorIdentityProfileStatus.synced);
    expect(profile.localFactors, containsAll(IdentityFactor.values));
  });

  testWidgets('synced profile requires all three identity factors', (
    WidgetTester tester,
  ) async {
    final account = await _login('100002', '123456');
    await operatorIdentityRepository.syncProfile(account);
    TaskCenterArguments? taskArguments;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: OperatorVerificationPage(
          appConfig: _productionConfig,
          arguments: OperatorVerificationArguments(
            account: account,
            initialVerifiedFactors: const <IdentityFactor>{IdentityFactor.nfc},
            requiredFactors: requiredOperatorIdentityFactors,
          ),
        ),
        onGenerateRoute: (settings) {
          if (settings.name != AppRoutes.taskCenter) {
            return null;
          }
          taskArguments = settings.arguments! as TaskCenterArguments;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('同步账号任务中心')),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('确认识别').first);
    await tester.pumpAndSettle();

    expect(taskArguments, isNull);
    expect(find.text('同步账号任务中心'), findsNothing);

    await tester.tap(find.text('确认并拍照校验'));
    await tester.pumpAndSettle();

    expect(find.text('同步账号任务中心'), findsOneWidget);
    expect(taskArguments!.account.verifiedFactors, <IdentityFactor>{
      IdentityFactor.face,
      IdentityFactor.fingerprint,
      IdentityFactor.nfc,
    });
  });

  testWidgets('account 100003 enters abnormal verification before reporting', (
    WidgetTester tester,
  ) async {
    final account = await _login('100003', '123456');
    Object? routedArguments;

    await tester.pumpWidget(
      _CoordinatorHarness(
        account: account,
        onRoute: (arguments) => routedArguments = arguments,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('continue_account_login')));
    await tester.pumpAndSettle();

    expect(find.text(AppRoutes.operatorVerification), findsOneWidget);
    final arguments = routedArguments! as OperatorVerificationArguments;
    expect(arguments.abnormalRecovery, isTrue);
    expect(arguments.requiredFactors, <IdentityFactor>{
      IdentityFactor.face,
      IdentityFactor.fingerprint,
      IdentityFactor.nfc,
    });
    final profile = await operatorIdentityRepository.loadProfile(account);
    expect(profile.abnormalReported, isFalse);
  });

  testWidgets(
    'abnormal profile reports after all required factors are attempted',
    (WidgetTester tester) async {
      final account = await _login('100003', '123456');
      // 模拟只有人脸资料异常，确保“一项成功、一项失败”也能完成异常报备。
      await operatorIdentityRepository.enrollFactor(
        account: account,
        factor: IdentityFactor.fingerprint,
      );
      IdentityEnrollmentArguments? enrollmentArguments;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: OperatorVerificationPage(
            appConfig: _productionConfig,
            arguments: OperatorVerificationArguments(
              account: account,
              requiredFactors: requiredOperatorIdentityFactors,
              abnormalRecovery: true,
            ),
          ),
          onGenerateRoute: (settings) {
            if (settings.name != AppRoutes.identityEnrollment) {
              return null;
            }
            enrollmentArguments =
                settings.arguments! as IdentityEnrollmentArguments;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('异常资料录入页')),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('确认识别').first);
      await tester.pumpAndSettle();

      expect(enrollmentArguments, isNull);
      var profile = await operatorIdentityRepository.loadProfile(account);
      expect(profile.abnormalReported, isFalse);

      await tester.tap(find.text('确认并拍照校验'));
      await tester.pumpAndSettle();

      expect(enrollmentArguments, isNull);

      await tester.tap(find.text('确认识别').first);
      await tester.pumpAndSettle();

      expect(find.text('异常资料录入页'), findsOneWidget);
      expect(enrollmentArguments?.abnormalReported, isTrue);
      expect(enrollmentArguments?.factors, <IdentityFactor>{
        IdentityFactor.face,
      });
      profile = await operatorIdentityRepository.loadProfile(account);
      expect(profile.abnormalReported, isTrue);
    },
  );
}

/// 使用演示仓库登录并返回必定存在的测试账号。
Future<OperatorAccount> _login(String username, String password) async {
  final account = await operatorIdentityRepository.login(
    username: username,
    password: password,
  );
  return account!;
}

/// 触发账号资料协调器并把目标路由替换为轻量测试页。
class _CoordinatorHarness extends StatelessWidget {
  /// 创建账号资料协调器测试壳。
  const _CoordinatorHarness({required this.account, required this.onRoute});

  final OperatorAccount account;
  final ValueChanged<Object?> onRoute;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              key: const ValueKey('continue_account_login'),
              onPressed: () => unawaited(
                continueOperatorAccountLogin(context, account: account),
              ),
              child: const Text('继续账号登录'),
            ),
          ),
        ),
      ),
      onGenerateRoute: (settings) {
        onRoute(settings.arguments);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(body: Text(settings.name ?? 'unknown')),
        );
      },
    );
  }
}
