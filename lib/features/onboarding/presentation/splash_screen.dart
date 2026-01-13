import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../home/presentation/home_screen.dart';
import '../../auth/presentation/login_screen.dart';
import 'onboarding_v2_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  String? _error;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _scaleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _fadeController.forward();
    _scaleController.forward();

    Future.delayed(const Duration(milliseconds: 2000), () => _checkFirstLaunch());
  }

  Future<void> _checkFirstLaunch() async {
    try {
      debugPrint('SplashScreen: Checking first launch...');

      final prefs = await SharedPreferences.getInstance();
      final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
      final hasEverLoggedIn = prefs.getBool('hasEverLoggedIn') ?? false;

      debugPrint('SplashScreen: hasSeenOnboarding = $hasSeenOnboarding');
      debugPrint('SplashScreen: hasEverLoggedIn = $hasEverLoggedIn');

      // Firebase auth state check with error handling
      User? currentUser;
      bool isLoggedIn = false;
      bool isAnonymous = false;

      try {
        currentUser = FirebaseAuth.instance.currentUser;
        isLoggedIn = currentUser != null;
        isAnonymous = currentUser?.isAnonymous ?? false;
        debugPrint('SplashScreen: isLoggedIn = $isLoggedIn, isAnonymous = $isAnonymous');
      } catch (e) {
        debugPrint('SplashScreen: Firebase auth check failed: $e');
      }

      // Auto sign-in anonymously if no user exists
      if (currentUser == null) {
        try {
          debugPrint('SplashScreen: No user found, signing in anonymously...');
          final result = await FirebaseAuth.instance.signInAnonymously();
          currentUser = result.user;
          isLoggedIn = true;
          isAnonymous = true;
          debugPrint('SplashScreen: Anonymous sign-in successful, UID: ${currentUser?.uid}');
        } catch (e) {
          debugPrint('SplashScreen: Anonymous sign-in failed: $e');
        }
      }

      if (!mounted) return;

      Widget nextScreen;
      // Eğer kullanıcı daha önce hiç login olmamışsa ve onboarding görmemişse
      if (!hasEverLoggedIn && !hasSeenOnboarding) {
        nextScreen = const OnboardingV2Screen();
      }
      // Eğer authenticated user ise (anonim değil) direkt home'a git
      else if (isLoggedIn && !isAnonymous) {
        nextScreen = const HomeScreen();
      }
      // Anonim kullanıcı veya login olmamış - login ekranına git
      else {
        nextScreen = const LoginScreen();
      }

      debugPrint('SplashScreen: Navigating to ${nextScreen.runtimeType}');

      Navigator.pushReplacement(
        context,
        PageRouteBuilder<void>(
          pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('SplashScreen: Error during launch check: $e');
      debugPrint('SplashScreen: StackTrace: $stackTrace');

      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Bir hata oluştu',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() => _error = null);
                      _checkFirstLaunch();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    child: const Text('Tekrar Dene', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Image.asset('assets/images/logo.png', height: 80),
          ),
        ),
      ),
    );
  }
}
