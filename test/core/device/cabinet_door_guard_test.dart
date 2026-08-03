import 'package:flutter_test/flutter_test.dart';

import 'package:smart_cabinet/src/core/device/cabinet_door_guard.dart';

void main() {
  group('CabinetDoorGuard', () {
    test('同一任务的不同开门周期会获得不同操作 ID', () {
      final guard = CabinetDoorGuard();

      final first = guard.createOperationId('TASK-001');
      final second = guard.createOperationId('TASK-001');

      expect(first, startsWith('TASK-001:'));
      expect(second, startsWith('TASK-001:'));
      expect(second, isNot(first));
    });

    test('同一柜门重复请求幂等成功', () {
      final guard = CabinetDoorGuard();

      final first = guard.requestOpen('A-01', operationId: 'TASK-001');
      final second = guard.requestOpen('A-01', operationId: 'TASK-001');

      expect(first, isA<CabinetDoorOpenGranted>());
      expect((first as CabinetDoorOpenGranted).idempotent, isFalse);
      expect(second, isA<CabinetDoorOpenGranted>());
      expect((second as CabinetDoorOpenGranted).idempotent, isTrue);
      expect(guard.activeDoorNo, 'A-01');
      expect(guard.activeOperationId, 'TASK-001');
    });

    test('其他柜门或其他任务请求返回结构化冲突且不抢占当前操作', () {
      final guard = CabinetDoorGuard()
        ..requestOpen('A-01', operationId: 'TASK-001');

      final result = guard.requestOpen('B-02', operationId: 'TASK-002');
      final sameDoorOtherTask = guard.requestOpen(
        'A-01',
        operationId: 'TASK-003',
      );

      expect(result, isA<CabinetDoorOpenConflict>());
      expect(sameDoorOtherTask, isA<CabinetDoorOpenConflict>());
      final conflict = result as CabinetDoorOpenConflict;
      expect(conflict.requestedDoorNo, 'B-02');
      expect(conflict.activeDoorNo, 'A-01');
      expect(conflict.activeOperationId, 'TASK-001');
      expect(guard.activeDoorNo, 'A-01');
      expect(guard.activeOperationId, 'TASK-001');
    });

    test('只有正确柜门和业务操作关闭才释放全局互锁', () {
      final guard = CabinetDoorGuard()
        ..requestOpen('A-01', operationId: 'TASK-001');

      expect(guard.markClosed('B-02', operationId: 'TASK-001'), isFalse);
      expect(guard.markClosed('A-01', operationId: 'TASK-OTHER'), isFalse);
      expect(guard.hasActiveOperation, isTrue);
      expect(guard.markClosed('A-01', operationId: 'TASK-001'), isTrue);
      expect(guard.allDoorsClosed, isTrue);
      expect(
        guard.requestOpen('B-02', operationId: 'TASK-002').granted,
        isTrue,
      );
    });
  });
}
