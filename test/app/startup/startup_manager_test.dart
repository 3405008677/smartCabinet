import 'package:flutter_test/flutter_test.dart';
import 'package:smart_cabinet/src/app/startup/startup_manager.dart';
import 'package:smart_cabinet/src/app/startup/startup_task.dart';

void main() {
  test('runs startup tasks by order', () async {
    final calls = <String>[];
    final manager = StartupManager(
      tasks: [
        _FakeStartupTask(
          name: 'second',
          order: 20,
          onRun: () => calls.add('2'),
        ),
        _FakeStartupTask(name: 'first', order: 10, onRun: () => calls.add('1')),
      ],
    );

    final result = await manager.start();

    expect(calls, ['1', '2']);
    expect(result.canEnterApp, isTrue);
    expect(result.taskResults.map((result) => result.name), [
      'first',
      'second',
    ]);
  });

  test('stops startup when required task fails', () async {
    final calls = <String>[];
    final manager = StartupManager(
      tasks: [
        _FakeStartupTask(name: 'first', order: 10, onRun: () => calls.add('1')),
        _FakeStartupTask(
          name: 'required failure',
          order: 20,
          onRun: () => throw StateError('broken'),
        ),
        _FakeStartupTask(name: 'third', order: 30, onRun: () => calls.add('3')),
      ],
    );

    StartupFailedException? failure;
    try {
      await manager.start();
    } on StartupFailedException catch (error) {
      failure = error;
    }

    expect(failure, isNotNull);
    expect(calls, ['1']);
    expect(failure?.result.canEnterApp, isFalse);
    expect(failure?.result.firstRequiredFailure?.name, 'required failure');
  });

  test('continues startup when optional task fails', () async {
    final calls = <String>[];
    final manager = StartupManager(
      tasks: [
        _FakeStartupTask(
          name: 'optional failure',
          order: 10,
          required: false,
          onRun: () => throw StateError('optional broken'),
        ),
        _FakeStartupTask(
          name: 'required task',
          order: 20,
          onRun: () => calls.add('2'),
        ),
      ],
    );

    final result = await manager.start();

    expect(calls, ['2']);
    expect(result.canEnterApp, isTrue);
    expect(result.taskResults.first.succeeded, isFalse);
    expect(result.taskResults.last.succeeded, isTrue);
  });
}

class _FakeStartupTask implements StartupTask {
  const _FakeStartupTask({
    required this.name,
    required this.order,
    required this.onRun,
    this.required = true,
  });

  @override
  final String name;

  @override
  final int order;

  @override
  final bool required;

  final void Function() onRun;

  @override
  Duration get timeout => const Duration(seconds: 1);

  @override
  Future<void> run() async => onRun();
}
