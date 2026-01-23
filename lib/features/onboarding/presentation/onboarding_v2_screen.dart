import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/localization.dart';
import '../../cats/providers/cats_provider.dart';
import '../../dogs/providers/dogs_provider.dart';
import '../../weight/providers/weight_provider.dart';
import '../../auth/presentation/login_screen.dart';
import '../../../data/models/pet_type.dart';

/// Yeni Onboarding 2.0 - Basitleştirilmiş ve Kedi Oluşturma İçeriyor
class OnboardingV2Screen extends ConsumerStatefulWidget {
  const OnboardingV2Screen({super.key});

  @override
  ConsumerState<OnboardingV2Screen> createState() => _OnboardingV2ScreenState();
}

class _OnboardingV2ScreenState extends ConsumerState<OnboardingV2Screen> {
  final PageController _pageController = PageController();
  final ScrollController _welcomeScrollController = ScrollController();
  int _currentPage = 0;
  final int _totalPages = 5;
  bool _showScrollIndicator = true;

  // Pet type selection
  PetType? _selectedPetType;

  // Pet creation form
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  DateTime _birthDate = DateTime.now().subtract(const Duration(days: 180));
  String? _selectedGender;
  String? _selectedBreed;
  String? _selectedSize;
  File? _photoFile;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() {
      if (mounted) setState(() {});
    });
    _welcomeScrollController.addListener(_onWelcomeScroll);
  }

  void _onWelcomeScroll() {
    if (_welcomeScrollController.hasClients) {
      final maxScroll = _welcomeScrollController.position.maxScrollExtent;
      final currentScroll = _welcomeScrollController.offset;
      if (currentScroll > maxScroll * 0.3 && _showScrollIndicator) {
        setState(() => _showScrollIndicator = false);
      } else if (currentScroll < maxScroll * 0.1 && !_showScrollIndicator) {
        setState(() => _showScrollIndicator = true);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _weightController.dispose();
    _welcomeScrollController.dispose();
    super.dispose();
  }

  bool get _canProceedFromPetForm {
    if (_nameController.text.trim().isEmpty) return false;
    if (_selectedGender == null) return false;
    return true;
  }

  void _nextPage() {
    FocusScope.of(context).unfocus();
    HapticService.instance.tap();

    if (_currentPage < _totalPages - 1) {
      if (_currentPage == 1 && _selectedPetType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Lütfen bir evcil hayvan türü seçin'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }

      if (_currentPage == 2) {
        if (!_canProceedFromPetForm) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Lütfen zorunlu alanları doldurun'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          return;
        }
        if (!_formKey.currentState!.validate()) {
          return;
        }
      }

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

    try {
      final authService = ref.read(authServiceProvider);
      if (authService.currentUser == null) {
        await authService.signInAnonymously();
      }

      double? weight;
      if (_weightController.text.trim().isNotEmpty) {
        try {
          weight = double.parse(_weightController.text.trim().replaceAll(',', '.'));
        } catch (e) {
          weight = null;
        }
      }

      if (_selectedPetType == PetType.cat) {
        final cat = await ref.read(catsProvider.notifier).addCat(
          name: _nameController.text.trim(),
          birthDate: _birthDate,
          gender: _selectedGender,
          weight: weight,
          photoPath: _photoFile?.path,
        );

        await prefs.setBool('hasSeenOnboarding', true);
        await prefs.setString('first_cat_id', cat.id);

        if (weight != null) {
          await prefs.setDouble('onboarding_initial_weight', weight);
          await ref.read(weightProvider.notifier).addWeightRecord(
            catId: cat.id,
            weight: weight,
            notes: 'İlk kayıt (Onboarding)',
          );
        }

        final ageInMonths = cat.ageInMonths;
        String catType = 'adult';
        if (ageInMonths < 12) {
          catType = 'kitten';
        } else if (ageInMonths >= 84) {
          catType = 'senior';
        }
        await prefs.setString('onboarding_cat_type', catType);
      } else if (_selectedPetType == PetType.dog) {
        final dog = await ref.read(dogsProvider.notifier).addDog(
          name: _nameController.text.trim(),
          birthDate: _birthDate,
          gender: _selectedGender,
          weight: weight,
          breed: _selectedBreed,
          size: _selectedSize,
          photoPath: _photoFile?.path,
        );

        await prefs.setBool('hasSeenOnboarding', true);
        await prefs.setString('first_dog_id', dog.id);

        if (weight != null) {
          await prefs.setDouble('onboarding_initial_weight', weight);
          await ref.read(weightProvider.notifier).addWeightRecord(
            catId: dog.id,
            weight: weight,
            notes: 'İlk kayıt (Onboarding)',
          );
        }

        final ageInMonths = dog.ageInMonths;
        String dogType = 'adult';
        if (ageInMonths < 12) {
          dogType = 'puppy';
        } else if (ageInMonths >= 84) {
          dogType = 'senior';
        }
        await prefs.setString('onboarding_dog_type', dogType);
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(isOnboardingComplete: true),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_selectedPetType == PetType.cat ? "Kedi" : "Köpek"} kaydedilemedi: $e')),
      );
    }
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.surfaceDark
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library, color: AppColors.primary),
                ),
                title: const Text('Galeriden Seç', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt, color: AppColors.secondary),
                ),
                title: const Text('Fotoğraf Çek', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );

    if (source != null) {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 90,
      );

      if (pickedFile != null) {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          compressQuality: 90,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Fotoğrafı Düzenle',
              toolbarColor: AppColors.primary,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: false,
              hideBottomControls: false,
              aspectRatioPresets: [
                CropAspectRatioPreset.square,
                CropAspectRatioPreset.ratio4x3,
                CropAspectRatioPreset.original,
              ],
            ),
            IOSUiSettings(
              title: 'Fotoğrafı Düzenle',
              aspectRatioLockEnabled: false,
              resetAspectRatioEnabled: true,
              aspectRatioPresets: [
                CropAspectRatioPreset.square,
                CropAspectRatioPreset.ratio4x3,
                CropAspectRatioPreset.original,
              ],
            ),
          ],
        );

        if (croppedFile != null && mounted) {
          setState(() {
            _photoFile = File(croppedFile.path);
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Column(
            children: [
              _buildProgressBar(isDark),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  children: [
                    _buildWelcomePage(isDark),
                    _buildPetTypeSelectionPage(isDark),
                    _buildPetCreationPage(isDark),
                    _buildWeightPage(isDark),
                    _buildReadyPage(isDark),
                  ],
                ),
              ),
              _buildNavigation(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          if (_currentPage > 0)
            GestureDetector(
              onTap: () {
                HapticService.instance.tap();
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                );
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isDark ? [] : AppShadows.small,
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  size: 20,
                ),
              ),
            )
          else
            const SizedBox(width: 40),

          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_totalPages, (index) {
                final isActive = index <= _currentPage;
                final isCurrent = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isCurrent ? 28 : 10,
                  height: 10,
                  decoration: BoxDecoration(
                    gradient: isActive
                        ? LinearGradient(colors: [AppColors.primary, AppColors.primaryLight])
                        : null,
                    color: isActive ? null : (isDark ? Colors.white.withOpacity(0.2) : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: isActive ? AppShadows.colored(AppColors.primary.withOpacity(0.3)) : [],
                  ),
                );
              }),
            ),
          ),

          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildNavigation(bool isDark) {
    bool canProceed = true;
    String buttonText = 'Devam';

    if (_currentPage == 1 && _selectedPetType == null) {
      canProceed = false;
    } else if (_currentPage == 2 && !_canProceedFromPetForm) {
      canProceed = false;
    }

    if (_currentPage == _totalPages - 1) {
      buttonText = 'Başla';
    }

    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = bottomPadding > 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: isKeyboardOpen ? 12 : 24,
        top: isKeyboardOpen ? 8 : 16,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: canProceed ? _nextPage : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300,
                disabledForegroundColor: isDark ? Colors.white.withOpacity(0.3) : Colors.grey.shade500,
                elevation: canProceed ? 4 : 0,
                shadowColor: AppColors.primary.withOpacity(0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    buttonText,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  if (canProceed) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ],
              ),
            ),
          ),

          if (_currentPage == 0 && !isKeyboardOpen) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Zaten Hesabım Var',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============ PAGES ============

  Widget _buildWelcomePage(bool isDark) {
    return Stack(
      children: [
        SingleChildScrollView(
          controller: _welcomeScrollController,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 32),

              // Logo with animated gradient ring
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryLight],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? AppColors.surfaceDark : Colors.white,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(55),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 80,
                        height: 80,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ).animate()
                .scale(duration: 700.ms, curve: Curves.elasticOut)
                .fadeIn(duration: 400.ms),

              const SizedBox(height: 36),

              // Title with better contrast
              Text(
                'Evcil Hayvanınızın\nDijital Sağlık Asistanı',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(duration: 500.ms, delay: 200.ms).slideY(begin: 0.2, end: 0),

              const SizedBox(height: 16),

              // Subtitle with much better contrast
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(isDark ? 0.2 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Yapay zeka destekli öneriler ve akıllı hatırlatmalarla evcil hayvanınızın sağlığını takip edin',
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF475569),
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 300.ms),

              const SizedBox(height: 40),

              // Feature cards with improved design
              _buildFeatureCard(
                icon: Icons.auto_awesome_rounded,
                title: 'Akıllı Öneriler',
                subtitle: 'Yapay zeka ile kişiselleştirilmiş sağlık tavsiyeleri alın',
                gradient: [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
                isDark: isDark,
                delay: 400,
              ),

              const SizedBox(height: 16),

              _buildFeatureCard(
                icon: Icons.notifications_active_rounded,
                title: 'Akıllı Hatırlatmalar',
                subtitle: 'Aşı, ilaç ve bakım zamanlarını asla kaçırmayın',
                gradient: [const Color(0xFF10B981), const Color(0xFF34D399)],
                isDark: isDark,
                delay: 500,
              ),

              const SizedBox(height: 16),

              _buildFeatureCard(
                icon: Icons.insights_rounded,
                title: 'Sağlık Takibi',
                subtitle: 'Kilo ve sağlık verilerini grafiklerle izleyin',
                gradient: [const Color(0xFFF59E0B), const Color(0xFFFBBF24)],
                isDark: isDark,
                delay: 600,
              ),

              const SizedBox(height: 100),
            ],
          ),
        ),

        // Scroll indicator
        if (_showScrollIndicator)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white,
                      size: 20,
                    ).animate(onPlay: (c) => c.repeat(reverse: true))
                      .moveY(begin: 0, end: 4, duration: 800.ms),
                    const SizedBox(width: 6),
                    const Text(
                      'Kaydır',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 1000.ms),
            ),
          ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required bool isDark,
    required int delay,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark ? [] : AppShadows.medium,
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : gradient.first.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: gradient.first.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white.withOpacity(0.7) : const Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: Duration(milliseconds: delay))
      .slideX(begin: 0.1, end: 0);
  }

  Widget _buildPetTypeSelectionPage(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withOpacity(isDark ? 0.3 : 0.1),
                  AppColors.primaryLight.withOpacity(isDark ? 0.2 : 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.pets_rounded,
                  size: 48,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'İlk Evcil Hayvanınızı Ekleyin',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Hangi tür evcil hayvan eklemek istersiniz?',
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white.withOpacity(0.7) : const Color(0xFF64748B),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Pet type options
          _buildPetTypeCard(
            petType: PetType.cat,
            emoji: '🐱',
            title: 'Kedi',
            description: 'Kedim için profil oluşturmak istiyorum',
            gradient: [AppColors.primary, AppColors.primaryLight],
            isDark: isDark,
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1, end: 0),

          const SizedBox(height: 16),

          _buildPetTypeCard(
            petType: PetType.dog,
            emoji: '🐶',
            title: 'Köpek',
            description: 'Köpeğim için profil oluşturmak istiyorum',
            gradient: [AppColors.secondary, const Color(0xFF34D399)],
            isDark: isDark,
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.1, end: 0),

          const SizedBox(height: 24),

          // Info note
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF64748B),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Daha sonra istediğiniz kadar evcil hayvan ekleyebilirsiniz.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
        ],
      ),
    );
  }

  Widget _buildPetTypeCard({
    required PetType petType,
    required String emoji,
    required String title,
    required String description,
    required List<Color> gradient,
    required bool isDark,
  }) {
    final isSelected = _selectedPetType == petType;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPetType = petType;
          _selectedBreed = null;
          _selectedSize = null;
        });
        HapticService.instance.tap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark
              ? (isSelected ? gradient.first.withOpacity(0.2) : Colors.white.withOpacity(0.08))
              : (isSelected ? gradient.first.withOpacity(0.08) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? gradient.first : (isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFE2E8F0)),
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: gradient.first.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : (isDark ? [] : AppShadows.small),
        ),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isSelected ? gradient : [Colors.grey.shade200, Colors.grey.shade300],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: gradient.first.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? gradient.first
                          : (isDark ? Colors.white : const Color(0xFF1E293B)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isSelected ? gradient.first : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? gradient.first : (isDark ? Colors.white.withOpacity(0.3) : Colors.grey.shade300),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPetCreationPage(bool isDark) {
    final isCat = _selectedPetType == PetType.cat;
    final petNamePossessive = isCat ? 'Kediniz' : 'Köpeğiniz';

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // Header
            Center(
              child: Column(
                children: [
                  Text(
                    'İlk $petNamePossessive Ekleyin',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$petNamePossessive hakkında birkaç bilgi alarak başlayalım',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF64748B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Photo picker
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: Stack(
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade100,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _photoFile != null
                              ? AppColors.primary
                              : (isDark ? Colors.white.withOpacity(0.2) : Colors.grey.shade300),
                          width: _photoFile != null ? 3 : 2,
                        ),
                        image: _photoFile != null
                            ? DecorationImage(image: FileImage(_photoFile!), fit: BoxFit.cover)
                            : null,
                        boxShadow: _photoFile != null
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : [],
                      ),
                      child: _photoFile == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo_rounded,
                                  color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey.shade500,
                                  size: 28,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Fotoğraf',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            )
                          : null,
                    ),
                    if (_photoFile != null)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: isDark ? AppColors.surfaceDark : Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.edit, color: Colors.white, size: 16),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Name field
            _buildFormSection(
              title: 'İsim',
              isRequired: true,
              isDark: isDark,
              child: TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
                decoration: _inputDecoration(
                  hint: '${petNamePossessive}in adı',
                  icon: Icons.pets_rounded,
                  isDark: isDark,
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'İsim gerekli' : null,
              ),
            ),

            // Breed (Dog only)
            if (!isCat) ...[
              const SizedBox(height: 20),
              _buildFormSection(
                title: 'Irk',
                isRequired: false,
                isDark: isDark,
                child: Autocomplete<String>(
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<String>.empty();
                    }
                    return AppConstants.dogBreeds.where((breed) =>
                        breed.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                  },
                  onSelected: (selection) {
                    setState(() => _selectedBreed = selection);
                  },
                  fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      textInputAction: TextInputAction.next,
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                      decoration: _inputDecoration(
                        hint: 'Köpeğinizin ırkı',
                        icon: Icons.category_rounded,
                        isDark: isDark,
                      ),
                      onChanged: (value) => _selectedBreed = value,
                    );
                  },
                ),
              ),

              // Size (Dog only)
              const SizedBox(height: 20),
              _buildFormSection(
                title: 'Boyut',
                isRequired: false,
                isDark: isDark,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: AppConstants.dogSizes.map((size) {
                    final isSelected = _selectedSize == size;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedSize = size);
                        HapticService.instance.tap();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withOpacity(isDark ? 0.3 : 0.1)
                              : (isDark ? Colors.white.withOpacity(0.08) : Colors.white),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : (isDark ? Colors.white.withOpacity(0.2) : Colors.grey.shade300),
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          size,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? AppColors.primary
                                : (isDark ? Colors.white.withOpacity(0.8) : const Color(0xFF475569)),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            // Birth Date
            const SizedBox(height: 20),
            _buildFormSection(
              title: 'Doğum Tarihi',
              isRequired: false,
              isDark: isDark,
              child: InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _birthDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.fromSeed(
                            seedColor: AppColors.primary,
                            brightness: isDark ? Brightness.dark : Brightness.light,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (date != null) {
                    setState(() => _birthDate = date);
                  }
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? Colors.white.withOpacity(0.2) : Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${_birthDate.day}/${_birthDate.month}/${_birthDate.year}',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_drop_down_rounded,
                        color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey.shade500,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Gender
            const SizedBox(height: 20),
            _buildFormSection(
              title: 'Cinsiyet',
              isRequired: true,
              isDark: isDark,
              child: Row(
                children: [
                  Expanded(child: _buildGenderOption('male', 'Erkek', Icons.male_rounded, isDark)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildGenderOption('female', 'Dişi', Icons.female_rounded, isDark)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildGenderOption('unknown', 'Bilinmiyor', Icons.help_outline_rounded, isDark)),
                ],
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildFormSection({
    required String title,
    required bool isRequired,
    required bool isDark,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    required bool isDark,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark ? Colors.white.withOpacity(0.4) : Colors.grey.shade500,
      ),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 22),
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.2) : Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.2) : Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildGenderOption(String value, String label, IconData icon, bool isDark) {
    final isSelected = _selectedGender == value;

    Color getGenderColor() {
      if (!isSelected) return isDark ? Colors.white.withOpacity(0.5) : Colors.grey.shade600;
      switch (value) {
        case 'male':
          return const Color(0xFF3B82F6);
        case 'female':
          return const Color(0xFFEC4899);
        default:
          return AppColors.primary;
      }
    }

    return GestureDetector(
      onTap: () {
        setState(() => _selectedGender = value);
        HapticService.instance.tap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? getGenderColor().withOpacity(isDark ? 0.25 : 0.1)
              : (isDark ? Colors.white.withOpacity(0.08) : Colors.white),
          border: Border.all(
            color: isSelected ? getGenderColor() : (isDark ? Colors.white.withOpacity(0.2) : Colors.grey.shade300),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: getGenderColor(),
              size: 26,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? getGenderColor()
                    : (isDark ? Colors.white.withOpacity(0.7) : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightPage(bool isDark) {
    final isCat = _selectedPetType == PetType.cat;
    final petNamePossessive = isCat ? 'Kediniz' : 'Köpeğiniz';

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          // Header with icon
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.weight, AppColors.weight.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.weight.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.monitor_weight_rounded, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 24),
                Text(
                  'Kilo Bilgisi',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Opsiyonel',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.info,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${petNamePossessive}in mevcut kilosunu girin.\nBu bilgi sağlık önerileri için kullanılacak.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF64748B),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 36),

          // Weight input card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
              ),
              boxShadow: isDark ? [] : AppShadows.medium,
            ),
            child: Column(
              children: [
                TextFormField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: '0.0',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white.withOpacity(0.3) : Colors.grey.shade400,
                    ),
                    suffixText: 'kg',
                    suffixStyle: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey.shade600,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  ),
                ),

                const SizedBox(height: 16),

                // Quick weight buttons
                Text(
                  'Hızlı Seçim',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: (isCat ? ['3', '4', '5', '6'] : ['5', '10', '15', '20', '25', '30'])
                      .map((weight) => GestureDetector(
                            onTap: () {
                              setState(() => _weightController.text = weight);
                              HapticService.instance.tap();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                color: _weightController.text == weight
                                    ? AppColors.weight.withOpacity(0.2)
                                    : (isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _weightController.text == weight
                                      ? AppColors.weight
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                '$weight kg',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _weightController.text == weight
                                      ? AppColors.weight
                                      : (isDark ? Colors.white.withOpacity(0.7) : const Color(0xFF64748B)),
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Info note
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.info.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.lightbulb_outline_rounded, color: AppColors.info, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Bu adımı atlayabilirsiniz. Kilo bilgisini daha sonra da ekleyebilirsiniz.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white.withOpacity(0.8) : const Color(0xFF1E40AF),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildReadyPage(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 40),

          // Success animation
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.success, AppColors.success.withOpacity(0.8)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withOpacity(0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(Icons.check_rounded, size: 70, color: Colors.white),
          ).animate()
            .scale(duration: 600.ms, curve: Curves.elasticOut)
            .fadeIn(duration: 300.ms),

          const SizedBox(height: 32),

          Text(
            'Her Şey Hazır!',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

          const SizedBox(height: 12),

          Text(
            _nameController.text.trim().isEmpty
                ? 'Evcil hayvanınız için en iyi bakımı sunmaya hazırsınız!'
                : '${_nameController.text} için en iyi bakımı sunmaya hazırsınız!',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white.withOpacity(0.7) : const Color(0xFF64748B),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

          const SizedBox(height: 40),

          // Summary cards
          _buildSummaryCard(
            icon: Icons.pets_rounded,
            iconColor: AppColors.primary,
            title: _selectedPetType == PetType.cat ? 'Kedi' : 'Köpek',
            value: _nameController.text.trim().isEmpty ? 'İsimsiz' : _nameController.text,
            isDark: isDark,
          ).animate().fadeIn(duration: 400.ms, delay: 400.ms).slideY(begin: 0.2, end: 0),

          const SizedBox(height: 12),

          _buildSummaryCard(
            icon: Icons.cake_rounded,
            iconColor: AppColors.accent,
            title: 'Doğum Tarihi',
            value: '${_birthDate.day}/${_birthDate.month}/${_birthDate.year}',
            isDark: isDark,
          ).animate().fadeIn(duration: 400.ms, delay: 500.ms).slideY(begin: 0.2, end: 0),

          const SizedBox(height: 12),

          _buildSummaryCard(
            icon: Icons.monitor_weight_rounded,
            iconColor: AppColors.weight,
            title: 'Kilo',
            value: _weightController.text.trim().isEmpty
                ? 'Henüz eklenmedi'
                : '${_weightController.text.trim()} kg',
            isDark: isDark,
          ).animate().fadeIn(duration: 400.ms, delay: 600.ms).slideY(begin: 0.2, end: 0),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
        ),
        boxShadow: isDark ? [] : AppShadows.small,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 22,
          ),
        ],
      ),
    );
  }
}
