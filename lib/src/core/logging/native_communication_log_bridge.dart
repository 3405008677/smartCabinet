import 'dart:async';

import 'package:flutter/services.dart';

import 'package:smart_cabinet/src/core/logging/communication_log_store.dart';

/// 把 Android 原生层缓存的通讯事件汇入应用级通讯日志。
///
/// 原生层会先在进程内有界队列保存事件，因此页面稍后打开时仍能通过 `snapshot`
/// 取得启动期日志。桥接先订阅实时事件再读取快照，并使用 nativeId 去重，避免两段
/// 时间窗口交叠时重复展示。
class NativeCommunicationLogBridge {
  /// 创建使用固定原生通道的桥接器。
  NativeCommunicationLogBridge({
    CommunicationLogStore? store,
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _store = store ?? CommunicationLogStore.instance,
       _methodChannel =
           methodChannel ??
           const MethodChannel('smart_cabinet/communication_log'),
       _eventChannel =
           eventChannel ??
           const EventChannel('smart_cabinet/communication_log/events');

  /// 应用级原生通讯日志桥接器。
  static final NativeCommunicationLogBridge instance =
      NativeCommunicationLogBridge();

  final CommunicationLogStore _store;
  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  final Set<int> _importedNativeIds = <int>{};
  StreamSubscription<Object?>? _eventsSubscription;
  Future<void>? _starting;

  /// 启动实时订阅并导入原生启动期快照；重复调用只执行一次。
  Future<void> ensureStarted() {
    final current = _starting;
    if (current != null) {
      return current;
    }
    final operation = _start();
    _starting = operation;
    return operation;
  }

  /// 先建立实时订阅，再导入原生有界队列的启动期快照。
  Future<void> _start() async {
    try {
      _eventsSubscription ??= _eventChannel.receiveBroadcastStream().listen(
        _importDynamicEvent,
        onError: (Object _) {
          // 缺少原生实现时保持 Dart 日志可用；诊断桥本身不能递归写通讯日志。
        },
      );
      final snapshot = await _methodChannel.invokeListMethod<Object?>(
        'snapshot',
      );
      if (snapshot == null) {
        return;
      }
      for (final event in snapshot) {
        _importDynamicEvent(event);
      }
    } on MissingPluginException {
      // Web、桌面和纯 Widget 测试没有 Android 插件，Dart 日志仍独立工作。
    } on PlatformException {
      // 原生快照暂不可用时不影响管理员页打开和 Dart 通讯主流程。
    } catch (_) {
      // 非标准平台返回或测试替身异常同样不能阻断通讯日志页面。
    }
  }

  /// 导入一条原生事件，无法识别的字段会被安全忽略。
  void _importDynamicEvent(Object? event) {
    try {
      if (event is! Map) {
        return;
      }
      final map = event.map<String, Object?>((key, value) {
        return MapEntry<String, Object?>(key.toString(), value);
      });
      final nativeId = _intValue(map['nativeId']);
      if (nativeId == null || _importedNativeIds.contains(nativeId)) {
        return;
      }
      final targetType = switch (map['targetType']?.toString()) {
        'server' => CommunicationTargetType.server,
        'hardware' => CommunicationTargetType.hardware,
        'upgradeCommand' => CommunicationTargetType.upgradeCommand,
        _ => null,
      };
      final direction = switch (map['direction']?.toString()) {
        'outbound' => CommunicationDirection.outbound,
        'inbound' => CommunicationDirection.inbound,
        _ => null,
      };
      if (targetType == null || direction == null) {
        return;
      }
      final epoch = _intValue(map['requestTimeEpochMs']);
      final importedId = _store.tryRecord(
        targetType: targetType,
        direction: direction,
        channel: map['channel']?.toString() ?? 'Android native',
        operation: map['operation']?.toString() ?? 'native event',
        messageBody: map['messageBody'],
        requestTime: epoch == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(epoch),
        result: map['result']?.toString() ?? '成功',
      );
      if (importedId == null) {
        return;
      }
      _importedNativeIds.add(nativeId);
      if (_importedNativeIds.length > 2000) {
        _importedNativeIds.remove(_importedNativeIds.first);
      }
    } catch (_) {
      // 非标准事件只丢弃当前项，不能让 EventChannel 回调形成未处理异常。
    }
  }

  /// 释放独立测试桥接器的实时订阅。
  Future<void> dispose() async {
    await _eventsSubscription?.cancel();
    _eventsSubscription = null;
  }
}

/// 把平台通道的数字或数字文本收敛为 int。
int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}
