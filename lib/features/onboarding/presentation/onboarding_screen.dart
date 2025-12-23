import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/localization.dart';
import '../../auth/presentation/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  late AnimationController _bounceController;
  late Animation<double> _bounceAnim;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _bounceAnim = Tween<double>(begin: 0, end: 15).animate(CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut));
    
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bounceController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  void _nextPage() {
    if (_currentPage < 4) {
      _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final colors = [
      AppColors.primary,
      AppColors.vaccine,
      AppColors.medicine,
      AppColors.vet,
      AppColors.food,
    ];
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              // Skip button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _completeOnboarding,
                      child: Text(AppLocalizations.get('skip'), style: TextStyle(color: context.textSecondary, fontSize: 15)),
                    ),
                  ],
                ),
              ),
              
              // Pages
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  children: [
                    _buildWelcomePage(isDark),
                    _buildFeaturePage(
                      emoji: '💉',
                      color: AppColors.vaccine,
                      titleKey: 'onboarding_vaccine_title',
                      descKey: 'onboarding_vaccine_desc',
                      features: ['onboarding_vaccine_feature1', 'onboarding_vaccine_feature2', 'onboarding_vaccine_feature3'],
                    ),
                    _buildFeaturePage(
                      emoji: '💊',
                      color: AppColors.medicine,
                      titleKey: 'onboarding_medicine_title',
                      descKey: 'onboarding_medicine_desc',
                      features: ['onboarding_medicine_feature1', 'onboarding_medicine_feature2', 'onboarding_medicine_feature3'],
                    ),
                    _buildFeaturePage(
                      emoji: '🏥',
                      color: AppColors.vet,
                      titleKey: 'onboarding_vet_title',
                      descKey: 'onboarding_vet_desc',
                      features: ['onboarding_vet_feature1', 'onboarding_vet_feature2', 'onboarding_vet_feature3'],
                    ),
                    _buildFeaturePage(
                      emoji: '🍽️',
                      color: AppColors.food,
                      titleKey: 'onboarding_food_title',
                      descKey: 'onboarding_food_desc',
                      features: ['onboarding_food_feature1', 'onboarding_food_feature2', 'onboarding_food_feature3'],
                    ),
                  ],
                ),
              ),
              
              // Dots indicator
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index ? colors[_currentPage] : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )),
                ),
              ),
              
              // Bottom button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors[_currentPage],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentPage == 4 ? AppLocalizations.get('get_started') : AppLocalizations.get('continue_btn'),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        Icon(_currentPage == 4 ? Icons.check : Icons.arrow_forward, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomePage(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated logo
          AnimatedBuilder(
            animation: _bounceAnim,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, -_bounceAnim.value),
              child: child,
            ),
            child: Image.asset('assets/images/logo.png', height: 120),
          ),
          const SizedBox(height: 32),
          
          // App name
          const Text('PetCare', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, letterSpacing: -1)),
          const SizedBox(height: 8),
          
          // Tagline
          Text(
            AppLocalizations.get('onboarding_welcome_tagline'),
            style: TextStyle(fontSize: 18, color: context.textSecondary, height: 1.4),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 48),
          
          // Feature preview icons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMiniFeature(Icons.vaccines, AppColors.vaccine),
              const SizedBox(width: 16),
              _buildMiniFeature(Icons.medication, AppColors.medicine),
              const SizedBox(width: 16),
              _buildMiniFeature(Icons.local_hospital, AppColors.vet),
              const SizedBox(width: 16),
              _buildMiniFeature(Icons.restaurant, AppColors.food),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniFeature(IconData icon, Color color) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: color, size: 26),
    );
  }

  Widget _buildFeaturePage({
    required String emoji,
    required Color color,
    required String titleKey,
    required String descKey,
    required List<String> features,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated emoji
          AnimatedBuilder(
            animation: _bounceAnim,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, -_bounceAnim.value),
              child: child,
            ),
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 50))),
            ),
          ),
          const SizedBox(height: 32),
          
          // Title
          Text(
            AppLocalizations.get(titleKey),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, height: 1.2),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          
          // Description
          Text(
            AppLocalizations.get(descKey),
            style: TextStyle(fontSize: 15, color: context.textSecondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 32),
          
          // Feature list
          ...features.map((key) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.check, color: color, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(AppLocalizations.get(key), style: const TextStyle(fontSize: 14))),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
