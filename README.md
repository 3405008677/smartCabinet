# 智能柜 Flutter 终端

这是一个面向 Android 智能柜终端屏幕的 Flutter 应用。项目当前已经不只是基础工程骨架，而是包含了首页、取件、放件、飞检、管理员入口、多语言、共享身份认证组件、模拟 API 数据层、Repository 分层、稳定性监测和硬件异常恢复提示的一套柜机端业务原型。

项目目标是让智能柜终端在无人值守场景下具备清晰的业务流程、统一的交互体验、可替换的数据边界、可扩展的硬件抽象，以及后续接入真实后端和真实设备时不会大面积重构的代码结构。

## 1. 项目背景

智能柜终端通常部署在固定场所，面向取件人、放件人、飞检人员和管理员使用。相比普通移动 App，智能柜软件更关注以下问题：

- 设备长期运行，不能频繁人工干预。
- 业务流程必须清晰，避免误开柜、漏记录、状态错乱。
- 人脸、指纹、NFC、柜控板、扫码器等硬件可能随时异常，需要给现场人员明确处理方式。
- 后台接口、柜控板协议、摄像头权限和系统保活策略通常会分阶段接入。
- 柜机端需要在断网、重启、崩溃、硬件失败等情况下具备恢复能力。

本项目当前以 Flutter 实现智能柜触屏端交互，并通过模拟数据完成业务闭环。后续可以逐步替换为真实后端接口和真实硬件驱动。

## 2. 当前状态

当前项目已实现以下主线能力：

- 新版智能柜首页。
- 存取件选择页。
- 取件完整流程。
- 放件完整流程。
- 飞检完整流程。
- 管理员登录弹窗。
- 四语言切换。
- 共享人脸、指纹、NFC 认证组件。
- 共享认证进度条和步骤卡片。
- Data Source、DTO、Domain Entity、Repository 分层。
- 模拟后端数据。
- Flutter 层崩溃日志和运行健康监测。
- 摄像头、指纹、NFC、柜控板异常恢复建议。
- Widget 测试和基础设施单元测试。

当前还没有完成的生产级能力：

