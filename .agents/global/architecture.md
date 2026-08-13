# 架构规则

## 核心原则

本项目是 `smartCabinet` 智能柜终端应用，主要技术形态为 `Flutter + Dart + Material 3 + Riverpod`。主要部署目标是 Android 智能柜触屏设备；Android 平台层使用 Kotlin 与 Gradle Kotlin DSL，摄像头推流链路涉及 Camera2、MediaCodec、RKMPP、RTSP/TCP 和 C++ JNI。`web/` 是 Flutter 平台目录，不代表本项目采用 Web 前端架构。

正式项目结构优先遵循以下顶层目录：

```text
smartCabinet/
├── .agents/                 # AI 协作规则
├── android/                 # Android 平台工程、Kotlin、JNI 与原生库
├── assets/                  # Flutter 静态资源
├── lib/                     # Flutter/Dart 主源码
├── test/                    # 单元测试与 Widget 测试
├── tool/                    # 自动版本递增、发布构建与工程审计工具
├── web/                     # Flutter Web 平台入口
├── AGENTS.md                # AI 协作入口
├── analysis_options.yaml    # Dart analyzer 与 lint 配置
├── ARCHITECTURE.md          # 项目架构说明
├── pubspec.yaml             # SDK、依赖与资源声明
├── pubspec.lock             # 依赖锁定文件
├── README.md                # 项目总说明
├── ROOT_DIRECTORY.md        # 根目录说明
└── 打包命令.md               # Android 打包与现场链路备忘
```

以下内容可以存在于工作区，但不作为源码架构依据，也不应手动编辑：

```text
.dart_tool/                  # Dart/Flutter 工具缓存
build/                       # Flutter 构建产物与缓存
android/build/               # Android 构建产物
android/.gradle/             # Gradle 本地缓存
android/.kotlin/             # Kotlin 本地缓存
.flutter-plugins-dependencies # Flutter 自动生成的插件映射
.idea/                       # IDE 本地配置
```

`.metadata` 由 Flutter 工具维护。除非用户明确要求执行平台迁移或 Flutter 工程升级，不手动改写。

当说明文档与当前文件树、`pubspec.yaml`、Gradle 配置或实际代码冲突时，以当前源码和配置为事实依据；不要复制已经不存在的路径或平台命令。只有任务范围包含文档维护时，才同步修正文档。

## `lib/` 分层

Flutter 主源码遵循现有轻量 Feature-first 结构：

```text
lib/
├── main.dart
└── src/
    ├── app/                 # 应用装配、启动、路由、主题、多语言和全局覆盖层
    ├── core/                # 跨业务基础设施与设备能力
    ├── features/            # 按业务域组织的功能模块
    └── shared/              # 跨业务复用且不属于独立业务域的通用 UI
```

依赖方向保持为：

```text
app          -> features + core + shared
presentation -> 同模块的 domain/data + shared + core
data         -> domain + core
domain       -> Dart 基础能力
core         -X-> features
```

以上是新增和重构代码需要收敛到的目标依赖方向。当前 `features/admin/domain/entities/admin.dart` 仍直接使用 `core/device/hardware_status_service.dart` 中的设备状态类型，这是既有兼容例外，不作为新代码范式；无关任务不顺手重构它，相关任务则优先通过中立领域对象或映射层消除耦合。

1. `app/` 负责组装，不承载具体业务规则。
2. `core/` 不依赖任何 `features/` 模块。
3. 一个 Feature 不直接引用另一个 Feature 的 `data/`；跨 Feature 复用通过领域对象、公开 Widget、路由参数或应用装配完成。
4. `domain/` 的新增依赖不指向 Flutter UI、具体网络客户端、本地存储实现或 Android 平台实现。
5. 页面不直接解析 DTO；DTO 到 Domain Entity 的转换由 Repository 实现负责。
6. 当前允许简单页面直接使用同模块的 Repository 实现。需要跨页面共享、替换实现或测试注入时，再通过 Riverpod 或应用装配提升依赖边界。

## `app/` 规则

`lib/src/app/` 当前包含以下职责：

