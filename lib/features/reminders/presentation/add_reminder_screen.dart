import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/localization.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/notification_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../cats/providers/cats_provider.dart';
import '../providers/reminders_provider.dart';

class AddReminderScreen extends ConsumerStatefulWidget {
  final String? initialType;
  final String? preselectedCatId;
  final dynamic reminder; // Düzenleme modu için mevcut kayıt
  const AddReminderScreen({super.key, this.initialType, this.preselectedCatId, this.reminder});

  @override
  ConsumerState<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends ConsumerState<AddReminderScreen> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  late String _selectedType;
  String _selectedFrequency = 'once';
  int? _customDays;
  bool _isLoading = false;
  bool _enableReminder = false;
  String _reminderTiming = 'on_day';
  bool _isCompleted = false;

  Set<String> _selectedCatIds = {};

  String? _selectedSubType;
  bool _isOtherSubType = false;

  final _reminderTypes = [
    {'type': 'dotcat_complete', 'icon': Icons.star_rounded, 'color': AppColors.primary},
    {'type': 'vaccine', 'icon': Icons.vaccines, 'color': AppColors.vaccine},
    {'type': 'medicine', 'icon': Icons.medication, 'color': AppColors.medicine},
    {'type': 'vet', 'icon': Icons.local_hospital, 'color': AppColors.vet},
    {'type': 'food', 'icon': Icons.restaurant, 'color': AppColors.food},
    {'type': 'weight', 'icon': Icons.monitor_weight, 'color': AppColors.warning},
  ];

  final _frequencies = [
    {'key': 'once', 'label': 'once'},
    {'key': 'daily', 'label': 'daily'},
    {'key': 'custom_2', 'label': 'every_2_days'},
    {'key': 'custom_3', 'label': 'every_3_days'},
    {'key': 'weekly', 'label': 'weekly'},
    {'key': 'custom_14', 'label': 'every_2_weeks'},
    {'key': 'monthly', 'label': 'monthly'},
    {'key': 'quarterly', 'label': 'quarterly'},
    {'key': 'biannual', 'label': 'biannual'},
    {'key': 'yearly', 'label': 'yearly'},
    {'key': 'custom', 'label': 'custom'},
  ];

  final _reminderTimings = [
    {'key': 'on_day', 'label': 'on_the_day', 'days': 0},
    {'key': 'one_day', 'label': 'one_day_before', 'days': 1},
    {'key': 'three_days', 'label': 'three_days_before', 'days': 3},
    {'key': 'one_week', 'label': 'one_week_before', 'days': 7},
  ];

  Map<String, List<String>> get _subTypes => {
    'dotcat_complete': ['dotcat_complete_full'],
    'vaccine': AppConstants.vaccineTypes,
    'medicine': ['internal_parasite', 'external_parasite', 'antibiotic', 'vitamin', 'other'],
    'food': ['dry_food', 'wet_food', 'supplement', 'treat', 'other'],
    'vet': ['checkup', 'emergency', 'surgery', 'dental', 'other'],
    'weight': ['weight_check'],
  };

