import '../app_localizations.dart';

const inspectionLocalizations = {
  'inspectionFlowTag': {
    AppLanguage.simplifiedChinese: '飞检',
    AppLanguage.traditionalChinese: '飛檢',
    AppLanguage.english: 'Inspection',
    AppLanguage.japanese: '抜取検査',
  },
  'inspectionVerificationTitle': {
    AppLanguage.simplifiedChinese: '飞检人员认证',
    AppLanguage.traditionalChinese: '飛檢人員驗證',
    AppLanguage.english: 'Inspector Verification',
    AppLanguage.japanese: '検査員認証',
  },
  'inspectionVerificationBadge': {
    AppLanguage.simplifiedChinese: '人员认证中 · 飞检',
    AppLanguage.traditionalChinese: '人員驗證中 · 飛檢',
    AppLanguage.english: 'Identity Verification · Inspection',
    AppLanguage.japanese: '本人認証中 · 検査',
  },
  'inspectionVerificationHeading': {
    AppLanguage.simplifiedChinese: '请完成飞检人员身份认证',
    AppLanguage.traditionalChinese: '請完成飛檢人員身份驗證',
    AppLanguage.english: 'Please complete inspector identity verification',
    AppLanguage.japanese: '検査員の本人認証を完了してください',
  },
  'inspectionVerifierInfo': {
    AppLanguage.simplifiedChinese: '飞检员：{name} · 工号 {code} · 权限 {permission}',
    AppLanguage.traditionalChinese: '飛檢員：{name} · 工號 {code} · 權限 {permission}',
    AppLanguage.english:
        'Inspector: {name} · ID {code} · Permission {permission}',
    AppLanguage.japanese: '検査員：{name} · 社員番号 {code} · 権限 {permission}',
  },
  'inspectionVerificationProgress': {
    AppLanguage.simplifiedChinese: '已完成 {count} / 3 项认证',
    AppLanguage.traditionalChinese: '已完成 {count} / 3 項驗證',
    AppLanguage.english: '{count} / 3 verifications completed',
    AppLanguage.japanese: '{count} / 3 認証完了',
  },
  'inspectionTaskListTitle': {
    AppLanguage.simplifiedChinese: '飞检柜门列表',
    AppLanguage.traditionalChinese: '飛檢櫃門列表',
    AppLanguage.english: 'Inspection Door List',
    AppLanguage.japanese: '検査対象扉一覧',
  },
  'inspectionTaskBadge': {
    AppLanguage.simplifiedChinese: '柜门任务 · 飞检',
    AppLanguage.traditionalChinese: '櫃門任務 · 飛檢',
    AppLanguage.english: 'Door Tasks · Inspection',
    AppLanguage.japanese: '扉タスク · 検査',
  },
  'inspectionTaskCompleted': {
    AppLanguage.simplifiedChinese: '本次飞检完成',
    AppLanguage.traditionalChinese: '本次飛檢完成',
    AppLanguage.english: 'Inspection Completed',
    AppLanguage.japanese: '本次検査完了',
  },
  'inspectionRandomTask': {
    AppLanguage.simplifiedChinese: '后台随机任务 {batchNo}',
    AppLanguage.traditionalChinese: '後台隨機任務 {batchNo}',
    AppLanguage.english: 'Random Task {batchNo}',
    AppLanguage.japanese: 'ランダムタスク {batchNo}',
  },
  'inspectionTaskMemoryStatus': {
    AppLanguage.simplifiedChinese:
        '已下发到本机内存 · 已飞检 {completedCount} / {totalCount} 个柜门',
    AppLanguage.traditionalChinese:
        '已下發到本機記憶體 · 已飛檢 {completedCount} / {totalCount} 個櫃門',
    AppLanguage.english:
        'Loaded in local memory · {completedCount} / {totalCount} doors inspected',
    AppLanguage.japanese: '本機メモリに配信済み · {completedCount} / {totalCount} 扉検査済み',
  },
  'inspectionStatusWaiting': {
    AppLanguage.simplifiedChinese: '待飞检',
    AppLanguage.traditionalChinese: '待飛檢',
    AppLanguage.english: 'Pending',
    AppLanguage.japanese: '未検査',
  },
  'inspectionStatusInspecting': {
    AppLanguage.simplifiedChinese: '飞检中',
    AppLanguage.traditionalChinese: '飛檢中',
    AppLanguage.english: 'Inspecting',
    AppLanguage.japanese: '検査中',
  },
  'inspectionStatusCompleted': {
    AppLanguage.simplifiedChinese: '已飞检',
    AppLanguage.traditionalChinese: '已飛檢',
    AppLanguage.english: 'Completed',
    AppLanguage.japanese: '検査済み',
  },
  'inspectionLockedHint': {
    AppLanguage.simplifiedChinese: '其他柜门已锁定，请先完成当前柜门飞检',
    AppLanguage.traditionalChinese: '其他櫃門已鎖定，請先完成目前櫃門飛檢',
    AppLanguage.english:
        'Other doors are locked. Complete the current inspection first.',
    AppLanguage.japanese: '他の扉はロックされています。現在の検査を先に完了してください。',
  },
  'inspectionOpenDoorAction': {
    AppLanguage.simplifiedChinese: '打开柜门',
    AppLanguage.traditionalChinese: '開啟櫃門',
    AppLanguage.english: 'Open Door',
    AppLanguage.japanese: '扉を開く',
  },
  'inspectionCompletedAction': {
    AppLanguage.simplifiedChinese: '已完成',
    AppLanguage.traditionalChinese: '已完成',
    AppLanguage.english: 'Completed',
    AppLanguage.japanese: '完了',
  },
  'inspectionCurrentDoorTitle': {
    AppLanguage.simplifiedChinese: '柜门 {doorNo} 飞检中',
    AppLanguage.traditionalChinese: '櫃門 {doorNo} 飛檢中',
    AppLanguage.english: 'Door {doorNo} Under Inspection',
    AppLanguage.japanese: '扉 {doorNo} 検査中',
  },
  'inspectionDoorNoLabel': {
    AppLanguage.simplifiedChinese: '柜门编号',
    AppLanguage.traditionalChinese: '櫃門編號',
    AppLanguage.english: 'Door No.',
    AppLanguage.japanese: '扉番号',
  },
  'inspectionFileCodeLabel': {
    AppLanguage.simplifiedChinese: '文件编号',
    AppLanguage.traditionalChinese: '文件編號',
    AppLanguage.english: 'Document Code',
    AppLanguage.japanese: '文書番号',
  },
  'inspectionSecretLevelLabel': {
    AppLanguage.simplifiedChinese: '文件密级',
    AppLanguage.traditionalChinese: '文件密級',
    AppLanguage.english: 'Security Level',
    AppLanguage.japanese: '機密区分',
  },
  'inspectionDepartmentLabel': {
    AppLanguage.simplifiedChinese: '责任部门',
    AppLanguage.traditionalChinese: '責任部門',
    AppLanguage.english: 'Department',
    AppLanguage.japanese: '担当部門',
  },
  'inspectionWaitingItemReturned': {
    AppLanguage.simplifiedChinese: '等待物品放回',
    AppLanguage.traditionalChinese: '等待物品放回',
    AppLanguage.english: 'Waiting for Item Return',
    AppLanguage.japanese: '返却待機中',
  },
  'inspectionItemReturned': {
    AppLanguage.simplifiedChinese: '物品已放回',
    AppLanguage.traditionalChinese: '物品已放回',
    AppLanguage.english: 'Item Returned',
    AppLanguage.japanese: '物品返却済み',
  },
  'inspectionConfirmItemReturned': {
    AppLanguage.simplifiedChinese: '确认物品已放回',
    AppLanguage.traditionalChinese: '確認物品已放回',
    AppLanguage.english: 'Confirm Item Returned',
    AppLanguage.japanese: '物品返却を確認',
  },
  'inspectionReturnVerified': {
    AppLanguage.simplifiedChinese: '放回校验成功',
    AppLanguage.traditionalChinese: '放回校驗成功',
    AppLanguage.english: 'Return Verification Passed',
    AppLanguage.japanese: '返却確認成功',
  },
  'inspectionWaitingReturnCheck': {
    AppLanguage.simplifiedChinese: '等待放回校验',
    AppLanguage.traditionalChinese: '等待放回校驗',
    AppLanguage.english: 'Waiting for Return Check',
    AppLanguage.japanese: '返却確認待機中',
  },
  'inspectionRunReturnCheck': {
    AppLanguage.simplifiedChinese: '执行放回校验',
    AppLanguage.traditionalChinese: '執行放回校驗',
    AppLanguage.english: 'Run Return Check',
    AppLanguage.japanese: '返却確認を実行',
  },
  'inspectionFinishCurrentDoor': {
    AppLanguage.simplifiedChinese: '完成本柜飞检',
    AppLanguage.traditionalChinese: '完成本櫃飛檢',
    AppLanguage.english: 'Complete This Door',
    AppLanguage.japanese: 'この扉の検査完了',
  },
  'inspectionSelectDoorTitle': {
    AppLanguage.simplifiedChinese: '请选择需要飞检的柜门',
    AppLanguage.traditionalChinese: '請選擇需要飛檢的櫃門',
    AppLanguage.english: 'Select a Door to Inspect',
    AppLanguage.japanese: '検査する扉を選択してください',
  },
  'inspectionSelectDoorHint': {
    AppLanguage.simplifiedChinese: '打开一个柜门后，其他柜门将自动锁定',
    AppLanguage.traditionalChinese: '開啟一個櫃門後，其他櫃門將自動鎖定',
    AppLanguage.english:
        'When one door is opened, all others will be locked automatically',
    AppLanguage.japanese: '1つの扉を開くと、他の扉は自動的にロックされます',
  },
  'inspectionAllDoneHint': {
    AppLanguage.simplifiedChinese: '所有后台下发柜门均已标记已飞检',
    AppLanguage.traditionalChinese: '所有後台下發櫃門均已標記為已飛檢',
    AppLanguage.english: 'All assigned doors have been marked as inspected',
    AppLanguage.japanese: '配信済みのすべての扉が検査済みとして登録されました',
  },
  'inspectionBack': {
    AppLanguage.simplifiedChinese: '返回',
    AppLanguage.traditionalChinese: '返回',
    AppLanguage.english: 'Back',
    AppLanguage.japanese: '戻る',
  },
};