```text
app/
├── bootstrap/              # Flutter 初始化、异常捕获与启动入口
├── localization/           # 多语言入口和按模块拆分的字典
├── overlays/               # 应用级覆盖层
├── routing/                # 路由名称与页面映射
├── shell/                  # 柜机页面统一外壳
├── startup/                # 启动任务、失败界面和启动媒体
├── theme/                  # Material 主题与视觉 token
└── app.dart                # MaterialApp 根装配
```

1. `lib/main.dart` 保持轻量，启动逻辑统一进入 `bootstrap()`。
2. 全局异常捕获、Riverpod 容器、启动任务和首帧前后时序维护在 `bootstrap/` 与 `startup/`。
3. 路由名称维护在 `app_routes.dart`，页面映射维护在 `app_router.dart`；不要把全局路由分支散落到业务页面。
4. 统一主题和页面外壳优先复用 `AppTheme` 与 `TerminalShell`，不要在单个页面重新建立全局视觉体系。
5. 应用级覆盖层放在 `overlays/`，不要在多个页面复制全局错误或状态监听逻辑。

## `features/` 规则

当前业务模块如下：

```text
features/
├── admin/                  # 管理员账号、三因子校验、设备检测、通讯日志与控制台
├── home/                   # 公开只读首页、柜体概览与登录入口
├── identity_verification/  # 操作员账号、三项全验、资料同步/录入/异常恢复
├── task_center/            # 认证后任务工作台与五类智能柜任务
└── terminal_upgrade/       # STUM 升级检查、URL 包校验与管理员安装流程
```

需要分层的 Feature 优先遵循：

```text
<feature>/
├── data/
│   ├── datasources/        # HTTP、模拟接口、本地或设备数据访问
│   ├── dtos/               # 贴近外部数据格式的对象
│   └── repositories/       # Repository 实现与 DTO/Entity 映射
├── domain/
│   ├── entities/           # 业务实体
│   └── repositories/       # 数据访问契约
└── presentation/
    ├── pages/              # 页面与流程编排
    └── widgets/            # 当前业务域内复用的组件
```

1. 目录按实际需要创建，不为小功能补齐空的 `data/domain/presentation`。
2. 模拟数据和接口行为放在数据层，不直接写进 Widget。
3. 页面专属组件留在对应 Feature；确有跨业务复用价值时，再提升到独立 Feature 或 `shared/`。
4. `identity_verification` 拥有操作员账号、身份资料状态和登录流程；管理员仅复用通用三因子状态与展示组件，不与操作员会话或任务权限合并。
5. 修改流程状态或接口字段时，同步检查 DTO、Entity、Repository、页面映射和相关测试。

## 核心业务流与安全边界

当前公开业务主线为：

```text
home
  -> 首个身份因子识别账号 / 账号密码确认账号
  -> 资料同步、缺失录入或异常复核
  -> 人脸、指纹、NFC 三项身份因子全部通过
  -> task_center
  -> task_execution
  -> task_center / 安全退出回 home
```

### 身份会话

普通账号、人脸和指纹认证由 `OperatorAfrrLoginDataSource` 通过 AFRR TCP A170/B170 完成。账号密码使用 40 位大写 SHA-1，三种方式分别使用 `logway = 1/2/3`，操作员登录固定使用 `func=userLogin` 且只认 `rst=9` 成功，不支持旧版 `cmd=login`；协议层负责 BCD 时间、KLV、流水号、长度、异或校验、转义、半包/粘包和最多两次重发。APP `logon` 成功后同一长连接每 60 秒发送 `func=heartbeat` 并等待 B170 `rst=9`；连续失败时废弃当前 Socket，延时重连并保证 `logon` 仍是新连接首帧。真实终端 A101/A102 接收链路未接入时，heartbeat 的终端透传 `data` 必须为 `null`。B170 同时识别文档标准的两字节原流水号加 JSON 回复，以及现场 APP `logon` 使用的五字节原指令码、原流水号和结果码精简回复；`userLogin` 必须取得人员资料 JSON。B170 人员资料映射为 `OperatorAccount` 和不含 HTTP token 的 `OperatorLoginSession`，退出回首页前清除，不进入 Widget 参数或日志。当前只支持未加密标记 `0x00`，人脸和指纹文件 ID 解析仍是可替换的模拟硬件边界。

