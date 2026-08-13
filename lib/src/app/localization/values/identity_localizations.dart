import 'package:smart_cabinet/src/app/localization/app_localizations.dart';

/// 操作员与管理员身份认证组件共用的多语言文案。
const identityLocalizations = {
  'identityFaceTitle': {
    AppLanguage.simplifiedChinese: '人脸识别',
    AppLanguage.traditionalChinese: '人臉識別',
    AppLanguage.english: 'Face Recognition',
    AppLanguage.japanese: '顔認証',
  },
  'identityFingerprintTitle': {
    AppLanguage.simplifiedChinese: '指纹识别',
    AppLanguage.traditionalChinese: '指紋識別',
    AppLanguage.english: 'Fingerprint Scan',
    AppLanguage.japanese: '指紋認証',
  },
  'identityNfcTitle': {
    AppLanguage.simplifiedChinese: 'NFC识别',
    AppLanguage.traditionalChinese: 'NFC識別',
    AppLanguage.english: 'NFC Scan',
    AppLanguage.japanese: 'NFC認証',
  },
  'identityConfirmFingerprint': {
    AppLanguage.simplifiedChinese: '确认指纹识别',
    AppLanguage.traditionalChinese: '確認指紋識別',
    AppLanguage.english: 'Confirm Fingerprint',
    AppLanguage.japanese: '指紋認証を確認',
  },
  'identityFingerprintDone': {
    AppLanguage.simplifiedChinese: '指纹识别已完成',
    AppLanguage.traditionalChinese: '指紋識別已完成',
    AppLanguage.english: 'Fingerprint Verified',
    AppLanguage.japanese: '指紋認証完了',
  },
  'identityConfirmNfc': {
    AppLanguage.simplifiedChinese: '确认NFC识别',
    AppLanguage.traditionalChinese: '確認NFC識別',
    AppLanguage.english: 'Confirm NFC',
    AppLanguage.japanese: 'NFC認証を確認',
  },
  'identityNfcDone': {
    AppLanguage.simplifiedChinese: 'NFC识别已完成',
    AppLanguage.traditionalChinese: 'NFC識別已完成',
    AppLanguage.english: 'NFC Verified',
    AppLanguage.japanese: 'NFC認証完了',
  },
  'sharedVerificationProgress': {
    AppLanguage.simplifiedChinese: '验证进度',
    AppLanguage.traditionalChinese: '驗證進度',
    AppLanguage.english: 'Verification Progress',
    AppLanguage.japanese: '認証進捗',
  },
  'sharedWaitingVerification': {
    AppLanguage.simplifiedChinese: '等待认证',
    AppLanguage.traditionalChinese: '等待驗證',
    AppLanguage.english: 'Waiting for Verification',
    AppLanguage.japanese: '認証待機中',
  },
  'sharedVerified': {
    AppLanguage.simplifiedChinese: '已通过',
    AppLanguage.traditionalChinese: '已通過',
    AppLanguage.english: 'Verified',
    AppLanguage.japanese: '認証済み',
  },
  'sharedFaceCameraStarting': {
    AppLanguage.simplifiedChinese: '正在启动摄像头...',
    AppLanguage.traditionalChinese: '正在啟動攝像頭...',
    AppLanguage.english: 'Starting camera...',
    AppLanguage.japanese: 'カメラを起動中...',
  },
  'sharedFaceNoCamera': {
    AppLanguage.simplifiedChinese: '未检测到可用摄像头',
    AppLanguage.traditionalChinese: '未偵測到可用攝影機',
    AppLanguage.english: 'No available camera detected',
    AppLanguage.japanese: '利用可能なカメラが検出されません',
  },
  'sharedFaceCameraPermissionDenied': {
    AppLanguage.simplifiedChinese: '摄像头权限被拒绝',
    AppLanguage.traditionalChinese: '攝影機權限遭拒',
    AppLanguage.english: 'Camera permission was denied',
    AppLanguage.japanese: 'カメラの権限が拒否されました',
  },
  'sharedFaceCameraPermissionPermanentlyDenied': {
    AppLanguage.simplifiedChinese: '摄像头权限被永久拒绝，请到系统设置开启',
    AppLanguage.traditionalChinese: '攝影機權限已永久遭拒，請前往系統設定開啟',
    AppLanguage.english:
        'Camera permission is permanently denied. Enable it in system settings',
    AppLanguage.japanese: 'カメラの権限が恒久的に拒否されています。システム設定で許可してください',
  },
  'sharedFaceCameraStartFailed': {
    AppLanguage.simplifiedChinese: '摄像头启动失败',
    AppLanguage.traditionalChinese: '攝影機啟動失敗',
    AppLanguage.english: 'Failed to start the camera',
    AppLanguage.japanese: 'カメラを起動できませんでした',
  },
  'sharedFaceFallbackAvailable': {
    AppLanguage.simplifiedChinese: '{message}，可使用模拟校验',
    AppLanguage.traditionalChinese: '{message}，可使用模擬驗證',
    AppLanguage.english: '{message}. Simulated verification is available',
    AppLanguage.japanese: '{message}。模擬認証を使用できます',
  },
  'sharedFaceSimulationVerifying': {
    AppLanguage.simplifiedChinese: '测试模式：正在完成人脸模拟认证...',
    AppLanguage.traditionalChinese: '測試模式：正在完成人臉模擬認證...',
    AppLanguage.english: 'Test mode: completing simulated face verification...',
    AppLanguage.japanese: 'テストモード：顔認証をシミュレートしています...',
  },
  'sharedFaceCaptureVerifying': {
    AppLanguage.simplifiedChinese: '正在拍照并提交后端校验...',
    AppLanguage.traditionalChinese: '正在拍照並提交後端驗證...',
    AppLanguage.english:
        'Capturing a photo and submitting it for validation...',
    AppLanguage.japanese: '撮影してバックエンド検証へ送信しています...',
  },
  'sharedFaceCaptureFailed': {
    AppLanguage.simplifiedChinese: '拍照或校验失败，请重试',
    AppLanguage.traditionalChinese: '拍照或驗證失敗，請重試',
    AppLanguage.english: 'Capture or verification failed. Try again',
    AppLanguage.japanese: '撮影または認証に失敗しました。再試行してください',
  },
  'sharedFaceVerifiedSubmitted': {
    AppLanguage.simplifiedChinese: '人脸识别通过，照片已提交后端校验',
    AppLanguage.traditionalChinese: '人臉識別通過，照片已提交後端校驗',
    AppLanguage.english:
        'Face verified. Photo submitted for backend validation.',
    AppLanguage.japanese: '顔認証成功。写真をバックエンド検証へ送信しました。',
  },
  'sharedFaceCameraReady': {
    AppLanguage.simplifiedChinese: '摄像头已启动，请对准面部后点击确认',
    AppLanguage.traditionalChinese: '攝像頭已啟動，請對準臉部後點擊確認',
    AppLanguage.english: 'Camera ready. Align your face and tap confirm.',
    AppLanguage.japanese: 'カメラ準備完了。顔を合わせて確認を押してください。',
  },
  'sharedFaceVerifiedShort': {
    AppLanguage.simplifiedChinese: '人脸识别通过',
    AppLanguage.traditionalChinese: '人臉識別通過',
    AppLanguage.english: 'Face Verified',
    AppLanguage.japanese: '顔認証成功',
  },
  'sharedFaceVerifying': {
    AppLanguage.simplifiedChinese: '校验中...',
    AppLanguage.traditionalChinese: '校驗中...',
    AppLanguage.english: 'Verifying...',
    AppLanguage.japanese: '検証中...',
  },
  'sharedFaceConfirmCapture': {
    AppLanguage.simplifiedChinese: '确认并拍照校验',
    AppLanguage.traditionalChinese: '確認並拍照校驗',
    AppLanguage.english: 'Confirm and Capture',
    AppLanguage.japanese: '確認して撮影認証',
  },
  'sharedFaceSimulationReady': {
    AppLanguage.simplifiedChinese: '测试模式：点击确认完成人脸模拟认证',
    AppLanguage.traditionalChinese: '測試模式：點擊確認完成人臉模擬認證',
    AppLanguage.english: 'Test mode: tap confirm to simulate face verification',
    AppLanguage.japanese: 'テストモード：確認を押して顔認証をシミュレートします',
  },
  'sharedFaceSimulationSucceeded': {
    AppLanguage.simplifiedChinese: '测试模式：人脸模拟认证已完成',
    AppLanguage.traditionalChinese: '測試模式：人臉模擬認證已完成',
    AppLanguage.english: 'Test mode: simulated face verification completed',
    AppLanguage.japanese: 'テストモード：顔認証シミュレーションが完了しました',
  },
  'sharedFaceConfirmSimulation': {
    AppLanguage.simplifiedChinese: '确认模拟认证',
    AppLanguage.traditionalChinese: '確認模擬認證',
    AppLanguage.english: 'Confirm Simulation',
    AppLanguage.japanese: '模擬認証を確認',
  },
  'sharedRetryDetection': {
    AppLanguage.simplifiedChinese: '重新检测',
    AppLanguage.traditionalChinese: '重新偵測',
    AppLanguage.english: 'Detect Again',
    AppLanguage.japanese: '再検出',
  },
  'hardwareRecoverySummary': {
    AppLanguage.simplifiedChinese: '{title}：{steps}',
    AppLanguage.traditionalChinese: '{title}：{steps}',
    AppLanguage.english: '{title}: {steps}',
    AppLanguage.japanese: '{title}：{steps}',
  },
  'hardwareCameraPermissionTitle': {
    AppLanguage.simplifiedChinese: '摄像头权限异常',
    AppLanguage.traditionalChinese: '攝影機權限異常',
    AppLanguage.english: 'Camera Permission Error',
    AppLanguage.japanese: 'カメラ権限エラー',
  },
  'hardwareCameraPermissionDescription': {
    AppLanguage.simplifiedChinese: '当前无法访问摄像头，不能进行人脸拍照校验。',
    AppLanguage.traditionalChinese: '目前無法存取攝影機，無法進行人臉拍照驗證。',
    AppLanguage.english:
        'The camera cannot be accessed, so photo-based face verification is unavailable.',
    AppLanguage.japanese: 'カメラにアクセスできないため、顔写真による認証を実行できません。',
  },
  'hardwareCameraPermissionSteps': {
    AppLanguage.simplifiedChinese: '到系统设置开启摄像头权限，或联系管理员检查终端权限白名单。',
    AppLanguage.traditionalChinese: '請前往系統設定開啟攝影機權限，或聯絡管理員檢查終端權限白名單。',
    AppLanguage.english:
        'Enable camera access in system settings, or ask an administrator to check the terminal permission allowlist.',
    AppLanguage.japanese: 'システム設定でカメラ権限を許可するか、管理者に端末の権限許可リストを確認するよう依頼してください。',
  },
  'hardwareCameraUnavailableTitle': {
    AppLanguage.simplifiedChinese: '摄像头不可用',
    AppLanguage.traditionalChinese: '攝影機無法使用',
    AppLanguage.english: 'Camera Unavailable',
    AppLanguage.japanese: 'カメラを利用できません',
  },
  'hardwareCameraUnavailableDescription': {
    AppLanguage.simplifiedChinese: '摄像头启动失败或没有检测到可用摄像头。',
    AppLanguage.traditionalChinese: '攝影機啟動失敗，或未偵測到可用攝影機。',
    AppLanguage.english:
        'The camera failed to start or no available camera was detected.',
    AppLanguage.japanese: 'カメラの起動に失敗したか、利用可能なカメラが検出されませんでした。',
  },
  'hardwareCameraUnavailableSteps': {
    AppLanguage.simplifiedChinese: '检查摄像头连接后点击重试；如仍失败，请重启终端并联系运维。',
    AppLanguage.traditionalChinese: '請檢查攝影機連線後點選重試；若仍失敗，請重新啟動終端並聯絡維運人員。',
    AppLanguage.english:
        'Check the camera connection and retry. If it still fails, restart the terminal and contact support.',
    AppLanguage.japanese:
        'カメラの接続を確認して再試行してください。解決しない場合は端末を再起動し、運用担当者に連絡してください。',
  },
  'hardwareFingerprintUnavailableTitle': {
    AppLanguage.simplifiedChinese: '指纹模块不可用',
    AppLanguage.traditionalChinese: '指紋模組無法使用',
    AppLanguage.english: 'Fingerprint Module Unavailable',
    AppLanguage.japanese: '指紋モジュールを利用できません',
  },
  'hardwareFingerprintUnavailableDescription': {
    AppLanguage.simplifiedChinese: '当前无法完成指纹认证。',
    AppLanguage.traditionalChinese: '目前無法完成指紋認證。',
    AppLanguage.english: 'Fingerprint verification cannot be completed.',
    AppLanguage.japanese: '現在、指紋認証を完了できません。',
  },
  'hardwareFingerprintUnavailableSteps': {
    AppLanguage.simplifiedChinese: '清洁指纹模块并重新按压；如无响应，请检查指纹模块连接并联系运维。',
    AppLanguage.traditionalChinese: '請清潔指紋模組並重新按壓；若無回應，請檢查模組連線並聯絡維運人員。',
    AppLanguage.english:
        'Clean the fingerprint module and press again. If it does not respond, check its connection and contact support.',
    AppLanguage.japanese:
        '指紋モジュールを清掃して再度押してください。反応しない場合は接続を確認し、運用担当者に連絡してください。',
  },
  'hardwareNfcTimeoutTitle': {
    AppLanguage.simplifiedChinese: 'NFC 读取超时',
    AppLanguage.traditionalChinese: 'NFC 讀取逾時',
    AppLanguage.english: 'NFC Read Timed Out',
    AppLanguage.japanese: 'NFC 読み取りタイムアウト',
  },
  'hardwareNfcTimeoutDescription': {
    AppLanguage.simplifiedChinese: '未在规定时间内读取到有效 NFC 凭证。',
    AppLanguage.traditionalChinese: '未在規定時間內讀取到有效的 NFC 憑證。',
    AppLanguage.english:
        'No valid NFC credential was read within the allowed time.',
    AppLanguage.japanese: '制限時間内に有効な NFC 認証情報を読み取れませんでした。',
  },
  'hardwareNfcTimeoutSteps': {
    AppLanguage.simplifiedChinese: '重新贴近 NFC 读卡区域，保持 1 秒以上；仍失败时请使用备用认证或联系管理员。',
    AppLanguage.traditionalChinese:
        '請重新貼近 NFC 讀卡區域並保持至少 1 秒；若仍失敗，請使用備用認證或聯絡管理員。',
    AppLanguage.english:
        'Hold the credential near the NFC reader for at least one second. If it still fails, use backup verification or contact an administrator.',
    AppLanguage.japanese:
        'NFC 読み取り領域に 1 秒以上かざしてください。失敗が続く場合は代替認証を使用するか、管理者に連絡してください。',
  },
  'hardwareNfcUnavailableTitle': {
    AppLanguage.simplifiedChinese: 'NFC 模块不可用',
    AppLanguage.traditionalChinese: 'NFC 模組無法使用',
    AppLanguage.english: 'NFC Module Unavailable',
    AppLanguage.japanese: 'NFC モジュールを利用できません',
  },
  'hardwareNfcUnavailableDescription': {
    AppLanguage.simplifiedChinese: '当前无法读取 NFC 凭证。',
    AppLanguage.traditionalChinese: '目前無法讀取 NFC 憑證。',
    AppLanguage.english: 'NFC credentials cannot currently be read.',
    AppLanguage.japanese: '現在、NFC 認証情報を読み取れません。',
  },
  'hardwareNfcUnavailableSteps': {
    AppLanguage.simplifiedChinese: '重新贴近 NFC 读卡区域；如无响应，请检查 NFC 模块连接并联系运维。',
    AppLanguage.traditionalChinese: '請重新貼近 NFC 讀卡區域；若無回應，請檢查 NFC 模組連線並聯絡維運人員。',
    AppLanguage.english:
        'Move the credential close to the NFC reader again. If it does not respond, check the module connection and contact support.',
    AppLanguage.japanese:
        'NFC 読み取り領域にもう一度かざしてください。反応しない場合はモジュールの接続を確認し、運用担当者に連絡してください。',
  },
  'hardwareCabinetControllerTitle': {
    AppLanguage.simplifiedChinese: '柜控板通讯异常',
    AppLanguage.traditionalChinese: '櫃控板通訊異常',
    AppLanguage.english: 'Cabinet Controller Communication Error',
    AppLanguage.japanese: 'キャビネット制御基板の通信エラー',
  },
  'hardwareCabinetControllerDescription': {
    AppLanguage.simplifiedChinese: '应用无法确认柜门控制板状态。',
    AppLanguage.traditionalChinese: '應用程式無法確認櫃門控制板狀態。',
    AppLanguage.english:
        'The app cannot confirm the cabinet door controller status.',
    AppLanguage.japanese: 'アプリがキャビネット扉の制御基板の状態を確認できません。',
  },
  'hardwareCabinetControllerSteps': {
    AppLanguage.simplifiedChinese: '检查柜控板电源和通讯线，确认指示灯正常后重试；仍异常请切换维护模式。',
    AppLanguage.traditionalChinese: '請檢查櫃控板電源與通訊線，確認指示燈正常後重試；若仍異常，請切換至維護模式。',
    AppLanguage.english:
        'Check the controller power and communication cable, then retry after its indicators are normal. Switch to maintenance mode if the error remains.',
    AppLanguage.japanese:
        '制御基板の電源と通信ケーブルを確認し、表示灯が正常になってから再試行してください。異常が続く場合は保守モードに切り替えてください。',
  },
};
