import 'package:smart_cabinet/src/app/localization/app_localizations.dart';

/// 首页接口动态字段的多语言文案。
///
/// 这些字段可能由接口返回稳定代码，也可能由旧版接口返回中文显示值，因此统一在
/// 展示层转换，避免服务端默认值绕过本地化资源。
const homeRuntimeLocalizations = {
  'homeDefaultRegion': {
    AppLanguage.simplifiedChinese: 'A · B 区',
    AppLanguage.traditionalChinese: 'A · B 區',
    AppLanguage.english: 'Areas A · B',
    AppLanguage.japanese: 'A・B エリア',
  },
  'homeStatusOnline': {
    AppLanguage.simplifiedChinese: '在线运行',
    AppLanguage.traditionalChinese: '線上運行',
    AppLanguage.english: 'Online',
    AppLanguage.japanese: 'オンライン稼働',
  },
  'homeCabinetStatisticsHeadline': {
    AppLanguage.simplifiedChinese: '智能柜统计信息',
    AppLanguage.traditionalChinese: '智慧櫃統計資訊',
    AppLanguage.english: 'Smart Cabinet Statistics',
    AppLanguage.japanese: 'スマートキャビネット統計',
  },
  'homeDocumentCountValue': {
    AppLanguage.simplifiedChinese: '{count} 份',
    AppLanguage.traditionalChinese: '{count} 份',
    AppLanguage.english: '{count} files',
    AppLanguage.japanese: '{count} 件',
  },
};