- 真实后端 HTTP 接口。
- 真实柜控板开门、关门、门磁状态读取。
- 真实指纹、NFC、扫码器驱动。
- Android 前台服务、开机自启、系统白名单和设备所有者模式。
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
dart format lib test
flutter analyze
flutter test
```

建议每次提交前至少执行以上三条命令。

## 5. 业务流程说明

### 5.1 首页

首页负责展示当前智能柜的核心状态和业务入口，包括柜体状态、统计摘要、快捷入口、管理员入口和语言设置入口。

主要入口：

- 存取件入口：进入取件/放件选择页。
- 飞检入口：进入飞检人员认证流程。
- 管理员入口：打开管理员登录弹窗。
- 设置入口：打开设置弹窗，当前包含语言切换。

相关文件：

- `lib/src/features/home/presentation/pages/home_page.dart`
- `lib/src/features/storage/presentation/pages/storage_home_page.dart`

### 5.2 取件流程

取件流程模拟取件人通过多重认证后打开指定柜门取出文件。

流程：

```text
首页 -> 存取件选择 -> 取件安全验证 -> 验证加载 -> 柜门信息 -> 开柜取件
```

认证项：

- 人脸识别。
- 指纹识别。
- NFC 识别。
- 取件码验证。

流程特点：

- 前三项认证复用共享认证组件。
- 取件码为取件流程特有认证项。
- 验证完成后进入加载页，再展示柜门信息。
- 柜门信息和人员/文件信息来自 Repository 返回的模型数据。

相关文件：

- `lib/src/features/pickup/presentation/pages/pickup_verification_page.dart`
- `lib/src/features/pickup/presentation/pages/verification_loading_page.dart`
- `lib/src/features/pickup/presentation/pages/cabinet_door_info_page.dart`
- `lib/src/features/pickup/presentation/pages/open_cabinet_door_page.dart`

### 5.3 放件流程

放件流程模拟放件人员完成身份认证、文件认证后打开柜门放入文件。

流程：

```text
首页 -> 存取件选择 -> 放件人员认证 -> 文件认证 -> 确认开柜 -> 开柜放件 -> 放件成功
```

认证项：

- 人脸识别。
- 指纹识别。
- NFC 识别。
- 文件信息确认。

流程特点：

- 人员认证和飞检、取件共用同一套认证组件。
- 文件认证页当前使用模拟 API 返回的文件编号和文件名称。
- 开柜确认、放件完成均为 UI 和模拟状态流程，后续可接入柜控板接口。

相关文件：

- `lib/src/features/dropoff/presentation/pages/dropoff_person_verification_page.dart`
- `lib/src/features/dropoff/presentation/pages/dropoff_file_verification_page.dart`
- `lib/src/features/dropoff/presentation/pages/dropoff_confirm_opening_page.dart`
- `lib/src/features/dropoff/presentation/pages/dropoff_open_cabinet_page.dart`
- `lib/src/features/dropoff/presentation/pages/dropoff_success_page.dart`

### 5.4 飞检流程

飞检流程用于后台随机指定柜门后，由飞检人员完成身份认证并逐个检查柜门。

流程：

```text
首页 -> 飞检人员认证 -> 飞检柜门任务 -> 单柜开柜 -> 放回校验 -> 标记完成
```

流程规则：

- 飞检人员先完成人脸、指纹、NFC 认证。
- 认证完成后展示待飞检柜门任务列表。
- 单个柜门打开时，其他柜门不可操作。
- 放回并确认后，当前柜门标记为已完成。
- 全部任务完成后流程结束。

相关文件：

- `lib/src/features/flight_inspection/presentation/pages/flight_inspection_verification_page.dart`
- `lib/src/features/flight_inspection/presentation/pages/flight_inspection_task_page.dart`

### 5.5 管理员入口

管理员入口当前以弹窗形式展示登录界面和数字键盘布局。

覆盖点：

- 紧凑屏幕布局可用。
- 数字键盘在弹窗内不溢出。
- 多语言切换后相关文案更新。

相关文件：

- `lib/src/features/home/presentation/pages/home_page.dart`
- `test/widget_test.dart`

## 6. 架构说明

两个 Flutter 项目统一采用轻量 Feature-first 架构：

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

- `camera`、`device`、`mqtt`：智能柜专属硬件和通讯能力。
- `config`、`constants`：应用配置与常量。
- `errors`：异常和失败对象。
- `logging`、`monitoring`：日志、崩溃记录和运行健康监测。
- `network`：网络客户端、结果抽象和当前模拟数据。
- `storage`：本地存储抽象。
- `utils`：通用工具。

### 6.3 features

`features` 按业务模块聚合数据访问、业务模型和界面，当前包括 `home`、`pickup`、`dropoff`、`flight_inspection`、`admin`、`identity_verification` 和 `storage`。

标准数据流为：

```text
presentation -> domain repository -> data repository -> data source
```

- `data/datasources`：调用 HTTP、本地数据或设备接口。
- `data/dtos`：贴近接口字段的响应对象。
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
final text = context.l10n.t('pickupTitle', '取件');
```

约定：

- 页面里保留中文兜底，避免 key 缺失时页面显示空白。
- 多语言 key 使用模块前缀，便于查找。
- 多语言字典按模块拆分，存放在 `lib/src/app/localization/values/`。
- 新增页面固定文案时，应同步补充语言切换测试。

字典文件：

- `home_localizations.dart`
- `foundation_localizations.dart`
- `pickup_localizations.dart`
- `dropoff_localizations.dart`
- `inspection_localizations.dart`
- `admin_localizations.dart`

## 8. 共享身份认证组件

项目已经将人脸、指纹、NFC 认证抽成共享组件，避免取件、放件、飞检各写一套。

### 8.1 人脸识别

组件：

```text
lib/src/shared/widgets/identity_verification/face_verification_card.dart
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
lib/src/shared/widgets/identity_verification/sensor_verification_card.dart
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

- Android 前台服务。
- 开机自启。
- 默认 Launcher。
- Lock Task / Kiosk 模式。
- 设备所有者 Device Owner。
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
```

接入约定：

