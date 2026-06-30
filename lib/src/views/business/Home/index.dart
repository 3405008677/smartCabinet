import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/app_localizations.dart';
import '../../../app/router/app_router.dart';
import '../../../components/Layout/TerminalShell/index.dart';
import '../../../core/device/device_info_service.dart';
import '../../../core/storage/app_local_store_provider.dart';
import '../../../models/home_model.dart';
import '../../../repositories/admin_repository.dart';
import '../../../repositories/home_repository.dart';

// Home 页面内部拆分文件。
//
// 这里使用 part 而不是普通 import/export，是为了让拆分后的文件仍然共享
// Home 页面私有组件（_Xxx）的可见性，避免把仅属于首页的组件暴露为公共 API。
part 'Dashboard/index.dart';
part 'Settings/index.dart';
part 'AdminLogin/index.dart';
part 'Shared/index.dart';

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
/// `Dashboard/index.dart`、`Settings/index.dart`、`AdminLogin/index.dart`
/// 和 `Shared/index.dart` 中维护。
class _SmartCabinetHomePageState extends State<SmartCabinetHomePage> {
  /// 首页展示数据。
  ///
  /// 先使用一份同步默认值作为首帧兜底，避免异步接口尚未返回时页面空白。
  HomeModel _homeData = HomeModel.fallback();

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
