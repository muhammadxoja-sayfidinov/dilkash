// Simplified Unified Login Screen for Dilkash Restaurant Staff
// Clean, calm, usable with one hand. Phone + PIN.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/local_discovery_service.dart';

class UnifiedLoginScreen extends ConsumerStatefulWidget {
  const UnifiedLoginScreen({super.key});

  @override
  ConsumerState<UnifiedLoginScreen> createState() => _UnifiedLoginScreenState();
}

class _UnifiedLoginScreenState extends ConsumerState<UnifiedLoginScreen> {
  final _phoneController = TextEditingController(text: '+998 90 111 22 33');
  final _pinController = TextEditingController(text: '1234');
  bool _isLoading = false;
  bool _isDiscovering = false;

  @override
  void initState() {
    super.initState();
    _initConnection();
  }

  Future<void> _initConnection() async {
    await AppConfig.loadAll();
    if (mounted) setState(() {});
    if (AppConfig.isLocalPosMode) {
      await _runDiscovery();
    }
  }

  Future<String?> _runDiscovery() async {
    if (mounted) setState(() => _isDiscovering = true);
    final found = await LocalDiscoveryService.discoverPosHub(
      savedUrl: AppConfig.posLocalBaseUrl,
    );
    if (found != null) {
      await AppConfig.setLocalPosBaseUrl(found);
    }
    if (mounted) {
      setState(() => _isDiscovering = false);
    }
    return found;
  }

  Future<void> _showServerSettingsDialog() async {
    await AppConfig.loadAll();
    if (!mounted) return;
    final posCtrl = TextEditingController(text: AppConfig.posLocalBaseUrl);
    final cloudCtrl = TextEditingController(text: AppConfig.cloudBaseUrl);
    String mode = AppConfig.connectionMode;
    bool searching = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Ulanish rejimi'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: AppConfig.modeLocalPos,
                      label: Text('Wi-Fi POS'),
                      icon: Icon(Icons.wifi_rounded),
                    ),
                    ButtonSegment(
                      value: AppConfig.modeCloud,
                      label: Text('Cloud'),
                      icon: Icon(Icons.cloud_outlined),
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: (val) {
                    setDialogState(() => mode = val.first);
                  },
                ),
                const SizedBox(height: 16),
                if (mode == AppConfig.modeLocalPos) ...[
                  TextField(
                    controller: posCtrl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Dilkash POS Hub (Lokal Wi-Fi)',
                      hintText: 'http://192.168.1.105:8088',
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: searching
                        ? null
                        : () async {
                            setDialogState(() => searching = true);
                            final found = await LocalDiscoveryService.discoverPosHub(
                              savedUrl: posCtrl.text,
                            );
                            if (ctx.mounted) {
                              setDialogState(() {
                                searching = false;
                                if (found != null) posCtrl.text = found;
                              });
                            }
                          },
                    icon: searching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.radar_rounded),
                    label: Text(searching ? 'Izlanmoqda...' : 'Wi-Fi dan POS topish'),
                  ),
                ] else ...[
                  TextField(
                    controller: cloudCtrl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Cloud Django URL (Kuryer)',
                      hintText: 'https://dilkash-django-production.up.railway.app',
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await AppConfig.resetBaseUrl();
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  setState(() {});
                  DilkashFeedback.showSuccess(context, 'Standart Wi-Fi POS rejimi tiklandi');
                }
              },
              child: const Text('Standart'),
            ),
            ElevatedButton(
              onPressed: () async {
                await AppConfig.setConnectionMode(mode);
                if (mode == AppConfig.modeLocalPos) {
                  await AppConfig.setLocalPosBaseUrl(posCtrl.text);
                } else {
                  await AppConfig.setCloudBaseUrl(cloudCtrl.text);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  setState(() {});
                  DilkashFeedback.showSuccess(context, 'Tarmoq sozlamasi saqlandi');
                }
              },
              child: const Text('Saqlash'),
            ),
          ],
        ),
      ),
    );
    posCtrl.dispose();
    cloudCtrl.dispose();
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _showServerSettingsDialog,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppConfig.isLocalPosMode
                              ? (AppConfig.hasLocalPos
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFFEF3C7))
                              : const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              AppConfig.isLocalPosMode ? Icons.wifi_rounded : Icons.cloud_outlined,
                              size: 16,
                              color: AppConfig.isLocalPosMode
                                  ? (AppConfig.hasLocalPos
                                      ? const Color(0xFF15803D)
                                      : const Color(0xFFB45309))
                                  : const Color(0xFF0369A1),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _isDiscovering
                                    ? 'Wi-Fi POS izlanmoqda...'
                                    : AppConfig.isLocalPosMode
                                        ? (AppConfig.hasLocalPos
                                            ? 'Wi-Fi POS: ${AppConfig.posLocalBaseUrl.replaceFirst('http://', '')}'
                                            : 'Wi-Fi POS tanlanmagan (bosing)')
                                        : 'Cloud Server (Kuryer)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Server manzili',
                    icon: const Icon(
                      Icons.dns_outlined,
                      color: DilkashColors.textMutedLight,
                    ),
                    onPressed: _showServerSettingsDialog,
                  ),
                ],
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
