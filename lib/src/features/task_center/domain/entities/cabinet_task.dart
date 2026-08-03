/// 智能柜任务类型。
enum TaskType {
  /// 将新证件存入智能柜。
  storeEvidence,

  /// 从智能柜取出证件。
  retrieveEvidence,

  /// 借出证件并形成待归还记录。
  borrowEvidence,

  /// 将已借证件归还智能柜。
  returnEvidence,

  /// 对柜内证件执行 RFID 盘点。
  inventory,
}

/// 智能柜任务状态。
enum CabinetTaskStatus { pending, inProgress, completed }

/// 任务内单个证件的处理状态。
enum TaskItemStatus { pending, processing, completed }

/// 盘点任务的抽盘口径。
enum InventorySamplingMode {
  /// 对当前机构的全部授权箱格执行盘点。
  full,

  /// 由平台按箱格比例抽取，命中的箱格必须整箱盘点。
  byBoxRatio,

  /// 平台指定证件，并将其所在箱格扩展为整箱盘点。
  specifiedDocuments,
}

/// 盘点过程中单份证件的比对结果。
enum InventoryItemResult { pending, normal, missing, surplus }

/// 盘点证件是否已经放回当前箱格。
enum InventoryReturnStatus { notRequired, waiting, returned }

/// 盘点明细页中一个箱格的展示状态。
enum InventorySlotStatus {
  /// 本次任务未抽中该箱格。
  notRequired,

  /// 已抽中但尚未开箱。
  pending,

  /// 柜门已经打开，尚未完成首份证件比对。
  inProgress,

  /// 已盘完部分证件，箱内仍有待核对证件。
  partiallyChecked,

  /// 整箱盘点正确且已确认放回。
  completed,

  /// 整箱存在缺失或溢余。
  abnormal,
}

/// 任务演示流程支持的步骤类型。
enum TaskStepType {
  attachRfid,
  scanRfid,
  captureFront,
  captureBack,
  runOcr,
  verifyPickupCode,
  reviewPendingItems,
  verifyInventoryCode,
  inventoryBySlot,
  assignSlot,
  openDoor,
  transferWithinDeadline,
  closeDoorAndReport,
}

/// 返回五类任务不可删减或重排的规范步骤序列。
List<TaskStepType> requiredTaskStepTypes(TaskType type) {
  return switch (type) {
    TaskType.storeEvidence => const [
      TaskStepType.attachRfid,
      TaskStepType.captureFront,
      TaskStepType.captureBack,
      TaskStepType.runOcr,
      TaskStepType.assignSlot,
      TaskStepType.openDoor,
      TaskStepType.transferWithinDeadline,
      TaskStepType.closeDoorAndReport,
    ],
    TaskType.retrieveEvidence || TaskType.borrowEvidence => const [
      TaskStepType.verifyPickupCode,
      TaskStepType.reviewPendingItems,
      TaskStepType.assignSlot,
      TaskStepType.openDoor,
      TaskStepType.scanRfid,
      TaskStepType.transferWithinDeadline,
      TaskStepType.closeDoorAndReport,
    ],
    TaskType.returnEvidence => const [
      TaskStepType.reviewPendingItems,
      TaskStepType.scanRfid,
      TaskStepType.captureFront,
      TaskStepType.captureBack,
      TaskStepType.runOcr,
      TaskStepType.assignSlot,
      TaskStepType.openDoor,
      TaskStepType.transferWithinDeadline,
      TaskStepType.closeDoorAndReport,
    ],
    TaskType.inventory => const [
      TaskStepType.verifyInventoryCode,
      TaskStepType.inventoryBySlot,
    ],
  };
}

/// 任务步骤状态。
enum TaskStepStatus { pending, completed }

/// 任务中的一个可执行步骤。
final class TaskStep {
  /// 创建任务步骤。
  const TaskStep({required this.type, this.status = TaskStepStatus.pending});

  /// 步骤类型。
  final TaskStepType type;

