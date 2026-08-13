# 智能柜 Flutter 终端

这是一个面向 Android 智能柜终端屏幕的 Flutter 应用。项目当前包含登录优先的首页、操作员账号与生物识别登录、身份资料录入、任务工作台、存证/取证/借证/还证/盘点任务骨架、管理员入口、多语言、模拟数据边界、稳定性监测和硬件异常恢复提示。

项目目标是让智能柜终端在无人值守场景下具备清晰的业务流程、统一的交互体验、可替换的数据边界、可扩展的硬件抽象，以及后续接入真实后端和真实设备时不会大面积重构的代码结构。

## 1. 项目背景

智能柜终端通常部署在固定场所，面向监管机构操作员和管理员使用。相比普通移动 App，智能柜软件更关注以下问题：

- 设备长期运行，不能频繁人工干预。
- 业务流程必须清晰，避免误开柜、漏记录、状态错乱。
- 人脸、指纹、NFC、柜控板、扫码器等硬件可能随时异常，需要给现场人员明确处理方式。
- 后台接口、柜控板协议、摄像头权限和系统保活策略通常会分阶段接入。
- 柜机端需要在断网、重启、崩溃、硬件失败等情况下具备恢复能力。

本项目当前以 Flutter 实现智能柜触屏端交互，并通过模拟数据演示已经落地的流程骨架。真实业务闭环仍依赖后端、柜控板、门磁、RFID、OCR 和扫码设备，不能由模拟步骤替代。

## 2. 当前状态

当前项目已实现以下主线能力：

- 登录优先的新版智能柜首页。
- 人脸登录与账号登录入口。
- 普通操作员账号、人脸和指纹登录已统一接入 AFRR TCP A170/B170 报文协议。
- 人脸、指纹、NFC 三项全部完成的身份验证。
- 可通过 `AppConfig.current.isTestMode` 控制账号登录后的身份测试旁路；当前测试配置为 `true`，平台账号密码验证成功后直接进入任务中心，人脸登录仍执行三项认证。该开关不会绕过真实账号接口，正式部署前必须改为 `false`。
- 本机身份资料同步、缺失资料录入和异常复核报备。
- 按监管机构隔离的任务工作台。
- 存证、取证、借证、还证和盘点五类任务的统一入口、类型区分与顺序步骤演示。
- 应用进程内的全局单柜门互锁，以及演示数据中的监管机构专属箱格校验。
- 管理员登录、身份校验与设备控制台。
- ZRD STUM 终端升级监控、URL 升级包校验、管理员确认和 Android 安装状态追踪。
- 四语言切换。
- 共享人脸、指纹、NFC 认证组件。
- 共享认证进度条和步骤卡片。
- Data Source、DTO、Domain Entity、Repository 分层。
- 模拟后端数据。
- Flutter 层崩溃日志和运行健康监测。
- 摄像头、指纹、NFC、柜控板异常恢复建议。
- Widget 测试和基础设施单元测试。

当前仍需接入或完成生产验收的能力：

- 真实后端 HTTP 接口。
- 真实柜控板开门、关门、门磁状态读取。
- 真实指纹、NFC、扫码器驱动。
- 真实 RFID、OCR、拍照上传，以及平台分箱和任务结果上报。
- 借出记录、归还核销、期限等真实借还业务闭环。
- 按箱格生成的盘点计划、缺失/溢余结果和异常留痕平台接口。
- Android 前台服务、开机自启、默认 Launcher 和厂商系统白名单。
- Device Owner、Device Admin Receiver 与 Lock Task 已有代码边界，但仍需设备配置和目标真机验收。
- 文件持久化崩溃日志。
- 远程运行指标、异常上报和远程运维平台；AFRR APP 在线心跳已接入。
- URL 升级链路的现场服务端联调、稳定 release 签名和目标设备安装验收，以及协议未定义的整包分发、结果上报、灰度与回滚闭环。

## 3. 技术栈

- Flutter 3.x：跨平台 UI 框架。
- Dart 3.x：业务逻辑和 UI 代码语言。
- Riverpod：依赖注入和状态管理基础能力。
- Material 3：基础视觉组件体系。
- flutter_localizations：Flutter 官方国际化支持。
- camera：摄像头预览和拍照能力。
- flutter_test：Widget 测试和单元测试。
- flutter_lints：静态代码规范。

## 3.1 文档索引

- `README.md`：项目总说明、业务流程、技术栈和常用命令。
- `ARCHITECTURE.md`：项目架构、分层规则和模块依赖方向。
- `ROOT_DIRECTORY.md`：根目录文件和文件夹用途说明。
- `打包命令.md`：Android APK 打包命令和本机打包注意事项。

## 4. 快速开始

### 4.1 安装依赖

```bash
flutter pub get
```

### 4.2 启动应用

Android 设备：

```bash
flutter run -d android
```

Windows 桌面：

```bash
flutter run -d windows
```

默认运行：

```bash
flutter run
```

### 4.3 构建 Android 调试包

```bash
flutter build apk --debug
```

### 4.4 自动递增版本并构建 Android release

如果只需要生成可安装的本地测试 APK，不需要先冻结正式 `applicationId` 或配置生产证书：

```powershell
dart run tool/build_release.dart --local-build
```

该命令同样把 patch 与 `versionCode` 各增加 1，并把版本写回 `pubspec.yaml`；产物使用 debug 证书，仅可用于开发或现场测试，不能作为生产 OTA 包。Android 桌面显示名称由 `app_name` 资源决定，与只能使用 ASCII 域名格式的内部 `applicationId` 不是同一个概念。

正式打包统一使用项目内发布工具：

```powershell
dart run tool/build_release.dart `
  --dart-define=AFRR_HOST=10.0.0.1 `
  --dart-define=AFRR_PORT=16666 `
  --dart-define=AFRR_SHELF_CODE=123456789012345 `
  --dart-define=DEVICE_IMEI=123456789012345 `
  --dart-define=STUM_DP=10.0.0.1
