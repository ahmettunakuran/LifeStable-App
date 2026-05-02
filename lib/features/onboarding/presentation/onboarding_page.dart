import 'package:flutter/material.dart';
import '../../../shared/constants/app_colors.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/localization/app_localizations.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _buttonController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _textOpacity;
  late Animation<double> _buttonOpacity;
  late Animation<Offset> _buttonSlide;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );

    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _buttonSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _buttonController, curve: Curves.easeOut));
    _buttonOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeIn),
    );

    _startAnimations();
  }

  Future<void> _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    _textController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _buttonController.forward();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.3,
            colors: [Color(0xFF1E1608), Color(0xFF0D0D0D)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: -80,
                right: -60,
                child: _GlowCircle(
                  size: 280,
                  color: AppColors.gold.withOpacity(0.07),
                ),
              ),
              Positioned(
                bottom: -100,
                left: -80,
                child: _GlowCircle(
                  size: 320,
                  color: AppColors.gold.withOpacity(0.05),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _logoController,
                        builder: (context, child) => Opacity(
                          opacity: _logoOpacity.value,
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: child,
                          ),
                        ),
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.gold.withOpacity(0.4),
                                blurRadius: 36,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: AppColors.cardBg,
                                child: const Icon(
                                  Icons.balance,
                                  color: AppColors.gold,
                                  size: 56,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      AnimatedBuilder(
                        animation: _textController,
                        builder: (context, child) => SlideTransition(
                          position: _textSlide,
                          child: Opacity(opacity: _textOpacity.value, child: child),
                        ),
                        child: Column(
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [AppColors.goldLight, AppColors.gold],
                              ).createShader(bounds),
                              child: const Text(
                                'LifeStable',
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -1.5,
                                  height: 1.1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Build habits.\nLive intentionally.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white.withOpacity(0.55),
                                letterSpacing: 0.3,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 64),
                      AnimatedBuilder(
                        animation: _buttonController,
                        builder: (context, child) => SlideTransition(
                          position: _buttonSlide,
                          child: Opacity(
                              opacity: _buttonOpacity.value, child: child),
                        ),
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.of(context)
                                  .pushReplacementNamed(AppRoutes.register),
                              child: Container(
                                width: double.infinity,
                                padding:
                                const EdgeInsets.symmetric(vertical: 18),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppColors.goldLight,
                                      AppColors.gold,
                                      AppColors.goldDark,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.gold.withOpacity(0.35),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text(
                                    'Get Started',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextButton(
                              onPressed: () => Navigator.of(context)
                                  .pushReplacementNamed(AppRoutes.login),
                              child: Text(
                                'Already have an account? Sign in',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.45),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

