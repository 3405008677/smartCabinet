/// 取件展示模型。
class PickupData {
  /// 创建取件展示模型。
  const PickupData({
    required this.personName,
    required this.personTitle,
    required this.employeeCode,
    required this.phone,
    required this.idCard,
    required this.organization,
    required this.permissionLevel,
    required this.faceResult,
    required this.fingerprintResult,
    required this.nfcResult,
    required this.pickupCodeResult,
    required this.doorNo,
    required this.doorLocation,
    required this.fileName,
    required this.pickupSuccessSummary,
  });

  /// 页面首帧兜底展示数据。
  factory PickupData.fallback() {
    return PickupData.fromMap(const {
      'personName': '张晓明',
      'personTitle': '涉密文件取件人',
      'employeeCode': 'EMP-2026-0612',
      'phone': '138****6721',
      'idCard': '1101**********3219',
      'organization': '法务合规部',
      'permissionLevel': 'L3 · 取件权限',
      'faceResult': '已通过',
      'fingerprintResult': '已通过',
      'nfcResult': '已通过',
      'pickupCodeResult': '已通过',
      'doorNo': 'A-08',
      'doorLocation': 'A区第2列第4格 · 标准文件柜 · 已锁定',
      'fileName': '合格证原件',
      'pickupSuccessSummary': '已取出 1 份文件 · 柜门 A-08 · 已写入审计日志',
    });
  }

  /// 取件人姓名。
  final String personName;

  /// 取件人在界面上展示的职位或身份标签。
  final String personTitle;

  /// 取件人工号。
  final String employeeCode;

  /// 取件人联系电话。
  final String phone;

  /// 取件人证件号码。
  final String idCard;

  /// 取件人所属组织或部门。
  final String organization;

  /// 取件人当前拥有的操作权限等级。
  final String permissionLevel;

  /// 人脸识别步骤展示给用户的结果文案。
  final String faceResult;

  /// 指纹识别步骤展示给用户的结果文案。
  final String fingerprintResult;

  /// NFC 识别步骤展示给用户的结果文案。
  final String nfcResult;

  /// 取件码验证步骤展示给用户的结果文案。
  final String pickupCodeResult;

  /// 需要打开的柜门编号。
  final String doorNo;

  /// 柜门所在的物理位置说明，例如区域、排号或层号。
  final String doorLocation;

  /// 当前待取文件名称。
  final String fileName;

  /// 取件成功页底部或结果区域使用的总结文案。
  final String pickupSuccessSummary;

  /// 从接口返回的 Map 结构创建取件展示模型。
  ///
  /// 这里假设字段已经在 DTO 或上游接口层完成基本校验，
  /// 因此直接按预期字段取值并转换为强类型属性。
  factory PickupData.fromMap(Map<String, Object> map) {
    return PickupData(
      personName: map['personName'] as String,
      personTitle: map['personTitle'] as String,
      employeeCode: map['employeeCode'] as String,
      phone: map['phone'] as String,
      idCard: map['idCard'] as String,
      organization: map['organization'] as String,
      permissionLevel: map['permissionLevel'] as String,
      faceResult: map['faceResult'] as String,
      fingerprintResult: map['fingerprintResult'] as String,
      nfcResult: map['nfcResult'] as String,
      pickupCodeResult: map['pickupCodeResult'] as String,
      doorNo: map['doorNo'] as String,
      doorLocation: map['doorLocation'] as String,
      fileName: map['fileName'] as String,
      pickupSuccessSummary: map['pickupSuccessSummary'] as String,
    );
  }

  /// 转为 JSON 结构。
  ///
  /// 主要用于调试输出、测试断言或后续本地缓存持久化场景。
  Map<String, Object> toJson() {
    return {
      'personName': personName,
      'personTitle': personTitle,
      'employeeCode': employeeCode,
      'phone': phone,
      'idCard': idCard,
      'organization': organization,
      'permissionLevel': permissionLevel,
      'faceResult': faceResult,
      'fingerprintResult': fingerprintResult,
      'nfcResult': nfcResult,
      'pickupCodeResult': pickupCodeResult,
      'doorNo': doorNo,
      'doorLocation': doorLocation,
      'fileName': fileName,
      'pickupSuccessSummary': pickupSuccessSummary,
    };
  }
}
