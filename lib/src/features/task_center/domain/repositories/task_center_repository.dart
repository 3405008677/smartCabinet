import 'package:smart_cabinet/src/features/identity_verification/domain/entities/operator_account.dart';
import 'package:smart_cabinet/src/features/task_center/domain/entities/cabinet_task.dart';

/// 操作员未完成任务操作要求的多因子认证。
final class OperatorFactorVerificationException implements Exception {
  /// 创建多因子认证不足异常。
  OperatorFactorVerificationException({
    required this.operatorId,
    required Set<IdentityFactor> verifiedFactors,
    this.requiredFactorCount = 3,
  }) : verifiedFactors = Set<IdentityFactor>.unmodifiable(verifiedFactors);

  /// 未满足认证要求的操作员 ID。
  final String operatorId;

  /// 当前会话已经通过的不同身份因子。
  final Set<IdentityFactor> verifiedFactors;

  /// 任务业务要求的最少不同身份因子数量。
  final int requiredFactorCount;

  @override
  String toString() {
    return '任务操作至少需要 $requiredFactorCount 种不同身份因子，'
        '当前仅通过 ${verifiedFactors.length} 种';
  }
}

/// 指定任务不存在或不再可执行。
final class CabinetTaskNotFoundException implements Exception {
  /// 创建任务不存在异常。
  const CabinetTaskNotFoundException(this.taskId);

  /// 未找到的任务 ID。
  final String taskId;

  @override
  String toString() => '未找到任务：$taskId';
}

/// 操作员尝试访问其他监管机构任务。
final class CabinetTaskOrganizationException implements Exception {
  /// 创建任务机构越权异常。
  const CabinetTaskOrganizationException({
    required this.taskId,
    required this.operatorOrganizationId,
    required this.taskOrganizationId,
  });

  /// 被访问的任务 ID。
  final String taskId;

  /// 当前操作员机构 ID。
  final String operatorOrganizationId;

  /// 任务所属机构 ID。
  final String taskOrganizationId;

  @override
  String toString() {
    return '机构无权访问任务：$taskId '
        '($operatorOrganizationId != $taskOrganizationId)';
  }
}

/// 请求箱格与当前监管机构的独占绑定冲突。
final class InstitutionSlotConflictException implements Exception {
  /// 创建机构箱格冲突异常。
  const InstitutionSlotConflictException({
    required this.doorNo,
    required this.requestedOrganizationId,
    required this.boundOrganizationId,
  });

  /// 发生冲突的柜门编号。
  final String doorNo;

  /// 请求使用箱格的机构 ID。
  final String requestedOrganizationId;

  /// 箱格实际绑定的机构 ID。
  final String boundOrganizationId;

  @override
  String toString() {
    return '箱格 $doorNo 已绑定机构 $boundOrganizationId，'
        '机构 $requestedOrganizationId 无权使用';
  }
}

/// 任务步骤未按平台规定顺序推进。
final class CabinetTaskStepOrderException implements Exception {
  /// 创建步骤顺序异常。
  const CabinetTaskStepOrderException({
    required this.expected,
    required this.actual,
  });

  /// 当前应完成的步骤。
  final TaskStepType expected;

  /// 调用方请求完成的步骤。
  final TaskStepType actual;

  @override
  String toString() => '任务步骤顺序错误：应为 $expected，实际为 $actual';
}

/// 平台任务步骤不符合当前任务类型的固定业务流程。
final class CabinetTaskWorkflowException implements Exception {
  /// 创建任务流程结构异常。
  const CabinetTaskWorkflowException({
    required this.taskId,
    required this.taskType,
    required this.message,
  });

  /// 流程结构异常的任务 ID。
  final String taskId;

  /// 当前任务声明的业务类型。
  final TaskType taskType;

  /// 便于平台排查的稳定原因。
  final String message;

  @override
  String toString() => '任务流程结构无效：$message（任务 $taskId，类型 $taskType）';
}

