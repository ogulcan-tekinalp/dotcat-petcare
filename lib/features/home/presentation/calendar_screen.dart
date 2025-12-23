import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/utils/localization.dart';
import '../../../data/database/database_helper.dart';
import '../../cats/providers/cats_provider.dart';
import '../../reminders/providers/reminders_provider.dart';
import '../../reminders/presentation/add_reminder_screen.dart';
import '../../reminders/presentation/record_detail_screen.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  Set<String> _completedDates = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(remindersProvider.notifier).loadReminders();
      ref.read(catsProvider.notifier).loadCats();
      _loadCompletions();
    });
  }

  Future<void> _loadCompletions() async {
    final completions = await DatabaseHelper.instance.getAllCompletedDates();
    setState(() => _completedDates = completions);
  }

  // Frequency'ye göre sonraki tarihi hesapla
  DateTime? _calculateNextDate(DateTime date, String frequency) {
    switch (frequency) {
      case 'daily': return date.add(const Duration(days: 1));
      case 'weekly': return date.add(const Duration(days: 7));
      case 'monthly': return DateTime(date.year, date.month + 1, date.day);
      case 'quarterly': return DateTime(date.year, date.month + 3, date.day);
      case 'biannual': return DateTime(date.year, date.month + 6, date.day);
      case 'yearly': return DateTime(date.year + 1, date.month, date.day);
      default:
        if (frequency.startsWith('custom_')) {
          final days = int.tryParse(frequency.substring(7));
          if (days != null) return date.add(Duration(days: days));
        }
        return null;
    }
  }

  // Bir reminder için tüm occurrence'ları oluştur
  List<Map<String, dynamic>> _generateOccurrences(dynamic reminder, DateTime rangeStart, DateTime rangeEnd) {
    final items = <Map<String, dynamic>>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    if (reminder.frequency == 'once') {
      final date = DateTime(reminder.createdAt.year, reminder.createdAt.month, reminder.createdAt.day);
      if (date.isAfter(rangeStart.subtract(const Duration(days: 1))) && date.isBefore(rangeEnd.add(const Duration(days: 1)))) {
        final key = '${reminder.id}_${date.toIso8601String().split('T')[0]}';
        final isCompleted = _completedDates.contains(key) || reminder.isCompleted;
        String status;
        if (isCompleted) {
          status = 'completed';
        } else if (date.isBefore(today)) {
          status = 'overdue';
        } else {
          status = 'pending';
        }
        items.add({'reminder': reminder, 'date': date, 'status': status});
      }
    } else {
      DateTime current = DateTime(reminder.createdAt.year, reminder.createdAt.month, reminder.createdAt.day);
      
      while (current.isBefore(rangeStart)) {
        final next = _calculateNextDate(current, reminder.frequency);
        if (next == null) break;
        current = next;
      }
      
      while (current.isBefore(rangeEnd.add(const Duration(days: 1)))) {
        final key = '${reminder.id}_${current.toIso8601String().split('T')[0]}';
        final isCompleted = _completedDates.contains(key);
        String status;
        if (isCompleted) {
          status = 'completed';
        } else if (current.isBefore(today)) {
          status = 'overdue';
        } else {
          status = 'pending';
        }
        items.add({'reminder': reminder, 'date': current, 'status': status});
        
        final next = _calculateNextDate(current, reminder.frequency);
        if (next == null) break;
        current = next;
      }
    }
    
    return items;
  }

  // Tüm günler için occurrence'ları hesapla
  Map<DateTime, List<Map<String, dynamic>>> _getEventsForMonth(DateTime monthStart, DateTime monthEnd) {
    final reminders = ref.read(remindersProvider);
    final events = <DateTime, List<Map<String, dynamic>>>{};
    
    for (final reminder in reminders) {
      final occurrences = _generateOccurrences(reminder, monthStart, monthEnd);
      for (final occ in occurrences) {
        final date = occ['date'] as DateTime;
        final day = DateTime(date.year, date.month, date.day);
        if (!events.containsKey(day)) {
          events[day] = [];
        }
        events[day]!.add(occ);
      }
    }
    
    return events;
  }

  // Kayıt türüne göre renk
  Color _getTypeColor(String type) {
    switch (type) {
      case 'vaccine': return AppColors.vaccine;
      case 'medicine': return AppColors.medicine;
      case 'vet': return AppColors.vet;
      case 'food': return AppColors.food;
      case 'dotcat_complete': return AppColors.dotcat;
      case 'weight': return AppColors.warning;
      default: return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(catsProvider);

    final monthStart = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final monthEnd = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    final events = _getEventsForMonth(monthStart, monthEnd);

    final selectedDayKey = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    final selectedDayEvents = events[selectedDayKey] ?? [];
    selectedDayEvents.sort((a, b) {
      final aTime = (a['reminder'] as dynamic).time;
      final bTime = (b['reminder'] as dynamic).time;
      return aTime.compareTo(bTime);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.get('calendar')),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: AppLocalizations.get('add_record'),
            onPressed: () {
              final cat = cats.isNotEmpty ? cats.first : null;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddReminderScreen(
                    preselectedCatId: cat?.id,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: CalendarFormat.month, // Sadece ay görünümü
            eventLoader: (day) {
              final dayKey = DateTime(day.year, day.month, day.day);
              return events[dayKey] ?? [];
            },
            startingDayOfWeek: StartingDayOfWeek.monday,
            locale: AppLocalizations.currentLanguage == AppLanguage.tr ? 'tr_TR' : 
                    AppLocalizations.currentLanguage == AppLanguage.de ? 'de_DE' :
                    AppLocalizations.currentLanguage == AppLanguage.es ? 'es_ES' :
                    AppLocalizations.currentLanguage == AppLanguage.ar ? 'ar_SA' : 'en_US',
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              todayDecoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              weekendDecoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
              ),
              defaultTextStyle: const TextStyle(fontSize: 14),
              weekendTextStyle: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              todayTextStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
              selectedTextStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              markersMaxCount: 3,
              markerSize: 6,
              canMarkersOverflow: true,
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: false, // Format butonunu kaldır
              titleCentered: true,
              titleTextStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              leftChevronIcon: const Icon(Icons.chevron_left, size: 24),
              rightChevronIcon: const Icon(Icons.chevron_right, size: 24),
              formatButtonShowsNext: false,
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              setState(() => _focusedDay = focusedDay);
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return null;
                final dayEvents = events as List<Map<String, dynamic>>;
                
                // Kayıt türlerine göre renkleri topla
                final Set<String> types = {};
                for (final event in dayEvents) {
                  final reminder = event['reminder'] as dynamic;
                  types.add(reminder.type);
                }
                
                if (types.isEmpty) return null;
                
                // Birden fazla tür varsa küçük noktalar halinde göster
                final typeList = types.toList();
                if (typeList.length == 1) {
                  // Tek tür varsa büyük nokta
                  Color typeColor = _getTypeColor(typeList[0]);
                  return Positioned(
                    bottom: 1,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: typeColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                } else {
                  // Birden fazla tür varsa küçük noktalar
                  return Positioned(
                    bottom: 1,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: typeList.take(3).map((type) {
                        return Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: _getTypeColor(type),
                            shape: BoxShape.circle,
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  DateHelper.formatDate(_selectedDay),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (selectedDayEvents.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${selectedDayEvents.length} ${AppLocalizations.get('items')}',
                      style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: selectedDayEvents.isEmpty
                ? Center(
                    child: Text(
                      AppLocalizations.get('no_records'),
                      style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                    ),
                  )
                : ListView.builder(
                    itemCount: selectedDayEvents.length,
                    itemBuilder: (context, index) {
                      final occ = selectedDayEvents[index];
                      final record = occ['reminder'] as dynamic;
                      final status = occ['status'] as String;
                      final cat = cats.firstWhere(
                        (c) => c.id == record.catId,
                        orElse: () => null as dynamic,
                      );

                      Color typeColor;
                      IconData icon;
                      switch (record.type) {
                        case 'vaccine':
                          typeColor = AppColors.vaccine;
                          icon = Icons.vaccines;
                          break;
                        case 'medicine':
                          typeColor = AppColors.medicine;
                          icon = Icons.medication;
                          break;
                        case 'vet':
                          typeColor = AppColors.vet;
                          icon = Icons.local_hospital;
                          break;
                        case 'food':
                          typeColor = AppColors.food;
                          icon = Icons.restaurant;
                          break;
                        case 'dotcat_complete':
                          typeColor = AppColors.dotcat;
                          icon = Icons.pets;
                          break;
                        case 'weight':
                          typeColor = AppColors.warning;
                          icon = Icons.monitor_weight;
                          break;
                        default:
                          typeColor = AppColors.primary;
                          icon = Icons.event;
                      }

                      Color borderColor;
                      if (status == 'overdue') borderColor = AppColors.error;
                      else if (status == 'pending') borderColor = AppColors.warning;
                      else borderColor = AppColors.success;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: borderColor, width: 2),
                          ),
                          child: ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: typeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(icon, color: typeColor),
                            ),
                            title: Text(
                              record.title,
                              style: TextStyle(
                                decoration: status == 'completed' ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            subtitle: Text(cat?.name ?? ''),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(record.time, style: const TextStyle(fontSize: 12)),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: borderColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    status == 'overdue' ? AppLocalizations.get('overdue') :
                                    status == 'pending' ? AppLocalizations.get('pending') :
                                    AppLocalizations.get('completed'),
                                    style: TextStyle(fontSize: 9, color: borderColor, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RecordDetailScreen(
                                    record: record,
                                    catName: cat?.name ?? '',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
