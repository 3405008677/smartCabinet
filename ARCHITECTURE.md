# 智能柜 Flutter 项目架构

## 1. 项目定位

本项目是面向 Android 智能柜终端屏幕的 Flutter 企业级基础框架。首期只提供工程骨架和基础设施边界，不实现具体业务模块，不接入硬件驱动。

## 2. 架构主线

项目采用 `Riverpod + Clean Architecture`。

整体分为四个主层级：

- `app`：应用装配层，负责启动、ProviderScope、路由、主题、国际化和全局异常入口。
- `core`：基础设施层，负责网络、日志、存储、异常、配置、常量、工具和设备抽象。
- `shared`：共享层，负责跨模块复用的扩展、模型和通用组件。
- `features`：业务功能层，作为后续业务模块入口。

## 3. 目录结构

```text
lib/
  main.dart
  src/
    app/
      app.dart
      bootstrap/
      localization/
      router/
      theme/
    core/
      config/
      constants/
      device/
      errors/
      logging/
      network/
      storage/
      utils/
    shared/
      extensions/
      models/
      widgets/
    features/
assets/
  fonts/
  icons/
  i18n/
  images/
test/
  app/
  core/
  features/
  shared/
```

## 4. 文件存放规则

- `app/` 只放应用装配代码，不放业务规则。
- `core/` 只放跨业务基础设施，不引用具体 `features`。
- `shared/` 只放可复用 UI、扩展方法和通用对象，不写业务流程。
- `features/` 首期不预置业务模块，后续新增业务模块时必须按 `data/domain/presentation` 分层。
- `assets/images/` 放图片资源。
- `assets/icons/` 放图标资源。
- `assets/fonts/` 放字体资源。
- `assets/i18n/` 放国际化资源。
- `test/` 与 `lib/` 分层保持一致，方便后续补测试。

## 5. 后续业务模块规范

新增业务模块必须放在 `lib/src/features/<feature_name>/` 下，并使用以下结构：

```text
features/<feature_name>/
  data/
    datasources/
    dto/
    repositories/
  domain/
    entities/
    repositories/
    usecases/
  presentation/
    controllers/
    pages/
    widgets/
```

模块依赖方向必须遵循：

```text
presentation -> domain -> data -> core
```

`domain` 不依赖 Flutter UI、网络库、存储库等具体实现。`presentation` 不直接调用 `data` 层。跨模块通信优先通过领域抽象、路由参数或应用级事件完成。

## 6. 基础设施边界

- `core/config`：应用配置入口，首期不做 dev/test/prod 切换。
- `core/errors`：统一异常和失败对象。
- `core/logging`：统一调试日志、业务日志和错误日志入口。
- `core/network`：网络客户端和网络结果抽象。
- `core/storage`：本地键值存储抽象。
- `core/device`：智能柜设备能力抽象，首期不实现扫码、开柜、打印、摄像头等驱动。
- `core/utils`：与业务无关的通用工具对象。

## 7. Provider 规则

Riverpod 用于依赖注入和状态管理。Provider 应尽量放在所属模块或基础设施附近，禁止将所有 Provider 堆到一个全局文件中。

## 8. 当前非目标

- 不实现登录、首页、柜格、订单、存件、取件、维护等业务模块。
- 不接入扫码器、开柜控制板、打印机、摄像头、语音、OTA 等硬件或运维能力。
- 不配置 dev/test/prod 多环境。
- 不配置 Android flavor。
- 不写具体测试用例。
- 不配置覆盖率和 CI。
- 不拆分多 package 架构。
