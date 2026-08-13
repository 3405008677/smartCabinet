/// 应用运行配置。
///
/// 适合放置和环境相关的配置，例如应用名称、接口地址、开关项等。
class AppConfig {
  /// 创建一份应用配置。
  const AppConfig({
    required this.appName,
    required this.apiBaseUrl,
    this.isTestMode = false,
    this.operatorProtocolHost = '',
    this.operatorProtocolPort = 0,
    this.operatorShelfCode = '',
    this.afrrDeviceImei = '',
    this.terminalUpgradeDataProtocolIp = '',
    this.terminalUpgradeVersionDate = '20260812',
    this.appCredentialSource = defaultAppCredentialSource,
  });

  /// 应用名称。
  final String appName;

  /// 其他后端 HTTP 接口的基础地址。
  final String apiBaseUrl;

  /// 是否处于柜机业务测试阶段。
  ///
  /// 开启后，账号登录成功可跳过人脸、指纹与 NFC 身份校验并直接进入任务中心；
  /// 人脸登录仍执行完整三项认证。正式环境必须设为 `false`。
  final bool isTestMode;

  /// AFRR A170/B170 登录协议使用的 TCP 服务主机。
  final String operatorProtocolHost;

  /// AFRR A170/B170 登录协议使用的 TCP 服务端口。
  final int operatorProtocolPort;

  /// AFRR 报文头使用的 15 位 IMEI 或 16 位货架编码。
  final String operatorShelfCode;

  /// AFRR 与 STUM 共用的设备主板 IMEI。
  ///
  /// 现场必须通过 `--dart-define=DEVICE_IMEI=...` 配置真实的 15 位数字。
  /// AFRR 登录使用该值，STUM `T01.IM` 也必须使用同一值匹配后台升级任务。
  final String afrrDeviceImei;

  /// STUM `T01.DP` 使用的数据通讯地址。
  ///
  /// 该值属于服务端登记身份的一部分，不是终端当前局域网地址，升级页面不得覆盖。
  final String terminalUpgradeDataProtocolIp;

  /// STUM `T03.VE` 使用的应用版本日期，格式固定为 yyyyMMdd。
  ///
  /// 该日期描述当前 APK 的版本构建批次，不使用请求当天日期，避免同一 APK
  /// 在不同日期重启后向服务端上报成不同版本。
  final String terminalUpgradeVersionDate;

  /// APP 登录凭据混淆源串。
  ///
  /// 按 1 开始计数，奇数位组成 appId，偶数位组成 appSecret。
  final String appCredentialSource;

  /// AFRR APP 登录使用的 appId。
  String get appId => charactersAtOddPositions(appCredentialSource);

  /// AFRR APP 登录使用的签名密钥。
  String get appSecret => charactersAtEvenPositions(appCredentialSource);

  /// 固定保存的 APP 登录凭据混淆源串。
  static const String defaultAppCredentialSource =
      'a7xq2kf8bv0r4n6mz3dgp5jht1ycue7awolq9b2f';

  /// 取得从 1 开始计数的奇数位字符。
  static String charactersAtOddPositions(String value) {
    return _charactersAtParity(value, startIndex: 0);
  }

  /// 取得从 1 开始计数的偶数位字符。
  static String charactersAtEvenPositions(String value) {
    return _charactersAtParity(value, startIndex: 1);
  }

  /// AFRR 与 STUM 共用的唯一设备 IMEI 配置源。
  static const String _configuredAfrrDeviceImei = String.fromEnvironment(
    'DEVICE_IMEI',
    defaultValue: '867282037661259',
  );

  /// STUM 数据通讯地址的唯一配置源。
  static const String _configuredTerminalUpgradeDataProtocolIp =
      String.fromEnvironment('STUM_DP', defaultValue: '47.107.40.88');

  /// 当前运行环境使用的默认配置。
  ///
  /// 现场可通过 `--dart-define` 覆盖 AFRR 服务器地址与设备标识。
  static const AppConfig current = AppConfig(
    appName: '智能柜终端',
    apiBaseUrl: '',
    isTestMode: true,
    operatorProtocolHost: String.fromEnvironment(
      'AFRR_HOST',
      defaultValue: '192.168.2.236',
    ),
    operatorProtocolPort: int.fromEnvironment('AFRR_PORT', defaultValue: 16666),
    operatorShelfCode: String.fromEnvironment(
      'AFRR_SHELF_CODE',
      defaultValue: _configuredAfrrDeviceImei,
    ),
    afrrDeviceImei: _configuredAfrrDeviceImei,
    terminalUpgradeDataProtocolIp: _configuredTerminalUpgradeDataProtocolIp,
    terminalUpgradeVersionDate: String.fromEnvironment(
      'STUM_VERSION_DATE',
      defaultValue: '20260812',
    ),
  );

  /// 固定 RTSP 服务地址前缀。
  static const String streamBaseUrl = 'rtsp://183.56.183.39:8888/app';

  /// ZRD STUM 终端升级监控服务的默认 TCP 主机。
  ///
  /// 现场仍可在升级设置页覆盖该地址；这里仅用于首次安装和旧空配置迁移。
  static const String terminalUpgradeHost = '47.107.40.88';

  /// ZRD STUM 终端升级监控服务的默认 TCP 端口。
  static const int terminalUpgradePort = 21251;

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

String _charactersAtParity(String value, {required int startIndex}) {
  final result = StringBuffer();
  for (var index = startIndex; index < value.length; index += 2) {
    result.write(value[index]);
  }
  return result.toString();
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
