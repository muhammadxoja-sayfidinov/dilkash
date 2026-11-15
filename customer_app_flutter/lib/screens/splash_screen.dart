import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import 'onboarding_screen.dart';
import 'main_navigation_shell.dart';

class CustomerSplashScreen extends StatefulWidget {
  final bool autoNavigate;

  const CustomerSplashScreen({
    Key? key,
    this.autoNavigate = true,
  }) : super(key: key);

  @override
  State<CustomerSplashScreen> createState() => _CustomerSplashScreenState();
}

class _CustomerSplashScreenState extends State<CustomerSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.7, curve: Curves.easeIn)),
    );

    _controller.forward();

    if (widget.autoNavigate) {
      _timer = Timer(const Duration(milliseconds: 1800), () {
        if (mounted) _navigateNext();
      });
    }
  }

  Future<void> _navigateNext() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    Widget target;
    if (!auth.hasSeenOnboarding) {
      target = const OnboardingScreen();
    } else {
      target = const MainNavigationShell();
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, animation, secondaryAnimation) => target,
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070D0A),
      body: Stack(
        children: [
          // Background subtle radiant glow
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.85,
                  colors: [
                    Color(0xFF0F3D2E),
                    Color(0xFF070D0A),
                  ],
                ),
              ),
            ),
          ),

          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: child,
                  ),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Glowing App Logo
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(0.35),
                          blurRadius: 36,
                          spreadRadius: 8,
                        ),
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withOpacity(0.20),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Brand Title
                  const Text(
                    'D I L K A S H',
                    style: TextStyle(
                      color: Color(0xFFFEF3C7),
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6.0,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Slogan
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D6B4E).withOpacity(0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3), width: 1),
                    ),
                    child: const Text(
                      'Milliy Taomlar & Tezkor Yetkazish',
                      style: TextStyle(
                        color: Color(0xFF94CFB7),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom loading and version
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'v2.0.0 Reliz',
                  style: TextStyle(
                    color: const Color(0xFF94CFB7).withOpacity(0.6),
                    fontSize: 11,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