```

工具会读取 `pubspec.yaml` 的 `version` 字段，并让补丁版本和 Android 构建号
各增加 1，例如 `1.0.0+1 → 1.0.1+2 → 1.0.2+3`。只有 APK 构建成功、
版本元数据正确且正式签名验证通过后，工具才会把新版本写回 `pubspec.yaml`。
预检、构建或验真失败不会修改持久版本；失败候选不得上传、分发或创建 STUM
offer。任何 APK 一旦离开本机或无法确认未分发，其版本即视为已消耗，修复时必须
人工指定更高版本，不能盲目复用同一 `versionName/versionCode`。

正式发布工具当前面向 Windows。生产 `--dart-define` 必须显式提供，除
AFRR/STUM 身份外还包括当前 APK 构建批次日期
`STUM_VERSION_DATE=yyyyMMdd`；脚本会校验并透传给 Flutter，避免静默使用
源码中的现场样例默认值。
本地锁只保护当前工作区；正式版本必须由唯一发布机串行生成，多台电脑或多个
clone 并行发布需要先引入中央版本分配服务。

`android/key.properties` 继续采用简单的 `key=value` 单行格式；相对
`storeFile` 与 Gradle 一致，以 `android/app/` 为基准。路径或密码如需 Java
Properties 转义、续行或 `:` 分隔，应先改为无转义的单行值，避免发布工具与
Gradle 对同一配置产生不同解释。

- `1.0.1` 会成为 Android `versionName`、升级页当前版本和全局右下角版本；
  STUM `T03.VE` 按现场服务端约定包装为 `SL_V1.0.1_yyyyMMdd`。
- `2` 会成为 Android `versionCode`。OTA 安装门禁要求它严格大于设备已安装
  版本的 `versionCode`。
- 现场 OTA 每次必须同时更新两部分；只提高 `versionCode` 会被 STUM 的同
  `versionName` 判断挡住，只提高 `versionName` 而不提高 `versionCode` 会被
  Android 防降级门禁拒绝。

正式制品输出到 `build/releases/smart-cabinet-<versionName>+<versionCode>.apk`，
并同时生成供制品核对的 `.sha256` 和供 STUM `S03.MD` 使用的 `.md5`
摘要。`build/` 会被 `flutter clean` 删除，因此验收后必须把正式制品和两个摘要
复制到受控发布库；本地目录不能作为唯一归档。可以先预览下一版，不启动 Flutter
或修改文件：

```powershell
dart run tool/build_release.dart --dry-run
```

`--dry-run` 只计算下一版本，不执行包名、测试模式、生产参数或签名发布预检。

切换 minor 或 major 版本时可显式给出目标版本；名称和构建号都必须严格高于
当前版本：

```powershell
dart run tool/build_release.dart --version-name 1.1.0 --version-code 20 `
  --dart-define=AFRR_HOST=10.0.0.1 `
  --dart-define=AFRR_PORT=16666 `
  --dart-define=AFRR_SHELF_CODE=123456789012345 `
  --dart-define=DEVICE_IMEI=123456789012345 `
  --dart-define=STUM_DP=10.0.0.1 `
  --dart-define=STUM_VERSION_DATE=20260812
