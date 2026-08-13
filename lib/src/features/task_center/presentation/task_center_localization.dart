import 'package:flutter/widgets.dart';

import 'package:smart_cabinet/src/app/localization/app_localizations.dart';
import 'package:smart_cabinet/src/features/task_center/domain/entities/cabinet_task.dart';
import 'package:smart_cabinet/src/features/task_center/domain/repositories/task_center_repository.dart';

/// 返回任务类型的界面标题。
String localizedTaskTypeTitle(BuildContext context, TaskType type) {
  final l10n = context.l10n;
  return switch (type) {
    TaskType.storeEvidence => l10n.t('taskTypeStoreEvidence', '存证'),
    TaskType.retrieveEvidence => l10n.t('taskTypeRetrieveEvidence', '取证'),
    TaskType.borrowEvidence => l10n.t('taskTypeBorrowEvidence', '借证'),
    TaskType.returnEvidence => l10n.t('taskTypeReturnEvidence', '还证'),
    TaskType.inventory => l10n.t('taskTypeInventory', '盘点'),
  };
}

/// 本地化内置演示任务标题；平台下发的业务专名保持原样。
String localizedTaskTitle(BuildContext context, CabinetTask task) {
  return switch (task.id) {
    'TASK-STORE-001' => _taskTitleWithDocument(
      context,
      task.type,
      _documentText(context, 'taskDemoDocumentCertificateOriginal', '合格证原件'),
    ),
    'TASK-RETRIEVE-001' => _taskTitleWithDocument(
      context,
      task.type,
      _documentText(
        context,
        'taskDemoDocumentEnterpriseRegistrationArchive',
        '企业登记档案',
      ),
    ),
    'TASK-BORROW-001' => _taskTitleWithDocument(
      context,
      task.type,
      _documentText(
        context,
        'taskDemoDocumentEnforcementInspectionMaterials',
        '执法检查材料',
      ),
    ),
    'TASK-RETURN-001' => _taskTitleWithDocument(
      context,
      task.type,
      _documentText(context, 'taskDemoDocumentLicenseCopy', '许可证副本'),
    ),
    'TASK-INVENTORY-001' => context.l10n.t(
      'taskDemoInventoryTitleZoneAQuarterly',
      '盘点任务 · A 区季度盘点',
    ),
    'TASK-ORG2-001' => context.l10n.t(
      'taskDemoInventoryTitlePublicSecurityArchives',
      '公安档案盘点任务',
    ),
    _ => task.title,
  };
}

/// 本地化内置演示证件名称；平台下发的证件业务专名保持原样。
String localizedTaskItemName(BuildContext context, TaskItem item) {
  if (item.isInventorySurplus) {
    return context.l10n.t('taskInventorySurplusDocument', '未登记证件');
  }

  if (item.id.startsWith('TASK-STORE-001-')) {
    return _documentText(
      context,
      'taskDemoDocumentCertificateOriginal',
      '合格证原件',
    );
  }
  if (item.id.startsWith('TASK-RETRIEVE-001-')) {
    return _documentText(
      context,
      'taskDemoDocumentEnterpriseRegistrationArchive',
      '企业登记档案',
    );
  }
  if (item.id.startsWith('TASK-BORROW-001-')) {
    final document = _documentText(
      context,
      'taskDemoDocumentEnforcementInspectionMaterials',
      '执法检查材料',
    );
    final index = int.tryParse(item.id.split('-').last);
    if (index == null) {
      return document;
    }
    return context.l10n
        .t('taskDemoDocumentIndexed', '{document} {index}')
        .replaceAll('{document}', document)
        .replaceAll('{index}', '$index');
  }
  if (item.id.startsWith('TASK-RETURN-001-')) {
    return _documentText(context, 'taskDemoDocumentLicenseCopy', '许可证副本');
  }

  return switch (item.documentCode) {
    'CERT-A05-001' => _documentText(
      context,
      'taskDemoDocumentFoodBusinessLicense',
      '食品经营许可证',
    ),
    'CERT-A05-002' => _documentText(
      context,
      'taskDemoDocumentProductCertificate',
      '产品合格证',
    ),
    'CERT-A06-001' => _documentText(
      context,
      'taskDemoDocumentInspectionReportOriginal',
      '检验报告原件',
    ),
    'CERT-A07-001' => _documentText(
      context,
      'taskDemoDocumentEnterpriseRegistrationArchive',
      '企业登记档案',
    ),
    'CERT-A08-001' => _documentText(
      context,
      'taskDemoDocumentEnforcementInspectionMaterials',
      '执法检查材料',
    ),
    'CERT-B01-001' => _documentText(
      context,
      'taskDemoDocumentSpecifiedSecurityArchive',
      '指定治安档案',
    ),
    'CERT-B01-002' => _documentText(
      context,
      'taskDemoDocumentRelatedArchive',
      '同箱关联档案',
    ),
    'CERT-B02-001' => _documentText(
      context,
      'taskDemoDocumentUnselectedArchive',
      '未抽中档案',
    ),
    _ => item.documentName,
  };
}

