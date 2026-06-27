import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/app_localizations.dart';
import '../../core/device/device_info_service.dart';
import '../../core/storage/app_local_store_provider.dart';
import '../../models/home_model.dart';
import '../../repositories/admin_repository.dart';
import '../../repositories/home_repository.dart';
import '../../shared/widgets/terminal_shell.dart';
import 'app_router.dart';

/// 智能柜新首页。
///
/// 参考 `智能柜首页模板2.png` 的模块化首页：上方展示柜体和成品 banner，
/// 下方展示统计、存取件入口和飞检操作。
class SmartCabinetHomePage extends StatefulWidget {
  /// 创建智能柜新首页。
  const SmartCabinetHomePage({super.key});

  @override
  State<SmartCabinetHomePage> createState() => _SmartCabinetHomePageState();
}

class _SmartCabinetHomePageState extends State<SmartCabinetHomePage> {
  /// 首页展示数据。
  ///
  /// 先使用一份同步默认值作为首帧兜底，避免异步接口尚未返回时页面空白。
  HomeModel _homeData = HomeModel.fromMap(const {
    'cabinetCode': 'CAB-A01',
    'region': 'A · B 区',
    'status': '在线运行',
    'headline': '智能柜统计信息',
    'stats': {
      'documentCount': '12 份',
      'occupiedSlots': '6 / 12',
      'pendingPickup': '3 份',
      'todayStored': '5 份',
      'todayPickedUp': '2 份',
      'occupancyRateText': '50%',
      'occupancyRateValue': 0.5,
    },
    'footer': {
      'statusSummary': 'CAB-A01 · 在线',
      'doorStatus': '柜门已锁定',
      'slotSummary': '格位 A·B 区 · 共 12 个',
    },
  });

  /// 底部版本号连续点击次数。
  int _versionTapCount = 0;

  @override
  void initState() {
    super.initState();

    /// 页面初始化后异步加载首页数据，并用真实返回覆盖默认兜底值。
    _loadHomeData();
  }

  /// 加载首页展示数据。
  ///
  /// 当前通过 Repository 读取模拟接口数据，后续可以无感替换为真实后端返回。
  Future<void> _loadHomeData() async {
    final data = await homeRepository.fetchHomeData();
    if (!mounted) {
      return;
    }
    setState(() => _homeData = data);
  }

  /// 连续点击底部版本号 8 次后打开隐藏设置列表。
  void _handleVersionTap() {
    _versionTapCount += 1;
    if (_versionTapCount < 8) {
      return;
    }

    _versionTapCount = 0;
    _showSettingsDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    return TerminalShell(
      onVersionTap: _handleVersionTap,
      child: CustomPaint(
        painter: const _DotGridPainter(),
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFEAF2FF), Color(0xFFF7FAFF)],
            ),
          ),
          child: _DashboardBody(
            homeData: _homeData,
            onCabinetModelTap: _handleVersionTap,
          ),
        ),
      ),
    );
  }
}