- 终端锁定、Kiosk 和系统设置能力通过 `KioskDevice` 暴露。
- Android 原生能力通过 `MethodChannelKioskDevice` 接入。
- 页面不要直接调用 MethodChannel。
- 硬件失败统一转换成可展示的业务状态和 `HardwareRecoveryAdvice`。
- 柜控板或扫码器尚未接入；开始真实对接时再创建带有具体操作契约的接口，不保留没有实现和调用方的空接口。

真实柜控板至少需要覆盖：

- 查询柜控板是否在线。
- 查询柜门状态。
- 打开指定柜门。
- 监听门磁状态变化。
- 上报柜控板异常码。
- 执行柜控板自检。

## 11. 数据流说明

页面获取数据的标准路径：

```text
Page / Controller
  -> Domain Repository 接口
  -> Data Repository 实现
  -> Remote Data Source
  -> HttpClient / FakeHttpClient
```

接口返回后的映射路径：

```text
JSON -> DTO -> Domain Entity -> Page
```

例如，首页由 `HomeRepositoryImpl` 实现 `HomeRepository`，通过 `HomeRemoteDataSource` 获取数据，并向页面返回 `HomeData`。取件、放件、飞检和管理员模块遵循相同规则。

接入真实接口时，优先替换对应模块 `data/datasources` 的实现，并在 DTO 和仓库实现中消化字段差异，尽量不修改页面。

## 12. 测试说明

测试目录：

```text
test/
  core/
  features/
  shared/
  widget_test.dart
```

当前测试覆盖：

- 首页渲染。
- 设置弹窗和语言切换。
- 旧入口保留跳转。
- 取件认证卡片统一头部。
- 取件页英文文案。
- 放件卡片外壳一致性。
- 放件完整关键流程。
- 飞检锁柜流程。
- 非首页页面多语言。
- 管理员弹窗布局。
- 人脸预览布局。
- 共享身份认证组件。
- 崩溃日志存储。
- 运行健康监测。
- 硬件异常恢复建议。

常用测试命令：

```bash
flutter test
```

运行单个测试文件：

```bash
flutter test test/shared/identity_verification_test.dart
```

运行指定测试用例：

```bash
flutter test test/widget_test.dart --plain-name "dropoff flow completes with simulated verification"
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
dart format lib test
flutter analyze
flutter test
```

如果只改 README、设计文档或验收文档，可以不执行 Flutter 测试，但需要人工检查文档内容是否准确。

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

- 修改 `core/network/mock_api_data.dart` 中的模拟数据（仍使用模拟接口时）。
- 修改对应 Feature 的 DTO。
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
- 模拟数据是否集中在 `core/network/mock_api_data.dart`，数据访问是否位于对应 Feature 的 Data 层。
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

- 当前没有真实后端，业务数据来自模拟 API。
- 当前没有真实柜控板，开柜和门状态为 UI 流程模拟。
- 当前指纹和 NFC 为点击模拟认证。
- 摄像头依赖运行设备权限和硬件环境，测试环境使用 fallback 路径。
- 崩溃日志当前为内存存储，应用进程退出后不会保留。
- 运行健康监测当前只提供记录和快照能力，尚未做定时采样和远程上传。
- Android 系统级保活尚未接入。

## 17. 后续建议路线

建议按以下顺序继续推进：

1. 接入文件持久化日志，保证崩溃后重启仍能查看日志。
2. 增加设备心跳上报接口，把运行状态同步到后台。
3. 接入 Android 前台服务、开机自启、默认 Launcher 和 Kiosk 模式。
4. 接入真实柜控板，完成开门、门磁、异常码读取。
5. 接入真实指纹、NFC、扫码器。
6. 将取件、放件、飞检关键流程升级为可持久化状态机。
7. 增加断网事件队列和网络恢复补偿。
8. 增加远程运维页面，查看日志、心跳、版本、设备状态。
9. 增加 OTA 升级和版本回滚机制。

## 18. 相关文档

- `ARCHITECTURE.md`：项目架构说明。
- `lib/src/app/localization/localization_readme.md`：多语言说明。
- `.openCode/PM/设计/`：设计记录。
- `.openCode/PM/测试/`：测试记录。
- `.openCode/PM/验收/`：验收记录。
- `.openCode/历史记录/沟通日志/`：沟通日志。
- `.openCode/会话状态/`：当前会话状态和任务进度。
