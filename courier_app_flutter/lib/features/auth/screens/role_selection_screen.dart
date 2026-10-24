// Role Selection Screen for Dilkash Restaurant App
// Displays ONLY the roles assigned to this verified account and allows seamless switching.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';
import '../../../core/auth/auth_notifier.dart';

class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final session = ref.watch(authProvider).value;

    if (session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: DilkashColors.background(isDark),
      appBar: AppBar(
        title: const Text('Rolni Tanlang'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Chiqish',
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Employee Header
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
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor:
                          DilkashColors.primary500.withValues(alpha: 0.15),
                      child: Text(
                        session.name.isNotEmpty
                            ? session.name.substring(0, 1).toUpperCase()
                            : 'X',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: DilkashColors.primary500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: DilkashColors.textPrimary(isDark),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Xodim kodi: ${session.staffCode} • ${session.phone}',
                            style: TextStyle(
                              fontSize: 13,
                              color: DilkashColors.textSecondary(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Sizga biriktirilgan vazifalar:',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: DilkashColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 12),

              // Courier Card (Shown ONLY if assigned)
              if (session.canActAsCourier) ...[
                _RoleCard(
                  title: 'Kuryerlik Xizmati',
                  subtitle:
                      'Yetkazib berish buyurtmalari, navigatsiya va naqd pul yigʻish',
                  icon: Icons.two_wheeler_rounded,
                  badge: 'Yetkazish boʻlimi',
                  color: const Color(0xFF10B981),
                  isSelected: session.isCourier,
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    await ref.read(authProvider.notifier).switchRole('courier');
                    if (context.mounted) context.go('/courier');
                  },
                ),
                const SizedBox(height: 14),
              ],

              // Waiter Card (Shown ONLY if assigned)
              if (session.canActAsWaiter) ...[
                _RoleCard(
                  title: 'Zal Ofitsianti',
                  subtitle:
                      'Stollar rejasi, buyurtma olish, oshxona nazorati va hisob-kitob',
                  icon: Icons.room_service_rounded,
                  badge: 'Restoran zali',
                  color: const Color(0xFFD97706),
                  isSelected: session.isWaiter,
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    await ref.read(authProvider.notifier).switchRole('waiter');
                    if (context.mounted) context.go('/waiter');
                  },
                ),
              ],

              const Spacer(),
              Text(
                'Eslatma: Rolni istalgan paytda ilova profilidan qayta oʻzgartirishingiz mumkin.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: DilkashColors.textSecondary(isDark),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String badge;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badge,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: DilkashRadii.radiusMd,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF16231D) : Colors.white,
            borderRadius: DilkashRadii.radiusMd,
            border: Border.all(
              color: isSelected ? color : Colors.grey.withValues(alpha: 0.25),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : DilkashShadows.card(isDark),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: DilkashRadii.radiusSm,
                ),
                child: Center(
                  child: Icon(icon, color: color, size: 28),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: DilkashColors.textPrimary(isDark),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: DilkashColors.textSecondary(isDark),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: DilkashColors.textSecondary(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
