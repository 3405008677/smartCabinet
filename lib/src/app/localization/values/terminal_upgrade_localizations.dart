import 'package:smart_cabinet/src/app/localization/app_localizations.dart';

/// 终端升级静态标签、运行态、配置校验和操作失败文案。
///
/// 集中维护升级功能文案，避免领域层、数据层和原生安装器决定界面语言。
const Map<String, Map<AppLanguage, String>>
terminalUpgradeRuntimeLocalizations = {
  'adminUpgradeLoadSettingsFailed': {
    AppLanguage.simplifiedChinese: '读取升级配置失败：{detail}',
    AppLanguage.traditionalChinese: '讀取升級設定失敗：{detail}',
    AppLanguage.english: 'Failed to load upgrade settings: {detail}',
    AppLanguage.japanese: 'アップグレード設定の読み込みに失敗しました：{detail}',
  },
  'adminUpgradeSaveSettingsFailed': {
    AppLanguage.simplifiedChinese: '保存升级配置失败：{detail}',
    AppLanguage.traditionalChinese: '儲存升級設定失敗：{detail}',
    AppLanguage.english: 'Failed to save upgrade settings: {detail}',
    AppLanguage.japanese: 'アップグレード設定の保存に失敗しました：{detail}',
  },
  'adminUpgradeCheckFailed': {
    AppLanguage.simplifiedChinese: '检查升级失败：{detail}',
    AppLanguage.traditionalChinese: '檢查升級失敗：{detail}',
    AppLanguage.english: 'Failed to check for upgrades: {detail}',
    AppLanguage.japanese: 'アップグレードの確認に失敗しました：{detail}',
  },
  'adminUpgradeInstallFailed': {
    AppLanguage.simplifiedChinese: '升级安装失败：{detail}',
    AppLanguage.traditionalChinese: '升級安裝失敗：{detail}',
    AppLanguage.english: 'Failed to install the upgrade: {detail}',
    AppLanguage.japanese: 'アップグレードのインストールに失敗しました：{detail}',
  },
  'adminUpgradeMessageWithDetail': {
    AppLanguage.simplifiedChinese: '{message}：{detail}',
    AppLanguage.traditionalChinese: '{message}：{detail}',
    AppLanguage.english: '{message}: {detail}',
    AppLanguage.japanese: '{message}：{detail}',
  },
  'adminUpgradeInstallStateUnknown': {
    AppLanguage.simplifiedChinese: '未知安装状态（{state}）',
    AppLanguage.traditionalChinese: '未知安裝狀態（{state}）',
    AppLanguage.english: 'Unknown install state ({state})',
    AppLanguage.japanese: '不明なインストール状態（{state}）',
  },
  'adminUpgradeValidationHostRequired': {
    AppLanguage.simplifiedChinese: '升级服务地址不能为空',
    AppLanguage.traditionalChinese: '升級服務位址不能為空',
    AppLanguage.english: 'Upgrade server address is required',
    AppLanguage.japanese: 'アップグレードサーバーのアドレスを入力してください',
  },
  'adminUpgradeValidationPortInvalid': {
    AppLanguage.simplifiedChinese: '升级服务端口必须在 1 到 65535 之间',
    AppLanguage.traditionalChinese: '升級服務連接埠必須介於 1 到 65535 之間',
    AppLanguage.english: 'Upgrade server port must be between 1 and 65535',
    AppLanguage.japanese: 'アップグレードサーバーのポートは 1～65535 にしてください',
  },
  'adminUpgradeValidationTerminalIdInvalid': {
    AppLanguage.simplifiedChinese: '终端 ID 必须是非零开头的 11 位或 15 位数字',
    AppLanguage.traditionalChinese: '終端 ID 必須是非零開頭的 11 位或 15 位數字',
    AppLanguage.english:
        'Terminal ID must be 11 or 15 digits and cannot start with zero',
    AppLanguage.japanese: '端末 ID は 0 以外で始まる 11 桁または 15 桁の数字にしてください',
  },
  'adminUpgradeValidationModuleIdInvalid': {
    AppLanguage.simplifiedChinese: 'DEVICE_IMEI 系统配置无效，必须配置为 15 位数字',
    AppLanguage.traditionalChinese: 'DEVICE_IMEI 系統設定無效，必須設定為 15 位數字',
    AppLanguage.english:
        'The DEVICE_IMEI system configuration must contain 15 digits',
    AppLanguage.japanese: 'DEVICE_IMEI システム設定は 15 桁の数字にしてください',
  },
  'adminUpgradeValidationDataIpInvalid': {
    AppLanguage.simplifiedChinese: 'STUM_DP 必须是一个或多个以英文逗号分隔的 IPv4 地址',
    AppLanguage.traditionalChinese: 'STUM_DP 必須是一個或多個以英文逗號分隔的 IPv4 位址',
    AppLanguage.english:
        'STUM_DP must contain one or more comma-separated IPv4 addresses',
    AppLanguage.japanese: 'STUM_DP は 1 つ以上の IPv4 アドレスを半角カンマで区切って指定してください',
  },
  'adminUpgradeValidationChipIdInvalid': {
    AppLanguage.simplifiedChinese: '“关于设备”中没有可用于 CD 的有效唯一设备 ID',
    AppLanguage.traditionalChinese: '「關於裝置」中沒有可用於 CD 的有效唯一裝置 ID',
    AppLanguage.english:
        'About Device does not contain a valid unique device ID for CD',
    AppLanguage.japanese: '「デバイス情報」に CD として使用できる有効な一意のデバイス ID がありません',
  },
  'adminUpgradeValidationProtocolValueInvalid': {
    AppLanguage.simplifiedChinese: 'PT 只能使用 ASCII 字符，且不能包含竖线或换行',
    AppLanguage.traditionalChinese: 'PT 只能使用 ASCII 字元，且不能包含豎線或換行',
    AppLanguage.english:
        'PT must use ASCII characters without pipes or line breaks',
    AppLanguage.japanese: 'PT は ASCII 文字のみ使用でき、縦線や改行を含めることはできません',
  },
  'adminUpgradeMessageMonitoringDisabled': {
    AppLanguage.simplifiedChinese: '升级监控未启用',
    AppLanguage.traditionalChinese: '升級監控未啟用',
    AppLanguage.english: 'Upgrade monitoring is disabled',
    AppLanguage.japanese: 'アップグレード監視は無効です',
  },
  'adminUpgradeMessageMonitoringReady': {
    AppLanguage.simplifiedChinese: '升级监控已启用，准备连接服务端',
    AppLanguage.traditionalChinese: '升級監控已啟用，準備連線服務端',
    AppLanguage.english: 'Upgrade monitoring enabled; preparing to connect',
    AppLanguage.japanese: 'アップグレード監視を有効化し、サーバーへの接続を準備しています',
  },
  'adminUpgradeMessageConnectingServer': {
    AppLanguage.simplifiedChinese: '正在连接升级服务端',
    AppLanguage.traditionalChinese: '正在連線升級服務端',
    AppLanguage.english: 'Connecting to the upgrade server',
    AppLanguage.japanese: 'アップグレードサーバーに接続しています',
  },
  'adminUpgradeMessageAuthenticatingTerminal': {
    AppLanguage.simplifiedChinese: '已连接，正在验证终端身份',
    AppLanguage.traditionalChinese: '已連線，正在驗證終端身分',
    AppLanguage.english: 'Connected; authenticating the terminal',
    AppLanguage.japanese: '接続済みです。端末を認証しています',
  },
  'adminUpgradeMessageCheckingVersion': {
    AppLanguage.simplifiedChinese: '正在检查新版本',
    AppLanguage.traditionalChinese: '正在檢查新版本',
    AppLanguage.english: 'Checking for a new version',
    AppLanguage.japanese: '新しいバージョンを確認しています',
  },
  'adminUpgradeMessageCheckRequestAccepted': {
    AppLanguage.simplifiedChinese: '服务端已接收升级检查请求',
    AppLanguage.traditionalChinese: '服務端已接收升級檢查請求',
    AppLanguage.english: 'The server accepted the upgrade check request',
    AppLanguage.japanese: 'サーバーがアップグレード確認要求を受け付けました',
  },
  'adminUpgradeMessageAlreadyLatest': {
    AppLanguage.simplifiedChinese: '服务端当前没有可下发升级包（VE=0）',
    AppLanguage.traditionalChinese: '服務端目前沒有可下發的升級套件（VE=0）',
    AppLanguage.english:
        'The server currently has no upgrade package to deliver (VE=0)',
    AppLanguage.japanese: 'サーバーに現在配信可能なアップグレードパッケージがありません（VE=0）',
  },
  'adminUpgradeMessageUpdateAvailable': {
    AppLanguage.simplifiedChinese: '发现新版本 {version}，请管理员确认安装',
    AppLanguage.traditionalChinese: '發現新版本 {version}，請管理員確認安裝',
    AppLanguage.english:
        'Version {version} is available; administrator confirmation is required',
    AppLanguage.japanese: '新しいバージョン {version} があります。管理者がインストールを確認してください',
  },
  'terminalUpgradeOfferPromptTitle': {
    AppLanguage.simplifiedChinese: '发现终端新版本',
    AppLanguage.traditionalChinese: '發現終端新版本',
    AppLanguage.english: 'Terminal Update Available',
    AppLanguage.japanese: '端末の新しいバージョンがあります',
  },
  'terminalUpgradeOfferPromptMessage': {
    AppLanguage.simplifiedChinese: '服务端已提供版本 {version}。请管理员确认后下载并安装。',
    AppLanguage.traditionalChinese: '服務端已提供版本 {version}。請管理員確認後下載並安裝。',
    AppLanguage.english:
        'The server offered version {version}. An administrator must confirm before download and installation.',
    AppLanguage.japanese:
        'サーバーからバージョン {version} が提供されました。管理者の確認後にダウンロードしてインストールしてください。',
  },
  'terminalUpgradeOfferPromptAction': {
    AppLanguage.simplifiedChinese: '管理员处理',
    AppLanguage.traditionalChinese: '管理員處理',
    AppLanguage.english: 'Administrator',
    AppLanguage.japanese: '管理者が処理',
  },
  'adminUpgradeMessageDownloadingVersion': {
    AppLanguage.simplifiedChinese: '正在下载版本 {version}',
    AppLanguage.traditionalChinese: '正在下載版本 {version}',
    AppLanguage.english: 'Downloading version {version}',
    AppLanguage.japanese: 'バージョン {version} をダウンロードしています',
  },
  'adminUpgradeMessageChecksumVerified': {
    AppLanguage.simplifiedChinese: '升级包 MD5 校验通过',
    AppLanguage.traditionalChinese: '升級套件 MD5 驗證通過',
    AppLanguage.english: 'Upgrade package MD5 verified',
    AppLanguage.japanese: 'アップグレードパッケージの MD5 検証が完了しました',
  },
  'adminUpgradeMessageSubmittingInstaller': {
    AppLanguage.simplifiedChinese: '正在提交 Android 安装会话',
    AppLanguage.traditionalChinese: '正在提交 Android 安裝工作階段',
    AppLanguage.english: 'Submitting the Android install session',
    AppLanguage.japanese: 'Android のインストールセッションを送信しています',
  },
  'adminUpgradeMessageInstallSessionSubmitted': {
    AppLanguage.simplifiedChinese: '安装会话 {sessionId} 已提交，等待系统完成升级',
    AppLanguage.traditionalChinese: '安裝工作階段 {sessionId} 已提交，等待系統完成升級',
    AppLanguage.english:
        'Install session {sessionId} submitted; waiting for the system',
    AppLanguage.japanese: 'インストールセッション {sessionId} を送信しました。システムの完了を待っています',
  },
  'adminUpgradeMessageAwaitingUserConfirmation': {
    AppLanguage.simplifiedChinese: '等待管理员确认系统安装',
    AppLanguage.traditionalChinese: '等待管理員確認系統安裝',
    AppLanguage.english: 'Waiting for administrator installation confirmation',
    AppLanguage.japanese: '管理者によるシステムインストールの確認を待っています',
  },
  'adminUpgradeMessageAwaitingSystemInstall': {
    AppLanguage.simplifiedChinese: '等待系统完成安装',
    AppLanguage.traditionalChinese: '等待系統完成安裝',
    AppLanguage.english: 'Waiting for the system to finish installation',
    AppLanguage.japanese: 'システムのインストール完了を待っています',
  },
  'adminUpgradeMessageInstallSucceeded': {
    AppLanguage.simplifiedChinese: '终端已经升级到 {version}',
    AppLanguage.traditionalChinese: '終端已升級至 {version}',
    AppLanguage.english: 'The terminal was upgraded to {version}',
    AppLanguage.japanese: '端末を {version} にアップグレードしました',
  },
  'adminUpgradeMessageConnectionInterruptedRetrying': {
    AppLanguage.simplifiedChinese: '升级服务连接已中断，将自动重连',
    AppLanguage.traditionalChinese: '升級服務連線已中斷，將自動重新連線',
    AppLanguage.english:
        'The upgrade service connection was interrupted; reconnecting automatically',
    AppLanguage.japanese: 'アップグレードサービスとの接続が中断されました。自動的に再接続します',
  },
  'adminUpgradeErrorReadAppVersionFailed': {
    AppLanguage.simplifiedChinese: '无法读取当前应用版本',
    AppLanguage.traditionalChinese: '無法讀取目前應用程式版本',
    AppLanguage.english: 'Could not read the current app version',
    AppLanguage.japanese: '現在のアプリバージョンを取得できませんでした',
  },
  'adminUpgradeErrorMonitoringNotEnabled': {
    AppLanguage.simplifiedChinese: '请先保存并启用升级监控配置',
    AppLanguage.traditionalChinese: '請先儲存並啟用升級監控設定',
    AppLanguage.english: 'Save and enable upgrade monitoring first',
    AppLanguage.japanese: '先にアップグレード監視設定を保存して有効にしてください',
  },
  'adminUpgradeErrorCheckBlockedByDownload': {
    AppLanguage.simplifiedChinese: '升级包正在下载或校验，不能重复检查',
    AppLanguage.traditionalChinese: '升級套件正在下載或驗證，不能重複檢查',
    AppLanguage.english:
        'An upgrade is being downloaded or verified; another check cannot start',
    AppLanguage.japanese: 'アップグレードのダウンロードまたは検証中のため、再確認できません',
  },
  'adminUpgradeErrorInstallAlreadyActive': {
    AppLanguage.simplifiedChinese: '系统仍在处理上一笔升级安装',
    AppLanguage.traditionalChinese: '系統仍在處理上一筆升級安裝',
    AppLanguage.english: 'The previous upgrade installation is still active',
    AppLanguage.japanese: '前回のアップグレードをインストールしています',
  },
  'adminUpgradeErrorNoInstallableOffer': {
    AppLanguage.simplifiedChinese: '当前没有可安装的升级包',
    AppLanguage.traditionalChinese: '目前沒有可安裝的升級套件',
    AppLanguage.english: 'No upgrade package is available to install',
    AppLanguage.japanese: 'インストール可能なアップグレードパッケージがありません',
  },
  'adminUpgradeErrorAdministratorConfirmationRequired': {
    AppLanguage.simplifiedChinese: '请由管理员明确确认本次升级后再安装',
    AppLanguage.traditionalChinese: '請由管理員明確確認本次升級後再安裝',
    AppLanguage.english:
        'Administrator confirmation is required for this upgrade',
    AppLanguage.japanese: 'このアップグレードをインストールするには管理者の確認が必要です',
  },
  'adminUpgradeErrorConfirmedOfferChanged': {
    AppLanguage.simplifiedChinese: '待安装升级包已变化，请重新确认',
    AppLanguage.traditionalChinese: '待安裝升級套件已變更，請重新確認',
    AppLanguage.english:
        'The pending upgrade package changed; confirm it again',
    AppLanguage.japanese: 'インストール待ちのパッケージが変更されました。もう一度確認してください',
  },
  'adminUpgradeErrorPendingOfferRequiresDecision': {
    AppLanguage.simplifiedChinese: '已有待确认升级包，请先处理后再检查',
    AppLanguage.traditionalChinese: '已有待確認升級套件，請先處理後再檢查',
    AppLanguage.english:
        'Resolve the pending upgrade package before checking again',
    AppLanguage.japanese: '確認待ちのアップグレードを処理してから、もう一度確認してください',
  },
  'adminUpgradeErrorDoorsNotClosed': {
    AppLanguage.simplifiedChinese: '存在尚未确认关闭的柜门，禁止安装升级',
    AppLanguage.traditionalChinese: '有櫃門尚未確認關閉，禁止安裝升級',
    AppLanguage.english:
        'Installation is blocked because not all cabinet doors are confirmed closed',
    AppLanguage.japanese: 'すべての扉が閉じていることを確認できないため、インストールできません',
  },
  'adminUpgradeErrorMaintenanceUnavailable': {
    AppLanguage.simplifiedChinese: '柜门或其他维护操作正在占用设备，禁止安装升级',
    AppLanguage.traditionalChinese: '櫃門或其他維護操作正在使用設備，禁止安裝升級',
    AppLanguage.english:
        'A cabinet-door or maintenance operation is using the device; installation is blocked',
    AppLanguage.japanese: '扉または他の保守操作がデバイスを使用中のため、インストールできません',
  },
  'adminUpgradeErrorDoorsChangedDuringDownload': {
    AppLanguage.simplifiedChinese: '下载期间柜门状态发生变化，已取消安装',
    AppLanguage.traditionalChinese: '下載期間櫃門狀態發生變化，已取消安裝',
    AppLanguage.english:
        'Cabinet-door status changed during download; installation was cancelled',
    AppLanguage.japanese: 'ダウンロード中に扉の状態が変わったため、インストールをキャンセルしました',
  },
  'adminUpgradeErrorInstallFailed': {
    AppLanguage.simplifiedChinese: '升级安装失败',
    AppLanguage.traditionalChinese: '升級安裝失敗',
    AppLanguage.english: 'Upgrade installation failed',
    AppLanguage.japanese: 'アップグレードのインストールに失敗しました',
  },
  'adminUpgradeErrorReadInstallStatusFailed': {
    AppLanguage.simplifiedChinese: '读取系统安装状态失败',
    AppLanguage.traditionalChinese: '讀取系統安裝狀態失敗',
    AppLanguage.english: 'Failed to read the system installation status',
    AppLanguage.japanese: 'システムのインストール状態を取得できませんでした',
  },
  'adminUpgradeErrorServerLoginRejected': {
    AppLanguage.simplifiedChinese: '终端登录被服务端拒绝',
    AppLanguage.traditionalChinese: '終端登入被服務端拒絕',
    AppLanguage.english: 'The server rejected the terminal login',
    AppLanguage.japanese: 'サーバーが端末のログインを拒否しました',
  },
  'adminUpgradeErrorConnectFailed': {
    AppLanguage.simplifiedChinese: '无法连接升级服务端',
    AppLanguage.traditionalChinese: '無法連線升級服務端',
    AppLanguage.english: 'Could not connect to the upgrade server',
    AppLanguage.japanese: 'アップグレードサーバーに接続できませんでした',
  },
  'adminUpgradeErrorServerCheckRejected': {
    AppLanguage.simplifiedChinese: '升级检查被服务端拒绝',
    AppLanguage.traditionalChinese: '升級檢查被服務端拒絕',
    AppLanguage.english: 'The server rejected the upgrade check',
    AppLanguage.japanese: 'サーバーがアップグレード確認を拒否しました',
  },
  'adminUpgradeErrorOfferRejected': {
    AppLanguage.simplifiedChinese: '升级包未通过协议校验（{responseCode}）',
    AppLanguage.traditionalChinese: '升級套件未通過協議驗證（{responseCode}）',
    AppLanguage.english:
        'The upgrade package failed protocol validation ({responseCode})',
    AppLanguage.japanese: 'アップグレードパッケージがプロトコル検証に失敗しました（{responseCode}）',
  },
  'adminUpgradeErrorCheckTimedOut': {
    AppLanguage.simplifiedChinese: '等待升级检查结果超时，请手动重试',
    AppLanguage.traditionalChinese: '等待升級檢查結果逾時，請手動重試',
    AppLanguage.english:
        'Timed out waiting for the upgrade result; try again manually',
    AppLanguage.japanese: 'アップグレード確認がタイムアウトしました。手動で再試行してください',
  },
  'adminUpgradeErrorMaintenanceRestoreFailed': {
    AppLanguage.simplifiedChinese: '安装仍在进行，但无法恢复升级维护锁；请立即停止柜门业务并联系运维人员',
    AppLanguage.traditionalChinese: '安裝仍在進行，但無法恢復升級維護鎖；請立即停止櫃門作業並聯絡維運人員',
    AppLanguage.english:
        'Installation is still active, but the upgrade maintenance lock could not be restored. Stop cabinet operations and contact support.',
    AppLanguage.japanese:
        'インストールは進行中ですが、アップグレード保守ロックを復元できません。扉の操作を停止し、運用担当者に連絡してください',
  },
  'adminUpgradeErrorConfirmationLaunchFailed': {
    AppLanguage.simplifiedChinese: '系统安装确认页未能打开，请退出锁定任务模式后重试或联系运维人员',
    AppLanguage.traditionalChinese: '系統安裝確認頁無法開啟，請退出鎖定工作模式後重試或聯絡維運人員',
    AppLanguage.english:
        'The system confirmation screen could not open. Exit lock task mode and retry, or contact support.',
    AppLanguage.japanese:
        'システム確認画面を開けませんでした。ロックタスクモードを終了して再試行するか、運用担当者に連絡してください',
  },
  'adminUpgradeErrorInstallerReasonUnavailable': {
    AppLanguage.simplifiedChinese: '系统安装器未提供失败原因',
    AppLanguage.traditionalChinese: '系統安裝程式未提供失敗原因',
    AppLanguage.english:
        'The system installer did not provide a failure reason',
    AppLanguage.japanese: 'システムインストーラーから失敗理由が返されませんでした',
  },
  'adminUpgradeErrorOperationCancelled': {
    AppLanguage.simplifiedChinese: '升级操作已取消',
    AppLanguage.traditionalChinese: '升級操作已取消',
    AppLanguage.english: 'The upgrade operation was cancelled',
    AppLanguage.japanese: 'アップグレード操作をキャンセルしました',
  },
  'adminUpgradeErrorRepositoryDisposed': {
    AppLanguage.simplifiedChinese: '终端升级服务已经释放',
    AppLanguage.traditionalChinese: '終端升級服務已經釋放',
    AppLanguage.english: 'The terminal upgrade service has been disposed',
    AppLanguage.japanese: '端末アップグレードサービスはすでに破棄されています',
  },
  'adminUpgradeTitle': {
    AppLanguage.simplifiedChinese: '终端升级',
    AppLanguage.traditionalChinese: '終端升級',
    AppLanguage.english: 'Terminal Upgrade',
    AppLanguage.japanese: '端末アップグレード',
  },
  'adminUpgradeBadge': {
    AppLanguage.simplifiedChinese: '设备维护 · STUM',
    AppLanguage.traditionalChinese: '設備維護 · STUM',
    AppLanguage.english: 'Device Maintenance · STUM',
    AppLanguage.japanese: 'デバイス保守 · STUM',
  },
  'adminUpgradeSettingsSaved': {
    AppLanguage.simplifiedChinese: '升级配置已保存',
    AppLanguage.traditionalChinese: '升級設定已儲存',
    AppLanguage.english: 'Upgrade settings saved',
    AppLanguage.japanese: 'アップグレード設定を保存しました',
  },
  'adminUpgradeCheckStarted': {
    AppLanguage.simplifiedChinese: '正在检查新版本，等待服务端结果',
    AppLanguage.traditionalChinese: '正在檢查新版本，等待服務端結果',
    AppLanguage.english:
        'Checking for a new version; waiting for the server response',
    AppLanguage.japanese: '新しいバージョンを確認しています。サーバーの応答を待っています',
  },
  'adminUpgradeEnableFirst': {
    AppLanguage.simplifiedChinese: '请先启用升级监控',
    AppLanguage.traditionalChinese: '請先啟用升級監控',
    AppLanguage.english: 'Enable upgrade monitoring first',
    AppLanguage.japanese: '先にアップグレード監視を有効にしてください',
  },
  'adminUpgradeConfirmTitle': {
    AppLanguage.simplifiedChinese: '确认安装升级',
    AppLanguage.traditionalChinese: '確認安裝升級',
    AppLanguage.english: 'Confirm Upgrade',
    AppLanguage.japanese: 'アップグレードの確認',
  },
  'adminUpgradeConfirmMessage': {
    AppLanguage.simplifiedChinese:
        '即将安装版本 {version}。安装期间应用可能重启，请先确认没有进行中的任务且所有柜门已经关闭。',
    AppLanguage.traditionalChinese:
        '即將安裝版本 {version}。安裝期間應用程式可能重新啟動，請先確認沒有進行中的任務且所有櫃門已關閉。',
    AppLanguage.english:
        'Version {version} will be installed. The app may restart; confirm that no task is active and all cabinet doors are closed.',
    AppLanguage.japanese:
        'バージョン {version} をインストールします。アプリが再起動する場合があるため、実行中のタスクがなく、すべての扉が閉じていることを確認してください。',
  },
  'adminUpgradeCancel': {
    AppLanguage.simplifiedChinese: '取消',
    AppLanguage.traditionalChinese: '取消',
    AppLanguage.english: 'Cancel',
    AppLanguage.japanese: 'キャンセル',
  },
  'adminUpgradeInstall': {
    AppLanguage.simplifiedChinese: '下载并安装',
    AppLanguage.traditionalChinese: '下載並安裝',
    AppLanguage.english: 'Download and Install',
    AppLanguage.japanese: 'ダウンロードしてインストール',
  },
  'adminUpgradeConnectionTitle': {
    AppLanguage.simplifiedChinese: '升级服务配置',
    AppLanguage.traditionalChinese: '升級服務設定',
    AppLanguage.english: 'Upgrade Service Settings',
    AppLanguage.japanese: 'アップグレードサービス設定',
  },
  'adminUpgradeStatusTitle': {
    AppLanguage.simplifiedChinese: '升级状态',
    AppLanguage.traditionalChinese: '升級狀態',
    AppLanguage.english: 'Upgrade Status',
    AppLanguage.japanese: 'アップグレード状態',
  },
  'adminUpgradeEnabled': {
    AppLanguage.simplifiedChinese: '开机连接升级监控服务',
    AppLanguage.traditionalChinese: '開機連線升級監控服務',
    AppLanguage.english: 'Connect to upgrade monitoring at startup',
    AppLanguage.japanese: '起動時にアップグレード監視へ接続',
  },
  'adminUpgradeEnabledHint': {
    AppLanguage.simplifiedChinese: '默认关闭；启用后按 T01 登录并在重连后发送 T03',
    AppLanguage.traditionalChinese: '預設關閉；啟用後以 T01 登入並在重連後傳送 T03',
    AppLanguage.english:
        'Off by default; when enabled, log in with T01 and send T03 after reconnecting',
    AppLanguage.japanese: '初期設定は無効です。有効にすると T01 でログインし、再接続後に T03 を送信します',
  },
  'adminUpgradeHost': {
    AppLanguage.simplifiedChinese: '服务地址',
    AppLanguage.traditionalChinese: '服務位址',
    AppLanguage.english: 'Server Address',
    AppLanguage.japanese: 'サーバーアドレス',
  },
  'adminUpgradePort': {
    AppLanguage.simplifiedChinese: 'TCP 端口',
    AppLanguage.traditionalChinese: 'TCP 連接埠',
    AppLanguage.english: 'TCP Port',
    AppLanguage.japanese: 'TCP ポート',
  },
  'adminUpgradeTerminalId': {
    AppLanguage.simplifiedChinese: '设备号 ID（11/15 位数字）',
    AppLanguage.traditionalChinese: '設備號 ID（11/15 位數字）',
    AppLanguage.english: 'Device Number ID (11/15 digits)',
    AppLanguage.japanese: 'デバイス番号 ID（11/15 桁の数字）',
  },
  'adminUpgradeModuleId': {
    AppLanguage.simplifiedChinese: '设备 IMEI（IM）',
    AppLanguage.traditionalChinese: '裝置 IMEI（IM）',
    AppLanguage.english: 'Device IMEI (IM)',
    AppLanguage.japanese: 'デバイス IMEI（IM）',
  },
  'adminUpgradePackageTag': {
    AppLanguage.simplifiedChinese: '包标记 PT（可选）',
    AppLanguage.traditionalChinese: '套件標記 PT（選填）',
    AppLanguage.english: 'Package Tag PT (optional)',
    AppLanguage.japanese: 'パッケージタグ PT（任意）',
  },
  'adminUpgradeChipId': {
    AppLanguage.simplifiedChinese: '设备唯一 ID CD',
    AppLanguage.traditionalChinese: '裝置唯一 ID CD',
    AppLanguage.english: 'Unique Device ID CD',
    AppLanguage.japanese: '一意のデバイス ID CD',
  },
  'adminUpgradeDataIp': {
    AppLanguage.simplifiedChinese: '数据通讯 IP DP',
    AppLanguage.traditionalChinese: '資料通訊 IP DP',
    AppLanguage.english: 'Data IP DP',
    AppLanguage.japanese: 'データ通信 IP DP',
  },
  'adminUpgradeProtocolBoundary': {
    AppLanguage.simplifiedChinese:
        '当前仅支持 URL 模式（DT=1），并只在当前 T03 请求窗口处理 S03。分包模式 AD=2 缺少帧定义，将按 NG3AD 拒绝。',
    AppLanguage.traditionalChinese:
        '目前僅支援 URL 模式（DT=1），且只在目前 T03 請求視窗處理 S03。分包模式 AD=2 缺少訊框定義，將以 NG3AD 拒絕。',
    AppLanguage.english:
        'Only URL mode (DT=1) is supported, and S03 is handled only in the current T03 request window. AD=2 has no framing definition and is rejected with NG3AD.',
    AppLanguage.japanese:
        'URL モード（DT=1）のみ対応し、S03 は現在の T03 要求ウィンドウ内でのみ処理します。AD=2 はフレーム定義がないため NG3AD で拒否します。',
  },
  'adminUpgradeSave': {
    AppLanguage.simplifiedChinese: '保存配置',
    AppLanguage.traditionalChinese: '儲存設定',
    AppLanguage.english: 'Save Settings',
    AppLanguage.japanese: '設定を保存',
  },
  'adminUpgradeCheck': {
    AppLanguage.simplifiedChinese: '检查升级',
    AppLanguage.traditionalChinese: '檢查升級',
    AppLanguage.english: 'Check for Upgrade',
    AppLanguage.japanese: 'アップグレードを確認',
  },
  'adminUpgradeCurrentVersion': {
    AppLanguage.simplifiedChinese: '当前版本',
    AppLanguage.traditionalChinese: '目前版本',
    AppLanguage.english: 'Current Version',
    AppLanguage.japanese: '現在のバージョン',
  },
  'adminUpgradeTargetVersion': {
    AppLanguage.simplifiedChinese: '目标版本',
    AppLanguage.traditionalChinese: '目標版本',
    AppLanguage.english: 'Target Version',
    AppLanguage.japanese: '対象バージョン',
  },
  'adminUpgradeDownloadAddress': {
    AppLanguage.simplifiedChinese: '下载地址',
    AppLanguage.traditionalChinese: '下載位址',
    AppLanguage.english: 'Download Address',
    AppLanguage.japanese: 'ダウンロード先',
  },
  'adminUpgradeRefreshInstall': {
    AppLanguage.simplifiedChinese: '刷新安装结果',
    AppLanguage.traditionalChinese: '重新整理安裝結果',
    AppLanguage.english: 'Refresh Install Result',
    AppLanguage.japanese: 'インストール結果を更新',
  },
  'adminUpgradeInstallStatus': {
    AppLanguage.simplifiedChinese: '安装状态',
    AppLanguage.traditionalChinese: '安裝狀態',
    AppLanguage.english: 'Install Status',
    AppLanguage.japanese: 'インストール状態',
  },
  'adminUpgradeInstallSession': {
    AppLanguage.simplifiedChinese: '安装会话',
    AppLanguage.traditionalChinese: '安裝工作階段',
    AppLanguage.english: 'Install Session',
    AppLanguage.japanese: 'インストールセッション',
  },
  'adminUpgradeInstallMessage': {
    AppLanguage.simplifiedChinese: '系统说明',
    AppLanguage.traditionalChinese: '系統說明',
    AppLanguage.english: 'System Message',
    AppLanguage.japanese: 'システムメッセージ',
  },
  'adminUpgradeInstallStateValidating': {
    AppLanguage.simplifiedChinese: '正在校验升级包',
    AppLanguage.traditionalChinese: '正在驗證升級套件',
    AppLanguage.english: 'Validating package',
    AppLanguage.japanese: 'アップグレードパッケージを検証中',
  },
  'adminUpgradeInstallStateSubmitting': {
    AppLanguage.simplifiedChinese: '正在提交安装',
    AppLanguage.traditionalChinese: '正在提交安裝',
    AppLanguage.english: 'Submitting install',
    AppLanguage.japanese: 'インストールを送信中',
  },
  'adminUpgradeInstallStateSubmitted': {
    AppLanguage.simplifiedChinese: '已提交系统安装器',
    AppLanguage.traditionalChinese: '已提交系統安裝程式',
    AppLanguage.english: 'Submitted to system installer',
    AppLanguage.japanese: 'システムインストーラーに送信済み',
  },
  'adminUpgradeInstallStatePending': {
    AppLanguage.simplifiedChinese: '等待管理员确认',
    AppLanguage.traditionalChinese: '等待管理員確認',
    AppLanguage.english: 'Waiting for administrator confirmation',
    AppLanguage.japanese: '管理者の確認待ち',
  },
  'adminUpgradeInstallStateSuccess': {
    AppLanguage.simplifiedChinese: '安装成功',
    AppLanguage.traditionalChinese: '安裝成功',
    AppLanguage.english: 'Installed successfully',
    AppLanguage.japanese: 'インストール成功',
  },
  'adminUpgradeInstallStateFailed': {
    AppLanguage.simplifiedChinese: '安装失败',
    AppLanguage.traditionalChinese: '安裝失敗',
    AppLanguage.english: 'Install failed',
    AppLanguage.japanese: 'インストール失敗',
  },
  'adminUpgradePhaseDisabled': {
    AppLanguage.simplifiedChinese: '未启用',
    AppLanguage.traditionalChinese: '未啟用',
    AppLanguage.english: 'Disabled',
    AppLanguage.japanese: '無効',
  },
  'adminUpgradePhaseDisconnected': {
    AppLanguage.simplifiedChinese: '等待连接',
    AppLanguage.traditionalChinese: '等待連線',
    AppLanguage.english: 'Waiting to Connect',
    AppLanguage.japanese: '接続待ち',
  },
  'adminUpgradePhaseConnecting': {
    AppLanguage.simplifiedChinese: '连接中',
    AppLanguage.traditionalChinese: '連線中',
    AppLanguage.english: 'Connecting',
    AppLanguage.japanese: '接続中',
  },
  'adminUpgradePhaseAuthenticating': {
    AppLanguage.simplifiedChinese: '登录验证中',
    AppLanguage.traditionalChinese: '登入驗證中',
    AppLanguage.english: 'Authenticating',
    AppLanguage.japanese: '認証中',
  },
  'adminUpgradePhaseChecking': {
    AppLanguage.simplifiedChinese: '检查中',
    AppLanguage.traditionalChinese: '檢查中',
    AppLanguage.english: 'Checking',
    AppLanguage.japanese: '確認中',
  },
  'adminUpgradePhaseLatest': {
    AppLanguage.simplifiedChinese: '无可用升级包',
    AppLanguage.traditionalChinese: '無可用升級套件',
    AppLanguage.english: 'No Upgrade Package',
    AppLanguage.japanese: 'アップグレードパッケージなし',
  },
  'adminUpgradePhaseAvailable': {
    AppLanguage.simplifiedChinese: '发现新版本',
    AppLanguage.traditionalChinese: '發現新版本',
    AppLanguage.english: 'Update Available',
    AppLanguage.japanese: '新しいバージョンあり',
  },
  'adminUpgradePhaseDownloading': {
    AppLanguage.simplifiedChinese: '下载中',
    AppLanguage.traditionalChinese: '下載中',
    AppLanguage.english: 'Downloading',
    AppLanguage.japanese: 'ダウンロード中',
  },
  'adminUpgradePhaseVerifying': {
    AppLanguage.simplifiedChinese: '校验中',
    AppLanguage.traditionalChinese: '驗證中',
    AppLanguage.english: 'Verifying',
    AppLanguage.japanese: '検証中',
  },
  'adminUpgradePhaseInstalling': {
    AppLanguage.simplifiedChinese: '提交安装中',
    AppLanguage.traditionalChinese: '提交安裝中',
    AppLanguage.english: 'Submitting Install',
    AppLanguage.japanese: 'インストール送信中',
  },
  'adminUpgradePhaseRestart': {
    AppLanguage.simplifiedChinese: '等待安装与重启',
    AppLanguage.traditionalChinese: '等待安裝與重新啟動',
    AppLanguage.english: 'Awaiting Install and Restart',
    AppLanguage.japanese: 'インストールと再起動待ち',
  },
  'adminUpgradePhaseFailed': {
    AppLanguage.simplifiedChinese: '升级失败',
    AppLanguage.traditionalChinese: '升級失敗',
    AppLanguage.english: 'Upgrade Failed',
    AppLanguage.japanese: 'アップグレード失敗',
  },
  'adminUpgradeErrorInstallValidationFailed': {
    AppLanguage.simplifiedChinese: '升级包未通过 Android 安装前校验',
    AppLanguage.traditionalChinese: '升級套件未通過 Android 安裝前驗證',
    AppLanguage.english:
        'The upgrade package failed Android pre-install validation',
    AppLanguage.japanese: 'アップグレードパッケージは Android のインストール前検証に失敗しました',
  },
  'adminUpgradeErrorInstallSubmissionFailed': {
    AppLanguage.simplifiedChinese: '无法创建或提交系统安装会话',
    AppLanguage.traditionalChinese: '無法建立或提交系統安裝工作階段',
    AppLanguage.english:
        'Could not create or submit the system install session',
    AppLanguage.japanese: 'システムのインストールセッションを作成または送信できませんでした',
  },
  'adminUpgradeErrorInstallSessionMissing': {
    AppLanguage.simplifiedChinese: '系统安装会话已不存在，请重新发起升级',
    AppLanguage.traditionalChinese: '系統安裝工作階段已不存在，請重新發起升級',
    AppLanguage.english:
        'The system install session no longer exists. Start the upgrade again.',
    AppLanguage.japanese: 'システムのインストールセッションが存在しません。アップグレードをやり直してください',
  },
  'adminUpgradeErrorInstallSessionExpired': {
    AppLanguage.simplifiedChinese: '系统安装会话已过期并被终止，请重新发起升级',
    AppLanguage.traditionalChinese: '系統安裝工作階段已逾期並終止，請重新發起升級',
    AppLanguage.english:
        'The system install session expired and was stopped. Start the upgrade again.',
    AppLanguage.japanese: 'システムのインストールセッションは期限切れのため終了しました。アップグレードをやり直してください',
  },
  'adminUpgradeErrorConfirmationRecoveryFailed': {
    AppLanguage.simplifiedChinese: '安装确认恢复任务无法调度，请联系运维人员',
    AppLanguage.traditionalChinese: '無法排程安裝確認恢復工作，請聯絡維運人員',
    AppLanguage.english:
        'Installation-confirmation recovery could not be scheduled. Contact support.',
    AppLanguage.japanese: 'インストール確認の復旧処理をスケジュールできませんでした。運用担当者に連絡してください',
  },
  'adminUpgradeErrorConfirmationTimedOut': {
    AppLanguage.simplifiedChinese: '等待安装确认超时，系统会话已取消，请重新发起升级',
    AppLanguage.traditionalChinese: '等待安裝確認逾時，系統工作階段已取消，請重新發起升級',
    AppLanguage.english:
        'Installation confirmation timed out and the system session was cancelled. Start the upgrade again.',
    AppLanguage.japanese:
        'インストール確認がタイムアウトし、システムセッションを取り消しました。アップグレードをやり直してください',
  },
  'adminUpgradeErrorPackageInstallerFailed': {
    AppLanguage.simplifiedChinese: 'Android 系统安装器报告安装失败',
    AppLanguage.traditionalChinese: 'Android 系統安裝程式回報安裝失敗',
    AppLanguage.english:
        'The Android system installer reported an installation failure',
    AppLanguage.japanese: 'Android システムインストーラーがインストール失敗を報告しました',
  },
  'adminUpgradeErrorUnexpectedOperation': {
    AppLanguage.simplifiedChinese: '操作未完成，请重试',
    AppLanguage.traditionalChinese: '操作未完成，請重試',
    AppLanguage.english: 'The operation did not complete. Try again.',
    AppLanguage.japanese: '操作が完了しませんでした。もう一度お試しください',
  },
};
