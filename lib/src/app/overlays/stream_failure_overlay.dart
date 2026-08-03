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

class _StreamFailureOverlayState extends State<StreamFailureOverlay>
    with WidgetsBindingObserver {
  static const _statusTimeout = Duration(seconds: 1);

  /// 轮询原生推流状态的定时器。
  Timer? _pollingTimer;

  /// 当前正在展示的失败消息。
  String? _visibleMessage;

  /// 当前正在展示的消息句柄。
  MessageHandle? _messageHandle;

  /// 是否正在读取原生状态，避免轮询重入。
  bool _checkingStatus = false;
  bool _isAppActive = true;
  int _checkGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _isAppActive =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    if (_isAppActive) {
      _startPolling();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isAppActive) {
          unawaited(_checkStreamStatus());
        }
      });
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(widget.pollingInterval, (_) {
      unawaited(_checkStreamStatus());
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isActive = state == AppLifecycleState.resumed;
    if (_isAppActive == isActive) {
      return;
    }
    _isAppActive = isActive;
    if (isActive) {
      _startPolling();
      unawaited(_checkStreamStatus());
    } else {
      _checkGeneration++;
      _stopPolling();
    }
  }

  @override
  void dispose() {
    _isAppActive = false;
    _checkGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    _messageHandle?.close();
    _messageHandle = null;
    _visibleMessage = null;
    super.dispose();
  }

  /// 读取两路推流状态，并在失败时展示全局提示。
  Future<void> _checkStreamStatus() async {
    if (_checkingStatus || !mounted || !_isAppActive) {
      return;
    }
    _checkingStatus = true;
    final generation = _checkGeneration;
    try {
      final request = Future.wait<CameraStreamStatus>([
        widget.cameraService.readOutsideEnvironmentStreamStatus(),
        widget.cameraService.readOperationAreaStreamStatus(),
      ]);
      late final List<CameraStreamStatus> statuses;
      try {
        statuses = await request.timeout(_statusTimeout);
      } on TimeoutException {
        // Keep the guard locked until the real native request completes.
        try {
          await request;
        } catch (_) {
          // A late native failure is still contained inside this poll.
        }
        return;
      }
      if (!mounted || !_isAppActive || generation != _checkGeneration) {
        return;
      }
      final failureMessage = _buildFailureMessage(
        outsideStatus: statuses[0],
        operationStatus: statuses[1],
      );
      if (failureMessage == null) {
        if (_visibleMessage == null && _messageHandle == null) {
          return;
        }
        _visibleMessage = null;
        _messageHandle?.close();
        _messageHandle = null;
        return;
      }
      if (_visibleMessage == failureMessage && _messageHandle != null) {
        return;
      }
      if (_showFailureMessage(failureMessage)) {
        _visibleMessage = failureMessage;
      }
    } catch (_) {
      // Keep the last known prompt until a later successful status read.
    } finally {
      _checkingStatus = false;
    }
  }

  /// 展示推流失败全局提示。
  bool _showFailureMessage(String message) {
    if (!mounted) {
      return false;
    }
    final overlay = widget.navigatorKey.currentState?.overlay;
    if (overlay == null) {
      return false;
    }
    _messageHandle?.close();
    _messageHandle = Message.showInOverlay(
      overlay,
      '推流异常：$message',
      type: MessageType.error,
      duration: null,
    );
    return true;
  }

  /// 生成需要展示给用户的推流失败文案。
  String? _buildFailureMessage({
    required CameraStreamStatus outsideStatus,
    required CameraStreamStatus operationStatus,
  }) {
    if (outsideStatus.needsUserAttention) {
      return '柜外环境推流异常：${outsideStatus.displayStatus}';
    }
    if (operationStatus.isUnconfigured) {
      return null;
    }
    if (operationStatus.needsUserAttention) {
      return '操作区推流异常：${operationStatus.displayStatus}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
