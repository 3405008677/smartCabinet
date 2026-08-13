/// 柜门开启请求的结果。
sealed class CabinetDoorOpenResult {
  /// 创建柜门开启请求结果。
  const CabinetDoorOpenResult({
    required this.requestedDoorNo,
    required this.requestedOperationId,
  });

  /// 本次请求希望打开的柜门编号。
  final String requestedDoorNo;

  /// 发起本次请求的任务或业务操作 ID。
  final String requestedOperationId;

  /// 本次请求是否允许继续执行开门动作。
  bool get granted;
}

/// 柜门开启请求已获准。
final class CabinetDoorOpenGranted extends CabinetDoorOpenResult {
  /// 创建获准结果。
  const CabinetDoorOpenGranted({
    required super.requestedDoorNo,
    required super.requestedOperationId,
    required this.idempotent,
  });

  /// 是否为同一柜门的重复幂等请求。
  final bool idempotent;

  @override
  bool get granted => true;
}

/// 柜门开启请求因另一柜门占用而被拒绝。
final class CabinetDoorOpenConflict extends CabinetDoorOpenResult {
  /// 创建柜门冲突结果。
  const CabinetDoorOpenConflict({
    required super.requestedDoorNo,
    required super.requestedOperationId,
    required this.activeDoorNo,
    required this.activeOperationId,
  });

  /// 当前已经占用全局开门资格的柜门编号。
  final String activeDoorNo;

  /// 当前实际占用柜门资格的任务或业务操作 ID。
  final String activeOperationId;

  @override
  bool get granted => false;
}

/// 柜门开启请求因系统维护租约而被拒绝。
final class CabinetDoorOpenMaintenanceConflict extends CabinetDoorOpenResult {
  /// 创建维护占用冲突结果。
  const CabinetDoorOpenMaintenanceConflict({
    required super.requestedDoorNo,
    required super.requestedOperationId,
    required this.maintenanceOperationId,
  });

  /// 当前维护租约的操作 ID。
  final String maintenanceOperationId;

  @override
  bool get granted => false;
}

/// 在应用进程内强制执行“任意时刻最多打开一个柜门”的互锁器。
///
/// [requestOpen] 和 [markClosed] 都是同步操作，因此同一 Dart isolate 内不会在
/// 检查与写入之间穿插另一条请求。真实设备仍需结合柜控板门磁状态和平台租约，
/// 本类只负责终端应用侧的第一道安全门禁。
final class CabinetDoorGuard {
  /// 创建柜门互锁器。
  CabinetDoorGuard();

  String? _activeDoorNo;
  String? _activeOperationId;
  String? _maintenanceOperationId;
  int _nextOperationSequence = 0;

  /// 当前占用开门资格的柜门编号；全部关闭时为 null。
  String? get activeDoorNo => _activeDoorNo;

  /// 当前占用开门资格的任务或业务操作 ID。
  String? get activeOperationId => _activeOperationId;

  /// 当前是否确认所有柜门均已关闭。
  bool get allDoorsClosed => _activeDoorNo == null;

  /// 当前是否存在尚未完成的柜门操作或系统维护租约。
  bool get hasActiveOperation =>
      _activeDoorNo != null || _maintenanceOperationId != null;

  /// 当前是否由升级等系统维护流程独占开门资格。
  bool get maintenanceActive => _maintenanceOperationId != null;

  /// 当前维护租约的操作 ID；无维护时为 null。
  String? get maintenanceOperationId => _maintenanceOperationId;

  /// 为一次具体开门周期签发进程内唯一的操作 ID。
  ///
  /// 同一任务的不同证件、不同箱格或重复页面必须使用不同 ID，避免旧页面误把
  /// 新一轮同门操作当成自己的幂等请求并释放其互锁。
  String createOperationId(String taskId) {
    final normalizedTaskId = taskId.trim();
    if (normalizedTaskId.isEmpty) {
      throw ArgumentError.value(taskId, 'taskId', '任务 ID 不能为空');
    }
    _nextOperationSequence += 1;
    return '$normalizedTaskId:$_nextOperationSequence';
  }

