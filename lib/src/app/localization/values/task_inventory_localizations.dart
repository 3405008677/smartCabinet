import 'package:smart_cabinet/src/app/localization/app_localizations.dart';

/// 任务箱格批处理、箱格级盘点、飞检码和 RFID 差异处理使用的多语言文案。
const taskInventoryLocalizations = {
  'taskActionInventoryBySlot': {
    AppLanguage.simplifiedChinese: '进入盘点明细',
    AppLanguage.traditionalChinese: '進入盤點明細',
    AppLanguage.english: 'Open Inventory Details',
    AppLanguage.japanese: '棚卸し明細を開く',
  },
  'taskActionVerifyInventoryCode': {
    AppLanguage.simplifiedChinese: '验证飞检码',
    AppLanguage.traditionalChinese: '驗證飛檢碼',
    AppLanguage.english: 'Verify Inspection Code',
    AppLanguage.japanese: '検査コードを確認',
  },
  'taskCenterDoorOpenCannotStartTask': {
    AppLanguage.simplifiedChinese: '仍有柜门操作尚未完成，请确认关门后再开始其他任务',
    AppLanguage.traditionalChinese: '仍有櫃門操作尚未完成，請確認關門後再開始其他任務',
    AppLanguage.english:
        'A cabinet-door operation is still active. Confirm the door is closed before starting another task.',
    AppLanguage.japanese: '進行中の扉操作があります。扉が閉じていることを確認してから別のタスクを開始してください。',
  },
  'taskExecutionConfirmClosedAndRecover': {
    AppLanguage.simplifiedChinese: '确认已关门并恢复',
    AppLanguage.traditionalChinese: '確認已關門並恢復',
    AppLanguage.english: 'Confirm Closed and Recover',
    AppLanguage.japanese: '閉扉を確認して復旧',
  },
  'taskExecutionDoorRecoveryHint': {
    AppLanguage.simplifiedChinese: '开门状态更新失败。请先确认当前柜门已经关闭，再恢复任务。',
    AppLanguage.traditionalChinese: '開門狀態更新失敗。請先確認目前櫃門已經關閉，再恢復任務。',
    AppLanguage.english:
        'The open-door state could not be updated. Confirm the current door is closed before recovering the task.',
    AppLanguage.japanese: '扉の開放状態を更新できませんでした。現在の扉が閉じていることを確認してからタスクを復旧してください。',
  },
  'taskExecutionFinalizationHint': {
    AppLanguage.simplifiedChinese: '业务步骤已完成，正在向平台提交整单结果；失败时可安全重试，不会重复执行开关门。',
    AppLanguage.traditionalChinese: '業務步驟已完成，正在向平台提交整單結果；失敗時可安全重試，不會重複執行開關門。',
    AppLanguage.english:
        'All workflow steps are complete. The final result is being submitted; retrying will not repeat a door operation.',
    AppLanguage.japanese: '業務手順は完了しました。最終結果を送信中です。再試行しても扉操作は繰り返されません。',
  },
  'taskExecutionFinalizationTitle': {
    AppLanguage.simplifiedChinese: '等待任务结果提交',
    AppLanguage.traditionalChinese: '等待任務結果提交',
    AppLanguage.english: 'Submitting Task Result',
    AppLanguage.japanese: 'タスク結果を送信中',
  },
  'taskExecutionRetryFinalization': {
    AppLanguage.simplifiedChinese: '重试提交任务结果',
    AppLanguage.traditionalChinese: '重試提交任務結果',
    AppLanguage.english: 'Retry Final Submission',
    AppLanguage.japanese: '最終送信を再試行',
  },
  'taskExecutionSelectItemHint': {
    AppLanguage.simplifiedChinese: '点击任一待办证件，选择下一次开箱目标',
    AppLanguage.traditionalChinese: '點擊任一待辦證件，選擇下一次開箱目標',
    AppLanguage.english:
        'Select any pending document as the next door-opening target.',
    AppLanguage.japanese: '保留中の証憑を選択して、次に開ける区画の対象にします。',
  },
  'taskExecutionSameSlotRemaining': {
    AppLanguage.simplifiedChinese: '箱格 {doorNo} 还有 {count} 份待取，请逐份扫描，全部取出后再关门',
    AppLanguage.traditionalChinese: '箱格 {doorNo} 還有 {count} 份待取，請逐份掃描，全部取出後再關門',
    AppLanguage.english:
        'Slot {doorNo} still has {count} item(s) to retrieve. Scan each item and close the door only after all are removed.',
    AppLanguage.japanese:
        '区画 {doorNo} には残り {count} 件あります。1 件ずつスキャンし、すべて取り出してから扉を閉めてください。',
  },
  'taskInventoryCloseDetail': {
    AppLanguage.simplifiedChinese: '关闭',
    AppLanguage.traditionalChinese: '關閉',
    AppLanguage.english: 'Close',
    AppLanguage.japanese: '閉じる',
  },
  'taskInventoryCloseDoorAction': {
    AppLanguage.simplifiedChinese: '确认全部放回并关箱',
    AppLanguage.traditionalChinese: '確認全部放回並關箱',
    AppLanguage.english: 'Confirm All Returned and Close Door',
    AppLanguage.japanese: 'すべてを戻して扉を閉めたことを確認',
  },
  'taskInventoryCloseRuleHint': {
    AppLanguage.simplifiedChinese: '确认关箱将把未扫描证件标记为缺失，并把正常及溢余实物标记为已放回。',
    AppLanguage.traditionalChinese: '確認關箱會將未掃描證件標記為缺失，並將正常及溢餘實物標記為已放回。',
    AppLanguage.english:
        'Closing the slot marks unscanned documents as missing and scanned normal or surplus items as returned.',
    AppLanguage.japanese: '扉を閉めると、未スキャンの証憑は不足、正常品と余剰品は返却済みとして記録されます。',
  },
  'taskInventoryCodeDescription': {
    AppLanguage.simplifiedChinese: '飞检码仅用于确认本次盘点计划，验证通过后按平台抽中的箱格整箱盘点。',
    AppLanguage.traditionalChinese: '飛檢碼僅用於確認本次盤點計畫，驗證通過後依平台抽中的箱格整箱盤點。',
    AppLanguage.english:
        'The inspection code confirms this inventory plan. After verification, inspect every document in each platform-selected slot.',
    AppLanguage.japanese:
        '検査コードで今回の棚卸し計画を確認します。認証後、プラットフォームが選択した区画を箱単位で全件確認します。',
  },
  'taskInventoryCodeEmpty': {
    AppLanguage.simplifiedChinese: '请输入飞检码',
    AppLanguage.traditionalChinese: '請輸入飛檢碼',
    AppLanguage.english: 'Enter the inspection code',
    AppLanguage.japanese: '検査コードを入力してください',
  },
  'taskInventoryCodeHint': {
    AppLanguage.simplifiedChinese: '请输入平台下发的飞检码',
    AppLanguage.traditionalChinese: '請輸入平台下發的飛檢碼',
    AppLanguage.english: 'Enter the inspection code issued by the platform',
    AppLanguage.japanese: 'プラットフォームが発行した検査コードを入力してください',
  },
  'taskInventoryCodeIncorrect': {
    AppLanguage.simplifiedChinese: '飞检码错误，请重新输入',
    AppLanguage.traditionalChinese: '飛檢碼錯誤，請重新輸入',
    AppLanguage.english: 'Incorrect inspection code. Enter it again',
    AppLanguage.japanese: '検査コードが正しくありません。再入力してください',
  },
  'taskInventoryCodeInput': {
    AppLanguage.simplifiedChinese: '飞检码',
    AppLanguage.traditionalChinese: '飛檢碼',
    AppLanguage.english: 'Inspection Code',
    AppLanguage.japanese: '検査コード',
  },
  'taskInventoryCodeNotConfigured': {
    AppLanguage.simplifiedChinese: '当前盘点任务未配置飞检码，请联系平台处理',
    AppLanguage.traditionalChinese: '目前盤點任務未設定飛檢碼，請聯絡平台處理',
    AppLanguage.english:
        'No inspection code is configured for this task. Contact platform support',
    AppLanguage.japanese: 'この棚卸しタスクには検査コードが設定されていません。プラットフォームにお問い合わせください',
  },
  'taskInventoryCodeTitle': {
    AppLanguage.simplifiedChinese: '输入飞检码',
    AppLanguage.traditionalChinese: '輸入飛檢碼',
    AppLanguage.english: 'Enter Inspection Code',
    AppLanguage.japanese: '検査コードを入力',
  },
  'taskInventoryCodeUnavailable': {
    AppLanguage.simplifiedChinese: '当前步骤无法校验飞检码，请刷新任务',
    AppLanguage.traditionalChinese: '目前步驟無法驗證飛檢碼，請重新整理任務',
    AppLanguage.english:
        'The inspection code cannot be verified at this step. Refresh the task',
    AppLanguage.japanese: '現在のステップでは検査コードを確認できません。タスクを更新してください',
  },
  'taskInventoryCompletedDetailTitle': {
    AppLanguage.simplifiedChinese: '箱格 #{doorNo} 盘点结果',
    AppLanguage.traditionalChinese: '箱格 #{doorNo} 盤點結果',
    AppLanguage.english: 'Slot #{doorNo} Inventory Result',
    AppLanguage.japanese: '区画 #{doorNo} の棚卸し結果',
  },
  'taskInventoryConfirmDoorClosed': {
    AppLanguage.simplifiedChinese: '确认柜门已关闭',
    AppLanguage.traditionalChinese: '確認櫃門已關閉',
    AppLanguage.english: 'Confirm Door Closed',
    AppLanguage.japanese: '扉が閉じたことを確認',
  },
  'taskInventoryDemoScan': {
    AppLanguage.simplifiedChinese: '演示快速扫描：',
    AppLanguage.traditionalChinese: '示範快速掃描：',
    AppLanguage.english: 'Demo quick scan:',
    AppLanguage.japanese: 'デモ用クイックスキャン：',
  },
  'taskInventoryDemoSurplus': {
    AppLanguage.simplifiedChinese: '模拟溢余',
    AppLanguage.traditionalChinese: '模擬溢餘',
    AppLanguage.english: 'Simulate Surplus',
    AppLanguage.japanese: '余剰をシミュレート',
  },
  'taskInventoryDetailsTitle': {
    AppLanguage.simplifiedChinese: '盘点明细',
    AppLanguage.traditionalChinese: '盤點明細',
    AppLanguage.english: 'Inventory Details',
    AppLanguage.japanese: '棚卸し明細',
  },
  'taskInventoryDocumentCodeColumn': {
    AppLanguage.simplifiedChinese: '合格证编号',
    AppLanguage.traditionalChinese: '合格證編號',
    AppLanguage.english: 'Certificate No.',
    AppLanguage.japanese: '証憑番号',
  },
  'taskInventoryDoorCountdown': {
    AppLanguage.simplifiedChinese: '箱格 {doorNo}：{seconds} 秒',
    AppLanguage.traditionalChinese: '箱格 {doorNo}：{seconds} 秒',
    AppLanguage.english: 'Slot {doorNo}: {seconds}s',
    AppLanguage.japanese: '区画 {doorNo}：{seconds} 秒',
  },
  'taskInventoryDoorRecoveryHint': {
    AppLanguage.simplifiedChinese:
        '箱格 {doorNo} 已取得开门资格，但盘点状态更新失败。确认柜门已经关闭后才能退出。',
    AppLanguage.traditionalChinese:
        '箱格 {doorNo} 已取得開門資格，但盤點狀態更新失敗。確認櫃門已關閉後才能退出。',
    AppLanguage.english:
        'Slot {doorNo} obtained permission to open, but its inventory state failed to update. Confirm the door is closed before leaving.',
    AppLanguage.japanese:
        '区画 {doorNo} は開扉資格を取得しましたが、棚卸し状態を更新できませんでした。扉が閉じたことを確認してから終了してください。',
  },
  'taskInventoryDoorRecoveryTitle': {
    AppLanguage.simplifiedChinese: '请先确认柜门已关闭',
    AppLanguage.traditionalChinese: '請先確認櫃門已關閉',
    AppLanguage.english: 'Confirm the Door Is Closed',
    AppLanguage.japanese: '扉が閉じたことを確認してください',
  },
  'taskInventoryLegendTitle': {
    AppLanguage.simplifiedChinese: '状态说明',
    AppLanguage.traditionalChinese: '狀態說明',
    AppLanguage.english: 'Status Legend',
    AppLanguage.japanese: 'ステータス説明',
  },
  'taskInventoryPhotoPolicy': {
    AppLanguage.simplifiedChinese:
        '正常证件不逐件拍照；建议开关箱保留箱内全景，缺失或溢余时补拍异常照片。当前为流程模拟。',
    AppLanguage.traditionalChinese:
        '正常證件不逐件拍照；建議開關箱保留箱內全景，缺失或溢餘時補拍異常照片。目前為流程模擬。',
    AppLanguage.english:
        'Normal documents are not photographed individually. Keep slot overview images at opening and closing, and capture anomalies for missing or surplus items. This is currently a simulated flow.',
    AppLanguage.japanese:
        '正常な証憑は個別撮影しません。開閉時に区画全景を保存し、不足または余剰がある場合は異常写真を追加します。現在はフローのシミュレーションです。',
  },
  'taskInventoryPlanMissing': {
    AppLanguage.simplifiedChinese: '平台未下发盘点计划',
    AppLanguage.traditionalChinese: '平台未下發盤點計畫',
    AppLanguage.english: 'The platform did not provide an inventory plan',
    AppLanguage.japanese: 'プラットフォームから棚卸し計画が届いていません',
  },
  'taskInventoryPlanTitle': {
    AppLanguage.simplifiedChinese: '盘点计划',
    AppLanguage.traditionalChinese: '盤點計畫',
    AppLanguage.english: 'Inventory Plan',
    AppLanguage.japanese: '棚卸し計画',
  },
  'taskInventoryResultColumn': {
    AppLanguage.simplifiedChinese: '盘点结果',
    AppLanguage.traditionalChinese: '盤點結果',
    AppLanguage.english: 'Inventory Result',
    AppLanguage.japanese: '棚卸し結果',
  },
  'taskInventoryResultMissing': {
    AppLanguage.simplifiedChinese: '缺失',
    AppLanguage.traditionalChinese: '缺失',
    AppLanguage.english: 'Missing',
    AppLanguage.japanese: '不足',
  },
  'taskInventoryResultNormal': {
    AppLanguage.simplifiedChinese: '正常',
    AppLanguage.traditionalChinese: '正常',
    AppLanguage.english: 'Normal',
    AppLanguage.japanese: '正常',
  },
  'taskInventoryResultPending': {
    AppLanguage.simplifiedChinese: '待扫描',
    AppLanguage.traditionalChinese: '待掃描',
    AppLanguage.english: 'Pending Scan',
    AppLanguage.japanese: 'スキャン待ち',
  },
  'taskInventoryResultSurplus': {
    AppLanguage.simplifiedChinese: '溢余',
    AppLanguage.traditionalChinese: '溢餘',
    AppLanguage.english: 'Surplus',
    AppLanguage.japanese: '余剰',
  },
  'taskInventoryRetrySettlement': {
    AppLanguage.simplifiedChinese: '重试盘点结算',
    AppLanguage.traditionalChinese: '重試盤點結算',
    AppLanguage.english: 'Retry Inventory Settlement',
    AppLanguage.japanese: '棚卸し確定を再試行',
  },
  'taskInventoryReturnWithPendingReport': {
    AppLanguage.simplifiedChinese: '保存待上报状态并返回',
    AppLanguage.traditionalChinese: '儲存待上報狀態並返回',
    AppLanguage.english: 'Save Pending Report and Return',
    AppLanguage.japanese: '未送信状態を保存して戻る',
  },
  'taskInventoryReturnNotRequired': {
    AppLanguage.simplifiedChinese: '未发现 / 无需放回',
    AppLanguage.traditionalChinese: '未發現 / 無需放回',
    AppLanguage.english: 'Not Found / Not Applicable',
    AppLanguage.japanese: '未発見 / 返却不要',
  },
  'taskInventoryReturnReturned': {
    AppLanguage.simplifiedChinese: '已放回',
    AppLanguage.traditionalChinese: '已放回',
    AppLanguage.english: 'Returned',
    AppLanguage.japanese: '返却済み',
  },
  'taskInventoryReturnStatusColumn': {
    AppLanguage.simplifiedChinese: '放回状态',
    AppLanguage.traditionalChinese: '放回狀態',
    AppLanguage.english: 'Return Status',
    AppLanguage.japanese: '返却状態',
  },
  'taskInventoryReturnWaiting': {
    AppLanguage.simplifiedChinese: '等待放回',
    AppLanguage.traditionalChinese: '等待放回',
    AppLanguage.english: 'Waiting to Return',
    AppLanguage.japanese: '返却待ち',
  },
  'taskInventorySamplingByBoxRatio': {
    AppLanguage.simplifiedChinese: '按箱格比例抽盘 {percent}%',
    AppLanguage.traditionalChinese: '按箱格比例抽盤 {percent}%',
    AppLanguage.english: 'Sample {percent}% by Slot',
    AppLanguage.japanese: '区画単位で {percent}% を抽出',
  },
  'taskInventorySamplingFull': {
    AppLanguage.simplifiedChinese: '全部箱格盘点',
    AppLanguage.traditionalChinese: '全部箱格盤點',
    AppLanguage.english: 'Full Slot Inventory',
    AppLanguage.japanese: '全区画棚卸し',
  },
  'taskInventorySamplingRuleHint': {
    AppLanguage.simplifiedChinese: '比例按箱格计算；抽中箱格后，箱内全部证件必须全盘。指定证件时，其所在箱格全部纳入。',
    AppLanguage.traditionalChinese: '比例按箱格計算；抽中箱格後，箱內全部證件必須全盤。指定證件時，其所在箱格全部納入。',
    AppLanguage.english:
        'Sampling is calculated by slot. Every document in a selected slot must be checked. A specified document selects its entire slot.',
    AppLanguage.japanese:
        '抽出率は区画単位で計算します。選択された区画内の証憑は全件確認します。指定証憑がある場合はその区画全体を対象にします。',
  },
  'taskInventorySamplingSpecifiedDocuments': {
    AppLanguage.simplifiedChinese: '指定证件所在箱格整箱盘点',
    AppLanguage.traditionalChinese: '指定證件所在箱格整箱盤點',
    AppLanguage.english: 'Inspect Entire Slots Containing Specified Documents',
    AppLanguage.japanese: '指定証憑がある区画を全件棚卸し',
  },
  'taskInventorySamplingSummary': {
    AppLanguage.simplifiedChinese:
        '已完成 {completed} / {required} 箱，共展示 {total} 箱',
    AppLanguage.traditionalChinese:
        '已完成 {completed} / {required} 箱，共顯示 {total} 箱',
    AppLanguage.english:
        'Completed {completed} / {required} selected slots; {total} slots shown',
    AppLanguage.japanese: '対象 {required} 区画中 {completed} 区画完了、全 {total} 区画を表示',
  },
  'taskInventoryScanRfidAction': {
    AppLanguage.simplifiedChinese: '确认扫描',
    AppLanguage.traditionalChinese: '確認掃描',
    AppLanguage.english: 'Confirm Scan',
    AppLanguage.japanese: 'スキャンを確認',
  },
  'taskInventoryScanRfidHint': {
    AppLanguage.simplifiedChinese: '请使用 RFID 设备扫描，或输入演示值',
    AppLanguage.traditionalChinese: '請使用 RFID 裝置掃描，或輸入示範值',
    AppLanguage.english: 'Scan with the RFID device or enter a demo value',
    AppLanguage.japanese: 'RFID 機器でスキャンするか、デモ値を入力してください',
  },
  'taskInventoryScanRfidInput': {
    AppLanguage.simplifiedChinese: '扫描 RFID',
    AppLanguage.traditionalChinese: '掃描 RFID',
    AppLanguage.english: 'Scan RFID',
    AppLanguage.japanese: 'RFID をスキャン',
  },
  'taskInventorySelectSlotHint': {
    AppLanguage.simplifiedChinese: '点击蓝色箱格开始盘点',
    AppLanguage.traditionalChinese: '點擊藍色箱格開始盤點',
    AppLanguage.english: 'Select a blue slot to begin',
    AppLanguage.japanese: '青い区画を選択して開始してください',
  },
  'taskInventorySequenceColumn': {
    AppLanguage.simplifiedChinese: '序号',
    AppLanguage.traditionalChinese: '序號',
    AppLanguage.english: 'No.',
    AppLanguage.japanese: '番号',
  },
  'taskInventorySlotAbnormal': {
    AppLanguage.simplifiedChinese: '已盘 · 有差异',
    AppLanguage.traditionalChinese: '已盤 · 有差異',
    AppLanguage.english: 'Checked · Discrepancy',
    AppLanguage.japanese: '完了 · 差異あり',
  },
  'taskInventorySlotCompleted': {
    AppLanguage.simplifiedChinese: '盘点正确',
    AppLanguage.traditionalChinese: '盤點正確',
    AppLanguage.english: 'Inventory Correct',
    AppLanguage.japanese: '棚卸し一致',
  },
  'taskInventorySlotCheckedCount': {
    AppLanguage.simplifiedChinese: '已盘：{count}',
    AppLanguage.traditionalChinese: '已盤：{count}',
    AppLanguage.english: 'Checked: {count}',
    AppLanguage.japanese: '確認済み：{count}',
  },
  'taskInventorySlotDetailHint': {
    AppLanguage.simplifiedChinese: '逐一扫描箱内全部 RFID；未扫到的预期证件将在关箱时标记为缺失。',
    AppLanguage.traditionalChinese: '逐一掃描箱內全部 RFID；未掃到的預期證件將在關箱時標記為缺失。',
    AppLanguage.english:
        'Scan every RFID in the slot. Expected documents not scanned will be marked missing when the door closes.',
    AppLanguage.japanese:
        '区画内の RFID をすべてスキャンしてください。未スキャンの予定証憑は扉を閉める際に不足として記録されます。',
  },
  'taskInventorySlotDetailTitle': {
    AppLanguage.simplifiedChinese: '箱格 #{doorNo} 证件明细',
    AppLanguage.traditionalChinese: '箱格 #{doorNo} 證件明細',
    AppLanguage.english: 'Slot #{doorNo} Document Details',
    AppLanguage.japanese: '区画 #{doorNo} の証憑明細',
  },
  'taskInventorySlotDifferenceCount': {
    AppLanguage.simplifiedChinese: '差异：{count}',
    AppLanguage.traditionalChinese: '差異：{count}',
    AppLanguage.english: 'Differences: {count}',
    AppLanguage.japanese: '差異：{count}',
  },
  'taskInventorySlotInProgress': {
    AppLanguage.simplifiedChinese: '正在盘点',
    AppLanguage.traditionalChinese: '正在盤點',
    AppLanguage.english: 'In Progress',
    AppLanguage.japanese: '棚卸し中',
  },
  'taskInventorySlotNotRequired': {
    AppLanguage.simplifiedChinese: '无需盘点',
    AppLanguage.traditionalChinese: '無需盤點',
    AppLanguage.english: 'Not Required',
    AppLanguage.japanese: '対象外',
  },
  'taskInventorySlotPartiallyChecked': {
    AppLanguage.simplifiedChinese: '部分已盘',
    AppLanguage.traditionalChinese: '部分已盤',
    AppLanguage.english: 'Partially Checked',
    AppLanguage.japanese: '一部確認済み',
  },
  'taskInventorySlotPending': {
    AppLanguage.simplifiedChinese: '待盘点',
    AppLanguage.traditionalChinese: '待盤點',
    AppLanguage.english: 'Pending',
    AppLanguage.japanese: '棚卸し待ち',
  },
  'taskInventorySlotPendingCount': {
    AppLanguage.simplifiedChinese: '待盘：{count}',
    AppLanguage.traditionalChinese: '待盤：{count}',
    AppLanguage.english: 'To check: {count}',
    AppLanguage.japanese: '対象：{count}',
  },
  'taskInventorySurplusDocument': {
    AppLanguage.simplifiedChinese: '未登记证件',
    AppLanguage.traditionalChinese: '未登記證件',
    AppLanguage.english: 'Unregistered Document',
    AppLanguage.japanese: '未登録証憑',
  },
  'taskInventoryVerifyCode': {
    AppLanguage.simplifiedChinese: '验证并查看盘点明细',
    AppLanguage.traditionalChinese: '驗證並查看盤點明細',
    AppLanguage.english: 'Verify and View Inventory Details',
    AppLanguage.japanese: '認証して棚卸し明細を表示',
  },
  'taskStepInventoryBySlot': {
    AppLanguage.simplifiedChinese: '按箱格执行整箱盘点',
    AppLanguage.traditionalChinese: '按箱格執行整箱盤點',
    AppLanguage.english: 'Perform Full Inventory by Slot',
    AppLanguage.japanese: '区画単位で全件棚卸し',
  },
  'taskStepVerifyInventoryCode': {
    AppLanguage.simplifiedChinese: '验证飞检码',
    AppLanguage.traditionalChinese: '驗證飛檢碼',
    AppLanguage.english: 'Verify Inspection Code',
    AppLanguage.japanese: '検査コードを確認',
  },
  'operatorGenderFemale': {
    AppLanguage.simplifiedChinese: '女',
    AppLanguage.traditionalChinese: '女',
    AppLanguage.english: 'Female',
    AppLanguage.japanese: '女性',
  },
  'operatorGenderMale': {
    AppLanguage.simplifiedChinese: '男',
    AppLanguage.traditionalChinese: '男',
    AppLanguage.english: 'Male',
    AppLanguage.japanese: '男性',
  },
  'operatorPositionArchiveAdministrator': {
    AppLanguage.simplifiedChinese: '档案管理员',
    AppLanguage.traditionalChinese: '檔案管理員',
    AppLanguage.english: 'Records Administrator',
    AppLanguage.japanese: '文書管理者',
  },
  'operatorPositionOperationsSpecialist': {
    AppLanguage.simplifiedChinese: '业务专员',
    AppLanguage.traditionalChinese: '業務專員',
    AppLanguage.english: 'Operations Specialist',
    AppLanguage.japanese: '業務担当者',
  },
  'operatorPositionRegulator': {
    AppLanguage.simplifiedChinese: '监管员',
    AppLanguage.traditionalChinese: '監管員',
    AppLanguage.english: 'Regulatory Officer',
    AppLanguage.japanese: '監督担当者',
  },
  'operatorPositionRegulatorySpecialist': {
    AppLanguage.simplifiedChinese: '监管专员',
    AppLanguage.traditionalChinese: '監管專員',
    AppLanguage.english: 'Regulatory Specialist',
    AppLanguage.japanese: '監督専門員',
  },
  'taskDemoDocumentCertificateOriginal': {
    AppLanguage.simplifiedChinese: '合格证原件',
    AppLanguage.traditionalChinese: '合格證正本',
    AppLanguage.english: 'Original Certificate of Conformity',
    AppLanguage.japanese: '適合証明書原本',
  },
  'taskDemoDocumentEnforcementInspectionMaterials': {
    AppLanguage.simplifiedChinese: '执法检查材料',
    AppLanguage.traditionalChinese: '執法檢查資料',
    AppLanguage.english: 'Enforcement Inspection Materials',
    AppLanguage.japanese: '立入検査資料',
  },
  'taskDemoDocumentEnterpriseRegistrationArchive': {
    AppLanguage.simplifiedChinese: '企业登记档案',
    AppLanguage.traditionalChinese: '企業登記檔案',
    AppLanguage.english: 'Enterprise Registration Records',
    AppLanguage.japanese: '企業登録文書',
  },
  'taskDemoDocumentFoodBusinessLicense': {
    AppLanguage.simplifiedChinese: '食品经营许可证',
    AppLanguage.traditionalChinese: '食品經營許可證',
    AppLanguage.english: 'Food Business License',
    AppLanguage.japanese: '食品営業許可証',
  },
  'taskDemoDocumentIndexed': {
    AppLanguage.simplifiedChinese: '{document} {index}',
    AppLanguage.traditionalChinese: '{document} {index}',
    AppLanguage.english: '{document} {index}',
    AppLanguage.japanese: '{document} {index}',
  },
  'taskDemoDocumentInspectionReportOriginal': {
    AppLanguage.simplifiedChinese: '检验报告原件',
    AppLanguage.traditionalChinese: '檢驗報告正本',
    AppLanguage.english: 'Original Inspection Report',
    AppLanguage.japanese: '検査報告書原本',
  },
  'taskDemoDocumentLicenseCopy': {
    AppLanguage.simplifiedChinese: '许可证副本',
    AppLanguage.traditionalChinese: '許可證副本',
    AppLanguage.english: 'License Copy',
    AppLanguage.japanese: '許可証の写し',
  },
  'taskDemoDocumentProductCertificate': {
    AppLanguage.simplifiedChinese: '产品合格证',
    AppLanguage.traditionalChinese: '產品合格證',
    AppLanguage.english: 'Product Certificate of Conformity',
    AppLanguage.japanese: '製品適合証明書',
  },
  'taskDemoDocumentRelatedArchive': {
    AppLanguage.simplifiedChinese: '同箱关联档案',
    AppLanguage.traditionalChinese: '同箱關聯檔案',
    AppLanguage.english: 'Related Records in the Same Slot',
    AppLanguage.japanese: '同一区画の関連文書',
  },
  'taskDemoDocumentSpecifiedSecurityArchive': {
    AppLanguage.simplifiedChinese: '指定治安档案',
    AppLanguage.traditionalChinese: '指定治安檔案',
    AppLanguage.english: 'Specified Public Security Records',
    AppLanguage.japanese: '指定治安文書',
  },
  'taskDemoDocumentUnselectedArchive': {
    AppLanguage.simplifiedChinese: '未抽中档案',
    AppLanguage.traditionalChinese: '未抽中檔案',
    AppLanguage.english: 'Records Not Selected for Sampling',
    AppLanguage.japanese: '抽出対象外の文書',
  },
  'taskDemoInventoryTitlePublicSecurityArchives': {
    AppLanguage.simplifiedChinese: '公安档案盘点任务',
    AppLanguage.traditionalChinese: '公安檔案盤點任務',
    AppLanguage.english: 'Public Security Records Inventory',
    AppLanguage.japanese: '公安文書棚卸しタスク',
  },
  'taskDemoInventoryTitleZoneAQuarterly': {
    AppLanguage.simplifiedChinese: '盘点任务 · A 区季度盘点',
    AppLanguage.traditionalChinese: '盤點任務 · A 區季度盤點',
    AppLanguage.english: 'Inventory Task · Zone A Quarterly Inventory',
    AppLanguage.japanese: '棚卸しタスク · A エリア四半期棚卸し',
  },
  'taskDemoTitleWithDocument': {
    AppLanguage.simplifiedChinese: '{type}任务 · {document}',
    AppLanguage.traditionalChinese: '{type}任務 · {document}',
    AppLanguage.english: '{type} Task · {document}',
    AppLanguage.japanese: '{document} · {type}タスク',
  },
  'taskErrorAuthenticationRequired': {
    AppLanguage.simplifiedChinese: '身份认证状态已失效，请重新登录',
    AppLanguage.traditionalChinese: '身分認證狀態已失效，請重新登入',
    AppLanguage.english: 'Your verification session has expired. Sign in again',
    AppLanguage.japanese: '本人確認セッションの有効期限が切れました。もう一度ログインしてください',
  },
  'taskErrorIncomplete': {
    AppLanguage.simplifiedChinese: '任务仍有未完成的步骤或证件，请完成后再提交',
    AppLanguage.traditionalChinese: '任務仍有未完成的步驟或證件，請完成後再提交',
    AppLanguage.english:
        'The task still has incomplete steps or documents. Complete them before submitting',
    AppLanguage.japanese: '未完了のステップまたは証憑があります。完了してから送信してください',
  },
  'taskErrorItemAlreadyCompleted': {
    AppLanguage.simplifiedChinese: '该证件已经处理完成，请选择其他待办证件',
    AppLanguage.traditionalChinese: '該證件已處理完成，請選擇其他待辦證件',
    AppLanguage.english:
        'This document has already been processed. Select another pending document',
    AppLanguage.japanese: 'この証憑は処理済みです。別の保留中の証憑を選択してください',
  },
  'taskErrorItemNotFound': {
    AppLanguage.simplifiedChinese: '未找到该待办证件，请刷新任务后重试',
    AppLanguage.traditionalChinese: '未找到該待辦證件，請重新整理任務後重試',
    AppLanguage.english:
        'The pending document was not found. Refresh the task and try again',
    AppLanguage.japanese: '対象の証憑が見つかりません。タスクを更新して再試行してください',
  },
  'taskErrorItemSelectionUnavailable': {
    AppLanguage.simplifiedChinese: '当前步骤不能更换待办证件，请刷新任务',
    AppLanguage.traditionalChinese: '目前步驟無法更換待辦證件，請重新整理任務',
    AppLanguage.english:
        'The pending document cannot be changed at this step. Refresh the task',
    AppLanguage.japanese: '現在のステップでは対象の証憑を変更できません。タスクを更新してください',
  },
  'taskErrorNotFound': {
    AppLanguage.simplifiedChinese: '任务不存在或已不可执行，请返回任务工作台刷新',
    AppLanguage.traditionalChinese: '任務不存在或已無法執行，請返回任務工作台重新整理',
    AppLanguage.english:
        'The task does not exist or is no longer available. Return to the task workbench and refresh',
    AppLanguage.japanese: 'タスクが存在しないか、実行できなくなりました。タスクワークベンチに戻って更新してください',
  },
  'taskErrorOrganizationUnauthorized': {
    AppLanguage.simplifiedChinese: '当前机构无权访问此任务',
    AppLanguage.traditionalChinese: '目前機構無權存取此任務',
    AppLanguage.english:
        'The current organization is not authorized to access this task',
    AppLanguage.japanese: '現在の機関にはこのタスクへのアクセス権限がありません',
  },
  'taskErrorStateChanged': {
    AppLanguage.simplifiedChinese: '任务状态已更新，请刷新后重试',
    AppLanguage.traditionalChinese: '任務狀態已更新，請重新整理後重試',
    AppLanguage.english: 'The task state has changed. Refresh and try again',
    AppLanguage.japanese: 'タスクの状態が更新されました。更新して再試行してください',
  },
  'taskErrorUnexpected': {
    AppLanguage.simplifiedChinese: '操作失败，请稍后重试',
    AppLanguage.traditionalChinese: '操作失敗，請稍後再試',
    AppLanguage.english: 'The operation failed. Try again later',
    AppLanguage.japanese: '操作に失敗しました。しばらくしてから再試行してください',
  },
  'taskErrorWorkflowInvalid': {
    AppLanguage.simplifiedChinese: '平台下发的任务流程异常，请联系平台处理',
    AppLanguage.traditionalChinese: '平台下發的任務流程異常，請聯絡平台處理',
    AppLanguage.english:
        'The task workflow from the platform is invalid. Contact platform support',
    AppLanguage.japanese: 'プラットフォームから受信したタスク手順に問題があります。プラットフォームにお問い合わせください',
  },
  'taskInventoryAnotherDoorActive': {
    AppLanguage.simplifiedChinese: '箱格 {doorNo} 仍在盘点中，请先完成并关门',
    AppLanguage.traditionalChinese: '箱格 {doorNo} 仍在盤點中，請先完成並關門',
    AppLanguage.english:
        'Slot {doorNo} is still being checked. Complete it and close the door first',
    AppLanguage.japanese: '区画 {doorNo} は棚卸し中です。先に完了して扉を閉めてください',
  },
  'taskInventoryCodeVerificationRequired': {
    AppLanguage.simplifiedChinese: '请先验证飞检码',
    AppLanguage.traditionalChinese: '請先驗證飛檢碼',
    AppLanguage.english: 'Verify the inspection code first',
    AppLanguage.japanese: '先に検査コードを確認してください',
  },
  'taskInventoryDoorAlreadyCompleted': {
    AppLanguage.simplifiedChinese: '该箱格已经完成盘点，可直接查看盘点结果',
    AppLanguage.traditionalChinese: '該箱格已完成盤點，可直接查看盤點結果',
    AppLanguage.english:
        'This slot has already been checked. View its inventory result instead',
    AppLanguage.japanese: 'この区画の棚卸しは完了しています。棚卸し結果を確認してください',
  },
  'taskInventoryDoorUnavailable': {
    AppLanguage.simplifiedChinese: '该箱格不在本次盘点范围内',
    AppLanguage.traditionalChinese: '該箱格不在本次盤點範圍內',
    AppLanguage.english:
        'This slot is not included in the current inventory check',
    AppLanguage.japanese: 'この区画は今回の棚卸し対象ではありません',
  },
  'taskInventoryPlanInvalid': {
    AppLanguage.simplifiedChinese: '平台下发的盘点计划异常，请联系平台处理',
    AppLanguage.traditionalChinese: '平台下發的盤點計畫異常，請聯絡平台處理',
    AppLanguage.english:
        'The inventory plan from the platform is invalid. Contact platform support',
    AppLanguage.japanese: 'プラットフォームから受信した棚卸し計画に問題があります。プラットフォームにお問い合わせください',
  },
  'taskInventoryRfidEmpty': {
    AppLanguage.simplifiedChinese: '请扫描或输入 RFID',
    AppLanguage.traditionalChinese: '請掃描或輸入 RFID',
    AppLanguage.english: 'Scan or enter an RFID',
    AppLanguage.japanese: 'RFID をスキャンするか入力してください',
  },
};
