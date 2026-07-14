import 'package:flutter/material.dart';

import 'package:smart_cabinet/src/app/theme/app_theme.dart';

import 'package:smart_cabinet/src/app/shell/app_shell.dart';
import 'package:smart_cabinet/src/features/home/data/repositories/home_repository_impl.dart';
import 'package:smart_cabinet/src/features/home/domain/entities/home.dart';
import 'package:smart_cabinet/src/features/home/presentation/widgets/home_dashboard.dart';
import 'package:smart_cabinet/src/features/home/presentation/widgets/home_widgets.dart';
import 'package:smart_cabinet/src/features/home/presentation/widgets/settings_dialog.dart';

/// 智能柜新首页。
///
/// 下方展示统计、存取件入口和飞检操作。
class SmartCabinetHomePage extends StatefulWidget {
  /// 创建智能柜新首页。
  const SmartCabinetHomePage({super.key});

  @override
  State<SmartCabinetHomePage> createState() => _SmartCabinetHomePageState();
}

/// 首页根状态。
///
/// 只负责页面级数据加载和隐藏设置入口触发，具体界面结构放在
/// Dashboard, settings, login, and shared UI live in independent files under
/// presentation/widgets.
class _SmartCabinetHomePageState extends State<SmartCabinetHomePage> {
  /// 首页展示数据。
  ///
  /// 先使用一份同步默认值作为首帧兜底，避免异步接口尚未返回时页面空白。
  HomeData _homeData = HomeData.fallback();

  /// 底部版本号连续点击次数。
  int _versionTapCount = 0;

  @override
  void initState() {
    super.initState();

    // 页面初始化后异步加载首页数据，并用真实返回覆盖默认兜底值。
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
    showSettingsDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    return TerminalShell(
      onVersionTap: _handleVersionTap,
      child: CustomPaint(
        painter: const HomeDotGridPainter(),
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppTheme.scaffoldBackgroundColor, AppTheme.surfaceColor],
            ),
          ),
          child: HomeDashboard(
            homeData: _homeData,
            onCabinetModelTap: _handleVersionTap,
          ),
        ),
      ),
    );
  }
}
