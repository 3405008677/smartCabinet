/// 首页响应 DTO。
class HomeResponseDto {
  /// 创建首页响应 DTO。
  const HomeResponseDto({
    required this.cabinetName,
    required this.cabinetCode,
    required this.region,
    required this.status,
    required this.headline,
    required this.stats,
    required this.footer,
  });

  /// 柜体名称。
  final String cabinetName;

  /// 柜体编号。
  final String cabinetCode;

  /// 柜体所属区域或部署地点。
  final String region;

  /// 柜体当前状态文案，例如在线、运行中等。
  final String status;

  /// 首页 banner 或主信息卡区域的主标题文案。
  final String headline;

  /// 首页统计数据原始结构。
  ///
  /// 当前保留为 Map，便于后续根据后端协议逐步细化为更明确的 DTO 结构。
  final Map<String, Object> stats;

  /// 首页底部状态摘要原始结构。
  final Map<String, Object> footer;

  /// 从 JSON 创建首页响应 DTO。
  ///
  /// DTO 层尽量贴近接口返回字段命名，减少协议适配时的信息损失。
  factory HomeResponseDto.fromJson(Map<String, Object> json) {
    return HomeResponseDto(
      cabinetName: json['cabinetName'] as String,
      cabinetCode: json['cabinetCode'] as String,
      region: json['region'] as String,
      status: json['status'] as String,
      headline: json['headline'] as String,
      stats: json['stats'] as Map<String, Object>,
      footer: json['footer'] as Map<String, Object>,
    );
  }
}
