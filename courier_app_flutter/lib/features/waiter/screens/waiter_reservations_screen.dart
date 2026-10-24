// Waiter Reservations Screen
// Displays today's reservations list, arrival confirmation, table assignment, and guest calls.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';
import '../../../core/auth/auth_notifier.dart';

class WaiterReservationsScreen extends ConsumerStatefulWidget {
  const WaiterReservationsScreen({super.key});

  @override
  ConsumerState<WaiterReservationsScreen> createState() =>
      _WaiterReservationsScreenState();
}

class _WaiterReservationsScreenState
    extends ConsumerState<WaiterReservationsScreen> {
  List<Map<String, dynamic>> _reservations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReservations();
  }

  Future<void> _loadReservations() async {
    final repo = ref.read(staffRepositoryProvider);
    try {
      final list = await repo.fetchTodayReservations();
      if (mounted) {
        setState(() {
          _reservations = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _callGuest(String phone) async {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('tel:+$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _markArrived(Map<String, dynamic> res) async {
    HapticFeedback.mediumImpact();
    final repo = ref.read(staffRepositoryProvider);
    await repo.markReservationArrived(
      res['id'] as int,
      res['table_number'] as String,
    );

    setState(() {
      res['is_arrived'] = true;
    });

    if (mounted) {
      DilkashFeedback.showSuccess(
        context,
        '${res['guest_name']} yetib keldi deb belgilandi. Stol ${res['table_number']} ochildi!',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: DilkashColors.background(isDark),
      appBar: AppBar(
        title: const Text('Bugungi Bronlar (Rezervatsiyalar)'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _reservations.isEmpty
                ? const Center(
                    child: DilkashEmptyState(
                      icon: Icons.event_seat_outlined,
                      title: 'Bugunga bronlar yoʻq',
                      subtitle: 'Barcha stollar jonli navbat asosida xizmatda.',
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reservations.length,
                    itemBuilder: (context, index) {
                      final r = _reservations[index];
                      final isArrived = r['is_arrived'] == true;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF16231D) : Colors.white,
                          borderRadius: DilkashRadii.radiusMd,
                          border: Border.all(
                            color: isArrived
                                ? Colors.green.withValues(alpha: 0.4)
                                : (isDark
                                    ? const Color(0xFF1E3529)
                                    : DilkashColors.neutral200),
                          ),
                          boxShadow: DilkashShadows.card(isDark),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: DilkashColors.primary500
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Vaqt: ${r['time']}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: DilkashColors.primary500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Stol ${r['table_number']} (${r['zone']})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.amber[900],
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                if (isArrived)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.green.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Yetib kelgan ✓',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: DilkashColors.primary500
                                      .withValues(alpha: 0.1),
                                  child: const Icon(Icons.person_rounded,
                                      color: DilkashColors.primary500, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r['guest_name'],
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color:
                                              DilkashColors.textPrimary(isDark),
                                        ),
                                      ),
                                      Text(
                                        '${r['guest_phone']} • ${r['guest_count']} kishi',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: DilkashColors.textSecondary(
                                              isDark),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.phone_rounded,
                                      color: Colors.green),
                                  tooltip: 'Qoʻngʻiroq qilish',
                                  onPressed: () =>
                                      _callGuest(r['guest_phone']),
                                ),
                              ],
                            ),

                            if (r['occasion'] != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Tadbir/Izoh: ${r['occasion']}',
                                style: const TextStyle(
                                    fontSize: 12, fontStyle: FontStyle.italic),
                              ),
                            ],

                            if (!isArrived) ...[
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton.icon(
                                  onPressed: () => _markArrived(r),
                                  icon: const Icon(Icons.check_circle_rounded),
                                  label: const Text(
                                    'Mehmon yetib keldi deb belgilash',
                                    style: TextStyle(fontWeight: FontWeight.w700),
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
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
