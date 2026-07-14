import 'dart:async';

import 'package:flutter/material.dart';

import 'package:smart_cabinet/src/app/theme/app_theme.dart';

enum MessageType { info, success, warning, error, loading }

class MessageHandle {
  const MessageHandle._(this._close);

  final VoidCallback _close;

  void close() => _close();
}

class Message {
  Message._();

  static const Duration defaultDuration = Duration(seconds: 2);
  static const double defaultTop = 32;
  static const double defaultMaxWidth = 440;

  static final List<_MessageRecord> _records = [];

  static MessageHandle info(
    BuildContext context,
    String text, {
    Duration? duration = defaultDuration,
  }) {
    return show(context, text, type: MessageType.info, duration: duration);
  }

  static MessageHandle success(
    BuildContext context,
    String text, {
    Duration? duration = defaultDuration,
  }) {
    return show(context, text, type: MessageType.success, duration: duration);
  }

  static MessageHandle warning(
    BuildContext context,
    String text, {
    Duration? duration = defaultDuration,
  }) {
    return show(context, text, type: MessageType.warning, duration: duration);
  }

  static MessageHandle error(
    BuildContext context,
    String text, {
    Duration? duration = defaultDuration,
  }) {
    return show(context, text, type: MessageType.error, duration: duration);
  }

  static MessageHandle loading(
    BuildContext context,
    String text, {
    Duration? duration,
  }) {
    return show(context, text, type: MessageType.loading, duration: duration);
  }

  static MessageHandle show(
    BuildContext context,
    String text, {
    MessageType type = MessageType.info,
    Duration? duration = defaultDuration,
    double top = defaultTop,
    double maxWidth = defaultMaxWidth,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    return showInOverlay(
      overlay,
      text,
      type: type,
      duration: duration,
      top: top,
      maxWidth: maxWidth,
    );
  }

  static MessageHandle showInOverlay(
    OverlayState overlay,
    String text, {
    MessageType type = MessageType.info,
    Duration? duration = defaultDuration,
    double top = defaultTop,
    double maxWidth = defaultMaxWidth,
  }) {
    final id = Object();
    late final OverlayEntry entry;

    void close() {
      final index = _records.indexWhere((record) => record.id == id);
      if (index == -1) {
        return;
      }
      final record = _records.removeAt(index);
      record.entry.remove();
      _markNeedsBuild();
    }

    entry = OverlayEntry(
      builder: (context) {
        final index = _records.indexWhere((record) => record.id == id);
        final offset = index < 0 ? 0 : index;

        return _MessagePositioned(
          top: top + offset * 62,
          maxWidth: maxWidth,
          child: _MessageToast(
            key: ValueKey(id),
            text: text,
            type: type,
            duration: duration,
            onClose: close,
          ),
        );
      },
    );

    _records.add(_MessageRecord(id: id, entry: entry));
    overlay.insert(entry);
    _markNeedsBuild();

    return MessageHandle._(close);
  }

  static void closeAll() {
    final records = List<_MessageRecord>.of(_records);
    _records.clear();
    for (final record in records) {
      record.entry.remove();
    }
  }

  static void _markNeedsBuild() {
    for (final record in _records) {
      record.entry.markNeedsBuild();
    }
  }
}

class _MessageRecord {
  const _MessageRecord({required this.id, required this.entry});

  final Object id;
  final OverlayEntry entry;
}

class _MessagePositioned extends StatelessWidget {
  const _MessagePositioned({
    required this.top,
    required this.maxWidth,
    required this.child,
  });

  final double top;
  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: IgnorePointer(
        ignoring: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _MessageToast extends StatefulWidget {
  const _MessageToast({
    required this.text,
    required this.type,
    required this.duration,
    required this.onClose,
    super.key,
  });

  final String text;
  final MessageType type;
  final Duration? duration;
  final VoidCallback onClose;

  @override
  State<_MessageToast> createState() => _MessageToastState();
}

class _MessageToastState extends State<_MessageToast> {
  bool _visible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _visible = true);
      }
    });
    final duration = widget.duration;
    if (duration != null) {
      _timer = Timer(duration, _close);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _close() {
    if (!mounted || !_visible) {
      widget.onClose();
      return;
    }
    setState(() => _visible = false);
    Timer(const Duration(milliseconds: 180), widget.onClose);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _MessageColors.resolve(widget.type);

    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, -.18),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: Material(
          color: Colors.transparent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A0F172A),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MessageIcon(type: widget.type, color: colors.foreground),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      widget.text,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _close,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: colors.foreground.withValues(alpha: .75),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageIcon extends StatelessWidget {
  const _MessageIcon({required this.type, required this.color});

  final MessageType type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (type == MessageType.loading) {
      return SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    }

    return Icon(_iconData, size: 20, color: color);
  }

  IconData get _iconData {
    return switch (type) {
      MessageType.success => Icons.check_circle_rounded,
      MessageType.warning => Icons.warning_amber_rounded,
      MessageType.error => Icons.cancel_rounded,
      MessageType.info || MessageType.loading => Icons.info_rounded,
    };
  }
}

class _MessageColors {
  const _MessageColors({
    required this.background,
    required this.border,
    required this.foreground,
    required this.text,
  });

  final Color background;
  final Color border;
  final Color foreground;
  final Color text;

  static _MessageColors resolve(MessageType type) {
    return switch (type) {
      MessageType.success => const _MessageColors(
        background: Color(0xFFEFFAF2),
        border: Color(0xFFBEE9C8),
        foreground: Color(0xFF1F9D55),
        text: Color(0xFF14532D),
      ),
      MessageType.warning => const _MessageColors(
        background: Color(0xFFFFF8E6),
        border: Color(0xFFF7D88A),
        foreground: Color(0xFFD97706),
        text: Color(0xFF7C2D12),
      ),
      MessageType.error => const _MessageColors(
        background: Color(0xFFFFF1F2),
        border: Color(0xFFFFC4C9),
        foreground: Color(0xFFE11D48),
        text: Color(0xFF7F1D1D),
      ),
      MessageType.info || MessageType.loading => const _MessageColors(
        background: AppTheme.primarySoftColor,
        border: AppTheme.primaryBorderColor,
        foreground: AppTheme.primaryColor,
        text: AppTheme.primaryStrongColor,
      ),
    };
  }
}
