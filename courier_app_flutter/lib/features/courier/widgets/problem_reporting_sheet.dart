// Problem Reporting Sheet for Courier
// Supports customer unreachable (5-minute waiting countdown & escalation), wrong address, damaged order, late delivery with photos.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';
import '../../../core/audit/audit_logger.dart';

class ProblemReportingSheet extends StatefulWidget {
  final int orderId;
  final String customerPhone;
  final Function(String reason, String notes) onSubmit;

  const ProblemReportingSheet({
    super.key,
    required this.orderId,
    required this.customerPhone,
    required this.onSubmit,
  });

  static Future<void> show({
    required BuildContext context,
    required int orderId,
    required String customerPhone,
    required Function(String reason, String notes) onSubmit,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ProblemReportingSheet(
        orderId: orderId,
        customerPhone: customerPhone,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<ProblemReportingSheet> createState() => _ProblemReportingSheetState();
}

class _ProblemReportingSheetState extends State<ProblemReportingSheet> {
  String _selectedReason = 'Mijoz bilan aloqa yoʻq';
  final _notesController = TextEditingController();
  bool _photoAttached = false;

  // Unreachable timer (5 minutes countdown)
  int _unreachableSeconds = 300;
  Timer? _unreachableTimer;
  bool _timerActive = false;

  @override
  void dispose() {
    _unreachableTimer?.cancel();
    _notesController.dispose();
    super.dispose();
  }

  void _startUnreachableTimer() {
    setState(() => _timerActive = true);
    _unreachableTimer?.cancel();
    _unreachableTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_unreachableSeconds > 1) {
        setState(() => _unreachableSeconds--);
      } else {
        timer.cancel();
        setState(() => _timerActive = false);
        HapticFeedback.heavyImpact();
      }
    });
  }

  String get _formattedTimer {
    final m = (_unreachableSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_unreachableSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _handleSubmit() {
    HapticFeedback.mediumImpact();
    AuditLogger.instance.log(
      staffName: 'Kuryer',
      role: 'courier',
      action: 'DELIVERY_PROBLEM_REPORTED',
      details: 'Buyurtma #${widget.orderId}: $_selectedReason. Izoh: ${_notesController.text}',
    );

    widget.onSubmit(_selectedReason, _notesController.text.trim());
    Navigator.pop(context);
    DilkashFeedback.showWarning(context, 'Muammo dispetcherga yuborildi!');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final reasons = [
      'Mijoz bilan aloqa yoʻq',
      'Notoʻgʻri koʻrsatilgan manzil',
      'Mijoz buyurtmani rad etdi',
      'Buyurtma shikastlangan / toʻkilgan',
      'Kechikish (tirbandlik yoki avariya)',
    ];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.red, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Yetkazish Muammosini Xabar Qilish',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: DilkashColors.textPrimary(isDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Reason dropdown / options
              ...reasons.map((r) {
                final isSelected = _selectedReason == r;
                return InkWell(
                  onTap: () => setState(() => _selectedReason = r),
                  borderRadius: DilkashRadii.radiusSm,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.red.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: DilkashRadii.radiusSm,
                      border: Border.all(
                        color: isSelected
                            ? Colors.red
                            : Colors.grey.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: isSelected ? Colors.red : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            r,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: DilkashColors.textPrimary(isDark),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              // 5-Minute Waiting Timer if "Mijoz bilan aloqa yoʻq"
              if (_selectedReason == 'Mijoz bilan aloqa yoʻq') ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : const Color(0xFFFEF2F2),
                    borderRadius: DilkashRadii.radiusSm,
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined,
                              color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Kutish qoidasi: 5 daqiqa',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: DilkashColors.textPrimary(isDark),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formattedTimer,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.red,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Mijoz telefoniga qoʻngʻiroq qilib boʻlmaganda kuryer 5 daqiqa eshik oldida kutishi shart. Shundan soʻng dispetcher bekor qiladi.',
                        style: TextStyle(
                          fontSize: 12,
                          color: DilkashColors.textSecondary(isDark),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (!_timerActive && _unreachableSeconds == 300)
                        ElevatedButton.icon(
                          onPressed: _startUnreachableTimer,
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: const Text('Kutish taymerini yoqish'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[600],
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),
              // Notes input
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Muammo tafsiloti (ixtiyoriy)',
                  hintText: 'Masalan: Domofon kodi ishlamadi, qoʻngʻiroq oʻchirilgan',
                  border: OutlineInputBorder(borderRadius: DilkashRadii.radiusSm),
                  filled: true,
                  fillColor: isDark ? Colors.grey[900] : Colors.white,
                ),
              ),
              const SizedBox(height: 12),

              // Photo proof toggle
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _photoAttached = !_photoAttached);
                      if (_photoAttached) {
                        DilkashFeedback.showSuccess(
                            context, 'Muammo fotosurati biriktirildi');
                      }
                    },
                    icon: Icon(
                      _photoAttached
                          ? Icons.check_circle_rounded
                          : Icons.camera_alt_rounded,
                      color: _photoAttached ? Colors.green : Colors.grey,
                    ),
                    label: Text(_photoAttached
                        ? 'Rasm yuklandi (1 ta)'
                        : 'Dalil rasmini olish'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: DilkashRadii.radiusSm),
                  ),
                  child: const Text(
                    'Menejerga Xabar Berish va Qaytish',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