```

正式模式要求 `AppConfig.current.isTestMode == false`，并要求
使用已经冻结的非示例 `applicationId`，且 `android/key.properties` 的稳定 release
证书配置完整。除 Gradle 使用的四个签名字段外，`key.properties` 还必须提供
冻结的 `applicationId` 与 `certificateSha256`；工具会将源码包名和 APK signer
分别与这两个生产基线比对。当前缺少正式签名配置时，
只允许显式执行以下未签名编译检查；它使用当前版本、不递增也不修改版本，
产物不能用于生产 OTA：

```powershell
dart run tool/build_release.dart --allow-unsigned-compile-check
```

不要手改已忽略的 `android/local.properties`，也不要把直接执行
`flutter build apk --release` 或 `gradlew assembleRelease` 当作自动发版入口。
新 APK 还必须实际安装并重启应用，热重载不会改变 Android 包元数据。

### 4.5 常用验证命令

```bash
dart format path/to/changed_file.dart
flutter analyze --no-pub
flutter test --no-pub
```

将示例路径替换为本次实际修改的 Dart 文件；行为变化优先运行相关测试，跨模块或高风险改动再运行完整测试。

## 5. 业务流程说明

### 5.1 首页与登录入口

首页只展示柜体状态、统计摘要、静态背景区和登录入口，不直接发起具体业务任务。操作员必须先通过“人脸登录”或“账号登录”建立身份，再根据账号所属监管机构进入任务工作台。全局右下角从 Android 已安装 APK 元数据读取真实 `versionName`，与升级页当前版本同源；版本号连续点击仍可打开设置与管理员入口。

相关文件：

- `lib/src/features/home/presentation/pages/home_page.dart`
- `lib/src/features/home/presentation/widgets/home_dashboard.dart`
- `lib/src/features/home/presentation/widgets/settings_dialog.dart`

### 5.2 操作员身份流程

“人脸登录”入口进入统一身份校验页，首个成功的人脸、指纹或 NFC 因子负责识别账号；也可以先用账号密码确认账号。账号密码本身不计入身份因子，普通任务要求同一账号完成人脸、指纹与 NFC 三项认证。

账号、人脸和指纹登录均通过 AFRR TCP A170/B170 完整报文完成，不再使用 HTTP 登录接口。三种方式统一使用 `OperatorLoginRequest`：账号对应 `logway = 1`，人脸文件 ID 对应 `logway = 2`，指纹文件 ID 对应 `logway = 3`。账号密码去除首尾空白后转为 40 位大写 SHA-1；`OperatorProtocolLoginRequestDto` 按 2026-08-10 协议固定将请求包装为 `{ "func": "userLogin", "data": ... }`，只认 `rst=9` 成功，不再支持旧版 `cmd=login`。协议层再加入货架编码、16 位流水号、BCD 时间、`0xA0` JSON KLV、异或校验、`0x7F` 转义及头尾标记。客户端同时解析文档标准的“原流水号 + JSON”B170，以及现场 APP `logon` 返回的“原指令码 + 原流水号 + 结果码”精简 B170；`userLogin` 成功必须带人员资料 JSON。单次等待 5 秒，最多重发 2 次。

应用启动后先在 AFRR 长连接发送 `func=logon`，成功后每 60 秒发送一次 `func=heartbeat`，并按原流水号等待 B170 `rst=9`。心跳超时同样最多重发 2 次；持续失败时废弃当前会话和 Socket，延时重连并保证新连接的首帧仍为 `logon`。心跳时间使用协议规定的 18 位本地时间。当前真实终端 A101/A102 接收链路尚未接入，所以心跳中的终端透传 `data` 明确发送 `null`，不使用空数组伪造终端在线；后续接入时只通过可替换的心跳载荷 Provider 提供去掉头尾各 2 字节的终端报文。

运行前必须通过 `--dart-define=AFRR_HOST=... --dart-define=AFRR_PORT=... --dart-define=AFRR_SHELF_CODE=... --dart-define=DEVICE_IMEI=...` 显式配置主机、端口、15/16 位货架编码和 15 位主板 IMEI；协议文档没有给出服务器地址，因此缺少配置时登录会明确失败，不会误用原 HTTP 地址。当前链路只支持未加密标记 `0x00`；收到 `0x01` 会明确拒绝，待服务端提供 AES 密钥、IV 和协商规则后再接入。

人脸和指纹登录会先从可替换的本机识别边界取得文件 ID，再发送 A170。当前本机人脸/指纹文件 ID 解析仍由模拟硬件数据源提供，正式设备需替换为真实模块。B170 返回的 `uid`、`uname`、`rname`、`uorg`、`faceId`、`fgerId` 和 `time` 会映射为账号与当前 AFRR 会话；协议没有定义 HTTP token。

测试阶段例外：`lib/src/core/config/app_config.dart` 中 `AppConfig.current.isTestMode` 为 `true` 时，真实平台账号密码登录成功会为本次测试会话建立三项认证旁路并直接进入任务中心。该开关不跳过账号接口、不影响人脸登录，正式环境必须设为 `false`。

管理员与普通操作员身份校验页共用同一套页面间距、标题、进度和三栏卡片尺寸。测试模式下，人脸卡片明确显示“模拟认证”，不启动摄像头、不提交或等待后端；正式模式仍保留真实摄像头与身份仓库校验路径。

- 资料正常：人脸、指纹、NFC 三项认证全部完成后才能进入任务工作台。
- 本机无资料但平台资料完整：先同步到本机，再完成人脸、指纹与 NFC 三项认证。
- 缺少人脸或指纹：只录入缺失项；单项失败留在录入页重试，全部录入成功后 3 秒自动或手动返回首页重新登录。
- 本机资料异常：完成人脸、指纹与 NFC 三项复核；三项都已尝试后仍有异常时，先向平台报备，再重录异常的人脸或指纹资料。

以下内存账号仅供自动化测试和身份资料分支验证；正式运行的账号登录界面不会接受这些账号作为离线兜底：

| 账号 | 密码 | 演示分支 |
| --- | --- | --- |
| `666666` | `666666` | 资料正常，三项认证完成后进入任务工作台 |
| `100001` | `123456` | 缺少人脸和指纹，进入录入流程 |
| `100002` | `123456` | 平台资料完整、本机仅有 NFC，先同步再完成三项认证 |
| `100003` | `123456` | 本机人脸和指纹异常，完成三项复核后报备并重录异常项 |

相关文件：

- `lib/src/features/identity_verification/presentation/operator_login_coordinator.dart`
- `lib/src/features/identity_verification/presentation/pages/operator_verification_page.dart`
- `lib/src/features/identity_verification/presentation/pages/identity_enrollment_page.dart`
- `lib/src/features/identity_verification/presentation/widgets/operator_account_login_dialog.dart`

### 5.3 任务工作台与安全约束

身份验证通过后，任务工作台只加载当前监管机构的待办任务。当前无任务安全退出倒计时为 10 秒，只在无加载、无导航、无进行中动作且全部柜门确认关闭时推进。

- 任意时刻最多一个箱格取得开启资格；每次开门周期签发唯一操作 ID，只有同门且同操作 ID 的关门确认才能释放并允许下一个箱格。
- 箱格与监管机构独占绑定；当前由 Fake DataSource 内存绑定和 Repository 校验实现，其他机构不能因箱格空闲而复用。
- 五类任务必须匹配完整固定步骤序列；缺步、增步、乱序或“待办步骤之后又出现已完成步骤”的平台任务会被 Repository 拒绝。
- 开门前重新核对身份因子、操作员机构、任务机构、当前证件门号与平台箱格绑定；盘点开始、扫码和关箱时还会再次核对箱格绑定。
- 开门后启动 30 秒倒计时；超时只显示报警，不会自动释放互锁。
- 开门结果响应异常时先回读最新任务：若平台已提交则保持当前开门周期继续；若无法确认，必须人工确认关门，由 Repository 把可能已提交的开门步骤安全回退后才释放互锁。
- 柜门未确认关闭时，禁止返回任务中心、手动退出和自动退出；安全条件恢复后才重新开始倒计时。
- `CabinetDoorGuard` 仅提供单 Dart isolate 的进程内第一道互锁。真实投产仍需柜控板门磁状态、平台授权或租约和异常恢复。

相关文件：

- `lib/src/features/task_center/presentation/pages/task_center_page.dart`
- `lib/src/features/task_center/presentation/pages/task_execution_page.dart`
- `lib/src/core/device/cabinet_door_guard.dart`

### 5.4 五类任务目标流程

下述内容是任务中心需要遵守的目标业务规则。文档中的“存件、取件、借件、还件”分别对应当前代码和界面中的“存证、取证、借证、还证”。所有任务均先完成身份验证，再由 Repository 复核当前账号、监管机构、任务、步骤和箱格授权；任意时刻最多允许一个柜门取得开启资格。

#### 5.4.1 存件（存证）

进入存证任务后，为证件粘贴并读取 RFID，拍摄正面和反面，提交 OCR 返回的证件信息供操作员确认。确认无误后由平台分配当前机构专属箱格，Repository 复核门号后申请柜门互锁并通知开门；操作员在限时内存入证件并关门，终端再上报 RFID 已存入。多份证件依次处理，全部完成后进入任务完成页。

RFID 读取、OCR 识别、平台分箱、真实开门和结果上报当前仍是待接入能力；界面上的模拟完成不能视为平台已经收件。

#### 5.4.2 取件（取证）

进入取证任务后，先通过专用入口校验取件码，再展示当前账号和机构可取的证件列表。点击证件或箱格后复核平台授权并打开对应柜门，在限时内取出证件并逐一扫描 RFID；同一箱格有多份待取证件时应在本次开门内连续取完，匹配无误后关门并上报。所有授权证件取完后完成任务。

常规取件不默认要求逐份拍照；如平台规则要求异常留痕，可在 RFID 不匹配、箱内缺件等异常分支拍摄箱格全景。

#### 5.4.3 借件（借证）

物理操作与取件相同：校验取件码、查看可借列表、按箱格开门、扫描 RFID、限时取出、关门并上报。业务上必须使用独立借证任务类型，并由平台建立借出人、借出时间、应还时间和待归还状态；后续还证成功后才能核销闭环。

当前终端只区分借证任务类型并演示取出步骤，尚未接入真实借出记录、期限和核销接口，不能宣称借还闭环已经落地。

#### 5.4.4 还件（还证）

进入还证任务后展示待还列表，扫描 RFID 与借出记录匹配；按平台要求在拍照箱采集证件正反面并进行 OCR 核对，核对通过后确认目标箱格。Repository 完成机构和门号复核后打开柜门，操作员限时放回并关门，终端上报 RFID 已归还，再继续处理下一份证件。全部归还并经平台核销后完成任务。

拍照箱、真实 OCR、借出记录匹配和平台核销当前仍需接入；模拟步骤只用于验证页面顺序与失败不推进原则。

#### 5.4.5 盘点

盘点是按箱格完成的“取出核对再放回”，不是把同一箱格中的证件拆成多次开门。身份验证后进入盘点任务，通过专用入口输入飞检码，成功后展示箱格盘点明细；点击待盘箱格后打开柜门，取出箱内全部证件逐一扫描 RFID，确认合格证放回并关闭柜门，再继续盘点其他箱格。

抽盘范围由平台生成并固化到任务中：

- 按比例盘点时，比例按有权盘点的箱格数量计算，不按证件数量计算；比例大于 0 时如何取整由平台统一约定，建议向上取整且至少抽 1 箱。
- 指定证件盘点时，每个指定编号必须唯一匹配一份预期证件；定位所在箱格并按箱格去重后，把这些箱格中的全部证件纳入盘点。
- 终端会验证每份预期证件都属于计划中的某个箱格；全量计划漏列箱格、比例与抽中数量不一致、指定编号不存在或活动箱格与缓存绑定不一致时拒绝执行。
- 未抽中的箱格只展示“无需盘点”，不得展示其他监管机构的证件数量或明细；终端不得在本地重新随机抽箱。

箱格按钮同时显示箱号、待盘数量和文字状态，例如 `#50`、`待盘：2`。颜色含义固定为：

