import 'dart:async';

import 'package:flutter/material.dart';

import 'package:smart_cabinet/src/shared/widgets/smart_cabinet_brand_panel.dart';

/// 应用启动阶段展示的媒体层。
///
/// 启动视觉由代码绘制，避免图片内嵌文字绕过多语言系统。
class StartupMedia extends StatefulWidget {
  /// 创建启动媒体层。
  const StartupMedia({required this.child, super.key});

  /// 启动媒体结束后显示的正式应用内容。
  final Widget child;

  /// 启动图最短展示时间。
  ///
  /// 测试可以临时改为 [Duration.zero]，避免与业务点击用例互相遮挡。
  static Duration minimumDisplayDuration = const Duration(seconds: 3);

  @override
  State<StartupMedia> createState() => _StartupMediaState();
}

class _StartupMediaState extends State<StartupMedia> {
  /// 是否已经结束启动媒体展示。
  bool _startupFinished = false;

  @override
  void initState() {
    super.initState();
    if (StartupMedia.minimumDisplayDuration <= Duration.zero) {
      _startupFinished = true;
      return;
    }

    Timer(StartupMedia.minimumDisplayDuration, _finishStartup);
  }

  /// 结束启动媒体展示，切换到正式应用内容。
  void _finishStartup() {
    if (!mounted) {
      return;
    }

    setState(() => _startupFinished = true);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchOutCurve: Curves.easeOutCubic,
          child: _startupFinished
              ? const SizedBox.shrink()
              : AbsorbPointer(
                  key: const ValueKey('startup_media_layer'),
                  absorbing: true,
                  child: const SmartCabinetBrandPanel(
                    key: ValueKey('startup_media_image'),
                    showLoading: true,
                  ),
                ),
        ),
      ],
    );
  }
}
