import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/localization.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/utils/notification_service.dart';
import '../../../core/utils/page_transitions.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/services/widget_service.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/models/cat.dart';
import '../../../data/models/dog.dart';
import '../../../data/models/reminder_completion.dart';
import '../../cats/providers/cats_provider.dart';
import '../../dogs/providers/dogs_provider.dart';
import '../../reminders/providers/reminders_provider.dart';
import '../../reminders/providers/completions_provider.dart';
import '../../cats/presentation/cat_profile_screen.dart';
import '../../dogs/presentation/dog_profile_screen.dart';
import '../../cats/presentation/add_cat_screen.dart';
import '../../dogs/presentation/add_dog_screen.dart';
import '../../reminders/presentation/add_reminder_screen.dart';
import '../../reminders/presentation/record_detail_screen.dart';
import '../../insights/presentation/insights_screen.dart';
import '../../insights/providers/insights_provider.dart';
import '../../../core/services/insights_service.dart';
import '../../../core/services/insights_notification_service.dart';
import '../../../core/services/premium_service.dart';
import '../../premium/presentation/premium_screen.dart';
import '../../../data/models/pet_type.dart';
import '../../../core/constants/reminder_constants.dart';
import 'calendar_screen.dart';
import 'settings_screen.dart';

/// Veteriner masraf bilgisi için model
class VetExpenseInfo {
  final DateTime completionDate;
  final String? vetClinicName;
  final double? cost;
  final String? currency;
  final String? notes;

