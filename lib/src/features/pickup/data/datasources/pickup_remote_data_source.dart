import '../../index.dart';
import '../../../dto/pickup_response_dto.dart';

/// 取件数据 URL。
const String pickupVerificationUrl = '/api/pickup';

/// 获取取件数据接口。
Future<PickupResponseDto> pickupVerificationAPI() async {
  final data = await apiClient.get<Map<String, Object>>(pickupVerificationUrl);
  return PickupResponseDto.fromJson(data);
}
