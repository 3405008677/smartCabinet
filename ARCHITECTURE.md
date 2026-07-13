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

- `home`：终端首页和仪表盘。
- `storage`：存取件流程入口。
- `pickup`：取件认证、柜门信息和开柜流程。
- `dropoff`：放件认证、确认、开柜和完成流程。
- `flight_inspection`：飞检认证与任务流程。
- `admin`：管理员认证与控制台。
- `identity_verification`：跨业务复用的身份认证能力。

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

## 测试

`test/` 按 `app/core/shared/features` 映射源码。提交前执行：

```powershell
dart format lib test
flutter analyze
flutter test
```