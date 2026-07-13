import '../../index.dart';
import '../../../dto/dropoff_response_dto.dart';

/// 放件数据 URL。
const String dropoffFileVerificationUrl = '/api/dropoff';

/// 获取放件数据接口。
Future<DropoffResponseDto> dropoffFileVerificationAPI() async {
  final data = await apiClient.get<Map<String, Object>>(
    dropoffFileVerificationUrl,
  );
  return DropoffResponseDto.fromJson(data);
}