/// 本地化内置演示账号岗位；平台返回的业务岗位名称保持原样。
String localizedOperatorPosition(BuildContext context, String position) {
  return switch (position) {
    '监管专员' => context.l10n.t('operatorPositionRegulatorySpecialist', '监管专员'),
    '监管员' => context.l10n.t('operatorPositionRegulator', '监管员'),
    '档案管理员' => context.l10n.t('operatorPositionArchiveAdministrator', '档案管理员'),
    '业务专员' => context.l10n.t('operatorPositionOperationsSpecialist', '业务专员'),
    _ => position,
  };
}

/// 本地化内置演示账号性别；平台返回的其他业务值保持原样。
String localizedOperatorGender(BuildContext context, String gender) {
  return switch (gender) {
    '男' => context.l10n.t('operatorGenderMale', '男'),
    '女' => context.l10n.t('operatorGenderFemale', '女'),
    _ => gender,
  };
}

/// 把领域异常映射为稳定、可翻译且不泄露内部状态的用户提示。
String localizedTaskError(BuildContext context, Object error) {
  final l10n = context.l10n;
  return switch (error) {
    OperatorFactorVerificationException() => l10n.t(
      'taskErrorAuthenticationRequired',
      '身份认证状态已失效，请重新登录',
    ),
    CabinetTaskNotFoundException() => l10n.t(
      'taskErrorNotFound',
      '任务不存在或已不可执行，请返回任务工作台刷新',
    ),
    CabinetTaskOrganizationException() => l10n.t(
      'taskErrorOrganizationUnauthorized',
      '当前机构无权访问此任务',
    ),
    InstitutionSlotConflictException conflict =>
      l10n
          .t(
            'taskExecutionInstitutionSlotConflict',
            '箱格 {doorNo} 已绑定其他机构，当前机构无权使用',
          )
          .replaceAll('{doorNo}', conflict.doorNo),
    CabinetTaskStepOrderException() => l10n.t(
      'taskErrorStateChanged',
      '任务状态已更新，请刷新后重试',
    ),
    CabinetTaskWorkflowException() => l10n.t(
      'taskErrorWorkflowInvalid',
      '平台下发的任务流程异常，请联系平台处理',
    ),
    PickupCodeVerificationException pickupError => _pickupCodeError(
      context,
      pickupError.reason,
    ),
    TaskItemSelectionException selectionError => _taskItemSelectionError(
      context,
      selectionError.failure,
    ),
    InventoryCodeVerificationException inventoryCodeError =>
      _inventoryCodeError(context, inventoryCodeError.reason),
    InventoryOperationException inventoryError => _inventoryOperationError(
      context,
      inventoryError,
    ),
    CabinetTaskDoorValidationException() => l10n.t(
      'taskExecutionDoorValidationFailed',
      '任务箱格信息已变更，请返回任务工作台刷新',
    ),
    CabinetTaskIncompleteException() => l10n.t(
      'taskErrorIncomplete',
      '任务仍有未完成的步骤或证件，请完成后再提交',
    ),
    _ => l10n.t('taskErrorUnexpected', '操作失败，请稍后重试'),
  };
}

String _taskTitleWithDocument(
  BuildContext context,
  TaskType type,
  String document,
) {
  return context.l10n
      .t('taskDemoTitleWithDocument', '{type}任务 · {document}')
      .replaceAll('{type}', localizedTaskTypeTitle(context, type))
      .replaceAll('{document}', document);
}

String _documentText(BuildContext context, String key, String fallback) {
  return context.l10n.t(key, fallback);
}

