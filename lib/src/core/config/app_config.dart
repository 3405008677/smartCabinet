/// 应用运行配置。
///
/// 适合放置和环境相关的配置，例如应用名称、接口地址、开关项等。
class AppConfig {
  /// 创建一份应用配置。
  const AppConfig({
    required this.appName,
    required this.apiBaseUrl,
    this.isTestMode = false,
  });

  /// 应用名称。
  final String appName;

  /// 后端接口基础地址。
  ///
  /// 例如后续可以配置为 `https://api.example.com`。
  final String apiBaseUrl;

  /// 是否处于柜机业务测试阶段。
  ///
  /// 开启后，账号密码登录成功可跳过人脸、指纹与 NFC 身份校验并直接进入
  /// 任务中心；人脸登录仍执行完整三项认证。正式环境必须设为 `false`。
  final bool isTestMode;

  /// 当前运行环境使用的默认配置。
  static const AppConfig current = AppConfig(
    appName: '智能柜终端',
    apiBaseUrl: '',
    isTestMode: true,
  );

  /// 固定 RTSP 服务地址前缀。
  static const String streamBaseUrl = 'rtsp://183.56.183.39:8888/app';

  /// 可按需启动的 H265 推流清晰度配置。
  static const List<StreamProfileConfig> streamProfiles = [
    StreamProfileConfig(
      name: '720p',
      width: 1280,
      height: 720,
      fps: 15,
      bitrate: 2000 * 1000,
      gopSeconds: 1,
    ),
    StreamProfileConfig(
      name: '1080p',
      width: 1920,
      height: 1080,
      fps: 15,
      bitrate: 5000 * 1000,
      gopSeconds: 1,
    ),
  ];
}

/// H265 推流清晰度配置。
class StreamProfileConfig {
  /// 创建一份清晰度配置。
  const StreamProfileConfig({
    required this.name,
    required this.width,
    required this.height,
    required this.fps,
    required this.bitrate,
    required this.gopSeconds,
  });

  /// 清晰度名称，例如 `720p` 或 `1080p`。
  final String name;

  /// H265 推流宽度。
  final int width;

  /// H265 推流高度。
  final int height;

  /// H265 推流帧率。
  final int fps;

  /// H265 推流码率，单位 bps。
  final int bitrate;

  /// H265 推流关键帧间隔，单位秒。
  final int gopSeconds;
}
