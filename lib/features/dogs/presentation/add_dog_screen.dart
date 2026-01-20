import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/localization.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/storage_service.dart';
import '../providers/dogs_provider.dart';
import '../../weight/providers/weight_provider.dart';

class AddDogScreen extends ConsumerStatefulWidget {
  const AddDogScreen({super.key});

  @override
  ConsumerState<AddDogScreen> createState() => _AddDogScreenState();
}

class _AddDogScreenState extends ConsumerState<AddDogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _weightController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _birthDate = DateTime.now().subtract(const Duration(days: 365));
  String? _selectedGender; // 'male', 'female', 'unknown'
  String? _selectedSize; // 'Çok Küçük', 'Küçük', 'Orta', 'Büyük', 'Çok Büyük'
  File? _photoFile;
  String? _savedPhotoPath;
  bool _isLoading = false;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickAndCropImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 90,
      );

      if (image == null) return;

      // Kırpma işlemi
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: AppLocalizations.get('edit_photo'),
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
            title: AppLocalizations.get('edit_photo'),
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
        // Geçici dosyayı kalıcı bir yere kopyala
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'dog_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedPath = p.join(appDir.path, fileName);

        await File(croppedFile.path).copy(savedPath);

        setState(() {
          _photoFile = File(savedPath);
          _savedPhotoPath = savedPath;
        });
      }
    } catch (e) {
      debugPrint('Image error: $e');
      if (mounted) {
        _showToast('Error: $e', isError: true);
      }
    }
  }

  void _showImageOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.photo_library, color: AppColors.primary)),
              title: Text(AppLocalizations.get('choose_from_gallery')),
              onTap: () { Navigator.pop(ctx); _pickAndCropImage(ImageSource.gallery); },
            ),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.info.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.camera_alt, color: AppColors.info)),
              title: Text(AppLocalizations.get('take_photo')),
              onTap: () { Navigator.pop(ctx); _pickAndCropImage(ImageSource.camera); },
            ),
            if (_photoFile != null)
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.delete, color: AppColors.error)),
                title: Text(AppLocalizations.get('remove_photo')),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _photoFile = null;
                    _savedPhotoPath = null;
                  });
                },
              ),
          ]),
        ),
      ),
    );
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _saveDog() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? photoUrl = _savedPhotoPath;

      // Önce köpeği oluştur (ID'yi almak için)
      final dog = await ref.read(dogsProvider.notifier).addDog(
        name: _nameController.text.trim(),
        birthDate: _birthDate,
        breed: _breedController.text.trim().isEmpty ? null : _breedController.text.trim(),
        gender: _selectedGender,
        weight: _weightController.text.trim().isEmpty ? null : double.tryParse(_weightController.text.trim().replaceAll(',', '.')),
        size: _selectedSize,
        photoPath: null, // Önce null, sonra URL ile güncellenecek
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      // Fotoğraf varsa Firebase Storage'a yükle
      if (_photoFile != null && _savedPhotoPath != null) {
        try {
          final uploadedUrl = await StorageService.instance.uploadDogPhoto(_photoFile!, dog.id);
          if (uploadedUrl != null) {
            // Köpeği URL ile güncelle
            final updatedDog = dog.copyWith(photoPath: uploadedUrl);
            await ref.read(dogsProvider.notifier).updateDog(updatedDog);
            photoUrl = uploadedUrl;
          }
        } catch (e) {
          debugPrint('AddDogScreen: Photo upload error: $e');
          // Fotoğraf yüklenemese bile köpeği kaydet (fotoğraf olmadan)
        }
      }

      // Kilo girildiyse, kilo kaydı ekle
      if (_weightController.text.trim().isNotEmpty) {
        final weightValue = double.tryParse(_weightController.text.trim().replaceAll(',', '.'));
        if (weightValue != null) {
          await ref.read(weightProvider.notifier).addWeightRecord(
            catId: dog.id, // catId parametresi aslında petId olarak kullanılıyor
            weight: weightValue,
            notes: null,
          );
        }
      }

      if (mounted) {
        _showToast(AppLocalizations.get('dog_added'));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showToast(AppLocalizations.get('error_saving'), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.get('add_dog'))),
      body: Form(
        key: _formKey,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            // Photo
            Center(
              child: GestureDetector(
                onTap: _showImageOptions,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.grey.shade100,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
                    image: _photoFile != null
                        ? DecorationImage(image: FileImage(_photoFile!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _photoFile == null
                      ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_a_photo, size: 32, color: AppColors.primary.withOpacity(0.5)),
                          const SizedBox(height: 4),
                          Text(AppLocalizations.get('add_photo'), style: TextStyle(fontSize: 11, color: AppColors.primary.withOpacity(0.7))),
                        ])
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Name
            _buildLabel(AppLocalizations.get('name'), true),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameController,
              decoration: _inputDecoration(isDark),
              validator: (v) => v == null || v.trim().isEmpty ? AppLocalizations.get('name_required') : null,
            ),
            const SizedBox(height: 16),

            // Birth Date
            _buildLabel(AppLocalizations.get('birth_date'), false),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _birthDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (date != null) setState(() => _birthDate = date);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${_birthDate.day}/${_birthDate.month}/${_birthDate.year}'),
                    const Icon(Icons.calendar_today, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Breed (öneri + serbest metin)
            _buildLabel(AppLocalizations.get('breed'), false),
            const SizedBox(height: 6),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _breedController.text),
              optionsBuilder: (TextEditingValue value) {
                final query = value.text.toLowerCase();
                if (query.isEmpty) {
                  return AppConstants.dogBreeds;
                }
                return AppConstants.dogBreeds.where(
                  (breed) => breed.toLowerCase().contains(query),
                );
              },
              onSelected: (String selection) {
                _breedController.text = selection;
              },
              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                textEditingController.text = _breedController.text;
                textEditingController.selection = TextSelection.fromPosition(
                  TextPosition(offset: textEditingController.text.length),
                );
                return TextFormField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: _inputDecoration(isDark).copyWith(
                    hintText: AppLocalizations.get('select_breed'),
                  ),
                  onChanged: (value) {
                    _breedController.text = value;
                  },
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                if (options.isEmpty) return const SizedBox.shrink();
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(10),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final option = options.elementAt(index);
                          return ListTile(
                            title: Text(option),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Size (Köpek boyutu)
            _buildLabel(AppLocalizations.get('dog_size'), false),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedSize,
              decoration: _inputDecoration(isDark),
              items: AppConstants.dogSizes.map((size) {
                return DropdownMenuItem(
                  value: size,
                  child: Text(size),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedSize = value);
              },
            ),
            const SizedBox(height: 16),

            // Gender
            _buildLabel('Cinsiyet', false),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _buildGenderOption('male', 'Erkek', Icons.male, isDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildGenderOption('female', 'Dişi', Icons.female, isDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildGenderOption('unknown', 'Bilinmiyor', Icons.help_outline, isDark),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Weight
            _buildLabel(AppLocalizations.get('weight_kg'), false),
            const SizedBox(height: 6),
            TextFormField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _inputDecoration(isDark),
            ),
            const SizedBox(height: 16),

            // Notes
            _buildLabel(AppLocalizations.get('notes'), false),
            const SizedBox(height: 6),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: _inputDecoration(isDark).copyWith(hintText: AppLocalizations.get('notes_hint')),
            ),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveDog,
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(AppLocalizations.get('save')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, bool required) {
    return Row(
      children: [
        Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        if (required) const Text(' *', style: TextStyle(color: AppColors.error)),
      ],
    );
  }

  InputDecoration _inputDecoration(bool isDark) {
    return InputDecoration(
      filled: true,
      fillColor: isDark ? AppColors.surfaceDark : Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
    );
  }

  Widget _buildGenderOption(String value, String label, IconData icon, bool isDark) {
    final isSelected = _selectedGender == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGender = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : (isDark ? AppColors.surfaceDark : Colors.white),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : Colors.grey.shade600,
              size: 24,
            ),
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
}
