// Waiter Shell Dashboard
// Bottom navigation with max 3 tabs: Stollar (Tables), Profil (Profile).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';
import 'waiter_tables_screen.dart';
import '../../common/screens/staff_profile_screen.dart';

class WaiterFloorScreenV2 extends StatefulWidget {
  const WaiterFloorScreenV2({super.key});

  @override
  State<WaiterFloorScreenV2> createState() => _WaiterFloorScreenV2State();
}

class _WaiterFloorScreenV2State extends State<WaiterFloorScreenV2> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    WaiterTablesScreen(),
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
              icon: Icon(Icons.table_restaurant_outlined),
              activeIcon: Icon(Icons.table_restaurant_rounded),
              label: 'Stollar',
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
