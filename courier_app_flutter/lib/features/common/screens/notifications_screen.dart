// Notifications Center for Dilkash Staff App
// Displays kitchen alerts, table QR calls, delivery assignments, and manager announcements.

import 'package:flutter/material.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<Map<String, dynamic>> _notifications = [
    {
      'id': 1,
      'title': 'Oshxona tayyorladi!',
      'message': 'Stol T-03: Qozon Kabob va Gʻijduvon shashlik dasturxonga tayyor.',
      'time': '2 daqiqa oldin',
      'type': 'kitchen',
      'is_read': false,
    },
    {
      'id': 2,
      'title': 'Ofitsiant chaqiruvi',
      'message': 'Stol T-03 mehmonga xizmat kutmoqda (Stoldan QR chaqiruv).',
      'time': '5 daqiqa oldin',
      'type': 'call',
      'is_read': false,
    },
    {
      'id': 3,
      'title': 'Yangi yetkazish biriktirildi',
      'message': 'Buyurtma #ORD-177 sizga biriktirildi. Chilonzor 9-mavze.',
      'time': '20 daqiqa oldin',
      'type': 'courier',
      'is_read': true,
    },
    {
      'id': 4,
      'title': 'Menejer xabarnomasi',
      'message': 'Bugun kechki soat 19:00 dan boshlab VIP zalda tadbir kutilmoqda.',
      'time': '1 soat oldin',
      'type': 'manager',
      'is_read': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: DilkashColors.background(isDark),
      appBar: AppBar(
        title: const Text('Bildirishnomalar Markazi'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                for (var n in _notifications) {
                  n['is_read'] = true;
                }
              });
              DilkashFeedback.showSuccess(context, 'Barchasi oʻqilgan deb belgilandi');
            },
            child: const Text('Barchasi oʻqildi'),
          ),
        ],
      ),
      body: SafeArea(
        child: _notifications.isEmpty
            ? const Center(
                child: DilkashEmptyState(
                  icon: Icons.notifications_off_outlined,
                  title: 'Yangi bildirishnomalar yoʻq',
                  subtitle: 'Barcha yangiliklar shu yerda aks etadi.',
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _notifications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final notif = _notifications[index];
                  final isRead = notif['is_read'] as bool;
                  final type = notif['type'] as String;

                  IconData icon;
                  Color iconColor;

                  switch (type) {
                    case 'kitchen':
                      icon = Icons.restaurant_rounded;
                      iconColor = DilkashColors.primary500;
                      break;
                    case 'call':
                      icon = Icons.notifications_active_rounded;
                      iconColor = Colors.red;
                      break;
                    case 'courier':
                      icon = Icons.two_wheeler_rounded;
                      iconColor = Colors.blue;
                      break;
                    default:
                      icon = Icons.campaign_rounded;
                      iconColor = Colors.amber;
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF16231D) : Colors.white,
                      borderRadius: DilkashRadii.radiusSm,
                      border: Border.all(
                        color: isRead
                            ? Colors.grey.withValues(alpha: 0.2)
                            : iconColor.withValues(alpha: 0.4),
                        width: isRead ? 1 : 1.5,
                      ),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: iconColor.withValues(alpha: 0.12),
                        child: Icon(icon, color: iconColor, size: 22),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              notif['title'],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isRead
                                    ? FontWeight.w600
                                    : FontWeight.w800,
                                color: DilkashColors.textPrimary(isDark),
                              ),
                            ),
                          ),
                          Text(
                            notif['time'],
                            style: TextStyle(
                              fontSize: 11,
                              color: DilkashColors.textSecondary(isDark),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          notif['message'],
                          style: TextStyle(
                            fontSize: 13,
                            color: DilkashColors.textSecondary(isDark),
                          ),
                        ),
                      ),
                      onTap: () {
                        setState(() => notif['is_read'] = true);
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}
