/// 放件展示模型。
class DropoffData {
  /// 创建放件展示模型。
  const DropoffData({
    required this.personName,
    required this.employeeCode,
    required this.department,
    required this.permissionLevel,
    required this.fileCode,
    required this.fileName,
    required this.frcResult,
    required this.doorNo,
    required this.doorLocation,
    required this.openDoorTitle,
    required this.successSummary,
  });

  /// 页面首帧兜底展示数据。
  factory DropoffData.fallback() {
    return DropoffData.fromMap(const {
      'personName': '张晓明',
      'employeeCode': 'EMP-2026-0612',
      'department': '法务合规部',
      'permissionLevel': 'L3 · 文件存放权限',
      'fileCode': 'FILE-2026-001',
      'fileName': '合格证原件',
      'frcResult': '已匹配',
      'doorNo': 'A-08',
      'doorLocation': 'A区第2列第4格 · 标准文件柜 · 待开门',
      'openDoorTitle': '柜门 A-08 已打开',
      'successSummary': '已存入 1 份文件 · 柜门 A-08 · 已写入审计日志',
    });
  }

  /// 放件人员姓名。
  final String personName;

  /// 放件人员工号。
  final String employeeCode;

  /// 放件人员所属部门。
  final String department;

  /// 放件人员当前拥有的权限等级。
  final String permissionLevel;

  /// 本次待放文件对应的文件编号。
  final String fileCode;

  /// 本次待放文件的展示名称。
  final String fileName;

  /// 文件认证结果或 FRC 校验文案。
  final String frcResult;

  /// 需要打开的柜门编号。
  final String doorNo;

  /// 柜门所在位置描述。
  final String doorLocation;

  /// 开柜确认页使用的主标题文案。
  final String openDoorTitle;

  /// 放件成功页使用的总结文案。
  final String successSummary;

  /// 从接口返回的 Map 结构创建放件展示模型。
  factory DropoffData.fromMap(Map<String, Object> map) {
    return DropoffData(
      personName: map['personName'] as String,
      employeeCode: map['employeeCode'] as String,
      department: map['department'] as String,
      permissionLevel: map['permissionLevel'] as String,
      fileCode: map['fileCode'] as String,
      fileName: map['fileName'] as String,
      frcResult: map['frcResult'] as String,
      doorNo: map['doorNo'] as String,
      doorLocation: map['doorLocation'] as String,
      openDoorTitle: map['openDoorTitle'] as String,
      successSummary: map['successSummary'] as String,
    );
  }

  /// 转为 JSON 结构。
  ///
  /// 用于测试校验、日志输出或后续缓存持久化场景。
  Map<String, Object> toJson() {
    return {
      'personName': personName,
      'employeeCode': employeeCode,
      'department': department,
      'permissionLevel': permissionLevel,
      'fileCode': fileCode,
      'fileName': fileName,
      'frcResult': frcResult,
      'doorNo': doorNo,
      'doorLocation': doorLocation,
      'openDoorTitle': openDoorTitle,
      'successSummary': successSummary,
    };
  }
}
