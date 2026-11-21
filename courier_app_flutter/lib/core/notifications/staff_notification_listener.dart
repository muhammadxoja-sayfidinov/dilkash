import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../auth/auth_notifier.dart';
import '../navigation/app_router.dart';

class StaffNotificationListenerWidget extends ConsumerStatefulWidget {
  final Widget child;
  const StaffNotificationListenerWidget({super.key, required this.child});

  @override
  ConsumerState<StaffNotificationListenerWidget> createState() =>
      _StaffNotificationListenerWidgetState();
}

class _StaffNotificationListenerWidgetState
    extends ConsumerState<StaffNotificationListenerWidget> {
  Timer? _pollingTimer;
  final Set<int> _handledNotificationIds = {};
  bool _isDialogShowing = false;

  @override
  void initState() {
    super.initState();
    // Har 10 soniyada yangi xabarnomalar va zakaz takliflarini tekshirish
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkNotifications();
    });
    // Dastlabki tekshiruv 2 soniyadan so'ng
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _checkNotifications();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkNotifications() async {
    final session = ref.read(authProvider).value;
    if (session == null || _isDialogShowing) return;

    try {
      final repo = ref.read(staffRepositoryProvider);
      final notifs = await repo.fetchStaffNotifications();
      if (!mounted || notifs.isEmpty || _isDialogShowing) return;

      for (final n in notifs) {
        final id = (n['id'] as num?)?.toInt() ?? 0;
        if (id != 0 && !_handledNotificationIds.contains(id)) {
          _handledNotificationIds.add(id);
          _showOrderOfferDialog(n);
          break; // bittalab ko'rsatish
        }
      }
    } catch (_) {
      // Tarmoq vaqtincha yo'q bo'lsa xatolik chiqarmaymiz
    }
  }

  void _showOrderOfferDialog(Map<String, dynamic> notif) {
    if (_isDialogShowing) return;
    _isDialogShowing = true;

    // Ovozli vibratsiya
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}

    final notifId = (notif['id'] as num?)?.toInt() ?? 0;
    final orderId = (notif['order_id'] as num?)?.toInt() ?? 0;
    final orderNumber = notif['order_number']?.toString() ?? '$orderId';
    final isDualRole = notif['is_dual_role_prompt'] == true;
    final address = notif['delivery_address']?.toString() ?? '';
    final totalAmount = (notif['total_amount'] as num?)?.toDouble() ?? 0.0;
    final formattedTotal = NumberFormat("#,##0", "uz_UZ").format(totalAmount);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDualRole
                      ? Colors.orange.withOpacity(0.15)
                      : Colors.teal.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delivery_dining,
                  color: isDualRole ? Colors.orange.shade800 : Colors.teal.shade700,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDualRole
                          ? 'Dastavka Taklifi (Kuryer)'
                          : 'Yangi Dastavka Zakazi',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      'Buyurtma #$orderNumber',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Zakaz #$orderNumber bor. Qabul qilasanmi?',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              if (address.isNotEmpty) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, size: 18, color: Colors.redAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        address,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              if (totalAmount > 0)
                Row(
                  children: [
                    const Icon(Icons.payments_outlined, size: 18, color: Colors.green),
                    const SizedBox(width: 6),
                    Text(
                      'Summa: $formattedTotal so\'m',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              if (isDualRole) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sizda Ofitsiant va Kuryer roli mavjud. Qabul qilsangiz, avtomatik tarzda Kuryer ekraniga o\'tasiz.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                _isDialogShowing = false;
                try {
                  final repo = ref.read(staffRepositoryProvider);
                  await repo.respondStaffNotification(
                    notificationId: notifId,
                    action: 'decline',
                  );
                } catch (_) {}
              },
              child: const Text('Rad etish'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                elevation: 0,
              ),
              icon: const Icon(Icons.check, size: 18),
              label: const Text(
                'Ha, qabul qilaman',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                _isDialogShowing = false;
                try {
                  final repo = ref.read(staffRepositoryProvider);
                  final resp = await repo.respondStaffNotification(
                    notificationId: notifId,
                    action: 'accept',
                  );
                  if (resp['success'] == true) {
                    final session = ref.read(authProvider).value;
                    // Agar ofitsiant rolida bo'lsa va kuryerlikka ruxsati bo'lsa, kuryer roliga o'tkazish
                    if (session != null && !session.isCourier && session.canActAsCourier) {
                      await ref.read(authProvider.notifier).switchRole('courier');
                    }
                    if (orderId != 0 && mounted) {
                      ref.read(appRouterProvider).push('/courier/order/$orderId');
                    }
                  }
                } catch (_) {}
              },
            ),
          ],
        );
      },
    ).then((_) {
      _isDialogShowing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
