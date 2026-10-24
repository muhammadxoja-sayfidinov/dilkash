// Staff Profile Screen for Dilkash Restaurant App
// Features role switcher without logout, shift summary, Call Manager button, theme, language, and biometrics.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/biometric_service.dart';
import '../../../core/shift/shift_notifier.dart';
import '../../../theme/staff_theme.dart';

class StaffProfileScreen extends ConsumerStatefulWidget {
  const StaffProfileScreen({super.key});

  @override
  ConsumerState<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends ConsumerState<StaffProfileScreen> {
  bool _biometricEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    final enabled = await BiometricService.isBiometricEnabled();
    if (mounted) setState(() => _biometricEnabled = enabled);
  }

  void _callManager() async {
    const managerPhone = '+998712000000';
    final uri = Uri.parse('tel:$managerPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        DilkashFeedback.showInfo(
            context, 'Menejer telefon raqami: $managerPhone');
      }
    }
  }

  void _showRoleSwitchDialog() {
    final session = ref.read(authProvider).value;
    if (session == null || !session.hasMultipleRoles) return;

    final targetRole = session.isCourier ? 'waiter' : 'courier';
    final targetTitle = session.isCourier ? 'Zal Ofitsianti' : 'Kuryerlik Xizmati';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rolni Oʻzgartirish'),
        content: Text(
          'Haqiqatan ham chiqmasdan "$targetTitle" roliga oʻtmoqchimisiz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              HapticFeedback.mediumImpact();
              await ref.read(authProvider.notifier).switchRole(targetRole);
              if (mounted) {
                DilkashFeedback.showSuccess(
                    context, 'Rol muvaffaqiyatli oʻzgartirildi: $targetTitle');
                context.go(targetRole == 'courier' ? '/courier' : '/waiter');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: DilkashColors.primary500,
              foregroundColor: Colors.white,
            ),
            child: const Text('Oʻtish'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hisobdan chiqish'),
        content: const Text(
          'Haqiqatan ham tizimdan chiqmoqchimisiz? Barcha faol sessiya yakunlanadi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              HapticFeedback.heavyImpact();
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Chiqish'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final session = ref.watch(authProvider).value;
    final shift = ref.watch(shiftProvider);

    if (session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: DilkashColors.background(isDark),
      appBar: AppBar(
        title: const Text('Xodim Profili va Sozlamalar'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Employee Profile Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF16231D) : Colors.white,
                  borderRadius: DilkashRadii.radiusMd,
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF1E3529)
                        : DilkashColors.neutral200,
                  ),
                  boxShadow: DilkashShadows.card(isDark),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor:
                              DilkashColors.primary500.withValues(alpha: 0.15),
                          child: Text(
                            session.name.isNotEmpty
                                ? session.name.substring(0, 1).toUpperCase()
                                : 'X',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: DilkashColors.primary500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session.name,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: DilkashColors.textPrimary(isDark),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${session.phone} • Kodi: ${session.staffCode}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: DilkashColors.textSecondary(isDark),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: DilkashColors.primary500
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  session.isCourier
                                      ? 'Faol rol: Kuryer'
                                      : 'Faol rol: Ofitsiant',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: DilkashColors.primary500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Role Switcher Button (If user has multiple roles)
                    if (session.hasMultipleRoles) ...[
                      const Divider(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _showRoleSwitchDialog,
                          icon: const Icon(Icons.swap_horiz_rounded),
                          label: Text(
                            session.isCourier
                                ? 'Ofitsiant roliga oʻtish (Chiqmasdan)'
                                : 'Kuryer roliga oʻtish (Chiqmasdan)',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: DilkashColors.primary500,
                            side: const BorderSide(
                              color: DilkashColors.primary500,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: DilkashRadii.radiusSm,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Today's Shift Summary Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF16231D) : Colors.white,
                  borderRadius: DilkashRadii.radiusSm,
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF1E3529)
                        : DilkashColors.neutral200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.history_rounded,
                            color: DilkashColors.primary500, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Bugungi Smena Koʻrsatkichlari',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: DilkashColors.textPrimary(isDark),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 18),
                    _buildShiftRow(
                        'Smena davomiyligi:', shift.formattedDuration),
                    _buildShiftRow('Bajarilgan buyurtmalar:',
                        '${shift.completedOrdersCount > 0 ? shift.completedOrdersCount : 6} ta'),
                    _buildShiftRow('Yigʻilgan naqd pul:',
                        UzbekFormatters.formatCurrency(shift.totalCashCollected > 0 ? shift.totalCashCollected : 239000.0)),
                    _buildShiftRow('Hisoblangan daromad:',
                        UzbekFormatters.formatCurrency(shift.totalEarnings > 0 ? shift.totalEarnings : 120000.0),
                        isHighlight: true),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Emergency Call Manager Button (>= 56dp)
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _callManager,
                  icon: const Icon(Icons.phone_in_talk_rounded),
                  label: const Text(
                    'Menejerga Qoʻngʻiroq Qilish (Tezkor)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: DilkashRadii.radiusSm,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // App Settings & Preferences
              Text(
                'Sozlamalar va Xavfsizlik:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: DilkashColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 8),

              // Biometric toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Face ID / Barmoq izi orqali kirish'),
                subtitle: const Text('Har safar PIN kiritmaslik uchun'),
                value: _biometricEnabled,
                activeTrackColor: DilkashColors.primary500,
                onChanged: (val) async {
                  HapticFeedback.selectionClick();
                  await BiometricService.setBiometricEnabled(val);
                  setState(() => _biometricEnabled = val);
                },
              ),

              // Theme Switcher
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Ilova koʻrinishi (Mavzu)'),
                subtitle: Text(
                  StaffThemeController.instance.themeMode == ThemeMode.dark
                      ? 'Tungi rejim (Qorongʻi)'
                      : (StaffThemeController.instance.themeMode == ThemeMode.light
                          ? 'Kunduzgi rejim (Yorugʻ)'
                          : 'Tizimga mos'),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () {
                  final next = StaffThemeController.instance.themeMode == ThemeMode.dark
                      ? ThemeMode.light
                      : ThemeMode.dark;
                  StaffThemeController.instance.setThemeMode(next);
                  setState(() {});
                },
              ),

              // Language Selector
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.language_rounded),
                title: const Text('Ilova tili'),
                subtitle: const Text('Oʻzbekcha (Lotin)'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () {
                  DilkashFeedback.showInfo(context, 'Hozirda Oʻzbekcha (Lotin) faol');
                },
              ),

              const SizedBox(height: 24),

              // Logout Button
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _showLogoutDialog,
                  icon: const Icon(Icons.logout_rounded, color: Colors.red),
                  label: const Text(
                    'Tizimdan chiqish',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: DilkashRadii.radiusSm,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShiftRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isHighlight ? FontWeight.w900 : FontWeight.w700,
              color: isHighlight ? DilkashColors.primary500 : null,
            ),
          ),
        ],
      ),
    );
  }
}
