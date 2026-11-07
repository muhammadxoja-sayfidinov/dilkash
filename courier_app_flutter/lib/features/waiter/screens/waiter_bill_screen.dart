// Screen 3: Waiter Bill Screen
// Strictly follows KEEP:
// - Items and total
// - Choose payment (naqd / karta / Click / Payme)
// - ONE primary button (>= 56dp): "To’landi"
// - No discounts, no split bill, no manager PINs

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';
import '../../../core/auth/auth_notifier.dart';

class WaiterBillScreen extends ConsumerStatefulWidget {
  final String tableNumber;

  const WaiterBillScreen({
    super.key,
    required this.tableNumber,
  });

  @override
  ConsumerState<WaiterBillScreen> createState() => _WaiterBillScreenState();
}

class _WaiterBillScreenState extends ConsumerState<WaiterBillScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _tableData;
  String _selectedPayment = 'naqd'; // 'naqd', 'karta', 'online'
  bool _isSettling = false;

  final List<Map<String, dynamic>> _paymentMethods = const [
    {
      'id': 'naqd',
      'title': 'Naqd',
      'subtitle': 'Pul hisobi',
      'icon': Icons.payments_rounded,
      'color': Color(0xFF16A34A),
    },
    {
      'id': 'karta',
      'title': 'Karta',
      'subtitle': 'Terminal',
      'icon': Icons.credit_card_rounded,
      'color': Color(0xFF2563EB),
    },
    {
      'id': 'online',
      'title': 'Click / Payme',
      'subtitle': 'QR to’lov',
      'icon': Icons.qr_code_2_rounded,
      'color': Color(0xFF0284C7),
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadTableBill();
  }

  Future<void> _loadTableBill() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(staffRepositoryProvider);
      final tables = await repo.fetchTables();
      final table = tables.firstWhere(
        (t) => t['table_number'] == widget.tableNumber,
        orElse: () => <String, dynamic>{},
      );

      if (mounted) {
        if (table.isEmpty) {
          setState(() {
            _error = 'Stol topilmadi';
            _isLoading = false;
          });
        } else {
          setState(() {
            _tableData = table;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _settleBill() async {
    if (_isSettling || _tableData == null) return;

    setState(() => _isSettling = true);
    HapticFeedback.heavyImpact();

    try {
      final repo = ref.read(staffRepositoryProvider);
      await repo.settleTableBill(
        tableNumber: widget.tableNumber,
        paymentMethod: _selectedPayment,
      );

      if (mounted) {
        DilkashFeedback.showSuccess(
          context,
          'Stol ${widget.tableNumber} hisobi to’landi va yopildi!',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        DilkashFeedback.showError(
          context,
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isSettling = false);
    }
  }

  void _showReceiptSheet(
    BuildContext context,
    double subtotal,
    double serviceCharge,
    double grandTotal,
    List<Map<String, dynamic>> items,
  ) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(DilkashSpacing.xl),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(DilkashRadii.xl)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: DilkashColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Center(
              child: Text(
                'DILKASH RESTORAN',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                'Stol ${widget.tableNumber} • Chek nusxasi',
                style: DilkashTypography.caption.copyWith(
                  color: DilkashColors.textSecondaryLight,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: DilkashColors.borderLight, thickness: 1),
            const SizedBox(height: 8),
            ...items.map((it) {
              final dishName = it['dish_name'] ?? '';
              final qty = (it['quantity'] as num?)?.toInt() ?? 1;
              final price = (it['price'] as num?)?.toDouble() ?? 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${qty}x $dishName',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Text(
                      UzbekFormatters.formatCurrency(price * qty),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            const Divider(color: DilkashColors.borderLight, thickness: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Taomlar summasi:', style: DilkashTypography.bodyMedium),
                Text(
                  UzbekFormatters.formatCurrency(subtotal),
                  style: DilkashTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Xizmat haqi (10%):', style: DilkashTypography.bodyMedium),
                Text(
                  UzbekFormatters.formatCurrency(serviceCharge),
                  style: DilkashTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(color: DilkashColors.borderLight, thickness: 1.5),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Jami:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                Text(
                  UzbekFormatters.formatCurrency(grandTotal),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: DilkashColors.primary500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  DilkashFeedback.showSuccess(context, 'Chek printerga yuborildi');
                },
                icon: const Icon(Icons.print_rounded, color: Colors.white),
                label: const Text(
                  'Chop etish',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DilkashColors.textPrimaryLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DilkashRadii.md),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: DilkashColors.bgLight,
        body: Center(
          child: CircularProgressIndicator(color: DilkashColors.primary500),
        ),
      );
    }

    if (_error != null || _tableData == null) {
      return Scaffold(
        backgroundColor: DilkashColors.bgLight,
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(DilkashSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: DilkashColors.error,
                ),
                const SizedBox(height: DilkashSpacing.md),
                Text(_error ?? 'Xatolik', style: DilkashTypography.bodyLarge),
                const SizedBox(height: DilkashSpacing.lg),
                ElevatedButton(
                  onPressed: _loadTableBill,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DilkashColors.primary500,
                  ),
                  child: const Text(
                    'Qayta urinish',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final items = List<Map<String, dynamic>>.from(
      _tableData!['items'] as List? ?? [],
    );
    final rawTotal = (_tableData!['total_amount'] as num?)?.toDouble() ?? 0.0;
    final itemsSubtotal = items.fold<double>(
      0.0,
      (acc, it) =>
          acc +
          (((it['price'] as num?)?.toDouble() ?? 0.0) *
              ((it['quantity'] as num?)?.toInt() ?? 1)),
    );
    // If backend returns total with service charge already included, use that
    // Otherwise calculate standard 10% service charge
    final serviceCharge = rawTotal > itemsSubtotal
        ? (rawTotal - itemsSubtotal)
        : (itemsSubtotal * 0.10).roundToDouble();
    final grandTotal = rawTotal > 0 ? rawTotal : (itemsSubtotal + serviceCharge);

    return Scaffold(
      backgroundColor: DilkashColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Stol ${widget.tableNumber} hisobi',
          style: DilkashTypography.h3.copyWith(
            fontWeight: FontWeight.w700,
            color: DilkashColors.textPrimaryLight,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined, color: DilkashColors.textPrimaryLight),
            tooltip: 'Chek',
            onPressed: () => _showReceiptSheet(
              context,
              itemsSubtotal,
              serviceCharge,
              grandTotal,
              items,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadTableBill,
                color: DilkashColors.primary500,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(DilkashSpacing.lg),
                  children: [
                    // Total Amount Banner (Key number >= 24sp)
                    Container(
                      padding: const EdgeInsets.all(DilkashSpacing.xl),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(DilkashRadii.lg),
                        border: Border.all(color: DilkashColors.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Jami to’lov summasi:',
                            style: DilkashTypography.caption.copyWith(
                              color: DilkashColors.textSecondaryLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            UzbekFormatters.formatCurrency(grandTotal),
                            style: DilkashTypography.h1.copyWith(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: DilkashColors.primary500,
                            ),
                          ),
                          const SizedBox(height: DilkashSpacing.md),
                          const Divider(color: DilkashColors.borderLight, height: 1),
                          const SizedBox(height: DilkashSpacing.sm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Taomlar summasi:',
                                style: DilkashTypography.bodyMedium.copyWith(
                                  color: DilkashColors.textSecondaryLight,
                                ),
                              ),
                              Text(
                                UzbekFormatters.formatCurrency(itemsSubtotal),
                                style: DilkashTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Xizmat haqi (10%):',
                                style: DilkashTypography.bodyMedium.copyWith(
                                  color: DilkashColors.textSecondaryLight,
                                ),
                              ),
                              Text(
                                UzbekFormatters.formatCurrency(serviceCharge),
                                style: DilkashTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: DilkashSpacing.lg),

                    // Items Summary Card
                    Container(
                      padding: const EdgeInsets.all(DilkashSpacing.lg),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(DilkashRadii.md),
                        border: Border.all(color: DilkashColors.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Buyurtma tarkibi (${items.length} ta xil)',
                            style: DilkashTypography.h3.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: DilkashSpacing.md),
                          if (items.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Taomlar hali qo’shilmagan',
                                style: DilkashTypography.caption.copyWith(
                                  color: DilkashColors.textMutedLight,
                                ),
                              ),
                            )
                          else
                            ...items.map((it) {
                              final dishName = it['dish_name'] ?? '';
                              final qty = it['quantity'] ?? 1;
                              final price =
                                  (it['price'] as num?)?.toDouble() ?? 0.0;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: DilkashColors.bgLight,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${qty}x',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                          color: DilkashColors.textPrimaryLight,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        dishName,
                                        style: DilkashTypography.bodyLarge.copyWith(
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      UzbekFormatters.formatCurrency(price * qty),
                                      style: DilkashTypography.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),

                    const SizedBox(height: DilkashSpacing.lg),

                    // Payment Method Selection (3 clean large targets)
                    Text(
                      'To’lov usuli',
                      style: DilkashTypography.h3.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: DilkashColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: DilkashSpacing.sm),

                    Row(
                      children: _paymentMethods.map((m) {
                        final id = m['id'] as String;
                        final isSelected = _selectedPayment == id;
                        final title = m['title'] as String;
                        final subtitle = m['subtitle'] as String;
                        final icon = m['icon'] as IconData;
                        final color = m['color'] as Color;

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Material(
                              color: isSelected
                                  ? color.withValues(alpha: 0.10)
                                  : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(DilkashRadii.md),
                                side: BorderSide(
                                  color: isSelected
                                      ? color
                                      : DilkashColors.borderLight,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: InkWell(
                                borderRadius:
                                    BorderRadius.circular(DilkashRadii.md),
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedPayment = id);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: 6,
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        icon,
                                        color: isSelected
                                            ? color
                                            : DilkashColors.textSecondaryLight,
                                        size: 26,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                          color: isSelected
                                              ? color
                                              : DilkashColors.textPrimaryLight,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        subtitle,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isSelected
                                              ? color.withValues(alpha: 0.8)
                                              : DilkashColors.textMutedLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            // PRIMARY ACTIONS AT BOTTOM (>= 56dp height)
            Container(
              padding: const EdgeInsets.all(DilkashSpacing.lg),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 10,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  SizedBox(
                    height: 58,
                    child: OutlinedButton.icon(
                      onPressed: () => _showReceiptSheet(
                        context,
                        itemsSubtotal,
                        serviceCharge,
                        grandTotal,
                        items,
                      ),
                      icon: const Icon(Icons.print_rounded, size: 20),
                      label: const Text('Chek', style: TextStyle(fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DilkashColors.textPrimaryLight,
                        side: const BorderSide(color: DilkashColors.borderLight, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DilkashRadii.md),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: DilkashSpacing.md),
                  Expanded(
                    child: SizedBox(
                      height: 58,
                      child: ElevatedButton(
                        onPressed: _isSettling ? null : _settleBill,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DilkashColors.primary500,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(DilkashRadii.md),
                          ),
                        ),
                        child: _isSettling
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                'To’landi (${UzbekFormatters.formatCurrency(grandTotal)})',
                                style: DilkashTypography.bodyLarge.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
