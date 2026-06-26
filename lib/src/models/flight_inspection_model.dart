/// 飞检任务模型。
class FlightInspectionTaskModel {
  /// 创建飞检任务模型。
  const FlightInspectionTaskModel({
    required this.doorNo,
    required this.fileCode,
    required this.secretLevel,
    required this.department,
  });

  /// 待飞检的柜门编号。
  final String doorNo;

  /// 当前柜门对应的文件编号。
  final String fileCode;

  /// 文件密级。
  final String secretLevel;

  /// 文件所属部门。
  final String department;

  /// 从接口返回的 Map 结构创建单个飞检任务模型。
  factory FlightInspectionTaskModel.fromMap(Map<String, Object> map) {
    return FlightInspectionTaskModel(
      doorNo: map['doorNo'] as String,
      fileCode: map['fileCode'] as String,
      secretLevel: map['secretLevel'] as String,
      department: map['department'] as String,
    );
  }

  /// 转为 JSON 结构。
  ///
  /// 方便测试断言、日志打印和后续缓存落地。
  Map<String, Object> toJson() {
    return {
      'doorNo': doorNo,
      'fileCode': fileCode,
      'secretLevel': secretLevel,
      'department': department,
    };
  }
}

/// 飞检展示模型。
class FlightInspectionModel {
  /// 创建飞检展示模型。
  const FlightInspectionModel({
    required this.inspectorName,
    required this.employeeCode,
    required this.permissionLevel,
    required this.batchNo,
    required this.tasks,
  });

  /// 飞检人员姓名。
  final String inspectorName;

  /// 飞检人员工号。
  final String employeeCode;

  /// 飞检人员权限等级。
  final String permissionLevel;

  /// 当前飞检任务批次号。
  final String batchNo;

  /// 当前批次下发的全部柜门飞检任务。
  final List<FlightInspectionTaskModel> tasks;

  /// 从接口返回的 Map 结构创建飞检展示模型。
  ///
  /// [tasks] 字段会进一步映射为强类型的 [FlightInspectionTaskModel] 列表，
  /// 便于页面层安全读取，而不直接操作动态类型集合。
  factory FlightInspectionModel.fromMap(Map<String, Object> map) {
    final rawTasks = map['tasks'] as List<dynamic>;
    return FlightInspectionModel(
      inspectorName: map['inspectorName'] as String,
      employeeCode: map['employeeCode'] as String,
      permissionLevel: map['permissionLevel'] as String,
      batchNo: map['batchNo'] as String,
      tasks: rawTasks
          .map(
            (task) =>
                FlightInspectionTaskModel.fromMap(task as Map<String, Object>),
          )
          .toList(),
    );
  }

  /// 转为 JSON 结构。
  ///
  /// 主要服务于测试、调试和未来可能的缓存落地场景。
  Map<String, Object> toJson() {
    return {
      'inspectorName': inspectorName,
      'employeeCode': employeeCode,
      'permissionLevel': permissionLevel,
      'batchNo': batchNo,
      'tasks': tasks.map((task) => task.toJson()).toList(),
    };
  }
}