  /// 当前步骤状态。
  final TaskStepStatus status;

  /// 返回更新状态后的步骤。
  TaskStep copyWith({TaskStepStatus? status}) {
    return TaskStep(type: type, status: status ?? this.status);
  }
}

/// 单个待处理证件或档案。
final class TaskItem {
  /// 创建任务证件项。
  const TaskItem({
    required this.id,
    required this.documentCode,
    required this.documentName,
    this.rfid,
    this.doorNo,
    this.status = TaskItemStatus.pending,
    this.inventoryResult = InventoryItemResult.pending,
    this.inventoryReturnStatus = InventoryReturnStatus.notRequired,
    this.isInventorySurplus = false,
  });

  /// 平台侧证件 ID。
  final String id;

  /// 业务证件编号。
  final String documentCode;

  /// 证件名称。
  final String documentName;

  /// 已绑定或预期读取的 RFID。
  final String? rfid;

  /// 目标或来源柜门编号。
  final String? doorNo;

  /// 当前证件处理状态。
  final TaskItemStatus status;

  /// 盘点任务中的 RFID 比对结果。
  final InventoryItemResult inventoryResult;

  /// 盘点任务中的放回状态。
  final InventoryReturnStatus inventoryReturnStatus;

  /// 是否为扫描到但平台清单中不存在的溢余证件。
  final bool isInventorySurplus;

  /// 返回更新后的证件项。
  TaskItem copyWith({
    String? rfid,
    String? doorNo,
    TaskItemStatus? status,
    InventoryItemResult? inventoryResult,
    InventoryReturnStatus? inventoryReturnStatus,
    bool? isInventorySurplus,
  }) {
    return TaskItem(
      id: id,
      documentCode: documentCode,
      documentName: documentName,
      rfid: rfid ?? this.rfid,
      doorNo: doorNo ?? this.doorNo,
      status: status ?? this.status,
      inventoryResult: inventoryResult ?? this.inventoryResult,
      inventoryReturnStatus:
          inventoryReturnStatus ?? this.inventoryReturnStatus,
      isInventorySurplus: isInventorySurplus ?? this.isInventorySurplus,
    );
  }
}

/// 平台下发的箱格级盘点计划。
///
/// 比例抽盘只在平台侧决定命中的箱格；终端收到计划后必须对命中箱格内的
/// 全部证件执行 RFID 比对，不能再次按证件比例缩小范围。
final class InventoryPlan {
  /// 创建盘点计划。
  const InventoryPlan({
    required this.inspectionCode,
    required this.samplingMode,
    required this.allDoorNos,
    required this.requiredDoorNos,
    this.boxSampleRatio,
    this.specifiedDocumentCodes = const [],
    this.completedDoorNos = const [],
    this.codeVerified = false,
    this.activeDoorNo,
  });

  /// 平台下发的飞检码，仅用于专用校验入口。
  final String inspectionCode;

  /// 本次盘点采用的抽盘口径。
  final InventorySamplingMode samplingMode;

  /// 当前机构在本计划中可见的全部箱格。
  final List<String> allDoorNos;

  /// 本次实际需要整箱盘点的箱格。
  final List<String> requiredDoorNos;

  /// 按箱格比例抽盘时的平台比例，取值范围为 0 到 1。
  final double? boxSampleRatio;

  /// 指定证件抽盘时的平台证件编号。
  final List<String> specifiedDocumentCodes;

  /// 已完成关门和差异上报的箱格。
  final List<String> completedDoorNos;

  /// 飞检码是否已经通过校验。
  final bool codeVerified;

  /// 当前正在盘点且占用柜门互锁的箱格。
  final String? activeDoorNo;

  /// 本次抽中的箱格数量。
  int get requiredDoorCount => requiredDoorNos.length;

  /// 已经完成的箱格数量。
  int get completedDoorCount => completedDoorNos.length;

  /// 所有抽中箱格是否已经完成。
  bool get allRequiredDoorsCompleted {
    return requiredDoorNos.isNotEmpty &&
        requiredDoorNos.every(completedDoorNos.contains);
  }

