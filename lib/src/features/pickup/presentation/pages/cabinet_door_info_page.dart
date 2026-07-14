import 'package:flutter/material.dart';

import 'package:smart_cabinet/src/app/theme/app_theme.dart';

import 'package:smart_cabinet/src/app/localization/app_localizations.dart';

import 'package:smart_cabinet/src/app/routing/app_routes.dart';
import 'package:smart_cabinet/src/app/shell/app_shell.dart';
import 'package:smart_cabinet/src/features/pickup/domain/entities/pickup.dart';
import 'package:smart_cabinet/src/features/pickup/data/repositories/pickup_repository_impl.dart';

/// 柜门信息页面。
///
/// 页面参考原型图“柜门信息.png”。左侧人员信息做得更密集，
/// 右侧展示文件和柜门授权信息。
class CabinetDoorInfoPage extends StatefulWidget {
  /// 创建柜门信息页。
  const CabinetDoorInfoPage({super.key});

  @override
  State<CabinetDoorInfoPage> createState() => _CabinetDoorInfoPageState();
}

class _CabinetDoorInfoPageState extends State<CabinetDoorInfoPage> {
  /// 取件展示数据。
  PickupData _pickupData = PickupData.fallback();

  @override
  void initState() {
    super.initState();
    _loadPickupData();
  }

  /// 加载取件展示数据。
  Future<void> _loadPickupData() async {
    final data = await pickupRepository.fetchPickupData();
    if (!mounted) {
      return;
    }
    setState(() => _pickupData = data);
  }

