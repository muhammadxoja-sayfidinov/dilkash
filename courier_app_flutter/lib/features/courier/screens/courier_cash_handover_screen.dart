// Courier Cash Handover Screen
// Reconciles physical cash collected per order vs expected balance, cashier PIN signoff, and discrepancy report.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';
import '../../../core/audit/audit_logger.dart';
import '../../../core/auth/auth_notifier.dart';

class CourierCashHandoverScreen extends ConsumerStatefulWidget {
  const CourierCashHandoverScreen({super.key});

  @override
  ConsumerState<CourierCashHandoverScreen> createState() =>
      _CourierCashHandoverScreenState();
}

class _CourierCashHandoverScreenState
    extends ConsumerState<CourierCashHandoverScreen> {
  final double _expectedAmount = 239000.0;
  final double _courierEarnings = 120000.0;
  final double _tipsTotal = 15000.0;

  late TextEditingController _actualController;
  final _cashierPinController = TextEditingController(text: '1234');
  final _notesController = TextEditingController();

  double _actualAmount = 239000.0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _actualController =
        TextEditingController(text: _expectedAmount.toInt().toString());
  }

  @override
  void dispose() {
    _actualController.dispose();
    _cashierPinController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _discrepancy => _actualAmount - _expectedAmount;

  void _submitHandover() async {
    final pin = _cashierPinController.text.trim();
    if (pin.length < 4) {
      DilkashFeedback.showError(context, 'Kassir PIN-kodi kiritilmadi');
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.heavyImpact();

    try {
      final repo = ref.read(staffRepositoryProvider);
      final res = await repo.submitCashHandover(
        expectedAmount: _expectedAmount,
        actualAmount: _actualAmount,
        cashierPin: pin,
        notes: _notesController.text.trim(),
      );

      AuditLogger.instance.log(
        staffName: 'Kuryer',
        role: 'courier',
        action: 'CASH_HANDOVER',
        details:
            'Kutilgan: $_expectedAmount, Topshirilgan: $_actualAmount, Farq: $_discrepancy',
        managerPinUsed: pin,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        _showSuccessDialog(res['handover_id'] ?? 'H-001');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        DilkashFeedback.showError(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  void _showSuccessDialog(String handoverId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: DilkashColors.primary500),
            SizedBox(width: 8),
            Text('Kassa Topshirildi'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kvitansiya raqami: $handoverId',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Topshirilgan naqd pul: ${UzbekFormatters.formatCurrency(_actualAmount)}'),
            Text('Kuryerning oʻz daromadi: ${UzbekFormatters.formatCurrency(_courierEarnings)}'),
            if (_discrepancy != 0)
              Text(
                'Farq: ${UzbekFormatters.formatCurrency(_discrepancy)}',
                style: TextStyle(
                  color: _discrepancy < 0 ? Colors.red : Colors.green,
                  fontWeight: FontWeight.w700,
                ),
              ),
            const SizedBox(height: 12),
            const Text(
              'Mablagʻ restoran bosh kassiri tomonidan qabul qilindi va tasdiqlandi.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/courier');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: DilkashColors.primary500,
              foregroundColor: Colors.white,
            ),
            child: const Text('Bosh sahifaga qaytish'),
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
        title: const Text('Kassaga Naqd Pul Topshirish'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Clear separation between Cash on Hand and Earnings/Tips
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
                        const Icon(Icons.point_of_sale_rounded,
                            color: DilkashColors.primary500, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Mablagʻlar taqsimoti:',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: DilkashColors.textPrimary(isDark),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    _buildBalanceRow(
                      'Restoran kassasiga topshiriladigan naqd pul:',
                      UzbekFormatters.formatCurrency(_expectedAmount),
                      isHighlight: true,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                    _buildBalanceRow(
                      'Kuryerning sof yetkazish daromadi:',
                      UzbekFormatters.formatCurrency(_courierEarnings),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                    _buildBalanceRow(
                      'Mijozlar bergan choychaqa (Tips):',
                      UzbekFormatters.formatCurrency(_tipsTotal),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Actual Cash Counted
              Text(
                'Topshirilayotgan haqiqiy summa (soʻm):',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: DilkashColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _actualController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.payments_rounded),
                  border: OutlineInputBorder(borderRadius: DilkashRadii.radiusSm),
                  filled: true,
                  fillColor: isDark ? Colors.grey[900] : Colors.white,
                ),
                onChanged: (val) {
                  final num = double.tryParse(val.replaceAll(' ', '')) ?? 0.0;
                  setState(() => _actualAmount = num);
                },
              ),
              const SizedBox(height: 12),

              // Discrepancy Alert
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _discrepancy == 0
                      ? DilkashColors.primary500.withValues(alpha: 0.1)
                      : (_discrepancy < 0
                          ? Colors.red.withValues(alpha: 0.1)
                          : Colors.amber.withValues(alpha: 0.1)),
                  borderRadius: DilkashRadii.radiusSm,
                  border: Border.all(
                    color: _discrepancy == 0
                        ? DilkashColors.primary500
                        : (_discrepancy < 0 ? Colors.red : Colors.amber),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _discrepancy == 0
                          ? Icons.check_circle_rounded
                          : Icons.info_outline_rounded,
                      color: _discrepancy == 0
                          ? DilkashColors.primary500
                          : (_discrepancy < 0 ? Colors.red : Colors.amber[800]),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _discrepancy == 0
                                ? 'Kassa toʻliq mos (Farq yoʻq)'
                                : (_discrepancy < 0
                                    ? 'Yetishmovchilik mavjud!'
                                    : 'Ortiqcha summa!'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: DilkashColors.textPrimary(isDark),
                            ),
                          ),
                          Text(
                            'Farq: ${UzbekFormatters.formatCurrency(_discrepancy)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: _discrepancy == 0
                                  ? DilkashColors.primary500
                                  : (_discrepancy < 0
                                      ? Colors.red
                                      : Colors.amber[800]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Cashier PIN
              Text(
                'Kassirning 4 xonali PIN-kodi (Tasdiqlash uchun):',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: DilkashColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _cashierPinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: InputDecoration(
                  counterText: '',
                  prefixIcon: const Icon(Icons.pin_rounded),
                  hintText: 'Kassir PIN-kodini kiriting (Test: 1234)',
                  border: OutlineInputBorder(borderRadius: DilkashRadii.radiusSm),
                  filled: true,
                  fillColor: isDark ? Colors.grey[900] : Colors.white,
                ),
              ),
              const SizedBox(height: 14),

              // Notes
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Kassaga izoh (ixtiyoriy)',
                  border: OutlineInputBorder(borderRadius: DilkashRadii.radiusSm),
                  filled: true,
                  fillColor: isDark ? Colors.grey[900] : Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              // Handover Button (>= 56dp height)
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitHandover,
                  icon: const Icon(Icons.handshake_rounded),
                  label: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Kassirga Topshirish va Tasdiqlash',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DilkashColors.primary500,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: DilkashRadii.radiusSm),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceRow(String label, String value,
      {bool isHighlight = false, required bool isDark}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isHighlight
                  ? DilkashColors.textPrimary(isDark)
                  : DilkashColors.textSecondary(isDark),
              fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isHighlight ? FontWeight.w900 : FontWeight.w700,
            color: isHighlight
                ? DilkashColors.primary500
                : DilkashColors.textPrimary(isDark),
          ),
        ),
      ],
    );
  }
}
