/// 取件响应 DTO。
class PickupResponseDto {
  /// 创建取件响应 DTO。
  const PickupResponseDto({required this.raw});

  /// 原始 JSON 数据。
  ///
  /// 当前取件接口字段与页面模型差异较小，因此先整体保留，
  /// 后续可以按需要再拆成更细的 DTO 字段。
  final Map<String, Object> raw;

  /// 从 JSON 创建 DTO。
  ///
  /// DTO 层尽量保持与接口协议一致，减少字段适配时的歧义。
  factory PickupResponseDto.fromJson(Map<String, Object> json) {
    return PickupResponseDto(raw: json);
  }
}