1. 正式模式下账号密码只用于确定 `OperatorAccount`，不能加入 `verifiedFactors`，也不能直接授予任务权限。仅当 `AppConfig.current.isTestMode == true` 时，账号登录协调器可为测试会话补齐三项 `verifiedFactors` 并直接进入任务中心；人脸登录不使用该旁路，正式部署前必须关闭。该测试开关不跳过 AFRR 登录，也不得在协议失败时回退 Fake 账号。测试模式下进入身份校验页时，人脸步骤使用明确的模拟结果，不启动摄像头或等待身份后端；正式模式继续走摄像头和 Repository。
2. 普通 `ready`、刚同步的 `synced` 与异常复核场景都要求人脸、指纹、NFC 三项认证全部完成；`verifiedFactors` 使用 `Set<IdentityFactor>` 表达不同因子，重复同一因子不能累计。
3. 服务端资料同步到本机后的 `synced` 场景，以及本机资料 `abnormal` 复核场景，同样必须完成人脸、指纹与 NFC 三项认证。
4. 缺失资料仅录入人脸和指纹。单项失败停留在录入页并允许重试；所有请求项成功后，3 秒自动或手动清空当前流程并回首页重新登录。
5. 异常复核必须等待全部必选因子都完成尝试；只要结果仍未满足全部必选项，就先报备平台，再重录异常或缺失项。
6. `AppRouter` 负责页面入口参数校验，身份 Repository 和任务 Repository 继续承担业务校验；路由成功不代表已经获得任务权限。

### 任务状态机与机构隔离

1. 存证、取证、借证、还证和盘点统一属于 `task_center`，每类任务的完整步骤序列是 Domain 契约；缺步、增步、重排或非连续完成状态必须在 Repository 拒绝。状态只能由 `TaskCenterRepository` 按业务顺序推进，页面不得直接篡改步骤、证件、箱格或任务完成状态。
2. 任务 Repository 的每个公开读取和变更入口都重新校验人脸、指纹与 NFC 三项身份因子，并校验 `account.organizationId == task.organizationId`；不能信任列表过滤、路由参数或页面缓存。
3. `InstitutionSlotBinding` 表达当前柜体箱格的监管机构独占绑定。分箱、授权箱格和开门前必须保证账号机构、任务机构与箱格机构一致，其他机构不能因箱格当前空闲而复用。
4. 取件码和飞检码使用各自专用校验入口。空值、错误码、未配置、任务类型不匹配或步骤不匹配均不得推进状态，通用 `completeStep` 不能绕过专用校验。
5. 非盘点多证件任务按业务证件推进，但同一箱格的连续取出动作应合并为一次开门；进入下一箱格时清理上一箱格绑定并重新完成门号授权。只有全部证件和步骤完成后才能结束整单。
6. 盘点按箱格推进：同一箱格中的全部预期证件共用一次开门和一份箱格结果，不能复用普通 `currentItem` 逻辑将同箱证件拆成多次开门。

### 五类任务目标流程

以下流程是业务实现契约，不代表真实设备和平台接口已经接入：

1. **存证**：绑定 RFID -> 拍摄正反面 -> OCR 识别并人工确认 -> 平台分配机构专属箱格 -> 开门 -> 限时存入 -> 匹配柜门关门 -> 上报存入结果。
2. **取证**：专用入口校验取件码 -> 展示可取列表 -> 确认授权箱格 -> 开门 -> 限时取出并扫描 RFID -> 同箱待取证件处理完毕 -> 关门并上报。
3. **借证**：物理步骤与取证一致，但任务类型、借出人、借出时间、应还时间和待归还状态必须独立保存；没有平台借出记录和后续归还核销时，不得标记为业务闭环完成。
4. **还证**：展示待还列表 -> RFID 匹配借出记录 -> 按平台要求拍摄正反面并 OCR 核对 -> 确认目标箱格 -> 开门 -> 限时放回 -> 关门上报 -> 平台核销借出记录。
5. **盘点**：专用入口校验飞检码 -> 展示箱格计划 -> 打开一个待盘箱格 -> 取出箱内全部证件逐一扫描 RFID -> 确认放回 -> 关门形成该箱格结果 -> 继续下一箱格。
6. 模拟 DataSource、模拟扫码、模拟 OCR 和 UI 关门确认只用于验证状态机与失败路径；不得将其描述为真实平台收件、借出记录、物理门磁或 OCR 结论。

