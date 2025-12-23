import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/localization.dart';
import '../../../data/models/cat.dart';
import '../providers/reminders_provider.dart';
import 'add_reminder_screen.dart';

class RemindersScreen extends ConsumerStatefulWidget {
  final Cat cat;
  final String? filterType;
  const RemindersScreen({super.key, required this.cat, this.filterType});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  late String? _currentFilter;

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.filterType;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(remindersProvider.notifier).loadRemindersForCat(widget.cat.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final reminders = ref.watch(remindersProvider);
    var catReminders = reminders.where((r) => r.catId == widget.cat.id).toList();
    
    // Apply filter if set
    if (_currentFilter != null) {
      catReminders = catReminders.where((r) => r.type == _currentFilter).toList();
    }

    // Separate active and inactive
    final activeReminders = catReminders.where((r) => r.isActive).toList();
    final inactiveReminders = catReminders.where((r) => !r.isActive).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.cat.name} - ${AppLocalizations.get('reminders')}'),
        actions: [
          PopupMenuButton<String?>(
            icon: Icon(_currentFilter != null ? Icons.filter_alt : Icons.filter_alt_outlined),
            onSelected: (value) => setState(() => _currentFilter = value),
            itemBuilder: (context) => [
              PopupMenuItem(value: null, child: Text(AppLocalizations.get('all'))),
              PopupMenuItem(value: 'food', child: Row(children: [Icon(Icons.restaurant, color: AppColors.food, size: 18), const SizedBox(width: 8), Text(AppLocalizations.get('food'))])),
              PopupMenuItem(value: 'medicine', child: Row(children: [Icon(Icons.medication, color: AppColors.medicine, size: 18), const SizedBox(width: 8), Text(AppLocalizations.get('medicine'))])),
              PopupMenuItem(value: 'weight', child: Row(children: [Icon(Icons.monitor_weight, color: AppColors.weight, size: 18), const SizedBox(width: 8), Text(AppLocalizations.get('weight'))])),
              PopupMenuItem(value: 'vet', child: Row(children: [Icon(Icons.local_hospital, color: AppColors.vet, size: 18), const SizedBox(width: 8), Text(AppLocalizations.get('vet'))])),
            ],
          ),
        ],
      ),
      body: catReminders.isEmpty
          ? _buildEmptyState()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (activeReminders.isNotEmpty) ...[
                  Text(AppLocalizations.get('active_reminders_title'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  const SizedBox(height: 8),
                  ...activeReminders.map((r) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _buildReminderCard(r, isDark))),
                ],
                if (inactiveReminders.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(AppLocalizations.get('completed_reminders'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textSecondary)),
                  const SizedBox(height: 8),
                  ...inactiveReminders.map((r) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _buildReminderCard(r, isDark))),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddReminderScreen(initialType: _currentFilter))),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildReminderCard(dynamic reminder, bool isDark) {
    IconData icon;
    Color color;

    switch (reminder.type) {
      case 'food':
        icon = Icons.restaurant;
        color = AppColors.food;
        break;
      case 'medicine':
        icon = Icons.medication;
        color = AppColors.medicine;
        break;
      case 'vaccine':
        icon = Icons.vaccines;
        color = AppColors.vaccine;
        break;
      case 'vet':
        icon = Icons.local_hospital;
        color = AppColors.vet;
        break;
      case 'weight':
        icon = Icons.monitor_weight;
        color = AppColors.weight;
        break;
      default:
        icon = Icons.notifications;
        color = AppColors.primary;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: reminder.isActive ? null : Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (reminder.isActive ? color : Colors.grey).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: reminder.isActive ? color : Colors.grey, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: reminder.isActive ? null : Colors.grey),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(reminder.time, style: TextStyle(fontSize: 13, color: reminder.isActive ? context.textSecondary : Colors.grey)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(AppLocalizations.get(reminder.frequency), style: TextStyle(fontSize: 10, color: color)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Switch(
            value: reminder.isActive,
            activeColor: color,
            onChanged: (value) => ref.read(remindersProvider.notifier).toggleReminder(reminder),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            color: AppColors.error,
            onPressed: () => _showDeleteDialog(reminder),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
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
            Icon(Icons.notifications_none, size: 50, color: AppColors.primary.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(AppLocalizations.get('no_reminders_yet'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(AppLocalizations.get('add_reminder_hint'), style: TextStyle(fontSize: 13, color: context.textSecondary), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(dynamic reminder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.get('delete_reminder')),
        content: Text(AppLocalizations.get('delete_reminder_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.get('cancel'))),
          TextButton(
            onPressed: () {
              ref.read(remindersProvider.notifier).deleteReminder(reminder.id);
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.get('delete'), style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