/// 首页内容区整体布局。
///
/// 负责组织顶部柜体信息与 banner、主体功能卡片以及底部状态栏。
class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.homeData,
    required this.onCabinetModelTap,
  });

  /// 首页展示数据。
  final HomeModel homeData;

  /// 点击左上角柜体模型时执行的隐藏入口动作。
  final VoidCallback onCabinetModelTap;

  @override
  Widget build(BuildContext context) {
    /// 整个首页主体区由顶部柜体信息、主功能区和底部状态摘要三部分组成。
    return Padding(
      /// 设置 padding的
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      child: Column(
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: 128,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CabinetOverviewCard(
                  homeData: homeData,
                  onCabinetModelTap: onCabinetModelTap,
                ),
                const SizedBox(width: 16),
                Expanded(child: _FinishedBannerCard(homeData: homeData)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StorageStatsCard(homeData: homeData),
                const SizedBox(width: 16),
                Expanded(
                  child: _AccessEntryCard(
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(AppRoutes.foundationHome),
                  ),
                ),
                const SizedBox(width: 16),
                const SizedBox(width: 213, child: _InspectionCard()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 当前柜体展示卡片。
class _CabinetOverviewCard extends StatelessWidget {
  const _CabinetOverviewCard({
    required this.homeData,
    required this.onCabinetModelTap,
  });

  /// 首页展示数据。
  final HomeModel homeData;

  /// 点击柜体模型时执行的隐藏入口动作。
  final VoidCallback onCabinetModelTap;

  @override
  Widget build(BuildContext context) {
    /// 当前语言下的首页文案入口。
    final l10n = context.l10n;

    return _DashboardCard(
      width: 292,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: Row(
        children: [
          SizedBox(
            width: 94,
            height: double.infinity,
            child: GestureDetector(
              key: const ValueKey('cabinet_model_tap_target'),
              behavior: HitTestBehavior.opaque,
              onTap: onCabinetModelTap,
              child: const _CabinetModelViewer(),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.t('currentCabinet', '当前柜体'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111936),
                    fontSize: 18,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                _InfoLine(
                  label: l10n.t('cabinetCode', '编号'),
                  value: homeData.cabinetCode,
                ),
                const SizedBox(height: 5),
                _InfoLine(
                  label: l10n.t('cabinetRegion', '区域'),
                  value: homeData.region,
                ),
                const SizedBox(height: 5),
                _InfoLine(
                  label: l10n.t('cabinetStatus', '状态'),
                  value: homeData.status,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 柜体概览中的单行键值信息。
class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  /// 左侧标签文本，例如编号、区域、状态。
  final String label;

  /// 右侧展示值。
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF8C98B8),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF334166),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

/// 成品 banner 展示区。
class _FinishedBannerCard extends StatelessWidget {
  const _FinishedBannerCard({required this.homeData});

  /// 首页展示数据。
  final HomeModel homeData;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF0F766E), Color(0xFF22C55E)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A047857),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: 92,
            top: -26,
            child: _GlowCircle(size: 138, opacity: .12),
          ),
          Positioned(
            right: -24,
            bottom: -58,
            child: _GlowCircle(size: 160, opacity: .12),
          ),
          Positioned(
            right: 58,
            top: 31,
            child: Icon(
              Icons.verified_user_outlined,
              color: Colors.white.withValues(alpha: .16),
              size: 76,
            ),
          ),
          Positioned(
            left: 30,
            top: 24,
            child: _SmallPill(text: l10n.t('safeTip', '安全提示')),
          ),
          Positioned(
            left: 30,
            top: 58,
            child: Text(
              homeData.headline,
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Positioned(
            left: 30,
            top: 94,
            child: Text(
              l10n.t('bannerSubtitle', '存取流程优化 · 异常实时预警 · 全程安全追溯'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Positioned(right: 26, bottom: 16, child: _BannerMetrics()),
        ],
      ),
    );
  }
}

/// banner 右下角的核心指标集合。
class _BannerMetrics extends StatelessWidget {
  const _BannerMetrics();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      children: [
        _MetricPill(label: l10n.t('todayFlow', '今日流转'), value: '7'),
        const SizedBox(width: 10),
        _MetricPill(label: l10n.t('freeSlots', '空闲格口'), value: '6'),
        const SizedBox(width: 10),
        _MetricPill(label: l10n.t('pending', '待处理'), value: '3'),
      ],
    );
  }
}

/// banner 内用于展示单个指标的胶囊标签。
class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  /// 指标名称。
  final String label;

  /// 指标数值。
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: .18)),
      ),
      child: Row(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .86),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// banner 背景中的半透明光斑装饰。
class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.opacity});

  /// 光斑直径。
  final double size;

  /// 白色填充的不透明度。
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// 小型圆角提示标签。
class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.text});

  /// 标签显示文本。
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// 存储统计卡片。
class _StorageStatsCard extends StatelessWidget {
  const _StorageStatsCard({required this.homeData});

  /// 首页展示数据。
  final HomeModel homeData;

  @override
  Widget build(BuildContext context) {
    final stats = homeData.stats;
    final l10n = context.l10n;

    return _DashboardCard(
      width: 292,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.inventory_2_outlined,
            text: l10n.t('storageStats', '存储统计'),
          ),
          const SizedBox(height: 12),
          _StatRow(
            icon: Icons.description_outlined,
            label: l10n.t('cabinetFiles', '柜内文件'),
            value: stats.documentCount,
            color: const Color(0xFF2F64F6),
          ),
          const SizedBox(height: 7),
          _StatRow(
            icon: Icons.view_in_ar_outlined,
            label: l10n.t('usedSlots', '已用格位'),
            value: stats.occupiedSlots,
            color: const Color(0xFF7C3AED),
          ),
          const SizedBox(height: 7),
          _StatRow(
            icon: Icons.mark_email_unread_outlined,
            label: l10n.t('pendingPickup', '待取件'),
            value: stats.pendingPickup,
            color: const Color(0xFFE05252),
          ),
          const SizedBox(height: 7),
          _StatRow(
            icon: Icons.trending_up_rounded,
            label: l10n.t('todayStored', '今日存入'),
            value: stats.todayStored,
            color: const Color(0xFF059669),
          ),
          const SizedBox(height: 7),
          _StatRow(
            icon: Icons.file_download_outlined,
            label: l10n.t('todayPickedUp', '今日取出'),
            value: stats.todayPickedUp,
            color: const Color(0xFF0891B2),
          ),
          const Spacer(),
          Row(
            children: [
              Text(
                l10n.t('occupancyRate', '格位占用率'),
                style: const TextStyle(
                  color: Color(0xFF6877A2),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                stats.occupancyRateText,
                style: const TextStyle(
                  color: Color(0xFF4664E9),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: stats.occupancyRateValue,
              minHeight: 6,
              backgroundColor: const Color(0xFFE6EAF5),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF7C3AED),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 卡片区域标题，包含图标和标题文本。
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.text});

  /// 标题左侧图标。
  final IconData icon;

  /// 标题文本。
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF2F64F6), size: 17),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF111936),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// 存储统计卡片中的单条统计信息。
class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  /// 统计项图标。
  final IconData icon;

  /// 统计项名称。
  final String label;

  /// 统计项数值。
  final String value;

