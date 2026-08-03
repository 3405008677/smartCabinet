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
- `admin`：管理员认证、设备检测与控制台。

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

## 任务中心安全边界

- 所有任务入口都要求同一账号至少通过人脸、指纹、NFC 中两种不同身份因子，Repository 是最终业务门禁。
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
