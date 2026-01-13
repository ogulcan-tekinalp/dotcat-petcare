import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
import '../theme/app_theme.dart';

/// Kutlama efektleri için overlay
class CelebrationOverlay extends StatefulWidget {
  final Widget child;
  
  const CelebrationOverlay({super.key, required this.child});

  @override
  State<CelebrationOverlay> createState() => CelebrationOverlayState();
}

class CelebrationOverlayState extends State<CelebrationOverlay> {
  late ConfettiController _confettiController;
  
  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  }
  
  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }
  
  /// Konfeti başlat
  void celebrate() {
    _confettiController.play();
  }
  
  /// Kısa kutlama (görev tamamlama için)
  void quickCelebrate() {
    _confettiController.play();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _confettiController.stop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        
        // Üstten konfeti
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: pi / 2, // aşağı doğru
            maxBlastForce: 5,
            minBlastForce: 2,
            emissionFrequency: 0.05,
            numberOfParticles: 20,
            gravity: 0.1,
            shouldLoop: false,
            colors: const [
              AppColors.primary,
              AppColors.secondary,
              AppColors.success,
              AppColors.warning,
              Color(0xFFFF69B4), // Pink
              Color(0xFF9B59B6), // Purple
            ],
            createParticlePath: (size) {
              // Pati şeklinde konfeti
              final path = Path();
              // Basit yıldız şekli
              path.addOval(Rect.fromCircle(center: Offset.zero, radius: size.width / 2));
              return path;
            },
          ),
        ),
      ],
    );
  }
}

/// Global celebration controller
class CelebrationController {
  static final CelebrationController instance = CelebrationController._init();
  CelebrationController._init();
  
  GlobalKey<CelebrationOverlayState>? _overlayKey;
  
  void setOverlayKey(GlobalKey<CelebrationOverlayState> key) {
    _overlayKey = key;
  }
  
  void celebrate() {
    _overlayKey?.currentState?.celebrate();
  }
  
  void quickCelebrate() {
    _overlayKey?.currentState?.quickCelebrate();
  }
}

/// Success animation widget (checkmark animasyonu)
class SuccessAnimation extends StatefulWidget {
  final VoidCallback? onComplete;
  final double size;
  final Color color;
  
  const SuccessAnimation({
    super.key,
    this.onComplete,
    this.size = 80,
    this.color = AppColors.success,
  });

  @override
  State<SuccessAnimation> createState() => _SuccessAnimationState();
}

class _SuccessAnimationState extends State<SuccessAnimation> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _scaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.5, curve: Curves.elasticOut),
      ),
    );
    
    _checkAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1, curve: Curves.easeOut),
      ),
    );
    
    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: CustomPaint(
              painter: _CheckmarkPainter(
                progress: _checkAnimation.value,
                color: widget.color,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;
  
  _CheckmarkPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    
    // Daire
    canvas.drawCircle(center, radius, paint);
    
    // Checkmark
    if (progress > 0) {
      final path = Path();
      final startX = center.dx - radius * 0.3;
      final startY = center.dy;
      final midX = center.dx - radius * 0.05;
      final midY = center.dy + radius * 0.25;
      final endX = center.dx + radius * 0.35;
      final endY = center.dy - radius * 0.25;
      
      path.moveTo(startX, startY);
      
      if (progress <= 0.5) {
        // İlk çizgi
        final t = progress * 2;
        path.lineTo(
          startX + (midX - startX) * t,
          startY + (midY - startY) * t,
        );
      } else {
        // İlk çizgi tamamlandı
        path.lineTo(midX, midY);
        // İkinci çizgi
        final t = (progress - 0.5) * 2;
        path.lineTo(
          midX + (endX - midX) * t,
          midY + (endY - midY) * t,
        );
      }
      
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

