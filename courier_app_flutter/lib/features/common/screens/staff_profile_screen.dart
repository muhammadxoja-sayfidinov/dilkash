// Staff Profile Screen for Dilkash Restaurant App
// Strictly follows KEEP specifications:
// - Employee info
// - Start/end shift as ONE simple toggle
// - Role switcher (if multiple roles)
// - Logout. Nothing else.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../../core/shift/shift_notifier.dart';

class StaffProfileScreen extends ConsumerWidget {
  const StaffProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider).value;
    final shift = ref.watch(shiftProvider);

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
          'Profil',
          style: DilkashTypography.h3.copyWith(
            fontWeight: FontWeight.w700,
            color: DilkashColors.textPrimaryLight,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DilkashSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Employee Info Card
              Container(
                padding: const EdgeInsets.all(DilkashSpacing.xl),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(DilkashRadii.lg),
                  border: Border.all(color: DilkashColors.borderLight),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: DilkashColors.primary50,
                      child: Text(
                        session.name.isNotEmpty
                            ? session.name.substring(0, 1).toUpperCase()
                            : 'X',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: DilkashColors.primary500,
                        ),
                      ),
                    ),
                    const SizedBox(width: DilkashSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.name,
                            style: DilkashTypography.h2.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            session.phone,
                            style: DilkashTypography.bodyLarge.copyWith(
                              color: DilkashColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: session.isCourier
                                  ? DilkashColors.primary50
                                  : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              session.isCourier ? 'Kuryer' : 'Ofitsiant',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: session.isCourier
                                  ? DilkashColors.primary500
                                  : const Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: DilkashSpacing.xl),

              // Simple Shift Toggle
              Container(
                padding: const EdgeInsets.all(DilkashSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(DilkashRadii.md),
                  border: Border.all(color: DilkashColors.borderLight),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: shift.isShiftActive
                            ? DilkashColors.success.withValues(alpha: 0.12)
                            : Colors.grey.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.access_time_filled_rounded,
                        color: shift.isShiftActive
                            ? DilkashColors.success
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: DilkashSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Smena holati',
                            style: DilkashTypography.h3.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            shift.isShiftActive
                                ? 'Smena ochiq (ishdasiz)'
                                : 'Smena yopiq',
                            style: DilkashTypography.bodyMedium.copyWith(
                              color: shift.isShiftActive
                                  ? DilkashColors.success
                                  : DilkashColors.textMutedLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: shift.isShiftActive,
                      activeTrackColor: DilkashColors.primary500,
                      onChanged: (val) {
                        HapticFeedback.selectionClick();
                        ref.read(shiftProvider.notifier).toggleShift();
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: DilkashSpacing.lg),

              // Switch Role Action (if account has multiple roles)
              if (session.hasMultipleRoles)
                Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DilkashRadii.md),
                    side: const BorderSide(color: DilkashColors.borderLight),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: DilkashSpacing.lg,
                      vertical: 6,
                    ),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.swap_horiz_rounded,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    title: Text(
                      'Rolni almashtirish',
                      style: DilkashTypography.h3.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      session.isCourier
                          ? 'Ofitsiant rejimiga o’tish'
                          : 'Kuryer rejimiga o’tish',
                      style: DilkashTypography.caption.copyWith(
                        color: DilkashColors.textSecondaryLight,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: DilkashColors.textMutedLight,
                    ),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.push('/role-select');
                    },
                  ),
                ),

              const Spacer(),

              // Logout Button (>= 56dp height)
              SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    ref.read(authProvider.notifier).logout();
                    context.go('/login');
                  },
                  icon: const Icon(Icons.logout_rounded, color: DilkashColors.error),
                  label: Text(
                    'Tizimdan chiqish',
                    style: DilkashTypography.bodyLarge.copyWith(
                      color: DilkashColors.error,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: DilkashColors.error, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DilkashRadii.md),
                    ),
                  ),
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
