import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/localization.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/utils/notification_service.dart';
import '../../../core/utils/page_transitions.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../data/models/reminder_completion.dart';
import '../../cats/providers/cats_provider.dart';
import '../../reminders/providers/reminders_provider.dart';
import '../../reminders/providers/completions_provider.dart';
import '../../cats/presentation/cat_detail_screen.dart';
import '../../cats/presentation/add_cat_screen.dart';
import '../../reminders/presentation/add_reminder_screen.dart';
import '../../reminders/presentation/record_detail_screen.dart';
import 'calendar_screen.dart';
import 'settings_screen.dart';

bool _photoExists(String? path) {
  if (path == null || path.isEmpty) return false;
  // URL ise her zaman true
  if (path.startsWith('http://') || path.startsWith('https://')) return true;
  return File(path).existsSync();
}

Widget _buildCatPhoto(String? photoPath, {double radius = 24, double iconSize = 24}) {
  final exists = _photoExists(photoPath);
  final isUrl = photoPath != null && (photoPath.startsWith('http://') || photoPath.startsWith('https://'));
  
  return ClipRRect(
    borderRadius: BorderRadius.circular(radius / 2 + 4),
    child: Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(radius / 2 + 4),
      ),
      child: exists
          ? (isUrl
              ? CachedNetworkImage(
                  imageUrl: photoPath!,
                  width: radius * 2,
                  height: radius * 2,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: radius * 2,
                    height: radius * 2,
                    color: AppColors.primary.withOpacity(0.1),
                    child: Center(
                      child: SizedBox(
                        width: iconSize * 0.5,
                        height: iconSize * 0.5,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: radius * 2,
                    height: radius * 2,
                    color: AppColors.primary.withOpacity(0.1),
                    child: Icon(Icons.pets_rounded, color: AppColors.primary, size: iconSize),
                  ),
                )
              : Image.file(
                  File(photoPath!),
                  width: radius * 2,
                  height: radius * 2,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: radius * 2,
                    height: radius * 2,
                    color: AppColors.primary.withOpacity(0.1),
                    child: Icon(Icons.pets_rounded, color: AppColors.primary, size: iconSize),
                  ),
                ))
          : Icon(Icons.pets_rounded, color: AppColors.primary, size: iconSize),
    ),
  );
}

// Her bir etkinlik occurence'ı temsil eder
class EventItem {
  final dynamic reminder;
  final dynamic cat;
  final DateTime date;
  final bool isCompleted;
  final String status; // 'overdue', 'pending', 'completed'

  EventItem({
    required this.reminder,
    required this.cat,
    required this.date,
    required this.isCompleted,
    required this.status,
  });

  String get uniqueKey => '${reminder.id}_${date.toIso8601String().split('T')[0]}';
}

// Gruplanmış etkinlikler
class EventGroup {
  final dynamic reminder;
  final dynamic cat;
  final List<EventItem> items;
  final String status; // 'overdue', 'today', 'pending', 'completed'
  
  EventGroup({required this.reminder, required this.cat, required this.items, required this.status});
  
  String get groupKey => '${reminder.id}_$status'; // Status'ü de ekle ki farklı listelerde aynı reminder farklı gruplar olsun
  
  EventItem get firstItem => items.first;
  
  int get count => items.length;
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  String? _globalTypeFilter;
  final Set<String> _expandedGroups = {}; // Açık olan gruplar
  Set<String> _selectedCatIds = {}; // Seçilen kediler (boş = tümü)
  // Her liste için ayrı tarih aralığı (gün cinsinden)
  int _overdueRangeDays = 9999; // Geçmiş için tüm tarihler (filtre yok)
  int _pendingRangeDays = 30; // Yaklaşan için varsayılan: 30 gün
  int _completedRangeDays = 1; // Tamamlananlar için varsayılan: 1 gün

