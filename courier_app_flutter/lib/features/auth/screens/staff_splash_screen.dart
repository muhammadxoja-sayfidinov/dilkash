import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_notifier.dart';

class StaffSplashScreen extends ConsumerStatefulWidget {
  final bool autoNavigate;

  const StaffSplashScreen({
    super.key,
    this.autoNavigate = true,
  }) : super();

  @override
  ConsumerState<StaffSplashScreen> createState() => _StaffSplashScreenState();
}

class _StaffSplashScreenState extends ConsumerState<StaffSplashScreen>
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

  void _navigateNext() {
    final authState = ref.read(authProvider);
    final session = authState.value;

    if (!mounted) return;

    if (session == null) {
      context.go('/login');
    } else {
      if (session.isCourier) {
        context.go('/courier');
      } else {
        context.go('/waiter');
      }
    }
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
      backgroundColor: const Color(0xFF09100C),
      body: Stack(
        children: [
          // Background subtle dark radiant glow
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.85,
                  colors: [
                    Color(0xFF112E22),
                    Color(0xFF09100C),
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
                  // Glowing Staff Emblem
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withOpacity(0.35),
                          blurRadius: 36,
                          spreadRadius: 6,
                        ),
                        BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(0.20),
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

                  // Staff Subtitle Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withOpacity(0.20),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4), width: 1),
                    ),
                    child: const Text(
                      'Xodimlar Portali • Kuryer & Ofitsiant',
                      style: TextStyle(
                        color: Color(0xFFFDE68A),
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

          // Bottom loading status and version
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
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
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