| 颜色 | 状态 | 业务含义 |
| --- | --- | --- |
| 灰色 | 无需盘点 | 本任务未抽中或当前账号无权查看明细，按钮不可发起开门 |
| 蓝色 | 待盘 | 已纳入任务，尚未打开箱格 |
| 橙色 | 盘点中 | 柜门已打开，正在核对且尚未形成部分匹配结果 |
| 浅绿色 | 部分完成 | 已匹配部分证件，仍有预期证件待扫描或待放回 |
| 绿色 | 盘点正常 | 全部预期证件匹配、无溢余且已确认放回 |
| 红色 | 盘点异常 | 存在缺失、溢余或未确认放回 |

打开箱格后使用明细窗口展示“序号、合格证编号、RFID、盘点结果、放回状态”。扫描到预期 RFID 时自动标记正常；扫描到非预期 RFID 时追加一行并标记溢余，同一 RFID 重复扫描不得重复追加。只有收到当前柜门的明确关门确认后，才能把仍未扫描的预期证件自动标记为缺失；30 秒超时、页面销毁或关闭弹窗都不得代替关门确认。关门后汇总箱格结果、关闭明细窗口，并将按钮更新为绿色或红色。

缺失证件的放回状态应显示“未发现”，只有实际扫描到的正常或溢余证件才使用“等待放回、已放回或未确认放回”。放回确认可以由二次扫描、柜内 RFID 或明确人工确认实现，最终方式以后续硬件协议为准。

常规盘点建议不对每份证件拍照；出现缺失、溢余等异常时，可按平台任务要求拍摄一张箱格全景用于报备。异常照片的采集、临时文件清理和上传接口目前尚未接入。

#### 当前实现边界

当前任务中心已经提供五类任务入口、完整固定步骤校验、取证/借证待办证件选择、机构过滤、Repository 业务校验和按开门周期隔离的应用进程内单柜门互锁。盘点已改为箱格级状态机，并实现演示飞检码、平台计划不变量校验、六色状态、重复扫码幂等、缺失/溢余明细、关门结算和放回状态；抽样计算本身仍应由真实平台完成，终端只执行固定计划。真实 RFID、OCR、柜控板门磁、拍照上传、借出记录和平台任务接口仍需后续接入。

### 5.5 管理员入口

管理员从设置弹窗进入账号登录，登录通过后继续完成人脸、指纹和 NFC 三项身份校验，再进入设备控制台。控制台包含相机能力、推流状态、自动检测、终端升级与通讯日志等设备运维功能。

相关文件：

- `lib/src/features/admin/presentation/widgets/admin_login_dialog.dart`
- `lib/src/features/admin/presentation/pages/admin_verification_page.dart`
- `lib/src/features/admin/presentation/pages/admin_console_page.dart`

### 5.6 终端升级