  @override
  void initState() {
    super.initState();
    // Diğer verileri yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllData();
    });
  }

  Future<void> _loadAllData() async {
    try {
      // Cats ve reminders'ı yükle (cloud sync dahil)
      await ref.read(catsProvider.notifier).loadCats();
      await ref.read(remindersProvider.notifier).loadReminders();
      // Completions'ı refresh et (merkezi provider'dan)
      await ref.read(completionsProvider.notifier).refresh();
    } catch (e, stackTrace) {
      debugPrint('HomeScreen: _loadAllData error: $e');
      debugPrint('HomeScreen: _loadAllData stackTrace: $stackTrace');
    }
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

  // Bir reminder için tüm occurence'ları oluştur (belirli tarih aralığında)
  // completedDates parametresi ile güncel completions'ı al
  List<EventItem> _generateOccurrences(dynamic reminder, dynamic cat, DateTime rangeStart, DateTime rangeEnd, Set<String> completedDates) {
    final items = <EventItem>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    if (reminder.frequency == 'once') {
      // Tek seferlik - sadece createdAt tarihinde
      final date = DateTime(reminder.createdAt.year, reminder.createdAt.month, reminder.createdAt.day);
      if (date.isAfter(rangeStart.subtract(const Duration(days: 1))) && date.isBefore(rangeEnd.add(const Duration(days: 1)))) {
        final key = '${reminder.id}_${date.toIso8601String().split('T')[0]}';
        final isCompleted = completedDates.contains(key) || reminder.isCompleted;
        String status;
        if (isCompleted) {
          status = 'completed';
        } else if (date.isBefore(today)) {
          status = 'overdue';
        } else {
          status = 'pending';
        }
        items.add(EventItem(reminder: reminder, cat: cat, date: date, isCompleted: isCompleted, status: status));
      }
    } else {
      // Tekrarlayan - tüm occurence'ları oluştur
      DateTime current = DateTime(reminder.createdAt.year, reminder.createdAt.month, reminder.createdAt.day);
      
      // Range başlangıcına kadar ilerle
      while (current.isBefore(rangeStart)) {
        final next = _calculateNextDate(current, reminder.frequency);
        if (next == null) break;
        current = next;
      }
      
      // Range içindeki tüm tarihleri ekle
      while (current.isBefore(rangeEnd.add(const Duration(days: 1)))) {
        final key = '${reminder.id}_${current.toIso8601String().split('T')[0]}';
        final isCompleted = completedDates.contains(key);
        String status;
        if (isCompleted) {
          status = 'completed';
        } else if (current.isBefore(today)) {
          status = 'overdue';
        } else {
          status = 'pending';
        }
        
        items.add(EventItem(reminder: reminder, cat: cat, date: current, isCompleted: isCompleted, status: status));
        
        final next = _calculateNextDate(current, reminder.frequency);
        if (next == null) break;
        current = next;
      }
    }
    
    return items;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [_buildHomePage(), _buildCatsPage()],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _currentIndex = 0),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: _currentIndex == 0 ? AppColors.primary : (isDark ? AppColors.surfaceDark : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.home_rounded, color: _currentIndex == 0 ? Colors.white : AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.get('home'), style: TextStyle(color: _currentIndex == 0 ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _currentIndex = 1),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: _currentIndex == 1 ? AppColors.primary : (isDark ? AppColors.surfaceDark : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.pets, color: _currentIndex == 1 ? Colors.white : AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.get('my_cats'), style: TextStyle(color: _currentIndex == 1 ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomePage() {
    final cats = ref.watch(catsProvider);
    final reminders = ref.watch(remindersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Güncel completions'ı kullan
    final completionsState = ref.watch(completionsProvider);
    final currentCompletedDates = completionsState.completedDates;
    final currentCompletionTimes = completionsState.completionTimes;
    
    // Genel üretim için geniş tarih aralığı:
    // - geçmiş ve tamamlananlar için geçmişe doğru en büyük aralık
    // - yaklaşanlar için geleceğe doğru aralık
    final maxPastDays = _overdueRangeDays > _completedRangeDays ? _overdueRangeDays : _completedRangeDays;
    final rangeStart = today.subtract(Duration(days: maxPastDays));
    final rangeEnd = today.add(Duration(days: _pendingRangeDays));

    // Tüm etkinlikleri oluştur ve grupla
    final Map<String, List<EventItem>> overdueMap = {};
    final Map<String, List<EventItem>> todayMap = {};
    final Map<String, List<EventItem>> pendingMap = {};
    final Map<String, List<EventItem>> completedMap = {};

    for (final reminder in reminders) {
      // Tip filtresi
      if (_globalTypeFilter != null && reminder.type != _globalTypeFilter) continue;
      
      final cat = cats.firstWhere((c) => c.id == reminder.catId, orElse: () => null as dynamic);
      if (cat == null) continue;

      // Kedi filtresi
      if (_selectedCatIds.isNotEmpty && !_selectedCatIds.contains(cat.id)) continue;

      final occurrences = _generateOccurrences(reminder, cat, rangeStart, rangeEnd, currentCompletedDates);
      final reminderKey = reminder.id;
      
      for (final item in occurrences) {
        switch (item.status) {
          case 'overdue':
            // Yalnızca seçilen gecikmiş aralığı içindekiler
            if (today.difference(item.date).inDays <= _overdueRangeDays) {
              if (!overdueMap.containsKey(reminderKey)) {
                overdueMap[reminderKey] = [];
              }
              overdueMap[reminderKey]!.add(item);
            }
            break;
          case 'pending':
            // Bugün olanları ayrı tut (sadece bugün 00:00'a kadar)
            final daysDiff = item.date.difference(today).inDays;
            if (daysDiff == 0) {
              // Sadece bugün olanlar
              if (!todayMap.containsKey(reminderKey)) {
                todayMap[reminderKey] = [];
              }
              todayMap[reminderKey]!.add(item);
            } else if (daysDiff > 0) {
              // Yaklaşanlar için reminder'a göre grupla
              if (!pendingMap.containsKey(reminderKey)) {
                pendingMap[reminderKey] = [];
              }
              // Yalnızca seçilen yaklaşan aralığı içindekiler
              if (daysDiff <= _pendingRangeDays) {
                pendingMap[reminderKey]!.add(item);
              }
            }
            break;
          case 'completed':
            // Son 24 saat içinde tamamlananlar
            if (item.isCompleted) {
              final completionKey = '${reminder.id}_${item.date.toIso8601String().split('T')[0]}';
              final completionTime = currentCompletionTimes[completionKey];
              
              if (completionTime != null) {
                final now = DateTime.now();
                final hoursSinceCompletion = now.difference(completionTime).inHours;
                
                // Son 24 saat içinde tamamlanmış olanlar
                if (hoursSinceCompletion >= 0 && hoursSinceCompletion <= 24) {
                  if (!completedMap.containsKey(reminderKey)) {
                    completedMap[reminderKey] = [];
                  }
                  completedMap[reminderKey]!.add(item);
                }
              } else {
                // Completion time bulunamadıysa, completion key'e bak
                // Eğer completion key varsa ve bugün tamamlandıysa göster
                if (currentCompletedDates.contains(completionKey)) {
                  final daysSince = today.difference(item.date).inDays;
                  if (daysSince <= 1) {
                    if (!completedMap.containsKey(reminderKey)) {
                      completedMap[reminderKey] = [];
                    }
                    completedMap[reminderKey]!.add(item);
                  }
                }
              }
            }
            break;
        }
      }
    }

    // Grupları oluştur ve sırala
    final allOverdueGroups = overdueMap.entries.map((e) {
      final reminder = reminders.firstWhere((r) => r.id == e.key);
      final cat = cats.firstWhere((c) => c.id == reminder.catId);
      e.value.sort((a, b) => b.date.compareTo(a.date));
      return EventGroup(reminder: reminder, cat: cat, items: e.value, status: 'overdue');
    }).toList();
    allOverdueGroups.sort((a, b) => b.firstItem.date.compareTo(a.firstItem.date));

    final allTodayGroups = todayMap.entries.map((e) {
      final reminder = reminders.firstWhere((r) => r.id == e.key);
      final cat = cats.firstWhere((c) => c.id == reminder.catId);
      e.value.sort((a, b) => a.reminder.time.compareTo(b.reminder.time));
      return EventGroup(reminder: reminder, cat: cat, items: e.value, status: 'today');
    }).toList();
    allTodayGroups.sort((a, b) => a.firstItem.reminder.time.compareTo(b.firstItem.reminder.time));

    final allPendingGroups = pendingMap.entries.map((e) {
      final reminder = reminders.firstWhere((r) => r.id == e.key);
      final cat = cats.firstWhere((c) => c.id == reminder.catId);
      e.value.sort((a, b) => a.date.compareTo(b.date));
      return EventGroup(reminder: reminder, cat: cat, items: e.value, status: 'pending');
    }).toList();
    allPendingGroups.sort((a, b) => a.firstItem.date.compareTo(b.firstItem.date));

    final allCompletedGroups = completedMap.entries.map((e) {
      final reminder = reminders.firstWhere((r) => r.id == e.key);
      final cat = cats.firstWhere((c) => c.id == reminder.catId);
      e.value.sort((a, b) => b.date.compareTo(a.date));
      return EventGroup(reminder: reminder, cat: cat, items: e.value, status: 'completed');
    }).toList();
    allCompletedGroups.sort((a, b) => b.firstItem.date.compareTo(a.firstItem.date));

    return RefreshIndicator(
      onRefresh: () async {
        await _loadAllData();
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverAppBar(
            floating: true,
            centerTitle: false,
            title: const Text('PetCare', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_month_rounded),
              tooltip: AppLocalizations.get('calendar'),
              onPressed: () => Navigator.push(
                context,
                PageTransitions.slide(page: const CalendarScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.push(
                context,
                PageTransitions.slide(page: const SettingsScreen()),
              ),
            ),
          ],
        ),
        
        // Quick Actions - dotcat dahil
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.get('add_new_record'),
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // dotcat ürünleri kutusu (logo + "Ürünleri")
                    _buildDotcatProductsAction(),
                  const SizedBox(width: 6),
                    _buildQuickAction(
                      icon: Icons.vaccines,
                      label: AppLocalizations.get('vaccine'),
                      color: AppColors.vaccine,
                      onTap: () => _goToAddRecord('vaccine'),
                    ),
                  const SizedBox(width: 6),
                    _buildQuickAction(
                      icon: Icons.medication,
                      label: AppLocalizations.get('medicine'),
                      color: AppColors.medicine,
                      onTap: () => _goToAddRecord('medicine'),
                    ),
                  const SizedBox(width: 6),
                    _buildQuickAction(
                      icon: Icons.local_hospital,
                      label: AppLocalizations.get('vet'),
                      color: AppColors.vet,
                      onTap: () => _goToAddRecord('vet'),
                    ),
                  const SizedBox(width: 6),
                    _buildQuickAction(
                      icon: Icons.restaurant,
                      label: AppLocalizations.get('food'),
                      color: AppColors.food,
                      onTap: () => _goToAddRecord('food'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        // Kedi filtresi
        if (cats.length > 1)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _buildCatFilterChip(null, AppLocalizations.get('all_cats'), null),
                  const SizedBox(width: 6),
                  ...cats.map((cat) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _buildCatFilterChip(cat.id, cat.name, cat.photoPath),
                  )),
                ]),
              ),
            ),
          ),
        
        // Tip filtresi (yalnızca türler)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      _buildFilterChip(null, AppLocalizations.get('all'), Icons.list),
                      const SizedBox(width: 6),
                      _buildFilterChip('dotcat_complete', 'dotcat', Icons.pets),
                      const SizedBox(width: 6),
                      _buildFilterChip('vaccine', AppLocalizations.get('vaccine'), Icons.vaccines),
                      const SizedBox(width: 6),
                      _buildFilterChip('medicine', AppLocalizations.get('medicine'), Icons.medication),
                      const SizedBox(width: 6),
                      _buildFilterChip('vet', AppLocalizations.get('vet'), Icons.local_hospital),
                      const SizedBox(width: 6),
                      _buildFilterChip('food', AppLocalizations.get('food'), Icons.restaurant),
                    ]),
            ),
          ),
        ),
        
        // Swipe hint
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(children: [
              Icon(Icons.swipe, size: 14, color: context.textSecondary),
              const SizedBox(width: 4),
              Text(AppLocalizations.get('swipe_hint'), style: TextStyle(fontSize: 11, color: context.textSecondary)),
            ]),
          ),
        ),
        
        // SÜRESİ GEÇENLER
        if (allOverdueGroups.isNotEmpty) ...[
          SliverToBoxAdapter(child: _buildSectionHeader(Icons.warning_amber_rounded, AppLocalizations.get('overdue_events'), allOverdueGroups.fold<int>(0, (sum, g) => sum + g.count), AppColors.error)),
          SliverList(delegate: SliverChildBuilderDelegate((context, index) {
            final group = allOverdueGroups[index];
            // Tek item varsa direkt normal card göster
            if (group.count == 1) {
              return _buildEventCard(group.firstItem, isDark);
            }
            return _buildEventGroupCard(group, isDark);
          }, childCount: allOverdueGroups.length)),
        ],

        // BUGÜN (24 saat içindeki etkinlikler)
        if (allTodayGroups.isNotEmpty) ...[
          SliverToBoxAdapter(child: _buildSectionHeader(Icons.today_rounded, AppLocalizations.get('today'), allTodayGroups.fold<int>(0, (sum, g) => sum + g.count), AppColors.primary)),
          SliverList(delegate: SliverChildBuilderDelegate((context, index) {
            final group = allTodayGroups[index];
            // Tek item varsa direkt normal card göster
            if (group.count == 1) {
              return _buildEventCard(group.firstItem, isDark);
            }
            return _buildEventGroupCard(group, isDark);
          }, childCount: allTodayGroups.length)),
        ],

        // YAKLAŞAN ETKİNLİKLER
        SliverToBoxAdapter(child: _buildSectionHeader(Icons.schedule, AppLocalizations.get('upcoming_events'), allPendingGroups.fold<int>(0, (sum, g) => sum + g.count), AppColors.warning)),
        // Yaklaşanlar için süre filtresi
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: _buildRangeSelectorChip(
                days: _pendingRangeDays,
                isDark: isDark,
                onTap: () => _showRangePicker(
                  currentDays: _pendingRangeDays,
                  onSelected: (value) => setState(() => _pendingRangeDays = value),
                ),
              ),
            ),
          ),
        ),
        if (allPendingGroups.isEmpty)
          SliverToBoxAdapter(child: _buildEmptyState(cats.isEmpty ? AppLocalizations.get('add_your_first_cat') : AppLocalizations.get('no_pending'), isDark))
        else
          SliverList(delegate: SliverChildBuilderDelegate((context, index) {
            final group = allPendingGroups[index];
            // Tek item varsa direkt normal card göster
            if (group.count == 1) {
              return _buildEventCard(group.firstItem, isDark);
            }
            return _buildEventGroupCard(group, isDark);
          }, childCount: allPendingGroups.length)),

        // TAMAMLANANLAR (Son 24 saat içinde tamamlananlar)
        SliverToBoxAdapter(child: _buildSectionHeader(Icons.check_circle, AppLocalizations.get('completed_events'), allCompletedGroups.fold<int>(0, (sum, g) => sum + g.count), AppColors.success)),
        if (allCompletedGroups.isEmpty)
          SliverToBoxAdapter(child: _buildEmptyState(AppLocalizations.get('no_completed'), isDark))
        else
          SliverList(delegate: SliverChildBuilderDelegate((context, index) {
            final group = allCompletedGroups[index];
            // Tek item varsa direkt normal card göster
            if (group.count == 1) {
              return _buildEventCard(group.firstItem, isDark);
            }
            return _buildEventGroupCard(group, isDark);
          }, childCount: allCompletedGroups.length)),
        
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  // Ortak tarih aralığı seçici chip'i
  Widget _buildRangeSelectorChip({
    required int days,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
          const Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
            Text(
              '$days ${AppLocalizations.get('days')}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  // Belirli bir liste için süre seçici bottom sheet
  void _showRangePicker({
    required int currentDays,
    required ValueChanged<int> onSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 16),
            Text(
              AppLocalizations.get('select_range'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          const SizedBox(height: 16),
            ...[7, 14, 30, 60, 90].map(
              (days) => ListTile(
            title: Text('$days ${AppLocalizations.get('days')}'),
                trailing: currentDays == days
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
            onTap: () {
                  onSelected(days);
              Navigator.pop(ctx);
            },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCatFilterChip(String? catId, String label, String? photoPath) {
    final isSelected = catId == null ? _selectedCatIds.isEmpty : _selectedCatIds.contains(catId);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (catId == null) {
            _selectedCatIds.clear();
          } else {
            if (_selectedCatIds.contains(catId)) {
              _selectedCatIds.remove(catId);
            } else {
              _selectedCatIds.add(catId);
            }
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade300),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (catId != null) ...[
            _buildCatPhoto(photoPath, radius: 10, iconSize: 10),
            const SizedBox(width: 6),
          ] else ...[
            Icon(Icons.select_all, size: 14, color: isSelected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(fontSize: 12, color: isSelected ? AppColors.primary : AppColors.textSecondary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
        ]),
      ),
    );
  }

  Widget _buildFilterChip(String? type, String label, IconData icon) {
    final isSelected = _globalTypeFilter == type;
    Color chipColor = AppColors.primary;
    if (type == 'dotcat_complete') chipColor = AppColors.dotcat;
    else if (type == 'vaccine') chipColor = AppColors.vaccine;
    else if (type == 'medicine') chipColor = AppColors.medicine;
    else if (type == 'vet') chipColor = AppColors.vet;
    else if (type == 'food') chipColor = AppColors.food;
    else if (type == 'weight') chipColor = AppColors.warning;
    
    return AppChip(
      label: label,
      icon: icon,
      isSelected: isSelected,
      color: chipColor,
      onTap: () => setState(() => _globalTypeFilter = type),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
      child: Row(children: [
        Icon(icon, color: color, size: AppSpacing.iconSm),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: icon == Icons.warning_amber_rounded ? color : null,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        AppBadge(
          text: '$count',
          color: color,
        ),
      ]),
    );
  }

  Widget _buildEmptyState(String message, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: isDark ? AppColors.surfaceDark : Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Center(child: Text(message, style: TextStyle(color: context.textSecondary, fontSize: 13), textAlign: TextAlign.center)),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: isDark ? color.withOpacity(0.15) : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Ana sayfada dotcat ürünleri için kare kutu (logo + "Ürünleri")
  Widget _buildDotcatProductsAction() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: () => _goToAddRecord('dotcat_complete'),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: isDark ? AppColors.dotcat.withOpacity(0.15) : AppColors.dotcat.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 22,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                AppLocalizations.get('products'),
                style: TextStyle(
                  fontSize: 9,
                  color: AppColors.dotcat,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventGroupCard(EventGroup group, bool isDark) {
    final isExpanded = _expandedGroups.contains(group.groupKey);
    final firstItem = group.firstItem;
    final reminder = group.reminder;
    final cat = group.cat;
    final status = group.status;
    
    Color typeColor;
    IconData icon;
    switch (reminder.type) {
      case 'vaccine': typeColor = AppColors.vaccine; icon = Icons.vaccines; break;
      case 'medicine': typeColor = AppColors.medicine; icon = Icons.medication; break;
      case 'vet': typeColor = AppColors.vet; icon = Icons.local_hospital; break;
      case 'food': typeColor = AppColors.food; icon = Icons.restaurant; break;
      case 'dotcat_complete': typeColor = AppColors.dotcat; icon = Icons.pets; break;
      case 'weight': typeColor = AppColors.warning; icon = Icons.monitor_weight; break;
      default: typeColor = AppColors.primary; icon = Icons.event;
    }

    Color borderColor;
    switch (status) {
      case 'overdue': borderColor = AppColors.error; break;
      case 'today': borderColor = AppColors.primary; break;
      case 'pending': borderColor = AppColors.warning; break;
      case 'completed': borderColor = AppColors.success; break;
      default: borderColor = Colors.grey.shade300;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDate = DateTime(firstItem.date.year, firstItem.date.month, firstItem.date.day);
    final daysUntil = firstDate.difference(today).inDays;
    
    String dateLabel;
    if (status == 'completed') {
      dateLabel = DateHelper.formatShortDate(firstItem.date);
    } else if (status == 'overdue') {
      final overdueDays = today.difference(firstDate).inDays;
      dateLabel = overdueDays == 0 ? AppLocalizations.get('today') : '$overdueDays ${AppLocalizations.get('days_ago')}';
    } else if (daysUntil == 0) {
      dateLabel = AppLocalizations.get('today');
    } else if (daysUntil == 1) {
      dateLabel = AppLocalizations.get('tomorrow');
    } else {
      dateLabel = DateHelper.formatShortDate(firstItem.date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Dismissible(
        key: Key('${group.groupKey}_dismissible'),
        direction: firstItem.isCompleted ? DismissDirection.endToStart : DismissDirection.startToEnd,
        background: Container(
          decoration: BoxDecoration(
            color: firstItem.isCompleted ? AppColors.warning : AppColors.success,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: firstItem.isCompleted ? Alignment.centerRight : Alignment.centerLeft,
          padding: EdgeInsets.only(left: firstItem.isCompleted ? 0 : 20, right: firstItem.isCompleted ? 20 : 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: firstItem.isCompleted
              ? [Text(AppLocalizations.get('mark_pending'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), const SizedBox(width: 8), const Icon(Icons.undo, color: Colors.white)]
              : [const Icon(Icons.check, color: Colors.white), const SizedBox(width: 8), Text(AppLocalizations.get('mark_completed'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))],
          ),
        ),
        confirmDismiss: (direction) async {
          // En yakın tarihteki item'ı bul ve tamamla
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          
          // Tamamlanmamış ve en yakın tarihli item'ı bul
          EventItem? targetItem;
          if (firstItem.isCompleted) {
            // Geri almak için en son tamamlananı bul
            final completedItems = group.items.where((i) => i.isCompleted).toList();
            if (completedItems.isEmpty) return false;
            completedItems.sort((a, b) => b.date.compareTo(a.date));
            targetItem = completedItems.first;
          } else {
            // Tamamlamak için en yakın tarihli tamamlanmamış item'ı bul
            final incompleteItems = group.items.where((i) => !i.isCompleted).toList();
            if (incompleteItems.isEmpty) return false;
            
            incompleteItems.sort((a, b) {
              final aDiff = (a.date.difference(today)).abs().inDays;
              final bDiff = (b.date.difference(today)).abs().inDays;
              return aDiff.compareTo(bDiff);
            });
            targetItem = incompleteItems.first;
          }
          
          if (targetItem != null) {
            await _toggleCompletion(targetItem);
            // Animasyon için state güncelle
            setState(() {});
          }
          return false;
        },
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Column(
            children: [
              // Ana kart (tıklanabilir)
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedGroups.remove(group.groupKey);
                    } else {
                      _expandedGroups.add(group.groupKey);
                    }
                  });
                },
                child: Container(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  _buildCatPhoto(cat.photoPath, radius: 22, iconSize: 20),
                  const SizedBox(width: 12),
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: (firstItem.isCompleted ? AppColors.success : typeColor).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: firstItem.isCompleted 
                      ? const Icon(Icons.check_circle, color: AppColors.success, size: 18)
                      : Icon(icon, color: typeColor, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(reminder.title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, decoration: firstItem.isCompleted ? TextDecoration.lineThrough : null, color: firstItem.isCompleted ? context.textSecondary : null)),
                      const SizedBox(height: 2),
                      Row(children: [
                        Text(cat.name, style: TextStyle(fontSize: 12, color: context.textSecondary)),
                        if (group.count > 1) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: typeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                            child: Text('${group.count} ${AppLocalizations.get('items')}', style: TextStyle(fontSize: 10, color: typeColor, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ]),
                    ]),
                  ),
                  Column(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: borderColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Column(children: [
                        Text(dateLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: borderColor)),
                        if (status != 'completed') Text(reminder.time, style: TextStyle(fontSize: 10, color: borderColor.withOpacity(0.8))),
                      ]),
                    ),
                    if (status == 'overdue') ...[
                      const SizedBox(height: 4),
                      const Icon(Icons.warning, color: AppColors.error, size: 16),
                    ],
                  ]),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: context.textSecondary,
                    size: 20,
                  ),
                ]),
              ),
            ),
            // Expandable detaylar
            if (isExpanded) ...[
              const Divider(height: 1),
              ...group.items.map((item) {
                final itemDate = DateTime(item.date.year, item.date.month, item.date.day);
                final itemDaysUntil = itemDate.difference(today).inDays;
                
                String itemDateLabel;
                if (item.isCompleted) {
                  itemDateLabel = DateHelper.formatShortDate(item.date);
                } else if (status == 'overdue') {
                  final overdueDays = today.difference(itemDate).inDays;
                  itemDateLabel = overdueDays == 0 ? AppLocalizations.get('today') : '$overdueDays ${AppLocalizations.get('days_ago')}';
                } else if (itemDaysUntil == 0) {
                  itemDateLabel = AppLocalizations.get('today');
                } else if (itemDaysUntil == 1) {
                  itemDateLabel = AppLocalizations.get('tomorrow');
                } else {
                  itemDateLabel = DateHelper.formatShortDate(item.date);
                }
                
                return Dismissible(
                  key: Key(item.uniqueKey),
                  direction: item.isCompleted ? DismissDirection.endToStart : DismissDirection.startToEnd,
                  background: Container(
                    decoration: BoxDecoration(color: item.isCompleted ? AppColors.warning : AppColors.success, borderRadius: BorderRadius.circular(12)),
                    alignment: item.isCompleted ? Alignment.centerRight : Alignment.centerLeft,
                    padding: EdgeInsets.only(left: item.isCompleted ? 0 : 20, right: item.isCompleted ? 20 : 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: item.isCompleted
                        ? [Text(AppLocalizations.get('mark_pending'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), const SizedBox(width: 8), const Icon(Icons.undo, color: Colors.white)]
                        : [const Icon(Icons.check, color: Colors.white), const SizedBox(width: 8), Text(AppLocalizations.get('mark_completed'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))],
                    ),
                  ),
                  confirmDismiss: (direction) async {
                    await _toggleCompletion(item);
                    return false;
                  },
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        PageTransitions.slide(
                          page: RecordDetailScreen(
                            record: reminder,
                            catName: cat.name,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: (item.isCompleted ? AppColors.success : borderColor).withOpacity(0.05),
                        border: Border(
                          left: BorderSide(color: item.isCompleted ? AppColors.success : borderColor, width: 3),
                        ),
                      ),
                      child: Row(children: [
                        Icon(
                          item.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                          color: item.isCompleted ? AppColors.success : borderColor,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(reminder.title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, decoration: item.isCompleted ? TextDecoration.lineThrough : null, color: item.isCompleted ? context.textSecondary : null)),
                            const SizedBox(height: 2),
                            Text(itemDateLabel, style: TextStyle(fontSize: 11, color: context.textSecondary)),
                          ]),
                        ),
                        Text(reminder.time, style: TextStyle(fontSize: 12, color: borderColor, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildEventCard(EventItem item, bool isDark) {
    final reminder = item.reminder;
    final cat = item.cat;
    final date = item.date;
    final status = item.status;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDate = DateTime(date.year, date.month, date.day);
    final daysUntil = eventDate.difference(today).inDays;
    
    Color typeColor;
    IconData icon;
    switch (reminder.type) {
      case 'vaccine': typeColor = AppColors.vaccine; icon = Icons.vaccines; break;
      case 'medicine': typeColor = AppColors.medicine; icon = Icons.medication; break;
      case 'vet': typeColor = AppColors.vet; icon = Icons.local_hospital; break;
      case 'food': typeColor = AppColors.food; icon = Icons.restaurant; break;
      case 'dotcat_complete': typeColor = AppColors.dotcat; icon = Icons.pets; break;
      case 'weight': typeColor = AppColors.warning; icon = Icons.monitor_weight; break;
      default: typeColor = AppColors.primary; icon = Icons.event;
    }

    Color borderColor;
    switch (status) {
      case 'overdue': borderColor = AppColors.error; break;
      case 'pending': borderColor = AppColors.warning; break;
      case 'completed': borderColor = AppColors.success; break;
      default: borderColor = Colors.grey.shade300;
    }

    String dateLabel;
    if (status == 'completed') {
      dateLabel = DateHelper.formatShortDate(date);
    } else if (status == 'overdue') {
      final overdueDays = today.difference(eventDate).inDays;
      dateLabel = overdueDays == 0 ? AppLocalizations.get('today') : '$overdueDays ${AppLocalizations.get('days_ago')}';
    } else if (daysUntil == 0) {
      dateLabel = AppLocalizations.get('today');
    } else if (daysUntil == 1) {
      dateLabel = AppLocalizations.get('tomorrow');
    } else {
      dateLabel = DateHelper.formatShortDate(date);
    }

    return Dismissible(
      key: Key(item.uniqueKey),
      direction: status == 'completed' ? DismissDirection.endToStart : DismissDirection.startToEnd,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(color: status == 'completed' ? AppColors.warning : AppColors.success, borderRadius: BorderRadius.circular(12)),
        alignment: status == 'completed' ? Alignment.centerRight : Alignment.centerLeft,
        padding: EdgeInsets.only(left: status == 'completed' ? 0 : 20, right: status == 'completed' ? 20 : 0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: status == 'completed'
            ? [Text(AppLocalizations.get('mark_pending'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), const SizedBox(width: 8), const Icon(Icons.undo, color: Colors.white)]
            : [const Icon(Icons.check, color: Colors.white), const SizedBox(width: 8), Text(AppLocalizations.get('mark_completed'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))],
        ),
      ),
      confirmDismiss: (direction) async {
        await _toggleCompletion(item);
        return false;
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: GestureDetector(
          onTap: () {
            // Önce kayıt detayı sayfasına git (takvimdeki gibi)
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RecordDetailScreen(
                  record: reminder,
                  catName: cat.name,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Row(children: [
              _buildCatPhoto(cat.photoPath, radius: 22, iconSize: 20),
              const SizedBox(width: 12),
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: (status == 'completed' ? AppColors.success : typeColor).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: status == 'completed' 
                  ? const Icon(Icons.check_circle, color: AppColors.success, size: 18)
                  : Icon(icon, color: typeColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(reminder.title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, decoration: status == 'completed' ? TextDecoration.lineThrough : null, color: status == 'completed' ? context.textSecondary : null)),
                  const SizedBox(height: 2),
                  Text(cat.name, style: TextStyle(fontSize: 12, color: context.textSecondary)),
                ]),
              ),
              Column(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: borderColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Column(children: [
                    Text(dateLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: borderColor)),
                    if (status != 'completed') Text(reminder.time, style: TextStyle(fontSize: 10, color: borderColor.withOpacity(0.8))),
                  ]),
                ),
                if (status == 'overdue') ...[
                  const SizedBox(height: 4),
                  const Icon(Icons.warning, color: AppColors.error, size: 16),
                ],
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleCompletion(EventItem item) async {
    try {
      final wasCompleted = item.isCompleted;
      final completionId = '${item.reminder.id}_${item.date.toIso8601String().split('T')[0]}';
      
      if (wasCompleted) {
        // Tamamlanandan geri al
        await ref.read(completionsProvider.notifier).deleteCompletion(
          completionId,
          item.reminder.id,
          item.date,
        );
      } else {
        // Tamamlandı olarak işaretle
        final completion = ReminderCompletion(
          id: completionId,
          reminderId: item.reminder.id,
          completedDate: item.date,
          completedAt: DateTime.now(),
        );
        await ref.read(completionsProvider.notifier).saveCompletion(completion);
      }
    
      if (mounted) {
        final isNowCompleted = !wasCompleted;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            Icon(isNowCompleted ? Icons.check_circle : Icons.undo, color: Colors.white, size: 20), 
            const SizedBox(width: 10), 
            Text(isNowCompleted ? AppLocalizations.get('marked_completed') : AppLocalizations.get('marked_pending'))
          ]),
          backgroundColor: isNowCompleted ? AppColors.success : AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e, stackTrace) {
      debugPrint('HomeScreen: _toggleCompletion error: $e');
      debugPrint('HomeScreen: stackTrace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _goToAddRecord(String type) async {
    final cats = ref.read(catsProvider);
    if (cats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.get('add_cat_first')),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: AppLocalizations.get('add'),
          textColor: Colors.white,
          onPressed: () => Navigator.push(
            context,
            PageTransitions.fadeSlide(page: const AddCatScreen()),
          ),
        ),
      ));
      return;
    }
    
    // Bildirim izni kontrolü
    final hasPermission = await NotificationService.instance.requestPermission();
    if (!hasPermission) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.notifications_off, color: AppColors.warning),
                const SizedBox(width: 12),
                Expanded(child: Text(AppLocalizations.get('notification_permission_required'))),
              ],
            ),
            content: Text(AppLocalizations.get('notification_permission_desc'), style: const TextStyle(height: 1.5)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.get('cancel')),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final granted = await NotificationService.instance.requestPermission();
                  if (granted && mounted) {
                    Navigator.push(
                      context,
                      PageTransitions.fadeSlide(page: AddReminderScreen(initialType: type)),
                    );
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(AppLocalizations.get('notification_permission_required')),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: Text(AppLocalizations.get('enable_notifications'), style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
      return;
    }
    
    Navigator.push(
      context,
      PageTransitions.fadeSlide(page: AddReminderScreen(initialType: type)),
    );
  }

  Widget _buildCatsPage() {
    final cats = ref.watch(catsProvider);
    final reminders = ref.watch(remindersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          centerTitle: false,
          title: Text(AppLocalizations.get('my_cats'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
          actions: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.add, color: AppColors.primary),
              ),
              onPressed: () => Navigator.push(
                context,
                PageTransitions.fadeSlide(page: const AddCatScreen()),
              ),
            ),
          ],
        ),
        if (cats.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.pets_rounded, size: 50, color: AppColors.primary),
                  ),
                  const SizedBox(height: 24),
                  Text(AppLocalizations.get('no_cats'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(AppLocalizations.get('add_your_first_cat'), style: TextStyle(color: context.textSecondary, fontSize: 15), textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                context,
                PageTransitions.fadeSlide(page: const AddCatScreen()),
              ),
                      icon: const Icon(Icons.add),
                      label: Text(AppLocalizations.get('add_cat'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final cat = cats[index];
                final catReminders = reminders.where((r) => r.catId == cat.id).toList();
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                
                // Ana sayfadaki mantıkla aynı hesaplama yap
                // Completion durumlarını da hesaba kat
                final completionsState = ref.watch(completionsProvider);
                final currentCompletedDates = completionsState.completedDates;
                int overdueCount = 0;
                
                // Geçmiş 90 gün ve gelecek 90 gün aralığında kontrol et
                final rangeStart = today.subtract(const Duration(days: 90));
                final rangeEnd = today.add(const Duration(days: 90));
                
                for (final reminder in catReminders) {
                  // Ana sayfadaki _generateOccurrences mantığını kullan
                  final occurrences = _generateOccurrences(reminder, cat, rangeStart, rangeEnd, currentCompletedDates);
                  
                  for (final item in occurrences) {
                    // Sadece tamamlanmamış olanları say
                    if (item.isCompleted) continue;
                    
                    // Sadece gecikmiş olanları say (yaklaşan sayıları gösterme)
                    if (item.status == 'overdue') {
                      overdueCount++;
                    }
                  }
                }
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      PageTransitions.slide(page: CatDetailScreen(cat: cat)),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
                      ),
                      child: Row(children: [
                        _buildCatPhoto(cat.photoPath, radius: 32, iconSize: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            if (cat.breed != null && cat.breed!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(cat.breed!, style: TextStyle(fontSize: 13, color: context.textSecondary)),
                            ],
                            const SizedBox(height: 8),
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                child: Text(DateHelper.getAge(cat.birthDate), style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500)),
                              ),
                              if (overdueCount > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(Icons.warning, size: 12, color: AppColors.error),
                                    const SizedBox(width: 4),
                                    Text('$overdueCount ${AppLocalizations.get('overdue_events_count')}', style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w500)),
                                  ]),
                                ),
                              ],
                            ]),
                          ]),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.chevron_right, color: context.textSecondary),
                        ),
                      ]),
                    ),
                  ),
                );
              }, childCount: cats.length),
          ),
        ),
      ],
    );
  }
}
