import 'package:smart_cabinet/src/app/localization/app_localizations.dart';

/// 操作员登录、任务概览与任务类型使用的多语言文案。
const operatorWorkflowLocalizations = {
  'homeTaskOverview': {
    AppLanguage.simplifiedChinese: '任务概览',
    AppLanguage.traditionalChinese: '任務概覽',
    AppLanguage.english: 'Task Overview',
    AppLanguage.japanese: 'タスク概要',
  },
  'homeTaskOverviewHint': {
    AppLanguage.simplifiedChinese: '登录并完成人脸、指纹与 NFC 三项身份验证后，根据账号权限展示任务',
    AppLanguage.traditionalChinese: '登入並完成人臉、指紋與 NFC 三項身分驗證後，依帳號權限顯示任務',
    AppLanguage.english:
        'Sign in and complete face, fingerprint, and NFC verification to view tasks permitted for this account',
    AppLanguage.japanese:
        'ログインして顔認証・指紋認証・NFC 認証をすべて完了すると、アカウント権限に応じたタスクが表示されます',
  },
  'homeIdentityLoginTitle': {
    AppLanguage.simplifiedChinese: '身份登录',
    AppLanguage.traditionalChinese: '身分登入',
    AppLanguage.english: 'Identity Sign-In',
    AppLanguage.japanese: '本人確認ログイン',
  },
  'homeIdentityLoginHint': {
    AppLanguage.simplifiedChinese: '先登录，再根据任务进行柜机操作',
    AppLanguage.traditionalChinese: '先登入，再依任務進行櫃機操作',
    AppLanguage.english:
        'Sign in first, then operate the cabinet according to assigned tasks',
    AppLanguage.japanese: '先にログインし、タスクに応じてキャビネットを操作してください',
  },
  'homeFaceLogin': {
    AppLanguage.simplifiedChinese: '人脸登录',
    AppLanguage.traditionalChinese: '人臉登入',
    AppLanguage.english: 'Face Sign-In',
    AppLanguage.japanese: '顔認証ログイン',
  },
  'homeAccountLogin': {
    AppLanguage.simplifiedChinese: '账号登录',
    AppLanguage.traditionalChinese: '帳號登入',
    AppLanguage.english: 'Account Sign-In',
    AppLanguage.japanese: 'アカウントログイン',
  },
  'homeAllThreeFactorsHint': {
    AppLanguage.simplifiedChinese: '人脸 / 指纹 / NFC，三项认证均需完成',
    AppLanguage.traditionalChinese: '人臉 / 指紋 / NFC，三項認證均需完成',
    AppLanguage.english: 'Complete face, fingerprint, and NFC verification',
    AppLanguage.japanese: '顔認証・指紋認証・NFC 認証をすべて完了してください',
  },
  'taskTypeDeposit': {
    AppLanguage.simplifiedChinese: '存证',
    AppLanguage.traditionalChinese: '存證',
    AppLanguage.english: 'Deposit Evidence',
    AppLanguage.japanese: '証憑保管',
  },
  'taskTypePickup': {
    AppLanguage.simplifiedChinese: '取证',
    AppLanguage.traditionalChinese: '取證',
    AppLanguage.english: 'Retrieve Evidence',
    AppLanguage.japanese: '証憑受取',
  },
  'taskTypeBorrow': {
    AppLanguage.simplifiedChinese: '借证',
    AppLanguage.traditionalChinese: '借證',
    AppLanguage.english: 'Borrow Evidence',
    AppLanguage.japanese: '証憑貸出',
  },
  'taskTypeReturn': {
    AppLanguage.simplifiedChinese: '还证',
    AppLanguage.traditionalChinese: '還證',
    AppLanguage.english: 'Return Evidence',
    AppLanguage.japanese: '証憑返却',
  },
  'taskTypeInventory': {
    AppLanguage.simplifiedChinese: '盘点',
    AppLanguage.traditionalChinese: '盤點',
    AppLanguage.english: 'Inventory Check',
    AppLanguage.japanese: '棚卸し',
  },
  // 操作员身份识别、账号登录与资料录入流程。
  'operatorAbnormalReportFailed': {
    AppLanguage.simplifiedChinese: '异常报备失败，请重新验证后再试',
    AppLanguage.traditionalChinese: '異常報備失敗，請重新驗證後再試',
    AppLanguage.english: 'Failed to report the anomaly. Verify again and retry',
    AppLanguage.japanese: '異常を報告できませんでした。再度認証してからお試しください',
  },
  'operatorAbnormalReporting': {
    AppLanguage.simplifiedChinese: '三项身份认证复核后仍有异常，正在向平台报备...',
    AppLanguage.traditionalChinese: '三項身分認證複核後仍有異常，正在向平台報備...',
    AppLanguage.english:
        'An anomaly remains after all three identity checks. Reporting it to the platform...',
    AppLanguage.japanese: '3 項目すべての本人確認後も異常が残っています。プラットフォームに報告しています...',
  },
  'operatorAbnormalVerificationBadge': {
    AppLanguage.simplifiedChinese: '异常复核 · 三项认证',
    AppLanguage.traditionalChinese: '異常複核 · 三項認證',
    AppLanguage.english: 'Anomaly Review · All Three Checks',
    AppLanguage.japanese: '異常再確認 · 3 項目必須',
  },
  'operatorAbnormalVerificationHint': {
    AppLanguage.simplifiedChinese: '本机资料存在异常，请完成人脸、指纹与 NFC 复核；三项均尝试后若仍有异常将报备重录',
    AppLanguage.traditionalChinese:
        '本機資料存在異常，請完成人臉、指紋與 NFC 複核；三項均嘗試後若仍有異常將報備重錄',
    AppLanguage.english:
        'Local identity data is abnormal. Complete all three identity checks; if the anomaly remains, it will be reported and the affected biometric data re-enrolled',
    AppLanguage.japanese:
        '端末内の本人確認情報に異常があります。3 項目すべてを再確認し、異常が残る場合は報告して該当する生体情報を再登録します',
  },
  'operatorAccountNotRecognized': {
    AppLanguage.simplifiedChinese: '未识别到账号，请重试或使用账号登录',
    AppLanguage.traditionalChinese: '未識別到帳號，請重試或使用帳號登入',
    AppLanguage.english:
        'Account not recognized. Try again or sign in with an account',
    AppLanguage.japanese: 'アカウントを認識できませんでした。再試行するか、アカウントでログインしてください',
  },
  'operatorConfirmFactor': {
    AppLanguage.simplifiedChinese: '确认识别',
    AppLanguage.traditionalChinese: '確認識別',
    AppLanguage.english: 'Confirm Verification',
    AppLanguage.japanese: '認証を確認',
  },
  'operatorFactorFaceName': {
    AppLanguage.simplifiedChinese: '人脸',
    AppLanguage.traditionalChinese: '人臉',
    AppLanguage.english: 'Face',
    AppLanguage.japanese: '顔',
  },
  'operatorFactorFingerprintName': {
    AppLanguage.simplifiedChinese: '指纹',
    AppLanguage.traditionalChinese: '指紋',
    AppLanguage.english: 'Fingerprint',
    AppLanguage.japanese: '指紋',
  },
  'operatorFactorVerificationSucceeded': {
    AppLanguage.simplifiedChinese: '{factor}识别通过',
    AppLanguage.traditionalChinese: '{factor}識別通過',
    AppLanguage.english: '{factor} verification passed',
    AppLanguage.japanese: '{factor}認証に成功しました',
  },
  'operatorFactorProfileUnavailable': {
    AppLanguage.simplifiedChinese: '当前身份资料不可用，请改用其他方式或重新录入',
    AppLanguage.traditionalChinese: '目前身分資料無法使用，請改用其他方式或重新錄入',
    AppLanguage.english:
        'The current identity information is unavailable. Use another method or enroll it again',
    AppLanguage.japanese: '現在の本人確認情報を利用できません。別の方法を使用するか、再登録してください',
  },
  'operatorEnrollFaceTitle': {
    AppLanguage.simplifiedChinese: '录入人脸',
    AppLanguage.traditionalChinese: '錄入人臉',
    AppLanguage.english: 'Enroll Face',
    AppLanguage.japanese: '顔情報を登録',
  },
  'operatorEnrollFingerprintTitle': {
    AppLanguage.simplifiedChinese: '录入指纹',
    AppLanguage.traditionalChinese: '錄入指紋',
    AppLanguage.english: 'Enroll Fingerprint',
    AppLanguage.japanese: '指紋を登録',
  },
  'operatorEnrollmentAccountInfo': {
    AppLanguage.simplifiedChinese: '账号：{name} · {organization}',
    AppLanguage.traditionalChinese: '帳號：{name} · {organization}',
    AppLanguage.english: 'Account: {name} · {organization}',
    AppLanguage.japanese: 'アカウント：{name} · {organization}',
  },
  'operatorEnrollmentBadge': {
    AppLanguage.simplifiedChinese: '身份资料录入',
    AppLanguage.traditionalChinese: '身分資料錄入',
    AppLanguage.english: 'Identity Enrollment',
    AppLanguage.japanese: '本人確認情報の登録',
  },
  'operatorEnrollmentBusy': {
    AppLanguage.simplifiedChinese: '录入中...',
    AppLanguage.traditionalChinese: '錄入中...',
    AppLanguage.english: 'Enrolling...',
    AppLanguage.japanese: '登録中...',
  },
  'operatorEnrollmentCancel': {
    AppLanguage.simplifiedChinese: '结束并返回首页',
    AppLanguage.traditionalChinese: '結束並返回首頁',
    AppLanguage.english: 'Finish and Return Home',
    AppLanguage.japanese: '終了してホームへ戻る',
  },
  'operatorEnrollmentFactorSucceeded': {
    AppLanguage.simplifiedChinese: '身份资料录入成功',
    AppLanguage.traditionalChinese: '身分資料錄入成功',
    AppLanguage.english: 'Identity information enrolled successfully',
    AppLanguage.japanese: '本人確認情報の登録が完了しました',
  },
  'operatorEnrollmentFactorResultSucceeded': {
    AppLanguage.simplifiedChinese: '{factor}录入成功',
    AppLanguage.traditionalChinese: '{factor}錄入成功',
    AppLanguage.english: '{factor} enrolled successfully',
    AppLanguage.japanese: '{factor}の登録が完了しました',
  },
  'operatorEnrollmentNfcUnsupported': {
    AppLanguage.simplifiedChinese: 'NFC 凭证不在本次录入范围内',
    AppLanguage.traditionalChinese: 'NFC 憑證不在本次錄入範圍內',
    AppLanguage.english: 'NFC credentials are not included in this enrollment',
    AppLanguage.japanese: 'NFC 認証情報は今回の登録対象ではありません',
  },
  'operatorEnrollmentFailed': {
    AppLanguage.simplifiedChinese: '身份资料录入失败，请检查设备后重试',
    AppLanguage.traditionalChinese: '身分資料錄入失敗，請檢查設備後重試',
    AppLanguage.english:
        'Identity enrollment failed. Check the device and try again',
    AppLanguage.japanese: '本人確認情報を登録できませんでした。デバイスを確認して再試行してください',
  },
  'operatorEnrollmentHeading': {
    AppLanguage.simplifiedChinese: '请录入缺失的身份资料',
    AppLanguage.traditionalChinese: '請錄入缺少的身分資料',
    AppLanguage.english: 'Enroll the missing identity information',
    AppLanguage.japanese: '未登録の本人確認情報を登録してください',
  },
  'operatorEnrollmentInProgress': {
    AppLanguage.simplifiedChinese: '正在采集身份资料，请保持姿势稳定...',
    AppLanguage.traditionalChinese: '正在採集身分資料，請保持姿勢穩定...',
    AppLanguage.english: 'Capturing identity information. Hold still...',
    AppLanguage.japanese: '本人確認情報を取得中です。姿勢を保ってください...',
  },
  'operatorEnrollmentNothingMissing': {
    AppLanguage.simplifiedChinese: '当前没有需要录入的身份资料',
    AppLanguage.traditionalChinese: '目前沒有需要錄入的身分資料',
    AppLanguage.english: 'No identity information needs to be enrolled',
    AppLanguage.japanese: '登録が必要な本人確認情報はありません',
  },
  'operatorEnrollmentReportedNotice': {
    AppLanguage.simplifiedChinese: '本机资料异常已报备，本次将重新录入异常项目',
    AppLanguage.traditionalChinese: '本機資料異常已報備，本次將重新錄入異常項目',
    AppLanguage.english:
        'The local information anomaly has been reported. The affected items will be enrolled again',
    AppLanguage.japanese: '端末内情報の異常を報告しました。今回は異常項目を再登録します',
  },
  'operatorEnrollmentReturnHome': {
    AppLanguage.simplifiedChinese: '立即返回首页',
    AppLanguage.traditionalChinese: '立即返回首頁',
    AppLanguage.english: 'Return Home Now',
    AppLanguage.japanese: '今すぐホームへ戻る',
  },
  'operatorEnrollmentStart': {
    AppLanguage.simplifiedChinese: '开始录入',
    AppLanguage.traditionalChinese: '開始錄入',
    AppLanguage.english: 'Start Enrollment',
    AppLanguage.japanese: '登録を開始',
  },
  'operatorEnrollmentSucceeded': {
    AppLanguage.simplifiedChinese: '身份资料录入成功，3 秒后返回首页重新登录',
    AppLanguage.traditionalChinese: '身分資料錄入成功，3 秒後返回首頁重新登入',
    AppLanguage.english:
        'Identity information enrolled successfully. Returning home in 3 seconds to sign in again',
    AppLanguage.japanese: '本人確認情報の登録が完了しました。3 秒後にホームへ戻り、再度ログインします',
  },
  'operatorFaceTitle': {
    AppLanguage.simplifiedChinese: '人脸识别',
    AppLanguage.traditionalChinese: '人臉識別',
    AppLanguage.english: 'Face Recognition',
    AppLanguage.japanese: '顔認証',
  },
  'operatorFactorBusy': {
    AppLanguage.simplifiedChinese: '识别中...',
    AppLanguage.traditionalChinese: '識別中...',
    AppLanguage.english: 'Verifying...',
    AppLanguage.japanese: '認証中...',
  },
  'operatorFactorDone': {
    AppLanguage.simplifiedChinese: '身份识别已完成',
    AppLanguage.traditionalChinese: '身分識別已完成',
    AppLanguage.english: 'Identity verification completed',
    AppLanguage.japanese: '本人確認が完了しました',
  },
  'operatorFactorSimulated': {
    AppLanguage.simplifiedChinese: '测试模式：身份模拟认证已完成',
    AppLanguage.traditionalChinese: '測試模式：身分模擬認證已完成',
    AppLanguage.english: 'Test mode: simulated identity verification completed',
    AppLanguage.japanese: 'テストモード：本人確認シミュレーションが完了しました',
  },
  'operatorFactorVerificationFailed': {
    AppLanguage.simplifiedChinese: '身份识别失败，请重试或改用其他方式',
    AppLanguage.traditionalChinese: '身分識別失敗，請重試或改用其他方式',
    AppLanguage.english:
        'Identity verification failed. Try again or use another method',
    AppLanguage.japanese: '本人確認に失敗しました。再試行するか別の方法を使用してください',
  },
  'operatorFactorVerifying': {
    AppLanguage.simplifiedChinese: '正在识别身份，请稍候...',
    AppLanguage.traditionalChinese: '正在識別身分，請稍候...',
    AppLanguage.english: 'Verifying identity. Please wait...',
    AppLanguage.japanese: '本人確認中です。しばらくお待ちください...',
  },
  'operatorFingerprintTitle': {
    AppLanguage.simplifiedChinese: '指纹识别',
    AppLanguage.traditionalChinese: '指紋識別',
    AppLanguage.english: 'Fingerprint Recognition',
    AppLanguage.japanese: '指紋認証',
  },
  'operatorIdentityFlowFailed': {
    AppLanguage.simplifiedChinese: '身份资料处理失败，请稍后重试',
    AppLanguage.traditionalChinese: '身分資料處理失敗，請稍後重試',
    AppLanguage.english:
        'Failed to process identity information. Try again later',
    AppLanguage.japanese: '本人確認情報を処理できませんでした。しばらくしてから再試行してください',
  },
  'operatorIdentitySyncSucceeded': {
    AppLanguage.simplifiedChinese: '身份资料已同步到本机，请完成人脸、指纹与 NFC 三项认证',
    AppLanguage.traditionalChinese: '身分資料已同步到本機，請完成人臉、指紋與 NFC 三項認證',
    AppLanguage.english:
        'Identity information has been synced to this terminal. Complete face, fingerprint, and NFC verification',
    AppLanguage.japanese: '本人確認情報を端末に同期しました。顔認証・指紋認証・NFC 認証をすべて完了してください',
  },
  'operatorInputPassword': {
    AppLanguage.simplifiedChinese: '输入密码',
    AppLanguage.traditionalChinese: '輸入密碼',
    AppLanguage.english: 'Enter Password',
    AppLanguage.japanese: 'パスワードを入力',
  },
  'operatorInputUsername': {
    AppLanguage.simplifiedChinese: '输入账号',
    AppLanguage.traditionalChinese: '輸入帳號',
    AppLanguage.english: 'Enter Account',
    AppLanguage.japanese: 'アカウントを入力',
  },
  'operatorKeyboardClear': {
    AppLanguage.simplifiedChinese: '清空',
    AppLanguage.traditionalChinese: '清空',
    AppLanguage.english: 'Clear',
    AppLanguage.japanese: 'クリア',
  },
  'operatorKeyboardDelete': {
    AppLanguage.simplifiedChinese: '删除',
    AppLanguage.traditionalChinese: '刪除',
    AppLanguage.english: 'Delete',
    AppLanguage.japanese: '削除',
  },
  'operatorLoginAction': {
    AppLanguage.simplifiedChinese: '登录',
    AppLanguage.traditionalChinese: '登入',
    AppLanguage.english: 'Sign In',
    AppLanguage.japanese: 'ログイン',
  },
  'operatorLoginServerHint': {
    AppLanguage.simplifiedChinese: '请输入平台分配的账号与密码',
    AppLanguage.traditionalChinese: '請輸入平台分配的帳號與密碼',
    AppLanguage.english:
        'Enter the account and password assigned by the platform',
    AppLanguage.japanese: 'プラットフォームから割り当てられたアカウントとパスワードを入力してください',
  },
  'operatorLoginDenied': {
    AppLanguage.simplifiedChinese: '账号或密码错误，请重新输入',
    AppLanguage.traditionalChinese: '帳號或密碼錯誤，請重新輸入',
    AppLanguage.english: 'Incorrect account or password. Try again',
    AppLanguage.japanese: 'アカウントまたはパスワードが正しくありません。再入力してください',
  },
  'operatorLoginFailed': {
    AppLanguage.simplifiedChinese: '账号登录失败，请稍后重试',
    AppLanguage.traditionalChinese: '帳號登入失敗，請稍後重試',
    AppLanguage.english: 'Account sign-in failed. Try again later',
    AppLanguage.japanese: 'アカウントログインに失敗しました。しばらくしてから再試行してください',
  },
  'operatorLoginInvalidResponse': {
    AppLanguage.simplifiedChinese: 'AFRR 登录回复无效，请联系平台管理员',
    AppLanguage.traditionalChinese: 'AFRR 登入回覆無效，請聯絡平台管理員',
    AppLanguage.english:
        'The sign-in service returned invalid data. Contact the platform administrator',
    AppLanguage.japanese: 'ログインサービスから無効なデータが返されました。プラットフォーム管理者に連絡してください',
  },
  'operatorLoginInvalidServerConfig': {
    AppLanguage.simplifiedChinese: 'AFRR 登录参数无效，请联系管理员检查终端配置',
    AppLanguage.traditionalChinese: 'AFRR 登入參數無效，請聯絡管理員檢查終端設定',
    AppLanguage.english:
        'The server address is invalid. Ask an administrator to check the terminal configuration',
    AppLanguage.japanese: 'サーバーアドレスが無効です。管理者に端末設定の確認を依頼してください',
  },
  'operatorLoginTimeout': {
    AppLanguage.simplifiedChinese: '连接 AFRR 登录服务超时，请检查柜机网络后重试',
    AppLanguage.traditionalChinese: '連線 AFRR 登入服務逾時，請檢查櫃機網路後重試',
    AppLanguage.english:
        'The server connection timed out. Check the cabinet network and try again',
    AppLanguage.japanese: 'サーバー接続がタイムアウトしました。キャビネットのネットワークを確認して再試行してください',
  },
  'operatorLoginNetworkUnavailable': {
    AppLanguage.simplifiedChinese: '无法连接 AFRR 登录服务，请检查柜机网络和服务状态',
    AppLanguage.traditionalChinese: '無法連線 AFRR 登入服務，請檢查櫃機網路與服務狀態',
    AppLanguage.english:
        'Unable to connect to the server. Check the cabinet network and server status',
    AppLanguage.japanese: 'サーバーに接続できません。キャビネットのネットワークとサーバーの状態を確認してください',
  },
  'operatorLoginRequired': {
    AppLanguage.simplifiedChinese: '请输入账号和密码',
    AppLanguage.traditionalChinese: '請輸入帳號和密碼',
    AppLanguage.english: 'Enter an account and password',
    AppLanguage.japanese: 'アカウントとパスワードを入力してください',
  },
  'operatorLoginTitle': {
    AppLanguage.simplifiedChinese: '账号登录',
    AppLanguage.traditionalChinese: '帳號登入',
    AppLanguage.english: 'Account Sign-In',
    AppLanguage.japanese: 'アカウントログイン',
  },
  'operatorLoginVisualDescription': {
    AppLanguage.simplifiedChinese: '确认账号后继续完成人脸、指纹与 NFC 三项身份认证',
    AppLanguage.traditionalChinese: '確認帳號後繼續完成人臉、指紋與 NFC 三項身分認證',
    AppLanguage.english:
        'Confirm the account, then complete face, fingerprint, and NFC verification',
    AppLanguage.japanese: 'アカウント確認後、顔認証・指紋認証・NFC 認証をすべて完了してください',
  },
  'operatorLoginVisualTitle': {
    AppLanguage.simplifiedChinese: '操作员账号登录',
    AppLanguage.traditionalChinese: '操作員帳號登入',
    AppLanguage.english: 'Operator Account Sign-In',
    AppLanguage.japanese: 'オペレーターアカウントログイン',
  },
  'operatorNfcTitle': {
    AppLanguage.simplifiedChinese: 'NFC识别',
    AppLanguage.traditionalChinese: 'NFC識別',
    AppLanguage.english: 'NFC Verification',
    AppLanguage.japanese: 'NFC 認証',
  },
  'operatorOptionalFactorSuffix': {
    AppLanguage.simplifiedChinese: '可选',
    AppLanguage.traditionalChinese: '可選',
    AppLanguage.english: 'Optional',
    AppLanguage.japanese: '任意',
  },
  'operatorPasswordLabel': {
    AppLanguage.simplifiedChinese: '密码',
    AppLanguage.traditionalChinese: '密碼',
    AppLanguage.english: 'Password',
    AppLanguage.japanese: 'パスワード',
  },
  'operatorRequiredFactorSuffix': {
    AppLanguage.simplifiedChinese: '必选',
    AppLanguage.traditionalChinese: '必選',
    AppLanguage.english: 'Required',
    AppLanguage.japanese: '必須',
  },
  'operatorRequiredVerificationBadge': {
    AppLanguage.simplifiedChinese: '身份校验中 · 三项必选',
    AppLanguage.traditionalChinese: '身分校驗中 · 三項必選',
    AppLanguage.english: 'Identity Check · All Three Required',
    AppLanguage.japanese: '本人確認中 · 3 項目必須',
  },
  'operatorRequiredVerificationHeading': {
    AppLanguage.simplifiedChinese: '请完成人脸、指纹与 NFC 认证',
    AppLanguage.traditionalChinese: '請完成人臉、指紋與 NFC 認證',
    AppLanguage.english: 'Complete face, fingerprint, and NFC verification',
    AppLanguage.japanese: '顔認証・指紋認証・NFC 認証を完了してください',
  },
  'operatorSyncedVerificationHint': {
    AppLanguage.simplifiedChinese: '服务端资料已同步，本次必须完成人脸、指纹与 NFC 三项认证',
    AppLanguage.traditionalChinese: '服務端資料已同步，本次必須完成人臉、指紋與 NFC 三項認證',
    AppLanguage.english:
        'Server identity data has been synced. Face, fingerprint, and NFC verification are all required',
    AppLanguage.japanese: 'サーバーの本人確認情報を同期しました。顔認証・指紋認証・NFC 認証をすべて完了してください',
  },
  'operatorUsernameLabel': {
    AppLanguage.simplifiedChinese: '账号',
    AppLanguage.traditionalChinese: '帳號',
    AppLanguage.english: 'Account',
    AppLanguage.japanese: 'アカウント',
  },
  'operatorVerificationAccountInfo': {
    AppLanguage.simplifiedChinese: '当前账号：{name} · {organization}',
    AppLanguage.traditionalChinese: '目前帳號：{name} · {organization}',
    AppLanguage.english: 'Current account: {name} · {organization}',
    AppLanguage.japanese: '現在のアカウント：{name} · {organization}',
  },
  'operatorVerificationBack': {
    AppLanguage.simplifiedChinese: '返回首页',
    AppLanguage.traditionalChinese: '返回首頁',
    AppLanguage.english: 'Back Home',
    AppLanguage.japanese: 'ホームへ戻る',
  },
  'operatorVerificationTitle': {
    AppLanguage.simplifiedChinese: '操作员身份校验',
    AppLanguage.traditionalChinese: '操作員身分校驗',
    AppLanguage.english: 'Operator Identity Check',
    AppLanguage.japanese: 'オペレーター本人確認',
  },
  'operatorVerificationProgress': {
    AppLanguage.simplifiedChinese: '已完成 {count} / {total} 项认证',
    AppLanguage.traditionalChinese: '已完成 {count} / {total} 項認證',
    AppLanguage.english: '{count} / {total} checks completed',
    AppLanguage.japanese: '{count} / {total} 項目の認証が完了',
  },
  'operatorVerificationBadge': {
    AppLanguage.simplifiedChinese: '身份校验中 · 三项必选',
    AppLanguage.traditionalChinese: '身分校驗中 · 三項必選',
    AppLanguage.english: 'Identity Check · All Three Required',
    AppLanguage.japanese: '本人確認中 · 3 項目必須',
  },
  'operatorVerificationHeading': {
    AppLanguage.simplifiedChinese: '请完成人脸、指纹与 NFC 三项身份认证',
    AppLanguage.traditionalChinese: '請完成人臉、指紋與 NFC 三項身分認證',
    AppLanguage.english: 'Complete face, fingerprint, and NFC verification',
    AppLanguage.japanese: '顔認証・指紋認証・NFC 認証をすべて完了してください',
  },
  'operatorVerificationIdentifyHint': {
    AppLanguage.simplifiedChinese: '首个身份因子用于识别账号，其余两项用于完成本人确认',
    AppLanguage.traditionalChinese: '首個身分因子用於識別帳號，其餘兩項用於完成本人確認',
    AppLanguage.english:
        'The first factor identifies the account; the other two complete operator verification',
    AppLanguage.japanese: '最初の認証要素でアカウントを特定し、残りの 2 項目で本人確認を完了します',
  },
  'operatorVerificationUseAccount': {
    AppLanguage.simplifiedChinese: '识别不到账号？使用账号登录',
    AppLanguage.traditionalChinese: '識別不到帳號？使用帳號登入',
    AppLanguage.english: 'Account not recognized? Sign in with an account',
    AppLanguage.japanese: 'アカウントを認識できませんか？アカウントでログイン',
  },
  // 任务工作台、任务执行步骤与操作文案。
  'taskActionAssignSlot': {
    AppLanguage.simplifiedChinese: '请求平台分箱',
    AppLanguage.traditionalChinese: '請求平台分箱',
    AppLanguage.english: 'Request Slot Assignment',
    AppLanguage.japanese: 'プラットフォームに格納区画を要求',
  },
  'taskActionAttachRfid': {
    AppLanguage.simplifiedChinese: '模拟读取 RFID',
    AppLanguage.traditionalChinese: '模擬讀取 RFID',
    AppLanguage.english: 'Simulate RFID Read',
    AppLanguage.japanese: 'RFID 読取をシミュレート',
  },
  'taskActionAuthorizeSlot': {
    AppLanguage.simplifiedChinese: '确认平台授权箱格',
    AppLanguage.traditionalChinese: '確認平台授權箱格',
    AppLanguage.english: 'Confirm Authorized Slot',
    AppLanguage.japanese: 'プラットフォームの承認区画を確認',
  },
  'taskActionCaptureBack': {
    AppLanguage.simplifiedChinese: '拍摄反面',
    AppLanguage.traditionalChinese: '拍攝反面',
    AppLanguage.english: 'Capture Back',
    AppLanguage.japanese: '裏面を撮影',
  },
  'taskActionCaptureFront': {
    AppLanguage.simplifiedChinese: '拍摄正面',
    AppLanguage.traditionalChinese: '拍攝正面',
    AppLanguage.english: 'Capture Front',
    AppLanguage.japanese: '表面を撮影',
  },
  'taskActionCloseDoorAndReport': {
    AppLanguage.simplifiedChinese: '确认已关门并上报',
    AppLanguage.traditionalChinese: '確認已關門並上報',
    AppLanguage.english: 'Confirm Door Closed and Report',
    AppLanguage.japanese: '扉を閉めたことを確認して報告',
  },
  'taskActionOpenDoor': {
    AppLanguage.simplifiedChinese: '通知打开柜门',
    AppLanguage.traditionalChinese: '通知打開櫃門',
    AppLanguage.english: 'Notify Door to Open',
    AppLanguage.japanese: 'キャビネット扉を開くよう通知',
  },
  'taskActionReviewPendingItems': {
    AppLanguage.simplifiedChinese: '确认待办列表',
    AppLanguage.traditionalChinese: '確認待辦列表',
    AppLanguage.english: 'Confirm Pending List',
    AppLanguage.japanese: '保留リストを確認',
  },
  'taskActionRunOcr': {
    AppLanguage.simplifiedChinese: '执行 OCR 并确认',
    AppLanguage.traditionalChinese: '執行 OCR 並確認',
    AppLanguage.english: 'Run OCR and Confirm',
    AppLanguage.japanese: 'OCR を実行して確認',
  },
  'taskActionScanRfid': {
    AppLanguage.simplifiedChinese: '模拟扫描 RFID',
    AppLanguage.traditionalChinese: '模擬掃描 RFID',
    AppLanguage.english: 'Simulate RFID Scan',
    AppLanguage.japanese: 'RFID スキャンをシミュレート',
  },
  'taskActionTransferDone': {
    AppLanguage.simplifiedChinese: '确认本次存取或盘点完成',
    AppLanguage.traditionalChinese: '確認本次存取或盤點完成',
    AppLanguage.english: 'Confirm Transfer or Inventory Complete',
    AppLanguage.japanese: '今回の入出庫または棚卸しの完了を確認',
  },
  'taskActionVerifyPickupCode': {
    AppLanguage.simplifiedChinese: '确认取件码',
    AppLanguage.traditionalChinese: '確認取件碼',
    AppLanguage.english: 'Confirm Pickup Code',
    AppLanguage.japanese: '受取コードを確認',
  },
  'taskCenterAccountId': {
    AppLanguage.simplifiedChinese: '账号 ID',
    AppLanguage.traditionalChinese: '帳號 ID',
    AppLanguage.english: 'Account ID',
    AppLanguage.japanese: 'アカウント ID',
  },
  'taskCenterAge': {
    AppLanguage.simplifiedChinese: '年龄',
    AppLanguage.traditionalChinese: '年齡',
    AppLanguage.english: 'Age',
    AppLanguage.japanese: '年齢',
  },
  'taskCenterAuthenticatedBadge': {
    AppLanguage.simplifiedChinese: '身份认证已通过 · {count} 项因子',
    AppLanguage.traditionalChinese: '身分認證已通過 · {count} 項因子',
    AppLanguage.english: 'Identity verified · {count} factors',
    AppLanguage.japanese: '本人確認済み · {count} 要素',
  },
  'taskCenterInactivityCountdown': {
    AppLanguage.simplifiedChinese: '无操作自动退出倒计时',
    AppLanguage.traditionalChinese: '無操作自動退出倒數',
    AppLanguage.english: 'Automatic sign-out countdown',
    AppLanguage.japanese: '自動ログアウトまでのカウントダウン',
  },
  'taskCenterAvailableTasks': {
    AppLanguage.simplifiedChinese: '当前可执行任务',
    AppLanguage.traditionalChinese: '目前可執行任務',
    AppLanguage.english: 'Available Tasks',
    AppLanguage.japanese: '実行可能なタスク',
  },
  'taskCenterCompany': {
    AppLanguage.simplifiedChinese: '公司',
    AppLanguage.traditionalChinese: '公司',
    AppLanguage.english: 'Company',
    AppLanguage.japanese: '会社',
  },
  'taskCenterDoorOpenCannotLogout': {
    AppLanguage.simplifiedChinese: '仍有柜门未关闭，暂不能退出登录',
    AppLanguage.traditionalChinese: '仍有櫃門未關閉，暫不能退出登入',
    AppLanguage.english:
        'A cabinet door is still open. Sign-out is unavailable',
    AppLanguage.japanese: '閉じていない扉があるため、ログアウトできません',
  },
  'taskCenterLoadFailed': {
    AppLanguage.simplifiedChinese: '任务加载失败：{error}',
    AppLanguage.traditionalChinese: '任務載入失敗：{error}',
    AppLanguage.english: 'Failed to load tasks: {error}',
    AppLanguage.japanese: 'タスクの読み込みに失敗しました：{error}',
  },
  'taskCenterGender': {
    AppLanguage.simplifiedChinese: '性别',
    AppLanguage.traditionalChinese: '性別',
    AppLanguage.english: 'Gender',
    AppLanguage.japanese: '性別',
  },
  'taskCenterLogout': {
    AppLanguage.simplifiedChinese: '退出登录',
    AppLanguage.traditionalChinese: '退出登入',
    AppLanguage.english: 'Sign Out',
    AppLanguage.japanese: 'ログアウト',
  },
  'taskCenterNoTaskCountdown': {
    AppLanguage.simplifiedChinese: '当前无任务，{seconds} 秒后退出登录',
    AppLanguage.traditionalChinese: '目前無任務，{seconds} 秒後退出登入',
    AppLanguage.english: 'No tasks. Signing out in {seconds} seconds',
    AppLanguage.japanese: '現在タスクはありません。{seconds} 秒後にログアウトします',
  },
  'taskCenterNoTaskOfType': {
    AppLanguage.simplifiedChinese: '暂无此类任务',
    AppLanguage.traditionalChinese: '暫無此類任務',
    AppLanguage.english: 'No task of this type',
    AppLanguage.japanese: 'この種類のタスクはありません',
  },
  'taskCenterNoTasks': {
    AppLanguage.simplifiedChinese: '当前无待办任务',
    AppLanguage.traditionalChinese: '目前無待辦任務',
    AppLanguage.english: 'No Pending Tasks',
    AppLanguage.japanese: '保留中のタスクはありません',
  },
  'taskCenterOrganization': {
    AppLanguage.simplifiedChinese: '监管机构',
    AppLanguage.traditionalChinese: '監管機構',
    AppLanguage.english: 'Regulatory Authority',
    AppLanguage.japanese: '監督機関',
  },
  'taskCenterPhoneNumber': {
    AppLanguage.simplifiedChinese: '手机号',
    AppLanguage.traditionalChinese: '手機號碼',
    AppLanguage.english: 'Mobile',
    AppLanguage.japanese: '携帯番号',
  },
  'taskCenterPosition': {
    AppLanguage.simplifiedChinese: '职位',
    AppLanguage.traditionalChinese: '職位',
    AppLanguage.english: 'Position',
    AppLanguage.japanese: '役職',
  },
  'taskCenterRefresh': {
    AppLanguage.simplifiedChinese: '刷新任务',
    AppLanguage.traditionalChinese: '重新整理任務',
    AppLanguage.english: 'Refresh Tasks',
    AppLanguage.japanese: 'タスクを更新',
  },
  'taskCenterRetry': {
    AppLanguage.simplifiedChinese: '重新加载',
    AppLanguage.traditionalChinese: '重新載入',
    AppLanguage.english: 'Reload',
    AppLanguage.japanese: '再読み込み',
  },
  'taskCenterStartTask': {
    AppLanguage.simplifiedChinese: '开始任务',
    AppLanguage.traditionalChinese: '開始任務',
    AppLanguage.english: 'Start Task',
    AppLanguage.japanese: 'タスクを開始',
  },
  'taskCenterTaskCount': {
    AppLanguage.simplifiedChinese: '{count} 项',
    AppLanguage.traditionalChinese: '{count} 項',
    AppLanguage.english: '{count} tasks',
    AppLanguage.japanese: '{count} 件',
  },
  'taskCenterTaskSummary': {
    AppLanguage.simplifiedChinese: '本机构共有 {count} 项待办任务',
    AppLanguage.traditionalChinese: '本機構共有 {count} 項待辦任務',
    AppLanguage.english: '{count} pending tasks for this organization',
    AppLanguage.japanese: 'この機関には {count} 件の保留タスクがあります',
  },
  'taskCenterTitle': {
    AppLanguage.simplifiedChinese: '任务工作台',
    AppLanguage.traditionalChinese: '任務工作台',
    AppLanguage.english: 'Task Workbench',
    AppLanguage.japanese: 'タスクワークベンチ',
  },
  'taskCenterVerifiedFactors': {
    AppLanguage.simplifiedChinese: '认证因子',
    AppLanguage.traditionalChinese: '認證因子',
    AppLanguage.english: 'Verified Factors',
    AppLanguage.japanese: '認証要素',
  },
  'taskCenterWaitingDoorClose': {
    AppLanguage.simplifiedChinese: '等待全部柜门关闭后再退出登录',
    AppLanguage.traditionalChinese: '等待全部櫃門關閉後再退出登入',
    AppLanguage.english: 'Close all cabinet doors before signing out',
    AppLanguage.japanese: 'すべての扉が閉じるまでログアウトできません',
  },
  'taskExecutionActionFailed': {
    AppLanguage.simplifiedChinese: '步骤执行失败：{error}',
    AppLanguage.traditionalChinese: '步驟執行失敗：{error}',
    AppLanguage.english: 'Step failed: {error}',
    AppLanguage.japanese: 'ステップの実行に失敗しました：{error}',
  },
  'taskExecutionAllStepsDone': {
    AppLanguage.simplifiedChinese: '全部步骤已完成',
    AppLanguage.traditionalChinese: '全部步驟已完成',
    AppLanguage.english: 'All Steps Completed',
    AppLanguage.japanese: 'すべてのステップが完了しました',
  },
  'taskExecutionAnotherDoorOpen': {
    AppLanguage.simplifiedChinese:
        '柜门 {activeDoorNo} 尚未关闭，不能打开 {requestedDoorNo}',
    AppLanguage.traditionalChinese:
        '櫃門 {activeDoorNo} 尚未關閉，無法打開 {requestedDoorNo}',
    AppLanguage.english:
        'Door {activeDoorNo} is still open. Cannot open {requestedDoorNo}',
    AppLanguage.japanese:
        '扉 {activeDoorNo} がまだ閉じていないため、{requestedDoorNo} を開けません',
  },
  'taskExecutionUpgradeMaintenanceActive': {
    AppLanguage.simplifiedChinese: '系统正在执行升级维护，暂不能打开柜门',
    AppLanguage.traditionalChinese: '系統正在執行升級維護，暫時無法打開櫃門',
    AppLanguage.english:
        'A system upgrade is in progress. Cabinet doors cannot be opened',
    AppLanguage.japanese: 'システム更新中のため、キャビネットの扉を開けません',
  },
  'taskExecutionDoorOpenBlocked': {
    AppLanguage.simplifiedChinese: '当前不能打开柜门，请稍后重试',
    AppLanguage.traditionalChinese: '目前無法打開櫃門，請稍後再試',
    AppLanguage.english: 'The cabinet door cannot be opened. Try again later',
    AppLanguage.japanese: '現在は扉を開けません。しばらくしてから再度お試しください',
  },
  'taskExecutionAssignedSlot': {
    AppLanguage.simplifiedChinese: '平台箱格：{doorNo}',
    AppLanguage.traditionalChinese: '平台箱格：{doorNo}',
    AppLanguage.english: 'Platform slot: {doorNo}',
    AppLanguage.japanese: 'プラットフォーム指定区画：{doorNo}',
  },
  'taskExecutionBack': {
    AppLanguage.simplifiedChinese: '返回任务工作台',
    AppLanguage.traditionalChinese: '返回任務工作台',
    AppLanguage.english: 'Back to Task Workbench',
    AppLanguage.japanese: 'タスクワークベンチへ戻る',
  },
  'taskExecutionBadge': {
    AppLanguage.simplifiedChinese: '{type}任务执行中',
    AppLanguage.traditionalChinese: '{type}任務執行中',
    AppLanguage.english: '{type} Task in Progress',
    AppLanguage.japanese: '{type}タスク実行中',
  },
  'taskExecutionCloseTargetMissing': {
    AppLanguage.simplifiedChinese: '没有可确认关闭的柜门',
    AppLanguage.traditionalChinese: '沒有可確認關閉的櫃門',
    AppLanguage.english:
        'No cabinet door is available for closure confirmation',
    AppLanguage.japanese: '閉鎖を確認できるキャビネット扉がありません',
  },
  'taskExecutionCompletedTitle': {
    AppLanguage.simplifiedChinese: '{type}任务已经完成',
    AppLanguage.traditionalChinese: '{type}任務已經完成',
    AppLanguage.english: '{type} Task Completed',
    AppLanguage.japanese: '{type}タスクが完了しました',
  },
  'taskExecutionDoorCountdown': {
    AppLanguage.simplifiedChinese: '柜门 {doorNo} 已打开，请在 {seconds} 秒内完成存取并关门',
    AppLanguage.traditionalChinese: '櫃門 {doorNo} 已打開，請在 {seconds} 秒內完成存取並關門',
    AppLanguage.english:
        'Door {doorNo} is open. Complete the operation and close the door within {seconds} seconds',
    AppLanguage.japanese: '扉 {doorNo} が開いています。{seconds} 秒以内に操作を完了して扉を閉めてください',
  },
  'taskExecutionDoorStateMismatch': {
    AppLanguage.simplifiedChinese: '柜门状态与当前任务不一致，柜门互锁未释放',
    AppLanguage.traditionalChinese: '櫃門狀態與目前任務不一致，櫃門互鎖未解除',
    AppLanguage.english:
        'The cabinet door state does not match the current task. The door interlock remains engaged',
    AppLanguage.japanese: '扉の状態が現在のタスクと一致しないため、扉のインターロックは解除されていません',
  },
  'taskExecutionDoorTimeoutAlarm': {
    AppLanguage.simplifiedChinese: '柜门 {doorNo} 超时未关闭，请立即处理',
    AppLanguage.traditionalChinese: '櫃門 {doorNo} 逾時未關閉，請立即處理',
    AppLanguage.english:
        'Door {doorNo} was not closed in time. Act immediately',
    AppLanguage.japanese: '扉 {doorNo} が時間内に閉じられていません。直ちに対応してください',
  },
  'taskExecutionDoorValidationFailed': {
    AppLanguage.simplifiedChinese: '任务箱格信息已变更，请返回任务工作台刷新',
    AppLanguage.traditionalChinese: '任務箱格資訊已變更，請返回任務工作台重新整理',
    AppLanguage.english:
        'The task slot information has changed. Return to the task workbench and refresh',
    AppLanguage.japanese: 'タスクの格納区画情報が変更されました。タスクワークベンチに戻って更新してください',
  },
  'taskExecutionInstitutionSlotConflict': {
    AppLanguage.simplifiedChinese: '箱格 {doorNo} 已绑定其他机构，当前机构无权使用',
    AppLanguage.traditionalChinese: '箱格 {doorNo} 已綁定其他機構，目前機構無權使用',
    AppLanguage.english:
        'Slot {doorNo} is assigned to another organization. The current organization is not authorized to use it',
    AppLanguage.japanese: '区画 {doorNo} は別の機関に割り当てられているため、現在の機関には使用権限がありません',
  },
  'taskExecutionLoadFailed': {
    AppLanguage.simplifiedChinese: '任务加载失败：{error}',
    AppLanguage.traditionalChinese: '任務載入失敗：{error}',
    AppLanguage.english: 'Failed to load task: {error}',
    AppLanguage.japanese: 'タスクの読み込みに失敗しました：{error}',
  },
  'taskExecutionLoadingBadge': {
    AppLanguage.simplifiedChinese: '任务加载中',
    AppLanguage.traditionalChinese: '任務載入中',
    AppLanguage.english: 'Loading Task',
    AppLanguage.japanese: 'タスクを読み込み中',
  },
  'taskExecutionNoTaskExit': {
    AppLanguage.simplifiedChinese: '当前无其他任务，{seconds} 秒后退出登录',
    AppLanguage.traditionalChinese: '目前無其他任務，{seconds} 秒後退出登入',
    AppLanguage.english: 'No other tasks. Signing out in {seconds} seconds',
    AppLanguage.japanese: '他のタスクはありません。{seconds} 秒後にログアウトします',
  },
  'taskExecutionOrganization': {
    AppLanguage.simplifiedChinese: '监管机构',
    AppLanguage.traditionalChinese: '監管機構',
    AppLanguage.english: 'Regulatory Authority',
    AppLanguage.japanese: '監督機関',
  },
  'taskExecutionPendingItems': {
    AppLanguage.simplifiedChinese: '待办证件列表',
    AppLanguage.traditionalChinese: '待辦證件列表',
    AppLanguage.english: 'Pending Document List',
    AppLanguage.japanese: '保留中の証憑リスト',
  },
  'taskExecutionPickupCodeEmpty': {
    AppLanguage.simplifiedChinese: '请输入取件码',
    AppLanguage.traditionalChinese: '請輸入取件碼',
    AppLanguage.english: 'Enter the pickup code',
    AppLanguage.japanese: '受取コードを入力してください',
  },
  'taskExecutionPickupCodeHint': {
    AppLanguage.simplifiedChinese: '请输入平台下发的取件码',
    AppLanguage.traditionalChinese: '請輸入平台下發的取件碼',
    AppLanguage.english: 'Enter the pickup code issued by the platform',
    AppLanguage.japanese: 'プラットフォームから発行された受取コードを入力してください',
  },
  'taskExecutionPickupCodeIncorrect': {
    AppLanguage.simplifiedChinese: '取件码错误，请重新输入',
    AppLanguage.traditionalChinese: '取件碼錯誤，請重新輸入',
    AppLanguage.english: 'Incorrect pickup code. Enter it again',
    AppLanguage.japanese: '受取コードが正しくありません。再入力してください',
  },
  'taskExecutionPickupCodeInput': {
    AppLanguage.simplifiedChinese: '输入取件码',
    AppLanguage.traditionalChinese: '輸入取件碼',
    AppLanguage.english: 'Enter Pickup Code',
    AppLanguage.japanese: '受取コードを入力',
  },
  'taskExecutionPickupCodeNotConfigured': {
    AppLanguage.simplifiedChinese: '当前任务未配置取件码，请联系平台处理',
    AppLanguage.traditionalChinese: '目前任務未設定取件碼，請聯絡平台處理',
    AppLanguage.english:
        'No pickup code is configured for this task. Contact platform support',
    AppLanguage.japanese: 'このタスクには受取コードが設定されていません。プラットフォームにお問い合わせください',
  },
  'taskExecutionPickupCodeUnavailable': {
    AppLanguage.simplifiedChinese: '当前步骤无法校验取件码，请刷新任务',
    AppLanguage.traditionalChinese: '目前步驟無法驗證取件碼，請重新整理任務',
    AppLanguage.english:
        'The pickup code cannot be verified at this step. Refresh the task',
    AppLanguage.japanese: '現在のステップでは受取コードを確認できません。タスクを更新してください',
  },
  'taskExecutionProcessing': {
    AppLanguage.simplifiedChinese: '处理中...',
    AppLanguage.traditionalChinese: '處理中...',
    AppLanguage.english: 'Processing...',
    AppLanguage.japanese: '処理中...',
  },
  'taskExecutionProgress': {
    AppLanguage.simplifiedChinese: '步骤进度',
    AppLanguage.traditionalChinese: '步驟進度',
    AppLanguage.english: 'Step Progress',
    AppLanguage.japanese: 'ステップ進捗',
  },
  'taskExecutionRemainingTasks': {
    AppLanguage.simplifiedChinese: '还有 {count} 项任务待处理',
    AppLanguage.traditionalChinese: '還有 {count} 項任務待處理',
    AppLanguage.english: '{count} tasks remain',
    AppLanguage.japanese: '残り {count} 件のタスクがあります',
  },
  'taskExecutionRetry': {
    AppLanguage.simplifiedChinese: '重新加载',
    AppLanguage.traditionalChinese: '重新載入',
    AppLanguage.english: 'Reload',
    AppLanguage.japanese: '再読み込み',
  },
  'taskExecutionReturnCenter': {
    AppLanguage.simplifiedChinese: '返回任务工作台',
    AppLanguage.traditionalChinese: '返回任務工作台',
    AppLanguage.english: 'Return to Task Workbench',
    AppLanguage.japanese: 'タスクワークベンチへ戻る',
  },
  'taskExecutionSlotMissing': {
    AppLanguage.simplifiedChinese: '平台尚未返回可用箱格',
    AppLanguage.traditionalChinese: '平台尚未返回可用箱格',
    AppLanguage.english: 'The platform has not returned an available slot',
    AppLanguage.japanese: 'プラットフォームから利用可能な区画が返されていません',
  },
  'taskExecutionStepCompleted': {
    AppLanguage.simplifiedChinese: '已完成',
    AppLanguage.traditionalChinese: '已完成',
    AppLanguage.english: 'Completed',
    AppLanguage.japanese: '完了',
  },
  'taskExecutionStepCurrent': {
    AppLanguage.simplifiedChinese: '当前步骤',
    AppLanguage.traditionalChinese: '目前步驟',
    AppLanguage.english: 'Current Step',
    AppLanguage.japanese: '現在のステップ',
  },
  'taskExecutionStepPending': {
    AppLanguage.simplifiedChinese: '等待执行',
    AppLanguage.traditionalChinese: '等待執行',
    AppLanguage.english: 'Pending',
    AppLanguage.japanese: '実行待ち',
  },
  'taskExecutionTaskId': {
    AppLanguage.simplifiedChinese: '任务编号',
    AppLanguage.traditionalChinese: '任務編號',
    AppLanguage.english: 'Task ID',
    AppLanguage.japanese: 'タスク ID',
  },
  'taskExecutionWaitingSlot': {
    AppLanguage.simplifiedChinese: '等待平台分配或授权箱格',
    AppLanguage.traditionalChinese: '等待平台分配或授權箱格',
    AppLanguage.english:
        'Waiting for the platform to assign or authorize a slot',
    AppLanguage.japanese: 'プラットフォームによる区画の割当または承認を待っています',
  },
  'taskExecutionWorkflow': {
    AppLanguage.simplifiedChinese: '任务执行步骤',
    AppLanguage.traditionalChinese: '任務執行步驟',
    AppLanguage.english: 'Task Steps',
    AppLanguage.japanese: 'タスク実行ステップ',
  },
  'taskStepAssignSlot': {
    AppLanguage.simplifiedChinese: '向平台请求分箱',
    AppLanguage.traditionalChinese: '向平台請求分箱',
    AppLanguage.english: 'Request a slot from the platform',
    AppLanguage.japanese: 'プラットフォームに格納区画を要求',
  },
  'taskStepAttachRfid': {
    AppLanguage.simplifiedChinese: '贴 RFID 并读取',
    AppLanguage.traditionalChinese: '貼 RFID 並讀取',
    AppLanguage.english: 'Attach and Read RFID',
    AppLanguage.japanese: 'RFID を貼付して読み取る',
  },
  'taskStepAuthorizeSlot': {
    AppLanguage.simplifiedChinese: '向平台确认授权箱格',
    AppLanguage.traditionalChinese: '向平台確認授權箱格',
    AppLanguage.english: 'Confirm an authorized slot with the platform',
    AppLanguage.japanese: 'プラットフォームの承認区画を確認',
  },
  'taskStepCaptureBack': {
    AppLanguage.simplifiedChinese: '拍摄证件反面',
    AppLanguage.traditionalChinese: '拍攝證件反面',
    AppLanguage.english: 'Capture Document Back',
    AppLanguage.japanese: '証憑の裏面を撮影',
  },
  'taskStepCaptureFront': {
    AppLanguage.simplifiedChinese: '拍摄证件正面',
    AppLanguage.traditionalChinese: '拍攝證件正面',
    AppLanguage.english: 'Capture Document Front',
    AppLanguage.japanese: '証憑の表面を撮影',
  },
  'taskStepCloseDoorAndReport': {
    AppLanguage.simplifiedChinese: '确认关门并上报平台',
    AppLanguage.traditionalChinese: '確認關門並上報平台',
    AppLanguage.english: 'Confirm Door Closed and Report to Platform',
    AppLanguage.japanese: '扉を閉めたことを確認してプラットフォームへ報告',
  },
  'taskStepOpenDoor': {
    AppLanguage.simplifiedChinese: '打开指定柜门',
    AppLanguage.traditionalChinese: '打開指定櫃門',
    AppLanguage.english: 'Open Assigned Cabinet Door',
    AppLanguage.japanese: '指定されたキャビネット扉を開く',
  },
  'taskStepReviewPendingItems': {
    AppLanguage.simplifiedChinese: '确认待办证件列表',
    AppLanguage.traditionalChinese: '確認待辦證件列表',
    AppLanguage.english: 'Confirm Pending Document List',
    AppLanguage.japanese: '保留中の証憑リストを確認',
  },
  'taskStepRunOcr': {
    AppLanguage.simplifiedChinese: 'OCR 识别并确认信息',
    AppLanguage.traditionalChinese: 'OCR 識別並確認資訊',
    AppLanguage.english: 'Run OCR and Confirm Information',
    AppLanguage.japanese: 'OCR を実行して情報を確認',
  },
  'taskStepScanRfid': {
    AppLanguage.simplifiedChinese: '扫描 RFID 并匹配',
    AppLanguage.traditionalChinese: '掃描 RFID 並比對',
    AppLanguage.english: 'Scan and Match RFID',
    AppLanguage.japanese: 'RFID をスキャンして照合',
  },
  'taskStepTransferWithinDeadline': {
    AppLanguage.simplifiedChinese: '限时完成存取或盘点',
    AppLanguage.traditionalChinese: '限時完成存取或盤點',
    AppLanguage.english:
        'Complete the transfer or inventory check within the time limit',
    AppLanguage.japanese: '制限時間内に入出庫または棚卸しを完了',
  },
  'taskStepVerifyPickupCode': {
    AppLanguage.simplifiedChinese: '验证取件码',
    AppLanguage.traditionalChinese: '驗證取件碼',
    AppLanguage.english: 'Verify Pickup Code',
    AppLanguage.japanese: '受取コードを確認',
  },
  'taskTypeBorrowEvidence': {
    AppLanguage.simplifiedChinese: '借证',
    AppLanguage.traditionalChinese: '借證',
    AppLanguage.english: 'Borrow Evidence',
    AppLanguage.japanese: '証憑貸出',
  },
  'taskTypeRetrieveEvidence': {
    AppLanguage.simplifiedChinese: '取证',
    AppLanguage.traditionalChinese: '取證',
    AppLanguage.english: 'Retrieve Evidence',
    AppLanguage.japanese: '証憑受取',
  },
  'taskTypeReturnEvidence': {
    AppLanguage.simplifiedChinese: '还证',
    AppLanguage.traditionalChinese: '還證',
    AppLanguage.english: 'Return Evidence',
    AppLanguage.japanese: '証憑返却',
  },
  'taskTypeStoreEvidence': {
    AppLanguage.simplifiedChinese: '存证',
    AppLanguage.traditionalChinese: '存證',
    AppLanguage.english: 'Deposit Evidence',
    AppLanguage.japanese: '証憑保管',
  },
};
