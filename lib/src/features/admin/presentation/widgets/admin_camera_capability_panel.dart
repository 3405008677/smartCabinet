import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:smart_cabinet/src/app/localization/app_localizations.dart';
import 'package:smart_cabinet/src/app/theme/app_theme.dart';
import 'package:smart_cabinet/src/core/camera/camera_stream_capability.dart';

/// 管理员预览固定使用 16:9 取景框，能力诊断信息在取景框下方独立展示。
const double adminCameraPreviewAspectRatio = 16 / 9;

/// 管理员实时预览沿用中档采集预设，不与原生 RTSP 推流清晰度耦合。
const ResolutionPreset adminCameraPreviewResolutionPreset =
    ResolutionPreset.medium;

/// 将 camera 插件原始异常归一为现场可操作的控制台提示。
///
/// 仅归类跨平台常见的“设备占用”和“并发上限”。非当前语言的
/// 原生 CJK 错误不直接上屏，避免固定中文混入英文或日文界面。
String adminCameraPreviewErrorMessage(
  Object? error, {
  AppLocalizations? localizations,
}) {
  final l10n =
      localizations ?? const AppLocalizations(AppLanguage.simplifiedChinese);
  final detail = error?.toString().trim() ?? '';
  final normalized = detail.toLowerCase();
  if (normalized.contains('already in use') ||
      normalized.contains('camera_in_use') ||
      normalized.contains('camera is in use') ||
      normalized.contains('being used') ||
      normalized.contains('正在使用') ||
      normalized.contains('已被占用')) {
    return l10n.t(
      'adminCameraPreviewErrorInUse',
      '预览异常：摄像头正被其他页面或应用占用，请先关闭其他预览',
    );
  }
  if (normalized.contains('too many cameras') ||
      normalized.contains('max_cameras') ||
      normalized.contains('maximum number of cameras') ||
      normalized.contains('max cameras') ||
      normalized.contains('limit number of open cameras') ||
      normalized.contains('camera limit')) {
    return l10n.t(
      'adminCameraPreviewErrorLimit',
      '预览异常：已达到系统同时打开摄像头上限，请先关闭其他摄像头',
    );
  }
  if (detail.isEmpty) {
    return l10n.t('adminCameraPreviewErrorUnavailable', '预览异常：摄像头暂时不可用');
  }
  final containsCjk = RegExp(r'[\u3400-\u9fff\u3040-\u30ff]').hasMatch(detail);
  if (containsCjk && l10n.language != AppLanguage.simplifiedChinese) {
    return l10n.t('adminCameraPreviewErrorUnavailable', '预览异常：摄像头暂时不可用');
  }
  return l10n
      .t('adminCameraPreviewErrorDetail', '预览异常：{detail}')
      .replaceAll('{detail}', detail);
}

/// 实时预览下方的只读 Camera2 能力诊断面板。
///
/// 能力读取与实时预览彼此独立：诊断失败只显示警告，不会停止或替换上方预览。
class AdminCameraCapabilityPanel extends StatelessWidget {
  /// 创建摄像头能力诊断面板。
  const AdminCameraCapabilityPanel({
    required this.previewCameraId,
    required this.previewStatus,
    required this.loading,
    this.capability,
    this.loadError = '',
    super.key,
  });

  /// 实时预览使用的 Flutter camera 设备 ID。
  final String previewCameraId;

  /// 当前预览状态，包含设备占用等运行期错误。
  final String previewStatus;

  /// 是否正在读取原生 Camera2 能力。
  final bool loading;

  /// 原生 Camera2 返回的只读能力快照。
  final CameraStreamCapability? capability;