  /// 统计项强调色，用于图标、数值和浅色背景。
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF6877A2),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/// 存取件主入口。
class _AccessEntryCard extends StatelessWidget {
  const _AccessEntryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return _DashboardCard(
      width: double.infinity,
      padding: EdgeInsets.zero,
      borderColor: const Color(0xFF2F64F6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2F64F6).withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.move_to_inbox_outlined,
                        color: Color(0xFF2F64F6),
                        size: 42,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      l10n.t('access', '存取件'),
                      style: const TextStyle(
                        color: Color(0xFF020817),
                        fontSize: 38,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'DEPOSIT & PICKUP',
                      style: TextStyle(
                        color: Color(0xFF2F64F6),
                        fontSize: 13,
                        height: 1,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      l10n.t('accessDescription', '进入存件 / 取件业务入口'),
                      style: const TextStyle(
                        color: Color(0xFF4C5E8B),
                        fontSize: 15,
                        height: 1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2F64F6).withValues(alpha: .06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF2F64F6).withValues(alpha: .16),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.t('start', '开始办理'),
                            style: const TextStyle(
                              color: Color(0xFF2F64F6),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 7),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF2F64F6),
                            size: 19,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 飞检操作入口。
class _InspectionCard extends StatelessWidget {
  const _InspectionCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return _DashboardCard(
      width: 132,
      padding: EdgeInsets.zero,
      borderColor: const Color(0xFF0891B2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(
            context,
          ).pushNamed(AppRoutes.flightInspectionVerification),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0891B2).withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.fact_check_outlined,
                    color: Color(0xFF0891B2),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.t('inspection', '飞检操作'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF020817),
                    fontSize: 22,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.t('tapStart', '点击开始 →'),
                  style: const TextStyle(
                    color: Color(0xFFA7B0CC),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 弹出设置窗口。
void _showSettingsDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _SettingsDialog(),
  );
}

/// 首页设置弹窗。
class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog();

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE4EAF6)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x24111B3D),
                blurRadius: 28,
                offset: Offset(0, 18),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 22, 18, 18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xFF17213D), Color(0xFF2F64F6)],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.settings_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.t('settings', '设置'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              height: 1,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.t('settingsSubtitle', '设备偏好与本地显示配置'),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .76),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.t('close', '关闭'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LanguageSettingRow(
                      selectedLanguage: appLocaleController.language,
                      onChanged: (language) {
                        if (language == null) {
                          return;
                        }

                        appLocaleController.setLanguage(language);
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 14),
                    _AdminModeSettingRow(
                      onTap: () {
                        Navigator.of(context).pop();
                        _showAdminLoginDialog(context);
                      },
                    ),
                    const SizedBox(height: 14),
                    _AboutDeviceSettingRow(
                      onTap: () => _showAboutDeviceDialog(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 设置列表中的管理员模式入口行。
class _AdminModeSettingRow extends StatelessWidget {
  const _AdminModeSettingRow({required this.onTap});

  /// 点击管理员模式入口时执行的动作。
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FAFF),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE4EAF6)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF2F64F6).withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: Color(0xFF2F64F6),
                  size: 21,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  l10n.t('adminMode', '管理员模式'),
                  style: const TextStyle(
                    color: Color(0xFF17213D),
                    fontSize: 16,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF7A86A8),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 设置列表中的关于设备入口行。
class _AboutDeviceSettingRow extends StatelessWidget {
  const _AboutDeviceSettingRow({required this.onTap});

  /// 点击关于设备入口时执行的动作。
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FAFF),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE4EAF6)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF2F64F6).withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.memory_rounded,
                  color: Color(0xFF2F64F6),
                  size: 21,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('aboutDevice', '关于设备'),
                      style: const TextStyle(
                        color: Color(0xFF17213D),
                        fontSize: 16,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.t('aboutDeviceHint', '查看当前主板与系统信息'),
                      style: const TextStyle(
                        color: Color(0xFF7A86A8),
                        fontSize: 12,
                        height: 1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF7A86A8),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 弹出关于设备窗口。
void _showAboutDeviceDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => const _AboutDeviceDialog(),
  );
}

/// 关于设备弹窗。
class _AboutDeviceDialog extends StatefulWidget {
  const _AboutDeviceDialog();

  @override
  State<_AboutDeviceDialog> createState() => _AboutDeviceDialogState();
}

class _AboutDeviceDialogState extends State<_AboutDeviceDialog> {
  /// 设备信息加载任务。
  late final Future<List<DeviceInfoItem>> _deviceInfoFuture;

  @override
  void initState() {
    super.initState();
    _deviceInfoFuture = _loadCachedDeviceInfo();
  }

