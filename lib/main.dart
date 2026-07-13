import 'package:smart_cabinet/src/app/bootstrap/bootstrap.dart';

/// Flutter 应用的入口函数。
///
/// 当应用启动时，Dart 会先执行 [main]。
/// 这里不直接写初始化逻辑，而是交给 [bootstrap] 统一处理，
/// 这样以后增加日志、异常捕获、依赖注入等启动配置时更容易维护。
void main() => bootstrap();
