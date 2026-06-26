/// 飞检响应 DTO。
class FlightInspectionResponseDto {
  /// 创建飞检响应 DTO。
  const FlightInspectionResponseDto({required this.raw});

  /// 原始 JSON 数据。
  ///
  /// 当前保留任务批次和任务列表的原始结构，供模型层统一映射。
  final Map<String, Object> raw;

  /// 从 JSON 创建 DTO。
  ///
  /// 保持 DTO 与后端协议贴近，便于后续排查接口字段问题。
  factory FlightInspectionResponseDto.fromJson(Map<String, Object> json) {
    return FlightInspectionResponseDto(raw: json);
  }
}