### 盘点箱格模型

1. 抽盘计划由平台生成并固定到任务版本，终端不本地随机抽箱。终端仍须校验计划集合、比例、验证码步骤、活动箱格与绑定的一致性，并保证全部预期证件属于计划箱格。按比例抽盘时按当前机构有权盘点的箱格数量计算；指定证件必须逐个唯一存在，映射到所在箱格并去重后，再把这些箱格的全部预期证件纳入盘点。
2. 为支持柜体全景，计划可以包含未抽中箱格，但未抽中或无权访问的箱格只能显示灰色“无需盘点”，不得返回或展示其他机构的证件数量与明细。
3. 箱格状态至少表达：灰色无需盘点、蓝色待盘、橙色开门盘点中、浅绿色部分匹配、绿色全部正常且确认放回、红色存在缺失/溢余/未确认放回。UI 同时显示状态文字或图标，颜色不能成为唯一信息来源。
4. 箱格明细按“序号、合格证编号、RFID、盘点结果、放回状态”展示。预期 RFID 首次扫描标记正常，非预期 RFID 新增溢余记录，重复扫描必须幂等。
5. 只有匹配当前门号的明确关门确认才能将未扫描的预期证件标记为缺失；超时、页面销毁、弹窗关闭、网络失败或导航不得触发缺失判定。缺失件的放回状态为未发现，不使用“等待放回”。
6. 全部预期证件匹配、无溢余且均确认放回时箱格为正常；存在缺失、溢余或未确认放回时为异常。所有被抽中箱格形成最终结果后，盘点任务才可完成。
7. 常规盘点默认不要求每份证件拍照。平台要求异常留痕时，可在缺失、溢余等异常分支采集箱格全景；照片临时文件、上传状态和失败重试必须有明确所有者，当前未接入时继续标明能力边界。

### 柜门互锁与安全退出

1. 开门顺序固定为：Repository 复核当前步骤、机构和门号 -> 应用级 `CabinetDoorGuard.requestOpen` -> 真实接入后的设备开门。任何一层失败都不得继续。
2. 每次开门周期签发唯一 `operationId`；只有同一柜门且同一 `operationId` 的重复请求才按幂等成功处理，其他任务、页面或后续开门周期均返回冲突且不能抢占。只有门号和 `operationId` 同时匹配的关门确认可以调用 `markClosed` 释放资格。
3. 当前开门操作 30 秒后只进入报警状态，不能因超时、页面销毁、异常或导航自动释放互锁，也不能据此把盘点证件判为缺失。
4. 盘点收到匹配柜门的关门确认后才汇总正常、缺失、溢余和放回状态，并关闭箱格明细窗口；真实接入后关门事实必须来自柜控板门磁，当前 UI 确认仅为演示边界。
5. 柜门未确认关闭时禁止返回任务中心或退出登录。当前无任务安全退出倒计时为 10 秒，只在无加载、无导航、无进行中动作且所有柜门关闭时推进；门打开时隐藏或重置倒计时。
6. 开门结果响应异常时先回读最新任务对账：已提交则保持当前开门周期继续，无法确认则保留互锁，待人工关门并把可能已提交的开门步骤安全回退后再释放。平台结果上报失败与物理关门状态分别处理，本地结果必须保留待上报或异常对账状态，不能伪造平台成功。
7. `CabinetDoorGuard` 只是单 Dart isolate 内的第一道门禁。真实投产必须叠加柜控板门磁状态、平台授权或租约和异常恢复，不能把 UI 确认或内存状态描述成物理事实。

### 旧模块边界

旧 `features/storage`、`features/pickup`、`features/dropoff` 和 `features/flight_inspection` 已删除，不作为兼容入口恢复。五类业务继续在 `task_center` 内共享任务模型和安全门禁。`core/storage` 是本地持久化基础设施，与旧业务入口无关，不能因名称相似而删除。

## `core/` 与 `shared/` 规则

`lib/src/core/` 当前按能力拆分为：

```text
core/
├── camera/                 # 摄像头发现、控制与推流能力
├── config/                 # 应用配置
├── device/                 # 柜机平台抽象与 MethodChannel 实现
├── logging/                # 应用日志、崩溃记录与结构化通讯日志
├── monitoring/             # 运行健康监测
├── mqtt/                   # MQTT 连接、消息与设备命令
├── network/                # API、HTTP 抽象及可复用 TCP 协议请求基础设施
└── storage/                # 本地存储抽象、实现与 Provider
```

