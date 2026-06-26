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
}