  /// 请求取得指定柜门的全局开门资格。
  ///
  /// 首次请求会占用资格；只有相同柜门且相同操作 ID 的重复请求按幂等成功处理；
  /// 其他请求会收到 [CabinetDoorOpenConflict]，且不会改变当前占用者。
  CabinetDoorOpenResult requestOpen(
    String doorNo, {
    required String operationId,
  }) {
    final normalizedDoorNo = doorNo.trim();
    final normalizedOperationId = operationId.trim();
    if (normalizedDoorNo.isEmpty) {
      throw ArgumentError.value(doorNo, 'doorNo', '柜门编号不能为空');
    }
    if (normalizedOperationId.isEmpty) {
      throw ArgumentError.value(operationId, 'operationId', '业务操作 ID 不能为空');
    }

    final maintenanceOperationId = _maintenanceOperationId;
    if (maintenanceOperationId != null) {
      return CabinetDoorOpenMaintenanceConflict(
        requestedDoorNo: normalizedDoorNo,
        requestedOperationId: normalizedOperationId,
        maintenanceOperationId: maintenanceOperationId,
      );
    }

    final activeDoorNo = _activeDoorNo;
    if (activeDoorNo == null) {
      _activeDoorNo = normalizedDoorNo;
      _activeOperationId = normalizedOperationId;
      return CabinetDoorOpenGranted(
        requestedDoorNo: normalizedDoorNo,
        requestedOperationId: normalizedOperationId,
        idempotent: false,
      );
    }
    if (activeDoorNo == normalizedDoorNo &&
        _activeOperationId == normalizedOperationId) {
      return CabinetDoorOpenGranted(
        requestedDoorNo: normalizedDoorNo,
        requestedOperationId: normalizedOperationId,
        idempotent: true,
      );
    }
    return CabinetDoorOpenConflict(
      requestedDoorNo: normalizedDoorNo,
      requestedOperationId: normalizedOperationId,
      activeDoorNo: activeDoorNo,
      activeOperationId: _activeOperationId!,
    );
  }

  /// 标记指定柜门已经由门磁确认关闭。
  ///
  /// 只有与当前占用者一致的柜门才能释放互锁。错误柜门或重复关闭返回 false，
  /// 防止误报关门使另一箱格获得开门资格。
  bool markClosed(String doorNo, {required String operationId}) {
    final normalizedDoorNo = doorNo.trim();
    final normalizedOperationId = operationId.trim();
    if (normalizedDoorNo.isEmpty ||
        normalizedOperationId.isEmpty ||
        normalizedDoorNo != _activeDoorNo ||
        normalizedOperationId != _activeOperationId) {
      return false;
    }
    _activeDoorNo = null;
    _activeOperationId = null;
    return true;
  }

  /// 判断指定任务是否正占用目标柜门的全局开门资格。
  bool isOpen(String doorNo, {required String operationId}) {
    return _activeDoorNo == doorNo.trim() &&
        _activeOperationId == operationId.trim();
  }

  /// 在全部柜门关闭时原子取得系统维护租约。
  ///
  /// 同一操作 ID 的重复请求按幂等成功处理；已有柜门操作或其它维护租约时返回
  /// false。租约存续期间所有新的 [requestOpen] 都会被拒绝。
  bool tryAcquireMaintenance(String operationId) {
    final normalizedOperationId = operationId.trim();
    if (normalizedOperationId.isEmpty) {
      throw ArgumentError.value(operationId, 'operationId', '维护操作 ID 不能为空');
    }
    if (_maintenanceOperationId == normalizedOperationId) {
      return true;
    }
    if (_activeDoorNo != null || _maintenanceOperationId != null) {
      return false;
    }
    _maintenanceOperationId = normalizedOperationId;
    return true;
  }

  /// 仅允许租约持有者释放系统维护占用。
  bool releaseMaintenance(String operationId) {
    final normalizedOperationId = operationId.trim();
    if (normalizedOperationId.isEmpty ||
        normalizedOperationId != _maintenanceOperationId) {
      return false;
    }
    _maintenanceOperationId = null;
    return true;
  }

  /// 判断指定操作是否持有系统维护租约。
  bool holdsMaintenance(String operationId) {
    return _maintenanceOperationId == operationId.trim();
  }
}

/// 应用默认共享的柜门互锁器。
final CabinetDoorGuard globalCabinetDoorGuard = CabinetDoorGuard();
