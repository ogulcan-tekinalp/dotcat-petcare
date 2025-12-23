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
import '../../../data/models/cat.dart';
import '../providers/cats_provider.dart';
import '../../weight/providers/weight_provider.dart';

class EditCatScreen extends ConsumerStatefulWidget {
  final Cat cat;
  const EditCatScreen({super.key, required this.cat});

  @override
  ConsumerState<EditCatScreen> createState() => _EditCatScreenState();
}

class _EditCatScreenState extends ConsumerState<EditCatScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _breedController;
  late final TextEditingController _weightController;
  late final TextEditingController _notesController;
  late DateTime _birthDate;
  File? _photoFile;
  String? _savedPhotoPath;
  bool _isLoading = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.cat.name);
    _breedController = TextEditingController(text: widget.cat.breed ?? '');
    _weightController = TextEditingController(text: widget.cat.weight?.toString() ?? '');
    _notesController = TextEditingController(text: widget.cat.notes ?? '');
    _birthDate = widget.cat.birthDate;
    _savedPhotoPath = widget.cat.photoPath;
    // URL ise _photoFile null kalır (NetworkImage kullanılacak)
    // Local path ise File olarak yükle
    if (_savedPhotoPath != null && !_savedPhotoPath!.startsWith('http')) {
      if (File(_savedPhotoPath!).existsSync()) {
        _photoFile = File(_savedPhotoPath!);
      }
    }
  }

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

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: AppLocalizations.get('edit_photo'),
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: AppLocalizations.get('edit_photo'),
            aspectRatioLockEnabled: false,
            resetAspectRatioEnabled: true,
          ),
        ],
      );

      if (croppedFile != null && mounted) {
        // Geçici dosyayı kalıcı bir yere kopyala
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'cat_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedPath = p.join(appDir.path, fileName);
        
        await File(croppedFile.path).copy(savedPath);
        
        setState(() {
          _photoFile = File(savedPath);
          _savedPhotoPath = savedPath;
        });
      }
    } catch (e) {
      debugPrint('Image error: $e');
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

  Future<void> _saveCat() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? photoUrl = _savedPhotoPath;
      
      // Yeni fotoğraf seçildiyse Firebase Storage'a yükle
      if (_photoFile != null && _savedPhotoPath != null && !_savedPhotoPath!.startsWith('http')) {
        try {
          // Eski fotoğrafı sil (eğer URL ise)
          if (widget.cat.photoPath != null && widget.cat.photoPath!.startsWith('http')) {
            await StorageService.instance.deleteCatPhoto(widget.cat.id);
          }
          // Yeni fotoğrafı yükle
          final uploadedUrl = await StorageService.instance.uploadCatPhoto(_photoFile!, widget.cat.id);
          if (uploadedUrl != null) {
            photoUrl = uploadedUrl;
          }
        } catch (e) {
          debugPrint('EditCatScreen: Photo upload error: $e');
          // Fotoğraf yüklenemese bile kediyi güncelle (fotoğraf olmadan)
        }
      } else if (_savedPhotoPath == null && widget.cat.photoPath != null && widget.cat.photoPath!.startsWith('http')) {
        try {
          // Fotoğraf silindi, cloud'dan da sil
          await StorageService.instance.deleteCatPhoto(widget.cat.id);
        } catch (e) {
          debugPrint('EditCatScreen: Photo delete error: $e');
          // Silme hatası olsa bile devam et
        }
      }

      final updatedCat = widget.cat.copyWith(
        name: _nameController.text.trim(),
        birthDate: _birthDate,
        breed: _breedController.text.trim().isEmpty ? null : _breedController.text.trim(),
        weight: _weightController.text.trim().isEmpty ? null : double.tryParse(_weightController.text.trim().replaceAll(',', '.')),
        photoPath: photoUrl,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      await ref.read(catsProvider.notifier).updateCat(updatedCat);

      // Kilo değiştiyse ve yeni kilo girildiyse, kilo kaydı ekle
      final newWeightValue = _weightController.text.trim().isEmpty ? null : double.tryParse(_weightController.text.trim().replaceAll(',', '.'));
      if (newWeightValue != null && (widget.cat.weight == null || widget.cat.weight != newWeightValue)) {
        try {
          await ref.read(weightProvider.notifier).addWeightRecord(
            catId: widget.cat.id,
            weight: newWeightValue,
            notes: null,
          );
        } catch (e) {
          debugPrint('EditCatScreen: Weight record error: $e');
          // Weight record eklenemese bile kediyi güncelle
        }
      }

      if (mounted) {
        _showToast(AppLocalizations.get('changes_saved'));
        Navigator.pop(context, updatedCat);
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
      appBar: AppBar(title: Text(AppLocalizations.get('edit_cat'))),
      body: Form(
        key: _formKey,
        child: ListView(
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
                    image: _savedPhotoPath != null
                        ? DecorationImage(
                            image: _savedPhotoPath!.startsWith('http')
                                ? NetworkImage(_savedPhotoPath!) as ImageProvider
                                : FileImage(File(_savedPhotoPath!)) as ImageProvider,
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _savedPhotoPath == null
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
                  return AppConstants.catBreeds;
                }
                return AppConstants.catBreeds.where(
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
                onPressed: _isLoading ? null : _saveCat,
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
}
