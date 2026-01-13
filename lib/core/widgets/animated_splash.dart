import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

/// Animasyonlu Splash Screen
class AnimatedSplash extends StatefulWidget {
  final VoidCallback onComplete;
  
  const AnimatedSplash({super.key, required this.onComplete});

  @override
  State<AnimatedSplash> createState() => _AnimatedSplashState();
}

class _AnimatedSplashState extends State<AnimatedSplash> 
    with TickerProviderStateMixin {
  late AnimationController _pawController;
  bool _showText = false;
  bool _showTagline = false;
  
  @override
  void initState() {
    super.initState();
    _pawController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _startAnimation();
  }
  
  void _startAnimation() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _pawController.forward();
    
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _showText = true);
    
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) setState(() => _showTagline = true);
    
    await Future.delayed(const Duration(milliseconds: 800));
    widget.onComplete();
  }
  
  @override
  void dispose() {
    _pawController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D9488), // Teal 600
              Color(0xFF14B8A6), // Teal 500
              Color(0xFF2DD4BF), // Teal 400
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pati logosu
                AnimatedBuilder(
                  animation: _pawController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: Curves.elasticOut.transform(_pawController.value),
                      child: _buildPawLogo(),
                    );
                  },
                ),
                
                const SizedBox(height: 24),
                
                // DOTCAT yazısı
                AnimatedOpacity(
                  opacity: _showText ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 500),
                  child: AnimatedSlide(
                    offset: _showText ? Offset.zero : const Offset(0, 0.3),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    child: const Text(
                      'DOTCAT',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Tagline
                AnimatedOpacity(
                  opacity: _showTagline ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 500),
                  child: Text(
                    'Kedinizin Bakım Asistanı',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.9),
                      letterSpacing: 1,
                    ),
                  ),
                ),
                
                const SizedBox(height: 60),
                
                // Loading dots
                if (_showTagline)
                  _LoadingDots()
                      .animate()
                      .fadeIn(duration: 300.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildPawLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(
        Icons.pets_rounded,
        size: 64,
        color: AppColors.primary,
      ),
    );
  }
}

/// Yükleniyor noktaları
class _LoadingDots extends StatefulWidget {
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  
  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (index) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
      
      Future.delayed(Duration(milliseconds: index * 200), () {
        if (mounted) {
          controller.repeat(reverse: true);
        }
      });
      
      return controller;
    });
  }
  
  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controllers[index],
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.translate(
                offset: Offset(0, -8 * _controllers[index].value),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

/// Page route animasyonu
class FadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  
  FadePageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        );
}

/// Slide up page route
class SlideUpPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  
  SlideUpPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;
            
            final tween = Tween(begin: begin, end: end)
                .chain(CurveTween(curve: curve));
            
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
        );
}

