import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/router/app_routes.dart';
import '../../../shared/constants/app_colors.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {
  static const Duration _holdDuration = Duration(milliseconds: 2200);

  late final AnimationController _logoController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;

  late final AnimationController _textController;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;

  late final AnimationController _glowController;

  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoScale = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutBack,
    ).drive(Tween<double>(begin: 0.7, end: 1.0));
    _logoFade = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOut,
    );

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _textFade = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _logoController.forward();
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _textController.forward();
    });

    _navigationTimer = Timer(_holdDuration, _goNext);
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.onboarding);
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _logoController.dispose();
    _textController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final logoSize = (size.shortestSide * 0.42).clamp(140.0, 220.0);

    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          // Radial gold glow that pulses gently behind the logo.
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _glowController,
              builder: (context, _) {
                final t = _glowController.value;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.95,
                      colors: [
                        AppColors.goldDark.withOpacity(0.20 + 0.10 * t),
                        AppColors.black.withOpacity(0.0),
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),

          // Centered brand block — fills the whole screen so it sits in the
          // true visual center regardless of device aspect ratio.
          Positioned.fill(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: _LogoMark(size: logoSize),
                    ),
                  ),
                  const SizedBox(height: 28),
                  FadeTransition(
                    opacity: _textFade,
                    child: SlideTransition(
                      position: _textSlide,
                      child: const _Wordmark(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FadeTransition(
                    opacity: _textFade,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Organize your life. Stabilize your day.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFB8B8B8),
                          fontSize: 13,
                          letterSpacing: 0.4,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom badge: progress strip + spaced wordmark.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 28, top: 16),
                child: FadeTransition(
                  opacity: _textFade,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      _GoldProgressBar(),
                      SizedBox(height: 16),
                      Text(
                        'LIFESTABLE',
                        style: TextStyle(
                          color: Color(0xFF6E6E6E),
                          fontSize: 11,
                          letterSpacing: 4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [
            Color(0xFF1F1606),
            AppColors.black,
          ],
          radius: 0.85,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.goldDark.withOpacity(0.35),
            blurRadius: 40,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(
          color: AppColors.gold.withOpacity(0.35),
          width: 1.2,
        ),
      ),
      padding: EdgeInsets.all(size * 0.14),
      child: Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        colors: [
          AppColors.goldLight,
          AppColors.gold,
          AppColors.goldDark,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect),
      blendMode: BlendMode.srcIn,
      child: const Text(
        'LifeStable',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 38,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          height: 1.0,
        ),
      ),
    );
  }
}

class _GoldProgressBar extends StatefulWidget {
  const _GoldProgressBar();

  @override
  State<_GoldProgressBar> createState() => _GoldProgressBarState();
}

class _GoldProgressBarState extends State<_GoldProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 3,
        width: 140,
        child: Stack(
          children: [
            Container(color: const Color(0xFF1F1F1F)),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;
                return FractionallySizedBox(
                  alignment: Alignment(-1.0 + 2.0 * t, 0),
                  widthFactor: 0.35,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          AppColors.goldLight,
                          AppColors.gold,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.4, 0.6, 1.0],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}