/// 取件码校验失败原因。
enum PickupCodeFailureReason {
  /// 当前任务不是取证或借证任务。
  wrongTaskType,

  /// 用户没有输入取件码。
  empty,

  /// 输入的取件码不正确。
  incorrect,

  /// 当前任务没有配置取件码。
  notConfigured,

  /// 当前尚未推进到取件码校验步骤。
  stepNotPending,

  /// 调用方试图绕过专用取件码校验入口。
  dedicatedEntryRequired,
}

/// 取件码未通过校验，任务步骤不会被推进。
final class PickupCodeVerificationException implements Exception {
  /// 创建取件码校验异常。
  const PickupCodeVerificationException({
    required this.taskId,
    required this.reason,
    this.currentStep,
  });

  /// 发生校验失败的任务 ID。
  final String taskId;

  /// 稳定的失败原因。
  final PickupCodeFailureReason reason;

  /// 失败时任务的当前步骤。
  final TaskStepType? currentStep;

  @override
  String toString() => '取件码校验失败：$reason（任务 $taskId）';
}

/// 取证或借证待办列表选择失败原因。
enum TaskItemSelectionFailure {
  /// 当前任务不是取证或借证任务。
  wrongTaskType,

  /// 当前步骤不允许更换开箱目标。
  stepNotReady,

  /// 指定证件不属于当前任务。
  itemNotFound,

  /// 指定证件已经处理完成。
  itemCompleted,
}

/// 待取证件不能成为当前开箱目标。
final class TaskItemSelectionException implements Exception {
  /// 创建待取证件选择异常。
  const TaskItemSelectionException({
    required this.taskId,
    required this.itemId,
    required this.failure,
    this.currentStep,
  });

  /// 当前任务 ID。
  final String taskId;

  /// 请求选择的证件 ID。
  final String itemId;

  /// 稳定失败原因。
  final TaskItemSelectionFailure failure;

  /// 失败时的当前步骤。
  final TaskStepType? currentStep;

  @override
  String toString() => '待取证件选择失败：$failure（任务 $taskId，证件 $itemId）';
}

/// 飞检码校验失败原因。
enum InventoryCodeFailureReason {
  /// 用户没有输入飞检码。
  empty,

  /// 输入的飞检码不正确。
  incorrect,

  /// 当前盘点计划没有配置飞检码。
  notConfigured,

  /// 当前任务尚未推进到飞检码校验步骤。
  stepNotPending,

  /// 调用方试图绕过专用飞检码校验入口。
  dedicatedEntryRequired,
}

/// 飞检码未通过校验，盘点计划不会被推进。
final class InventoryCodeVerificationException implements Exception {
  /// 创建飞检码校验异常。
  const InventoryCodeVerificationException({
    required this.taskId,
    required this.reason,
    this.currentStep,
  });

  /// 发生校验失败的盘点任务 ID。
  final String taskId;

  /// 稳定的失败原因。
  final InventoryCodeFailureReason reason;

  /// 失败时任务的当前步骤。
  final TaskStepType? currentStep;

  @override
  String toString() => '飞检码校验失败：$reason（任务 $taskId）';
}

/// 箱格级盘点操作失败原因。
enum InventoryOperationFailure {
  /// 当前任务不是盘点任务。
  wrongTaskType,

  /// 平台没有下发箱格级盘点计划。
  planMissing,

  /// 平台下发的盘点计划不满足箱格集合与抽样约束。
  planInvalid,

  /// 飞检码尚未通过校验。
  codeNotVerified,

  /// 当前任务步骤不能执行箱格盘点动作。
  stepNotReady,

  /// 请求箱格不在平台下发的柜体布局中。
  doorNotInPlan,

  /// 请求箱格未被本次抽盘命中。
  doorNotRequired,

  /// 请求箱格已经完成盘点。
  doorAlreadyCompleted,

