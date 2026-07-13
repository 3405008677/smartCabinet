import 'package:smart_cabinet/src/core/network/api_client.dart';
import 'package:smart_cabinet/src/features/dropoff/data/dtos/dropoff_response_dto.dart';

/// 放件数据 URL。
const String dropoffFileVerificationUrl = '/api/dropoff';

/// 获取放件数据接口。
Future<DropoffResponseDto> dropoffFileVerificationAPI() async {
  final data = await apiClient.get<Map<String, Object>>(
    dropoffFileVerificationUrl,
  );
  return DropoffResponseDto.fromJson(data);
}
