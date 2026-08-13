import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:smart_cabinet/src/app/theme/app_theme.dart';

import 'package:smart_cabinet/src/app/localization/app_localizations.dart';
import 'package:smart_cabinet/src/core/camera/cabinet_camera.dart';
import 'package:smart_cabinet/src/core/device/hardware_recovery_advice.dart';
import 'package:smart_cabinet/src/core/logging/communication_log_store.dart';
import 'package:smart_cabinet/src/features/identity_verification/presentation/widgets/localized_hardware_recovery_advice.dart';

/// 人脸识别流程状态。
enum FaceVerificationStatus { initializing, ready, verifying, success, failure }

/// 人脸卡片内部使用的稳定消息类型，最终在 build 阶段按当前语言转换。
enum _FaceVerificationMessage {
  cameraStarting,
  cameraReady,
  noCamera,
  cameraPermissionDenied,
  cameraPermissionPermanentlyDenied,
  cameraStartFailed,
  simulationReady,
  simulationVerifying,
  simulationSucceeded,
  captureVerifying,
  captureFailed,
  verifiedSubmitted,
}

/// 人脸识别卡片。
class FaceVerificationCard extends StatefulWidget {
  /// 创建人脸识别卡片。
  const FaceVerificationCard({
    super.key,
    required this.verified,
    required this.onVerified,
    this.title,
    this.subtitle,
    this.accentColor,
    this.stepNumber,
    this.allowFallbackWithoutCamera = false,
    this.simulateVerification = false,
    this.compact = false,
    this.showHeader = true,
  });

  /// 是否已经认证通过。
  final bool verified;

  /// 人脸认证成功时触发。
  final VoidCallback onVerified;

  /// 卡片标题。
  final String? title;

  /// 卡片副标题；当前统一头部不展示，仅保留兼容现有调用。
  final String? subtitle;

  /// 主题强调色。
  ///
  /// 为空时使用当前应用主题主色。
  final Color? accentColor;

  /// 右上角显示的步骤编号。
  final int? stepNumber;

  /// 无摄像头或权限失败时是否允许走模拟校验。
  final bool allowFallbackWithoutCamera;

  /// 是否完全跳过摄像头和后端，使用可控的测试认证流程。
  final bool simulateVerification;

  /// 是否使用紧凑模式。
  final bool compact;

  /// 是否显示卡片内部标题区。
  final bool showHeader;

  @override
  State<FaceVerificationCard> createState() => _FaceVerificationCardState();
}