  /// 另一箱格仍处于盘点状态。
  anotherDoorActive,

  /// 请求箱格不是当前正在盘点的箱格。
  doorNotActive,

  /// 当前箱格绑定与开箱时缓存的机构或门号不再一致。
  slotBindingChanged,

  /// RFID 为空。
  rfidEmpty,

  /// 调用方试图通过通用步骤入口绕过盘点专用入口。
  dedicatedEntryRequired,
}

/// 箱格级盘点操作不满足计划、步骤或门号约束。
final class InventoryOperationException implements Exception {
  /// 创建盘点操作异常。
  const InventoryOperationException({
    required this.taskId,
    required this.failure,
    this.doorNo,
    this.activeDoorNo,
    this.currentStep,
  });

  /// 发生失败的盘点任务 ID。
  final String taskId;

  /// 请求操作的箱格编号。
  final String? doorNo;

  /// 当前已被任务占用的箱格编号。
  final String? activeDoorNo;

  /// 失败时任务的当前步骤。
  final TaskStepType? currentStep;

  /// 稳定的失败原因。
  final InventoryOperationFailure failure;

  @override
  String toString() => '盘点操作失败：$failure（任务 $taskId，箱格 $doorNo）';
}

/// 开门前任务与证件箱格复核失败原因。
enum CabinetTaskDoorValidationFailure {
  /// 调用方试图绕过携带门号的专用开关门入口。
  dedicatedEntryRequired,

  /// 仓库中的最新任务尚未推进到开门步骤。
  stepNotReady,

  /// 平台尚未为任务确认箱格绑定。
  slotBindingMissing,

  /// 箱格绑定的监管机构与任务或操作员不一致。
  slotOrganizationMismatch,

  /// 任务不存在可继续处理的证件。
  currentItemMissing,

  /// 当前证件没有配置目标柜门。
  itemDoorMissing,

  /// 请求柜门不是当前证件要求的柜门。
  itemDoorMismatch,

  /// 平台箱格绑定与请求柜门不一致。
  bindingDoorMismatch,

  /// 平台权威箱格绑定与任务缓存不再一致。
  slotBindingChanged,

  /// 开门响应异常后的平台步骤无法安全回退到重新开门。
  recoveryStateInvalid,
}

/// 开门前任务、机构或证件门号复核失败。
final class CabinetTaskDoorValidationException implements Exception {
  /// 创建开门复核异常。
  const CabinetTaskDoorValidationException({
    required this.taskId,
    required this.requestedDoorNo,
    required this.failure,
    this.expectedDoorNo,
    this.currentStep,
    this.operatorOrganizationId,
    this.bindingOrganizationId,
  });

  /// 发生复核失败的任务 ID。
  final String taskId;

  /// 调用方准备打开的柜门编号。
  final String requestedDoorNo;

  /// 当前证件或绑定期望的柜门编号。
  final String? expectedDoorNo;

  /// 复核失败时仓库中的最新任务步骤。
  final TaskStepType? currentStep;

  /// 当前操作员机构 ID。
  final String? operatorOrganizationId;

  /// 平台箱格绑定的机构 ID。
  final String? bindingOrganizationId;

  /// 稳定的失败原因。
  final CabinetTaskDoorValidationFailure failure;

  @override
  String toString() => '柜门复核失败：$failure（任务 $taskId，柜门 $requestedDoorNo）';
}

/// 任务仍有步骤或证件未完成。
final class CabinetTaskIncompleteException implements Exception {
  /// 创建任务未完成异常。
  CabinetTaskIncompleteException({
    required this.taskId,
    required this.hasPendingStep,
    required List<String> incompleteItemIds,
  }) : incompleteItemIds = List<String>.unmodifiable(incompleteItemIds);

  /// 尚未满足完成条件的任务 ID。
  final String taskId;

  /// 是否仍存在待执行步骤。
  final bool hasPendingStep;

