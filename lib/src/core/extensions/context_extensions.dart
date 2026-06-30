import 'package:flutter/material.dart';

/// [BuildContext] 的主题快捷扩展。
///
/// 扩展可以给已有类型增加“语法糖”。
/// 有了这个扩展后，可以写 `context.theme`，不用每次都写 `Theme.of(context)`。
extension BuildContextTheme on BuildContext {
  /// 当前上下文对应的主题。
  ThemeData get theme => Theme.of(this);

  /// 当前主题中的文字样式集合。
  TextTheme get textTheme => theme.textTheme;
}
