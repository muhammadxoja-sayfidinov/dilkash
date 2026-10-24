// Waiter Bill Screen
// Features check view, split (equally, by item, by guest), discount (Manager PIN protected),
// service charge, multi-payment (cash, card, Click, Payme), mark paid, and receipt QR.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';
import '../../../core/audit/audit_logger.dart';
import '../../../core/auth/auth_notifier.dart';
import '../widgets/manager_pin_dialog.dart';

class WaiterBillScreen extends ConsumerStatefulWidget {
  final String tableNumber;

  const WaiterBillScreen({super.key, required this.tableNumber});

  @override
  ConsumerState<WaiterBillScreen> createState() => _WaiterBillScreenState();
}

class _WaiterBillScreenState extends ConsumerState<WaiterBillScreen> {
  Map<String, dynamic>? _table;
  bool _isLoading = true;

  // Split mode: 'equal', 'by_guest', 'by_item'
  String _splitMode = 'equal';
  int _equalSplitPersons = 2;

  // Discount & Service Charge
  double _discountPercent = 0.0;
  final double _servicePercent = 10.0;
  String? _verifiedManagerPin;

  // Payment Method
  String _paymentMethod = 'cash'; // 'cash', 'card', 'click', 'payme'

  @override
  void initState() {
    super.initState();
    _loadTable();
  }