  /// 从本地 Store 读取启动阶段缓存的设备信息。
  Future<List<DeviceInfoItem>> _loadCachedDeviceInfo() async {
    final providerContainer = ProviderScope.containerOf(context, listen: false);
    final store = await providerContainer.read(appLocalStoreProvider.future);
    final deviceInfo = (await store.state()).deviceInfo;

    if (deviceInfo.isEmpty) {
      return const [DeviceInfoItem(label: '状态', value: '设备信息尚未完成启动缓存')];
    }

    return deviceInfo.entries
        .map(
          (entry) => DeviceInfoItem(
            label: entry.key,
            value: entry.value?.toString() ?? '未知',
          ),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE4EAF6)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x24111B3D),
                blurRadius: 28,
                offset: Offset(0, 18),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AboutDeviceHeader(title: l10n.t('aboutDevice', '关于设备')),
              Flexible(
                child: FutureBuilder<List<DeviceInfoItem>>(
                  future: _deviceInfoFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const SizedBox(
                        height: 220,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (snapshot.hasError) {
                      return _AboutDeviceError(
                        message: l10n.t(
                          'aboutDeviceLoadFailed',
                          '设备信息读取失败，请确认当前运行在 Android 主板环境',
                        ),
                      );
                    }

                    final items = snapshot.data ?? const <DeviceInfoItem>[];
                    return _AboutDeviceInfoList(items: items);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 关于设备弹窗标题栏。
class _AboutDeviceHeader extends StatelessWidget {
  const _AboutDeviceHeader({required this.title});

  /// 标题文本。
  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 18, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF17213D), Color(0xFF2F64F6)],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.memory_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.t('close', '关闭'),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// 关于设备信息列表。
class _AboutDeviceInfoList extends StatelessWidget {
  const _AboutDeviceInfoList({required this.items});

  /// 设备信息条目。
  final List<DeviceInfoItem> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      itemBuilder: (context, index) => _AboutDeviceInfoRow(item: items[index]),
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemCount: items.length,
    );
  }
}

/// 单条关于设备信息行。
class _AboutDeviceInfoRow extends StatelessWidget {
  const _AboutDeviceInfoRow({required this.item});

  /// 设备信息条目。
  final DeviceInfoItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4EAF6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 154,
            child: Text(
              item.label,
              style: const TextStyle(
                color: Color(0xFF6E7CA7),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: SelectableText(
              item.value,
              style: const TextStyle(
                color: Color(0xFF17213D),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 关于设备读取失败提示。
class _AboutDeviceError extends StatelessWidget {
  const _AboutDeviceError({required this.message});

  /// 错误提示。
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF9A3412),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// 设置列表中的语言选择行。
class _LanguageSettingRow extends StatelessWidget {
  const _LanguageSettingRow({
    required this.selectedLanguage,
    required this.onChanged,
  });

  /// 当前选中的语言。
  final AppLanguage selectedLanguage;

  /// 语言选择变化回调。
  final ValueChanged<AppLanguage?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4EAF6)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF2F64F6).withValues(alpha: .08),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.language_rounded,
              color: Color(0xFF2F64F6),
              size: 21,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('languageSetting', '语言设置'),
                  style: const TextStyle(
                    color: Color(0xFF17213D),
                    fontSize: 16,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.t('languageSettingHint', '选择终端界面显示语言'),
                  style: const TextStyle(
                    color: Color(0xFF7A86A8),
                    fontSize: 12,
                    height: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _LanguageDropdown(
            selectedLanguage: selectedLanguage,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// 带国家或地区图标的语言下拉框。
class _LanguageDropdown extends StatelessWidget {
  const _LanguageDropdown({
    required this.selectedLanguage,
    required this.onChanged,
  });

  /// 当前选中的语言。
  final AppLanguage selectedLanguage;

  /// 语言选择变化回调。
  final ValueChanged<AppLanguage?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 172,
      height: 46,
      padding: const EdgeInsets.only(left: 12, right: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD9E2F5)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AppLanguage>(
          key: const ValueKey('settings_language_dropdown'),
          value: selectedLanguage,
          borderRadius: BorderRadius.circular(14),
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF6877A2),
          ),
          items: AppLanguage.values
              .map((language) {
                return DropdownMenuItem<AppLanguage>(
                  value: language,
                  child: _LanguageOption(language: language),
                );
              })
              .toList(growable: false),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// 下拉框中的单个语言选项。
class _LanguageOption extends StatelessWidget {
  const _LanguageOption({required this.language});

  /// 语言配置。
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(language.icon, style: const TextStyle(fontSize: 19)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            language.label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF17213D),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

/// 弹出管理员登录窗口。
void _showAdminLoginDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => const _AdminLoginDialog(),
  );
}

/// 管理员登录弹窗。
class _AdminLoginDialog extends StatefulWidget {
  const _AdminLoginDialog();

  @override
  State<_AdminLoginDialog> createState() => _AdminLoginDialogState();
}

class _AdminLoginDialogState extends State<_AdminLoginDialog> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  _AdminLoginFieldType? _activeField;
  bool _loginLoading = false;
  String? _loginError;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _selectField(_AdminLoginFieldType fieldType) {
    setState(() => _activeField = fieldType);
  }

  void _appendDigit(String value) {
    final controller = _activeController;
    if (controller == null) {
      return;
    }

    controller.text += value;
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
  }

  void _deleteDigit() {
    final controller = _activeController;
    if (controller == null || controller.text.isEmpty) {
      return;
    }

    controller.text = controller.text.substring(0, controller.text.length - 1);
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
  }

  void _clearInput() {
    _activeController?.clear();
  }

  void _returnToIllustration() {
    setState(() => _activeField = null);
  }

  /// 调用假 API 校验管理员权限，成功后进入管理员身份校验页。
  Future<void> _login() async {
    if (_loginLoading) {
      return;
    }
    setState(() {
      _loginLoading = true;
      _loginError = null;
    });
    try {
      final result = await adminRepository.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      if (!result.authorized) {
        setState(() {
          _loginLoading = false;
          _loginError = context.l10n.t(
            'adminLoginDeniedMessage',
            result.message,
          );
        });
        return;
      }
      Navigator.of(context).pop();
      Navigator.of(context).pushNamed(AppRoutes.adminVerification);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loginLoading = false;
        _loginError = context.l10n.t(
          'adminLoginFailureMessage',
          '管理员权限校验失败，请稍后重试',
        );
      });
    }
  }

  TextEditingController? get _activeController => switch (_activeField) {
    _AdminLoginFieldType.username => _usernameController,
    _AdminLoginFieldType.password => _passwordController,
    null => null,
  };

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final availableWidth = mediaSize.width - 48;
    final availableHeight = mediaSize.height - 48;
    final dialogWidth = availableWidth.clamp(592.0, 820.0);

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: availableHeight,
        ),
        child: Container(
          height: availableHeight.clamp(360.0, 454.0),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE3BD),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white, width: 5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2E1B1730),
                blurRadius: 24,
                offset: Offset(0, 14),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              Expanded(
                child: _AdminLoginVisualPanel(
                  activeField: _activeField,
                  onDigitPressed: _appendDigit,
                  onDelete: _deleteDigit,
                  onClear: _clearInput,
                  onBack: _returnToIllustration,
                ),
              ),
              SizedBox(
                width: 344,
                child: _AdminLoginPanel(
                  usernameController: _usernameController,
                  passwordController: _passwordController,
                  activeField: _activeField,
                  onFieldSelected: _selectField,
                  loginLoading: _loginLoading,
                  loginError: _loginError,
                  onLogin: _login,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 管理员登录当前选中的输入字段。
enum _AdminLoginFieldType { username, password }

/// 管理员登录左侧视觉区，输入框聚焦后由插画过渡为数字键盘。
class _AdminLoginVisualPanel extends StatelessWidget {
  const _AdminLoginVisualPanel({
    required this.activeField,
    required this.onDigitPressed,
    required this.onDelete,
    required this.onClear,
    required this.onBack,
  });

  /// 当前数字键盘绑定的输入字段；为空时显示插画。
  final _AdminLoginFieldType? activeField;

  /// 点击数字键时回调。
  final ValueChanged<String> onDigitPressed;

  /// 点击删除键时回调。
  final VoidCallback onDelete;

  /// 点击清空键时回调。
  final VoidCallback onClear;

  /// 点击返回时切回插画区域。
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(-.04, 0),
          end: Offset.zero,
        ).animate(animation);

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offsetAnimation, child: child),
        );
      },
      child: activeField == null
          ? const _AdminLoginIllustration(
              key: ValueKey('admin_login_illustration'),
            )
          : _AdminNumberKeyboardPanel(
              key: const ValueKey('admin_login_number_keyboard_panel'),
              activeField: activeField!,
              onDigitPressed: onDigitPressed,
              onDelete: onDelete,
              onClear: onClear,
              onBack: onBack,
            ),
    );
  }
}

