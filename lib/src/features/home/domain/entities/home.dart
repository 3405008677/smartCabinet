/// 首页统计数据模型。
class HomeStats {
  /// 创建首页统计数据模型。
  const HomeStats({
    required this.documentCount,
    required this.occupiedSlots,
    required this.pendingPickup,
    required this.todayStored,
    required this.todayPickedUp,
    required this.occupancyRateText,
    required this.occupancyRateValue,
  });

  /// 柜内文件数量。
  final String documentCount;

  /// 已用格位数量。
  final String occupiedSlots;

  /// 待取件数量。
  final String pendingPickup;

  /// 今日存入数量。
  final String todayStored;

  /// 今日取出数量。
  final String todayPickedUp;

  /// 占用率文本。
  final String occupancyRateText;

  /// 占用率数值。
  final double occupancyRateValue;

  /// 从接口数据创建模型。
  factory HomeStats.fromMap(Map<String, Object> map) {
    return HomeStats(
      documentCount: map['documentCount'] as String,
      occupiedSlots: map['occupiedSlots'] as String,
      pendingPickup: map['pendingPickup'] as String,
      todayStored: map['todayStored'] as String,
      todayPickedUp: map['todayPickedUp'] as String,
      occupancyRateText: map['occupancyRateText'] as String,
      occupancyRateValue: (map['occupancyRateValue'] as num).toDouble(),
    );
  }

  /// 转为 JSON 结构。
  Map<String, Object> toJson() {
    return {
      'documentCount': documentCount,
      'occupiedSlots': occupiedSlots,
      'pendingPickup': pendingPickup,
      'todayStored': todayStored,
      'todayPickedUp': todayPickedUp,
      'occupancyRateText': occupancyRateText,
      'occupancyRateValue': occupancyRateValue,
    };
  }
}

/// 首页展示模型。
class HomeData {
  /// 创建首页展示模型。
  const HomeData({
    required this.cabinetCode,
    required this.region,
    required this.status,
    required this.headline,
    required this.stats,
  });

  /// 页面首帧兜底展示数据。
  factory HomeData.fallback() {
    return HomeData.fromMap(const {
      'cabinetCode': 'CAB-A01',
      'region': 'A · B 区',
      'status': '在线运行',
      'headline': '智能柜统计信息',
      'stats': {
        'documentCount': '12 份',
        'occupiedSlots': '6 / 12',
        'pendingPickup': '3 份',
        'todayStored': '5 份',
        'todayPickedUp': '2 份',
        'occupancyRateText': '50%',
        'occupancyRateValue': 0.5,
      },
    });
  }

  /// 柜体编号。
  final String cabinetCode;

  /// 柜体区域。
  final String region;

  /// 柜体状态。
  final String status;

  /// banner 标题。
  final String headline;

  /// 首页统计数据。
  final HomeStats stats;

  /// 从接口数据创建模型。
  factory HomeData.fromMap(Map<String, Object> map) {
    return HomeData(
      cabinetCode: map['cabinetCode'] as String,
      region: map['region'] as String,
      status: map['status'] as String,
      headline: map['headline'] as String,
      stats: HomeStats.fromMap(map['stats'] as Map<String, Object>),
    );
  }

  /// 转为 JSON 结构。
  Map<String, Object> toJson() {
    return {
      'cabinetCode': cabinetCode,
      'region': region,
      'status': status,
      'headline': headline,
      'stats': stats.toJson(),
    };
  }
}