1. `core/` 只放跨业务基础设施，不承载操作员任务或管理员规则。
2. 跨业务柜机能力通过 `core/device` 中的 `KioskDevice` 等抽象访问；`TerminalUpgradeDevice` 这类 Feature 专属平台抽象必须位于对应 Feature 的 `data/datasources`。页面不得直接创建新的 `MethodChannel` 调用。
3. 网络请求复用 `ApiClient`、项目 HTTP 抽象和现有结果类型；模拟响应集中在 `mock_api_data.dart` 或对应 Feature DataSource。
4. 本地存储复用 `AppLocalStore`、KeyValueStorage 抽象和现有 Provider，不在页面散落 SharedPreferences key。
5. 普通业务日志和异常进入 `AppLogger` 等现有入口；管理员通讯记录只能进入独立的 `CommunicationLogStore`/原生有界队列，并按服务器、硬件或升级指令归类且在写入前脱敏。ZRD STUM 的 TCP 建连和每条 T01/T03/T00、S00/S03 收发必须使用“升级指令”类型。两类日志不得相互复用，避免错误正文、堆栈或原始协议内容进入管理员页面。
6. `shared/` 只放真正跨业务、业务无关的通用 UI 或模型，不把它变成无法归类代码的兜底目录。

## 终端升级边界

1. `terminal_upgrade` 的现场连接参数持久化在 `AppLocalStore.upgrade`，默认 `enabled = false`。`T01.ID` 来自管理员保存的真实设备号；`T01.IM` 只能由生产 Provider 从 `AppConfig.current.afrrDeviceImei` 注入，与 AFRR 共用唯一的 15 位 `DEVICE_IMEI`，确保匹配后台按 IMEI 绑定的升级任务，不得再创建第二份升级模块号环境配置；`T01.DP` 从 `terminalUpgradeDataProtocolIp`（`STUM_DP`，一个或多个逗号分隔的 IPv4 地址）注入。`T01.CD` 必须读取“关于设备”同源的 Android `Settings.Secure.ANDROID_ID`；它不是硬件芯片序列号，缺失或为占位值时必须在 Socket 建连前失败。经用户明确确认，管理员终端升级页面可以只读完整展示 IM、DP、CD，但页面和本地 Store 均不得编辑、保存或回退旧 `moduleImei`、`dataProtocolIp`、`chipId`，其它界面及全部日志不得输出。现场服务器可以由应用预填，但启动任务只在身份配置完整、管理员显式保存并启用时调度长连接，不得用空身份参数自动联网。
2. 跨协议复用 `core/network/protocol/TcpProtocolClient` 管理连接代际、增量拆帧、串行写入、请求匹配、超时、主动消息和断线清理；STUM 报文及命令语义保留在 `terminal_upgrade/data/protocol`，`core` 不得依赖 Feature。STUM TCP 必须按 CRLF 拆帧并只处理 ASCII；每次连接先发送 `T01`，收到对应 `S00 01:OK` 后直接发送 `T03`，二者之间不发送 `T02`。`T03.VE` 按现场约定编码为 `SL_V{Android versionName}_{STUM_VERSION_DATE}`，版本日期必须绑定 APK 构建批次而非请求当天。`S03.VE=0` 只表示当前没有匹配到可下发升级包，不得展示成已经证明客户端为最新版本。`SN` 在 1—9999 循环，服务端 `S03` 的回执复用其 `SN`。URL 中的冒号只能按属性段第一个冒号切分。
3. 当前只实现 `DT=1` URL 模式。新版本必须提供 HTTP/HTTPS `AD`、32 位完整文件 MD5，并在配置了 `PT` 时严格匹配；协议没有定义 `AD=2` 的分包帧、顺序、重传和校验，必须回复 `NG3AD`，不得自行扩展。
4. 新 `S03` 只允许作为当前 `T03` 请求窗口的业务回复；窗口外仅对已经接收 offer 的同 `SN/VE/AD/MD/PT` 精确重传幂等补发 ACK，人工或迟到帧不得创建或替换任务。后台收到合法 offer 时可以显示不含 URL、MD5 和设备身份的应用级管理员处理入口，但通知不能直接触发下载或安装，也不能绕过管理员账号和人脸、指纹、NFC 三因子流程；认证通过后可直接进入升级页。停止、重配或安装终态使 offer 失效时，应用级提示必须同步清除。管理员确认必须绑定其看到的具体 offer；`CabinetDoorGuard.allDoorsClosed` 为真后必须原子取得维护租约再下载。租约阻止新的开门请求并保持到安装终态，应用首帧前无论监控开关都先恢复原生活动安装租约；停止、重配或释放监控必须使未提交下载和未跨过原生 commit 的操作失效。下载限制大小、使用临时 `.part` 文件并在完成后校验 MD5。
5. `TerminalUpgradeDevice` 与 MethodChannel 实现位于 `terminal_upgrade/data/datasources`，`smart_cabinet/upgrade` 的 Android 实现位于 `android/app/src/main/kotlin/com/example/smart_cabinet/upgrade/`。Android 原生层必须重新校验 APK 可读性、协议目标版本与 APK `versionName`、当前包名、签名连续性和严格递增的 `versionCode`，使用 operation ID 隔离并取消 commit 前操作。`PackageInstaller` 显式结果 Receiver 必须核对任务、Session、系统包名与实际安装的精确版本，并持久化防重复提交和最终状态。
6. STUM 文档没有定义安装结果上报、灰度、失败重试或回滚命令；这些能力在服务端协议补齐前不得伪造。应用可在 `MY_PACKAGE_REPLACED` 后尝试拉起，但不能替代 Device Owner 或现场 watchdog。release 绝不回退到 debug 签名；生产构建必须在未入库的 `android/key.properties` 中配置 `storeFile`、`storePassword`、`keyAlias`、`keyPassword` 和稳定证书，并完成系统确认路径和目标真机自更新/拉起验收。

