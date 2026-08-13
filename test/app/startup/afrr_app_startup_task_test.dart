import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_cabinet/src/app/startup/afrr_startup_failure_app.dart';
import 'package:smart_cabinet/src/app/startup/startup_manager.dart';
import 'package:smart_cabinet/src/app/startup/startup_task.dart';
import 'package:smart_cabinet/src/app/startup/startup_tasks.dart';

void main() {
  test('AFRR APP logon is a required startup task', () async {
    var called = false;
    final task = ConnectAfrrAppStartupTask(logon: () async => called = true);

    await task.run();

    expect(called, isTrue);
    expect(task.required, isTrue);
    expect(task.name, '登录监管服务');
  });

  test('AFRR APP logon failure blocks the remaining startup tasks', () async {
    final laterTask = _RecordingStartupTask();

    await expectLater(
      StartupManager(
        tasks: <StartupTask>[
          ConnectAfrrAppStartupTask(
            logon: () async => throw StateError('连接被拒绝'),
          ),
          laterTask,
        ],
      ).start(),
      throwsA(
        isA<StartupFailedException>().having(
          (error) => error.result.firstRequiredFailure?.name,
          'failed task',
          '登录监管服务',
        ),
      ),
    );
    expect(laterTask.ran, isFalse);
  });

  testWidgets('service failure shows a non-dismissible blocking dialog', (
    tester,
  ) async {
    final result = StartupResult(
      taskResults: <StartupTaskResult>[
        StartupTaskResult(
          name: '登录监管服务',
          status: StartupTaskStatus.failed,
          required: true,
          duration: const Duration(milliseconds: 10),
          error: const _ReadableError('无法连接监管服务：Connection refused'),
        ),
      ],
    );

    await tester.pumpWidget(AfrrStartupFailureApp(result: result));

    expect(
      find.byKey(const ValueKey('afrr_startup_blocking_dialog')),
      findsOneWidget,
    );
    expect(find.text('无法连接监管服务：Connection refused'), findsOneWidget);
    expect(find.text('请联系管理员'), findsOneWidget);
    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
  });
}

final class _RecordingStartupTask implements StartupTask {
  bool ran = false;

  @override
  String get name => '不应执行';

  @override
  int get order => 20;

  @override
  bool get required => true;

  @override
  Duration get timeout => const Duration(seconds: 1);

  @override
  Future<void> run() async {
    ran = true;
  }
}

final class _ReadableError implements Exception {
  const _ReadableError(this.message);

  final String message;

  @override
  String toString() => message;
}
