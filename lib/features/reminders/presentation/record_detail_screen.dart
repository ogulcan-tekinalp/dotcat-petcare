import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/localization.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/utils/page_transitions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../data/models/reminder.dart';
import 'add_reminder_screen.dart';
import '../../../core/utils/notification_service.dart';
import '../../../core/services/firestore_service.dart';
import '../providers/reminders_provider.dart';

class RecordDetailScreen extends ConsumerStatefulWidget {
  final dynamic record;
  final String catName;
  
  const RecordDetailScreen({super.key, required this.record, required this.catName});

  @override
  ConsumerState<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends ConsumerState<RecordDetailScreen> {
  late bool _isCompleted;
  bool _isEditing = false;
  
  // Edit controllers
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  late String _selectedType;
  late String _selectedFrequency;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _isCompleted = !widget.record.isActive;
    _initEditControllers();
  }

  void _initEditControllers() {
    _titleController = TextEditingController(text: widget.record.title);
    _notesController = TextEditingController(text: widget.record.notes ?? '');
    _selectedType = widget.record.type;
    _selectedFrequency = widget.record.frequency;
    _selectedDate = widget.record.createdAt;
    
    final timeParts = widget.record.time.split(':');
    _selectedTime = TimeOfDay(
      hour: int.tryParse(timeParts[0]) ?? 9,
      minute: int.tryParse(timeParts[1]) ?? 0,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Color get _typeColor {
    switch (_selectedType) {
      case 'food': return AppColors.food;
      case 'medicine': return AppColors.medicine;
      case 'vaccine': return AppColors.vaccine;
      case 'vet': return AppColors.vet;
      case 'dotcat_complete': return AppColors.dotcat;
      case 'weight': return AppColors.warning;
      default: return AppColors.primary;
    }
  }

  IconData get _typeIcon {
    switch (_selectedType) {
      case 'food': return Icons.restaurant_rounded;
      case 'medicine': return Icons.medication_rounded;
      case 'vaccine': return Icons.vaccines_rounded;
      case 'vet': return Icons.local_hospital_rounded;
      case 'dotcat_complete': return Icons.pets_rounded;
      case 'weight': return Icons.monitor_weight_rounded;
      default: return Icons.event_rounded;
    }
  }

  String _getFrequencyText(String freq) {
    switch (freq) {
      case 'once': return AppLocalizations.get('once');
      case 'daily': return AppLocalizations.get('daily');
      case 'weekly': return AppLocalizations.get('weekly');
      case 'monthly': return AppLocalizations.get('monthly');
      case 'quarterly': return AppLocalizations.get('quarterly');
      case 'biannual': return AppLocalizations.get('biannual');
      case 'yearly': return AppLocalizations.get('yearly');
      default: 
        if (freq.startsWith('custom_')) {
          final days = freq.replaceFirst('custom_', '');
          return '$days ${AppLocalizations.get('days')}';
        }
        return freq;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? AppLocalizations.get('edit_record') : AppLocalizations.get('record_detail')),
        actions: [
          if (!_isEditing) ...[
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              onPressed: () {
                // AddReminderScreen'e yönlendir (düzenleme modu - mevcut kayıt ile)
                Navigator.push(
                  context,
                  PageTransitions.slide(
                    page: AddReminderScreen(
                      reminder: widget.record,
                    ),
                  ),
                ).then((_) {
                  // Geri dönünce refresh et
                  if (mounted) {
                    ref.read(remindersProvider.notifier).loadReminders();
                    setState(() {}); // UI'ı güncelle
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _showDeleteConfirmation,
            ),
          ] else ...[
            TextButton(
              onPressed: () {
                _initEditControllers();
                setState(() => _isEditing = false);
              },
              child: Text(AppLocalizations.get('cancel')),
            ),
            TextButton(
              onPressed: _saveChanges,
              child: Text(AppLocalizations.get('save'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
      body: _isEditing ? _buildEditView(isDark) : _buildDetailView(isDark),
    );
  }

  Widget _buildDetailView(bool isDark) {
    return ListView(
      physics: const BouncingScrollPhysics(), // iOS-style smooth scrolling
      padding: const EdgeInsets.all(16),
      children: [
        // Header card
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          child: Column(
            children: [
              // Tür logosu (dotcat için özel logo, diğerleri için icon)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _typeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _selectedType == 'dotcat_complete'
                    ? Image.asset('assets/images/logo.png', width: 64, height: 64)
                    : Icon(_typeIcon, color: _typeColor, size: 64),
              ),
              const SizedBox(height: 20),
              Text(widget.record.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(widget.catName, style: TextStyle(fontSize: 16, color: context.textSecondary, fontWeight: FontWeight.w500)),
              const SizedBox(height: 24),
              // Tamamlandı butonu - daha belirgin ve büyük
              AppButton(
                label: _isCompleted ? AppLocalizations.get('completed') : AppLocalizations.get('mark_completed'),
                icon: _isCompleted ? Icons.check_circle_rounded : Icons.schedule_rounded,
                onPressed: () => _handleToggleCompletion(),
                variant: ButtonVariant.filled,
                color: _isCompleted ? AppColors.success : AppColors.warning,
                height: AppSpacing.buttonHeightLg + 10,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Details
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.get('details'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              _buildDetailRow(Icons.category_rounded, AppLocalizations.get('type'), AppLocalizations.get(widget.record.type)),
              _buildDetailRow(Icons.calendar_today_rounded, AppLocalizations.get('date'), DateHelper.formatDate(widget.record.createdAt)),
              _buildDetailRow(Icons.access_time_rounded, AppLocalizations.get('time'), widget.record.time),
              _buildDetailRow(Icons.repeat_rounded, AppLocalizations.get('frequency'), _getFrequencyText(widget.record.frequency)),
              
              if (widget.record.notes != null && widget.record.notes!.isNotEmpty) ...[
                const Divider(height: 24),
                Row(children: [
                  Icon(Icons.notes_rounded, size: 18, color: context.textSecondary),
                  const SizedBox(width: 12),
                  Text(AppLocalizations.get('notes'), style: TextStyle(fontSize: 13, color: context.textSecondary)),
                ]),
                const SizedBox(height: 8),
                Text(widget.record.notes!, style: const TextStyle(fontSize: 15)),
              ],
            ],
          ),
        ),
        
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildEditView(bool isDark) {
    return ListView(
      physics: const BouncingScrollPhysics(), // iOS-style smooth scrolling
      padding: const EdgeInsets.all(16),
      children: [
        // Title
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.get('title'), style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: AppLocalizations.get('enter_title'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: isDark ? Colors.black12 : Colors.grey.shade50,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Type selector
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.get('type'), style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildTypeOption('vaccine', Icons.vaccines_rounded, AppColors.vaccine),
                  const SizedBox(width: 8),
                  _buildTypeOption('medicine', Icons.medication_rounded, AppColors.medicine),
                  const SizedBox(width: 8),
                  _buildTypeOption('vet', Icons.local_hospital_rounded, AppColors.vet),
                  const SizedBox(width: 8),
                  _buildTypeOption('food', Icons.restaurant_rounded, AppColors.food),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Date & Time
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.get('date_time'), style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _selectDate,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 20),
                            const SizedBox(width: 10),
                            Text(DateHelper.formatShortDate(_selectedDate)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: _selectTime,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 20),
                            const SizedBox(width: 10),
                            Text('${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Frequency
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.get('frequency'), style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['once', 'daily', 'weekly', 'monthly', 'yearly'].map((freq) {
                  final isSelected = _selectedFrequency == freq;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedFrequency = freq),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? _typeColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? _typeColor : Colors.grey.shade300),
                      ),
                      child: Text(
                        _getFrequencyText(freq),
                        style: TextStyle(
                          color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Notes
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.get('notes'), style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: AppLocalizations.get('notes_hint'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: isDark ? Colors.black12 : Colors.grey.shade50,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildTypeOption(String type, IconData icon, Color color) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: isSelected ? null : Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : color, size: 24),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.get(type),
                style: TextStyle(fontSize: 10, color: isSelected ? Colors.white : color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _saveChanges() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.get('enter_title')),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    final timeString = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';
    
    final updatedReminder = Reminder(
      id: widget.record.id,
      petId: widget.record.petId,
      title: _titleController.text,
      type: _selectedType,
      time: timeString,
      frequency: _selectedFrequency,
      isActive: widget.record.isActive,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      createdAt: _selectedDate,
    );

    // Update in Firebase
    try {
      await FirestoreService().saveReminder(updatedReminder);
      // Provider state'i de güncelle (reminder listesini yeniden yükle)
      await ref.read(remindersProvider.notifier).loadReminders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.get('error_saving')),
          backgroundColor: AppColors.error,
        ));
      }
      return;
    }
    
    // Reschedule notification
    await NotificationService.instance.cancelReminder(widget.record.id.hashCode);
    if (updatedReminder.isActive) {
      final scheduledDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );
      
      if (scheduledDateTime.isAfter(DateTime.now())) {
        if (_selectedFrequency == 'daily') {
          await NotificationService.instance.scheduleDailyReminder(
            id: updatedReminder.id.hashCode,
            title: '🐱 ${updatedReminder.title}',
            body: '${widget.catName} için hatırlatıcı',
            hour: _selectedTime.hour,
            minute: _selectedTime.minute,
          );
        } else {
          await NotificationService.instance.scheduleOneTimeReminder(
            id: updatedReminder.id.hashCode,
            title: '🐱 ${updatedReminder.title}',
            body: '${widget.catName} için hatırlatıcı',
            dateTime: scheduledDateTime,
          );
        }
      }
    }

    // Reload reminders
    await ref.read(remindersProvider.notifier).loadReminders();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.get('record_updated')),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.pop(context);
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _typeColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _typeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: _typeColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: TextStyle(color: context.textSecondary, fontSize: 15)),
                Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: _typeColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.delete_outline_rounded, size: 32, color: AppColors.error),
          ),
          const SizedBox(height: 20),
          Text(AppLocalizations.get('delete_record_confirm'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(widget.record.title, style: TextStyle(color: context.textSecondary, fontSize: 15)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text(AppLocalizations.get('cancel')),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () async {
                await ref.read(remindersProvider.notifier).deleteReminder(widget.record.id);
                if (mounted) {
                  Navigator.pop(context);
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text(AppLocalizations.get('delete')),
            )),
          ]),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }
  
  /// Tamamlama işlemini yönet - sağlık kayıtları için tarih sor
  Future<void> _handleToggleCompletion() async {
    final wasCompleted = _isCompleted;
    
    if (wasCompleted) {
      // Geri alma - doğrudan yap
      setState(() => _isCompleted = !_isCompleted);
      await ref.read(remindersProvider.notifier).toggleReminder(widget.record);
      _showCompletionFeedback();
    } else {
      // Tamamlama - sağlık kayıtları için tarih sor
      final isHealthRecord = ['vaccine', 'medicine', 'vet'].contains(widget.record.type);
      
      if (isHealthRecord && widget.record.frequency != 'once') {
        final actualDate = await _showCompletionDatePicker();
        if (actualDate != null) {
          setState(() => _isCompleted = !_isCompleted);
          await ref.read(remindersProvider.notifier).toggleReminder(widget.record, actualCompletionDate: actualDate);
          _showCompletionFeedback();
        }
      } else {
        setState(() => _isCompleted = !_isCompleted);
        await ref.read(remindersProvider.notifier).toggleReminder(widget.record);
        _showCompletionFeedback();
      }
    }
  }
  
  void _showCompletionFeedback() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isCompleted ? AppLocalizations.get('marked_completed') : AppLocalizations.get('marked_pending')),
        backgroundColor: _isCompleted ? AppColors.success : AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
  
  /// Sağlık kayıtları için "ne zaman yapıldı?" tarih seçici
  Future<DateTime?> _showCompletionDatePicker() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    DateTime selectedDate = widget.record.nextDate ?? DateTime.now();
    
    return showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Icon(
                widget.record.type == 'vaccine' ? Icons.vaccines :
                widget.record.type == 'medicine' ? Icons.medication :
                Icons.local_hospital,
                color: widget.record.type == 'vaccine' ? AppColors.vaccine :
                       widget.record.type == 'medicine' ? AppColors.medicine :
                       AppColors.vet,
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.get('when_was_it_done'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.get('next_will_be_calculated'),
                style: TextStyle(fontSize: 13, color: context.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Tarih seçici
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setModalState(() => selectedDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_today, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Text(
                        DateHelper.formatDate(selectedDate),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(AppLocalizations.get('cancel')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, selectedDate),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(AppLocalizations.get('confirm')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