管理员控制台提供独立的“终端升级”页面。升级监控默认关闭，当前现场服务器预填为 `47.107.40.88:21251`，仍必须由管理员显式保存并启用；`ID` 由管理员填写设备号（非零开头的 11 位或 15 位数字）。`T01.IM` 固定读取 `AppConfig.current.afrrDeviceImei`，构建来源与 AFRR 共用 `--dart-define=DEVICE_IMEI=...`；生产配置要求 15 位数字，以确保升级请求能匹配后台按 IMEI 绑定的终端任务，不再维护第二份升级模块号环境配置。协议实体仍兼容现场曾验证过的 11 位格式，但生产 Provider 不使用第二份模块号。`T01.DP` 固定读取 `--dart-define=STUM_DP=...`，必须是一个或多个以英文逗号分隔的 IPv4 地址，当前默认现场值为 `47.107.40.88`；`T01.CD` 固定读取“关于设备”中的唯一设备 ID，即 Android `Settings.Secure.ANDROID_ID`。该 ID 是 Android 标识而非真实硬件芯片序列号，缺失或为占位值时会在建连前失败。管理员升级页面可完整只读展示 IM、DP、CD，但不能编辑或在 `AppLocalStore.upgrade` 中保存第二份值；旧 `moduleImei`、`dataProtocolIp` 和 `chipId` 会在读取时清理。`PT` 仍可按服务端约定填写。

当前实现遵循 ZRD STUM 协议的 URL 控制链路：TCP 重连后先发送 `T01`，只有收到对应 `S00 01:OK` 才直接发送 `T03`，二者之间不发送 `T02`；`T03` 固定使用 `DT=1`，并按现场服务端约定把 Android 真实 `versionName` 与构建配置 `STUM_VERSION_DATE=yyyyMMdd` 编码为 `SL_V{versionName}_{date}`，例如 `SL_V1.0.2_20260812`。日期绑定 APK 构建批次，不能使用每次请求当天日期。服务端返回 `S03` 后，`VE=0` 只表示本次没有匹配到可下发升级包，不能据此断言客户端一定是最新版本；新版本只接受当前 T03 等待窗口内的 HTTP/HTTPS URL、匹配的 `PT` 和 32 位完整文件 MD5，并以复用服务端 `SN` 的 `T00` 回执。窗口关闭后只会对已经接收的同 `SN/VE/AD/MD/PT` 帧做幂等补发 `OK`，其它人工或迟到 `S03` 均回复 `NG1`，不得创建或替换升级任务。旧配置的迟到连接结果不会覆盖新连接，停止、重配或释放监控会使未提交下载及原生预提交操作失效。文档没有定义 `AD=2` 的分包帧、顺序、重传或完整性规则，因此终端会明确回复 `NG3AD`，不会自行扩展协议。

发现升级后不会立即安装。后台启动或重连收到合法 `S03` 时，会在当前页面顶部显示不含 URL、MD5 或设备身份的“发现终端新版本”提示；点击处理仍需先通过管理员账号登录以及人脸、指纹、NFC 三项校验，通过后才直接进入终端升级页。通知本身不能触发下载或安装；停止、重配或安装终态使 offer 失效时会同步清除提示。管理员进入升级页后，仍需确认其看到的同一份 offer；所有柜门均已关闭时，终端才会原子取得应用进程内的升级维护租约，阻止新的开门请求，再流式下载 APK、限制最大 512 MB 并校验 MD5。停止、重配、页面释放或 Activity 销毁会用同一 operation ID 取消尚未跨过 `PackageInstaller.commit` 的原生操作；跨过不可逆提交点后维护租约保持到 Android 明确终态。应用首帧前无论监控开关都会恢复原生活动安装及其维护租约，避免进程重建期间短暂允许开门。Android 原生层再次校验服务端 `VE` 与 APK `versionName`（仅兼容单个大写数字前导 `V`、请求的 `SL_V{version}_{yyyyMMdd}` 及服务端响应的 `SL_APP_V{version}` 外壳）、包名、签名证书链和严格递增的 `versionCode`，再提交 `PackageInstaller`；结果回调还会核对任务、Session、系统包名和实际安装的精确版本。Device Owner 或满足系统无交互更新条件的设备可由系统直接处理，否则可能显示系统安装确认页；安装完成后 `MY_PACKAGE_REPLACED` Receiver 会尝试恢复柜机主界面。Kiosk/OEM 仍可能限制后台拉起，因此必须在目标机配合 Device Owner 或外部 watchdog 做自更新验收。安装状态独立持久化，但当前协议没有定义安装结果上报、灰度策略或回滚命令。

当前仓库没有 `android/key.properties`，release 不会回退到 debug key，而会保持未签名，因此不能直接用于 OTA。生产部署必须配置稳定、备份且不入库的正式证书；已安装应用与升级 APK 必须保持 Android 认可的签名连续性。协议控制连接是普通 TCP，且为兼容现场协议仍允许 HTTP 下载；生产网络必须使用受控专网/VPN，升级地址应优先配置 HTTPS，不能把带令牌的 URL 暴露到不可信网络。

相关文件：

- `lib/src/features/terminal_upgrade/`
- `lib/src/features/terminal_upgrade/data/datasources/method_channel_terminal_upgrade_device.dart`
- `android/app/src/main/kotlin/com/example/smart_cabinet/upgrade/`

### 5.7 通讯日志

管理员控制台右侧功能列表提供独立的“通讯日志”页面。页面按时间倒序显示服务器、硬件或升级指令，以及上报/下发、消息体、请求时间和请求结果；点击消息体可查看该次通讯的完整诊断快照。这里的“上报”固定表示柜机软件发送，“下发”固定表示柜机软件接收。ZRD STUM 的 TCP 建连以及每一条 `T01`、`T03`、`T00` 上行帧和 `S00`、`S03` 下行帧统一归为“升级指令”；版本、SN、MD5 与脱敏后的协议属性可用于现场对账，ID、IM、DP、CD 和升级包 URL 路径仍不得进入日志。

日志使用应用进程内 500 条有界队列，不写入业务数据库或错误日志文件。当前覆盖 AFRR、STUM、MQTT、升级包 HTTP、Kiosk/摄像头/升级 MethodChannel，以及 Android 原生 RTSP 控制握手、18080 HTTP 控制请求、错误日志 HTTP 上报和 PackageInstaller 异步回调。账号、口令摘要、令牌、终端标识、生物资料、人员资料、本地路径和 URL 认证/查询参数会在进入队列前脱敏；图片、APK 内容、SDP、VPS/SPS/PPS、RTP/H265 帧和其它二进制内容不会进入日志。RTSP 日志只观察控制请求与响应，不改变视频推流、帧发送、重连或背压逻辑。

