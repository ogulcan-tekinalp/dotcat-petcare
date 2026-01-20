import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/utils/localization.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/cat.dart';
import '../../../data/models/dog.dart';
import '../providers/vaccination_provider.dart';

class VaccinationScreen extends ConsumerStatefulWidget {
  final dynamic pet; // Supports both Cat and Dog
  const VaccinationScreen({super.key, required this.pet});

  @override
  ConsumerState<VaccinationScreen> createState() => _VaccinationScreenState();
}

class _VaccinationScreenState extends ConsumerState<VaccinationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(vaccinationProvider.notifier).loadVaccinations(widget.pet.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final vaccinations = ref.watch(vaccinationProvider);
    final petVaccinations = vaccinations.where((v) => v.petId == widget.pet.id).toList();
    final upcoming = petVaccinations.where((v) => v.isUpcoming && !v.isCompleted).toList();
    final overdue = petVaccinations.where((v) => v.isOverdue && !v.isCompleted).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text('${widget.pet.name} - ${AppLocalizations.get('vaccination')}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (overdue.isNotEmpty)
            _buildAlertCard(AppLocalizations.get('overdue_vaccines'), '${overdue.length} ${AppLocalizations.get('vaccines_overdue')}', Icons.warning, AppColors.error, isDark),
          if (upcoming.isNotEmpty)
            _buildAlertCard(AppLocalizations.get('upcoming_vaccines'), '${upcoming.length} ${AppLocalizations.get('vaccines_upcoming')}', Icons.schedule, AppColors.warning, isDark),
          if (overdue.isNotEmpty || upcoming.isNotEmpty) const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppLocalizations.get('vaccine_history'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              TextButton.icon(onPressed: _showAddVaccinationDialog, icon: const Icon(Icons.add, size: 18), label: Text(AppLocalizations.get('add'))),
            ],
          ),
          const SizedBox(height: 8),

          if (petVaccinations.isEmpty)
            _buildEmptyState(isDark)
          else
            ...petVaccinations.map((v) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _buildVaccinationCard(v, isDark))),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddVaccinationDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildAlertCard(String title, String subtitle, IconData icon, Color color, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
          Text(subtitle, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8))),
        ]),
      ]),
    );
  }

  Widget _buildVaccinationCard(dynamic vaccination, bool isDark) {
    final isCompleted = vaccination.isCompleted;
    
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isCompleted ? Border.all(color: AppColors.success.withOpacity(0.3)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isCompleted ? AppColors.success : AppColors.vaccine).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.vaccines, color: isCompleted ? AppColors.success : AppColors.vaccine, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(vaccination.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              Text(DateHelper.formatDate(vaccination.date), style: TextStyle(fontSize: 12, color: context.textSecondary)),
            ])),
            // Complete toggle button
            _buildCompleteButton(vaccination, isCompleted),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: AppColors.error,
              onPressed: () => ref.read(vaccinationProvider.notifier).deleteVaccination(vaccination.id),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
          if (vaccination.nextDate != null && !isCompleted) ...[
            const SizedBox(height: 10),
            _buildNextDateChip(vaccination),
          ],
          if (isCompleted) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle, size: 14, color: AppColors.success),
                const SizedBox(width: 4),
                Text(AppLocalizations.get('completed'), style: const TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w500)),
              ]),
            ),
          ],
          if (vaccination.veterinarian != null) ...[
            const SizedBox(height: 6),
            Text('${AppLocalizations.get('veterinarian')}: ${vaccination.veterinarian}', style: TextStyle(fontSize: 11, color: context.textSecondary)),
          ],
        ],
      ),
    );
  }

  Widget _buildCompleteButton(dynamic vaccination, bool isCompleted) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => ref.read(vaccinationProvider.notifier).toggleComplete(vaccination.id),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isCompleted ? AppColors.success.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isCompleted ? AppColors.success : Colors.grey.shade400),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(isCompleted ? Icons.check_circle : Icons.circle_outlined, size: 16, color: isCompleted ? AppColors.success : Colors.grey),
            const SizedBox(width: 4),
            Text(
              isCompleted ? AppLocalizations.get('completed') : AppLocalizations.get('mark_done'),
              style: TextStyle(fontSize: 11, color: isCompleted ? AppColors.success : Colors.grey, fontWeight: FontWeight.w500),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildNextDateChip(dynamic vaccination) {
    final isOverdue = vaccination.isOverdue;
    final color = isOverdue ? AppColors.error : AppColors.warning;
    final daysText = vaccination.daysUntilNext != null
        ? (isOverdue ? '${vaccination.daysUntilNext!.abs()} ${AppLocalizations.get('days_overdue')}' : '${vaccination.daysUntilNext} ${AppLocalizations.get('days_left')}')
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.event, size: 14, color: color),
        const SizedBox(width: 4),
        Text('${AppLocalizations.get('next')}: ${DateHelper.formatDate(vaccination.nextDate!)}', style: TextStyle(fontSize: 11, color: color)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
          child: Text(daysText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ),
      ]),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: isDark ? AppColors.surfaceDark : Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Icon(Icons.vaccines, size: 40, color: AppColors.vaccine.withOpacity(0.4)),
        const SizedBox(height: 12),
        Text(AppLocalizations.get('no_vaccines_yet'), style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(AppLocalizations.get('add_first_vaccine'), style: TextStyle(fontSize: 13, color: context.textSecondary)),
      ]),
    );
  }

  void _showAddVaccinationDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String? selectedVaccine;
    DateTime selectedDate = DateTime.now();
    DateTime? nextDate;
    final vetController = TextEditingController();

    // Determine vaccine types based on pet type
    final isCat = widget.pet is Cat;
    final vaccineTypes = isCat ? AppConstants.catVaccineTypes : AppConstants.dogVaccineTypes;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(AppLocalizations.get('add_vaccine'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedVaccine,
                decoration: InputDecoration(labelText: AppLocalizations.get('vaccine_type')),
                items: vaccineTypes.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (v) => setModalState(() => selectedVaccine = v),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(AppLocalizations.get('vaccine_date')),
                subtitle: Text(DateHelper.formatDate(selectedDate)),
                trailing: const Icon(Icons.calendar_today, size: 20),
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2000), lastDate: DateTime.now());
                  if (picked != null) setModalState(() => selectedDate = picked);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(AppLocalizations.get('next_vaccine_date')),
                subtitle: Text(nextDate != null ? DateHelper.formatDate(nextDate!) : AppLocalizations.get('not_set')),
                trailing: const Icon(Icons.calendar_today, size: 20),
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 365)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365 * 3)));
                  if (picked != null) setModalState(() => nextDate = picked);
                },
              ),
              TextField(controller: vetController, decoration: InputDecoration(labelText: AppLocalizations.get('veterinarian'))),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: selectedVaccine == null ? null : () {
                  ref.read(vaccinationProvider.notifier).addVaccination(
                    catId: widget.pet.id,
                    catName: widget.pet.name,
                    name: selectedVaccine!,
                    date: selectedDate,
                    nextDate: nextDate,
                    veterinarian: vetController.text.isEmpty ? null : vetController.text,
                  );
                  Navigator.pop(context);
                  _showToast(AppLocalizations.get('vaccine_added'));
                },
                child: Text(AppLocalizations.get('save')),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [const Icon(Icons.check_circle, color: Colors.white, size: 20), const SizedBox(width: 10), Text(message)]),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