## Android、MethodChannel 与原生边界

Android 平台代码集中在：

```text
android/app/src/main/
├── kotlin/com/example/smart_cabinet/  # FlutterActivity 与柜机平台实现
│   ├── kiosk/                          # 跨页面柜机能力
│   └── upgrade/                        # APK 校验、PackageInstaller 与结果接收
├── cpp/rkmpp_bridge.cpp               # RKMPP JNI 桥接源码
├── native/                             # ndk-build 配置
├── jniLibs/arm64-v8a/                 # 预编译 RKMPP 与 C++ 运行库
└── res/                                # Manifest 使用的 Android 资源
```

1. Dart 与 Android 共用的业务通道名是 `smart_cabinet/kiosk` 和 `smart_cabinet/upgrade`；原生通讯诊断使用 `smart_cabinet/communication_log` 及其 events 通道。新增或修改方法时，必须同步检查 Dart 调用名、Kotlin 分发名、参数键、返回类型、错误码和测试。
2. 平台实现保持在 `MainActivity`、`KioskManager`、`kiosk/` 或 `upgrade/` 下的明确职责类中；Flutter 页面不直接了解 Camera2、MediaCodec、RTSP 或 `PackageInstaller` 细节。
3. 摄像头和推流代码必须正确处理应用生命周期、权限、重复启动、停止、取消、超时、线程切换、队列背压和资源释放；不得阻塞 Android 主线程或 Flutter UI isolate。
4. 当前推流主链路为 `Camera2 -> ImageReader -> MediaCodec/RKMPP H265 -> RtspTcpH265Publisher -> RTSP/TCP`。修改其中一层时，应检查上下游格式、分辨率、帧率、码率、GOP、缓冲和失败传播。
5. `android/app/build.gradle.kts` 当前限定 `arm64-v8a`，Java/Kotlin 目标为 17；不要无依据扩大 ABI、改变 SDK 或替换构建体系。
6. 普通构建默认打包 `jniLibs/arm64-v8a/` 中的预编译库，不会因为修改 `rkmpp_bridge.cpp` 就自动更新 `.so`。只有明确要求重建 native 时才启用和验证 `buildRkMppNative` 流程。
7. JNI/C++ 改动必须维护 ABI、符号加载、互斥、缓冲区边界和每条失败路径的资源释放，并明确需要在 Rockchip ARM64 真机上复测。
8. 当前 `applicationId` 仍是示例值，Manifest 还允许明文流量；release 已禁止回退 debug key，但仍需由部署方通过未入库的 `android/key.properties` 提供稳定生产证书。这些都是正式投产前需要专项处理的边界，不能把验收构建描述为生产发布构建。
9. 二进制 `.so`、签名配置和设备所有者/Kiosk 配置属于高风险交付边界，不为普通 UI 或业务改动顺手调整。
10. 通讯诊断只记录 RTSP 控制方法/CSeq/响应码、脱敏 endpoint 和其它结构化元数据；不得读取、复制或保存 SDP、Session、VPS/SPS/PPS、RTP/H265 帧，也不得改变视频发送、重连、队列背压或资源释放时序。

