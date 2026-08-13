# Smart Cabinet Flutter 架构

## 统一标准

`smartCabinet` 与 `smartCabinet-Phone` 使用同一套 Feature-first 架构、snake_case 命名、Riverpod 依赖入口和 Flutter 原生路由封装。两个项目只在业务 Feature 和终端基础能力上不同。

```text
lib/
  main.dart
  src/
    app/                 # 应用装配、启动、路由、主题、国际化、应用外壳
    core/                # 网络、存储、日志、异常、配置及平台能力
    shared/              # 跨 Feature 复用的纯 UI、模型和扩展
    features/
      <feature>/
        data/            # DataSource、DTO、Repository 实现
        domain/          # Entity、Repository 接口、UseCase
        presentation/    # Controller、Page、Widget
```

## 当前业务模块

- `home`：终端首页、柜体概览和登录入口。
- `identity_verification`：账号登录、人脸/指纹/NFC 认证与身份资料录入。
- `task_center`：任务工作台，以及存证、取证、借证、还证和箱格级盘点任务。普通任务按证件推进；盘点由平台下发抽中箱格，终端对每个抽中箱格整箱核对。
- `admin`：管理员认证、设备检测、通讯日志与控制台。
- `terminal_upgrade`：ZRD STUM 登录/升级检查、URL 升级包校验、管理员确认与 Android 安装状态。

## 依赖方向

```text
app          -> features + core + shared
presentation -> 同模块的 domain/data + shared + core
data         -> domain + core
domain       -> Dart 基础能力
core         -X-> features
```

`domain` 不依赖 Flutter UI、具体网络客户端或本地存储实现。业务页面不得直接解析 DTO。一个业务模块不得直接引用另一个模块的 `data`；跨 Feature 协作通过路由参数、领域对象、可复用能力的公开 Widget 或应用装配完成。

当前采用轻量分层：简单页面可以调用同模块的 Repository 实现；当状态需要跨页面共享、需要替换实现或测试注入时，再提升为 Domain 接口和 Riverpod Provider，避免为小功能制造空壳代码。

## Riverpod 规则

Riverpod 承担需要共享或替换的依赖注入和状态管理。应用级 Provider 可放在 `app/app_dependencies.dart`，仅一个 Feature 使用的 Provider 放在该 Feature 附近；Widget 私有瞬时状态继续使用 `StatefulWidget`。

## 命名规则

- 文件和目录使用小写 `snake_case`。
- 禁止使用无业务含义的 `index.dart`。
- 页面使用 `_page.dart`，共享控件使用 `_card.dart`、`_dialog.dart`、`_tile.dart` 等职责后缀。
- DTO 使用 `_dto.dart`，Repository 实现使用 `_repository_impl.dart`。
- Repository 接口不添加 `I` 前缀。
- 页面之间使用普通 `import`，不使用 `part/part of` 共享私有实现。

## 智能柜专属基础设施

`core/camera`、`core/device`、`core/mqtt` 和 `core/monitoring` 是柜机端专属能力。Phone 项目不创建这些空目录，但遵循相同的 `core` 边界。

`core/logging/communication_log_store.dart` 是独立于 `AppLogger`/崩溃日志的进程内结构化通讯队列。Dart 的 AFRR、STUM、MQTT、HTTP 和平台通道在业务协议边界写入已脱敏记录；Android 通过 `smart_cabinet/communication_log` 快照通道和对应 EventChannel 汇入 RTSP 控制、18080 HTTP、错误上报与 PackageInstaller 回调。通讯日志不得落入账号、凭据、生物资料、人员资料、设备唯一标识、本地路径、URL 查询参数或视频/图片/安装包二进制内容。

`core/device/app_version_service.dart` 通过现有 `smart_cabinet/upgrade` 通道读取 Android `PackageManager` 报告的已安装 APK `versionName/versionCode`，并按应用进程缓存。全局页脚和 `terminal_upgrade` 必须共用该服务，不得分别维护显示版本常量；持久构建版本仍只在 `pubspec.yaml` 的 `version` 字段维护。

可复用的 TCP 协议请求能力位于 `core/network/protocol`，统一提供连接代际隔离、增量拆帧适配、串行写入、请求匹配、超时、服务端主动消息和断线清理。具体协议的报文格式、字段校验和命令语义必须留在对应 Feature；STUM 的编解码器位于 `features/terminal_upgrade/data/protocol`，后续协议不得把业务命令反向放入 `core`。

