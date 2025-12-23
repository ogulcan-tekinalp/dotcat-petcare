import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/utils/localization.dart';
import '../../../data/models/cat.dart';
import '../../../features/reminders/providers/reminders_provider.dart';
import '../../reminders/presentation/add_reminder_screen.dart';
import '../providers/weight_provider.dart';

class WeightScreen extends ConsumerStatefulWidget {
  final Cat cat;
  const WeightScreen({super.key, required this.cat});

  @override
  ConsumerState<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends ConsumerState<WeightScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(weightProvider.notifier).loadWeightRecords(widget.cat.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final weights = ref.watch(weightProvider);
    final latest = weights.isNotEmpty ? weights.first : null;
    final change = ref.read(weightProvider.notifier).getWeightChange();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.cat.name} - ${AppLocalizations.get('weight_tracking')}'),
        actions: [
          IconButton(
            tooltip: AppLocalizations.get('add_weight'),
            icon: const Icon(Icons.add),
            onPressed: _showAddWeightDialog,
          ),
          IconButton(
            tooltip: AppLocalizations.get('add_weight_reminder'),
            icon: const Icon(Icons.alarm_add_rounded),
            onPressed: _goToWeightReminder,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.weight, AppColors.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(AppLocalizations.get('current_weight'), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                Text(latest != null ? '${latest.weight} kg' : '-', style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                if (change != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(change > 0 ? Icons.arrow_upward : Icons.arrow_downward, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text('${change.abs().toStringAsFixed(1)} kg', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (weights.length >= 2) ...[
            Text(AppLocalizations.get('last_6_months'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              height: 180,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
              ),
              child: _buildSimpleChart(ref.read(weightProvider.notifier).getLast6Months()),
            ),
            const SizedBox(height: 24),
          ],
          Text(AppLocalizations.get('weight_history'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (weights.isEmpty) _buildEmptyState() else ...weights.map((record) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _buildWeightCard(record))),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddWeightDialog,
        child: const Icon(Icons.monitor_weight),
      ),
    );
  }

  Widget _buildSimpleChart(List weights) {
    if (weights.isEmpty) return const SizedBox();
    final maxWeight = weights.map((w) => w.weight as double).reduce((a, b) => a > b ? a : b);
    final minWeight = weights.map((w) => w.weight as double).reduce((a, b) => a < b ? a : b);
    final range = maxWeight - minWeight;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: weights.map((record) {
        final heightPercent = range == 0 ? 1.0 : (record.weight - minWeight) / range;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text('${record.weight}', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Container(height: 80 * (0.3 + 0.7 * heightPercent), decoration: BoxDecoration(color: AppColors.weight.withOpacity(0.7), borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 4),
              Text('${record.recordedAt.day}/${record.recordedAt.month}', style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWeightCard(dynamic record) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.weight.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.monitor_weight, color: AppColors.weight),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${record.weight} kg', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(DateHelper.formatDate(record.recordedAt), style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ])),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.error),
          onPressed: () async {
            try {
              await ref.read(weightProvider.notifier).deleteWeightRecord(record.id);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(AppLocalizations.get('error_deleting')),
                  backgroundColor: AppColors.error,
                ));
              }
            }
          },
        ),
      ]),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Icon(Icons.monitor_weight, size: 48, color: AppColors.weight.withOpacity(0.5)),
        const SizedBox(height: 16),
        Text(AppLocalizations.get('no_weight_records'), style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(AppLocalizations.get('add_first_weight'), style: TextStyle(color: AppColors.textSecondary)),
      ]),
    );
  }

  void _showAddWeightDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.get('add_weight')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tarih seçici
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateHelper.formatDate(_selectedDate)),
                    const Icon(Icons.calendar_today, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: AppLocalizations.get('weight_kg'),
                hintText: '${AppLocalizations.get('example')}: 4.5',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.get('cancel'))),
          ElevatedButton(
            onPressed: () async {
              // Handle both comma and dot as decimal separator
              final weight = double.tryParse(controller.text.replaceAll(',', '.'));
              if (weight != null && weight > 0) {
                try {
                  await ref.read(weightProvider.notifier).addWeightRecord(
                    catId: widget.cat.id,
                    weight: weight,
                    // kaydı seçili tarih ile oluştur
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(AppLocalizations.get('error_saving')),
                      backgroundColor: AppColors.error,
                    ));
                  }
                }
              }
            },
            child: Text(AppLocalizations.get('add')),
          ),
        ],
      ),
    );
  }

  void _goToWeightReminder() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddReminderScreen(
          initialType: 'weight',
          preselectedCatId: widget.cat.id,
        ),
      ),
    );
  }
}
