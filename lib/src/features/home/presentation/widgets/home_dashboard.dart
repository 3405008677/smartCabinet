part of '../index.dart';

// 首页可见仪表盘区域。
//
// 该文件只放首页首屏能看到的卡片和入口，不包含隐藏设置、管理员登录弹窗
// 或 painter 等低层视觉组件。

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
    // 整个首页主体区由顶部柜体信息、主功能区和底部状态摘要三部分组成。
    return Padding(
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
    // 当前语言下的首页文案入口。
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

  /// 点击主入口后进入存取件业务首页。
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