  @override
  void initState() {
    super.initState();
    
    // Düzenleme modu: mevcut kayıt bilgilerini doldur
    if (widget.reminder != null) {
      final reminder = widget.reminder;
      _titleController.text = reminder.title ?? '';
      _notesController.text = reminder.notes ?? '';
      _selectedType = reminder.type;
      _selectedFrequency = reminder.frequency;
      _selectedDate = reminder.createdAt;
      
      // Time'ı parse et
      final timeParts = reminder.time.split(':');
      if (timeParts.length >= 2) {
        _selectedTime = TimeOfDay(
          hour: int.tryParse(timeParts[0]) ?? 9,
          minute: int.tryParse(timeParts[1]) ?? 0,
        );
      }
      
      // Subtype'ı bul (title'dan veya type'a göre)
      final subTypes = _subTypes[_selectedType] ?? [];
      if (subTypes.isNotEmpty) {
        // Title'ı kontrol et, eğer subtype'lardan biriyle eşleşiyorsa onu seç
        String? foundSubType;
        for (final subType in subTypes) {
          if (AppLocalizations.get(subType) == reminder.title) {
            foundSubType = subType;
            break;
          }
        }
        
        if (foundSubType != null) {
          _selectedSubType = foundSubType;
          _isOtherSubType = _selectedSubType == 'other' || _selectedSubType == 'vaccine_other';
        } else {
          // Eşleşme bulunamadı, "other" olarak işaretle
          _selectedSubType = subTypes.contains('other') ? 'other' : (subTypes.contains('vaccine_other') ? 'vaccine_other' : subTypes.first);
          _isOtherSubType = true;
          // Title'ı controller'a koy (kullanıcının girdiği özel başlık)
          _titleController.text = reminder.title ?? '';
        }
      }
      
      _enableReminder = reminder.isActive;
      _isCompleted = reminder.isCompleted;
      _selectedCatIds = {reminder.catId};
    } else {
      // Yeni kayıt modu
      _selectedType = widget.initialType ?? 'dotcat_complete';
      // dotcat_complete için varsayılan daily
      if (_selectedType == 'dotcat_complete') {
        _selectedFrequency = 'daily';
      }
      // İlk açılışta varsa alt türlerin ilkini seç
      final initialSubTypes = _subTypes[_selectedType];
      if (initialSubTypes != null && initialSubTypes.isNotEmpty) {
        _selectedSubType = initialSubTypes.first;
        _isOtherSubType = _selectedSubType == 'other' || _selectedSubType == 'vaccine_other';
      }
      // Hatırlatıcı varsayılan açık
      _enableReminder = true;
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final cats = ref.read(catsProvider);
        if (cats.isNotEmpty) {
          // preselectedCatId varsa onu kullan, yoksa ilk kediyi seç
          if (widget.preselectedCatId != null) {
            setState(() => _selectedCatIds = {widget.preselectedCatId!});
          } else {
            setState(() => _selectedCatIds = {cats.first.id});
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _isPastDate => _selectedDate.isBefore(DateTime.now().subtract(const Duration(days: 1)));

  String get _autoTitle {
    if (_isOtherSubType || _selectedSubType == 'other') {
      return _titleController.text;
    }
    if (_selectedSubType != null) {
      // Tüm alt türler için localization anahtarını kullan
      return AppLocalizations.get(_selectedSubType!);
    }
    return _titleController.text;
  }

  // İlk etkinlik tarihi: seçilen tarih
  // Bir sonraki tekrar tarihi: frequency'ye göre hesaplanır
  DateTime? _calculateNextRecurrence() {
    if (_selectedFrequency == 'once') return null;
    
    switch (_selectedFrequency) {
      case 'daily': return _selectedDate.add(const Duration(days: 1));
      case 'weekly': return _selectedDate.add(const Duration(days: 7));
      case 'monthly': return DateTime(_selectedDate.year, _selectedDate.month + 1, _selectedDate.day);
      case 'quarterly': return DateTime(_selectedDate.year, _selectedDate.month + 3, _selectedDate.day);
      case 'biannual': return DateTime(_selectedDate.year, _selectedDate.month + 6, _selectedDate.day);
      case 'yearly': return DateTime(_selectedDate.year + 1, _selectedDate.month, _selectedDate.day);
      default:
        if (_selectedFrequency.startsWith('custom_')) {
          final days = int.tryParse(_selectedFrequency.substring(7)) ?? _customDays;
          if (days != null) return _selectedDate.add(Duration(days: days));
        }
        return null;
    }
  }

  int _getReminderDaysBefore() {
    final timing = _reminderTimings.firstWhere((t) => t['key'] == _reminderTiming);
    return timing['days'] as int;
  }

  Future<void> _saveRecord() async {
    final title = _autoTitle.trim();
    if (title.isEmpty) {
      _showToast(AppLocalizations.get('title_required'), isError: true);
      return;
    }

    if (_selectedCatIds.isEmpty) {
      _showToast(AppLocalizations.get('select_cat_required'), isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final timeStr = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';
      String frequency = _selectedFrequency;
      if (_selectedFrequency == 'custom' && _customDays != null) {
        frequency = 'custom_$_customDays';
      }

      final cats = ref.read(catsProvider);
      // İlk etkinlik tarihi = seçilen tarih (nextDate olarak kaydedilecek)
      // Böylece yaklaşanlar listesinde doğru görünecek
      final firstEventDate = _selectedDate;
      final reminderDaysBefore = _getReminderDaysBefore();
      
      DateTime? reminderDate;
      if (_enableReminder) {
        if (!_isPastDate) {
          reminderDate = firstEventDate.subtract(Duration(days: reminderDaysBefore));
        }
      }
      
      // Düzenleme modu: mevcut kaydı güncelle
      if (widget.reminder != null) {
        final reminder = widget.reminder;
        final updatedReminder = reminder.copyWith(
          title: title,
          type: _selectedType,
          time: timeStr,
          frequency: frequency,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          isActive: !_isCompleted && _enableReminder,
          isCompleted: _isCompleted || (_isPastDate && _selectedFrequency == 'once'),
          createdAt: _selectedDate,
          nextDate: firstEventDate,
        );
        
        // Firebase'de güncelle
        await FirestoreService().saveReminder(updatedReminder);
        
        // Notification'ı yeniden planla
        await NotificationService.instance.cancelReminder(reminder.id.hashCode);
        if (_enableReminder && !_isCompleted && reminderDate != null && reminderDate.isAfter(DateTime.now())) {
          final cat = cats.firstWhere((c) => c.id == reminder.catId);
          // Notification'ı yeniden planla
          final timeParts = timeStr.split(':');
          final hour = int.parse(timeParts[0]);
          final minute = int.parse(timeParts[1]);
          
          if (frequency == 'daily') {
            await NotificationService.instance.scheduleDailyReminder(
              id: reminder.id.hashCode,
              title: '🐱 $title',
              body: '${cat.name} için $title zamanı!',
              hour: hour,
              minute: minute,
            );
          } else {
            final scheduledDateTime = DateTime(
              firstEventDate.year,
              firstEventDate.month,
              firstEventDate.day,
              hour,
              minute,
            );
            if (scheduledDateTime.isAfter(DateTime.now())) {
              await NotificationService.instance.scheduleOneTimeReminder(
                id: reminder.id.hashCode,
                title: '🐱 $title',
                body: '${cat.name} için $title zamanı!',
                dateTime: scheduledDateTime,
              );
            }
          }
        }
        
        // Provider'ı güncelle
        await ref.read(remindersProvider.notifier).loadRemindersForCat(reminder.catId);
        
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [const Icon(Icons.check_circle, color: Colors.white, size: 20), const SizedBox(width: 10), Text(AppLocalizations.get('record_updated'))]),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ));
        }
      } else {
        // Yeni kayıt modu
        for (final catId in _selectedCatIds) {
          final cat = cats.firstWhere((c) => c.id == catId);
          await ref.read(remindersProvider.notifier).addReminder(
            catId: catId,
            catName: cat.name,
            title: title,
            type: _selectedType,
            time: timeStr,
            frequency: frequency,
            description: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            notificationEnabled: _enableReminder && reminderDate != null && reminderDate.isAfter(DateTime.now()),
            isCompleted: _isCompleted || (_isPastDate && _selectedFrequency == 'once'),
            date: _selectedDate,
            nextDate: firstEventDate, // İlk etkinlik tarihi!
            reminderDate: reminderDate,
          );
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [const Icon(Icons.check_circle, color: Colors.white, size: 20), const SizedBox(width: 10), Text(AppLocalizations.get('record_saved'))]),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ));
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [Icon(isError ? Icons.error : Icons.check_circle, color: Colors.white, size: 20), const SizedBox(width: 10), Expanded(child: Text(message))]),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cats = ref.watch(catsProvider);
    final nextRecurrence = _calculateNextRecurrence();
    final subTypes = _subTypes[_selectedType] ?? [];

    return Scaffold(
      appBar: AppBar(title: Text(widget.reminder != null ? AppLocalizations.get('edit_record') : AppLocalizations.get('add_record'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Cat selection
          _buildSectionTitle(AppLocalizations.get('select_cats'), true),
          const SizedBox(height: 8),
          _buildCatSelector(cats, isDark),
          const SizedBox(height: 20),

          // Type selection
          _buildSectionTitle(AppLocalizations.get('record_type'), true),
          const SizedBox(height: 8),
          _buildTypeSelector(isDark),
          const SizedBox(height: 20),

          // Sub-type selection
          if (subTypes.isNotEmpty) ...[
            _buildSectionTitle(_getSubTypeLabel(), true),
            const SizedBox(height: 8),
            _buildSubTypeSelector(subTypes, isDark),
            const SizedBox(height: 20),
          ],

          // Date
          _buildSectionTitle(AppLocalizations.get('record_date'), true),
          const SizedBox(height: 8),
          _buildDateSelector(isDark),
          const SizedBox(height: 20),

          // Frequency
          _buildSectionTitle(AppLocalizations.get('frequency'), true),
          const SizedBox(height: 8),
          _buildFrequencySelector(isDark),
          if (_selectedFrequency == 'custom') ...[
            const SizedBox(height: 12),
            _buildCustomDaysInput(isDark),
          ],
          const SizedBox(height: 12),
          
          // Show next date
          if (nextRecurrence != null && _selectedFrequency != 'once') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.info.withOpacity(0.3)),
              ),
              child: Row(children: [
                Icon(Icons.event_repeat, color: AppColors.info, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(AppLocalizations.get('next_scheduled'), style: TextStyle(fontSize: 12, color: context.textSecondary)),
                  Text('${nextRecurrence.day}/${nextRecurrence.month}/${nextRecurrence.year}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ])),
              ]),
            ),
            const SizedBox(height: 20),
          ],

          // Reminder section
          _buildSectionTitle(AppLocalizations.get('reminder_settings'), false),
          const SizedBox(height: 8),
          _buildReminderSection(isDark, nextRecurrence),
          const SizedBox(height: 20),

          // Mark as completed
          if (_isPastDate && _selectedFrequency == 'once') ...[
            _buildCompletedToggle(isDark),
            const SizedBox(height: 20),
          ],

          // Notes
          _buildSectionTitle(AppLocalizations.get('notes'), false),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: AppLocalizations.get('notes_hint'),
              filled: true,
              fillColor: isDark ? AppColors.surfaceDark : Colors.white,
            ),
          ),
          const SizedBox(height: 24),

          // Save button
          ElevatedButton(
            onPressed: _isLoading ? null : _saveRecord,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(AppLocalizations.get('save'), style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _getSubTypeLabel() {
    switch (_selectedType) {
      case 'vaccine': return AppLocalizations.get('vaccine_type');
      case 'medicine': return AppLocalizations.get('medicine_type');
      case 'food': return AppLocalizations.get('food_type');
      case 'vet': return AppLocalizations.get('visit_type');
      case 'grooming': return AppLocalizations.get('grooming_type');
      case 'weight': return AppLocalizations.get('weight');
      default: return AppLocalizations.get('type');
    }
  }

  Widget _buildSectionTitle(String title, bool isRequired) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        if (isRequired) const Text(' *', style: TextStyle(fontSize: 14, color: AppColors.error)),
      ],
    );
  }