/// 协调摄像头生命周期、临时拍照文件与人脸认证页面状态。
class _FaceVerificationCardState extends State<FaceVerificationCard>
    with WidgetsBindingObserver {
  /// 摄像头控制器。
  CameraController? _controller;

  /// 正在初始化、尚未发布到界面的摄像头控制器。
  CameraController? _initializingController;

  /// 串行化控制器释放，避免 camera 插件同时关闭多个会话时争用原生资源。
  Future<void> _releaseChain = Future<void>.value();

  /// 摄像头异步请求代次，用于丢弃过期结果。
  int _cameraGeneration = 0;

  /// 当前页面是否处于可使用摄像头的前台状态。
  bool _lifecycleActive = true;

  /// 当前人脸识别状态。
  FaceVerificationStatus _status = FaceVerificationStatus.initializing;

  /// 人脸识别提示类型；具体文案在 build 阶段按当前语言生成。
  _FaceVerificationMessage _message = _FaceVerificationMessage.cameraStarting;

  /// 拍照后的定格图片路径。
  String? _capturedImagePath;

  /// 当前摄像头异常恢复建议。
  HardwareRecoveryAdvice? _recoveryAdvice;

  /// 摄像头服务。
  final CabinetCameraService _cameraService = const CabinetCameraService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _lifecycleActive =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    if (widget.simulateVerification) {
      _status = FaceVerificationStatus.ready;
      _message = _FaceVerificationMessage.simulationReady;
    } else if (_lifecycleActive) {
      unawaited(_initializeCamera());
    }
  }

  /// 外部认证结果变化时释放或重建摄像头，已通过的卡片不继续占用硬件。
  @override
  void didUpdateWidget(covariant FaceVerificationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.verified && !oldWidget.verified) {
      unawaited(_releaseControllers(invalidate: true));
      _status = FaceVerificationStatus.success;
      _message = widget.simulateVerification
          ? _FaceVerificationMessage.simulationSucceeded
          : _FaceVerificationMessage.verifiedSubmitted;
      _recoveryAdvice = null;
    } else if (!widget.verified &&
        oldWidget.verified &&
        _lifecycleActive &&
        !widget.simulateVerification) {
      unawaited(_initializeCamera());
    }
  }

  /// 退到后台时立即失效并释放摄像头，回到前台后再按最新状态初始化。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lifecycleActive = state == AppLifecycleState.resumed;
    if (_lifecycleActive == lifecycleActive) {
      return;
    }
    _lifecycleActive = lifecycleActive;
    if (lifecycleActive) {
      if (!widget.verified && !widget.simulateVerification) {
        unawaited(_initializeCamera());
      }
      return;
    }
    unawaited(_releaseControllers(invalidate: true));
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lifecycleActive = false;
    unawaited(_releaseControllers(invalidate: true));
    final capturedImagePath = _capturedImagePath;
    _capturedImagePath = null;
    unawaited(_cleanupCapturedImage(capturedImagePath));
    super.dispose();
  }

  /// 初始化摄像头，并用请求代次阻止较早的异步结果覆盖最新页面状态。
  Future<void> _initializeCamera() async {
    final generation = ++_cameraGeneration;
    await _releaseControllers(invalidate: false);
    if (!_isCameraRequestCurrent(generation) || widget.verified) {
      return;
    }

    final previousImagePath = _capturedImagePath;
    setState(() {
      _capturedImagePath = null;
      _status = FaceVerificationStatus.initializing;
      _message = _FaceVerificationMessage.cameraStarting;
      _recoveryAdvice = null;
    });
    unawaited(_cleanupCapturedImage(previousImagePath));

    CameraController? candidate;
    try {
      final selectedCamera = await _cameraService
          .resolveFaceRecognitionCamera();
      if (!_isCameraRequestCurrent(generation) || widget.verified) {
        return;
      }
      if (selectedCamera == null) {
        _markCameraFailure(_FaceVerificationMessage.noCamera);
        return;
      }

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      candidate = controller;
      _initializingController = controller;
      await CommunicationLogStore.instance.traceExchange<void>(
        targetType: CommunicationTargetType.hardware,
        channel: 'camera plugin',
        operation: '初始化人脸识别摄像头',
        requestBody: const <String, Object?>{
          'role': 'faceRecognition',
          'resolution': 'medium',
        },
        action: controller.initialize,
      );
      if (identical(_initializingController, controller)) {
        _initializingController = null;
      }

      if (!_isCameraRequestCurrent(generation) || widget.verified) {
        await _disposeControllerSerially(controller);
        return;
      }
      setState(() {
        _controller = controller;
        _status = FaceVerificationStatus.ready;
        _message = _FaceVerificationMessage.cameraReady;
        _recoveryAdvice = null;
      });
    } on CameraException catch (error) {
      if (identical(_initializingController, candidate)) {
        _initializingController = null;
      }
      await _disposeControllerSerially(candidate);
      if (!_isCameraRequestCurrent(generation)) {
        return;
      }
      final failure = switch (error.code) {
        'CameraAccessDenied' ||
        'CameraAccessDeniedWithoutPrompt' => HardwareFailure.permissionDenied,
        _ => HardwareFailure.unavailable,
      };
      final message = switch (error.code) {
        'CameraAccessDenied' => _FaceVerificationMessage.cameraPermissionDenied,
        'CameraAccessDeniedWithoutPrompt' =>
          _FaceVerificationMessage.cameraPermissionPermanentlyDenied,
        _ => _FaceVerificationMessage.cameraStartFailed,
      };
      _markCameraFailure(message, failure: failure);
    } catch (_) {
      if (identical(_initializingController, candidate)) {
        _initializingController = null;
      }
      await _disposeControllerSerially(candidate);
      if (_isCameraRequestCurrent(generation)) {
        _markCameraFailure(_FaceVerificationMessage.cameraStartFailed);
      }
    }
  }

  /// 只有仍挂载、位于前台且代次匹配的初始化请求可以发布控制器。
  bool _isCameraRequestCurrent(int generation) {
    return mounted && _lifecycleActive && generation == _cameraGeneration;
  }

  /// 先从页面状态摘除控制器，再按需使在途初始化请求失效并异步释放资源。
  Future<void> _releaseControllers({required bool invalidate}) {
    if (invalidate) {
      _cameraGeneration++;
    }
    final controller = _controller;
    final initializingController = _initializingController;
    _controller = null;
    _initializingController = null;
    var release = _disposeControllerSerially(controller);
    if (!identical(initializingController, controller)) {
      release = _disposeControllerSerially(initializingController);
    }
    return release;
  }

  /// 将控制器释放追加到同一 Future 链，避免原生层并发 close 产生竞态。
  Future<void> _disposeControllerSerially(CameraController? controller) {
    if (controller == null) {
      return _releaseChain;
    }
    _releaseChain = _releaseChain.then(
      (_) => _safeDisposeController(controller),
    );
    return _releaseChain;
  }

  /// 容忍生命周期切换时原生平台已先行回收摄像头的情况。
  Future<void> _safeDisposeController(CameraController? controller) async {
    if (controller == null) {
      return;
    }
    try {
      await CommunicationLogStore.instance.traceExchange<void>(
        targetType: CommunicationTargetType.hardware,
        channel: 'camera plugin',
        operation: '释放人脸识别摄像头',
        requestBody: const <String, Object?>{'role': 'faceRecognition'},
        action: controller.dispose,
      );
    } catch (_) {
      // 生命周期切换期间原生平台可能已经先行释放摄像头。
    }
  }

  /// 尽力移除本次拍照的图片缓存与临时文件；清理失败不能中断认证流程。
  Future<void> _cleanupCapturedImage(String? path) async {
    if (path == null || path.isEmpty) {
      return;
    }
    final file = File(path);
    try {
      await FileImage(file).evict();
    } catch (_) {
      // 图片可能尚未进入 Flutter 缓存，逐出失败无需阻断后续文件清理。
    }
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // 临时照片清理属于收尾动作，不能反向改变已经完成的认证结果。
    }
  }

  /// 标记摄像头启动失败。
  ///
  /// 失败后会同步生成恢复建议，便于现场人员知道下一步如何处理。
  void _markCameraFailure(
    _FaceVerificationMessage message, {
    HardwareFailure failure = HardwareFailure.unavailable,
  }) {
    if (!mounted) {
      return;
    }
    setState(() {
      _status = FaceVerificationStatus.failure;
      _message = message;
      _recoveryAdvice = HardwareRecoveryAdvice.forFailure(
        hardware: CabinetHardware.camera,
        failure: failure,
      );
    });
  }

  /// 拍照并模拟提交后端校验。
  ///
  /// 当前实现以 UI 流程演示为主：拍照成功后延迟一小段时间再标记为通过，
  /// 方便后续替换成真实后端人脸比对接口。
  Future<void> _captureAndVerify() async {
    if (!_lifecycleActive ||
        widget.verified ||
        _status == FaceVerificationStatus.verifying) {
      return;
    }

    final generation = _cameraGeneration;
    String? pendingImagePath;
    setState(() {
      _status = FaceVerificationStatus.verifying;
      _message = widget.simulateVerification
          ? _FaceVerificationMessage.simulationVerifying
          : _FaceVerificationMessage.captureVerifying;
    });

    if (widget.simulateVerification) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted || widget.verified) {
        return;
      }
      setState(() {
        _status = FaceVerificationStatus.success;
        _message = _FaceVerificationMessage.simulationSucceeded;
      });
      widget.onVerified();
      return;
    }

    try {
      final controller = _controller;
      if (controller != null && controller.value.isInitialized) {
        final image = await CommunicationLogStore.instance.traceExchange<XFile>(
          targetType: CommunicationTargetType.hardware,
          channel: 'camera plugin',
          operation: '采集人脸验证图片',
          requestBody: const <String, Object?>{'role': 'faceRecognition'},
          action: controller.takePicture,
          responseBody: (_) => const <String, Object?>{
            'captured': true,
            'imageContent': '<不记录>',
          },
        );
        pendingImagePath = image.path;
        if (!_isCameraRequestCurrent(generation)) {
          unawaited(_cleanupCapturedImage(pendingImagePath));
          return;
        }

        if (identical(_controller, controller)) {
          _controller = null;
        }
        await _disposeControllerSerially(controller);
        if (!_isCameraRequestCurrent(generation)) {
          unawaited(_cleanupCapturedImage(pendingImagePath));
          return;
        }

        final previousImagePath = _capturedImagePath;
        setState(() => _capturedImagePath = image.path);
        pendingImagePath = null;
        unawaited(_cleanupCapturedImage(previousImagePath));
      } else if (widget.allowFallbackWithoutCamera) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        if (!_isCameraRequestCurrent(generation)) {
          return;
        }
      } else {
        await _initializeCamera();
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!_isCameraRequestCurrent(generation) || widget.verified) {
        return;
      }
      setState(() {
        _status = FaceVerificationStatus.success;
        _message = widget.simulateVerification
            ? _FaceVerificationMessage.simulationSucceeded
            : _FaceVerificationMessage.verifiedSubmitted;
      });
      widget.onVerified();
    } catch (_) {
      unawaited(_cleanupCapturedImage(pendingImagePath));
      if (!_isCameraRequestCurrent(generation)) {
        return;
      }
      final capturedImagePath = _capturedImagePath;
      setState(() {
        _capturedImagePath = null;
        _status = FaceVerificationStatus.failure;
        _message = _FaceVerificationMessage.captureFailed;
        _recoveryAdvice = HardwareRecoveryAdvice.forFailure(
          hardware: CabinetHardware.camera,
          failure: HardwareFailure.unavailable,
        );
      });
      unawaited(_cleanupCapturedImage(capturedImagePath));
    }
  }

  /// 当前是否允许点击确认按钮。
  ///
  /// 只有在未通过、未校验中，且摄像头可用或允许 fallback 时才允许点击。
  bool get _canConfirm {
    if (!_lifecycleActive ||
        widget.verified ||
        _status == FaceVerificationStatus.verifying) {
      return false;
    }
    return _controller?.value.isInitialized == true ||
        widget.simulateVerification ||
        widget.allowFallbackWithoutCamera;
  }

  @override
  Widget build(BuildContext context) {
    /// 当前页面文案集合。
    final l10n = context.l10n;

    /// 当前状态在所选语言下的提示文案。
    final displayMessage = _localizedFaceMessage(
      l10n,
      _message,
      allowFallback:
          _status == FaceVerificationStatus.failure &&
          widget.allowFallbackWithoutCamera,
    );

    /// 未显式传入标题时使用当前语言的人脸识别标题。
    final effectiveTitle = widget.title ?? l10n.t('identityFaceTitle', '人脸识别');

    /// 当前组件实际使用的强调色。
    final effectiveAccentColor =
        widget.accentColor ?? Theme.of(context).colorScheme.primary;

    /// 当前状态对应的主色。
    final activeColor = switch (_status) {
      FaceVerificationStatus.success => const Color(0xFF22A857),
      FaceVerificationStatus.failure => const Color(0xFFE05252),
      _ => effectiveAccentColor,
    };

    /// 中部取景圆形框尺寸。
    final circleSize = widget.compact ? 104.0 : 126.0;

    /// 头部图标容器尺寸。
    final headerIconBoxSize = widget.compact ? 40.0 : 44.0;

    /// 头部图标尺寸。
    final headerIconSize = widget.compact ? 22.0 : 24.0;

    /// 头部标题字号。
    final headerTitleSize = widget.compact ? 16.0 : 18.0;

    /// 当前摄像头恢复建议。
    final recoveryAdvice = _recoveryAdvice == null
        ? null
        : localizeHardwareRecoveryAdvice(l10n, _recoveryAdvice!);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.showHeader ? (widget.compact ? 20 : 18) : 0,
        vertical: widget.showHeader ? (widget.compact ? 20 : 18) : 4,
      ),
      decoration: widget.showHeader
          ? BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: activeColor.withValues(alpha: .22)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D1B2E5A),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showHeader) ...[
            Container(
              height: widget.compact ? 54 : 58,
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 14),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppTheme.outlineColor),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: headerIconBoxSize,
                    height: headerIconBoxSize,
                    decoration: BoxDecoration(
                      color: effectiveAccentColor.withValues(alpha: .1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.center_focus_strong_rounded,
                      color: effectiveAccentColor,
                      size: headerIconSize,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      effectiveTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor,
                        fontSize: headerTitleSize,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: widget.verified
                          ? const Color(0xFF59BE5A)
                          : effectiveAccentColor,
                      shape: BoxShape.circle,
                    ),
                    child: widget.verified
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 18,
                          )
                        : Text(
                            '${widget.stepNumber ?? 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.primarySoftColor,
                borderRadius: BorderRadius.circular(14),
                border: widget.showHeader
                    ? Border.all(color: AppTheme.outlineColor)
                    : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: SizedBox.expand(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _FacePreview(
                      controller: _controller,
                      capturedImagePath: _capturedImagePath,
                      color: activeColor,
                      message: displayMessage,
                    ),
                    Container(
                      width: circleSize,
                      height: circleSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: activeColor.withValues(alpha: .75),
                          width: 3,
                        ),
                      ),
                    ),
                    if (_status == FaceVerificationStatus.verifying)
                      Container(
                        color: Colors.black.withValues(alpha: .18),
                        child: const Center(
                          child: SizedBox(
                            width: 34,
                            height: 34,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .88),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          widget.verified
                              ? l10n.t('sharedFaceVerifiedShort', '人脸识别通过')
                              : displayMessage,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          softWrap: true,
                          style: TextStyle(
                            color: activeColor,
                            fontSize: 12,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (recoveryAdvice != null) ...[
            SizedBox(height: widget.showHeader ? 10 : 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF6E8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFD49A)),
              ),
              child: Text(
                l10n
                    .t('hardwareRecoverySummary', '{title}：{steps}')
                    .replaceAll('{title}', recoveryAdvice.title)
                    .replaceAll('{steps}', recoveryAdvice.recoverySteps),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF7A4A0A),
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          SizedBox(height: widget.showHeader ? 14 : 10),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: _canConfirm ? _captureAndVerify : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: effectiveAccentColor,
                disabledBackgroundColor: AppTheme.primarySoftColor,
                disabledForegroundColor: const Color(0xFF22A857),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              child: Text(
                widget.verified
                    ? l10n.t('sharedVerified', '已通过')
                    : _status == FaceVerificationStatus.verifying
                    ? l10n.t('sharedFaceVerifying', '校验中...')
                    : widget.simulateVerification
                    ? l10n.t('sharedFaceConfirmSimulation', '确认模拟认证')
                    : l10n.t('sharedFaceConfirmCapture', '确认并拍照校验'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 摄像头预览区域。
class _FacePreview extends StatelessWidget {
  const _FacePreview({
    required this.controller,
    required this.capturedImagePath,
    required this.color,
    required this.message,
  });

  /// 摄像头控制器。
  final CameraController? controller;

  /// 定格图片路径。
  final String? capturedImagePath;

  /// 状态色。
  final Color color;

  /// 状态文案。
  final String message;

  @override
  Widget build(BuildContext context) {
    final imagePath = capturedImagePath;
    if (imagePath != null && File(imagePath).existsSync()) {
      return Positioned.fill(
        child: Image.file(File(imagePath), fit: BoxFit.cover),
      );
    }

    final faceController = controller;
    if (faceController != null && faceController.value.isInitialized) {
      return Positioned.fill(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: faceController.value.previewSize?.height ?? 1,
            height: faceController.value.previewSize?.width ?? 1,
            child: CameraPreview(faceController),
          ),
        ),
      );
    }

    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withValues(alpha: .12), const Color(0xFFFFFFFF)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 将稳定的人脸认证消息类型转换为当前界面语言。
String _localizedFaceMessage(
  AppLocalizations l10n,
  _FaceVerificationMessage message, {
  required bool allowFallback,
}) {
  final localized = switch (message) {
    _FaceVerificationMessage.cameraStarting => l10n.t(
      'sharedFaceCameraStarting',
      '正在启动摄像头...',
    ),
    _FaceVerificationMessage.cameraReady => l10n.t(
      'sharedFaceCameraReady',
      '摄像头已启动，请对准面部后点击确认',
    ),
    _FaceVerificationMessage.noCamera => l10n.t(
      'sharedFaceNoCamera',
      '未检测到可用摄像头',
    ),
    _FaceVerificationMessage.cameraPermissionDenied => l10n.t(
      'sharedFaceCameraPermissionDenied',
      '摄像头权限被拒绝',
    ),
    _FaceVerificationMessage.cameraPermissionPermanentlyDenied => l10n.t(
      'sharedFaceCameraPermissionPermanentlyDenied',
      '摄像头权限被永久拒绝，请到系统设置开启',
    ),
    _FaceVerificationMessage.cameraStartFailed => l10n.t(
      'sharedFaceCameraStartFailed',
      '摄像头启动失败',
    ),
    _FaceVerificationMessage.simulationReady => l10n.t(
      'sharedFaceSimulationReady',
      '测试模式：点击确认完成人脸模拟认证',
    ),
    _FaceVerificationMessage.simulationVerifying => l10n.t(
      'sharedFaceSimulationVerifying',
      '测试模式：正在完成人脸模拟认证...',
    ),
    _FaceVerificationMessage.simulationSucceeded => l10n.t(
      'sharedFaceSimulationSucceeded',
      '测试模式：人脸模拟认证已完成',
    ),
    _FaceVerificationMessage.captureVerifying => l10n.t(
      'sharedFaceCaptureVerifying',
      '正在拍照并提交后端校验...',
    ),
    _FaceVerificationMessage.captureFailed => l10n.t(
      'sharedFaceCaptureFailed',
      '拍照或校验失败，请重试',
    ),
    _FaceVerificationMessage.verifiedSubmitted => l10n.t(
      'sharedFaceVerifiedSubmitted',
      '人脸识别通过，照片已提交后端校验',
    ),
  };
  if (!allowFallback) {
    return localized;
  }
  return l10n
      .t('sharedFaceFallbackAvailable', '{message}，可使用模拟校验')
      .replaceAll('{message}', localized);
}
