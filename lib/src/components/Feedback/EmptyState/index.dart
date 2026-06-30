import 'package:flutter/material.dart';

/// 通用空状态组件。
///
/// 当列表没有数据、搜索没有结果或页面暂无内容时，可以显示这个组件。
class AppEmptyState extends StatelessWidget {
  /// 创建空状态组件。
  const AppEmptyState({required this.message, super.key});

  /// 空状态提示文案。
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(message, textAlign: TextAlign.center));
  }
}