相关文件：

- `lib/src/core/logging/communication_log_store.dart`
- `lib/src/core/logging/native_communication_log_bridge.dart`
- `lib/src/features/admin/presentation/pages/admin_communication_log_page.dart`
- `android/app/src/main/kotlin/com/example/smart_cabinet/logging/`

## 6. 架构说明

本仓库采用轻量 Feature-first 架构：

```text
lib/
  main.dart
  src/
    app/                 # 应用组装：启动、路由、主题、国际化和应用外壳
    core/                # 与具体业务无关的基础能力
    features/            # 按业务模块组织
      <feature>/
        data/            # 数据源、DTO 和仓库实现
        domain/          # 业务实体、仓库接口和业务规则
        presentation/    # 页面、业务组件和 Controller/Provider
    shared/              # 跨业务复用的 UI 组件
```

目录按实际需要创建，不要求小功能补齐空的 `data/domain/presentation`。

### 6.1 app

`app` 是应用组装层，负责启动、路由、主题、多语言和全局入口。

- `lib/src/app/app.dart`：根组件和 `MaterialApp` 装配。
- `lib/src/app/bootstrap/bootstrap.dart`：Flutter 初始化、异常捕获和健康监测启动。
- `lib/src/app/routing/app_routes.dart`：路由名称。
- `lib/src/app/routing/app_router.dart`：路由与页面映射。
- `lib/src/app/shell/app_shell.dart`：柜机页面外壳。
- `lib/src/app/theme/app_theme.dart`：主题配置。
- `lib/src/app/localization/app_localizations.dart`：多语言入口。

### 6.2 core

`core` 是跨业务基础设施层，不依赖具体业务模块。

- `camera`：摄像头发现、预览与推流能力。
- `config`：应用配置。
- `device`：柜机平台抽象、Kiosk/升级 MethodChannel 与应用级柜门互锁。
- `logging`、`monitoring`：日志、崩溃记录和运行健康监测。
- `mqtt`：MQTT 连接、消息与设备命令。
- `network`：网络客户端、结果抽象和模拟 API 数据。
- `storage`：本地存储抽象与实现。

### 6.3 features

`features` 按业务模块聚合数据访问、业务模型和界面，当前包括 `home`、`identity_verification`、`task_center`、`admin` 和 `terminal_upgrade`。

标准数据流为：

```text
presentation -> domain repository -> data repository -> data source
```

- `data/datasources`：调用 HTTP、本地数据或设备接口。
- `data/dtos`：需要适配外部结构时创建的响应对象；不为 Fake DataSource 强制补空 DTO。
- `data/repositories`：实现仓库接口并完成 DTO 到实体的映射。
- `domain/entities`：页面和业务流程使用的实体。
- `domain/repositories`：数据访问契约。
- `presentation/pages`：业务页面。
- `presentation/widgets`：仅当前业务使用的组件。

后端字段变化时，优先修改 Data 层；页面通过 Domain 层保持稳定。

### 6.4 shared

`shared` 只放跨多个业务模块复用的 UI。身份认证是一项独立业务能力，相关实体和组件位于 `features/identity_verification`，而不是继续堆进全局共享目录。

完整的依赖方向、Riverpod 和命名规则见 `ARCHITECTURE.md`。

## 7. 多语言说明

项目支持四种语言：

- 简体中文。
- 繁体中文。
- 英语。
- 日语。

调用方式：

```dart
final text = context.l10n.t('operatorVerificationBadge', '身份校验中 · 三项必选');
```

约定：

- 页面里保留中文兜底，避免 key 缺失时页面显示空白。
- 多语言 key 使用模块前缀，便于查找。
- 多语言字典按模块拆分，存放在 `lib/src/app/localization/values/`。
- 新增页面固定文案时，应同步补充语言切换测试。

字典文件：

- `home_localizations.dart`
- `identity_localizations.dart`
- `operator_workflow_localizations.dart`
- `admin_localizations.dart`

## 8. 共享身份认证组件

项目已经将人脸、指纹、NFC 认证抽成身份业务组件，由操作员登录、资料录入和管理员认证复用。

### 8.1 人脸识别

组件：

```text
lib/src/features/identity_verification/presentation/widgets/face_verification_card.dart
```

能力：

- 初始化摄像头。
- 优先选择前置摄像头。
- 摄像头预览。
- 拍照定格。
- 模拟提交后端校验。
- 无摄像头或测试环境下允许 fallback。
- 摄像头权限、启动、拍照异常展示恢复建议。

### 8.2 指纹和 NFC

组件：

```text
lib/src/features/identity_verification/presentation/widgets/sensor_verification_card.dart
```

能力：

- 统一展示图标、状态、按钮和通过状态。
- 支持步骤编号。
- 支持硬件异常恢复建议。
- 支持重新检测入口。

当前指纹和 NFC 仍是模拟点击认证。后续接入真实硬件时，不建议把平台通道写进组件内部，而应该通过设备抽象或页面控制器传入认证结果。

## 9. 稳定性能力

智能柜是无人值守设备，稳定性不能只靠 UI 流程。本项目当前已先落地 Flutter 应用层的基础能力。

### 9.1 崩溃日志

文件：

```text
lib/src/core/logging/app_logger.dart
lib/src/core/logging/crash_log_store.dart
```

说明：

- `AppLogger.error()` 会输出错误日志。
- 同时写入 `CrashLogStore`。
- `CrashLogStore` 当前是内存环形队列，便于测试和后续替换。
- 后续生产环境建议扩展为文件持久化，并支持远程上传。

### 9.2 运行健康监测

文件：

```text
lib/src/core/monitoring/runtime_health_monitor.dart
```

能力：

- 记录应用启动时间。
- 记录最近心跳时间。
- 记录运行时长。
- 记录内存样本。
- 记录卡顿风险事件。

`bootstrap()` 启动时会初始化健康监测。