  /// 指定箱格是否属于本次抽盘范围。
  bool requiresDoor(String doorNo) => requiredDoorNos.contains(doorNo);

  /// 指定箱格是否已经完成。
  bool isDoorCompleted(String doorNo) => completedDoorNos.contains(doorNo);

  /// 返回更新后的盘点计划。
  InventoryPlan copyWith({
    List<String>? completedDoorNos,
    bool? codeVerified,
    String? activeDoorNo,
    bool clearActiveDoorNo = false,
  }) {
    return InventoryPlan(
      inspectionCode: inspectionCode,
      samplingMode: samplingMode,
      allDoorNos: List<String>.unmodifiable(allDoorNos),
      requiredDoorNos: List<String>.unmodifiable(requiredDoorNos),
      boxSampleRatio: boxSampleRatio,
      specifiedDocumentCodes: List<String>.unmodifiable(specifiedDocumentCodes),
      completedDoorNos: List<String>.unmodifiable(
        completedDoorNos ?? this.completedDoorNos,
      ),
      codeVerified: codeVerified ?? this.codeVerified,
      activeDoorNo: clearActiveDoorNo
          ? null
          : activeDoorNo ?? this.activeDoorNo,
    );
  }
}

/// 监管机构与物理箱格的独占绑定。
final class InstitutionSlotBinding {
  /// 创建机构箱格绑定。
  const InstitutionSlotBinding({
    required this.cabinetId,
    required this.doorNo,
    required this.organizationId,
    required this.organizationName,
  });

  /// 智能柜设备 ID。
  final String cabinetId;

  /// 柜门编号。
  final String doorNo;

  /// 独占使用该箱格的监管机构 ID。
  final String organizationId;

  /// 独占使用该箱格的监管机构名称。
  final String organizationName;
}

/// 登录后展示和执行的智能柜任务。
final class CabinetTask {
  /// 创建智能柜任务。
  const CabinetTask({
    required this.id,
    required this.type,
    required this.title,
    required this.organizationId,
    required this.organizationName,
    required this.items,
    required this.steps,
    this.pickupCode,
    this.slotBinding,
    this.pendingClosedDoorNo,
    this.inventoryPlan,
    this.status = CabinetTaskStatus.pending,
  });

  /// 平台侧任务 ID。
  final String id;

  /// 任务类型。
  final TaskType type;

  /// 任务展示标题。
  final String title;

  /// 任务所属监管机构 ID。
  final String organizationId;

  /// 任务所属监管机构名称。
  final String organizationName;

  /// 本任务需要处理的证件列表。
  final List<TaskItem> items;

  /// 本任务的顺序步骤。
  final List<TaskStep> steps;

  /// 取证或借证使用的取件码演示值。
  final String? pickupCode;

  /// 平台已分配或已授权的机构箱格。
  final InstitutionSlotBinding? slotBinding;

  /// 实物门已确认关闭、但平台业务结算尚未成功的柜门编号。
  final String? pendingClosedDoorNo;

  /// 盘点任务的箱格抽样计划，其他任务保持为空。
  final InventoryPlan? inventoryPlan;

  /// 当前任务状态。
  final CabinetTaskStatus status;

  /// 当前第一个尚未完成的步骤。
  TaskStep? get currentStep {
    for (final step in steps) {
      if (step.status == TaskStepStatus.pending) {
        return step;
      }
    }
    return null;
  }

  /// 已完成步骤数量。
  int get completedStepCount {
    return steps
        .where((step) => step.status == TaskStepStatus.completed)
        .length;
  }

  /// 当前任务是否已完成。
  bool get isCompleted => status == CabinetTaskStatus.completed;

  /// 当前正在处理或下一份待处理的证件。
  TaskItem? get currentItem {
    for (final item in items) {
      if (item.status == TaskItemStatus.processing) {
        return item;
      }
    }
    for (final item in items) {
      if (item.status == TaskItemStatus.pending) {
        return item;
      }
    }
    return null;
  }