  /// 尚未完成的证件项 ID。
  final List<String> incompleteItemIds;

  @override
  String toString() => '任务仍有未完成步骤或证件：$taskId';
}

/// 登录后任务中心的数据边界。
abstract interface class TaskCenterRepository {
  /// 获取当前操作员所属机构的未完成任务。
  Future<List<CabinetTask>> fetchTasks(OperatorAccount account);

  /// 获取当前操作员有权执行的指定任务。
  Future<CabinetTask> fetchTask({
    required OperatorAccount account,
    required String taskId,
  });

  /// 请求平台为任务分配或确认一个机构专属箱格。
  Future<InstitutionSlotBinding> assignSlot({
    required OperatorAccount account,
    required String taskId,
    String? preferredDoorNo,
  });

  /// 校验取件码并原子推进取件码步骤，失败时不得修改任务。
  Future<CabinetTask> verifyPickupCode({
    required OperatorAccount account,
    required String taskId,
    required String pickupCode,
  });

  /// 在查看列表或授权箱格前选择任一尚未完成的取证/借证证件。
  Future<CabinetTask> selectTaskItem({
    required OperatorAccount account,
    required String taskId,
    required String itemId,
  });

  /// 校验飞检码并进入箱格级盘点明细，失败时不得修改任务。
  Future<CabinetTask> verifyInventoryCode({
    required OperatorAccount account,
    required String taskId,
    required String inspectionCode,
  });

  /// 开门前复核任务机构、箱格机构和当前证件门号。
  Future<InstitutionSlotBinding> validateDoorOpen({
    required OperatorAccount account,
    required String taskId,
    required String doorNo,
  });

  /// 柜门取得应用互锁后，按已复核门号原子完成开门步骤。
  Future<CabinetTask> confirmDoorOpened({
    required OperatorAccount account,
    required String taskId,
    required String doorNo,
  });

  /// 开门响应异常且人工确认关门后，将可能已提交的开门步骤安全回退。
  Future<CabinetTask> recoverDoorAfterOpenFailure({
    required OperatorAccount account,
    required String taskId,
    required String doorNo,
  });

  /// 实物门已确认关闭后先持久化待上报状态，成功后才允许释放应用互锁。
  Future<CabinetTask> recordDoorClosedPendingReport({
    required OperatorAccount account,
    required String taskId,
    required String doorNo,
  });

  /// 柜门明确关闭后，按匹配门号原子完成上报步骤。
  Future<CabinetTask> confirmDoorClosedAndReport({
    required OperatorAccount account,
    required String taskId,
    required String doorNo,
  });

  /// 盘点开箱前复核计划、机构和箱格绑定，但不改变任务状态。
  Future<InstitutionSlotBinding> validateInventoryDoorOpen({
    required OperatorAccount account,
    required String taskId,
    required String doorNo,
  });

  /// 柜门取得应用互锁后，将抽中箱格标记为正在盘点。
  Future<CabinetTask> startInventoryDoor({
    required OperatorAccount account,
    required String taskId,
    required String doorNo,
  });

  /// 在当前打开箱格中记录一次 RFID 扫描，重复扫描按幂等处理。
  Future<CabinetTask> scanInventoryRfid({
    required OperatorAccount account,
    required String taskId,
    required String doorNo,
    required String rfid,
  });

  /// 明确关门时标记未扫证件缺失、已扫证件放回并完成当前箱格。
  Future<CabinetTask> completeInventoryDoor({
    required OperatorAccount account,
    required String taskId,
    required String doorNo,
  });

  /// 顺序完成任务中的一个演示步骤。
  Future<CabinetTask> completeStep({
    required OperatorAccount account,
    required String taskId,
    required TaskStepType stepType,
  });

  /// 在全部步骤完成后提交任务完成状态。
  Future<CabinetTask> completeTask({
    required OperatorAccount account,
    required String taskId,
  });
}