  @override
  Widget build(BuildContext context) {
    return TerminalShell(
      child: CustomPaint(
        painter: const _DotGridPainter(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(40, 28, 40, 28),
          child: Row(
            children: [
              SizedBox(
                width: 390,
                child: _PersonInfoPanel(pickupData: _pickupData),
              ),
              const SizedBox(width: 28),
              Expanded(
                child: _DoorInfoPanel(
                  pickupData: _pickupData,
                  onOpenDoor: () => Navigator.of(
                    context,
                  ).pushNamed(AppRoutes.openCabinetDoor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 左侧人员信息面板。
class _PersonInfoPanel extends StatelessWidget {
  const _PersonInfoPanel({required this.pickupData});

  /// 取件展示数据。
  final PickupData pickupData;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 34,
                backgroundColor: AppTheme.primarySoftColor,
                child: Icon(
                  Icons.person_rounded,
                  color: AppTheme.primaryColor,
                  size: 38,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pickupData.personName,
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor,
                        fontSize: 24,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      pickupData.personTitle,
                      style: TextStyle(
                        color: Color(0xFF66739C),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _DenseInfoRow(
            label: l10n.t('pickupEmployeeCodeLabel', '员工编号'),
            value: pickupData.employeeCode,
          ),
          _DenseInfoRow(
            label: l10n.t('pickupPhoneLabel', '手机号码'),
            value: pickupData.phone,
          ),
          _DenseInfoRow(
            label: l10n.t('pickupIdCardLabel', '证件号码'),
            value: pickupData.idCard,
          ),
          _DenseInfoRow(
            label: l10n.t('pickupOrganizationLabel', '所属机构'),
            value: pickupData.organization,
          ),
          _DenseInfoRow(
            label: l10n.t('pickupPermissionLevelLabel', '权限等级'),
            value: pickupData.permissionLevel,
          ),
          _DenseInfoRow(
            label: l10n.t('pickupFaceLabel', '人脸识别'),
            value: pickupData.faceResult,
            success: true,
          ),
          _DenseInfoRow(
            label: l10n.t('pickupFingerprintLabel', '指纹识别'),
            value: pickupData.fingerprintResult,
            success: true,
          ),
          _DenseInfoRow(
            label: l10n.t('pickupNfcLabel', 'NFC识别'),
            value: pickupData.nfcResult,
            success: true,
          ),
          _DenseInfoRow(
            label: l10n.t('pickupCodeLabel', '取件码'),
            value: pickupData.pickupCodeResult,
            success: true,
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primarySoftColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDDE6FA)),
            ),
            child: Text(
              l10n.t(
                'pickupDoorInfoIdentitySummary',
                '身份链路完整，四重认证均已通过。本次取件行为将自动写入审计日志。',
              ),
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 密集信息行。
class _DenseInfoRow extends StatelessWidget {
  const _DenseInfoRow({
    required this.label,
    required this.value,
    this.success = false,
  });

  final String label;
  final String value;
  final bool success;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.outlineColor)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF9AA6C2),
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
              style: TextStyle(
                color: success
                    ? const Color(0xFF22A857)
                    : AppTheme.textPrimaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 右侧柜门和文件信息面板。
class _DoorInfoPanel extends StatelessWidget {
  const _DoorInfoPanel({required this.pickupData, required this.onOpenDoor});

  /// 取件展示数据。
  final PickupData pickupData;

  final VoidCallback onOpenDoor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primarySoftColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.meeting_room_outlined,
                  color: AppTheme.primaryColor,
                  size: 31,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      l10n.t('pickupDoorNoSectionTitle', '柜门信息'),
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor,
                        fontSize: 30,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        l10n.t(
                          'pickupDoorAuthorizationInfo',
                          'Door Authorization Information',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF8B98BA),
                          fontSize: 13,
                          letterSpacing: .8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    FlowStatusBadge(
                      text: l10n.t('pickupDoorInfoBadge', '证据信息已获取 · 待开柜'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _BigInfoCard(
                  title: l10n.t('pickupDoorNoLabel', '柜门编号'),
                  value: pickupData.doorNo,
                  icon: Icons.door_front_door_outlined,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: _BigInfoCard(
                  title: l10n.t('pickupFileCountLabel', '文件数量'),
                  value: l10n.t('pickupFileCountValue', '1 份'),
                  icon: Icons.description_outlined,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: _BigInfoCard(
                  title: l10n.t('pickupAuthorizationLabel', '授权状态'),
                  value: l10n.t('pickupAuthorizedValue', '已授权'),
                  icon: Icons.verified_outlined,
                  success: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppTheme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.outlineColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FileInfoLine(
                  label: l10n.t('pickupFileNameLabel', '文件名称'),
                  value: pickupData.fileName,
                ),
                _FileInfoLine(
                  label: l10n.t('pickupFileLevelLabel', '文件密级'),
                  value: l10n.t('pickupFileLevelValue', '内部机密 / 实名追溯'),
                ),
                _FileInfoLine(
                  label: l10n.t('pickupStorageLocationLabel', '存放位置'),
                  value: l10n
                      .t('pickupStorageLocationValue', 'A区 · {doorNo}号柜门 · 第二层')
                      .replaceAll('{doorNo}', pickupData.doorNo),
                ),
                _FileInfoLine(
                  label: l10n.t('pickupRequestNoLabel', '申请单号'),
                  value: l10n.t(
                    'pickupRequestNoValue',
                    'SC-PICKUP-20260612-0008',
                  ),
                ),
                _FileInfoLine(
                  label: l10n.t('pickupAuthorizedAtLabel', '授权时间'),
                  value: l10n.t(
                    'pickupAuthorizedAtValue',
                    '2026年6月12日 13:45:46',
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: Text(l10n.t('pickupDoorInfoBack', '返回验证')),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                    foregroundColor: AppTheme.textSecondaryColor,
                    side: const BorderSide(color: AppTheme.primaryBorderColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onOpenDoor,
                  icon: const Icon(Icons.lock_open_rounded, size: 19),
                  label: Text(l10n.t('pickupDoorInfoOpenDoor', '确认打开柜门')),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 重要信息卡片。
class _BigInfoCard extends StatelessWidget {
  const _BigInfoCard({
    required this.title,
    required this.value,
    required this.icon,
    this.success = false,
  });

  final String title;
  final String value;
  final IconData icon;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final color = success ? const Color(0xFF22A857) : AppTheme.primaryColor;
    return Container(
      height: 98,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF8996B8),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/// 文件信息行。
class _FileInfoLine extends StatelessWidget {
  const _FileInfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8C98B7),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: .96),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: AppTheme.outlineColor),
    boxShadow: const [
      BoxShadow(color: Color(0x0D1B2E5A), blurRadius: 18, offset: Offset(0, 8)),
    ],
  );
}

/// 背景点阵绘制器。
class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.outlineColor
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
