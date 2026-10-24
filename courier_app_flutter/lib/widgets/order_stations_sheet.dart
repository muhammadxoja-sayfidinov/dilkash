import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/staff_api_service.dart';
import '../theme/staff_theme.dart';

class OrderStationsSheet extends StatefulWidget {
  final int orderId;
  final String orderNumber;
  final String tableNumber;
  final double totalAmount;
  final Map<String, dynamic>? departments;
  final bool networkPrinted;

  const OrderStationsSheet({
    super.key,
    required this.orderId,
    required this.orderNumber,
    required this.tableNumber,
    required this.totalAmount,
    this.departments,
    this.networkPrinted = false,
  });

  static void show(
    BuildContext context, {
    required int orderId,
    required String orderNumber,
    required String tableNumber,
    required double totalAmount,
    Map<String, dynamic>? departments,
    bool networkPrinted = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OrderStationsSheet(
        orderId: orderId,
        orderNumber: orderNumber,
        tableNumber: tableNumber,
        totalAmount: totalAmount,
        departments: departments,
        networkPrinted: networkPrinted,
      ),
    );
  }

  @override
  State<OrderStationsSheet> createState() => _OrderStationsSheetState();
}

class _OrderStationsSheetState extends State<OrderStationsSheet> {
  bool _isPrinting = false;
  String _statusMessage = '';

