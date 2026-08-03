import 'package:smart_cabinet/src/features/task_center/domain/entities/cabinet_task.dart';
import 'package:smart_cabinet/src/features/task_center/domain/repositories/task_center_repository.dart';

/// 任务中心使用的数据源边界。
abstract interface class TaskCenterDataSource {
  /// 按机构读取任务。
  Future<List<CabinetTask>> fetchTasksByOrganization(String organizationId);

  /// 按 ID 读取任务，不在此层隐藏机构信息。
  Future<CabinetTask?> fetchTaskById(String taskId);

  /// 保存更新后的任务。
  Future<void> saveTask(CabinetTask task);

  /// 获取并校验指定机构可使用的箱格绑定。
  Future<InstitutionSlotBinding> resolveSlot({
    required String organizationId,
    String? preferredDoorNo,
  });
}

/// 基于内存数据的任务中心数据源。
///
/// 该实现用于页面演示和测试。箱格绑定采用独占模型：一个柜门一旦绑定机构，
/// 其他机构即使当前没有任务也不能复用该柜门。
final class FakeTaskCenterDataSource implements TaskCenterDataSource {
  /// 创建可注入测试数据的假数据源。
  FakeTaskCenterDataSource({
    required List<CabinetTask> tasks,
    required List<InstitutionSlotBinding> slotBindings,
  }) : _tasks = {for (final task in tasks) task.id: task},
       _slotBindings = {
         for (final binding in slotBindings) binding.doorNo: binding,
       };