String _pickupCodeError(BuildContext context, PickupCodeFailureReason reason) {
  return switch (reason) {
    PickupCodeFailureReason.empty => context.l10n.t(
      'taskExecutionPickupCodeEmpty',
      '请输入取件码',
    ),
    PickupCodeFailureReason.incorrect => context.l10n.t(
      'taskExecutionPickupCodeIncorrect',
      '取件码错误，请重新输入',
    ),
    PickupCodeFailureReason.notConfigured => context.l10n.t(
      'taskExecutionPickupCodeNotConfigured',
      '当前任务未配置取件码，请联系平台处理',
    ),
    PickupCodeFailureReason.wrongTaskType ||
    PickupCodeFailureReason.stepNotPending ||
    PickupCodeFailureReason.dedicatedEntryRequired => context.l10n.t(
      'taskExecutionPickupCodeUnavailable',
      '当前步骤无法校验取件码，请刷新任务',
    ),
  };
}

String _taskItemSelectionError(
  BuildContext context,
  TaskItemSelectionFailure failure,
) {
  return switch (failure) {
    TaskItemSelectionFailure.itemNotFound => context.l10n.t(
      'taskErrorItemNotFound',
      '未找到该待办证件，请刷新任务后重试',
    ),
    TaskItemSelectionFailure.itemCompleted => context.l10n.t(
      'taskErrorItemAlreadyCompleted',
      '该证件已经处理完成，请选择其他待办证件',
    ),
    TaskItemSelectionFailure.wrongTaskType ||
    TaskItemSelectionFailure.stepNotReady => context.l10n.t(
      'taskErrorItemSelectionUnavailable',
      '当前步骤不能更换待办证件，请刷新任务',
    ),
  };
}

String _inventoryCodeError(
  BuildContext context,
  InventoryCodeFailureReason reason,
) {
  return switch (reason) {
    InventoryCodeFailureReason.empty => context.l10n.t(
      'taskInventoryCodeEmpty',
      '请输入飞检码',
    ),
    InventoryCodeFailureReason.incorrect => context.l10n.t(
      'taskInventoryCodeIncorrect',
      '飞检码错误，请重新输入',
    ),
    InventoryCodeFailureReason.notConfigured => context.l10n.t(
      'taskInventoryCodeNotConfigured',
      '当前盘点任务未配置飞检码，请联系平台处理',
    ),
    InventoryCodeFailureReason.stepNotPending ||
    InventoryCodeFailureReason.dedicatedEntryRequired => context.l10n.t(
      'taskInventoryCodeUnavailable',
      '当前步骤无法校验飞检码，请刷新任务',
    ),
  };
}

String _inventoryOperationError(
  BuildContext context,
  InventoryOperationException error,
) {
  final l10n = context.l10n;
  return switch (error.failure) {
    InventoryOperationFailure.planMissing => l10n.t(
      'taskInventoryPlanMissing',
      '平台未下发盘点计划',
    ),
    InventoryOperationFailure.planInvalid => l10n.t(
      'taskInventoryPlanInvalid',
      '平台下发的盘点计划异常，请联系平台处理',
    ),
    InventoryOperationFailure.codeNotVerified => l10n.t(
      'taskInventoryCodeVerificationRequired',
      '请先验证飞检码',
    ),
    InventoryOperationFailure.doorNotInPlan ||
    InventoryOperationFailure.doorNotRequired => l10n.t(
      'taskInventoryDoorUnavailable',
      '该箱格不在本次盘点范围内',
    ),
    InventoryOperationFailure.doorAlreadyCompleted => l10n.t(
      'taskInventoryDoorAlreadyCompleted',
      '该箱格已经完成盘点，可直接查看盘点结果',
    ),
    InventoryOperationFailure.anotherDoorActive =>
      error.activeDoorNo == null
          ? l10n.t('taskErrorStateChanged', '任务状态已更新，请刷新后重试')
          : l10n
                .t(
                  'taskInventoryAnotherDoorActive',
                  '箱格 {doorNo} 仍在盘点中，请先完成并关门',
                )
                .replaceAll('{doorNo}', error.activeDoorNo!),
    InventoryOperationFailure.rfidEmpty => l10n.t(
      'taskInventoryRfidEmpty',
      '请扫描或输入 RFID',
    ),
    InventoryOperationFailure.slotBindingChanged => l10n.t(
      'taskExecutionDoorValidationFailed',
      '任务箱格信息已变更，请返回任务工作台刷新',
    ),
    InventoryOperationFailure.stepNotReady ||
    InventoryOperationFailure.doorNotActive ||
    InventoryOperationFailure.dedicatedEntryRequired => l10n.t(
      'taskErrorStateChanged',
      '任务状态已更新，请刷新后重试',
    ),
    InventoryOperationFailure.wrongTaskType => l10n.t(
      'taskErrorWorkflowInvalid',
      '平台下发的任务流程异常，请联系平台处理',
    ),
  };
}