  Future<void> _openReceiptUrl(String department) async {
    final urlStr =
        '${StaffApiService.baseUrl}/chef_panel/orders/${widget.orderId}/receipt/$department/';
    final uri = Uri.parse(urlStr);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Xatolik: $e'),
            backgroundColor: StaffColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: StaffDesign.radiusMd),
          ),
        );
      }
    }
  }

  Future<void> _triggerPrint(String department) async {
    setState(() {
      _isPrinting = true;
      _statusMessage = 'Printerga yuborilmoqda...';
    });

    try {
      final res = await StaffApiService.triggerStationPrint(
        orderId: widget.orderId,
        department: department,
      );

      setState(() {
        _isPrinting = false;
        _statusMessage = res['success'] == true
            ? '✓ Chek printerga muvaffaqiyatli uzatildi!'
            : 'Xatolik: ${res['message']}';
      });

      await _openReceiptUrl(department);
    } catch (e) {
      setState(() {
        _isPrinting = false;
        _statusMessage = 'Xatolik: $e';
      });
      await _openReceiptUrl(department);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final depts = widget.departments ?? {};
    final hasShashlik = depts.containsKey('shashlik');
    final hasKitchen = depts.containsKey('kitchen');
    final hasBar = depts.containsKey('bar');

    return Container(
      decoration: BoxDecoration(
        color: StaffColors.card(isDark),
        borderRadius: StaffDesign.radiusSheet,
        border: isDark
            ? Border(
                top: BorderSide(
                    color: StaffColors.border(isDark),
                    width: StaffDesign.borderStandard),
              )
            : null,
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: StaffColors.border(isDark),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: StaffColors.primary.withValues(alpha: 0.12),
                  borderRadius: StaffDesign.radiusMd,
                ),
                child: const Icon(
                  Icons.print_rounded,
                  color: StaffColors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stol #${widget.tableNumber} • Cheklar',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: StaffColors.textPrimary(isDark),
                      ),
                    ),
                    Text(
                      'Buyurtma #${widget.orderNumber} • ${widget.totalAmount.toStringAsFixed(0)} so\'m',
                      style: TextStyle(
                        fontSize: 13,
                        color: StaffColors.textSecondary(isDark),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.close_rounded,
                  color: StaffColors.textSecondary(isDark),
                ),
                style: IconButton.styleFrom(
                  backgroundColor: StaffColors.cardSecondary(isDark),
                ),
              ),
            ],
          ),

          if (widget.networkPrinted) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: StaffColors.primary.withValues(alpha: 0.10),
                borderRadius: StaffDesign.radiusSm,
                border: Border.all(
                  color: StaffColors.primary.withValues(alpha: 0.25),
                  width: StaffDesign.borderStandard,
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: StaffColors.primary, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cheklar bo\'lim printerlariga avtomatik yuborildi',
                      style: TextStyle(
                        color: StaffColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_statusMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: StaffColors.info,
              ),
            ),
          ],

          const SizedBox(height: 16),
          Text(
            'Bo\'limlar bo\'yicha alohida cheklar:',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: StaffColors.textSecondary(isDark),
            ),
          ),
          const SizedBox(height: 10),

          // Scrollable stations list
          Expanded(
            child: ListView(
              shrinkWrap: true,
              children: [
                // 1. Shashlikchi cheki
                if (hasShashlik)
                  _buildStationCard(
                    icon: '🥩',
                    title: 'Shashlikchi Cheki (Mangal)',
                    subtitle: 'Kaboblar va gril taomlari',
                    badgeColor: const Color(0xFFE11D48),
                    items: List<String>.from(depts['shashlik']['items'] ?? []),
                    deptKey: 'shashlik',
                    isDark: isDark,
                  ),

                // 2. Oshxona cheki
                if (hasKitchen)
                  _buildStationCard(
                    icon: '🍲',
                    title: 'Oshxona Cheki',
                    subtitle: 'Milliy va issiq taomlar, salatlar',
                    badgeColor: const Color(0xFFD97706),
                    items: List<String>.from(depts['kitchen']['items'] ?? []),
                    deptKey: 'kitchen',
                    isDark: isDark,
                  ),

                // 3. Desert va Bar cheki
                if (hasBar)
                  _buildStationCard(
                    icon: '☕',
                    title: 'Desert & Bar Cheki',
                    subtitle: 'Desertlar, shirinliklar va ichimliklar xonasi',
                    badgeColor: const Color(0xFF7C3AED),
                    items: List<String>.from(depts['bar']['items'] ?? []),
                    deptKey: 'bar',
                    isDark: isDark,
                  ),

                // 4. Kassa hisob cheki
                _buildStationCard(
                  icon: '🧾',
                  title: 'Kassa Hisob Cheki',
                  subtitle: 'Mijoz uchun umumiy hisob-kitob',
                  badgeColor: StaffColors.primary,
                  items: depts.containsKey('kassa')
                      ? List<String>.from(depts['kassa']['items'] ?? [])
                      : ['Barcha taomlar jamlangan hisob'],
                  deptKey: 'kassa',
                  totalText: '${widget.totalAmount.toStringAsFixed(0)} so\'m',
                  isDark: isDark,
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Bottom All-in-one button
          ElevatedButton.icon(
            onPressed: _isPrinting ? null : () => _triggerPrint('all'),
            icon: const Icon(Icons.print_rounded, size: 20),
            label: const Text(
              'Barcha cheklarni chiqarish (Ketma-ket)',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: StaffColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: StaffDesign.radiusMd),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStationCard({
    required String icon,
    required String title,
    required String subtitle,
    required Color badgeColor,
    required List<String> items,
    required String deptKey,
    required bool isDark,
    String? totalText,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StaffColors.card(isDark),
        borderRadius: StaffDesign.radiusMd,
        border: Border.all(
          color: StaffColors.border(isDark),
          width: StaffDesign.borderStandard,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: isDark ? 0.20 : 0.10),
                  borderRadius: StaffDesign.radiusSm,
                ),
                alignment: Alignment.center,
                child: Text(icon, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: StaffColors.textPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: StaffColors.textSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _triggerPrint(deptKey),
                icon: const Icon(Icons.print_rounded, size: 14),
                label: const Text('Chiqarish'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: StaffColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  shape: RoundedRectangleBorder(
                      borderRadius: StaffDesign.radiusSm),
                  textStyle:
                      const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: StaffColors.cardSecondary(isDark),
                borderRadius: StaffDesign.radiusSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: items
                    .take(4)
                    .map((it) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: StaffColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  it,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: StaffColors.textPrimary(isDark),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
          if (totalText != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Jami: $totalText',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: StaffColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