  /// 不影响实时预览的能力读取错误。
  final String loadError;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final data = capability;
    final warning = _warningFor(context, data);
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
          Text(
            l10n.t('adminCameraCapabilityTitle', '摄像头能力（仅供诊断）'),
            style: const TextStyle(
              color: AppTheme.textPrimaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          _CapabilityLine(
            label: l10n.t('adminCameraPreviewStatusLabel', '预览状态'),
            value: previewStatus,
          ),
          _CapabilityLine(
            label: l10n.t('adminCameraPreviewIdLabel', '预览摄像头 ID'),
            value: previewCameraId,
          ),
          if (loading)
            _CapabilityLine(
              label: l10n.t('adminCameraCapabilityLabel', '设备能力'),
              value: l10n.t('adminCameraCapabilityReading', '正在读取...'),
            )
          else if (loadError.isNotEmpty)
            _CapabilityLine(
              label: l10n.t('adminCameraCapabilityLabel', '设备能力'),
              value: l10n.t('adminCameraCapabilityReadFailed', '读取失败'),
            )
          else if (data != null) ...[
            _CapabilityLine(
              label: l10n.t('adminCameraBoundIdLabel', '绑定 Camera2 ID'),
              value: data.configuredCameraId.isEmpty
                  ? l10n.t('adminStatusNotConfigured', '未配置')
                  : data.configuredCameraId,
            ),
            _CapabilityLine(
              label: l10n.t('adminCameraCurrentIdsLabel', '系统当前 ID'),
              value: data.availableCameraIds.isEmpty
                  ? l10n.t('adminCameraNotEnumerated', '未枚举到摄像头')
                  : data.availableCameraIds.join(', '),
            ),
            _CapabilityLine(
              label: l10n.t('adminCameraSupportedYuvLabel', '支持的 YUV 分辨率'),
              value: _supportedSizeText(context, data),
            ),
            _CapabilityLine(
              label: l10n.t('adminCameraStreamProfileLabel', '推流配置'),
              value: _configuredProfileText(context, data),
            ),
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

  /// 只把会影响当前配置的能力问题提升为警告，预览错误保持最高优先级。
  String _warningFor(BuildContext context, CameraStreamCapability? data) {
    final l10n = context.l10n;
    final previewErrorPrefix = l10n.t('adminCameraPreviewErrorPrefix', '预览异常');
    if (previewStatus.startsWith(previewErrorPrefix)) {
      return previewStatus;
    }
    if (loadError.isNotEmpty) {
      return l10n.t('adminCameraCapabilityReadWarning', '能力信息读取失败不会影响上方实时预览。');
    }
    if (data == null) {
      return '';
    }
    if (!data.available) {
      final detail = _safeCapabilityDetail(l10n, data);
      return detail.isNotEmpty
          ? detail
          : l10n.t(
              'adminCameraBoundUnavailable',
              '绑定的摄像头当前不可用，请检查接线、设备 ID 或是否被系统移除。',
            );
    }
    final incompatible = data.incompatibleProfiles;
    if (incompatible.isNotEmpty) {
      return l10n
          .t(
            'adminCameraUnsupportedProfiles',
            '不支持推流配置：{profiles}。收到推流请求时会在打开摄像头前停止，并返回明确错误。',
          )
          .replaceAll(
            '{profiles}',
            incompatible.map((item) => item.label).join(', '),
          );
    }
    if (data.errorMessage.isNotEmpty) {
      return _safeCapabilityDetail(l10n, data);
    }
    return '';
  }

  /// 压缩过长的分辨率列表，保留总数并避免诊断面板无限增高。
  String _supportedSizeText(BuildContext context, CameraStreamCapability data) {
    final l10n = context.l10n;
    if (data.supportedYuvSizes.isEmpty) {
      return l10n.t('adminCameraNoYuvSizes', '未获取到');
    }
    const visibleCount = 12;
    final visible = data.supportedYuvSizes.take(visibleCount);
    final suffix = data.supportedYuvSizes.length > visibleCount
        ? l10n
              .t('adminCameraAdditionalSizes', ' 等 {count} 种')
              .replaceAll('{count}', '${data.supportedYuvSizes.length}')
        : '';
    return '${visible.map((size) => size.label).join(', ')}$suffix';
  }

  /// 展示配置档位与能力检测的三态结果：支持、不支持或尚待确认。
  String _configuredProfileText(
    BuildContext context,
    CameraStreamCapability data,
  ) {
    final l10n = context.l10n;
    if (data.configuredProfiles.isEmpty) {
      return l10n.t('adminCameraNativeStreamUnused', '该角色不使用原生推流');
    }
    return data.configuredProfiles
        .map((profile) {
          final compatible = data.isProfileCompatible(profile);
          final state = switch (compatible) {
            true => l10n.t('adminCameraProfileSupported', '支持'),
            false => l10n.t('adminCameraProfileUnsupported', '不支持'),
            null => l10n.t('adminCameraProfilePending', '待确认'),
          };
          return '${profile.label} ($state)';
        })
        .join(', ');
  }

  /// 原生固定中文诊断不直接跨语言展示；优先使用稳定错误码。
  String _safeCapabilityDetail(
    AppLocalizations l10n,
    CameraStreamCapability data,
  ) {
    final detail = data.errorMessage.trim();
    final containsCjk = RegExp(
      r'[\u3400-\u9fff\u3040-\u30ff]',
    ).hasMatch(detail);
    if (detail.isNotEmpty &&
        (!containsCjk || l10n.language == AppLanguage.simplifiedChinese)) {
      return detail;
    }
    final code = data.errorCode.trim();
    if (code.isEmpty) {
      return '';
    }
    return l10n
        .t('adminCameraDiagnosticCode', '摄像头诊断代码：{code}')
        .replaceAll('{code}', code);
  }
}

/// 能力诊断面板中的紧凑键值行。
class _CapabilityLine extends StatelessWidget {
  const _CapabilityLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final separator = context.l10n.t('adminLabelSeparator', '：');
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label$separator',
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
