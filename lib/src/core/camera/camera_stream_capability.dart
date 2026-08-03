import 'dart:convert';

/// Camera YUV output size reported by Android Camera2.
class CameraYuvSize {
  /// Creates a YUV output size.
  const CameraYuvSize(this.width, this.height);

  /// Pixel width.
  final int width;

  /// Pixel height.
  final int height;

  /// Human-readable size.
  String get label => '$width×$height';

  @override
  bool operator ==(Object other) {
    return other is CameraYuvSize &&
        other.width == width &&
        other.height == height;
  }

  @override
  int get hashCode => Object.hash(width, height);
}

/// A configured stream profile shown in camera diagnostics.
class CameraConfiguredStreamProfile {
  /// Creates a configured stream profile.
  const CameraConfiguredStreamProfile({
    required this.name,
    this.size,
    this.compatible,
  });

  /// Profile name such as `720p`.
  final String name;

  /// Configured encoder size.
  final CameraYuvSize? size;

  /// Compatibility result supplied by the native preflight probe.
  final bool? compatible;

  /// Human-readable profile label.
  String get label {
    final configuredSize = size;
    return configuredSize == null ? name : '$name ${configuredSize.label}';
  }
}

/// Read-only Camera2 streaming capability diagnostics.
class CameraStreamCapability {
  /// Creates camera stream capability diagnostics.
  const CameraStreamCapability({
    required this.configuredCameraId,
    required this.availableCameraIds,
    required this.available,
    required this.supportedYuvSizes,
    required this.configuredProfiles,
    this.errorCode = '',
    this.errorMessage = '',
  });

  /// Camera2 ID configured for the business role.
  final String configuredCameraId;

  /// Camera2 IDs visible at the time of the probe.
  final List<String> availableCameraIds;

  /// Whether the configured Camera2 ID currently exists.
  final bool available;

  /// Exact `YUV_420_888` sizes reported by Camera2.
  final List<CameraYuvSize> supportedYuvSizes;

  /// Stream profiles configured by the application.
  final List<CameraConfiguredStreamProfile> configuredProfiles;

  /// Stable native diagnostic code, when capability probing failed.
  final String errorCode;

  /// Human-readable native diagnostic detail.
  final String errorMessage;

  /// Whether Camera2 could not reliably verify the physical connection.
  ///
  /// A missing/offline configured ID is a confirmed disconnection. Other
  /// access failures are reported as detection errors instead of pretending
  /// that enumeration alone proved a healthy connection.
  bool get hasConnectionProbeError {
    if (errorCode.isEmpty || errorCode == 'YUV_OUTPUT_UNAVAILABLE') {
      return false;
    }
    if (!available &&
        (errorCode == 'CAMERA_OFFLINE' ||
            errorCode == 'CAMERA_DISCONNECTED' ||
            errorCode == 'UNKNOWN_CAMERA_ID')) {
      return false;
    }
    return true;
  }

  /// Configured profiles that the camera explicitly does not support.
  List<CameraConfiguredStreamProfile> get incompatibleProfiles {
    return configuredProfiles
        .where((profile) => isProfileCompatible(profile) == false)
        .toList(growable: false);
  }

  /// Returns exact-size compatibility, or `null` when it cannot be verified.
  bool? isProfileCompatible(CameraConfiguredStreamProfile profile) {
    final nativeResult = profile.compatible;
    if (nativeResult != null) {
      return nativeResult;
    }
    final size = profile.size;
    if (size == null || supportedYuvSizes.isEmpty) {
      return null;
    }
    return supportedYuvSizes.contains(size);
  }

  /// Creates diagnostics from a platform-channel map.
  factory CameraStreamCapability.fromMap(Map<String, Object?> map) {
    final configuredCameraId = map['configuredCameraId']?.toString() ?? '';
    final availableCameraIds = _parseCameraIds(map['availableCameraIds']);
    final supportedYuvSizes = _parseCameraYuvSizes(
      map['supportedYuvSizes'] ?? map['yuvSupportedSizes'],
    );
    final configuredProfiles = _parseConfiguredProfiles(
      map['configuredProfiles'],
    );
    final explicitAvailable = _parseLooseBool(map['available']);
    final normalizedConfiguredId = _normalizeCameraId(configuredCameraId);
    final inferredAvailable =
        normalizedConfiguredId.isNotEmpty &&
        availableCameraIds.any(
          (id) => _normalizeCameraId(id) == normalizedConfiguredId,
        );
    return CameraStreamCapability(
      configuredCameraId: configuredCameraId,
      availableCameraIds: List.unmodifiable(availableCameraIds),
      available: explicitAvailable ?? inferredAvailable,
      supportedYuvSizes: List.unmodifiable(supportedYuvSizes),
      configuredProfiles: List.unmodifiable(configuredProfiles),
      errorCode: map['errorCode']?.toString() ?? '',
      errorMessage: map['errorMessage']?.toString() ?? '',
    );
  }
}

