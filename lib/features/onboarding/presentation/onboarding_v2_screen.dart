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
  int _currentPage = 0;
  final int _totalPages = 5; // 4'ten 5'e çıktı (pet type selection eklendi)

  // Pet type selection
  PetType? _selectedPetType;

  // Pet creation form
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  DateTime _birthDate = DateTime.now().subtract(const Duration(days: 180)); // 6 ay
  String? _selectedGender;
  String? _selectedBreed; // Köpek için
  String? _selectedSize; // Köpek için
  File? _photoFile;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Name controller'a listener ekle - buton state'ini güncellemek için
    _nameController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _nextPage() {
    // Dismiss keyboard before navigation
    FocusScope.of(context).unfocus();

    HapticService.instance.tap();
    if (_currentPage < _totalPages - 1) {
      // Sayfa 1'de (pet type selection) validasyonu
      if (_currentPage == 1) {
        if (_selectedPetType == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lütfen bir evcil hayvan türü seçin')),
          );
          return;
        }
      }
      // Sayfa 2'de (pet creation) form validasyonu
      if (_currentPage == 2) {
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
      // Önce anonymous login yap (eğer giriş yapılmamışsa)
      final authService = ref.read(authServiceProvider);
      if (authService.currentUser == null) {
        await authService.signInAnonymously();
      }

      // Kilo değerini parse et
      double? weight;
      if (_weightController.text.trim().isNotEmpty) {
        try {
          weight = double.parse(_weightController.text.trim().replaceAll(',', '.'));
        } catch (e) {
          weight = null;
        }
      }

      if (_selectedPetType == PetType.cat) {
        // Kedi oluştur
        final cat = await ref.read(catsProvider.notifier).addCat(
          name: _nameController.text.trim(),
          birthDate: _birthDate,
          gender: _selectedGender,
          weight: weight,
          photoPath: _photoFile?.path,
        );

        // Preferences kaydet
        await prefs.setBool('hasSeenOnboarding', true);
        await prefs.setString('first_cat_id', cat.id);

        // Kiloyu preference'a kaydet (insights için)
        if (weight != null) {
          await prefs.setDouble('onboarding_initial_weight', weight);
          await ref.read(weightProvider.notifier).addWeightRecord(
            catId: cat.id,
            weight: weight,
            notes: 'İlk kayıt (Onboarding)',
          );
        }

        // Kedi yaşına göre tip kaydet
        final ageInMonths = cat.ageInMonths;
        String catType = 'adult';
        if (ageInMonths < 12) {
          catType = 'kitten';
        } else if (ageInMonths >= 84) {
          catType = 'senior';
        }
        await prefs.setString('onboarding_cat_type', catType);
      } else if (_selectedPetType == PetType.dog) {
        // Köpek oluştur
        final dog = await ref.read(dogsProvider.notifier).addDog(
          name: _nameController.text.trim(),
          birthDate: _birthDate,
          gender: _selectedGender,
          weight: weight,
          breed: _selectedBreed,
          size: _selectedSize,
          photoPath: _photoFile?.path,
        );

        // Preferences kaydet
        await prefs.setBool('hasSeenOnboarding', true);
        await prefs.setString('first_dog_id', dog.id);

        // Kiloyu preference'a kaydet (insights için)
        if (weight != null) {
          await prefs.setDouble('onboarding_initial_weight', weight);
          await ref.read(weightProvider.notifier).addWeightRecord(
            catId: dog.id, // Weight provider uses catId for both cats and dogs
            weight: weight,
            notes: 'İlk kayıt (Onboarding)',
          );
        }

        // Köpek yaşına göre tip kaydet
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

      // Login ekranına yönlendir
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
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeriden Seç'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Fotoğraf Çek'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
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
        // Kırpma işlemi
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
      onTap: () => FocusScope.of(context).unfocus(), // Dismiss keyboard on tap outside
      child: Scaffold(
        resizeToAvoidBottomInset: true, // Klavye açıldığında ekranı yukarı kaydır
        body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withOpacity(0.1),
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
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  children: [
                    _buildWelcomePage(),
                    _buildPetTypeSelectionPage(),
                    _buildPetCreationPage(isDark),
                    _buildNotificationPage(),
                    _buildReadyPage(),
                  ],
                ),
              ),

              // Navigation
              _buildNavigation(),
            ],
          ),
        ),
      ), // Close Scaffold
      ), // Close GestureDetector
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
              onPressed: () => _pageController.previousPage(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
              ),
              icon: const Icon(Icons.arrow_back_rounded),
            )
          else
            const SizedBox(width: 48),

          // Progress dots
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_totalPages, (index) {
                final isActive = index <= _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: index == _currentPage ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primary : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildNavigation() {
    // Sayfa 1'de (pet type selection) pet seçilmemişse disable
    // Sayfa 2'de (pet creation) form dolu değilse disable
    bool canProceed = true;
    if (_currentPage == 1 && _selectedPetType == null) {
      canProceed = false;
    } else if (_currentPage == 2 && _nameController.text.trim().isEmpty) {
      canProceed = false;
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: 24,
        top: MediaQuery.of(context).viewInsets.bottom > 0 ? 12 : 24, // Klavye açıksa padding azalt
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: canProceed ? _nextPage : null,
              child: Text(
                _currentPage == _totalPages - 1 ? 'Başla' : 'Devam',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          // "Zaten Hesabım Var" butonu - sadece ilk sayfada
          if (_currentPage == 0) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              child: Text(
                'Zaten Hesabım Var',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============ PAGES ============

  Widget _buildPetTypeSelectionPage() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'İlk Evcil Hayvanınızı Ekleyin',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Hangi tür evcil hayvan eklemek istersiniz?',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 40),

          // Cat option
          _buildPetTypeCard(
            petType: PetType.cat,
            icon: '🐱',
            title: 'Kedi',
            description: 'Kedim için profil oluştur',
            gradient: [AppColors.primary, AppColors.primaryLight],
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // Dog option
          _buildPetTypeCard(
            petType: PetType.dog,
            icon: '🐶',
            title: 'Köpek',
            description: 'Köpeğim için profil oluştur',
            gradient: [AppColors.secondary, AppColors.accent],
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildPetTypeCard({
    required PetType petType,
    required String icon,
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
          // Reset form when pet type changes
          _selectedBreed = null;
          _selectedSize = null;
        });
        HapticService.instance.tap();
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? gradient.first : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? AppShadows.colored(gradient.first)
              : AppShadows.medium,
        ),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(16),
                boxShadow: isSelected ? AppShadows.colored(gradient.first) : [],
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 40)),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? gradient.first : (isDark ? Colors.white : Colors.grey.shade800),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: gradient.first,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 20),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.05),
            AppColors.secondary.withOpacity(0.05),
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 40),

            // Animated logo with glow effect
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                ),
                boxShadow: AppShadows.colored(AppColors.primary),
              ),
              child: const Icon(Icons.pets_rounded, size: 70, color: Colors.white),
            ).animate()
              .scale(duration: 800.ms, curve: Curves.elasticOut)
              .shimmer(duration: 1500.ms, delay: 500.ms),

            const SizedBox(height: 40),

            // Modern title with gradient
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
              ).createShader(bounds),
              child: Text(
                'Evcil Hayvanınızın\nDijital Sağlık Asistanı',
                style: AppTypography.displayLarge.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3, end: 0),

            const SizedBox(height: 16),

            // Subtitle with better contrast
            Text(
              'Yapay zeka destekli öneriler ve akıllı hatırlatmalarla\nevcil hayvanınızın sağlığını takip edin',
              style: AppTypography.bodyLarge.copyWith(
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w500,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 300.ms, duration: 600.ms),

            const SizedBox(height: 56),

            // Modern feature cards with glassmorphism
            _buildModernFeatureCard(
              Icons.auto_awesome,
              'Akıllı Öneriler',
              'Yapay zeka ile kişiselleştirilmiş\nsağlık tavsiyeleri',
              [AppColors.primary, AppColors.primaryLight],
            ),
            const SizedBox(height: 16),
            _buildModernFeatureCard(
              Icons.notifications_active_rounded,
              'Hatırlatıcılar',
              'Aşı, ilaç ve bakım zamanlarını\nasla kaçırmayın',
              [AppColors.secondary, AppColors.vaccine],
            ),
            const SizedBox(height: 16),
            _buildModernFeatureCard(
              Icons.analytics_rounded,
              'Kilo Takibi',
              'Grafik ve trendlerle sağlıklı\nkilo aralığını koruyun',
              [AppColors.accent, AppColors.warning],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernFeatureCard(IconData icon, String title, String subtitle, List<Color> gradientColors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.medium,
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradientColors),
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppShadows.colored(gradientColors.first),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.titleMedium),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideX(begin: 0.2, end: 0);
  }

  Widget _buildPetCreationPage(bool isDark) {
    final isCat = _selectedPetType == PetType.cat;
    final petName = isCat ? 'Kedi' : 'Köpek';

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // Title
            Text(
              'İlk ${petName}inizi Ekleyin',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${petName}iniz hakkında birkaç bilgi alarak başlayalım',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),

            // Photo
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                    image: _photoFile != null
                        ? DecorationImage(image: FileImage(_photoFile!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _photoFile == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, color: Colors.grey.shade600),
                            const SizedBox(height: 4),
                            Text('Fotoğraf', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Name
            Text('İsim *', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: '${petName}inizin adı',
                filled: true,
                fillColor: isDark ? AppColors.surfaceDark : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'İsim gerekli' : null,
            ),
            const SizedBox(height: 20),

            // Breed (Dog only)
            if (!isCat) ...[
              Text('Irk', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Autocomplete<String>(
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
                    decoration: InputDecoration(
                      hintText: 'Köpeğinizin ırkı',
                      filled: true,
                      fillColor: isDark ? AppColors.surfaceDark : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (value) => _selectedBreed = value,
                  );
                },
              ),
              const SizedBox(height: 20),

              // Size (Dog only)
              Text('Boyut', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppConstants.dogSizes.map((size) {
                  final isSelected = _selectedSize == size;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedSize = size),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        size,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? AppColors.primary : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],

            // Birth Date
            Text('Doğum Tarihi', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _birthDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() => _birthDate = date);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 20),
                    const SizedBox(width: 12),
                    Text('${_birthDate.day}/${_birthDate.month}/${_birthDate.year}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Gender
            Text('Cinsiyet', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildGenderOption('male', 'Erkek', Icons.male)),
                const SizedBox(width: 12),
                Expanded(child: _buildGenderOption('female', 'Dişi', Icons.female)),
                const SizedBox(width: 12),
                Expanded(child: _buildGenderOption('unknown', 'Bilinmiyor', Icons.help_outline)),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderOption(String value, String label, IconData icon) {
    final isSelected = _selectedGender == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedGender = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : Colors.grey.shade600, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.primary : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationPage() {
    final isCat = _selectedPetType == PetType.cat;
    final petName = isCat ? 'Kedi' : 'Köpek';

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          const Text(
            'Kilo Bilgisi (Opsiyonel)',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '${petName}inizin mevcut kilosunu girin. Bu bilgi sağlık önerileri için kullanılacak.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 32),

          // Weight input
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.monitor_weight, color: AppColors.primary),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Kilo (kg)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                  style: const TextStyle(fontSize: 18),
                  decoration: InputDecoration(
                    hintText: 'Örn: 4.5',
                    suffixText: 'kg',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Kilo bilgisini boş bırakabilirsiniz. Daha sonra ekleyebilir veya güncelleyebilirsiniz.',
                    style: TextStyle(fontSize: 13, color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 40),

          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, size: 60, color: AppColors.success),
          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),

          const SizedBox(height: 32),

          const Text(
            'Her Şey Hazır! 🎉',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            _nameController.text.trim().isEmpty
                ? 'Evcil hayvanınız için en iyi bakımı sunmaya hazırsınız!'
                : '${_nameController.text} için en iyi bakımı sunmaya hazırsınız!',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),

          _buildSummaryCard(
            Icons.pets,
            _selectedPetType == PetType.cat ? 'Kedi Bilgileri' : 'Köpek Bilgileri',
            _nameController.text.trim().isEmpty ? 'Henüz eklenmedi' : _nameController.text,
          ),
          const SizedBox(height: 16),
          if (_weightController.text.trim().isNotEmpty)
            _buildSummaryCard(
              Icons.monitor_weight,
              'Kilo',
              '${_weightController.text.trim()} kg',
            ),
          if (_weightController.text.trim().isEmpty)
            _buildSummaryCard(
              Icons.monitor_weight,
              'Kilo',
              'Belirtilmedi (Sonra eklenebilir)',
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