  VetExpenseInfo({
    required this.completionDate,
    this.vetClinicName,
    this.cost,
    this.currency,
    this.notes,
  });
}

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

  // Yakınlaşan etkinlikler için tür filtreleri (varsayılan: önemli türler - günlük hatırlatıcılar hariç)
  Set<String> _pendingTypeFilters = {'vet', 'vaccine', 'neutering', 'surgery', 'microchip', 'bloodTest', 'xray', 'ultrasound', 'allergyTest', 'eyeExam', 'emergency', 'petInsurance'};
  bool _pendingShowAllTypes = false; // Tüm türleri göster (filtre kapalı)

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

      // Check for reactivated insights and send notifications
      await ref.read(insightsActionsProvider).checkAndNotifyReactivatedInsights();

      // Widget'ı güncelle
      _updateHomeWidget();
    } catch (e, stackTrace) {
      debugPrint('HomeScreen: _loadAllData error: $e');
      debugPrint('HomeScreen: _loadAllData stackTrace: $stackTrace');
    }
  }
  
  /// Home Screen Widget'ını güncelle
  void _updateHomeWidget() {
    final reminders = ref.read(remindersProvider);
    final completions = ref.read(completionsProvider);
    
    // Completion key'leri oluştur (CompletionsState'ten al)
    final completedKeys = completions.completedDates;
    
    // Widget'ı güncelle
    WidgetService.instance.updateTodayTasks(
      reminders: reminders,
      completedKeys: completedKeys,
    );
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
      floatingActionButton: _currentIndex == 0
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: AppShadows.colored(AppColors.primary),
              ),
              child: FloatingActionButton(
                onPressed: _showQuickAddModal,
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
              ),
            ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                .scaleXY(end: 1.05, duration: 2000.ms, curve: Curves.easeInOut)
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.backgroundDark.withOpacity(0.95) : Colors.white.withOpacity(0.95),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _currentIndex = 0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: _currentIndex == 0
                            ? LinearGradient(
                                colors: [AppColors.primary, AppColors.primaryDark],
                              )
                            : null,
                        color: _currentIndex == 0 ? null : (isDark ? AppColors.surfaceDark.withOpacity(0.5) : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _currentIndex == 0 ? AppShadows.colored(AppColors.primary) : null,
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(
                          Icons.home_rounded,
                          color: _currentIndex == 0 ? Colors.white : AppColors.textSecondary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.get('home'),
                          style: AppTypography.bodyLarge.copyWith(
                            color: _currentIndex == 0 ? Colors.white : AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _currentIndex = 1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: _currentIndex == 1
                            ? LinearGradient(
                                colors: [AppColors.primary, AppColors.primaryDark],
                              )
                            : null,
                        color: _currentIndex == 1 ? null : (isDark ? AppColors.surfaceDark.withOpacity(0.5) : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _currentIndex == 1 ? AppShadows.colored(AppColors.primary) : null,
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(
                          Icons.pets,
                          color: _currentIndex == 1 ? Colors.white : AppColors.textSecondary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.get('my_pets'),
                          style: AppTypography.bodyLarge.copyWith(
                            color: _currentIndex == 1 ? Colors.white : AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomePage() {
    final cats = ref.watch(catsProvider);
    final dogs = ref.watch(dogsProvider);
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

      // Hem kedilerde hem köpeklerde ara
      final cat = cats.where((c) => c.id == reminder.catId).firstOrNull;
      final dog = dogs.where((d) => d.id == reminder.catId).firstOrNull;
      dynamic pet = cat ?? dog;
      if (pet == null) continue;

      // Pet filtresi
      final petId = pet is Cat ? pet.id : (pet as Dog).id;
      if (_selectedCatIds.isNotEmpty && !_selectedCatIds.contains(petId)) continue;

      final occurrences = _generateOccurrences(reminder, pet, rangeStart, rangeEnd, currentCompletedDates);
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
              // Tür filtresini uygula (showAllTypes=true ise filtre yok)
              final passesTypeFilter = _pendingShowAllTypes || _pendingTypeFilters.contains(reminder.type);
              if (!passesTypeFilter) break; // Tür filtresine uymuyorsa atla

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

    // Helper: Pet'i bul (kedi veya köpek)
    dynamic findPet(String petId) {
      final cat = cats.where((c) => c.id == petId).firstOrNull;
      final dog = dogs.where((d) => d.id == petId).firstOrNull;
      return cat ?? dog;
    }

    // Grupları oluştur ve sırala
    final allOverdueGroups = overdueMap.entries.map((e) {
      final reminder = reminders.firstWhere((r) => r.id == e.key);
      final pet = findPet(reminder.catId);
      e.value.sort((a, b) => b.date.compareTo(a.date));
      return EventGroup(reminder: reminder, cat: pet, items: e.value, status: 'overdue');
    }).toList();
    allOverdueGroups.sort((a, b) => b.firstItem.date.compareTo(a.firstItem.date));

    final allTodayGroups = todayMap.entries.map((e) {
      final reminder = reminders.firstWhere((r) => r.id == e.key);
      final pet = findPet(reminder.catId);
      e.value.sort((a, b) => a.reminder.time.compareTo(b.reminder.time));
      return EventGroup(reminder: reminder, cat: pet, items: e.value, status: 'today');
    }).toList();
    allTodayGroups.sort((a, b) => a.firstItem.reminder.time.compareTo(b.firstItem.reminder.time));

    final allPendingGroups = pendingMap.entries.map((e) {
      final reminder = reminders.firstWhere((r) => r.id == e.key);
      final pet = findPet(reminder.catId);
      e.value.sort((a, b) => a.date.compareTo(b.date));
      return EventGroup(reminder: reminder, cat: pet, items: e.value, status: 'pending');
    }).toList();
    allPendingGroups.sort((a, b) => a.firstItem.date.compareTo(b.firstItem.date));

    final allCompletedGroups = completedMap.entries.map((e) {
      final reminder = reminders.firstWhere((r) => r.id == e.key);
      final pet = findPet(reminder.catId);
      e.value.sort((a, b) => b.date.compareTo(a.date));
      return EventGroup(reminder: reminder, cat: pet, items: e.value, status: 'completed');
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
            snap: true,
            centerTitle: false,
            backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
            elevation: 0,
            title: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
              ).createShader(bounds),
              child: Text(
                'PetCare',
                style: AppTypography.displayMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark.withOpacity(0.5) : Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppShadows.small,
              ),
              child: IconButton(
                icon: const Icon(Icons.calendar_month_rounded, size: 22),
                tooltip: AppLocalizations.get('calendar'),
                onPressed: () => Navigator.push(
                  context,
                  PageTransitions.slide(page: const CalendarScreen()),
                ),
              ),
            ).animate().fadeIn(duration: 300.ms).scale(delay: 100.ms),
            // Insights button with badge
            Container(
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark.withOpacity(0.5) : Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppShadows.small,
              ),
              child: Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.lightbulb_outline_rounded, size: 22),
                    tooltip: AppLocalizations.get('insights'),
                    onPressed: () => Navigator.push(
                      context,
                      PageTransitions.slide(page: const InsightsScreen()),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Consumer(
                      builder: (context, ref, _) {
                        final countAsync = ref.watch(highPriorityInsightsCountProvider);
                        return countAsync.when(
                          data: (count) {
                            if (count == 0) return const SizedBox.shrink();
                            return Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppColors.error, AppColors.error.withOpacity(0.8)],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: AppShadows.colored(AppColors.error),
                              ),
                              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                              child: Text(
                                count.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ).animate(onPlay: (controller) => controller.repeat())
                            .shake(duration: 500.ms)
                            .then(delay: 3000.ms);
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms).scale(delay: 200.ms),
            Container(
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark.withOpacity(0.5) : Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppShadows.small,
              ),
              child: IconButton(
                icon: const Icon(Icons.settings_outlined, size: 22),
                onPressed: () => Navigator.push(
                  context,
                  PageTransitions.slide(page: const SettingsScreen()),
                ),
              ),
            ).animate().fadeIn(duration: 300.ms).scale(delay: 300.ms),
          ],
        ),
        // Filtre butonu ve kedi slider
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                // Filtre butonu
                Container(
                  decoration: BoxDecoration(
                    gradient: (_selectedCatIds.isNotEmpty || _globalTypeFilter != null)
                        ? LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
                          )
                        : null,
                    color: (_selectedCatIds.isEmpty && _globalTypeFilter == null)
                        ? (isDark ? AppColors.surfaceDark : Colors.grey.shade100)
                        : null,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: (_selectedCatIds.isNotEmpty || _globalTypeFilter != null)
                        ? AppShadows.colored(AppColors.primary)
                        : null,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showFilterModal,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              size: 20,
                              color: (_selectedCatIds.isNotEmpty || _globalTypeFilter != null)
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : Colors.black54),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AppLocalizations.get('filter_verb'),
                              style: AppTypography.bodyMedium.copyWith(
                                color: (_selectedCatIds.isNotEmpty || _globalTypeFilter != null)
                                    ? Colors.white
                                    : (isDark ? Colors.white70 : Colors.black54),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_selectedCatIds.isNotEmpty || _globalTypeFilter != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${_selectedCatIds.length + (_globalTypeFilter != null ? 1 : 0)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Kedi slider (sadece birden fazla kedi varsa)
                if (cats.length > 1)
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildCatFilterChip(null, AppLocalizations.get('all_pets'), null),
                          const SizedBox(width: 6),
                          ...cats.map((cat) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _buildCatFilterChip(cat.id, cat.name, cat.photoPath),
                          )),
                          ...dogs.map((dog) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _buildCatFilterChip(dog.id, dog.name, dog.photoPath),
                          )),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
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
        // Yaklaşanlar için süre ve tür filtresi
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Tür filtresi toggle
                GestureDetector(
                  onTap: () => _showTypeFilterModal(isDark),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _pendingShowAllTypes
                          ? (isDark ? AppColors.surfaceDark : Colors.white)
                          : AppColors.info.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _pendingShowAllTypes ? Colors.grey.shade300 : AppColors.info,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _pendingShowAllTypes ? Icons.filter_list_off : Icons.filter_list,
                          size: 14,
                          color: _pendingShowAllTypes ? AppColors.textSecondary : AppColors.info,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _pendingShowAllTypes
                              ? AppLocalizations.get('all_types')
                              : AppLocalizations.get('important_only'),
                          style: TextStyle(
                            fontSize: 12,
                            color: _pendingShowAllTypes ? AppColors.textSecondary : AppColors.info,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Süre filtresi
                _buildRangeSelectorChip(
                  days: _pendingRangeDays,
                  isDark: isDark,
                  onTap: () => _showRangePicker(
                    currentDays: _pendingRangeDays,
                    onSelected: (value) => setState(() => _pendingRangeDays = value),
                  ),
                ),
              ],
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

  // Gün sayısını okunabilir formata çevir
  String _formatDaysLabel(int days) {
    if (days >= 730) {
      return '2 ${AppLocalizations.get('years')}';
    } else if (days >= 365) {
      return '1 ${AppLocalizations.get('year')}';
    } else if (days >= 180) {
      return '6 ${AppLocalizations.get('months')}';
    } else {
      return '$days ${AppLocalizations.get('days')}';
    }
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
              _formatDaysLabel(days),
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
            Expanded(
              child: ListView(
                shrinkWrap: true,
                children: [
                  // Kısa süreli seçenekler
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
                  const Divider(),
                  // Uzun süreli seçenekler (aylar ve yıllar)
                  ListTile(
                    title: Text('6 ${AppLocalizations.get('months')}'),
                    trailing: currentDays == 180
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () {
                      onSelected(180);
                      Navigator.pop(ctx);
                    },
                  ),
                  ListTile(
                    title: Text('1 ${AppLocalizations.get('year')}'),
                    trailing: currentDays == 365
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () {
                      onSelected(365);
                      Navigator.pop(ctx);
                    },
                  ),
                  ListTile(
                    title: Text('2 ${AppLocalizations.get('years')}'),
                    trailing: currentDays == 730
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () {
                      onSelected(730);
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Yakınlaşan etkinlikler için tür filtresi modal'ı
  void _showTypeFilterModal(bool isDark) {
    // Önemli türler (varsayılan seçili)
    final importantTypes = ['vet', 'vaccine', 'neutering', 'surgery', 'microchip', 'bloodTest', 'xray', 'ultrasound', 'allergyTest', 'eyeExam', 'emergency', 'petInsurance'];

    // Günlük/sık türler (varsayılan seçili değil)
    final frequentTypes = ['food', 'water', 'medicine', 'walk', 'litterCleaning', 'litterChange', 'playtime', 'treat', 'vitamin'];

    // Diğer türler
    final otherTypes = ['grooming', 'brushing', 'nailTrim', 'bath', 'earCleaning', 'dentalCare', 'fleaTick', 'deworming', 'weightCheck', 'training', 'photo', 'poopCleanup', 'dogPark', 'socialization', 'scratchingPost', 'hairballPrevention', 'catnip', 'exercise', 'other'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.9,
            minChildSize: 0.5,
            expand: false,
            builder: (context, scrollController) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppLocalizations.get('filter_by_type'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                              },
                              child: Text(AppLocalizations.get('done')),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Tümünü göster / Sadece önemli toggle
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    _pendingShowAllTypes = true;
                                  });
                                  setState(() {}); // Ana ekranı da güncelle
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _pendingShowAllTypes ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: _pendingShowAllTypes ? AppColors.primary : Colors.grey.shade300),
                                  ),
                                  child: Text(
                                    AppLocalizations.get('show_all'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _pendingShowAllTypes ? AppColors.primary : AppColors.textSecondary,
                                      fontWeight: _pendingShowAllTypes ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    _pendingShowAllTypes = false;
                                    _pendingTypeFilters = importantTypes.toSet();
                                  });
                                  setState(() {}); // Ana ekranı da güncelle
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: !_pendingShowAllTypes ? AppColors.info.withOpacity(0.15) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: !_pendingShowAllTypes ? AppColors.info : Colors.grey.shade300),
                                  ),
                                  child: Text(
                                    AppLocalizations.get('important_only'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: !_pendingShowAllTypes ? AppColors.info : AppColors.textSecondary,
                                      fontWeight: !_pendingShowAllTypes ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Önemli türler
                        Text(
                          AppLocalizations.get('important_events'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: importantTypes.map((type) => _buildTypeChip(type, setModalState, isDark)).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Günlük/sık türler
                        Text(
                          AppLocalizations.get('daily_reminders'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.warning,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: frequentTypes.map((type) => _buildTypeChip(type, setModalState, isDark)).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Diğer türler
                        Text(
                          AppLocalizations.get('other'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: otherTypes.map((type) => _buildTypeChip(type, setModalState, isDark)).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // camelCase'i snake_case'e dönüştür (örn: bloodTest -> blood_test)
  String _toSnakeCase(String input) {
    return input.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    );
  }

  Widget _buildTypeChip(String type, StateSetter setModalState, bool isDark) {
    final isSelected = _pendingTypeFilters.contains(type);
    final snakeCaseType = _toSnakeCase(type);
    final typeName = AppLocalizations.get('reminder_type_$snakeCaseType');

    return GestureDetector(
      onTap: _pendingShowAllTypes ? null : () {
        setModalState(() {
          if (isSelected) {
            _pendingTypeFilters.remove(type);
          } else {
            _pendingTypeFilters.add(type);
          }
        });
        setState(() {}); // Ana ekranı da güncelle
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _pendingShowAllTypes
              ? Colors.grey.withOpacity(0.1)
              : (isSelected ? AppColors.primary.withOpacity(0.15) : (isDark ? AppColors.surfaceDark : Colors.grey.shade100)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _pendingShowAllTypes
                ? Colors.grey.shade300
                : (isSelected ? AppColors.primary : Colors.grey.shade300),
          ),
        ),
        child: Text(
          typeName,
          style: TextStyle(
            fontSize: 12,
            color: _pendingShowAllTypes
                ? AppColors.textSecondary
                : (isSelected ? AppColors.primary : AppColors.textSecondary),
            fontWeight: isSelected && !_pendingShowAllTypes ? FontWeight.w600 : FontWeight.normal,
          ),
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
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.15), color.withOpacity(0.08)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: icon == Icons.warning_amber_rounded ? color : null,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.8)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
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
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor.withOpacity(0.4),
              width: 2,
            ),
            boxShadow: [
              ...AppShadows.medium,
              BoxShadow(
                color: borderColor.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
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
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderColor.withOpacity(0.4),
                width: 2,
              ),
              boxShadow: [
                ...AppShadows.medium,
                BoxShadow(
                  color: borderColor.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
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
    final wasCompleted = item.isCompleted;

    if (wasCompleted) {
      // Geri alma işlemi - doğrudan yap
      await _performToggleCompletion(item, wasCompleted, null);
    } else {
      // Tamamlama işlemi
      // Sağlık ile ilgili kayıtlar için tarih ve masraf bilgisi sor
      // Günlük kayıtlar (food, water, dotcat_complete vb.) için direkt tamamla
      final reminderType = ReminderTypeExtension.fromString(item.reminder.type);
      final isHealthRelated = reminderType.isHealthRelated;

      if (isHealthRelated) {
        // Sağlık kaydı - tarih ve opsiyonel masraf bilgisi sor
        final expenseInfo = await _showCompletionDatePicker(item);
        if (expenseInfo != null) {
          await _performToggleCompletion(item, wasCompleted, expenseInfo);
        }
      } else {
        // Günlük kayıt - direkt tamamla
        await _performToggleCompletion(item, wasCompleted, null);
      }
    }
  }

  /// Sağlık kayıtları için "ne zaman yapıldı?" tarih seçici + opsiyonel masraf bilgisi
  Future<VetExpenseInfo?> _showCompletionDatePicker(EventItem item) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    DateTime selectedDate = item.date;
    String? vetClinicName;
    String? costText;
    String selectedCurrency = 'TRY';
    String? notes;
    bool showExpenseFields = false;

    final reminderType = ReminderTypeExtension.fromString(item.reminder.type);
    final isHealthRelated = reminderType.isHealthRelated;

    final currencies = ['TRY', 'USD', 'EUR', 'GBP'];

    return showModalBottomSheet<VetExpenseInfo>(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
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
                  reminderType.icon,
                  color: reminderType.color,
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
                          '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
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

                // Veteriner masraf bilgileri - sadece sağlık ile ilgili kayıtlar için
                if (isHealthRelated) ...[
                  const SizedBox(height: 20),
                  // Masraf ekle butonu
                  GestureDetector(
                    onTap: () => setModalState(() => showExpenseFields = !showExpenseFields),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: showExpenseFields
                            ? AppColors.vet.withOpacity(0.1)
                            : (isDark ? AppColors.surfaceDark : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: showExpenseFields ? AppColors.vet : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            showExpenseFields ? Icons.remove_circle_outline : Icons.add_circle_outline,
                            color: showExpenseFields ? AppColors.vet : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.get('add_expense'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: showExpenseFields ? AppColors.vet : null,
                                  ),
                                ),
                                Text(
                                  AppLocalizations.get('optional'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            showExpenseFields ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            color: context.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Masraf alanları
                  if (showExpenseFields) ...[
                    const SizedBox(height: 16),
                    // Veteriner klinik adı
                    TextField(
                      decoration: InputDecoration(
                        labelText: AppLocalizations.get('vet_clinic_name'),
                        hintText: AppLocalizations.get('optional'),
                        prefixIcon: const Icon(Icons.local_hospital_outlined),
                        filled: true,
                        fillColor: isDark ? AppColors.surfaceDark : Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      onChanged: (v) => vetClinicName = v.isEmpty ? null : v,
                    ),
                    const SizedBox(height: 12),
                    // Ücret ve para birimi
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: AppLocalizations.get('expense_amount'),
                              hintText: '0.00',
                              prefixIcon: const Icon(Icons.attach_money),
                              filled: true,
                              fillColor: isDark ? AppColors.surfaceDark : Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            onChanged: (v) => costText = v.isEmpty ? null : v,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.surfaceDark : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedCurrency,
                                isExpanded: true,
                                items: currencies.map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c),
                                )).toList(),
                                onChanged: (v) => setModalState(() => selectedCurrency = v ?? 'TRY'),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Notlar
                    TextField(
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.get('notes'),
                        hintText: AppLocalizations.get('optional'),
                        prefixIcon: const Icon(Icons.notes),
                        filled: true,
                        fillColor: isDark ? AppColors.surfaceDark : Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      onChanged: (v) => notes = v.isEmpty ? null : v,
                    ),
                  ],
                ],

                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(AppLocalizations.get('cancel')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          double? cost;
                          if (costText != null && costText!.isNotEmpty) {
                            cost = double.tryParse(costText!.replaceAll(',', '.'));
                          }
                          Navigator.pop(ctx, VetExpenseInfo(
                            completionDate: selectedDate,
                            vetClinicName: vetClinicName,
                            cost: cost,
                            currency: cost != null ? selectedCurrency : null,
                            notes: notes,
                          ));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          AppLocalizations.get('mark_completed'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _performToggleCompletion(EventItem item, bool wasCompleted, VetExpenseInfo? expenseInfo) async {
    try {
      final completionDate = expenseInfo?.completionDate ?? item.date;
      final completionId = '${item.reminder.id}_${completionDate.toIso8601String().split('T')[0]}';

      if (wasCompleted) {
        // Tamamlanandan geri al
        await ref.read(completionsProvider.notifier).deleteCompletion(
          completionId,
          item.reminder.id,
          completionDate,
        );
      } else {
        // Tamamlandı olarak işaretle (masraf bilgileri ile birlikte)
        final completion = ReminderCompletion(
          id: completionId,
          reminderId: item.reminder.id,
          completedDate: completionDate,
          completedAt: DateTime.now(),
          vetClinicName: expenseInfo?.vetClinicName,
          cost: expenseInfo?.cost,
          currency: expenseInfo?.currency,
          notes: expenseInfo?.notes,
        );
        await ref.read(completionsProvider.notifier).saveCompletion(completion);

        // Sağlık kaydı ise ve tekrarlayan ise, sonraki tarihi güncelle
        final reminderType = ReminderTypeExtension.fromString(item.reminder.type);
        if (reminderType.isHealthRelated && item.reminder.frequency != 'once' && expenseInfo != null) {
          // Sonraki tarihi gerçek tamamlanma tarihine göre hesapla
          await ref.read(remindersProvider.notifier).updateNextDateFromCompletion(
            item.reminder.id,
            expenseInfo.completionDate,
          );
        }
      }

      // Widget'ı güncelle
      _updateHomeWidget();

      if (mounted) {
        final isNowCompleted = !wasCompleted;
        if (isNowCompleted) {
          // Masraf eklendiyse farklı mesaj göster
          if (expenseInfo?.cost != null && expenseInfo!.cost! > 0) {
            AppToast.success(context, AppLocalizations.get('expense_added'));
          } else {
            AppToast.success(context, AppLocalizations.get('marked_completed'));
          }
        } else {
          AppToast.warning(context, AppLocalizations.get('marked_pending'));
        }
      }
    } catch (e, stackTrace) {
      debugPrint('HomeScreen: _performToggleCompletion error: $e');
      debugPrint('HomeScreen: stackTrace: $stackTrace');
      if (mounted) {
        AppToast.error(context, 'Error: $e');
      }
    }
  }

  void _showFilterModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cats = ref.read(catsProvider);
    final dogs = ref.read(dogsProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.get('filter_verb'),
                  style: AppTypography.headlineLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_selectedCatIds.isNotEmpty || _globalTypeFilter != null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedCatIds.clear();
                        _globalTypeFilter = null;
                      });
                      Navigator.pop(context);
                    },
                    child: Text(AppLocalizations.get('clear')),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Evcil Hayvan Filtresi
            if (cats.isNotEmpty || dogs.isNotEmpty) ...[
              if (cats.isNotEmpty) ...[
                Text(
                  cats.length > 1 ? AppLocalizations.get('cats') : AppLocalizations.get('cat'),
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: cats.map((cat) {
                    final isSelected = _selectedCatIds.contains(cat.id);
                    return FilterChip(
                      label: Text(cat.name),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedCatIds.add(cat.id);
                          } else {
                            _selectedCatIds.remove(cat.id);
                          }
                        });
                        Navigator.pop(context);
                      },
                      backgroundColor: isDark ? AppColors.surfaceDark : Colors.grey.shade100,
                      selectedColor: AppColors.primary.withOpacity(0.2),
                      checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.primary : (isDark ? Colors.white70 : Colors.black87),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              if (dogs.isNotEmpty) ...[
                Text(
                  dogs.length > 1 ? AppLocalizations.get('dogs') : AppLocalizations.get('dog'),
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: dogs.map((dog) {
                    final isSelected = _selectedCatIds.contains(dog.id);
                    return FilterChip(
                      label: Text(dog.name),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedCatIds.add(dog.id);
                          } else {
                            _selectedCatIds.remove(dog.id);
                          }
                        });
                        Navigator.pop(context);
                      },
                      backgroundColor: isDark ? AppColors.surfaceDark : Colors.grey.shade100,
                      selectedColor: AppColors.info.withOpacity(0.2),
                      checkmarkColor: AppColors.info,
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.info : (isDark ? Colors.white70 : Colors.black87),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 8),
            ],

            // Tip Filtresi
            Text(
              AppLocalizations.get('reminder_type'),
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChipModal('dotcat_complete', AppLocalizations.get('dotcat_complete'), Icons.pets, isDark),
                _buildFilterChipModal('vaccine', AppLocalizations.get('vaccine'), Icons.vaccines, isDark),
                _buildFilterChipModal('medicine', AppLocalizations.get('medicine'), Icons.medication, isDark),
                _buildFilterChipModal('vet', AppLocalizations.get('vet'), Icons.local_hospital, isDark),
                _buildFilterChipModal('food', AppLocalizations.get('food'), Icons.restaurant, isDark),
                _buildFilterChipModal('grooming', AppLocalizations.get('grooming'), Icons.content_cut, isDark),
                _buildFilterChipModal('exercise', AppLocalizations.get('exercise'), Icons.fitness_center, isDark),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChipModal(String type, String label, IconData icon, bool isDark) {
    final isSelected = _globalTypeFilter == type;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? AppColors.primary : (isDark ? Colors.white70 : Colors.black54)),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _globalTypeFilter = selected ? type : null;
        });
        Navigator.pop(context);
      },
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.grey.shade100,
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : (isDark ? Colors.white70 : Colors.black87),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  void _showQuickAddModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cats = ref.read(catsProvider);
    final dogs = ref.read(dogsProvider);

    // Pet tipini belirle
    PetType? petType;
    if (cats.isNotEmpty && dogs.isEmpty) {
      petType = PetType.cat;
    } else if (dogs.isNotEmpty && cats.isEmpty) {
      petType = PetType.dog;
    }

    final categories = getReminderCategories(petType);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    AppLocalizations.get('add_reminder'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final isDotcatCategory = category.category == ReminderCategory.dotcat;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : category.color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: category.color.withOpacity(0.3)),
                    ),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      leading: Container(
                        padding: EdgeInsets.all(isDotcatCategory ? 6 : 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [category.color, category.color.withOpacity(0.8)]),
                          shape: BoxShape.circle,
                        ),
                        child: isDotcatCategory
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  width: 30,
                                  height: 30,
                                  fit: BoxFit.contain,
                                ),
                              )
                            : Icon(category.icon, color: Colors.white, size: 22),
                      ),
                      title: Text(
                        category.name,
                        style: TextStyle(fontWeight: FontWeight.bold, color: category.color),
                      ),
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            // Kategori altındaki tüm türler
                            ...category.types.map((type) {
                              return InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                  _goToAddRecordWithTitle(type.value, type.displayName);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: type.color.withOpacity(0.5)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(type.icon, color: type.color, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        type.displayName,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            // Her kategorinin altına "Diğer" seçeneği
                            InkWell(
                              onTap: () {
                                Navigator.pop(context);
                                // Diğer seçildiğinde type 'other' ve başlık boş
                                _goToAddRecordCustom(category.category);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.withOpacity(0.5), style: BorderStyle.solid),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit_rounded, color: Colors.grey, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      AppLocalizations.get('other_custom'),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? Colors.white70 : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  /// Alt tür seçildiğinde başlık otomatik set edilsin
  Future<void> _goToAddRecordWithTitle(String type, String title) async {
    final cats = ref.read(catsProvider);
    final dogs = ref.read(dogsProvider);

    if (cats.isEmpty && dogs.isEmpty) {
      AppToast.show(
        context,
        message: AppLocalizations.get('add_cat_first'),
        type: ToastType.warning,
        onTap: () => Navigator.push(
          context,
          PageTransitions.fadeSlide(page: const AddCatScreen()),
        ),
      );
      return;
    }

    // Bildirim izni kontrolü
    final hasPermission = await NotificationService.instance.requestPermission();
    if (!hasPermission) {
      if (mounted) {
        _showNotificationPermissionDialog(type, title);
      }
      return;
    }

    _showPetSelectionForRecordWithTitle(type, title);
  }

  /// Özel başlık için (Diğer seçeneği)
  Future<void> _goToAddRecordCustom(ReminderCategory category) async {
    final cats = ref.read(catsProvider);
    final dogs = ref.read(dogsProvider);

    if (cats.isEmpty && dogs.isEmpty) {
      AppToast.show(
        context,
        message: AppLocalizations.get('add_cat_first'),
        type: ToastType.warning,
        onTap: () => Navigator.push(
          context,
          PageTransitions.fadeSlide(page: const AddCatScreen()),
        ),
      );
      return;
    }

    // Bildirim izni kontrolü
    final hasPermission = await NotificationService.instance.requestPermission();
    if (!hasPermission) {
      if (mounted) {
        _showNotificationPermissionDialog('other', null);
      }
      return;
    }

    _showPetSelectionForRecordCustom(category);
  }

  void _showNotificationPermissionDialog(String type, String? title) {
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
                if (title != null) {
                  _showPetSelectionForRecordWithTitle(type, title);
                } else {
                  _showPetSelectionForRecord(type);
                }
              } else if (mounted) {
                AppToast.error(context, AppLocalizations.get('notification_permission_required'));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(AppLocalizations.get('enable_notifications'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPetSelectionForRecordWithTitle(String type, String title) {
    final cats = ref.read(catsProvider);
    final dogs = ref.read(dogsProvider);
    final List<dynamic> allPets = [...cats, ...dogs];

    if (allPets.length == 1) {
      final pet = allPets.first;
      final petId = pet is Cat ? pet.id : (pet as Dog).id;
      Navigator.push(
        context,
        PageTransitions.fadeSlide(
          page: AddReminderScreen(
            initialType: type,
            preselectedCatId: petId,
            initialTitle: title,
          ),
        ),
      );
      return;
    }

    _showPetSelectionBottomSheet(allPets, type, title);
  }

  void _showPetSelectionForRecordCustom(ReminderCategory category) {
    final cats = ref.read(catsProvider);
    final dogs = ref.read(dogsProvider);
    final List<dynamic> allPets = [...cats, ...dogs];

    if (allPets.length == 1) {
      final pet = allPets.first;
      final petId = pet is Cat ? pet.id : (pet as Dog).id;
      Navigator.push(
        context,
        PageTransitions.fadeSlide(
          page: AddReminderScreen(
            initialType: 'other',
            preselectedCatId: petId,
            initialTitle: null, // Kullanıcı kendi başlığını girecek
          ),
        ),
      );
      return;
    }

    _showPetSelectionBottomSheet(allPets, 'other', null);
  }

  void _showPetSelectionBottomSheet(List<dynamic> allPets, String type, String? title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedPetIds = <String>{};

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppLocalizations.get('select_pets_for_record'),
                style: AppTypography.headlineMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.get('select_multiple'),
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              ListView.builder(
                shrinkWrap: true,
                itemCount: allPets.length,
                itemBuilder: (context, index) {
                  final pet = allPets[index];
                  final isPetCat = pet is Cat;
                  final isSelected = selectedPetIds.contains(pet.id);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {
                        setModalState(() {
                          if (isSelected) {
                            selectedPetIds.remove(pet.id);
                          } else {
                            selectedPetIds.add(pet.id);
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                            ? (isPetCat ? AppColors.primary : AppColors.info).withOpacity(0.1)
                            : (isDark ? AppColors.surfaceDark : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                              ? (isPetCat ? AppColors.primary : AppColors.info)
                              : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: (isPetCat ? AppColors.primary : AppColors.info).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: pet.photoPath != null && pet.photoPath!.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      pet.photoPath!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Center(
                                          child: Text(
                                            isPetCat ? '🐱' : '🐶',
                                            style: const TextStyle(fontSize: 28),
                                          ),
                                        );
                                      },
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      isPetCat ? '🐱' : '🐶',
                                      style: const TextStyle(fontSize: 28),
                                    ),
                                  ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pet.name,
                                    style: AppTypography.titleMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isPetCat ? AppLocalizations.get('cat') : AppLocalizations.get('dog'),
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : Colors.black54,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: isPetCat ? AppColors.primary : AppColors.info,
                                size: 28,
                              )
                            else
                              Icon(
                                Icons.circle_outlined,
                                color: Colors.grey.shade400,
                                size: 28,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: selectedPetIds.isEmpty
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          this.context,
                          PageTransitions.fadeSlide(
                            page: AddReminderScreen(
                              initialType: type,
                              preselectedPetIds: selectedPetIds,
                              initialTitle: title,
                            ),
                          ),
                        );
                      },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: Text(
                    selectedPetIds.isEmpty
                      ? AppLocalizations.get('select_pet')
                      : '${AppLocalizations.get('continue_btn')} (${selectedPetIds.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _goToAddRecord(String? type) async {
    final cats = ref.read(catsProvider);
    final dogs = ref.read(dogsProvider);

    if (cats.isEmpty && dogs.isEmpty) {
      AppToast.show(
        context,
        message: AppLocalizations.get('add_cat_first'),
        type: ToastType.warning,
        onTap: () => Navigator.push(
          context,
          PageTransitions.fadeSlide(page: const AddCatScreen()),
        ),
      );
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
                    _showPetSelectionForRecord(type);
                  } else if (mounted) {
                    AppToast.error(context, AppLocalizations.get('notification_permission_required'));
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

    // Hayvan seçim ekranını göster
    _showPetSelectionForRecord(type);
  }

  void _showPetSelectionForRecord(String? type) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cats = ref.read(catsProvider);
    final dogs = ref.read(dogsProvider);
    final List<dynamic> allPets = [...cats, ...dogs];

    // Eğer tek hayvan varsa direkt kayıt sayfasına git
    if (allPets.length == 1) {
      Navigator.push(
        context,
        PageTransitions.fadeSlide(
          page: AddReminderScreen(
            initialType: type,
            preselectedCatId: allPets.first.id,
          ),
        ),
      );
      return;
    }

    // Çoklu seçim için state
    final selectedPetIds = <String>{};

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Başlık
              Text(
                'Hangi hayvanlar için kayıt eklemek istersiniz?',
                style: AppTypography.headlineMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Birden fazla seçebilirsiniz',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),

              // Hayvan listesi
              ListView.builder(
                shrinkWrap: true,
                itemCount: allPets.length,
                itemBuilder: (context, index) {
                  final pet = allPets[index];
                  final isPetCat = pet is Cat;
                  final isSelected = selectedPetIds.contains(pet.id);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {
                        setModalState(() {
                          if (isSelected) {
                            selectedPetIds.remove(pet.id);
                          } else {
                            selectedPetIds.add(pet.id);
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                            ? (isPetCat ? AppColors.primary : AppColors.info).withOpacity(0.1)
                            : (isDark ? AppColors.surfaceDark : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                              ? (isPetCat ? AppColors.primary : AppColors.info)
                              : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Fotoğraf veya emoji
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: (isPetCat ? AppColors.primary : AppColors.info).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: pet.photoPath != null && pet.photoPath!.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      pet.photoPath!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Center(
                                          child: Text(
                                            isPetCat ? '🐱' : '🐶',
                                            style: const TextStyle(fontSize: 28),
                                          ),
                                        );
                                      },
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      isPetCat ? '🐱' : '🐶',
                                      style: const TextStyle(fontSize: 28),
                                    ),
                                  ),
                            ),
                            const SizedBox(width: 16),

                            // İsim
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pet.name,
                                    style: AppTypography.titleMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isPetCat ? AppLocalizations.get('cat') : AppLocalizations.get('dog'),
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : Colors.black54,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Seçim göstergesi
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: isPetCat ? AppColors.primary : AppColors.info,
                                size: 28,
                              )
                            else
                              Icon(
                                Icons.circle_outlined,
                                color: Colors.grey.shade400,
                                size: 28,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Devam butonu
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: selectedPetIds.isEmpty
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          PageTransitions.fadeSlide(
                            page: AddReminderScreen(
                              initialType: type,
                              preselectedPetIds: selectedPetIds,
                            ),
                          ),
                        );
                      },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: Text(
                    selectedPetIds.isEmpty
                      ? AppLocalizations.get('select_pets')
                      : AppLocalizations.get('continue_with_count').replaceAll('{count}', selectedPetIds.length.toString()),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCatsPage() {
    final cats = ref.watch(catsProvider);
    final dogs = ref.watch(dogsProvider);
    final reminders = ref.watch(remindersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Combine cats and dogs into a single list with metadata
    final List<Map<String, dynamic>> pets = [
      ...cats.map((cat) => {'pet': cat, 'type': PetType.cat}),
      ...dogs.map((dog) => {'pet': dog, 'type': PetType.dog}),
    ];

    // Sort by createdAt descending
    pets.sort((a, b) {
      final petA = a['pet'];
      final petB = b['pet'];
      return petB.createdAt.compareTo(petA.createdAt);
    });

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          centerTitle: false,
          title: Text(AppLocalizations.get('my_pets'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
          actions: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.add, color: AppColors.primary),
              ),
              onPressed: () => _showAddPetDialog(),
            ),
          ],
        ),
        if (pets.isEmpty)
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
                  Text(AppLocalizations.get('no_pets'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(AppLocalizations.get('add_your_first_pet'), style: TextStyle(color: context.textSecondary, fontSize: 15), textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _showAddPetDialog,
                      icon: const Icon(Icons.add),
                      label: Text(AppLocalizations.get('add_pet'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
                final petData = pets[index];
                final pet = petData['pet'];
                final petType = petData['type'] as PetType;
                final petReminders = reminders.where((r) => r.catId == pet.id).toList();
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
                
                for (final reminder in petReminders) {
                  // Ana sayfadaki _generateOccurrences mantığını kullan
                  final occurrences = _generateOccurrences(reminder, pet, rangeStart, rangeEnd, currentCompletedDates);
                  
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
                    onTap: () {
                      // Navigate to appropriate profile screen based on pet type
                      if (petType == PetType.cat) {
                        Navigator.push(
                          context,
                          PageTransitions.slide(page: CatProfileScreen(cat: pet)),
                        );
                      } else {
                        Navigator.push(
                          context,
                          PageTransitions.slide(page: DogProfileScreen(dog: pet)),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: AppShadows.large,
                      ),
                      child: Row(children: [
                        _buildCatPhoto(pet.photoPath, radius: 32, iconSize: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(
                              children: [
                                Text(pet.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                const SizedBox(width: 8),
                                Text(
                                  petType == PetType.cat ? '🐱' : '🐶',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                            if (pet.breed != null && pet.breed!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(pet.breed!, style: TextStyle(fontSize: 13, color: context.textSecondary)),
                            ],
                            const SizedBox(height: 8),
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                child: Text(DateHelper.getAge(pet.birthDate), style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500)),
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
              }, childCount: pets.length),
          ),
        ),
      ],
    );
  }

  void _showAddPetDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Check if user already has pets and is not premium
    final cats = ref.read(catsProvider);
    final dogs = ref.read(dogsProvider);
    final totalPets = cats.length + dogs.length;
    final isPremium = PremiumService.instance.isPremium;

    // If user already has 1+ pets and is not premium, show premium screen
    if (totalPets >= 1 && !isPremium) {
      Navigator.push(
        context,
        PageTransitions.fadeSlide(page: const PremiumScreen()),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 24),
              Text(
                AppLocalizations.get('add_pet'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildPetTypeCard(
                      context: ctx,
                      title: AppLocalizations.get('add_cat'),
                      emoji: '🐱',
                      color: AppColors.primary,
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          PageTransitions.fadeSlide(page: const AddCatScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildPetTypeCard(
                      context: ctx,
                      title: AppLocalizations.get('add_dog'),
                      emoji: '🐶',
                      color: AppColors.info,
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          PageTransitions.fadeSlide(page: const AddDogScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPetTypeCard({
    required BuildContext context,
    required String title,
    IconData? icon,
    String? emoji,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: emoji != null
                ? Text(emoji, style: const TextStyle(fontSize: 32))
                : Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

}
