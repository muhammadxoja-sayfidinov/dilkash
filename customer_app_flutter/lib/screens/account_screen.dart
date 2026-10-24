import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';
import '../services/auth_provider.dart';
import '../services/api_service.dart';
import '../services/theme_provider.dart';
import 'auth_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  void _showThemeSelectionSheet(BuildContext context, ThemeProvider themeProv) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentMode = themeProv.themeMode;

    DilkashBottomSheet.show(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ilova mavzusini tanlang',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: DilkashColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 16),
          _buildThemeTile(
            context: ctx,
            title: 'Kunduzgi rejim (Yorugʻ)',
            icon: Icons.light_mode_rounded,
            isSelected: currentMode == ThemeMode.light,
            onTap: () {
              themeProv.setThemeMode(ThemeMode.light);
              Navigator.pop(ctx);
            },
          ),
          const SizedBox(height: 8),
          _buildThemeTile(
            context: ctx,
            title: 'Tungi rejim (Qorongʻi)',
            icon: Icons.dark_mode_rounded,
            isSelected: currentMode == ThemeMode.dark,
            onTap: () {
              themeProv.setThemeMode(ThemeMode.dark);
              Navigator.pop(ctx);
            },
          ),
          const SizedBox(height: 8),
          _buildThemeTile(
            context: ctx,
            title: 'Tizim sozlamasi (Avtomatik)',
            icon: Icons.brightness_auto_rounded,
            isSelected: currentMode == ThemeMode.system,
            onTap: () {
              themeProv.setThemeMode(ThemeMode.system);
              Navigator.pop(ctx);
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  static Widget _buildThemeTile({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark
                ? DilkashColors.surfaceDarkElevated
                : DilkashColors.primary50)
            : Colors.transparent,
        borderRadius: DilkashRadii.radiusSm,
        border: Border.all(
          color: isSelected
              ? DilkashColors.primary(isDark)
              : (isDark ? DilkashColors.borderDark : DilkashColors.borderLight),
        ),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected
              ? DilkashColors.primary(isDark)
              : DilkashColors.textSecondary(isDark),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: DilkashColors.textPrimary(isDark),
          ),
        ),
        trailing: isSelected
            ? Icon(Icons.check_circle_rounded,
                color: DilkashColors.primary(isDark))
            : null,
        onTap: onTap,
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, AuthProvider auth) {
    final nameCtrl = TextEditingController(text: auth.user?.fullName ?? '');
    final addrCtrl =
        TextEditingController(text: auth.user?.defaultAddress ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Profilni tahrirlash'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DilkashTextField(
              controller: nameCtrl,
              label: 'Ism va familiya',
            ),
            const SizedBox(height: 12),
            DilkashTextField(
              controller: addrCtrl,
              label: 'Asosiy manzil',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor qilish'),
          ),
          DilkashButton(
            label: 'Saqlash',
            isFullWidth: false,
            size: DilkashButtonSize.sm,
            onPressed: () async {
              if (nameCtrl.text.trim().isNotEmpty) {
                await auth.updateProfile(
                  fullName: nameCtrl.text.trim(),
                );
                if (addrCtrl.text.trim().isNotEmpty) {
                  await auth.saveDefaultAddress(addrCtrl.text.trim());
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  DilkashFeedback.showSuccess(context, 'Profil yangilandi');
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final themeProv = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final user = auth.user;

    return Scaffold(
      backgroundColor: DilkashColors.background(isDark),
      appBar: AppBar(
        title: const Text('Profil va Sozlamalar'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // User Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: DilkashColors.surface(isDark),
                borderRadius: DilkashRadii.radiusLg,
                border: Border.all(
                  color: isDark
                      ? DilkashColors.borderDark
                      : DilkashColors.borderLight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: isDark
                          ? DilkashColors.surfaceDarkElevated
                          : DilkashColors.primary50,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? DilkashColors.primary400
                            : DilkashColors.primary500,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.person_rounded,
                        size: 32,
                        color: isDark
                            ? DilkashColors.primary400
                            : DilkashColors.primary500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? 'Mehmon',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: DilkashColors.textPrimary(isDark),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          user != null
                              ? UzbekFormatters.formatPhone(user.phone)
                              : 'Tizimga kirmagan',
                          style: TextStyle(
                            fontSize: 13,
                            color: DilkashColors.textSecondary(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (auth.isAuthenticated)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _showEditProfileDialog(context, auth),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Cashback & Orders Stats Row
            if (auth.isAuthenticated && user != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: DilkashColors.surface(isDark),
                        borderRadius: DilkashRadii.radiusLg,
                        border: Border.all(
                          color: isDark
                              ? DilkashColors.borderDark
                              : DilkashColors.borderLight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.savings_outlined,
                                  size: 18, color: DilkashColors.amber500),
                              const SizedBox(width: 6),
                              Text(
                                'Keshbek',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: DilkashColors.textSecondary(isDark)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            UzbekFormatters.formatCurrency(user.cashbackPoints),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? DilkashColors.primary400
                                  : DilkashColors.primary600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: DilkashColors.surface(isDark),
                        borderRadius: DilkashRadii.radiusLg,
                        border: Border.all(
                          color: isDark
                              ? DilkashColors.borderDark
                              : DilkashColors.borderLight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.receipt_long_outlined,
                                  size: 18,
                                  color: DilkashColors.primary(isDark)),
                              const SizedBox(width: 6),
                              Text(
                                'Buyurtmalar',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: DilkashColors.textSecondary(isDark)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${user.ordersCount} ta',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: DilkashColors.textPrimary(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Settings List
            Container(
              decoration: BoxDecoration(
                color: DilkashColors.surface(isDark),
                borderRadius: DilkashRadii.radiusLg,
                border: Border.all(
                  color: isDark
                      ? DilkashColors.borderDark
                      : DilkashColors.borderLight,
                ),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.palette_outlined),
                    title: const Text('Ilova mavzusi (Yorugʻ / Tungi)'),
                    subtitle: Text(
                      themeProv.isDarkMode ? 'Tungi rejim' : 'Kunduzgi rejim',
                      style: TextStyle(
                          fontSize: 12,
                          color: DilkashColors.textSecondary(isDark)),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showThemeSelectionSheet(context, themeProv),
                  ),
                  Divider(
                      height: 1,
                      color: isDark
                          ? DilkashColors.borderDark
                          : DilkashColors.borderLight),
                  ListTile(
                    leading: const Icon(Icons.language_rounded),
                    title: const Text('Til / Язык'),
                    subtitle: Text(
                      'Oʻzbekcha (Lotin)',
                      style: TextStyle(
                          fontSize: 12,
                          color: DilkashColors.textSecondary(isDark)),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      DilkashFeedback.showInfo(
                          context, 'Hozirda Oʻzbek tili faol');
                    },
                  ),
                  Divider(
                      height: 1,
                      color: isDark
                          ? DilkashColors.borderDark
                          : DilkashColors.borderLight),
                  ListTile(
                    leading: const Icon(Icons.dns_outlined),
                    title: const Text('Server manzili (Base URL)'),
                    subtitle: Text(
                      ApiService.baseUrl,
                      style: TextStyle(
                          fontSize: 12,
                          color: DilkashColors.textSecondary(isDark)),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AuthScreen()),
                      );
                    },
                  ),
                  Divider(
                      height: 1,
                      color: isDark
                          ? DilkashColors.borderDark
                          : DilkashColors.borderLight),
                  ListTile(
                    leading: const Icon(Icons.support_agent_rounded),
                    title: const Text('Qoʻllab-quvvatlash xizmati'),
                    subtitle: Text(
                      '+998 71 200 00 00',
                      style: TextStyle(
                          fontSize: 12,
                          color: DilkashColors.textSecondary(isDark)),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      DilkashFeedback.showInfo(
                          context, 'Bogʻlanish: +998 71 200 00 00');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Logout or Login Button
            if (auth.isAuthenticated)
              DilkashButton(
                label: 'Akkountdan chiqish',
                variant: DilkashButtonVariant.outline,
                leadingIcon: Icons.logout_rounded,
                onPressed: () {
                  auth.logout();
                  DilkashFeedback.showInfo(context, 'Akkountdan chiqildi');
                },
              )
            else
              DilkashButton(
                label: 'Tizimga kirish',
                leadingIcon: Icons.login_rounded,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
