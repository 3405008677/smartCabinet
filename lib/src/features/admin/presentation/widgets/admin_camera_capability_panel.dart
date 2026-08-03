import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:smart_cabinet/src/app/theme/app_theme.dart';
import 'package:smart_cabinet/src/core/camera/camera_stream_capability.dart';

/// The preview frame keeps its existing shape; diagnostics are rendered below it.
const double adminCameraPreviewAspectRatio = 16 / 9;

/// The admin preview keeps its existing capture preset.
const ResolutionPreset adminCameraPreviewResolutionPreset =
    ResolutionPreset.medium;

/// Converts camera-plugin errors into an actionable admin-console message.
String adminCameraPreviewErrorMessage(Object? error) {
  final detail = error?.toString().trim() ?? '';
  final normalized = detail.toLowerCase();
  if (normalized.contains('already in use') ||
      normalized.contains('camera_in_use') ||
      normalized.contains('camera is in use') ||
      normalized.contains('being used') ||
      normalized.contains('正在使用') ||
      normalized.contains('已被占用')) {
    return '预览异常：摄像头正被其他页面或应用占用，请先关闭其他预览';
  }
  if (normalized.contains('too many cameras') ||
      normalized.contains('max_cameras') ||
      normalized.contains('maximum number of cameras') ||
      normalized.contains('max cameras') ||
      normalized.contains('limit number of open cameras') ||
      normalized.contains('camera limit')) {
    return '预览异常：已达到系统同时打开摄像头上限，请先关闭其他摄像头';
  }
  if (detail.isEmpty) {
    return '预览异常：摄像头暂时不可用';
  }
  return '预览异常：$detail';
}

/// Read-only capability details shown below the live camera preview.
class AdminCameraCapabilityPanel extends StatelessWidget {
  /// Creates a camera capability panel.
  const AdminCameraCapabilityPanel({
    required this.previewCameraId,
    required this.previewStatus,
    required this.loading,
    this.capability,
    this.loadError = '',
    super.key,
  });

  /// Flutter camera ID used by the preview.
  final String previewCameraId;

  /// Current preview status, including occupancy errors.
  final String previewStatus;

  /// Whether Camera2 capability discovery is in progress.
  final bool loading;

  /// Native Camera2 capability data.
  final CameraStreamCapability? capability;

  /// Non-fatal capability loading error.
  final String loadError;

  @override
  Widget build(BuildContext context) {
    final data = capability;
    final warning = _warningFor(data);
    return Container(
      key: const ValueKey('admin_camera_capability_panel'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primarySoftColor.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '摄像头能力（仅供诊断）',
            style: TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          _CapabilityLine(label: '预览状态', value: previewStatus),
          _CapabilityLine(label: '预览摄像头 ID', value: previewCameraId),
          if (loading)
            const _CapabilityLine(label: '设备能力', value: '正在读取...')
          else if (loadError.isNotEmpty)
            _CapabilityLine(label: '设备能力', value: loadError)
          else if (data != null) ...[
            _CapabilityLine(
              label: '绑定 Camera2 ID',
              value: data.configuredCameraId.isEmpty
                  ? '未配置'
                  : data.configuredCameraId,
            ),
            _CapabilityLine(
              label: '系统当前 ID',
              value: data.availableCameraIds.isEmpty
                  ? '未枚举到摄像头'
                  : data.availableCameraIds.join('、'),
            ),
            _CapabilityLine(
              label: '支持的 YUV 分辨率',
              value: _supportedSizeText(data),
            ),
            _CapabilityLine(label: '推流配置', value: _configuredProfileText(data)),
          ],
          if (warning.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              warning,
              key: const ValueKey('admin_camera_capability_warning'),
              style: const TextStyle(
                color: Color(0xFFB54708),
                fontSize: 11,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _warningFor(CameraStreamCapability? data) {
    if (previewStatus.contains('占用') || previewStatus.contains('打开摄像头上限')) {
      return previewStatus;
    }
    if (loadError.isNotEmpty) {
      return '能力信息读取失败不会影响上方实时预览。';
    }
    if (data == null) {
      return '';
    }
    if (!data.available) {
      return data.errorMessage.isNotEmpty
          ? data.errorMessage
          : '绑定的摄像头当前不可用，请检查接线、设备 ID 或是否被系统移除。';
    }
    final incompatible = data.incompatibleProfiles;
    if (incompatible.isNotEmpty) {
      return '不支持推流配置：${incompatible.map((item) => item.label).join('、')}。'
          '收到推流请求时会在打开摄像头前停止，并返回明确错误。';
    }
    if (data.errorMessage.isNotEmpty) {
      return data.errorMessage;
    }
    return '';
  }

  String _supportedSizeText(CameraStreamCapability data) {
    if (data.supportedYuvSizes.isEmpty) {
      return '未获取到';
    }
    const visibleCount = 12;
    final visible = data.supportedYuvSizes.take(visibleCount);
    final suffix = data.supportedYuvSizes.length > visibleCount
        ? ' 等 ${data.supportedYuvSizes.length} 种'
        : '';
    return '${visible.map((size) => size.label).join('、')}$suffix';
  }

  String _configuredProfileText(CameraStreamCapability data) {
    if (data.configuredProfiles.isEmpty) {
      return '该角色不使用原生推流';
    }
    return data.configuredProfiles
        .map((profile) {
          final compatible = data.isProfileCompatible(profile);
          final state = switch (compatible) {
            true => '支持',
            false => '不支持',
            null => '待确认',
          };
          return '${profile.label}（$state）';
        })
        .join('、');
  }
}

class _CapabilityLine extends StatelessWidget {
  const _CapabilityLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label：',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            TextSpan(text: value),
          ],
        ),
        style: const TextStyle(
          color: AppTheme.textSecondaryColor,
          fontSize: 11,
          height: 1.35,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