## 多语言与资源

1. 应用文案通过 `context.l10n.t('key', '中文兜底')` 或现有等价入口读取，不在同一流程的多个页面重复硬编码固定文案。
2. 字典位于 `lib/src/app/localization/values/`，按业务域拆分。新增或修改文案时同步维护简体中文、繁体中文、英语和日语，并保留中文兜底。
3. 新增语言或修改语言枚举时，同步检查设置入口、`supportedLocales`、字典和语言切换测试。
4. 新增、移动或删除资源时，同步检查 `pubspec.yaml` 的 `flutter.assets` 声明和所有引用路径。
5. 不手动编辑 Flutter 或 Gradle 自动生成的资源索引和缓存文件。

## 测试结构

`test/` 优先映射源码职责：

```text
test/
├── app/                    # 启动、外壳、覆盖层与路由相关测试
├── core/                   # 摄像头、设备、MQTT、存储等基础设施测试
├── features/               # 业务流程与业务组件测试
├── shared/                 # 通用组件测试
├── tool/                   # 发布版本与工程工具测试
└── widget_test.dart        # 跨流程 Widget 回归测试
```

1. 行为变化优先补最接近实现层级的测试。
2. MethodChannel、异步生命周期和硬件错误分支应使用可控替身或测试通道覆盖，不让单元测试依赖真实设备。
3. UI 改动检查关键交互、多语言、加载/错误状态以及目标柜机尺寸下的溢出风险。
4. 仅能在真机验证的 Camera2、RKMPP、RTSP 或 Kiosk 行为必须在交付说明中明确列出，不能用模拟测试结果替代真机结论。
5. 身份与任务改动至少回归：匿名或缺少任一因子时拒绝、三项全验、资料缺失/同步/异常、跨机构任务与箱格拒绝、取件码和飞检码失败不推进、同箱多证件只开一次门、第二柜门冲突、错误关门不释放、超时不判缺失、关门自动汇总缺失/溢余、门开时暂停退出，以及全部任务项完成后才允许结束。

## 变更约束

1. 没有明确必要时，不新增正式顶层目录。
2. 除非用户要求重构，不批量移动文件或跨层改写现有模块。
3. 命名和职责与同级代码保持一致，不为个人偏好大规模重命名。
4. 不为配置、状态、设备能力或派生数据建立重复事实来源。
5. 不通过空 README、空接口、空 Provider 或占位目录预建未来架构。
6. 不手动修改 `.dart_tool/`、`build/`、Gradle/Kotlin 缓存、`.flutter-plugins-dependencies` 或 `.git/`。
7. `flutter clean` 只在缓存损坏或产物确认失效时使用；日常开发不执行。`flutter pub upgrade` 只在用户明确要求升级依赖时使用。
8. `打包命令.md` 中的本机路径、服务器命令、进程号和现场性能数据仅作环境备忘；未经明确授权和重新核对，不执行服务器停止、杀进程或重启操作。

## 交付要求

1. 改动应尽量小且可验证，不修改与任务无关的文件。
2. Dart 改动先格式化实际修改文件，再运行 `flutter analyze` 和相关 `flutter test`；跨模块改动运行完整测试。
3. Android/Kotlin 改动按需在 `android/` 下运行 `./gradlew :app:assembleDebug`（Windows 使用 `.\gradlew.bat :app:assembleDebug`）。
4. 需要 APK 验证时优先构建 debug 包；release 包必须明确当前签名限制。
5. 规则、README 或纯文档改动不启动应用或执行全量构建，只检查内容、链接、路径与 Git 差异。