  /// 创建包含三家监管机构和主演示任务的默认数据源。
  factory FakeTaskCenterDataSource.seeded() {
    const orgOneId = 'org-001';
    const orgOneName = '市市场监督管理局';
    const orgTwoId = 'org-002';
    const orgTwoName = '市公安局';

    return FakeTaskCenterDataSource(
      tasks: [
        _buildTask(
          id: 'TASK-STORE-001',
          type: TaskType.storeEvidence,
          title: '存证任务 · 合格证原件',
          organizationId: orgOneId,
          organizationName: orgOneName,
          doorNo: 'A-01',
        ),
        _buildTask(
          id: 'TASK-RETRIEVE-001',
          type: TaskType.retrieveEvidence,
          title: '取证任务 · 企业登记档案',
          organizationId: orgOneId,
          organizationName: orgOneName,
          doorNo: 'A-02',
          pickupCode: '82640135',
        ),
        _buildTask(
          id: 'TASK-BORROW-001',
          type: TaskType.borrowEvidence,
          title: '借证任务 · 执法检查材料',
          organizationId: orgOneId,
          organizationName: orgOneName,
          doorNo: 'A-03',
          pickupCode: '73051826',
          itemCount: 2,
        ),
        _buildTask(
          id: 'TASK-RETURN-001',
          type: TaskType.returnEvidence,
          title: '还证任务 · 许可证副本',
          organizationId: orgOneId,
          organizationName: orgOneName,
          doorNo: 'A-04',
        ),
        _buildInventoryTask(
          id: 'TASK-INVENTORY-001',
          title: '盘点任务 · A 区季度盘点',
          organizationId: orgOneId,
          organizationName: orgOneName,
          inspectionCode: '593826',
          samplingMode: InventorySamplingMode.byBoxRatio,
          allDoorNos: const ['A-05', 'A-06', 'A-07', 'A-08'],
          requiredDoorNos: const ['A-05', 'A-06'],
          boxSampleRatio: 0.5,
          items: const [
            TaskItem(
              id: 'TASK-INVENTORY-001-A05-01',
              documentCode: 'CERT-A05-001',
              documentName: '食品经营许可证',
              rfid: 'RFID-A05-0001',
              doorNo: 'A-05',
            ),
            TaskItem(
              id: 'TASK-INVENTORY-001-A05-02',
              documentCode: 'CERT-A05-002',
              documentName: '产品合格证',
              rfid: 'RFID-A05-0002',
              doorNo: 'A-05',
            ),
            TaskItem(
              id: 'TASK-INVENTORY-001-A06-01',
              documentCode: 'CERT-A06-001',
              documentName: '检验报告原件',
              rfid: 'RFID-A06-0001',
              doorNo: 'A-06',
            ),
            TaskItem(
              id: 'TASK-INVENTORY-001-A07-01',
              documentCode: 'CERT-A07-001',
              documentName: '企业登记档案',
              rfid: 'RFID-A07-0001',
              doorNo: 'A-07',
            ),
            TaskItem(
              id: 'TASK-INVENTORY-001-A08-01',
              documentCode: 'CERT-A08-001',
              documentName: '执法检查材料',
              rfid: 'RFID-A08-0001',
              doorNo: 'A-08',
            ),
          ],
        ),
        _buildInventoryTask(
          id: 'TASK-ORG2-001',
          title: '公安档案盘点任务',
          organizationId: orgTwoId,
          organizationName: orgTwoName,
          inspectionCode: '271904',
          samplingMode: InventorySamplingMode.specifiedDocuments,
          allDoorNos: const ['B-01', 'B-02'],
          requiredDoorNos: const ['B-01'],
          specifiedDocumentCodes: const ['CERT-B01-001'],
          items: const [
            TaskItem(
              id: 'TASK-ORG2-001-B01-01',
              documentCode: 'CERT-B01-001',
              documentName: '指定治安档案',
              rfid: 'RFID-B01-0001',
              doorNo: 'B-01',
            ),
            TaskItem(
              id: 'TASK-ORG2-001-B01-02',
              documentCode: 'CERT-B01-002',
              documentName: '同箱关联档案',
              rfid: 'RFID-B01-0002',
              doorNo: 'B-01',
            ),
            TaskItem(
              id: 'TASK-ORG2-001-B02-01',
              documentCode: 'CERT-B02-001',
              documentName: '未抽中档案',
              rfid: 'RFID-B02-0001',
              doorNo: 'B-02',
            ),
          ],
        ),
      ],
      slotBindings: const [
        InstitutionSlotBinding(
          cabinetId: 'CAB-A01',
          doorNo: 'A-01',
          organizationId: orgOneId,
          organizationName: orgOneName,
        ),
        InstitutionSlotBinding(
          cabinetId: 'CAB-A01',
          doorNo: 'A-02',
          organizationId: orgOneId,
          organizationName: orgOneName,
        ),
        InstitutionSlotBinding(
          cabinetId: 'CAB-A01',
          doorNo: 'A-03',
          organizationId: orgOneId,
          organizationName: orgOneName,
        ),
        InstitutionSlotBinding(
          cabinetId: 'CAB-A01',
          doorNo: 'A-04',
          organizationId: orgOneId,
          organizationName: orgOneName,
        ),
        InstitutionSlotBinding(
          cabinetId: 'CAB-A01',
          doorNo: 'A-05',
          organizationId: orgOneId,
          organizationName: orgOneName,
        ),
        InstitutionSlotBinding(
          cabinetId: 'CAB-A01',
          doorNo: 'A-06',
          organizationId: orgOneId,
          organizationName: orgOneName,
        ),
        InstitutionSlotBinding(
          cabinetId: 'CAB-A01',
          doorNo: 'A-07',
          organizationId: orgOneId,
          organizationName: orgOneName,
        ),
        InstitutionSlotBinding(
          cabinetId: 'CAB-A01',
          doorNo: 'A-08',
          organizationId: orgOneId,
          organizationName: orgOneName,
        ),
        InstitutionSlotBinding(
          cabinetId: 'CAB-A01',
          doorNo: 'B-01',
          organizationId: orgTwoId,
          organizationName: orgTwoName,
        ),
        InstitutionSlotBinding(
          cabinetId: 'CAB-A01',
          doorNo: 'B-02',
          organizationId: orgTwoId,
          organizationName: orgTwoName,
        ),
      ],
    );
  }

