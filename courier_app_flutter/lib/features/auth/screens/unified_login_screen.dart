// Simplified Unified Login Screen for Dilkash Restaurant Staff
// Clean, calm, usable with one hand. Phone + PIN.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../../core/config/app_config.dart';

class UnifiedLoginScreen extends ConsumerStatefulWidget {
  const UnifiedLoginScreen({super.key});

  @override
  ConsumerState<UnifiedLoginScreen> createState() => _UnifiedLoginScreenState();
}

class _UnifiedLoginScreenState extends ConsumerState<UnifiedLoginScreen> {
  final _phoneController = TextEditingController(text: '+998 90 111 22 33');
  final _pinController = TextEditingController(text: '1234');
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    AppConfig.loadSavedBaseUrl();
  }

  Future<void> _showServerSettingsDialog() async {
    await AppConfig.loadSavedBaseUrl();
    if (!mounted) return;
    final urlCtrl = TextEditingController(text: AppConfig.baseUrl);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Server manzili'),
        content: TextField(
          controller: urlCtrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Backend URL',
            hintText: 'https://dilkash-django-production.up.railway.app',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await AppConfig.resetBaseUrl();
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                DilkashFeedback.showSuccess(context, 'Standart server tiklandi');
              }
            },
            child: const Text('Standart'),
          ),
          ElevatedButton(
            onPressed: () async {
              await AppConfig.setBaseUrl(urlCtrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                DilkashFeedback.showSuccess(context, 'Server saqlandi');
              }
            },
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
    urlCtrl.dispose();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final phone = _phoneController.text.trim();
    final pin = _pinController.text.trim();

    if (pin.length < 4) {
      DilkashFeedback.showError(context, 'PIN-kod 4 xonali bo’lishi kerak');
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final session = await ref.read(authProvider.notifier).login(
            phone: phone,
            pin: pin,
          );

      if (!mounted) return;

      if (session.assignedRoles.length == 1) {
        context.go(session.isCourier ? '/courier' : '/waiter');
      } else {
        context.go('/role-select');
      }
    } catch (e) {
      if (!mounted) return;
      DilkashFeedback.showError(
        context,
        e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _fillDemo(String phone, String pin) {
    HapticFeedback.selectionClick();
    _phoneController.text = phone;
    _pinController.text = pin;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DilkashColors.bgLight,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: DilkashSpacing.xl),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  tooltip: 'Server manzili',
                  icon: const Icon(
                    Icons.dns_outlined,
                    color: DilkashColors.textMutedLight,
                  ),
                  onPressed: _showServerSettingsDialog,
                ),
              ),
              const Spacer(flex: 1),
              // Brand Header
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: DilkashColors.primary50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: DilkashColors.primary100),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.restaurant_rounded,
                      size: 38,
                      color: DilkashColors.primary500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: DilkashSpacing.lg),
              Text(
                'Dilkash Xodimlar',
                textAlign: TextAlign.center,
                style: DilkashTypography.h2.copyWith(
                  fontWeight: FontWeight.w700,
                  color: DilkashColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: DilkashSpacing.xs),
              Text(
                'Kuryer va ofitsiantlar uchun sodda tizim',
                textAlign: TextAlign.center,
                style: DilkashTypography.bodyMedium.copyWith(
                  color: DilkashColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: DilkashSpacing.xxl),

              // Phone Field
              Text(
                'Telefon raqamingiz',
                style: DilkashTypography.labelLarge.copyWith(
                  color: DilkashColors.textPrimaryLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: DilkashSpacing.xs),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: DilkashTypography.bodyLarge.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.phone_outlined,
                      color: DilkashColors.primary500),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: DilkashSpacing.lg,
                    vertical: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DilkashRadii.md),
                    borderSide: const BorderSide(color: DilkashColors.borderLight),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DilkashRadii.md),
                    borderSide: const BorderSide(color: DilkashColors.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DilkashRadii.md),
                    borderSide: const BorderSide(
                        color: DilkashColors.primary500, width: 2),
                  ),
                ),
              ),

              const SizedBox(height: DilkashSpacing.lg),

              // PIN Field
              Text(
                'Maxfiy PIN-kod',
                style: DilkashTypography.labelLarge.copyWith(
                  color: DilkashColors.textPrimaryLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: DilkashSpacing.xs),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                style: DilkashTypography.bodyLarge.copyWith(
                  fontSize: 22,
                  letterSpacing: 10,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  prefixIcon: const Icon(Icons.lock_outline_rounded,
                      color: DilkashColors.primary500),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: DilkashSpacing.lg,
                    vertical: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DilkashRadii.md),
                    borderSide: const BorderSide(color: DilkashColors.borderLight),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DilkashRadii.md),
                    borderSide: const BorderSide(color: DilkashColors.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DilkashRadii.md),
                    borderSide: const BorderSide(
                        color: DilkashColors.primary500, width: 2),
                  ),
                ),
              ),

              const SizedBox(height: DilkashSpacing.xl),

              // Demo accounts quick select
              Text(
                'Tezkor sinov hisoblari:',
                style: DilkashTypography.caption.copyWith(
                  color: DilkashColors.textMutedLight,
                ),
              ),
              const SizedBox(height: DilkashSpacing.xs),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Jasur (Ikkala rol)'),
                    backgroundColor: Colors.white,
                    onPressed: () => _fillDemo('+998 90 111 22 33', '1234'),
                  ),
                  ActionChip(
                    label: const Text('Sardor (Ofitsiant)'),
                    backgroundColor: Colors.white,
                    onPressed: () => _fillDemo('+998 90 222 33 44', '2345'),
                  ),
                  ActionChip(
                    label: const Text('Nodir (Ofitsiant)'),
                    backgroundColor: Colors.white,
                    onPressed: () => _fillDemo('+998 90 333 44 55', '3456'),
                  ),
                ],
              ),

              const Spacer(flex: 2),

              // Primary Login Action (>= 56dp height)
              SizedBox(
                height: 58,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DilkashColors.primary500,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DilkashRadii.md),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'Tizimga kirish',
                          style: DilkashTypography.bodyLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: DilkashSpacing.lg),
            ],
          ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
