import 'dart:async';

import 'package:flutter/material.dart';

import 'package:smart_cabinet/src/shared/widgets/app_message.dart';
import 'package:smart_cabinet/src/core/camera/cabinet_camera.dart';

/// 全局推流失败提示层。
class StreamFailureOverlay extends StatefulWidget {
  /// 创建全局推流失败提示层。
  const StreamFailureOverlay({
    required this.child,
    required this.navigatorKey,
    this.cameraService = const CabinetCameraService(),
    this.pollingInterval = const Duration(seconds: 2),
    super.key,
  });

  /// 正常应用内容。
  final Widget child;

  /// 应用导航器，用于在 [MaterialApp.builder] 外层安全展示全局弹窗。
  final GlobalKey<NavigatorState> navigatorKey;

  /// 摄像头与推流状态服务。
  final CabinetCameraService cameraService;

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

  /// 当前正在展示的消息句柄。
  MessageHandle? _messageHandle;

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
      final outsideStatus = await widget.cameraService
          .readOutsideEnvironmentStreamStatus();
      final operationStatus = await widget.cameraService
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
        _messageHandle?.close();
        _messageHandle = null;
        return;
      }
      if (_visibleMessage == failureMessage) {
        return;
      }
      _visibleMessage = failureMessage;
      _showFailureMessage(failureMessage);
    } finally {
      _checkingStatus = false;
    }
  }

  /// 展示推流失败全局提示。
  void _showFailureMessage(String message) {
    if (!mounted) {
      return;
    }
    final overlay = widget.navigatorKey.currentState?.overlay;
    if (overlay == null) {
      return;
    }
    _messageHandle?.close();
    _messageHandle = Message.showInOverlay(
      overlay,
      '推流异常：$message',
      type: MessageType.error,
      duration: null,
    );
  }

  /// 生成需要展示给用户的推流失败文案。
  String? _buildFailureMessage({
    required CameraStreamStatus outsideStatus,
    required CameraStreamStatus operationStatus,
  }) {
    if (outsideStatus.needsUserAttention) {
      return '柜外环境推流异常：${outsideStatus.status}';
    }
    if (operationStatus.isUnconfigured) {
      return null;
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