  /// 所有证件是否均已逐件处理完成。
  bool get allItemsCompleted {
    return items.isNotEmpty &&
        items.every((item) => item.status == TaskItemStatus.completed);
  }

  /// 当前任务是否满足提交完成所需的证件条件。
  bool get allRequiredItemsCompleted {
    final plan = inventoryPlan;
    if (type != TaskType.inventory || plan == null) {
      return allItemsCompleted;
    }
    if (!plan.allRequiredDoorsCompleted) {
      return false;
    }
    return items
        .where((item) => plan.requiresDoor(item.doorNo ?? ''))
        .every((item) => item.status == TaskItemStatus.completed);
  }

  /// 返回指定箱格内的全部预期与溢余证件。
  List<TaskItem> inventoryItemsForDoor(String doorNo) {
    return List<TaskItem>.unmodifiable(
      items.where((item) => item.doorNo == doorNo),
    );
  }

  /// 返回指定箱格中尚未完成业务处理的证件数量。
  int unfinishedItemCountForDoor(String doorNo) {
    return items
        .where(
          (item) =>
              item.doorNo == doorNo && item.status != TaskItemStatus.completed,
        )
        .length;
  }

  /// 返回指定箱格尚未完成 RFID 比对的预期证件数量。
  int inventoryPendingCount(String doorNo) {
    return items
        .where(
          (item) =>
              item.doorNo == doorNo &&
              !item.isInventorySurplus &&
              item.inventoryResult == InventoryItemResult.pending,
        )
        .length;
  }

  /// 根据计划和证件差异计算箱格展示状态。
  InventorySlotStatus inventorySlotStatus(String doorNo) {
    final plan = inventoryPlan;
    if (plan == null || !plan.requiresDoor(doorNo)) {
      return InventorySlotStatus.notRequired;
    }
    final doorItems = inventoryItemsForDoor(doorNo);
    if (plan.isDoorCompleted(doorNo)) {
      final hasDifference = doorItems.any(
        (item) =>
            item.inventoryResult == InventoryItemResult.missing ||
            item.inventoryResult == InventoryItemResult.surplus,
      );
      return hasDifference
          ? InventorySlotStatus.abnormal
          : InventorySlotStatus.completed;
    }
    if (plan.activeDoorNo == doorNo) {
      final checkedCount = doorItems
          .where(
            (item) =>
                item.inventoryResult == InventoryItemResult.normal ||
                item.inventoryResult == InventoryItemResult.surplus,
          )
          .length;
      if (checkedCount > 0 && inventoryPendingCount(doorNo) > 0) {
        return InventorySlotStatus.partiallyChecked;
      }
      return InventorySlotStatus.inProgress;
    }
    return InventorySlotStatus.pending;
  }

  /// 返回更新后的任务。
  CabinetTask copyWith({
    List<TaskItem>? items,
    List<TaskStep>? steps,
    InstitutionSlotBinding? slotBinding,
    bool clearSlotBinding = false,
    String? pendingClosedDoorNo,
    bool clearPendingClosedDoorNo = false,
    InventoryPlan? inventoryPlan,
    CabinetTaskStatus? status,
  }) {
    return CabinetTask(
      id: id,
      type: type,
      title: title,
      organizationId: organizationId,
      organizationName: organizationName,
      items: List<TaskItem>.unmodifiable(items ?? this.items),
      steps: List<TaskStep>.unmodifiable(steps ?? this.steps),
      pickupCode: pickupCode,
      slotBinding: clearSlotBinding ? null : slotBinding ?? this.slotBinding,
      pendingClosedDoorNo: clearPendingClosedDoorNo
          ? null
          : pendingClosedDoorNo ?? this.pendingClosedDoorNo,
      inventoryPlan: inventoryPlan ?? this.inventoryPlan,
      status: status ?? this.status,
    );
  }
}
