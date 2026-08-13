import 'package:smart_cabinet/src/app/localization/app_localizations.dart';

/// 把 Android 原生层返回的稳定设备字段名转换为当前界面语言。
String localizeDeviceInfoLabel(AppLocalizations l10n, String rawLabel) {
  return switch (rawLabel) {
    '唯一设备ID' || '唯一设备 ID' => l10n.t('deviceInfoUniqueId', '唯一设备ID'),
    '主板' => l10n.t('deviceInfoBoard', '主板'),
    '启动加载器' => l10n.t('deviceInfoBootloader', '启动加载器'),
    '品牌' => l10n.t('deviceInfoBrand', '品牌'),
    '设备' => l10n.t('deviceInfoDevice', '设备'),
    '显示版本' => l10n.t('deviceInfoDisplayBuild', '显示版本'),
    '指纹' || '构建指纹' => l10n.t('deviceInfoBuildFingerprint', '构建指纹'),
    '硬件' => l10n.t('deviceInfoHardware', '硬件'),
    '主机' => l10n.t('deviceInfoHost', '主机'),
    '构建 ID' => l10n.t('deviceInfoBuildId', '构建 ID'),
    '厂商' => l10n.t('deviceInfoManufacturer', '厂商'),
    '型号' => l10n.t('deviceInfoModel', '型号'),
    '产品' => l10n.t('deviceInfoProduct', '产品'),
    '标签' => l10n.t('deviceInfoTags', '标签'),
    '构建时间' => l10n.t('deviceInfoBuildTime', '构建时间'),
    '构建类型' => l10n.t('deviceInfoBuildType', '构建类型'),
    '用户' => l10n.t('deviceInfoUser', '用户'),
    'Android 版本' => l10n.t('deviceInfoAndroidVersion', 'Android 版本'),
    'Android SDK' => l10n.t('deviceInfoAndroidSdk', 'Android SDK'),
    '安全补丁' => l10n.t('deviceInfoSecurityPatch', '安全补丁'),
    '平台' => l10n.t('deviceInfoPlatform', '平台'),
    '状态' => l10n.t('deviceInfoStatus', '状态'),
    _ => rawLabel,
  };
}

/// 把原生层和本地缓存中的已知状态值转换为当前界面语言。
String localizeDeviceInfoValue(AppLocalizations l10n, String rawValue) {
  return switch (rawValue) {
    '未知' => l10n.t('deviceInfoUnknown', '未知'),
    '不支持' => l10n.t('deviceInfoUnsupported', '不支持'),
    '浏览器调试环境' => l10n.t('deviceInfoBrowserDebug', '浏览器调试环境'),
    '当前平台未返回设备信息' => l10n.t('deviceInfoUnavailable', '当前平台未返回设备信息'),
    '设备信息尚未完成启动缓存' => l10n.t('deviceInfoCachePending', '设备信息尚未完成启动缓存'),
    _ => rawValue,
  };
}