List<String> _parseCameraIds(Object? raw) {
  final values = <String>[];

  void add(Object? value) {
    if (value == null) {
      return;
    }
    if (value is Iterable) {
      for (final item in value) {
        add(item);
      }
      return;
    }
    if (value is Map) {
      add(value['id'] ?? value['cameraId'] ?? value['name']);
      return;
    }
    final text = value.toString().trim();
    if (text.isEmpty) {
      return;
    }
    final decoded = _tryDecodeJson(text);
    if (decoded is Iterable || decoded is Map) {
      add(decoded);
      return;
    }
    for (final token in text.split(RegExp(r'[,;|\s]+'))) {
      final id = token.trim();
      if (id.isNotEmpty && !values.contains(id)) {
        values.add(id);
      }
    }
  }

  add(raw);
  return values;
}

List<CameraYuvSize> _parseCameraYuvSizes(Object? raw) {
  final sizes = <CameraYuvSize>[];

  void addSize(int? width, int? height) {
    if (width == null || height == null || width <= 0 || height <= 0) {
      return;
    }
    final size = CameraYuvSize(width, height);
    if (!sizes.contains(size)) {
      sizes.add(size);
    }
  }

  void add(Object? value) {
    if (value == null) {
      return;
    }
    if (value is Iterable) {
      for (final item in value) {
        add(item);
      }
      return;
    }
    if (value is Map) {
      final width = int.tryParse(
        (value['width'] ?? value['w'] ?? '').toString(),
      );
      final height = int.tryParse(
        (value['height'] ?? value['h'] ?? '').toString(),
      );
      if (width != null && height != null) {
        addSize(width, height);
        return;
      }
      add(value['size'] ?? value['resolution']);
      return;
    }
    final text = value.toString().trim();
    final decoded = _tryDecodeJson(text);
    if (decoded is Iterable || decoded is Map) {
      add(decoded);
      return;
    }
    final matches = RegExp(r'(\d{2,5})\s*[xX×*]\s*(\d{2,5})').allMatches(text);
    for (final match in matches) {
      addSize(int.tryParse(match.group(1)!), int.tryParse(match.group(2)!));
    }
  }

  add(raw);
  return sizes;
}

List<CameraConfiguredStreamProfile> _parseConfiguredProfiles(Object? raw) {
  final profiles = <CameraConfiguredStreamProfile>[];

  void addProfile(String name, {CameraYuvSize? size, bool? compatible}) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return;
    }
    final existingIndex = profiles.indexWhere(
      (profile) => profile.name == trimmedName,
    );
    final profile = CameraConfiguredStreamProfile(
      name: trimmedName,
      size: size,
      compatible: compatible,
    );
    if (existingIndex >= 0) {
      profiles[existingIndex] = profile;
    } else {
      profiles.add(profile);
    }
  }

  void add(Object? value, {String? fallbackName}) {
    if (value == null) {
      return;
    }
    if (value is Iterable) {
      for (final item in value) {
        add(item);
      }
      return;
    }
    if (value is Map) {
      final name =
          (value['name'] ?? value['profile'] ?? value['videoType'])
              ?.toString() ??
          fallbackName ??
          '';
      final width = int.tryParse(
        (value['width'] ?? value['w'] ?? '').toString(),
      );
      final height = int.tryParse(
        (value['height'] ?? value['h'] ?? '').toString(),
      );
      CameraYuvSize? size;
      if (width != null && height != null) {
        size = CameraYuvSize(width, height);
      } else {
        final parsedSizes = _parseCameraYuvSizes(
          value['size'] ?? value['resolution'],
        );
        size = parsedSizes.isEmpty ? null : parsedSizes.first;
      }
      if (name.isNotEmpty) {
        addProfile(
          name,
          size: size,
          compatible: _parseLooseBool(value['compatible']),
        );
        return;
      }
      for (final entry in value.entries) {
        add(entry.value, fallbackName: entry.key.toString());
      }
      return;
    }
    final text = value.toString().trim();
    if (text.isEmpty) {
      return;
    }
    final decoded = _tryDecodeJson(text);
    if (decoded is Iterable || decoded is Map) {
      add(decoded, fallbackName: fallbackName);
      return;
    }
    final pattern = RegExp(
      r'([A-Za-z0-9_-]+)\s*[:=]?\s*(\d{2,5})\s*[xX×*]\s*(\d{2,5})',
    );
    final matches = pattern.allMatches(text);
    if (matches.isNotEmpty) {
      for (final match in matches) {
        addProfile(
          match.group(1)!,
          size: CameraYuvSize(
            int.parse(match.group(2)!),
            int.parse(match.group(3)!),
          ),
        );
      }
      return;
    }
    addProfile(fallbackName ?? text);
  }

  add(raw);
  return profiles;
}

bool? _parseLooseBool(Object? raw) {
  if (raw is bool) {
    return raw;
  }
  if (raw is num) {
    return raw != 0;
  }
  return switch (raw?.toString().trim().toLowerCase()) {
    'true' || '1' || 'yes' || 'available' => true,
    'false' || '0' || 'no' || 'unavailable' => false,
    _ => null,
  };
}

Object? _tryDecodeJson(String text) {
  if ((!text.startsWith('[') || !text.endsWith(']')) &&
      (!text.startsWith('{') || !text.endsWith('}'))) {
    return null;
  }
  try {
    return jsonDecode(text);
  } catch (_) {
    return null;
  }
}

String _normalizeCameraId(String value) {
  return value.startsWith('cameraId_')
      ? value.replaceFirst('cameraId_', '')
      : value;
}
