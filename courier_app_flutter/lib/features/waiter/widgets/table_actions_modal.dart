// Table Actions Modal for Waiter Floor View
// Supports Opening table with guest counter, transferring table, merging tables, and fast navigation to order/bill.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';

class TableActionsModal extends StatefulWidget {
  final Map<String, dynamic> table;
  final List<Map<String, dynamic>> allTables;
  final Function(int guestCount) onOpenTable;
  final Function(String toTable) onTransferTable;
  final Function(String mergeWithTable) onMergeTables;
  final VoidCallback onDismissCall;

  const TableActionsModal({
    super.key,
    required this.table,
    required this.allTables,
    required this.onOpenTable,
    required this.onTransferTable,
    required this.onMergeTables,
    required this.onDismissCall,
  });

  static Future<void> show({
    required BuildContext context,
    required Map<String, dynamic> table,
    required List<Map<String, dynamic>> allTables,
    required Function(int guestCount) onOpenTable,
    required Function(String toTable) onTransferTable,
    required Function(String mergeWithTable) onMergeTables,
    required VoidCallback onDismissCall,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => TableActionsModal(
        table: table,
        allTables: allTables,
        onOpenTable: onOpenTable,
        onTransferTable: onTransferTable,
        onMergeTables: onMergeTables,
        onDismissCall: onDismissCall,
      ),
    );
  }

  @override
  State<TableActionsModal> createState() => _TableActionsModalState();
}

class _TableActionsModalState extends State<TableActionsModal> {
  int _guestCount = 2;

  void _showTransferDialog() {
    final available = widget.allTables
        .where((t) =>
            t['status'] == 'free' &&
            t['table_number'] != widget.table['table_number'])
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stolni Koʻchirish (Transfer)'),
        content: available.isEmpty
            ? const Text('Boshqa boʻsh stollar mavjud emas.')
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: available.length,
                  itemBuilder: (_, i) {
                    final t = available[i];
                    return ListTile(
                      leading: const Icon(Icons.table_restaurant_rounded,
                          color: DilkashColors.primary500),
                      title: Text('Stol ${t['table_number']} (${t['zone']})'),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                        widget.onTransferTable(t['table_number']);
                      },
                    );
                  },
                ),
              ),
      ),
    );
  }

  void _showMergeDialog() {
    final active = widget.allTables
        .where((t) =>
            t['status'] != 'free' &&
            t['table_number'] != widget.table['table_number'])
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stollarni Birlashtirish (Merge)'),
        content: active.isEmpty
            ? const Text('Birlashtirish uchun boshqa band stollar yoʻq.')
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: active.length,
                  itemBuilder: (_, i) {
                    final t = active[i];
                    return ListTile(
                      leading: const Icon(Icons.merge_type_rounded,
                          color: Colors.amber),
                      title: Text('Stol ${t['table_number']} bilan birlashtirish'),
                      subtitle: Text('${t['guest_count']} mehmon • ${UzbekFormatters.formatCurrency(t['total_amount'] ?? 0.0)}'),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                        widget.onMergeTables(t['table_number']);
                      },
                    );
                  },
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final table = widget.table;
    final tableNum = table['table_number'] ?? '';
    final status = table['status'] ?? 'free';
    final isFree = status == 'free';
    final hasActiveCall = table['active_call'] == true;
    final guestCount = table['guest_count'] ?? 0;
    final totalAmount = (table['total_amount'] as num?)?.toDouble() ?? 0.0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: DilkashColors.primary500.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Stol $tableNum',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: DilkashColors.primary500,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Zona: ${table['zone'] ?? 'Zal'}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: DilkashColors.textSecondary(isDark),
                  ),
                ),
                const Spacer(),
                if (hasActiveCall)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.notifications_active_rounded,
                            size: 14, color: Colors.red),
                        SizedBox(width: 4),
                        Text(
                          'Mijoz chaqirdi!',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.red),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Free Table Actions: Open Table with Guest Count Picker
            if (isFree) ...[
              Text(
                'Mehmonlar sonini belgilang:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: DilkashColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    onPressed: _guestCount > 1
                        ? () => setState(() => _guestCount--)
                        : null,
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      '$_guestCount kishi',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: _guestCount < 16
                        ? () => setState(() => _guestCount++)
                        : null,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context);
                    widget.onOpenTable(_guestCount);
                  },
                  icon: const Icon(Icons.door_front_door_rounded),
                  label: const Text(
                    'Stolni Ochish va Buyurtma Olish',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DilkashColors.primary500,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: DilkashRadii.radiusSm),
                  ),
                ),
              ),
            ] else ...[
              // Active Table Information
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : const Color(0xFFF1F5F9),
                  borderRadius: DilkashRadii.radiusSm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Mehmonlar: $guestCount kishi',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      'Jami hisob: ${UzbekFormatters.formatCurrency(totalAmount)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: DilkashColors.primary500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Actions List (Order, Bill, Transfer, Merge)
              _buildActionButton(
                label: 'Buyurtma Olish / Taom Qoʻshish',
                icon: Icons.add_circle_outline_rounded,
                color: DilkashColors.primary500,
                onTap: () {
                  Navigator.pop(context);
                  context.push('/waiter/order/$tableNum');
                },
              ),
              const SizedBox(height: 10),
              _buildActionButton(
                label: 'Hisobni Chiqarish va Toʻlov',
                icon: Icons.receipt_long_rounded,
                color: Colors.blue[700]!,
                onTap: () {
                  Navigator.pop(context);
                  context.push('/waiter/bill/$tableNum');
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showTransferDialog,
                      icon: const Icon(Icons.swap_calls_rounded, size: 18),
                      label: const Text('Koʻchirish'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showMergeDialog,
                      icon: const Icon(Icons.merge_rounded, size: 18),
                      label: const Text('Birlashtirish'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              if (hasActiveCall) ...[
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onDismissCall();
                  },
                  icon: const Icon(Icons.check_rounded, color: Colors.green),
                  label: const Text('Mijoz chaqiruvini qabul qildim deb belgilash'),
                ),
              ],
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: DilkashRadii.radiusSm),
        ),
      ),
    );
  }
}
