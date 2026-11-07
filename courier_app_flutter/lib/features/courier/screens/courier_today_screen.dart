// Screen 3: Courier Today Screen
// Strictly follows KEEP: deliveries count, cash collected (to hand over at end of shift), simple history.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';
import '../../../core/auth/auth_notifier.dart';

class CourierTodayScreen extends ConsumerStatefulWidget {
  const CourierTodayScreen({super.key});

  @override
  ConsumerState<CourierTodayScreen> createState() => _CourierTodayScreenState();
}

class _CourierTodayScreenState extends ConsumerState<CourierTodayScreen> {
  bool _isLoading = true;
  String? _error;
  int _deliveriesCount = 0;
  double _cashCollected = 0.0;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(staffRepositoryProvider);
      final data = await repo.fetchCourierTodaySummary();
      if (mounted) {
        setState(() {
          _deliveriesCount = data['deliveries_count'] as int? ?? 0;
          _cashCollected = (data['cash_collected'] as num?)?.toDouble() ?? 0.0;
          _history = List<Map<String, dynamic>>.from(data['history'] as List? ?? []);
          _isLoading = false;
        });
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

    if (_error != null) {
      return Scaffold(
        backgroundColor: DilkashColors.bgLight,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(DilkashSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 48, color: DilkashColors.error),
                const SizedBox(height: DilkashSpacing.md),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: DilkashTypography.bodyLarge,
                ),
                const SizedBox(height: DilkashSpacing.lg),
                ElevatedButton(
                  onPressed: _loadSummary,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DilkashColors.primary500,
                  ),
                  child: const Text('Qayta urinish',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: DilkashColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Bugungi hisobot',
          style: DilkashTypography.h3.copyWith(
            fontWeight: FontWeight.w700,
            color: DilkashColors.textPrimaryLight,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: DilkashColors.primary500,
          onRefresh: _loadSummary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(DilkashSpacing.lg),
            children: [
              // Top Cards: Deliveries Count & Cash Collected (Key numbers >= 24sp)
              Row(
                children: [
                  // Deliveries Count Card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(DilkashSpacing.lg),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(DilkashRadii.md),
                        border: Border.all(color: DilkashColors.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: DilkashColors.primary50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.check_circle_outline_rounded,
                                  color: DilkashColors.primary500,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Yetkazildi',
                                style: DilkashTypography.caption.copyWith(
                                  color: DilkashColors.textSecondaryLight,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: DilkashSpacing.md),
                          Text(
                            '$_deliveriesCount ta',
                            style: DilkashTypography.h1.copyWith(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: DilkashColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: DilkashSpacing.md),
                  // Cash Collected Card (Soft amber tint)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(DilkashSpacing.lg),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB), // Amber-50
                        borderRadius: BorderRadius.circular(DilkashRadii.md),
                        border: Border.all(color: const Color(0xFFFDE68A)), // Amber-200
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.account_balance_wallet_outlined,
                                  color: Color(0xFFD97706),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Topshiriladigan naqd',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: DilkashTypography.caption.copyWith(
                                    color: DilkashColors.textSecondaryLight,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: DilkashSpacing.md),
                          Text(
                            UzbekFormatters.formatCurrency(_cashCollected),
                            style: DilkashTypography.h2.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: DilkashSpacing.xl),

              // Simple History Section
              Text(
                'Topshirilgan buyurtmalar tarixi',
                style: DilkashTypography.h3.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: DilkashColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: DilkashSpacing.md),

              if (_history.isEmpty)
                Container(
                  padding: const EdgeInsets.all(DilkashSpacing.xxl),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(DilkashRadii.md),
                    border: Border.all(color: DilkashColors.borderLight),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.inbox_rounded,
                          size: 40,
                          color: DilkashColors.textMutedLight,
                        ),
                        const SizedBox(height: DilkashSpacing.sm),
                        Text(
                          'Bugun hali yetkazilgan buyurtmalar yo’q',
                          style: DilkashTypography.bodyMedium.copyWith(
                            color: DilkashColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._history.map((h) {
                  final isCash = h['payment_type'] == 'cash';
                  final amount = (h['amount'] as num?)?.toDouble() ?? 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: DilkashSpacing.sm),
                    child: Material(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DilkashRadii.md),
                        side: const BorderSide(color: DilkashColors.borderLight),
                      ),
                      child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: DilkashSpacing.lg,
                        vertical: DilkashSpacing.xs,
                      ),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: DilkashColors.primary50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.done_all_rounded,
                          color: DilkashColors.primary500,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        h['delivery_address'] ?? 'Manzil ko’rsatilmagan',
                        style: DilkashTypography.bodyLarge.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Vaqt: ${h['time']} • ${isCash ? 'Naqd' : 'To’langan'}',
                        style: DilkashTypography.caption.copyWith(
                          color: DilkashColors.textSecondaryLight,
                        ),
                      ),
                      trailing: Text(
                        isCash
                            ? UzbekFormatters.formatCurrency(amount)
                            : 'To’langan',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isCash
                              ? DilkashColors.textPrimaryLight
                              : DilkashColors.primary500,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