当前健康监测尚未做定时内存采样和远程运行指标上报。AFRR APP 协议在线心跳已由独立的 60 秒定时任务完成，但它不等同于运行时健康样本或真实终端 A102 状态。

### 9.3 硬件异常恢复建议

文件：

```text
lib/src/core/device/hardware_recovery_advice.dart
lib/src/core/device/cabinet_door_guard.dart
```

覆盖硬件：

- 摄像头。
- 指纹模块。
- NFC 模块。
- 柜控板。

覆盖异常：

- 权限拒绝。
- 模块不可用。
- 读取超时。
- 通讯断开。

目标是让现场人员看到“出了什么问题”和“下一步怎么处理”，而不是只看到技术错误字符串。

### 9.4 生产级稳定性待补项

如果要达到真实柜机投产标准，建议继续补：

- Android 前台服务、开机自启和默认 Launcher。
- Device Owner、Device Admin Receiver 与 Lock Task 的设备配置和真机验收。
- 厂商 ROM 白名单。
- 文件持久化崩溃日志。
- 远程运行指标和异常上报；AFRR APP 在线心跳已接入。
- 硬件 Watchdog。
- 断网事件队列和恢复补偿。
- 柜门状态机持久化。

## 10. 硬件接入边界

当前已落地的终端硬件代码集中在 `core/device`：

```text
lib/src/core/device/device_info_service.dart
lib/src/core/device/hardware_status_service.dart
lib/src/core/device/kiosk_device.dart
lib/src/core/device/method_channel_kiosk_device.dart
lib/src/core/device/hardware_recovery_advice.dart
lib/src/core/device/cabinet_door_guard.dart
```

接入约定：

- 终端锁定、Kiosk 和系统设置能力通过 `KioskDevice` 暴露。
- Android 原生能力通过 `MethodChannelKioskDevice` 接入。
- 页面不要直接调用 MethodChannel。
- 硬件失败统一转换成可展示的业务状态和 `HardwareRecoveryAdvice`。
- `CabinetDoorGuard` 当前只负责应用进程内互锁，不能替代真实门磁或平台租约。
- 柜控板或扫码器尚未接入；开始真实对接时再创建带有具体操作契约的接口，不保留没有实现和调用方的空接口。

真实柜控板至少需要覆盖：

- 查询柜控板是否在线。
- 查询柜门状态。
- 打开指定柜门。
- 监听门磁状态变化。
- 上报柜控板异常码。
- 执行柜控板自检。

## 11. 数据流说明

页面获取业务数据的通用方向：

```text
Page / Controller
  -> Domain Repository 接口
  -> Data Repository 实现
  -> Feature DataSource
  -> Fake 数据、HTTP、设备或本地存储边界
```

只有确实需要适配外部 JSON 协议的模块才增加 DTO：

```text
JSON -> DTO -> Domain Entity -> Page
```

首页当前通过 `HomeRemoteDataSource` 和 `core/network/mock_api_data.dart` 模拟 HTTP；普通操作员账号、人脸和指纹登录已统一接入 AFRR TCP A170/B170，NFC、身份资料同步/录入和任务中心仍分别使用 Feature 内的 `FakeOperatorIdentityDataSource` 与 `FakeTaskCenterDataSource`。当前人脸、指纹文件 ID 解析仍是模拟硬件边界；页面不直接处理 JSON、帧校验或 Socket 生命周期。

## 12. 测试说明

测试目录：

```text
test/
  app/
  core/
  features/
  shared/
  widget_test.dart
```

当前测试覆盖：

- 首页渲染且仅显示登录入口。
- 设置弹窗、管理员登录与多语言切换。
- AFRR A170/B170 编解码、APP `logon` 与 60 秒 `heartbeat`、标准与精简 B170 回复、标准 `userLogin`、账号 SHA-1 摘要、人脸/指纹文件 ID JSON、半包/粘包、校验失败、响应映射、业务错误和缺少连接配置。
- 账号识别、资料同步、异常复核和身份资料录入。
- 人脸、指纹、NFC 共享认证组件。
- 按机构加载任务、取件码校验与五类任务步骤。
- 单柜门互锁、机构箱格隔离、开门倒计时展示和无任务安全退出。
- 管理员设备检测、摄像头能力和推流恢复。
- STUM 报文编解码、TCP 登录/检查时序、`AD=2` 拒绝和升级 MethodChannel 映射。
- 本地存储、稳定性监测和硬件异常恢复建议。

常用测试命令：

```bash
flutter test
```

运行身份、任务仓库和柜门安全测试：

```bash
flutter test test/features/identity_verification/operator_identity_flow_test.dart
flutter test test/features/task_center/task_center_repository_test.dart
flutter test test/core/device/cabinet_door_guard_test.dart
flutter test test/features/terminal_upgrade
flutter test test/features/terminal_upgrade/data/datasources/method_channel_terminal_upgrade_device_test.dart
```

运行指定测试用例：

```bash
flutter test test/features/task_center/task_center_page_test.dart --plain-name "无任务倒计时等待柜门关闭后才退出"
```

## 13. 开发规范

### 13.1 修改前

- 先确认要改的是 Presentation、Domain、Data、Shared 还是 Core。
- 涉及行为变化时先补测试。
- 不要在页面里直接写模拟数据。
- 不要在多个业务页面复制同一套认证组件。

### 13.2 修改中

- 页面只依赖 Repository 或共享组件。
- Repository 实现负责 DTO 到 Domain Entity 的映射。
- 共享组件保持业务无关，具体流程由页面控制。
- 多语言文案使用 `l10n.t('key', '中文兜底')`。
- 硬件异常使用 `HardwareRecoveryAdvice` 统一描述。

### 13.3 修改后

至少执行：

```bash
dart format path/to/changed_file.dart
flutter analyze --no-pub
flutter test --no-pub
```

将格式化示例路径替换为本次实际改动文件。如果只改 README、规则或设计文档，可以不执行 Flutter 测试，但必须人工检查内容、路径和命令是否准确。

## 14. 常见开发场景

### 14.1 新增一个页面

建议步骤：

