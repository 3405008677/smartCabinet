import 'dart:async';

import 'package:flutter/material.dart';

/// 应用启动阶段展示的媒体层。
///
/// 当前使用图片资源，后续如果要替换成视频，只需要保留外部调用不变，
/// 将本组件内部的 [Image.asset] 替换为视频播放器即可。
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
  /// 启动图资源路径。
  ///
  /// 如果后续要替换图片，修改这里的资源路径，并在 `pubspec.yaml` 注册资源目录。
  static const String _startupImageAsset = 'assets/images/智能柜启动.png';

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
                  child: _StartupImage(assetPath: _startupImageAsset),
                ),
        ),
      ],
    );
  }
}

/// 启动图片展示组件。
class _StartupImage extends StatelessWidget {
  /// 创建启动图片展示组件。
  const _StartupImage({required this.assetPath});

  /// 图片资源路径。
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFD6DEEF),
      child: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 1280,
            height: 800,
            child: Image.asset(
              assetPath,
              key: const ValueKey('startup_media_image'),
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
        ),
      ),
    );
  }
}
