import 'package:flutter/material.dart';

import 'package:smart_cabinet/src/app/bootstrap/bootstrap.dart';
import 'package:smart_cabinet/src/app/startup/startup_task.dart';

/// 启动失败时展示的兜底应用。
///
/// 关键启动任务失败时不进入主业务界面，避免设备在不稳定状态下继续运行。
class StartupFailureApp extends StatefulWidget {
  /// 创建启动失败兜底应用。
  const StartupFailureApp({required this.result, super.key});

  /// 启动结果。
  final StartupResult result;

  @override
  State<StartupFailureApp> createState() => _StartupFailureAppState();
}

class _StartupFailureAppState extends State<StartupFailureApp> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) {
      return;
    }
    setState(() => _retrying = true);
    try {
      await retryBootstrap();
    } finally {
      if (mounted) {
        setState(() => _retrying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final failure = widget.result.firstRequiredFailure;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF111827),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '系统启动失败',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '关键功能未准备完成，系统已阻止进入主界面。请检查硬件连接后重试。',
                          style: TextStyle(
                            fontSize: 18,
                            height: 1.5,
                            color: Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (failure != null) _FailureSummary(failure: failure),
                        const SizedBox(height: 24),
                        _TaskResultList(results: widget.result.taskResults),
                        const SizedBox(height: 28),
                        FilledButton.icon(
                          onPressed: _retrying ? null : _retry,
                          icon: _retrying
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded),
                          label: const Text('重新启动检测'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FailureSummary extends StatelessWidget {
  const _FailureSummary({required this.failure});

  final StartupTaskResult failure;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '失败任务：${failure.name}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF7F1D1D),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '错误原因：${_readableErrorMessage(failure.error)}',
              style: const TextStyle(fontSize: 15, color: Color(0xFF7F1D1D)),
            ),
          ],
        ),
      ),
    );
  }

  String _readableErrorMessage(Object? error) {
    final message = error?.toString() ?? '未知错误';
    if (message.contains('Device reporting less cameras than anticipated') ||
        message.contains('Available cameras: 0') ||
        message.contains('未检测到可用摄像头')) {
      return '未检测到可用摄像头。请确认摄像头已连接、系统相机权限正常，并重启检测。';
    }
    if (message.length <= 180) {
      return message;
    }
    return '${message.substring(0, 180)}...';
  }
}

class _TaskResultList extends StatelessWidget {
  const _TaskResultList({required this.results});

  final List<StartupTaskResult> results;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '启动任务结果',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        for (final result in results) _TaskResultTile(result: result),
      ],
    );
  }
}

class _TaskResultTile extends StatelessWidget {
  const _TaskResultTile({required this.result});

  final StartupTaskResult result;

  @override
  Widget build(BuildContext context) {
    final succeeded = result.succeeded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            succeeded ? Icons.check_circle_rounded : Icons.error_rounded,
            color: succeeded
                ? const Color(0xFF047857)
                : const Color(0xFFDC2626),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${result.name} · ${result.duration.inMilliseconds}ms',
              style: const TextStyle(fontSize: 15, color: Color(0xFF111827)),
            ),
          ),
        ],
      ),
    );
  }
}
