import 'dart:async';

import 'package:flutter/material.dart';

import 'package:smart_cabinet/src/app/localization/app_localizations.dart';
import 'package:smart_cabinet/src/features/home/data/repositories/home_repository_impl.dart';

/// Returns the delay to the next wall-clock minute boundary.
@visibleForTesting
Duration terminalClockDelayUntilNextMinute(DateTime now) {
  final nextMinute = DateTime(
    now.year,
    now.month,
    now.day,
    now.hour,
    now.minute + 1,
  );
  return nextMinute.difference(now);
}

/// 智能柜终端的全局页面外壳。
///
/// 任何业务页面都放在这个外壳中显示，这样顶部设备信息、当前时间、
/// 底部安全状态和版本号就能在所有页面保持一致。
class TerminalShell extends StatefulWidget {
  /// 创建终端页面外壳。
  const TerminalShell({
    required this.child,
    this.topBarLeading,
    this.topRightBadge,
    this.onVersionTap,
    super.key,
  });

  /// 页面主体内容。
  final Widget child;

  /// 顶部信息栏下方左侧的页面操作区。
  ///
  /// 例如取件验证页的“返回 / 安全身份验证 / 取件”信息。
  final Widget? topBarLeading;

  /// 顶部信息栏下方右侧的小状态标签。
  ///
  /// 例如取件流程中可以显示“四重认证通过 · 取件”。
  final Widget? topRightBadge;

  /// 点击底部版本号时执行的动作。
  final VoidCallback? onVersionTap;

  @override
  State<TerminalShell> createState() => _TerminalShellState();
}

class _TerminalShellState extends State<TerminalShell> {
  /// 当前柜体编号。
  String _cabinetCode = 'CAB-A01';

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  /// 加载顶部壳层展示数据。
  Future<void> _loadHomeData() async {
    final data = await homeRepository.fetchHomeData();
    if (!mounted) {
      return;
    }
    setState(() => _cabinetCode = data.cabinetCode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 1280,
            height: 800,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFB9C8F5)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x140B1F4D),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _GlobalHeader(cabinetCode: _cabinetCode),
                  if (widget.topBarLeading != null ||
                      widget.topRightBadge != null)
                    _SubHeader(
                      leading: widget.topBarLeading,
                      topRightBadge: widget.topRightBadge,
                    ),
                  Expanded(child: widget.child),
                  _GlobalFooter(onVersionTap: widget.onVersionTap),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 顶部全局信息栏。
class _GlobalHeader extends StatelessWidget {
  const _GlobalHeader({required this.cabinetCode});

  /// 当前柜体编号。
  final String cabinetCode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 86,
      padding: const EdgeInsets.only(left: 40, right: 40),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFF),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F6))),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.t('appTitle', '智能文件保管柜'),
                style: const TextStyle(
                  color: Color(0xFF17213D),
                  fontSize: 14,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Intelligent Document Cabinet · $cabinetCode',
                style: const TextStyle(
                  color: Color(0xFF6E7CA7),
                  fontSize: 13,
                  height: 1,
                  letterSpacing: .4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Spacer(),
          _GlobalClock(language: l10n.language),
        ],
      ),
    );
  }

  /// 按当前语言格式化顶部日期文本。
  static String _dateText(DateTime time, AppLanguage language) {
    const englishWeekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const chineseWeekdays = ['一', '二', '三', '四', '五', '六', '日'];
    const japaneseWeekdays = ['月', '火', '水', '木', '金', '土', '日'];

    String two(int value) => value.toString().padLeft(2, '0');

    return switch (language) {
      AppLanguage.simplifiedChinese =>
        '${time.year}年${time.month}月${time.day}日周${chineseWeekdays[time.weekday - 1]}',
      AppLanguage.traditionalChinese =>
        '${time.year}年${time.month}月${time.day}日週${chineseWeekdays[time.weekday - 1]}',
      AppLanguage.english =>
        '${time.year}-${two(time.month)}-${two(time.day)} ${englishWeekdays[time.weekday - 1]}',
      AppLanguage.japanese =>
        '${time.year}年${time.month}月${time.day}日(${japaneseWeekdays[time.weekday - 1]})',
    };
  }

  /// 把时间格式化成 `HH:mm`。
  static String _timeText(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}';
  }
}

