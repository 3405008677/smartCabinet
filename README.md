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
- 人脸、指纹、NFC 三项全部完成的身份验证。
- 可通过 `AppConfig.current.isTestMode` 控制账号登录测试旁路；当前测试配置为 `true`，账号密码正确后直接进入任务中心，人脸登录仍执行三项认证。正式部署前必须改为 `false`。
- 本机身份资料同步、缺失资料录入和异常复核报备。
- 按监管机构隔离的任务工作台。
- 存证、取证、借证、还证和盘点五类任务的统一入口、类型区分与顺序步骤演示。
- 应用进程内的全局单柜门互锁，以及演示数据中的监管机构专属箱格校验。
- 管理员登录、身份校验与设备控制台。
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
- 远程心跳上报和远程运维平台。
- OTA 升级和版本灰度。

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

### 4.4 常用验证命令

```bash
dart format path/to/changed_file.dart
flutter analyze --no-pub
flutter test --no-pub
```

将示例路径替换为本次实际修改的 Dart 文件；行为变化优先运行相关测试，跨模块或高风险改动再运行完整测试。

## 5. 业务流程说明

### 5.1 首页与登录入口

首页只展示柜体状态、统计摘要、静态背景区和登录入口，不直接发起具体业务任务。操作员必须先通过“人脸登录”或“账号登录”建立身份，再根据账号所属监管机构进入任务工作台。版本号连续点击仍可打开设置与管理员入口。

相关文件：

- `lib/src/features/home/presentation/pages/home_page.dart`
- `lib/src/features/home/presentation/widgets/home_dashboard.dart`
- `lib/src/features/home/presentation/widgets/settings_dialog.dart`

### 5.2 操作员身份流程

“人脸登录”入口进入统一身份校验页，首个成功的人脸、指纹或 NFC 因子负责识别账号；也可以先用账号密码确认账号。账号密码本身不计入身份因子，普通任务要求同一账号完成人脸、指纹与 NFC 三项认证。

测试阶段例外：`lib/src/core/config/app_config.dart` 中 `AppConfig.current.isTestMode` 为 `true` 时，账号密码登录成功会为本次测试会话建立三项认证旁路并直接进入任务中心。该开关不影响人脸登录，正式环境必须设为 `false`。

管理员与普通操作员身份校验页共用同一套页面间距、标题、进度和三栏卡片尺寸。测试模式下，人脸卡片明确显示“模拟认证”，不启动摄像头、不提交或等待后端；正式模式仍保留真实摄像头与身份仓库校验路径。

- 资料正常：人脸、指纹、NFC 三项认证全部完成后才能进入任务工作台。
- 本机无资料但平台资料完整：先同步到本机，再完成人脸、指纹与 NFC 三项认证。
- 缺少人脸或指纹：只录入缺失项；单项失败留在录入页重试，全部录入成功后 3 秒自动或手动返回首页重新登录。
- 本机资料异常：完成人脸、指纹与 NFC 三项复核；三项都已尝试后仍有异常时，先向平台报备，再重录异常的人脸或指纹资料。

当前内存演示账号用于人工验收不同分支：

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

管理员从设置弹窗进入账号登录，登录通过后继续完成人脸、指纹和 NFC 三项身份校验，再进入设备控制台。控制台包含相机能力、推流状态与自动检测等设备运维功能。

相关文件：

- `lib/src/features/admin/presentation/widgets/admin_login_dialog.dart`
- `lib/src/features/admin/presentation/pages/admin_verification_page.dart`
- `lib/src/features/admin/presentation/pages/admin_console_page.dart`

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
- `device`：柜机平台抽象、MethodChannel 与应用级柜门互锁。
- `logging`、`monitoring`：日志、崩溃记录和运行健康监测。
- `mqtt`：MQTT 连接、消息与设备命令。
- `network`：网络客户端、结果抽象和模拟 API 数据。
- `storage`：本地存储抽象与实现。

### 6.3 features

`features` 按业务模块聚合数据访问、业务模型和界面，当前包括 `home`、`identity_verification`、`task_center` 和 `admin`。

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

当前还没有做定时器自动采样和远程上报，后续可以在应用启动后增加定时心跳任务。

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
- 远程心跳和异常上报。
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

首页当前通过 `HomeRemoteDataSource` 和 `core/network/mock_api_data.dart` 模拟 HTTP；身份认证和任务中心分别使用 Feature 内的 `FakeOperatorIdentityDataSource` 与 `FakeTaskCenterDataSource`，直接返回 Domain Entity。接入真实接口时优先替换对应 DataSource，并由 Repository 保持页面所依赖的领域契约稳定。

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
- 账号识别、资料同步、异常复核和身份资料录入。
- 人脸、指纹、NFC 共享认证组件。
- 按机构加载任务、取件码校验与五类任务步骤。
- 单柜门互锁、机构箱格隔离、开门倒计时展示和无任务安全退出。
- 管理员设备检测、摄像头能力和推流恢复。
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

- 当前没有真实后端，首页使用模拟 API，身份认证和任务中心使用 Feature 内存 Fake DataSource。
- 当前没有真实柜控板、门磁和平台租约；开门、关门确认与 30 秒报警仍是 UI/内存演示，`CabinetDoorGuard` 只能保证当前应用进程内互斥。
- 当前指纹和 NFC 为点击模拟认证；人脸照片只模拟提交后端校验。
- 监管机构箱格隔离目前由内存绑定和 Repository 校验实现，仍需服务端持久化授权与并发控制。
- 摄像头依赖运行设备权限和硬件环境，测试环境使用 fallback 路径。
- Device Owner、Device Admin Receiver 和 Lock Task 已有代码边界，但仍需目标设备配置与真机验收。
- 崩溃日志当前为内存存储，应用进程退出后不会保留。
- 运行健康监测当前只提供记录和快照能力，尚未做定时采样和远程上传。
- Android 前台服务、开机自启和默认 Launcher 尚未接入。

## 17. 后续建议路线

建议按以下顺序继续推进：

1. 接入文件持久化日志，保证崩溃后重启仍能查看日志。
2. 增加设备心跳上报接口，把运行状态同步到后台。
3. 接入 Android 前台服务、开机自启和默认 Launcher，并完成 Device Owner / Lock Task 设备配置与验收。
4. 接入真实柜控板，完成开门、门磁、异常码读取。
5. 接入真实指纹、NFC、扫码器。
6. 将操作员身份认证与任务执行进度升级为可持久化状态机。
7. 增加断网事件队列和网络恢复补偿。
8. 增加远程运维页面，查看日志、心跳、版本、设备状态。
9. 增加 OTA 升级和版本回滚机制。

## 18. 相关文档

- `AGENTS.md`：AI 协作入口和强制业务门禁。
- `.agents/global/README.md`：全局规则索引与当前业务基线。
- `.agents/global/architecture.md`：项目分层、身份会话、任务状态机和柜门安全边界。
- `.agents/global/code-style.md`：代码风格、实现约束和验证要求。
- `ARCHITECTURE.md`：项目架构说明。
- `ROOT_DIRECTORY.md`：根目录说明。
- `打包命令.md`：Android 打包与现场环境备忘。
