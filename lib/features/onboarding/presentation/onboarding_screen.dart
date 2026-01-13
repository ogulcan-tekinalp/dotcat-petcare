import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/localization.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../auth/presentation/login_screen.dart';

/// İnteraktif Onboarding 2.0
class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onComplete;
  
  const OnboardingScreen({super.key, this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // İnteraktif seçimler
  String? _selectedCatType;
  final List<String> _selectedFeatures = [];
  String? _selectedNotificationTime;
  
  final List<_OnboardingPage> _pages = [
    _OnboardingPage(
      type: OnboardingPageType.welcome,
      title: 'DOTCAT\'e Hoş Geldiniz',
      subtitle: 'Kedinizin bakımını kolaylaştıran akıllı asistan',
      icon: Icons.pets_rounded,
      color: AppColors.primary,
    ),
    _OnboardingPage(
      type: OnboardingPageType.catType,
      title: 'Kediniz nasıl biri?',
      subtitle: 'Size özel öneriler sunabilmemiz için kedinizi tanıyalım',
      icon: Icons.category_rounded,
      color: AppColors.secondary,
    ),
    _OnboardingPage(
      type: OnboardingPageType.features,
      title: 'En çok nede yardım istersiniz?',
      subtitle: 'Size en uygun özellikleri öne çıkaralım',
      icon: Icons.tune_rounded,
      color: AppColors.success,
    ),
    _OnboardingPage(
      type: OnboardingPageType.notifications,
      title: 'Bildirimleri ayarlayın',
      subtitle: 'Hiçbir bakım görevini kaçırmayın',
      icon: Icons.notifications_active_rounded,
      color: AppColors.warning,
    ),
    _OnboardingPage(
      type: OnboardingPageType.ready,
      title: 'Her şey hazır! 🎉',
      subtitle: 'Kediniz için en iyi bakımı sunmaya hazırsınız',
      icon: Icons.check_circle_rounded,
      color: AppColors.primary,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    HapticService.instance.tap();
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }
  
  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Onboarding tamamlandı flag'i
    await prefs.setBool('hasSeenOnboarding', true);
    
    // Kullanıcı seçimlerini kaydet (kişiselleştirilmiş öneriler için)
    if (_selectedCatType != null) {
      await prefs.setString('onboarding_cat_type', _selectedCatType!);
    }
    if (_selectedFeatures.isNotEmpty) {
      await prefs.setStringList('onboarding_features', _selectedFeatures);
    }
    if (_selectedNotificationTime != null) {
      await prefs.setString('onboarding_notification_time', _selectedNotificationTime!);
    }
    
    debugPrint('Onboarding completed - catType: $_selectedCatType, features: $_selectedFeatures, notificationTime: $_selectedNotificationTime');
    
    if (!mounted) return;
    
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }
  
  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }
  
  bool _canProceed() {
    // Tüm seçimler opsiyonel - her zaman devam edilebilir
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _pages[_currentPage].color.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Progress bar
              _buildProgressBar(),
              
              // Page content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _buildPage(_pages[index]);
                  },
                ),
              ),
              
              // Navigation buttons
              _buildNavigation(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Geri butonu
          if (_currentPage > 0)
            IconButton(
              onPressed: _previousPage,
              icon: const Icon(Icons.arrow_back_rounded),
            )
          else
            const SizedBox(width: 48),
          
          // Progress dots
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (index) {
                final isActive = index <= _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: index == _currentPage ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive
                        ? _pages[_currentPage].color
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
          
          // Geç butonu
          TextButton(
            onPressed: _completeOnboarding,
            child: const Text('Geç'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPage(_OnboardingPage page) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          
          // İkon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: page.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              page.icon,
              size: 50,
              color: page.color,
            ),
          )
              .animate()
              .scale(duration: 600.ms, curve: Curves.elasticOut),
          
          const SizedBox(height: 32),
          
          // Başlık
          Text(
            page.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          )
              .animate()
              .fadeIn(delay: 200.ms)
              .slideY(begin: 0.2, end: 0),
          
          const SizedBox(height: 12),
          
          // Alt başlık
          Text(
            page.subtitle,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          )
              .animate()
              .fadeIn(delay: 400.ms)
              .slideY(begin: 0.2, end: 0),
          
          const SizedBox(height: 40),
          
          // İnteraktif içerik
          _buildInteractiveContent(page.type),
        ],
      ),
    );
  }
  
  Widget _buildInteractiveContent(OnboardingPageType type) {
    switch (type) {
      case OnboardingPageType.welcome:
        return _buildWelcomeContent();
      case OnboardingPageType.catType:
        return _buildCatTypeSelection();
      case OnboardingPageType.features:
        return _buildFeaturesSelection();
      case OnboardingPageType.notifications:
        return _buildNotificationSetup();
      case OnboardingPageType.ready:
        return _buildReadyContent();
    }
  }
  
  Widget _buildWelcomeContent() {
    return Column(
      children: [
        _FeatureCard(
          icon: Icons.notifications_active_rounded,
          title: 'Akıllı Hatırlatıcılar',
          subtitle: 'Mama, ilaç, aşı zamanlarını kaçırmayın',
          color: AppColors.warning,
        ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.2, end: 0),
        
        const SizedBox(height: 12),
        
        _FeatureCard(
          icon: Icons.monitor_weight_outlined,
          title: 'Kilo Takibi',
          subtitle: 'Sağlıklı kilo değişimini izleyin',
          color: AppColors.weight,
        ).animate().fadeIn(delay: 700.ms).slideX(begin: -0.2, end: 0),
        
        const SizedBox(height: 12),
        
        _FeatureCard(
          icon: Icons.vaccines_outlined,
          title: 'Aşı Takvimi',
          subtitle: 'Tüm aşıları takip edin',
          color: AppColors.vaccine,
        ).animate().fadeIn(delay: 800.ms).slideX(begin: -0.2, end: 0),
        
        const SizedBox(height: 12),
        
        _FeatureCard(
          icon: Icons.lightbulb_outline_rounded,
          title: 'Akıllı Öneriler',
          subtitle: 'Kişiselleştirilmiş bakım tavsiyeleri',
          color: AppColors.success,
        ).animate().fadeIn(delay: 900.ms).slideX(begin: -0.2, end: 0),
      ],
    );
  }
  
  Widget _buildCatTypeSelection() {
    final catTypes = [
      _CatTypeOption('kitten', 'Yavru Kedi', '0-1 yaş', Icons.child_friendly_rounded),
      _CatTypeOption('adult', 'Yetişkin Kedi', '1-7 yaş', Icons.pets_rounded),
      _CatTypeOption('senior', 'Yaşlı Kedi', '7+ yaş', Icons.elderly_rounded),
      _CatTypeOption('indoor', 'Ev Kedisi', 'Dış mekan yok', Icons.home_rounded),
      _CatTypeOption('outdoor', 'Dış Mekan', 'Bahçe erişimi var', Icons.park_rounded),
    ];
    
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: catTypes.asMap().entries.map((entry) {
        final index = entry.key;
        final type = entry.value;
        final isSelected = _selectedCatType == type.id;
        
        return GestureDetector(
          onTap: () {
            HapticService.instance.selection();
            setState(() => _selectedCatType = type.id);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 150,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.secondary.withOpacity(0.1) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColors.secondary : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  type.icon,
                  size: 36,
                  color: isSelected ? AppColors.secondary : AppColors.textSecondary,
                ),
                const SizedBox(height: 8),
                Text(
                  type.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppColors.secondary : AppColors.textPrimary,
                  ),
                ),
                Text(
                  type.subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ).animate(delay: (100 * index).ms).fadeIn().scale(begin: const Offset(0.9, 0.9));
      }).toList(),
    );
  }
  
  Widget _buildFeaturesSelection() {
    final features = [
      _FeatureOption('reminders', 'Hatırlatıcılar', Icons.alarm_rounded),
      _FeatureOption('weight', 'Kilo Takibi', Icons.monitor_weight_outlined),
      _FeatureOption('vaccines', 'Aşı Takvimi', Icons.vaccines_outlined),
      _FeatureOption('vet', 'Veteriner', Icons.medical_services_outlined),
      _FeatureOption('grooming', 'Tırnak/Tüy', Icons.content_cut_rounded),
      _FeatureOption('food', 'Beslenme', Icons.restaurant_rounded),
    ];
    
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: features.asMap().entries.map((entry) {
        final index = entry.key;
        final feature = entry.value;
        final isSelected = _selectedFeatures.contains(feature.id);
        
        return GestureDetector(
          onTap: () {
            HapticService.instance.selection();
            setState(() {
              if (isSelected) {
                _selectedFeatures.remove(feature.id);
              } else {
                _selectedFeatures.add(feature.id);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 110,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.success.withOpacity(0.1) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColors.success : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Stack(
                  children: [
                    Icon(
                      feature.icon,
                      size: 32,
                      color: isSelected ? AppColors.success : AppColors.textSecondary,
                    ),
                    if (isSelected)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  feature.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppColors.success : AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ).animate(delay: (100 * index).ms).fadeIn().scale(begin: const Offset(0.9, 0.9));
      }).toList(),
    );
  }
  
  Widget _buildNotificationSetup() {
    final times = [
      _NotificationOption('morning', 'Sabah', '08:00', Icons.wb_sunny_rounded),
      _NotificationOption('noon', 'Öğlen', '12:00', Icons.light_mode_rounded),
      _NotificationOption('evening', 'Akşam', '18:00', Icons.nights_stay_rounded),
      _NotificationOption('custom', 'Özel', 'Kendin seç', Icons.schedule_rounded),
    ];
    
    return Column(
      children: [
        ...times.asMap().entries.map((entry) {
          final index = entry.key;
          final time = entry.value;
          final isSelected = _selectedNotificationTime == time.id;
          
          return GestureDetector(
            onTap: () {
              HapticService.instance.selection();
              setState(() => _selectedNotificationTime = time.id);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.warning.withOpacity(0.1) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppColors.warning : Colors.grey.shade200,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? AppColors.warning.withOpacity(0.2) 
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      time.icon,
                      color: isSelected ? AppColors.warning : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          time.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isSelected ? AppColors.warning : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          time.subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.warning,
                    ),
                ],
              ),
            ),
          ).animate(delay: (100 * index).ms).fadeIn().slideX(begin: 0.2, end: 0);
        }),
        
        const SizedBox(height: 16),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade600),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Bu ayarları daha sonra değiştirebilirsiniz',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
        ).animate(delay: 500.ms).fadeIn(),
      ],
    );
  }
  
  Widget _buildReadyContent() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.celebration_rounded,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              const Text(
                'Tebrikler!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Artık kediniz için harika bir bakım takibi yapabilirsiniz.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ).animate().fadeIn().scale(),
        
        const SizedBox(height: 24),
        
        _SummaryCard(
          title: 'Kedi Tipi',
          value: _getCatTypeName(_selectedCatType),
          icon: Icons.pets_rounded,
        ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2, end: 0),
        
        const SizedBox(height: 12),
        
        _SummaryCard(
          title: 'Seçilen Özellikler',
          value: '${_selectedFeatures.length} özellik aktif',
          icon: Icons.check_circle_outline_rounded,
        ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.2, end: 0),
        
        const SizedBox(height: 12),
        
        _SummaryCard(
          title: 'Bildirim Zamanı',
          value: _getNotificationTimeName(_selectedNotificationTime),
          icon: Icons.notifications_active_rounded,
        ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.2, end: 0),
      ],
    );
  }
  
  String _getCatTypeName(String? type) {
    switch (type) {
      case 'kitten': return 'Yavru Kedi';
      case 'adult': return 'Yetişkin Kedi';
      case 'senior': return 'Yaşlı Kedi';
      case 'indoor': return 'Ev Kedisi';
      case 'outdoor': return 'Dış Mekan Kedisi';
      default: return 'Seçilmedi';
    }
  }
  
  String _getNotificationTimeName(String? time) {
    switch (time) {
      case 'morning': return 'Sabah (08:00)';
      case 'noon': return 'Öğlen (12:00)';
      case 'evening': return 'Akşam (18:00)';
      case 'custom': return 'Özel Saat';
      default: return 'Seçilmedi';
    }
  }
  
  Widget _buildNavigation() {
    final isLastPage = _currentPage == _pages.length - 1;
    final canProceed = _canProceed();
    
    return Container(
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        width: double.infinity,
        child: AppButton(
          label: isLastPage ? 'Başla' : 'Devam',
          onPressed: canProceed ? _nextPage : null,
          icon: isLastPage ? Icons.arrow_forward_rounded : null,
          variant: ButtonVariant.filled,
        ),
      ),
    );
  }
}

// Helper classes
enum OnboardingPageType {
  welcome,
  catType,
  features,
  notifications,
  ready,
}

class _OnboardingPage {
  final OnboardingPageType type;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  
  _OnboardingPage({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

class _CatTypeOption {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  
  _CatTypeOption(this.id, this.title, this.subtitle, this.icon);
}

class _FeatureOption {
  final String id;
  final String title;
  final IconData icon;
  
  _FeatureOption(this.id, this.title, this.icon);
}

class _NotificationOption {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  
  _NotificationOption(this.id, this.title, this.subtitle, this.icon);
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
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

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