class _GlobalClock extends StatefulWidget {
  const _GlobalClock({required this.language});

  final AppLanguage language;

  @override
  State<_GlobalClock> createState() => _GlobalClockState();
}

class _GlobalClockState extends State<_GlobalClock> {
  DateTime _now = DateTime.now();
  Timer? _timer;
  bool _tickerEnabled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    if (_tickerEnabled == tickerEnabled) {
      return;
    }
    _tickerEnabled = tickerEnabled;
    if (!tickerEnabled) {
      _timer?.cancel();
      _timer = null;
      return;
    }

    _now = DateTime.now();
    _scheduleNextMinute();
  }

  /// 只在下一分钟边界唤醒一次。
  ///
  /// 使用连续的一次性定时器而不是周期定时器，可以避免计时漂移，也不会为了
  /// 不显示的“秒”字段每秒提交一整帧。
  void _scheduleNextMinute() {
    _timer?.cancel();
    final now = DateTime.now();
    _timer = Timer(terminalClockDelayUntilNextMinute(now), _onMinuteBoundary);
  }

  void _onMinuteBoundary() {
    if (!mounted || !_tickerEnabled) {
      return;
    }
    setState(() => _now = DateTime.now());
    _scheduleNextMinute();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _GlobalHeader._dateText(_now, widget.language),
            style: const TextStyle(
              color: Color(0xFFA7B0CC),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _GlobalHeader._timeText(_now),
            style: const TextStyle(
              color: Color(0xFF1B2340),
              fontSize: 22,
              height: 1,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 顶部和主体之间的辅助栏。
class _SubHeader extends StatelessWidget {
  const _SubHeader({required this.leading, required this.topRightBadge});

  /// 左侧页面操作区。
  final Widget? leading;

  /// 右侧流程状态徽标。
  final Widget? topRightBadge;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFF),
        border: Border(bottom: BorderSide(color: Color(0xFFEAF0FA))),
      ),
      child: Row(children: [?leading, const Spacer(), ?topRightBadge]),
    );
  }
}

/// 底部全局状态栏。
class _GlobalFooter extends StatelessWidget {
  const _GlobalFooter({this.onVersionTap});

  /// 点击底部版本号时执行的动作。
  final VoidCallback? onVersionTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFF),
        border: Border(top: BorderSide(color: Color(0xFFE4EAF6))),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, color: Color(0xFF7580A8), size: 16),
                SizedBox(width: 9),
                Text(
                  '银行级加密保护',
                  style: TextStyle(
                    color: Color(0xFF7580A8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _StatusDot(),
              const SizedBox(width: 9),
              Text(
                '所有系统正常运行',
                style: TextStyle(
                  color: Color(0xFF7580A8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              key: const ValueKey('terminal_version_tap_target'),
              behavior: HitTestBehavior.opaque,
              onTap: onVersionTap,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'v2.4.1',
                  style: TextStyle(
                    color: Color(0xFFA7B0CC),
                    fontSize: 12,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 绿色状态圆点。
class _StatusDot extends StatelessWidget {
  const _StatusDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Color(0xFF6FC76A),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// 蓝色业务状态徽标。
class FlowStatusBadge extends StatelessWidget {
  /// 创建业务状态徽标。
  const FlowStatusBadge({required this.text, super.key});

  /// 徽标显示文案。
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.primary.withValues(alpha: .22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_user_outlined,
            color: colorScheme.primary,
            size: 15,
          ),
          const SizedBox(width: 7),
          Text(
            text,
            style: TextStyle(
              color: colorScheme.primary,
              fontSize: 13,
              height: 1,
              letterSpacing: .4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