/// 管理员登录左侧插画区域。
class _AdminLoginIllustration extends StatelessWidget {
  const _AdminLoginIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(painter: const _AdminIllustrationPainter()),
        ),
        Align(
          alignment: const Alignment(0, -.46),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SpeechBubble(width: 104),
              const SizedBox(height: 8),
              const Icon(
                Icons.sentiment_satisfied_alt_rounded,
                color: Color(0xFF8A2364),
                size: 96,
              ),
              const SizedBox(height: 2),
              Container(
                width: 118,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FBFF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFC8D6F2)),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: Color(0xFF8A2364),
                  size: 38,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 48,
          right: 48,
          bottom: 30,
          child: Column(
            children: [
              Text(
                context.l10n.t('adminLoginSubtitleTitle', '智能柜管理后台'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF7F1D58),
                  fontSize: 18,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                context.l10n.t(
                  'adminLoginSubtitleDescription',
                  '设备状态、格口权限与业务记录统一管控',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF7F1D58),
                  fontSize: 11,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 管理员登录右侧面板。
class _AdminLoginPanel extends StatelessWidget {
  const _AdminLoginPanel({
    required this.usernameController,
    required this.passwordController,
    required this.activeField,
    required this.onFieldSelected,
    required this.loginLoading,
    required this.loginError,
    required this.onLogin,
  });

  /// 用户名输入控制器。
  final TextEditingController usernameController;

  /// 密码输入控制器。
  final TextEditingController passwordController;

  /// 当前正在通过数字键盘输入的字段。
  final _AdminLoginFieldType? activeField;

  /// 输入框获得焦点时切换数字键盘目标字段。
  final ValueChanged<_AdminLoginFieldType> onFieldSelected;

  /// 是否正在提交登录校验。
  final bool loginLoading;

  /// 登录失败或无权限时的提示文本。
  final String? loginError;

  /// 点击登录按钮时执行的动作。
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return LayoutBuilder(
      builder: (context, constraints) {
        final panelWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 344.0;
        final compactPadding = panelWidth < 340;
        final panelHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 454.0;
        final compactHeight = panelHeight < 420;
        final titleGap = compactHeight ? 20.0 : 29.0;
        final fieldGap = compactHeight ? 12.0 : 16.0;
        final buttonGap = compactHeight ? 16.0 : 22.0;

        return Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(
            compactPadding ? 28 : 54,
            compactHeight ? 30 : (compactPadding ? 34 : 70),
            compactPadding ? 28 : 54,
            compactHeight ? 28 : (compactPadding ? 30 : 52),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _AdminLoginMark(),
              SizedBox(height: compactHeight ? 12 : 24),
              Text(
                l10n.t('adminLoginTitle', '管理员后台'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF555555),
                  fontSize: 21,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: titleGap),
              _AdminLoginField(
                labelText: l10n.t('adminUsernameLabel', '用户名'),
                hintText: 'mail@abc.com',
                controller: usernameController,
                selected: activeField == _AdminLoginFieldType.username,
                onTap: () => onFieldSelected(_AdminLoginFieldType.username),
              ),
              SizedBox(height: fieldGap),
              _AdminLoginField(
                labelText: l10n.t('adminPasswordLabel', '密码'),
                hintText: '••••••••••••',
                controller: passwordController,
                selected: activeField == _AdminLoginFieldType.password,
                onTap: () => onFieldSelected(_AdminLoginFieldType.password),
                obscureText: true,
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  SizedBox(
                    width: 13,
                    height: 13,
                    child: Checkbox(
                      value: true,
                      onChanged: (_) {},
                      activeColor: const Color(0xFF8A2364),
                      side: const BorderSide(
                        color: Color(0xFFC8D6F2),
                        width: 1,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.t('adminRememberPassword', '记住密码'),
                    style: TextStyle(
                      color: Color(0xFFA99AA5),
                      fontSize: 10,
                      height: 1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: buttonGap),
              if (loginError != null) ...[
                Text(
                  loginError!,
                  key: const ValueKey('admin_login_error'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 11,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              _AdminPrimaryButton(
                compact: compactHeight,
                loading: loginLoading,
                onPressed: onLogin,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 管理员登录标识。
class _AdminLoginMark extends StatelessWidget {
  const _AdminLoginMark();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.scatter_plot_rounded,
        color: Color(0xFF8A2364),
        size: 38,
      ),
    );
  }
}

/// 管理员登录主按钮。
class _AdminPrimaryButton extends StatelessWidget {
  const _AdminPrimaryButton({
    required this.compact,
    required this.loading,
    required this.onPressed,
  });

  /// 是否使用紧凑高度，避免小屏高度下底部溢出。
  final bool compact;

  /// 是否正在登录校验。
  final bool loading;

  /// 点击登录按钮时执行的动作。
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SizedBox(
      height: compact ? 32 : 35,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8A2364),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                l10n.t('adminLoginButton', '登录'),
                style: TextStyle(
                  fontSize: 13,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
      ),
    );
  }
}

/// 管理员登录数字键盘面板。
class _AdminNumberKeyboardPanel extends StatelessWidget {
  const _AdminNumberKeyboardPanel({
    super.key,
    required this.activeField,
    required this.onDigitPressed,
    required this.onDelete,
    required this.onClear,
    required this.onBack,
  });

  /// 当前数字键盘绑定的输入字段。
  final _AdminLoginFieldType activeField;

  /// 点击数字键时回调。
  final ValueChanged<String> onDigitPressed;

  /// 点击删除键时回调。
  final VoidCallback onDelete;

  /// 点击清空键时回调。
  final VoidCallback onClear;

  /// 点击返回时切回插画区域。
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = switch (activeField) {
      _AdminLoginFieldType.username => l10n.t('adminInputUsername', '输入用户名'),
      _AdminLoginFieldType.password => l10n.t('adminInputPassword', '输入密码'),
    };

    return Container(
      color: const Color(0xFFFBF6F9),
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF555555),
                    fontSize: 15,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton.icon(
                key: const ValueKey('admin_keyboard_back'),
                onPressed: onBack,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF8A2364),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 15),
                label: Text(l10n.t('adminKeyboardBack', '返回')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.t('adminKeyboardHint', '使用左侧数字键盘录入'),
            style: TextStyle(
              color: Color(0xFFA99AA5),
              fontSize: 11,
              height: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: _AdminNumberKeyboard(
              onDigitPressed: onDigitPressed,
              onDelete: onDelete,
              onClear: onClear,
            ),
          ),
        ],
      ),
    );
  }
}

/// 管理员登录数字键盘。
class _AdminNumberKeyboard extends StatelessWidget {
  const _AdminNumberKeyboard({
    required this.onDigitPressed,
    required this.onDelete,
    required this.onClear,
  });

  /// 点击数字键时回调。
  final ValueChanged<String> onDigitPressed;

  /// 点击删除键时回调。
  final VoidCallback onDelete;

  /// 点击清空键时回调。
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final clearLabel = l10n.t('adminKeyboardClear', '清空');
    final deleteLabel = l10n.t('adminKeyboardDelete', '删除');
    final keys = [
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      clearLabel,
      '0',
      deleteLabel,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final keyboardWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 256.0;
        final keyboardHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 300.0;
        const crossAxisSpacing = 9.0;
        const mainAxisSpacing = 9.0;
        const rowCount = 4;
        const columnCount = 3;
        final buttonWidth =
            (keyboardWidth - crossAxisSpacing * (columnCount - 1)) /
            columnCount;
        final buttonHeight =
            (keyboardHeight - mainAxisSpacing * (rowCount - 1)) / rowCount;
        final buttonAspectRatio = buttonWidth / buttonHeight.clamp(1.0, 80.0);

        return GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: keys.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnCount,
            mainAxisSpacing: mainAxisSpacing,
            crossAxisSpacing: crossAxisSpacing,
            childAspectRatio: buttonAspectRatio,
          ),
          itemBuilder: (context, index) {
            final key = keys[index];
            return _AdminKeyboardButton(
              key: ValueKey('admin_keyboard_$key'),
              label: key,
              onPressed: switch (key) {
                var label when label == clearLabel => onClear,
                var label when label == deleteLabel => onDelete,
                _ => () => onDigitPressed(key),
              },
            );
          },
        );
      },
    );
  }
}

/// 管理员数字键盘上的单个按键。
class _AdminKeyboardButton extends StatelessWidget {
  const _AdminKeyboardButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  /// 按键显示文本。
  final String label;

  /// 点击按键时执行的动作。
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isAction =
        label == l10n.t('adminKeyboardClear', '清空') ||
        label == l10n.t('adminKeyboardDelete', '删除');

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: isAction ? const Color(0xFFF3EDF1) : Colors.white,
        foregroundColor: isAction
            ? const Color(0xFF7E7078)
            : const Color(0xFF8A2364),
        side: const BorderSide(color: Color(0xFFE2D7DE)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: TextStyle(
          fontSize: isAction ? 12 : 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      child: Text(label),
    );
  }
}

/// 管理员登录输入框。
class _AdminLoginField extends StatelessWidget {
  const _AdminLoginField({
    required this.labelText,
    required this.hintText,
    required this.controller,
    required this.selected,
    required this.onTap,
    this.obscureText = false,
  });

  /// 输入框标签。
  final String labelText;

  /// 输入框占位提示。
  final String hintText;

  /// 输入框文本控制器。
  final TextEditingController controller;

  /// 是否为当前数字键盘输入目标。
  final bool selected;

  /// 点击输入框时触发，用于展示并绑定右侧数字键盘。
  final VoidCallback onTap;

  /// 是否隐藏输入内容。
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            labelText,
            style: const TextStyle(
              color: Color(0xFF7E7078),
              fontSize: 10,
              height: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 31,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.none,
              obscureText: obscureText,
              onTap: onTap,
              readOnly: true,
              style: const TextStyle(
                color: Color(0xFF555555),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 0,
                ),
                hintStyle: const TextStyle(
                  color: Color(0xFFD8CED5),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(
                    color: selected
                        ? const Color(0xFF8A2364)
                        : const Color(0xFFE2D7DE),
                    width: selected ? 1.2 : 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(
                    color: Color(0xFF8A2364),
                    width: 1.2,
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

/// 登录页左侧气泡。
class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _SpeechBubblePainter(),
      child: SizedBox(
        width: width,
        height: 42,
        child: const Center(
          child: Text(
            '•••••••',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}

/// 登录页左侧气泡绘制器。
class _SpeechBubblePainter extends CustomPainter {
  const _SpeechBubblePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF64164F);
    final path = Path()
      ..moveTo(4, 0)
      ..lineTo(size.width - 4, 0)
      ..quadraticBezierTo(size.width, 0, size.width, 4)
      ..lineTo(size.width, size.height - 16)
      ..quadraticBezierTo(
        size.width,
        size.height - 12,
        size.width - 4,
        size.height - 12,
      )
      ..lineTo(size.width - 16, size.height - 12)
      ..lineTo(size.width - 9, size.height)
      ..lineTo(size.width - 28, size.height - 12)
      ..lineTo(4, size.height - 12)
      ..quadraticBezierTo(0, size.height - 12, 0, size.height - 16)
      ..lineTo(0, 4)
      ..quadraticBezierTo(0, 0, 4, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 登录页左侧背景装饰绘制器。
class _AdminIllustrationPainter extends CustomPainter {
  const _AdminIllustrationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final peach = Paint()..color = const Color(0xFFFFE3BD);
    canvas.drawRect(Offset.zero & size, peach);

    canvas.drawCircle(
      Offset(size.width * .46, size.height * .42),
      142,
      Paint()..color = const Color(0xFFF7CDA8).withValues(alpha: .42),
    );
    canvas.drawCircle(
      const Offset(16, 18),
      74,
      Paint()..color = const Color(0xFFB8313E).withValues(alpha: .94),
    );
    canvas.drawCircle(
      Offset(size.width - 52, size.height + 4),
      40,
      Paint()..color = const Color(0xFFC774A4).withValues(alpha: .48),
    );

    final dotPaint = Paint()..color = const Color(0xFFB8313E);
    const points = [
      Offset(76, 64),
      Offset(142, 112),
      Offset(92, 248),
      Offset(232, 84),
      Offset(318, 136),
      Offset(388, 58),
      Offset(420, 284),
      Offset(138, 360),
    ];
    for (final point in points) {
      canvas.drawCircle(point, 1.4, dotPaint);
    }

    final linePaint = Paint()
      ..color = const Color(0xFFC35B67).withValues(alpha: .65)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(112, 300), const Offset(144, 278), linePaint);
    canvas.drawLine(
      Offset(size.width - 116, 64),
      Offset(size.width - 88, 42),
      linePaint,
    );
    canvas.drawLine(
      Offset(size.width - 170, 150),
      Offset(size.width - 136, 128),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 首页通用白色卡片容器。
///
/// 统一提供圆角、边框、阴影以及可选顶部强调色条。
class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.width,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderColor,
  });

  /// 卡片宽度。
  final double width;

  /// 卡片内部内容。
  final Widget child;

  /// 卡片内容内边距。
  final EdgeInsetsGeometry padding;

  /// 顶部强调色条颜色；为空时不显示强调色条。
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .96),
        borderRadius: radius,
        border: Border.all(color: const Color(0xFFE5EBF8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D1B2E5A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (borderColor != null)
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              child: Container(height: 3, color: borderColor),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// 当前柜体卡片中的原生柜体预览。
class _CabinetModelViewer extends StatelessWidget {
  const _CabinetModelViewer();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: const DecoratedBox(
        key: ValueKey('cabinet_native_preview'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEAF2FF), Color(0xFFF8FBFF)],
          ),
        ),
        child: CustomPaint(
          painter: _CabinetPreviewPainter(),
          child: SizedBox.expand(),
        ),
      ),
    );
  }
}

/// 首页小卡片使用的轻量柜体绘制器。
class _CabinetPreviewPainter extends CustomPainter {
  const _CabinetPreviewPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bodyRect = Rect.fromLTWH(
      size.width * .18,
      size.height * .08,
      size.width * .58,
      size.height * .84,
    );
    final sidePath = Path()
      ..moveTo(bodyRect.right, bodyRect.top)
      ..lineTo(size.width * .88, size.height * .19)
      ..lineTo(size.width * .88, size.height * .82)
      ..lineTo(bodyRect.right, bodyRect.bottom)
      ..close();
    final topPath = Path()
      ..moveTo(bodyRect.left, bodyRect.top)
      ..lineTo(size.width * .31, size.height * .01)
      ..lineTo(size.width * .88, size.height * .19)
      ..lineTo(bodyRect.right, bodyRect.top)
      ..close();

    final shadowPaint = Paint()
      ..color = const Color(0x24334666)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .2,
          size.height * .86,
          size.width * .68,
          size.height * .08,
        ),
        const Radius.circular(12),
      ),
      shadowPaint,
    );

    canvas.drawPath(
      sidePath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFB9C8E7), Color(0xFF7E91BB)],
        ).createShader(sidePath.getBounds()),
    );
    canvas.drawPath(
      topPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFDDE7FA)],
        ).createShader(topPath.getBounds()),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(8)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8FBFF), Color(0xFFD8E4F8)],
        ).createShader(bodyRect),
    );

    final strokePaint = Paint()
      ..color = const Color(0xFF7D91BB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(8)),
      strokePaint,
    );
    canvas.drawPath(topPath, strokePaint);
    canvas.drawPath(sidePath, strokePaint);

    _drawDoors(canvas, bodyRect);
    _drawDisplay(canvas, bodyRect);
    _drawStatusLight(canvas, size);
  }

  void _drawDoors(Canvas canvas, Rect bodyRect) {
    final doorPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;
    final doorStrokePaint = Paint()
      ..color = const Color(0xFFC3D1EA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8;

    const rowCount = 5;
    const columnCount = 2;
    final gap = bodyRect.width * .055;
    final doorWidth = (bodyRect.width - gap * 3) / columnCount;
    final doorHeight = (bodyRect.height * .67 - gap * 6) / rowCount;
    final startTop = bodyRect.top + bodyRect.height * .25;

    for (var row = 0; row < rowCount; row++) {
      for (var column = 0; column < columnCount; column++) {
        final left = bodyRect.left + gap + column * (doorWidth + gap);
        final top = startTop + row * (doorHeight + gap);
        final doorRect = Rect.fromLTWH(left, top, doorWidth, doorHeight);
        canvas.drawRRect(
          RRect.fromRectAndRadius(doorRect, const Radius.circular(2.5)),
          doorPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(doorRect, const Radius.circular(2.5)),
          doorStrokePaint,
        );
        canvas.drawCircle(
          Offset(doorRect.right - doorWidth * .18, doorRect.center.dy),
          1.1,
          Paint()..color = const Color(0xFF9AACCE),
        );
      }
    }
  }

  void _drawDisplay(Canvas canvas, Rect bodyRect) {
    final screenRect = Rect.fromLTWH(
      bodyRect.left + bodyRect.width * .14,
      bodyRect.top + bodyRect.height * .08,
      bodyRect.width * .72,
      bodyRect.height * .12,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(screenRect, const Radius.circular(4)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF2563EB), Color(0xFF22C55E)],
        ).createShader(screenRect),
    );
    canvas.drawCircle(
      Offset(screenRect.left + screenRect.width * .17, screenRect.center.dy),
      2,
      Paint()..color = const Color(0xB3FFFFFF),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          screenRect.left + screenRect.width * .34,
          screenRect.center.dy - 1.2,
          screenRect.width * .42,
          2.4,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0x8CFFFFFF),
    );
  }

  void _drawStatusLight(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(size.width * .83, size.height * .24),
      4.4,
      Paint()..color = const Color(0x3322C55E),
    );
    canvas.drawCircle(
      Offset(size.width * .83, size.height * .24),
      2.4,
      Paint()..color = const Color(0xFF22C55E),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 背景点阵绘制器。
class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD8E1F4)
      ..style = PaintingStyle.fill;

    const spacing = 32.0;
    for (double y = 17; y < size.height; y += spacing) {
      for (double x = 16; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.05, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
