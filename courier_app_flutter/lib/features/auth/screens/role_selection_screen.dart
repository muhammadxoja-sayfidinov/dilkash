// Role Selection Screen for Dilkash Restaurant Staff
// Shows ONLY verified assigned roles for this employee.

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
    final session = ref.watch(authProvider).value;

    if (session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: DilkashColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Rolni tanlang',
          style: DilkashTypography.h3.copyWith(
            fontWeight: FontWeight.w700,
            color: DilkashColors.textPrimaryLight,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: DilkashColors.textMutedLight),
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
          padding: const EdgeInsets.all(DilkashSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Employee greeting card
              Container(
                padding: const EdgeInsets.all(DilkashSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(DilkashRadii.md),
                  border: Border.all(color: DilkashColors.borderLight),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: DilkashColors.primary50,
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
                    const SizedBox(width: DilkashSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.name,
                            style: DilkashTypography.h3.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            session.phone,
                            style: DilkashTypography.caption.copyWith(
                              color: DilkashColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DilkashSpacing.xxl),

              Text(
                'Bugun qaysi vazifada ishlaysiz?',
                style: DilkashTypography.h3.copyWith(
                  fontWeight: FontWeight.w700,
                  color: DilkashColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: DilkashSpacing.md),

              // Courier Role Card
              if (session.canActAsCourier)
                _RoleCard(
                  title: 'Kuryer',
                  subtitle: 'Yetkazib berish buyurtmalari',
                  icon: Icons.delivery_dining_rounded,
                  badgeColor: DilkashColors.primary500,
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    await ref.read(authProvider.notifier).switchRole('courier');
                    if (context.mounted) {
                      context.go('/courier');
                    }
                  },
                ),

              if (session.canActAsCourier && session.canActAsWaiter)
                const SizedBox(height: DilkashSpacing.lg),

              // Waiter Role Card
              if (session.canActAsWaiter)
                _RoleCard(
                  title: 'Ofitsiant',
                  subtitle: 'Zal stollari va yangi buyurtmalar',
                  icon: Icons.table_restaurant_rounded,
                  badgeColor: const Color(0xFF2563EB),
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    await ref.read(authProvider.notifier).switchRole('waiter');
                    if (context.mounted) {
                      context.go('/waiter');
                    }
                  },
                ),

              const Spacer(),
              Text(
                'Tanlangan rol keyingi safar avtomatik ochiladi.',
                textAlign: TextAlign.center,
                style: DilkashTypography.caption.copyWith(
                  color: DilkashColors.textMutedLight,
                ),
              ),
              const SizedBox(height: DilkashSpacing.md),
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
  final Color badgeColor;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(DilkashRadii.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DilkashRadii.lg),
        child: Container(
          padding: const EdgeInsets.all(DilkashSpacing.xl),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DilkashRadii.lg),
            border: Border.all(color: DilkashColors.borderLight, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(DilkashRadii.md),
                ),
                child: Center(
                  child: Icon(icon, color: badgeColor, size: 30),
                ),
              ),
              const SizedBox(width: DilkashSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: DilkashTypography.h3.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: DilkashTypography.bodyMedium.copyWith(
                        color: DilkashColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: DilkashColors.textMutedLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