普通操作员账号、人脸和指纹登录统一使用 `OperatorLoginRequest` 与 `OperatorProtocolLoginStrategy`，并全部提交给 `OperatorAfrrLoginDataSource`。AFRR Feature 协议层负责 A170/B170、BCD 时间、KLV、流水号、长度、异或校验、转义、半包/粘包和重发；通用连接生命周期继续复用 `core/network/protocol`。应用启动先完成 APP `logon`，同一长连接之后每 60 秒发送 `heartbeat`；心跳连续失败时废弃 Socket，延时重连并保证新连接首帧仍为 `logon`。真实终端 A101/A102 接收边界未接入时，心跳透传数据固定为 `null`，不得构造终端在线数据。三种操作员登录方式分别使用 `logway = 1/2/3`，人脸和指纹先从可替换的本机识别边界取得文件 ID。当前硬件文件 ID 解析仍为模拟边界，且 `0x01` AES 尚未接入密钥和 IV 协商；页面和任务门禁不依赖具体帧规则。

终端升级使用独立的 `smart_cabinet/upgrade` MethodChannel，抽象与实现位于 `features/terminal_upgrade/data/datasources`。Dart 侧负责 STUM 协议、仅当前 T03 请求窗口的 S03 边界、流式下载、MD5、取消检查和流程状态；窗口关闭后只允许对已接收 offer 的精确重传幂等补发 ACK。`T01.IM` 和 `T01.DP` 由唯一生产 Provider 分别从 `AppConfig.current.afrrDeviceImei`（15 位 `DEVICE_IMEI`，与 AFRR 共用）和 `terminalUpgradeDataProtocolIp`（`STUM_DP`）注入，其中 DP 严格校验为一个或多个逗号分隔的 IPv4 地址；`T01.CD` 延迟读取“关于设备”同源的 Android `Settings.Secure.ANDROID_ID`。三者均不允许升级页面编辑，也不在本地升级设置中保存第二份。`T03.VE` 由 Android `versionName` 和构建批次 `STUM_VERSION_DATE` 形成 `SL_V{version}_{yyyyMMdd}`；Android 侧只剥离请求的这一外壳或服务端 `S03.VE=SL_APP_V{version}` 外壳后校验 APK `versionName`，并继续校验包名、签名证书链和递增 `versionCode`，再提交 `PackageInstaller`；页面不得绕过这两层校验。当前只支持协议定义完整的 `DT=1` URL 模式，`AD=2` 因缺少分包格式、顺序、重传和完整性定义而明确拒绝。升级监控默认关闭；后台发现合法 offer 后只显示脱敏的管理员处理入口，不能直接触发下载或安装。安装必须经过绑定具体 offer 的管理员确认，并原子取得 `CabinetDoorGuard` 维护租约以阻止新的开门请求；原生活动安装的租约在应用首帧前恢复，停止、重配或释放会取消未跨过 commit 的操作。该进程内租约仍不能替代真实门磁、平台任务租约或现场 watchdog。

## 任务中心安全边界

- 所有任务入口都要求同一账号完成人脸、指纹与 NFC 三项身份因子，Repository 是最终业务门禁。
- 五类任务使用 Domain 中的完整固定步骤序列；Repository 拒绝缺步、增步、乱序或非连续完成状态。
- 柜门操作必须先复核任务、机构、证件和精确门号，再使用本次开门周期唯一操作 ID 申请应用级单门互锁；超时只报警，不能自动释放互锁。开门响应异常先对账，无法确认时人工关门并安全回退后再释放。
- 通用 `completeStep` 不能推进取件码、飞检码、开门、关门或箱格盘点等受保护步骤，这些动作必须使用携带业务数据和门号的专用 Repository 方法。
- 多监管机构共享柜体时，箱格采用机构独占绑定，不因当前空闲而跨机构复用。
- 盘点按箱格聚合：比例按箱格计算；指定证件必须存在并扩展到其所在整箱；全部预期证件必须属于计划箱格。未抽中箱格不计入完成条件，未扫描的预期证件只能在明确关门时标记为缺失。
- 盘点正常件不要求逐份拍照；真实平台可要求开关箱全景，并在缺失、溢余等异常时补拍凭证。

当前任务数据、RFID、OCR、飞检码和柜门反馈仍是可替换的演示边界。真实平台校验、硬件门磁以及借出记录闭环接入后，继续保持上述 Domain/Repository 契约，页面不得直接绕过。

## 测试

`test/` 按 `app/core/shared/features` 映射源码。提交前执行：

```powershell
dart format path/to/changed_file.dart
flutter analyze --no-pub
flutter test --no-pub
```

将格式化示例替换为本次实际修改的 Dart 文件；优先运行相关测试，跨模块或高风险变更再运行完整测试。