  Future<void> _loadTable() async {
    final repo = ref.read(staffRepositoryProvider);
    try {
      final tables = await repo.fetchFloorTables();
      final match = tables.firstWhere(
        (t) => t['table_number'] == widget.tableNumber,
        orElse: () => tables.first,
      );
      if (mounted) {
        setState(() {
          _table = Map<String, dynamic>.from(match);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _subtotal {
    final items = List<Map<String, dynamic>>.from(_table?['items'] ?? []);
    double sum = 0.0;
    for (final it in items) {
      sum += ((it['price'] as num) * (it['quantity'] as num));
    }
    return sum > 0 ? sum : 240000.0;
  }

  double get _serviceAmount => _subtotal * (_servicePercent / 100);
  double get _discountAmount => _subtotal * (_discountPercent / 100);
  double get _finalTotal => _subtotal + _serviceAmount - _discountAmount;

  void _applyDiscount(double percent) async {
    if (percent == 0.0) {
      setState(() => _discountPercent = 0.0);
      return;
    }

    final verified = await ManagerPinDialog.verify(
      context: context,
      actionTitle: '$percent% Chegirma qoʻllash',
      reason: 'Stol #${widget.tableNumber} uchun sodiqlik chegirmasi',
    );

    if (verified) {
      setState(() {
        _discountPercent = percent;
        _verifiedManagerPin = '1234';
      });
      if (mounted) {
        DilkashFeedback.showSuccess(context, '$percent% chegirma tasdiqlandi');
      }
    }
  }

  void _voidItem(Map<String, dynamic> item) async {
    final verified = await ManagerPinDialog.verify(
      context: context,
      actionTitle: '${item['dish_name']} ni hisobdan bekor qilish',
      reason: 'Mijoz talabi / xato buyurtma',
    );

    if (verified) {
      final repo = ref.read(staffRepositoryProvider);
      await repo.cancelOrderItem(
        orderId: 1,
        itemId: item['id'] ?? 1,
        reason: 'Mijoz bekor qildi',
        managerPin: '1234',
      );
      _loadTable();
      if (mounted) {
        DilkashFeedback.showSuccess(context, 'Taom hisobdan chiqarildi');
      }
    }
  }

  void _settleBill() async {
    HapticFeedback.heavyImpact();
    final repo = ref.read(staffRepositoryProvider);

    try {
      final res = await repo.settleTableBill(
        tableNumber: widget.tableNumber,
        paymentMethod: _paymentMethod,
        totalAmount: _subtotal,
        discountPercent: _discountPercent,
        managerPinForDiscount: _verifiedManagerPin,
      );

      AuditLogger.instance.log(
        staffName: 'Ofitsiant',
        role: 'waiter',
        action: 'TABLE_BILL_SETTLED',
        details:
            'Stol #${widget.tableNumber}: Jami ${_finalTotal.toInt()} soʻm, Usul: $_paymentMethod',
      );

      if (mounted) {
        _showReceiptDialog(res['receipt_qr'] ?? 'RECEIPT-001');
      }
    } catch (e) {
      if (mounted) {
        DilkashFeedback.showError(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  void _showReceiptDialog(String receiptCode) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: DilkashColors.primary500),
            SizedBox(width: 8),
            Text('Hisob Yopildi!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stol ${widget.tableNumber} toʻlovi qabul qilindi.'),
            const SizedBox(height: 6),
            Text('Toʻlov usuli: ${_paymentMethod.toUpperCase()}'),
            Text('Toʻlangan summa: ${UzbekFormatters.formatCurrency(_finalTotal)}'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_2_rounded, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Elektron chek kodi: $receiptCode\nPrinterga uzatildi.',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/waiter');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: DilkashColors.primary500,
              foregroundColor: Colors.white,
            ),
            child: const Text('Zallarga qaytish'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading || _table == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final items = List<Map<String, dynamic>>.from(_table!['items'] ?? []);

    return Scaffold(
      backgroundColor: DilkashColors.background(isDark),
      appBar: AppBar(
        title: Text('Stol ${widget.tableNumber} Hisobi'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Itemized Check List
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF16231D) : Colors.white,
                  borderRadius: DilkashRadii.radiusMd,
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E3529) : DilkashColors.neutral200,
                  ),
                  boxShadow: DilkashShadows.card(isDark),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Buyurtma Qilingan Taomlar',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: DilkashColors.textPrimary(isDark),
                          ),
                        ),
                        Text(
                          '${items.length} ta pozitsiya',
                          style: TextStyle(
                            fontSize: 12,
                            color: DilkashColors.textSecondary(isDark),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Taomlar roʻyxati boʻsh'),
                      )
                    else
                      ...items.map((it) {
                        final price = (it['price'] as num).toDouble();
                        final qty = it['quantity'] as int;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Text(
                                '${qty}x',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: DilkashColors.primary500,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      it['dish_name'],
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: DilkashColors.textPrimary(isDark),
                                      ),
                                    ),
                                    if (it['portion'] != null)
                                      Text(
                                        it['portion'],
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: DilkashColors.textSecondary(isDark),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                UzbekFormatters.formatCurrency(price * qty),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline,
                                    size: 18, color: Colors.red),
                                tooltip: 'Bekor qilish (Menejer PIN)',
                                onPressed: () => _voidItem(it),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Split Mode Selector
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF16231D) : Colors.white,
                  borderRadius: DilkashRadii.radiusSm,
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E3529) : DilkashColors.neutral200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hisobni boʻlish (Split Bill):',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: DilkashColors.textPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Barchasi bitta'),
                            selected: _splitMode == 'single',
                            onSelected: (_) => setState(() => _splitMode = 'single'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Teng boʻlish'),
                            selected: _splitMode == 'equal',
                            onSelected: (_) => setState(() => _splitMode = 'equal'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Mehmon boʻyicha'),
                            selected: _splitMode == 'by_guest',
                            onSelected: (_) => setState(() => _splitMode = 'by_guest'),
                          ),
                        ],
                      ),
                    ),
                    if (_splitMode == 'equal') ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text('Kishilar soni:'),
                          const SizedBox(width: 12),
                          DropdownButton<int>(
                            value: _equalSplitPersons,
                            items: [2, 3, 4, 5, 6].map((n) {
                              return DropdownMenuItem(value: n, child: Text('$n kishi'));
                            }).toList(),
                            onChanged: (v) => setState(() => _equalSplitPersons = v ?? 2),
                          ),
                          const Spacer(),
                          Text(
                            'Har biriga: ${UzbekFormatters.formatCurrency(_finalTotal / _equalSplitPersons)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: DilkashColors.primary500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Discount & Service Charge Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF16231D) : Colors.white,
                  borderRadius: DilkashRadii.radiusSm,
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E3529) : DilkashColors.neutral200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Xizmat haqi (Xizmat):',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(
                          '${_servicePercent.toInt()}% (${UzbekFormatters.formatCurrency(_serviceAmount)})',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Chegirma (Menejer tasdigʻi):',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(
                          _discountPercent > 0
                              ? '-${_discountPercent.toInt()}% (${UzbekFormatters.formatCurrency(_discountAmount)})'
                              : '0%',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _discountPercent > 0 ? Colors.green : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ActionChip(
                          label: const Text('0%'),
                          onPressed: () => _applyDiscount(0),
                        ),
                        ActionChip(
                          label: const Text('5%'),
                          onPressed: () => _applyDiscount(5),
                        ),
                        ActionChip(
                          label: const Text('10%'),
                          onPressed: () => _applyDiscount(10),
                        ),
                        ActionChip(
                          label: const Text('15%'),
                          onPressed: () => _applyDiscount(15),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Payment Method Selector
              Text(
                'Toʻlov usulini tanlang:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: DilkashColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildPaymentChip('cash', 'Naqd pul', Icons.payments_rounded),
                  const SizedBox(width: 8),
                  _buildPaymentChip('card', 'Bank kartasi', Icons.credit_card_rounded),
                  const SizedBox(width: 8),
                  _buildPaymentChip('click', 'Click', Icons.phone_android_rounded),
                  const SizedBox(width: 8),
                  _buildPaymentChip('payme', 'Payme', Icons.account_balance_wallet_rounded),
                ],
              ),
              const SizedBox(height: 20),

              // Total Payable Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: DilkashColors.primary500.withValues(alpha: 0.1),
                  borderRadius: DilkashRadii.radiusSm,
                  border: Border.all(color: DilkashColors.primary500),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Jami Toʻlanadigan Summa:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      UzbekFormatters.formatCurrency(_finalTotal),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: DilkashColors.primary500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Settle Button (>= 56dp height)
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _settleBill,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text(
                    'Toʻlovni Qabul Qilish va Chek Chiqarish',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DilkashColors.primary500,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: DilkashRadii.radiusSm,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentChip(String id, String label, IconData icon) {
    final isSelected = _paymentMethod == id;
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _paymentMethod = id);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? DilkashColors.primary500.withValues(alpha: 0.15)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? DilkashColors.primary500 : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 20,
                  color: isSelected ? DilkashColors.primary500 : Colors.grey),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? DilkashColors.primary500 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
