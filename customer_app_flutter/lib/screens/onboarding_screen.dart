import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';
import '../services/auth_provider.dart';
import 'auth_screen.dart';
import 'main_navigation_shell.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<Map<String, dynamic>> _slides = [
    {
      'title': 'Eng Sara Milliy & Zamonaviy Taomlar',
      'subtitle':
          'Toshkent toʻy oshi, Gʻijduvon shashliklari va tandir somsalar toʻgʻridan-toʻgʻri restoran oshpazlaridan sizning dasturxoningizga.',
      'icon': Icons.restaurant_rounded,
      'color': DilkashColors.amber600,
      'badge': 'PREMIUM SIFAT',
      'badgeIcon': Icons.verified_rounded,
    },
    {
      'title': 'Tezkor Dastavka & Jonli Xarita',
      'subtitle':
          'Buyurtmangiz oshxonadan chiqishi bilanoq kuryer xaritada real vaqt rejimida koʻrinadi. Oʻrtacha yetkazish atigi 30 daqiqa.',
      'icon': Icons.electric_moped_rounded,
      'color': DilkashColors.primary500,
      'badge': '30 DAQIQADA',
      'badgeIcon': Icons.timer_outlined,
    },
    {
      'title': 'Keshbeklar, Choychaqa & Oson Toʻlov',
      'subtitle':
          'Har bir buyurtmadan 5% gacha keshbek oling. Naqd, Click yoki Payme orqali birgina harakat bilan toʻlang.',
      'icon': Icons.account_balance_wallet_rounded,
      'color': DilkashColors.primary400,
      'badge': '5% KESHBEK',
      'badgeIcon': Icons.savings_rounded,
    },
  ];

  void _finishOnboarding(bool goToAuth) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.setOnboardingSeen();

    if (!mounted) return;
    if (goToAuth && !auth.isAuthenticated) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationShell()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: DilkashColors.background(isDark),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? DilkashColors.surfaceDarkElevated
                          : const Color(0xFFE2E8F0),
                      borderRadius: DilkashRadii.radiusFull,
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${_slides.length}',
                      style: TextStyle(
                        color: DilkashColors.textSecondary(isDark),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _finishOnboarding(false),
                    child: Text(
                      'Oʻtkazib yuborish',
                      style: TextStyle(
                        color: DilkashColors.textSecondary(isDark),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Page View Slider
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (idx) => setState(() => _currentIndex = idx),
                itemBuilder: (context, idx) {
                  final slide = _slides[idx];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon circle container
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: (slide['color'] as Color)
                                .withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: (slide['color'] as Color)
                                  .withValues(alpha: 0.25),
                              width: 2.0,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              slide['icon'] as IconData,
                              size: 54,
                              color: slide['color'] as Color,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Badge Pill (No Emojis!)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark
                                ? DilkashColors.surfaceDarkElevated
                                : const Color(0xFFF1F5F9),
                            borderRadius: DilkashRadii.radiusFull,
                            border: Border.all(
                              color: isDark
                                  ? DilkashColors.borderDark
                                  : DilkashColors.borderLight,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                slide['badgeIcon'] as IconData,
                                size: 14,
                                color: slide['color'] as Color,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                slide['badge'] as String,
                                style: TextStyle(
                                  color: slide['color'] as Color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Title
                        Text(
                          slide['title'] as String,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: DilkashColors.textPrimary(isDark),
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Subtitle
                        Text(
                          slide['subtitle'] as String,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: DilkashColors.textSecondary(isDark),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Indicator Dots & Action Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentIndex == i ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentIndex == i
                              ? (isDark
                                  ? DilkashColors.primary400
                                  : DilkashColors.primary500)
                              : (isDark
                                  ? DilkashColors.borderDark
                                  : const Color(0xFFCBD5E1)),
                          borderRadius: DilkashRadii.radiusFull,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Next / Start Button
                  DilkashButton(
                    label: _currentIndex == _slides.length - 1
                        ? 'Boshlash'
                        : 'Davom etish',
                    trailingIcon: Icons.arrow_forward_rounded,
                    onPressed: () {
                      if (_currentIndex < _slides.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        _finishOnboarding(true);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
