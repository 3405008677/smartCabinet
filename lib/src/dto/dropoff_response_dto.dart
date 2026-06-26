/// 放件响应 DTO。
class DropoffResponseDto {
  /// 创建放件响应 DTO。
  const DropoffResponseDto({required this.raw});

  /// 原始 JSON 数据。
  ///
  /// 当前放件接口字段与页面模型相近，因此先保留整份原始结构。
  final Map<String, Object> raw;

  /// 从 JSON 创建 DTO。
  ///
  /// 后续如果接口结构更复杂，可以在 DTO 层拆分出更明确的字段属性。
  factory DropoffResponseDto.fromJson(Map<String, Object> json) {
    return DropoffResponseDto(raw: json);
  }
}
