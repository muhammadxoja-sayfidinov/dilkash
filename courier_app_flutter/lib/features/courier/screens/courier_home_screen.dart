// Courier Shell Dashboard
// Bottom navigation with max 3 tabs: Buyurtmalar (Orders), Bugun (Today), Profil (Profile).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';
import 'courier_orders_screen.dart';
import 'courier_today_screen.dart';
import '../../common/screens/staff_profile_screen.dart';

class CourierHomeScreen extends StatefulWidget {
  const CourierHomeScreen({super.key});

  @override
  State<CourierHomeScreen> createState() => _CourierHomeScreenState();
}

class _CourierHomeScreenState extends State<CourierHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    CourierOrdersScreen(),
    CourierTodayScreen(),
    StaffProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: DilkashColors.borderLight, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            HapticFeedback.selectionClick();
            setState(() => _currentIndex = index);
          },
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: DilkashColors.primary500,
          unselectedItemColor: DilkashColors.textMutedLight,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.delivery_dining_outlined),
              activeIcon: Icon(Icons.delivery_dining_rounded),
              label: 'Buyurtmalar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today_rounded),
              label: 'Bugun',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
