import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/utils/localization.dart';
import '../../../data/models/cat.dart';
import '../providers/health_provider.dart';

class HealthScreen extends ConsumerStatefulWidget {
  final Cat cat;
  const HealthScreen({super.key, required this.cat});

  @override
  ConsumerState<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends ConsumerState<HealthScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(healthProvider.notifier).loadHealthNotes(widget.cat.id);
    });
  }

  List<Map<String, dynamic>> get _healthTypes => [
    {'type': 'vet_visit', 'icon': Icons.local_hospital, 'color': AppColors.health},
    {'type': 'symptom', 'icon': Icons.healing, 'color': AppColors.warning},
    {'type': 'medication', 'icon': Icons.medication, 'color': AppColors.medicine},
    {'type': 'surgery', 'icon': Icons.medical_services, 'color': AppColors.error},
    {'type': 'other', 'icon': Icons.note, 'color': AppColors.textSecondary},
  ];

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(healthProvider);
    final catNotes = notes.where((n) => n.catId == widget.cat.id).toList();

    return Scaffold(
      appBar: AppBar(title: Text('${widget.cat.name} - ${AppLocalizations.get('health_notes')}')),
      body: catNotes.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: catNotes.length,
              itemBuilder: (context, index) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildNoteCard(catNotes[index])),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddNoteDialog,
        icon: const Icon(Icons.add),
        label: Text(AppLocalizations.get('add_health_note')),
      ),
    );
  }

  Widget _buildNoteCard(dynamic note) {
    final typeInfo = _healthTypes.firstWhere((t) => t['type'] == note.type, orElse: () => _healthTypes.last);
    final color = typeInfo['color'] as Color;
    final icon = typeInfo['icon'] as IconData;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(note.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                  child: Text(AppLocalizations.get(note.type), style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
                ),
                const SizedBox(width: 8),
                Text(DateHelper.formatDate(note.date), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ]),
            ])),
            IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.error), onPressed: () => ref.read(healthProvider.notifier).deleteHealthNote(note.id)),
          ]),
          if (note.description != null && note.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(note.description!, style: TextStyle(color: AppColors.textSecondary, height: 1.4)),
          ],
          if (note.veterinarian != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.person, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('${AppLocalizations.get('veterinarian')}: ${note.veterinarian}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: AppColors.health.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.health_and_safety, size: 60, color: AppColors.health.withOpacity(0.5)),
            ),
            const SizedBox(height: 24),
            Text(AppLocalizations.get('no_health_notes'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(AppLocalizations.get('add_health_hint'), style: TextStyle(fontSize: 14, color: AppColors.textSecondary), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  void _showAddNoteDialog() {
    String? selectedType;
    DateTime selectedDate = DateTime.now();
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final vetController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(AppLocalizations.get('add_health_note'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text(AppLocalizations.get('health_type'), style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _healthTypes.map((type) {
                    final isSelected = selectedType == type['type'];
                    final color = type['color'] as Color;
                    return GestureDetector(
                      onTap: () => setModalState(() => selectedType = type['type'] as String),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? color.withOpacity(0.2) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isSelected ? color : Colors.transparent),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(type['icon'] as IconData, size: 16, color: isSelected ? color : AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(AppLocalizations.get(type['type'] as String), style: TextStyle(fontSize: 12, color: isSelected ? color : AppColors.textSecondary)),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(controller: titleController, decoration: InputDecoration(labelText: AppLocalizations.get('title'))),
                const SizedBox(height: 12),
                TextField(controller: descController, maxLines: 3, decoration: InputDecoration(labelText: AppLocalizations.get('description_optional'), alignLabelWithHint: true)),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(AppLocalizations.get('date')),
                  subtitle: Text(DateHelper.formatDate(selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2000), lastDate: DateTime.now());
                    if (picked != null) setModalState(() => selectedDate = picked);
                  },
                ),
                TextField(controller: vetController, decoration: InputDecoration(labelText: AppLocalizations.get('veterinarian'))),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: (selectedType == null || titleController.text.isEmpty) ? null : () {
                    ref.read(healthProvider.notifier).addHealthNote(
                      petId: widget.cat.id,
                      title: titleController.text,
                      type: selectedType!,
                      description: descController.text.isEmpty ? null : descController.text,
                      date: selectedDate,
                      veterinarian: vetController.text.isEmpty ? null : vetController.text,
                    );
                    Navigator.pop(context);
                  },
                  child: Text(AppLocalizations.get('save')),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
