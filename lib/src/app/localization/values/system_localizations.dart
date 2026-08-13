import 'package:smart_cabinet/src/app/localization/app_localizations.dart';

/// 应用壳层、全局提示、推流状态和启动失败页使用的多语言文案。
const systemLocalizations = {
  'startupBrandTitle': {
    AppLanguage.simplifiedChinese: '智能柜',
    AppLanguage.traditionalChinese: '智慧櫃',
    AppLanguage.english: 'Smart Cabinet',
    AppLanguage.japanese: 'スマートキャビネット',
  },
  'startupBrandTagline': {
    AppLanguage.simplifiedChinese: '智享生活，便捷未来',
    AppLanguage.traditionalChinese: '智享生活，便捷未來',
    AppLanguage.english: 'Smarter living, a more convenient future',
    AppLanguage.japanese: 'スマートな暮らし、便利な未来',
  },
  'startupFeatureRecognition': {
    AppLanguage.simplifiedChinese: '智能识别',
    AppLanguage.traditionalChinese: '智慧識別',
    AppLanguage.english: 'Smart Recognition',
    AppLanguage.japanese: 'スマート認識',
  },
  'startupFeatureSecurity': {
    AppLanguage.simplifiedChinese: '安全可靠',
    AppLanguage.traditionalChinese: '安全可靠',
    AppLanguage.english: 'Safe and Reliable',
    AppLanguage.japanese: '安全・高信頼',
  },
  'startupFeatureCloud': {
    AppLanguage.simplifiedChinese: '云端管理',
    AppLanguage.traditionalChinese: '雲端管理',
    AppLanguage.english: 'Cloud Management',
    AppLanguage.japanese: 'クラウド管理',
  },
  'startupFeatureEnergy': {
    AppLanguage.simplifiedChinese: '绿色节能',
    AppLanguage.traditionalChinese: '綠色節能',
    AppLanguage.english: 'Energy Efficient',
    AppLanguage.japanese: '省エネルギー',
  },
  'startupSystemLoading': {
    AppLanguage.simplifiedChinese: '系统启动中…',
    AppLanguage.traditionalChinese: '系統啟動中…',
    AppLanguage.english: 'Starting system…',
    AppLanguage.japanese: 'システムを起動しています…',
  },
  'messageDismiss': {
    AppLanguage.simplifiedChinese: '关闭提示',
    AppLanguage.traditionalChinese: '關閉提示',
    AppLanguage.english: 'Dismiss message',
    AppLanguage.japanese: 'メッセージを閉じる',
  },
  'startupCameraUnavailable': {
    AppLanguage.simplifiedChinese: '未检测到可用摄像头。请确认摄像头已连接、系统相机权限正常，并重新检测。',
    AppLanguage.traditionalChinese: '未偵測到可用攝影機。請確認攝影機已連接、系統相機權限正常，並重新檢測。',
    AppLanguage.english:
        'No available camera was detected. Check the camera connection and system camera permission, then run the check again.',
    AppLanguage.japanese:
        '利用可能なカメラが検出されませんでした。カメラの接続とシステムのカメラ権限を確認し、もう一度検査してください。',
  },
  'startupErrorReason': {
    AppLanguage.simplifiedChinese: '错误原因：{reason}',
    AppLanguage.traditionalChinese: '錯誤原因：{reason}',
    AppLanguage.english: 'Reason: {reason}',
    AppLanguage.japanese: 'エラー理由：{reason}',
  },
  'startupFailureDescription': {
    AppLanguage.simplifiedChinese: '关键功能未准备完成，系统已阻止进入主界面。请检查硬件连接后重试。',
    AppLanguage.traditionalChinese: '關鍵功能尚未準備完成，系統已阻止進入主畫面。請檢查硬體連接後重試。',
    AppLanguage.english:
        'A critical function is not ready, so access to the main screen has been blocked. Check the hardware connections and try again.',
    AppLanguage.japanese:
        '重要な機能の準備が完了していないため、メイン画面への移動を停止しました。ハードウェアの接続を確認して再試行してください。',
  },
  'startupFailureTask': {
    AppLanguage.simplifiedChinese: '失败任务：{task}',
    AppLanguage.traditionalChinese: '失敗任務：{task}',
    AppLanguage.english: 'Failed check: {task}',
    AppLanguage.japanese: '失敗した検査：{task}',
  },
  'startupFailureTitle': {
    AppLanguage.simplifiedChinese: '系统启动失败',
    AppLanguage.traditionalChinese: '系統啟動失敗',
    AppLanguage.english: 'System Startup Failed',
    AppLanguage.japanese: 'システムを起動できませんでした',
  },
  'startupRetry': {
    AppLanguage.simplifiedChinese: '重新启动检测',
    AppLanguage.traditionalChinese: '重新啟動檢測',
    AppLanguage.english: 'Run Startup Checks Again',
    AppLanguage.japanese: '起動検査を再実行',
  },
  'startupTaskCacheLocalData': {
    AppLanguage.simplifiedChinese: '缓存本地设备数据',
    AppLanguage.traditionalChinese: '快取本機設備資料',
    AppLanguage.english: 'Cache Local Device Data',
    AppLanguage.japanese: '端末データをキャッシュ',
  },
  'startupTaskConnectMqtt': {
    AppLanguage.simplifiedChinese: '连接 MQTT',
    AppLanguage.traditionalChinese: '連接 MQTT',
    AppLanguage.english: 'Connect to MQTT',
    AppLanguage.japanese: 'MQTT に接続',
  },
  'startupTaskDuration': {
    AppLanguage.simplifiedChinese: '{task} · {milliseconds} 毫秒',
    AppLanguage.traditionalChinese: '{task} · {milliseconds} 毫秒',
    AppLanguage.english: '{task} · {milliseconds} ms',
    AppLanguage.japanese: '{task} · {milliseconds} ミリ秒',
  },
  'startupTaskLoadCameras': {
    AppLanguage.simplifiedChinese: '加载摄像头',
    AppLanguage.traditionalChinese: '載入攝影機',
    AppLanguage.english: 'Load Cameras',
    AppLanguage.japanese: 'カメラを読み込む',
  },
  'startupTaskResults': {
    AppLanguage.simplifiedChinese: '启动任务结果',
    AppLanguage.traditionalChinese: '啟動任務結果',
    AppLanguage.english: 'Startup Check Results',
    AppLanguage.japanese: '起動検査の結果',
  },
  'startupTaskStartUpgradeMonitor': {
    AppLanguage.simplifiedChinese: '启动终端升级监控',
    AppLanguage.traditionalChinese: '啟動終端升級監控',
    AppLanguage.english: 'Start Terminal Upgrade Monitor',
    AppLanguage.japanese: '端末更新モニターを開始',
  },
  'startupTaskUnknown': {
    AppLanguage.simplifiedChinese: '启动检测',
    AppLanguage.traditionalChinese: '啟動檢測',
    AppLanguage.english: 'Startup Check',
    AppLanguage.japanese: '起動検査',
  },
  'startupUnknownError': {
    AppLanguage.simplifiedChinese: '启动检测未完成，请检查设备状态后重试。',
    AppLanguage.traditionalChinese: '啟動檢測未完成，請檢查設備狀態後重試。',
    AppLanguage.english:
        'The startup check did not complete. Check the device status and try again.',
    AppLanguage.japanese: '起動検査が完了しませんでした。デバイスの状態を確認して再試行してください。',
  },
  'streamFailurePrefix': {
    AppLanguage.simplifiedChinese: '推流异常：{message}',
    AppLanguage.traditionalChinese: '串流異常：{message}',
    AppLanguage.english: 'Streaming issue: {message}',
    AppLanguage.japanese: '映像配信エラー：{message}',
  },
  'streamOperationFailure': {
    AppLanguage.simplifiedChinese: '操作区推流异常：{detail}',
    AppLanguage.traditionalChinese: '操作區串流異常：{detail}',
    AppLanguage.english: 'Operation-area stream issue: {detail}',
    AppLanguage.japanese: '操作エリアの映像配信エラー：{detail}',
  },
  'streamOutsideFailure': {
    AppLanguage.simplifiedChinese: '柜外环境推流异常：{detail}',
    AppLanguage.traditionalChinese: '櫃外環境串流異常：{detail}',
    AppLanguage.english: 'External-area stream issue: {detail}',
    AppLanguage.japanese: 'キャビネット外部の映像配信エラー：{detail}',
  },
  'streamStatusFailed': {
    AppLanguage.simplifiedChinese: '连接失败，请检查摄像头和网络',
    AppLanguage.traditionalChinese: '連接失敗，請檢查攝影機與網路',
    AppLanguage.english: 'Connection failed. Check the camera and network',
    AppLanguage.japanese: '接続に失敗しました。カメラとネットワークを確認してください',
  },
  'streamStatusReconnecting': {
    AppLanguage.simplifiedChinese: '正在重新连接',
    AppLanguage.traditionalChinese: '正在重新連接',
    AppLanguage.english: 'Reconnecting',
    AppLanguage.japanese: '再接続しています',
  },
  'streamStatusUnavailable': {
    AppLanguage.simplifiedChinese: '当前不可用，请检查摄像头和网络',
    AppLanguage.traditionalChinese: '目前無法使用，請檢查攝影機與網路',
    AppLanguage.english: 'Currently unavailable. Check the camera and network',
    AppLanguage.japanese: '現在利用できません。カメラとネットワークを確認してください',
  },
  'terminalProductSubtitle': {
    AppLanguage.simplifiedChinese: '智能文件保管柜 · {cabinetCode}',
    AppLanguage.traditionalChinese: '智慧文件保管櫃 · {cabinetCode}',
    AppLanguage.english: 'Intelligent Document Cabinet · {cabinetCode}',
    AppLanguage.japanese: 'スマート文書保管庫 · {cabinetCode}',
  },
  'terminalInactivityCountdownValue': {
    AppLanguage.simplifiedChinese: '{seconds} 秒',
    AppLanguage.traditionalChinese: '{seconds} 秒',
    AppLanguage.english: '{seconds}s',
    AppLanguage.japanese: '{seconds} 秒',
  },
};