- 在对应 `features/<module>/presentation/pages/` 下新增页面。
- 在 `app/routing/app_routes.dart` 声明路由名称，并在 `app_router.dart` 映射页面。
- 页面文案接入多语言。
- 页面需要数据时，依赖 Domain Repository，由 Data 层提供实现。
- 补 Widget 测试覆盖入口和关键交互。

### 14.2 新增一个接口字段

建议步骤：

- 按当前数据边界修改 `core/network/mock_api_data.dart` 或对应 Feature 的 Fake DataSource。
- 仅在模块存在外部 DTO 时同步修改 DTO；直接返回 Domain Entity 的 Fake DataSource 不补空 DTO。
- 修改 Domain Entity。
- 在 Repository 实现中完成字段映射。
- 页面读取 Entity 字段。
- 补对应测试。

### 14.3 接入真实后端接口

建议步骤：

- 保持 Domain Repository 对 Presentation 层的契约稳定。
- 替换对应 Feature 的 `data/datasources` 实现。
- DTO 贴合真实接口结构，Repository 实现负责转换成 Domain Entity。
- 处理超时、失败、空数据和字段缺失。
- 增加失败兜底 UI 或重试入口。

### 14.4 接入真实柜控板

建议步骤：

- 在 `core/device` 创建描述真实柜控操作的接口和数据模型。
- 通过 MethodChannel 或厂商 Flutter 插件实现 Android 通讯。
- Repository 或业务 Controller 依赖接口，不直接依赖平台实现。
- 页面只展示状态和操作入口。
- 柜控板异常转成 `HardwareRecoveryAdvice` 或业务错误状态。

### 14.5 新增语言

建议步骤：

- 在 `AppLanguage` 中增加语言枚举。
- 在所有 `values/*_localizations.dart` 中补充翻译。
- 在设置弹窗语言选项中增加入口。
- 补语言切换测试。

## 15. 交付检查清单

功能开发完成后建议检查：

- 页面是否能从入口进入。
- 主流程是否能走完。
- 返回首页或下一步跳转是否正确。
- 多语言切换后是否仍可读。
- 小屏幕是否溢出。
- 认证组件样式是否与其他流程一致。
- 模拟数据是否位于 `core/network/mock_api_data.dart` 或对应 Feature DataSource，页面是否仍通过 Repository 访问。
- 是否新增或更新测试。
- `flutter analyze` 是否通过。
- `flutter test` 是否通过。

稳定性相关功能还需要检查：

- 异常是否写入 `AppLogger.error()`。
- 关键失败是否有恢复建议。
- 用户是否知道下一步该做什么。
- 是否需要本地持久化。
- 是否需要远程上报。

## 16. 已知限制

- 普通操作员账号、人脸和指纹登录及 APP 60 秒在线心跳已接入 AFRR TCP A170/B170；现场仍需提供 `AFRR_HOST`、`AFRR_PORT` 和 `AFRR_SHELF_CODE`。当前只支持未加密标记 `0x00`，AES `0x01` 尚未接入密钥和 IV 协商；真实终端 A101/A102 接收链路未接入前，心跳中的终端透传数据按协议发送 `null`。
- 当前没有真实柜控板、门磁和平台租约；开门、关门确认与 30 秒报警仍是 UI/内存演示，`CabinetDoorGuard` 只能保证当前应用进程内互斥。
- 当前人脸和指纹文件 ID 由模拟硬件解析器提供，NFC 仍为点击模拟认证；正式设备需接入真实生物识别模块。
- 监管机构箱格隔离目前由内存绑定和 Repository 校验实现，仍需服务端持久化授权与并发控制。
- 摄像头依赖运行设备权限和硬件环境，测试环境使用 fallback 路径。
- Device Owner、Device Admin Receiver 和 Lock Task 已有代码边界，但仍需目标设备配置与真机验收。
- 崩溃日志当前为内存存储，应用进程退出后不会保留。
- 运行健康监测当前只提供记录和快照能力，尚未做定时采样和远程上传。
- Android 前台服务、开机自启和默认 Launcher 尚未接入。
- 升级服务器已预填 `47.107.40.88:21251`，但功能仍默认关闭；部署方仍需填写真实设备号，通过 15 位 `DEVICE_IMEI` 同时配置 AFRR 身份与 STUM 的 `T01.IM`，通过 `STUM_DP` 配置服务端登记的数据通讯地址，并保证“关于设备”能读取有效唯一设备 ID 作为 CD。启用前仍需用完整生产 `T01` 报文完成现场联调；`AD=2` 分包、升级结果上报、灰度与回滚没有协议定义，当前不支持。
- Android release 当前缺少稳定正式证书，且不会回退到 debug key；未配置 `android/key.properties` 时产物未签名。在正式证书、Device Owner/系统确认路径和目标 RK3566 真机验收完成前，不能作为生产 OTA 发布链路。

## 17. 后续建议路线

建议按以下顺序继续推进：

1. 接入文件持久化日志，保证崩溃后重启仍能查看日志。
2. 在现有 AFRR APP 在线心跳上补充真实终端 A102 透传和设备运行指标上报。
3. 接入 Android 前台服务、开机自启和默认 Launcher，并完成 Device Owner / Lock Task 设备配置与验收。
4. 接入真实柜控板，完成开门、门磁、异常码读取。
5. 接入真实指纹、NFC、扫码器。
6. 将操作员身份认证与任务执行进度升级为可持久化状态机。
7. 增加断网事件队列和网络恢复补偿。
8. 增加远程运维页面，查看日志、心跳、版本、设备状态。
9. 联调现有 URL OTA，补齐正式签名与真机验收；待服务端协议明确后再实现灰度、结果上报和回滚机制。

## 18. 相关文档

- `AGENTS.md`：AI 协作入口和强制业务门禁。
- `.agents/global/README.md`：全局规则索引与当前业务基线。
- `.agents/global/architecture.md`：项目分层、身份会话、任务状态机和柜门安全边界。
- `.agents/global/code-style.md`：代码风格、实现约束和验证要求。
- `ARCHITECTURE.md`：项目架构说明。
- `ROOT_DIRECTORY.md`：根目录说明。
- `打包命令.md`：Android 打包与现场环境备忘。
