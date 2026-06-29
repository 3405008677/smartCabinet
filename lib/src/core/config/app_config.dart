/// 应用运行配置。
///
/// 适合放置和环境相关的配置，例如应用名称、接口地址、开关项等。
class AppConfig {
  /// 创建一份应用配置。
  const AppConfig({required this.appName, required this.apiBaseUrl});

  /// 应用名称。
  final String appName;

  /// 后端接口基础地址。
  ///
  /// 例如后续可以配置为 `https://api.example.com`。
  final String apiBaseUrl;

  /// 当前运行环境使用的默认配置。
  static const AppConfig current = AppConfig(appName: '智能柜终端', apiBaseUrl: '');

  /// 固定 RTSP 服务地址前缀。
  static const String streamBaseUrl = 'rtsp://192.168.2.167/app';
  // static const String streamBaseUrl = 'rtsp://127.0.0.1:8554/app';

  /// 固定 H265 推流宽度。
  static const int streamWidth = 1920;

  /// 固定 H265 推流高度。
  static const int streamHeight = 1080;

  /// 固定 H265 推流帧率。
  static const int streamFps = 15;

  /// 固定 H265 推流码率，单位 bps。
  static const int streamBitrate = 3000 * 1000;

  /// 固定 H265 推流关键帧间隔，单位秒。
  static const int streamGopSeconds = 3;
}
