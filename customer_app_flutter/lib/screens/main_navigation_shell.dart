import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/cart_provider.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'cart_screen.dart';
import 'my_orders_screen.dart';
import 'account_screen.dart';

class MainNavigationShell extends StatefulWidget {
  final int initialIndex;

  const MainNavigationShell({Key? key, this.initialIndex = 0})
      : super(key: key);

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    CartScreen(isRootTab: true),
    MyOrdersScreen(),
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 0.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? 0.2
                      : 0.05),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
            backgroundColor: Theme.of(context).cardColor,
            elevation: 0,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.restaurant_menu_outlined),
                selectedIcon: Icon(Icons.restaurant_menu,
                    color: Theme.of(context).colorScheme.primary),
                label: 'Menyu',
              ),
              NavigationDestination(
                icon: const Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search,
                    color: Theme.of(context).colorScheme.primary),
                label: 'Qidiruv',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: cart.totalCount > 0,
                  label: Text('${cart.totalCount}'),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.shopping_bag_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: cart.totalCount > 0,
                  label: Text('${cart.totalCount}'),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Icon(Icons.shopping_bag,
                      color: Theme.of(context).colorScheme.primary),
                ),
                label: 'Savatcha',
              ),
              NavigationDestination(
                icon: const Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long,
                    color: Theme.of(context).colorScheme.primary),
                label: 'Buyurtmalar',
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person,
                    color: Theme.of(context).colorScheme.primary),
                label: 'Profil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
