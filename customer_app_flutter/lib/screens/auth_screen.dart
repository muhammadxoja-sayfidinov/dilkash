import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';
import '../services/auth_provider.dart';
import '../services/api_service.dart';
import 'main_navigation_shell.dart';

class AuthScreen extends StatefulWidget {
  final bool returnOnSuccess;

  const AuthScreen({super.key, this.returnOnSuccess = false});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isRegister = false;
  bool _otpSent = false;
  bool _isLoading = false;
  String? _errorMessage;

  final TextEditingController _phoneController =
      TextEditingController(text: '+998 90 123 45 67');
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _sendOtp() {
    final rawPhone = _phoneController.text.trim();
    if (rawPhone.replaceAll(RegExp(r'\D'), '').length < 9) {
      setState(() =>
          _errorMessage = 'Iltimos, toʻliq telefon raqamingizni kiriting');
      return;
    }
    if (_isRegister && _nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Iltimos, ismingizni kiriting');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // SMS OTP yuborish simulyatsiyasi
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _otpSent = true;
          _otpController.text = '1234'; // Sinov kodi
        });
      }
    });
  }

  Future<void> _verifyAndLogin() async {
    final code = _otpController.text.trim();
    if (code.length < 4) {
      setState(() => _errorMessage = '4 xonali SMS kodni kiriting');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.loginOrRegister(
        phone: _phoneController.text.trim(),
        fullName: _isRegister ? _nameController.text.trim() : null,
      );

      if (mounted) {
        DilkashFeedback.showSuccess(
          context,
          'Xush kelibsiz, ${auth.user?.fullName ?? "Mijoz"}!',
        );

        if (widget.returnOnSuccess) {
          Navigator.pop(context, true);
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainNavigationShell()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _showServerSettingsDialog() {
    final controller = TextEditingController(text: ApiService.baseUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Server sozlamasi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Backend server URL manzilini kiriting:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'http://10.40.4.94:8000',
                labelText: 'Server Base URL',
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Tezkor tanlov:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ActionChip(
                  label: const Text('10.40.4.94:8000 (Wi-Fi)'),
                  onPressed: () => controller.text = 'http://10.40.4.94:8000',
                ),
                ActionChip(
                  label: const Text('127.0.0.1:8000 (USB/ADB)'),
                  onPressed: () => controller.text = 'http://127.0.0.1:8000',
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newUrl = controller.text.trim();
              if (newUrl.isNotEmpty) {
                await ApiService.setBaseUrl(newUrl);
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() {});
              }
            },
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: DilkashColors.background(isDark),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Server sozlamalari',
            onPressed: _showServerSettingsDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Dilkash Brand Emblem
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isDark
                      ? DilkashColors.surfaceDarkElevated
                      : DilkashColors.primary50,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark
                        ? DilkashColors.borderDark
                        : DilkashColors.primary200,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.restaurant_rounded,
                    size: 36,
                    color: isDark
                        ? DilkashColors.primary400
                        : DilkashColors.primary500,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                _otpSent
                    ? 'SMS Tasdiqlash'
                    : (_isRegister ? 'Roʻyxatdan oʻtish' : 'Xush kelibsiz'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: DilkashColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _otpSent
                    ? '${_phoneController.text} raqamiga yuborilgan kodni kiriting'
                    : 'Restoran dastavka va olib ketish xizmatidan foydalaning',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: DilkashColors.textSecondary(isDark),
                ),
              ),
              const SizedBox(height: 28),

              // Error banner if any
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: DilkashColors.errorLight,
                    borderRadius: DilkashRadii.radiusSm,
                    border: Border.all(
                        color: DilkashColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 20, color: DilkashColors.error),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                              color: DilkashColors.error,
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Card Container
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
                child: Column(
                  children: [
                    if (!_otpSent) ...[
                      // Full Name if registering
                      if (_isRegister) ...[
                        DilkashTextField(
                          controller: _nameController,
                          label: 'Ismingiz',
                          hintText: 'Masalan: Sardor Rahimiy',
                          prefixIcon: Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Phone Field
                      DilkashTextField(
                        controller: _phoneController,
                        label: 'Telefon raqam',
                        hintText: '+998 90 123 45 67',
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_outlined,
                      ),
                      const SizedBox(height: 20),

                      // Continue Button
                      DilkashButton(
                        label: 'SMS Kod olish',
                        isLoading: _isLoading,
                        trailingIcon: Icons.arrow_forward_rounded,
                        onPressed: _sendOtp,
                      ),
                    ] else ...[
                      // Test hint box
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? DilkashColors.surfaceDarkElevated
                              : DilkashColors.amber50,
                          borderRadius: DilkashRadii.radiusSm,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                size: 18, color: DilkashColors.amber600),
                            const SizedBox(width: 8),
                            Text(
                              'Sinov uchun SMS kod: 1234',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? DilkashColors.amber400
                                    : DilkashColors.amber700,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // OTP Input
                      DilkashTextField(
                        controller: _otpController,
                        label: 'SMS kodni kiriting',
                        hintText: '1234',
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.sms_outlined,
                      ),
                      const SizedBox(height: 20),

                      // Verify Button
                      DilkashButton(
                        label: 'Tasdiqlash va Kirish',
                        isLoading: _isLoading,
                        onPressed: _verifyAndLogin,
                      ),
                      const SizedBox(height: 12),

                      TextButton(
                        onPressed: () => setState(() => _otpSent = false),
                        child: Text(
                          'Raqamni oʻzgartirish',
                          style: TextStyle(
                            color: DilkashColors.textSecondary(isDark),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Switch between Login and Register
              if (!_otpSent)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isRegister ? 'Akkountingiz bormi?' : 'Yangi mijozmisiz?',
                      style: TextStyle(
                        color: DilkashColors.textSecondary(isDark),
                        fontSize: 13,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _isRegister = !_isRegister;
                        _errorMessage = null;
                      }),
                      child: Text(
                        _isRegister ? 'Kirish' : 'Roʻyxatdan oʻtish',
                        style: TextStyle(
                          color: DilkashColors.primary(isDark),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),

              // Guest explore button
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MainNavigationShell()),
                  );
                },
                child: Text(
                  'Mehmon sifatida koʻrish',
                  style: TextStyle(
                    color: DilkashColors.textSecondary(isDark),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