  final Map<String, CabinetTask> _tasks;
  final Map<String, InstitutionSlotBinding> _slotBindings;

  @override
  Future<List<CabinetTask>> fetchTasksByOrganization(
    String organizationId,
  ) async {
    return List<CabinetTask>.unmodifiable(
      _tasks.values.where(
        (task) => task.organizationId == organizationId && !task.isCompleted,
      ),
    );
  }

  @override
  Future<CabinetTask?> fetchTaskById(String taskId) async => _tasks[taskId];

  @override
  Future<void> saveTask(CabinetTask task) async {
    _tasks[task.id] = task;
  }

  @override
  Future<InstitutionSlotBinding> resolveSlot({
    required String organizationId,
    String? preferredDoorNo,
  }) async {
    if (preferredDoorNo != null) {
      final binding = _slotBindings[preferredDoorNo];
      if (binding == null) {
        throw StateError('平台未配置箱格：$preferredDoorNo');
      }
      if (binding.organizationId != organizationId) {
        throw InstitutionSlotConflictException(
          doorNo: preferredDoorNo,
          requestedOrganizationId: organizationId,
          boundOrganizationId: binding.organizationId,
        );
      }
      return binding;
    }

    for (final binding in _slotBindings.values) {
      if (binding.organizationId == organizationId) {
        return binding;
      }
    }
    throw StateError('当前机构没有可用的专属箱格：$organizationId');
  }
}

/// 构建一条默认任务。
CabinetTask _buildTask({
  required String id,
  required TaskType type,
  required String title,
  required String organizationId,
  required String organizationName,
  required String doorNo,
  String? pickupCode,
  int itemCount = 1,
}) {
  return CabinetTask(
    id: id,
    type: type,
    title: title,
    organizationId: organizationId,
    organizationName: organizationName,
    pickupCode: pickupCode,
    items: [
      for (var index = 1; index <= itemCount; index++)
        TaskItem(
          id: '$id-ITEM-${index.toString().padLeft(2, '0')}',
          documentCode:
              'DOC-${id.split('-').last}-${index.toString().padLeft(2, '0')}',
          documentName: itemCount == 1
              ? title.split('·').last.trim()
              : '${title.split('·').last.trim()} $index',
          rfid:
              'RFID-${id.split('-').last}-${index.toString().padLeft(4, '0')}',
          doorNo: doorNo,
        ),
    ],
    steps: _buildSteps(type),
  );
}

/// 构建由平台预先抽取箱格的盘点任务。
CabinetTask _buildInventoryTask({
  required String id,
  required String title,
  required String organizationId,
  required String organizationName,
  required String inspectionCode,
  required InventorySamplingMode samplingMode,
  required List<String> allDoorNos,
  required List<String> requiredDoorNos,
  required List<TaskItem> items,
  double? boxSampleRatio,
  List<String> specifiedDocumentCodes = const [],
}) {
  return CabinetTask(
    id: id,
    type: TaskType.inventory,
    title: title,
    organizationId: organizationId,
    organizationName: organizationName,
    items: List<TaskItem>.unmodifiable(items),
    steps: _buildSteps(TaskType.inventory),
    inventoryPlan: InventoryPlan(
      inspectionCode: inspectionCode,
      samplingMode: samplingMode,
      allDoorNos: List<String>.unmodifiable(allDoorNos),
      requiredDoorNos: List<String>.unmodifiable(requiredDoorNos),
      boxSampleRatio: boxSampleRatio,
      specifiedDocumentCodes: List<String>.unmodifiable(specifiedDocumentCodes),
    ),
  );
}

/// 按任务类型创建演示步骤。
List<TaskStep> _buildSteps(TaskType type) {
  final stepTypes = requiredTaskStepTypes(type);
  return List<TaskStep>.unmodifiable(
    stepTypes.map((type) => TaskStep(type: type)),
  );
}
