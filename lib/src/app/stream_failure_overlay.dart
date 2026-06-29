import 'dart:async';

import 'package:flutter/material.dart';

import '../core/camera/camera_binding_service.dart';

/// 全局推流失败提示层。
class StreamFailureOverlay extends StatefulWidget {
  /// 创建全局推流失败提示层。
  const StreamFailureOverlay({
    required this.child,
    this.cameraBindingService = const CameraBindingService(),
    this.pollingInterval = const Duration(seconds: 2),
    super.key,
  });

  /// 正常应用内容。
  final Widget child;

  /// 摄像头绑定与推流状态服务。
  final CameraBindingService cameraBindingService;

  /// 推流状态轮询间隔。
  final Duration pollingInterval;

  @override
  State<StreamFailureOverlay> createState() => _StreamFailureOverlayState();
}

class _StreamFailureOverlayState extends State<StreamFailureOverlay> {
  /// 轮询原生推流状态的定时器。
  Timer? _pollingTimer;

  /// 当前正在展示的失败消息。
  String? _visibleMessage;

  /// 当前是否已有弹窗在展示。
  bool _dialogVisible = false;

  /// 是否正在读取原生状态，避免轮询重入。
  bool _checkingStatus = false;

  @override
  void initState() {
    super.initState();
    _pollingTimer = Timer.periodic(widget.pollingInterval, (_) {
      _checkStreamStatus();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkStreamStatus());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  /// 读取两路推流状态，并在失败时展示全局提示。
  Future<void> _checkStreamStatus() async {
    if (_checkingStatus || !mounted) {
      return;
    }
    _checkingStatus = true;
    try {
      final outsideStatus = await widget.cameraBindingService
          .readOutsideEnvironmentStreamStatus();
      final operationStatus = await widget.cameraBindingService
          .readOperationAreaStreamStatus();
      if (!mounted) {
        return;
      }
      final failureMessage = _buildFailureMessage(
        outsideStatus: outsideStatus,
        operationStatus: operationStatus,
      );
      if (failureMessage == null) {
        _visibleMessage = null;
        return;
      }
      if (_visibleMessage == failureMessage) {
        return;
      }
      _visibleMessage = failureMessage;
      _showFailureDialog(failureMessage);
    } finally {
      _checkingStatus = false;
    }
  }

  /// 展示推流失败全局弹窗。
  Future<void> _showFailureDialog(String message) async {
    if (_dialogVisible || !mounted) {
      return;
    }
    _dialogVisible = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          title: const Text('推流异常'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );
    _dialogVisible = false;
  }

  /// 生成需要展示给用户的推流失败文案。
  String? _buildFailureMessage({
    required CameraStreamStatus outsideStatus,
    required CameraStreamStatus operationStatus,
  }) {
    if (outsideStatus.needsUserAttention) {
      return '柜外环境推流异常：${outsideStatus.status}';
    }
    if (operationStatus.needsUserAttention) {
      return '操作区推流异常：${operationStatus.status}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