  Widget _buildCatSelector(List<dynamic> cats, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _selectedCatIds.isEmpty ? AppColors.error : Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Row(
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _selectedCatIds = cats.map((c) => c.id as String).toSet()),
                icon: const Icon(Icons.select_all, size: 18),
                label: Text(AppLocalizations.get('select_all')),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => setState(() => _selectedCatIds = {}),
                icon: const Icon(Icons.deselect, size: 18),
                label: Text(AppLocalizations.get('deselect_all')),
              ),
            ],
          ),
          const Divider(),
          ...cats.map((cat) {
            final isSelected = _selectedCatIds.contains(cat.id);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                backgroundImage: cat.photoPath != null ? FileImage(File(cat.photoPath!)) : null,
                child: cat.photoPath == null ? const Icon(Icons.pets, color: AppColors.primary, size: 20) : null,
              ),
              title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: Checkbox(
                value: isSelected,
                onChanged: (v) {
                  setState(() {
                    if (v == true) { _selectedCatIds.add(cat.id); } 
                    else { _selectedCatIds.remove(cat.id); }
                  });
                },
                activeColor: AppColors.primary,
              ),
              onTap: () {
                setState(() {
                  if (isSelected) { _selectedCatIds.remove(cat.id); } 
                  else { _selectedCatIds.add(cat.id); }
                });
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTypeSelector(bool isDark) {
    return Row(
      children: _reminderTypes.map((type) {
        final isSelected = _selectedType == type['type'];
        final color = type['color'] as Color;
        final isDotcat = type['type'] == 'dotcat_complete';
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() {
              _selectedType = type['type'] as String;
              _selectedSubType = null;
              _isOtherSubType = false;
              _titleController.clear();
              // dotcat için daily varsayılan
              if (_selectedType == 'dotcat_complete') {
                _selectedFrequency = 'daily';
              }
              // Yeni tipe geçince, varsa ilk alt türü otomatik seç
              final subTypesForType = _subTypes[_selectedType];
              if (subTypesForType != null && subTypesForType.isNotEmpty) {
                _selectedSubType = subTypesForType.first;
                _isOtherSubType = _selectedSubType == 'other' || _selectedSubType == 'vaccine_other';
              }
            }),
            child: Container(
              margin: EdgeInsets.only(right: type != _reminderTypes.last ? 6 : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.15) : (isDark ? AppColors.surfaceDark : Colors.white),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isSelected ? color : Colors.grey.shade300, width: isSelected ? 2 : 1),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (isDotcat)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset('assets/images/logo.png', width: 32, height: 32),
                  )
                else
                  Icon(type['icon'] as IconData, color: isSelected ? color : AppColors.textSecondary, size: 22),
                const SizedBox(height: 4),
                Text(
                  isDotcat ? AppLocalizations.get('products') : AppLocalizations.get(type['type'] as String), 
                  style: TextStyle(color: isSelected ? color : AppColors.textSecondary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubTypeSelector(List<String> subTypes, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: subTypes.map((subType) {
            final isSelected = _selectedSubType == subType;
            final isOther = subType == 'other' || subType == 'vaccine_other';
            final label = AppLocalizations.get(subType);
            
            return GestureDetector(
              onTap: () => setState(() {
                _selectedSubType = subType;
                _isOtherSubType = isOther;
                if (!isOther) _titleController.clear();
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withOpacity(0.15) : (isDark ? AppColors.surfaceDark : Colors.white),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade300),
                ),
                child: Text(label, style: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                )),
              ),
            );
          }).toList(),
        ),
        // Show text field when "other" or "vaccine_other" is selected
        if (_isOtherSubType) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: AppLocalizations.get('enter_title'),
              filled: true,
              fillColor: isDark ? AppColors.surfaceDark : Colors.white,
              prefixIcon: const Icon(Icons.edit, size: 20),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ],
    );
  }

  Widget _buildDateSelector(bool isDark) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context, 
          initialDate: _selectedDate,
          firstDate: DateTime(2000),
          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
        );
        if (picked != null) setState(() => _selectedDate = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _isPastDate ? AppColors.info : AppColors.primary),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Icon(_isPastDate ? Icons.history : Icons.calendar_today, color: _isPastDate ? AppColors.info : AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_isPastDate) Text(AppLocalizations.get('past_record'), style: TextStyle(fontSize: 11, color: AppColors.info)),
              Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _isPastDate ? AppColors.info : AppColors.primary)),
            ]),
          ]),
          Icon(Icons.edit, color: _isPastDate ? AppColors.info : AppColors.primary, size: 18),
        ]),
      ),
    );
  }

  Widget _buildFrequencySelector(bool isDark) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _frequencies.map((freq) {
        final isSelected = _selectedFrequency == freq['key'];
        return GestureDetector(
          onTap: () => setState(() => _selectedFrequency = freq['key']!),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withOpacity(0.15) : (isDark ? AppColors.surfaceDark : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade300),
            ),
            child: Text(AppLocalizations.get(freq['label']!), style: TextStyle(color: isSelected ? AppColors.primary : AppColors.textSecondary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, fontSize: 12)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCustomDaysInput(bool isDark) {
    return Row(children: [
      Expanded(
        child: TextField(
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: AppLocalizations.get('enter_days'), filled: true, fillColor: isDark ? AppColors.surfaceDark : Colors.white),
          onChanged: (v) => setState(() => _customDays = int.tryParse(v)),
        ),
      ),
      const SizedBox(width: 10),
      Text(AppLocalizations.get('days'), style: TextStyle(color: context.textSecondary)),
    ]);
  }

  Widget _buildReminderSection(bool isDark, DateTime? nextRecurrence) {
    final targetDate = nextRecurrence ?? _selectedDate;
    final canSetReminder = targetDate.isAfter(DateTime.now());
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _enableReminder ? AppColors.primary : Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(_enableReminder ? Icons.notifications_active : Icons.notifications_off, 
                     color: _enableReminder ? AppColors.primary : AppColors.textSecondary, size: 22),
                const SizedBox(width: 12),
                Text(AppLocalizations.get('enable_reminder'), style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
              Switch(
                value: _enableReminder,
                onChanged: canSetReminder ? (v) => setState(() => _enableReminder = v) : null,
                activeColor: AppColors.primary,
              ),
            ],
          ),
          
          if (!canSetReminder) ...[
            const SizedBox(height: 8),
            Text(AppLocalizations.get('reminder_not_available'), style: TextStyle(fontSize: 12, color: context.textSecondary)),
          ],
          
          if (_enableReminder && canSetReminder) ...[
            const SizedBox(height: 16),
            Text(AppLocalizations.get('remind_me'), style: TextStyle(fontSize: 13, color: context.textSecondary)),
            const SizedBox(height: 8),
            
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _reminderTimings.map((timing) {
                final isSelected = _reminderTiming == timing['key'];
                return GestureDetector(
                  onTap: () => setState(() => _reminderTiming = timing['key'] as String),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade300),
                    ),
                    child: Text(AppLocalizations.get(timing['label'] as String), style: TextStyle(
                      color: isSelected ? AppColors.primary : context.textSecondary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 12,
                    )),
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 12),
            Text(AppLocalizations.get('notification_time'), style: TextStyle(fontSize: 13, color: context.textSecondary)),
            const SizedBox(height: 8),
            _buildSimpleTimePicker(isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildCompletedToggle(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _isCompleted ? AppColors.success : Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Icon(_isCompleted ? Icons.check_circle : Icons.circle_outlined, color: _isCompleted ? AppColors.success : AppColors.textSecondary, size: 22),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(AppLocalizations.get('mark_completed'), style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(_isCompleted ? AppLocalizations.get('completed') : AppLocalizations.get('pending'), style: TextStyle(fontSize: 12, color: context.textSecondary)),
            ]),
          ]),
          Switch(value: _isCompleted, onChanged: (v) => setState(() => _isCompleted = v), activeColor: AppColors.success),
        ],
      ),
    );
  }

  Widget _buildSimpleTimePicker(bool isDark) {
    return Row(
      children: [
        // Hour picker
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withOpacity(0.5)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedTime.hour,
              isDense: true,
              items: List.generate(24, (i) => DropdownMenuItem(
                value: i,
                child: Text(i.toString().padLeft(2, '0'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              )),
              onChanged: (v) => setState(() => _selectedTime = TimeOfDay(hour: v!, minute: _selectedTime.minute)),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(':', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        // Minute picker
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withOpacity(0.5)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedTime.minute,
              isDense: true,
              items: List.generate(12, (i) => DropdownMenuItem(
                value: i * 5,
                child: Text((i * 5).toString().padLeft(2, '0'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              )),
              onChanged: (v) => setState(() => _selectedTime = TimeOfDay(hour: _selectedTime.hour, minute: v!)),
            ),
          ),
        ),
      ],
    );
  }
}
