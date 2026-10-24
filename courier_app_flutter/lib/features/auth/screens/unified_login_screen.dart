// Unified Login Screen for Dilkash Restaurant Staff (Courier & Waiter)
// Authentic Uzbek Latin UI, PIN/Code login, Biometric unlock, and quick demo credentials.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../../core/auth/biometric_service.dart';

class UnifiedLoginScreen extends ConsumerStatefulWidget {
  const UnifiedLoginScreen({super.key});

  @override
  ConsumerState<UnifiedLoginScreen> createState() => _UnifiedLoginScreenState();
}

class _UnifiedLoginScreenState extends ConsumerState<UnifiedLoginScreen> {
  final _phoneController = TextEditingController(text: '+998 90 123 45 67');
  final _codeController = TextEditingController();
  final _pinController = TextEditingController(text: '1234');
  bool _useStaffCode = false;
  bool _hasBiometrics = false;
  bool _obscurePin = true;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final enabled = await BiometricService.isBiometricEnabled();
    if (mounted) setState(() => _hasBiometrics = enabled);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final pin = _pinController.text.trim();
    if (pin.length < 4) {
      DilkashFeedback.showError(context, 'PIN-kod kamida 4 xonali boʻlishi shart');
      return;
    }

    HapticFeedback.mediumImpact();
    await ref.read(authProvider.notifier).login(
          phone: _useStaffCode ? null : _phoneController.text,
          staffCode: _useStaffCode ? _codeController.text : null,
          pin: pin,
        );

    final authState = ref.read(authProvider);
    authState.when(
      data: (session) {
        if (session != null && mounted) {
          DilkashFeedback.showSuccess(
            context,
            'Xush kelibsiz, ${session.name}!',
          );
          if (session.hasMultipleRoles) {
            context.go('/role-select');
          } else {
            context.go(session.isCourier ? '/courier' : '/waiter');
          }
        }
      },
      loading: () {},
      error: (e, _) {
        if (mounted) {
          DilkashFeedback.showError(
            context,
            e.toString().replaceAll('Exception: ', ''),
          );
        }
      },
    );
  }

  void _handleBiometricLogin() async {
    HapticFeedback.lightImpact();
    await ref.read(authProvider.notifier).loginWithBiometrics();
    final authState = ref.read(authProvider);
    authState.when(
      data: (session) {
        if (session != null && mounted) {
          DilkashFeedback.showSuccess(
              context, 'Biometrik tasdiqlandi: ${session.name}');
          if (session.hasMultipleRoles) {
            context.go('/role-select');
          } else {
            context.go(session.isCourier ? '/courier' : '/waiter');
          }
        }
      },
      loading: () {},
      error: (e, _) {
        if (mounted) {
          DilkashFeedback.showError(
            context,
            'Biometrik kirish muvaffaqiyatsiz. PIN orqali kiring.',
          );
        }
      },
    );
  }

  void _setDemoUser(String phone, String name, String pin) {
    setState(() {
      _useStaffCode = false;
      _phoneController.text = phone;
      _pinController.text = pin;
    });
    DilkashFeedback.showInfo(context, '$name maʻlumotlari yuklandi');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: DilkashColors.background(isDark),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Restaurant Crest & Brand
                  Center(
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            DilkashColors.primary500,
                            DilkashColors.primary700,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: DilkashColors.primary500.withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.restaurant_menu_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'DILKASH',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      color: DilkashColors.textPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Xodimlar Ilovasi • Kuryer va Ofitsiant',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: DilkashColors.textSecondary(isDark),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Auth Input Mode Switch (Phone vs Staff Code)
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.grey[200],
                      borderRadius: DilkashRadii.radiusSm,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _useStaffCode = false),
                            borderRadius: DilkashRadii.radiusSm,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !_useStaffCode
                                    ? (isDark ? Colors.grey[800] : Colors.white)
                                    : Colors.transparent,
                                borderRadius: DilkashRadii.radiusSm,
                              ),
                              child: Center(
                                child: Text(
                                  'Telefon raqam',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: !_useStaffCode
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: DilkashColors.textPrimary(isDark),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _useStaffCode = true),
                            borderRadius: DilkashRadii.radiusSm,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _useStaffCode
                                    ? (isDark ? Colors.grey[800] : Colors.white)
                                    : Colors.transparent,
                                borderRadius: DilkashRadii.radiusSm,
                              ),
                              child: Center(
                                child: Text(
                                  'Xodim kodi (DIL-...)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: _useStaffCode
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: DilkashColors.textPrimary(isDark),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Login Inputs
                  if (!_useStaffCode)
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Telefon raqam',
                        prefixIcon: const Icon(Icons.phone_iphone_rounded),
                        border: OutlineInputBorder(
                          borderRadius: DilkashRadii.radiusSm,
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.grey[900] : Colors.white,
                      ),
                    )
                  else
                    TextField(
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'Xodim kodi (Masalan: DIL-101)',
                        prefixIcon: const Icon(Icons.badge_rounded),
                        border: OutlineInputBorder(
                          borderRadius: DilkashRadii.radiusSm,
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.grey[900] : Colors.white,
                      ),
                    ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    obscureText: _obscurePin,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'Kirish PIN-kodi',
                      counterText: '',
                      prefixIcon: const Icon(Icons.lock_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePin
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded),
                        onPressed: () =>
                            setState(() => _obscurePin = !_obscurePin),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: DilkashRadii.radiusSm,
                      ),
                      filled: true,
                      fillColor: isDark ? Colors.grey[900] : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Main Login Action Button (>= 56dp height)
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DilkashColors.primary500,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: DilkashRadii.radiusSm,
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Tizimga kirish',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),

                  // Biometric Unlock Button
                  if (_hasBiometrics) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: isLoading ? null : _handleBiometricLogin,
                        icon: const Icon(Icons.fingerprint_rounded, size: 26),
                        label: const Text(
                          'Face ID / Barmoq izi orqali kirish',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
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

                  const SizedBox(height: 28),
                  Divider(color: Colors.grey.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),

                  // Quick Demo Accounts Selector (For fast testing and verification)
                  Text(
                    'Tezkor sinov xodimlari:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: DilkashColors.textSecondary(isDark),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.swap_horiz_rounded, size: 16),
                        label: const Text('Jasur (Ikkala rol: Kuryer + Ofitsiant)'),
                        onPressed: () => _setDemoUser(
                          '+998 90 123 45 67',
                          'Jasur Rahimov',
                          '1234',
                        ),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.two_wheeler_rounded, size: 16),
                        label: const Text('Bobur (Faqat Kuryer)'),
                        onPressed: () => _setDemoUser(
                          '+998 93 555 11 22',
                          'Bobur Mirzayev',
                          '1234',
                        ),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.room_service_rounded, size: 16),
                        label: const Text('Malika (Faqat Ofitsiant)'),
                        onPressed: () => _setDemoUser(
                          '+998 97 777 88 99',
                          'Malika Karimova',
                          '1234',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
