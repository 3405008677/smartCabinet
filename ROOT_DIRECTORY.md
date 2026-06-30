# 根目录文件说明

本文档说明项目根目录下主要文件和文件夹的用途，便于新成员快速判断哪些内容属于源码、配置、构建产物、本地缓存或工具记录。

## 1. 项目类型

当前项目是一个 Flutter 智能柜终端应用，主要面向 Android 智能柜触屏端，同时保留 Flutter Web 平台目录。项目源码以 Dart 和 Flutter 为主，Android 平台工程由 Gradle 管理。

## 2. 主要源码与资源目录

| 路径 | 作用 | 是否建议手动修改 |
| --- | --- | --- |
| `lib/` | Flutter/Dart 主源码目录，包含应用入口、页面、状态、基础设施、共享组件和业务模块。 | 是 |
| `lib/main.dart` | 应用启动入口，负责进入 Flutter 应用初始化流程。 | 是 |
| `lib/src/` | 项目主体源码目录，按 `app`、`core`、`shared`、`features` 等分层组织。 | 是 |
| `assets/` | 静态资源目录，存放图片、图标、国际化、字体、模型和原型页面等资源。 | 是 |
| `assets/images/` | 图片资源目录，已在 `pubspec.yaml` 中声明。 | 是 |
| `assets/icons/` | 图标资源目录，已在 `pubspec.yaml` 中声明。 | 是 |
| `assets/i18n/` | 国际化资源目录，已在 `pubspec.yaml` 中声明。 | 是 |
| `assets/GLB/` | 3D 模型或 GLB 资源目录。 | 按需 |
| `assets/原型页面/` | 原型页面资源目录，已在 `pubspec.yaml` 中声明。 | 是 |
| `test/` | Flutter 测试目录，包含 Widget 测试、单元测试和分层测试目录。 | 是 |

## 3. 平台工程目录

| 路径 | 作用 | 是否建议手动修改 |
| --- | --- | --- |
| `android/` | Android 平台工程目录，包含 Gradle 配置、Android 原生代码和 APK 构建配置。 | 按需 |
| `android/app/` | Android 应用模块，通常包含 Manifest、原生入口和签名/构建相关配置。 | 按需 |
| `android/gradle/` | Gradle Wrapper 相关文件。 | 少改 |
| `android/gradlew` | Linux/macOS 下使用的 Gradle Wrapper 启动脚本。 | 否 |
| `android/gradlew.bat` | Windows 下使用的 Gradle Wrapper 启动脚本。 | 否 |
| `android/build.gradle.kts` | Android 根 Gradle 构建脚本。 | 按需 |
| `android/settings.gradle.kts` | Android Gradle 项目模块配置。 | 按需 |
| `android/gradle.properties` | Android/Gradle 构建属性配置。 | 按需 |
| `android/local.properties` | 本机 Android SDK、Flutter SDK 等本地路径配置，通常不应提交或跨机器复用。 | 本机按需 |
| `web/` | Flutter Web 平台目录，包含 Web 启动页、manifest 和图标。 | 按需 |
| `web/index.html` | Flutter Web 应用 HTML 入口。 | 按需 |
| `web/manifest.json` | Web App Manifest 配置。 | 按需 |
| `web/favicon.png` | Web 页签图标。 | 按需 |
| `web/icons/` | Web 应用图标资源。 | 按需 |

## 4. Flutter 与 Dart 配置文件

| 路径 | 作用 | 是否建议手动修改 |
| --- | --- | --- |
| `pubspec.yaml` | Flutter 项目核心配置，声明项目名称、版本、SDK、依赖、开发依赖和资源路径。 | 是 |
| `pubspec.lock` | 依赖锁定文件，记录实际解析出的依赖版本，保证应用构建版本一致。 | 通常不手改 |
| `analysis_options.yaml` | Dart 静态分析和 lint 规则配置。 | 按需 |
| `.metadata` | Flutter 工具生成的项目元数据，用于升级和平台能力识别。 | 否 |
| `.flutter-plugins-dependencies` | Flutter 插件依赖映射文件，由 Flutter 工具自动生成。 | 否 |
| `devtools_options.yaml` | Dart/Flutter DevTools 设置文件。 | 按需 |

## 5. 文档文件

| 路径 | 作用 | 是否建议维护 |
| --- | --- | --- |
| `README.md` | 项目总入口文档，说明项目背景、当前能力、技术栈、启动命令和业务流程。 | 是 |
| `ARCHITECTURE.md` | 架构说明文档，描述项目分层、依赖方向和目录约束。 | 是 |
| `ROOT_DIRECTORY.md` | 根目录说明文档，即当前文件，用于解释根目录文件和文件夹用途。 | 是 |
| `打包命令.md` | 打包命令备忘文档，记录 Android APK 构建和依赖处理命令。 | 是 |

## 6. 构建产物与本地缓存

| 路径 | 作用 | 是否可以删除 |
| --- | --- | --- |
| `build/` | Flutter 构建输出和缓存目录，可能包含 APK、Web 构建产物、测试或中间文件。 | 通常可以 |
| `.dart_tool/` | Dart/Flutter 工具缓存目录，包含包配置、构建缓存和分析缓存。 | 通常可以 |
| `android/build/` | Android Gradle 构建输出目录。 | 通常可以 |
| `android/.gradle/` | Gradle 本地缓存目录。 | 通常可以 |
| `android/.kotlin/` | Kotlin/Gradle 相关缓存目录。 | 通常可以 |

删除以上缓存目录后，后续执行 `flutter pub get`、`flutter run`、`flutter test` 或 `flutter build` 时会重新生成。删除 `build/` 前如果需要保留刚生成的 APK、Web 静态文件或其他交付产物，应先备份对应输出。

## 7. Git、IDE 与本地工具目录

| 路径 | 作用 | 是否建议手动修改 |
| --- | --- | --- |
| `.git/` | Git 仓库元数据目录，保存提交历史、分支、索引和远程信息。 | 否 |
| `.gitignore` | Git 忽略规则，声明不纳入版本控制的本地文件和构建产物。 | 按需 |
| `.idea/` | JetBrains、Android Studio 或 IntelliJ IDEA 项目配置目录。 | 通常不手改 |
| `smart_cabinet.iml` | IDE 模块文件。 | 否 |
| `android/smart_cabinet_android.iml` | Android 子工程 IDE 模块文件。 | 否 |
| `.openCode/` | OpenCode 本地工作目录，保存会话状态、沟通日志、PM 文档、记忆和工具依赖。 | 按规则维护 |
| `Microsoft/` | 本地 PowerShell 分析缓存误生成目录，已在 `.gitignore` 中忽略。 | 否 |

## 8. 常见维护建议

- 写业务代码优先进入 `lib/src/features/`。
- 修改应用装配、路由、主题和国际化优先查看 `lib/src/app/`。
- 修改日志、网络、存储、设备抽象等基础能力优先查看 `lib/src/core/`。
- 修改通用组件、通用模型和扩展方法优先查看 `lib/src/shared/`。
- 新增图片、图标或国际化资源后，需要确认 `pubspec.yaml` 的 `flutter.assets` 是否覆盖对应路径。
- 不要手动编辑 `.dart_tool/`、`build/`、`.metadata`、`.flutter-plugins-dependencies`、`.git/` 等自动生成或工具维护内容。
- 打包或验证前建议执行 `flutter pub get`、`flutter analyze`、`flutter test`，必要时再执行 `flutter build apk --debug` 或 `flutter build apk --release`。
