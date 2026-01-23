import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/reminder_constants.dart';
import '../../../core/utils/localization.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/utils/page_transitions.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/models/cat.dart';
import '../../../data/models/dog.dart';
import '../../../data/models/pet_type.dart';
import '../../../data/models/reminder.dart';
import '../../reminders/providers/reminders_provider.dart';
import '../../reminders/providers/completions_provider.dart';
import '../../weight/providers/weight_provider.dart';
import '../../reminders/presentation/add_reminder_screen.dart';
import '../../reminders/presentation/record_detail_screen.dart';
import '../../weight/presentation/weight_screen.dart';
import '../providers/cats_provider.dart';
import '../../dogs/providers/dogs_provider.dart';
import 'edit_cat_screen.dart';
import '../../dogs/presentation/edit_dog_screen.dart';

bool _photoExists(String? path) {
  if (path == null || path.isEmpty) return false;
  if (path.startsWith('http://') || path.startsWith('https://')) return true;
  return File(path).existsSync();
}

/// Pet Profili - Kullanışlı bakım takip ekranı (kedi ve köpek için)
class CatProfileScreen extends ConsumerStatefulWidget {
  final dynamic cat; // Can be Cat or Dog
  const CatProfileScreen({super.key, required this.cat});

  @override
  ConsumerState<CatProfileScreen> createState() => _CatProfileScreenState();
}

class _CatProfileScreenState extends ConsumerState<CatProfileScreen> {
  late dynamic _currentPet; // Can be Cat or Dog

  // Overdue hesaplama için tarih aralığı (son 30 gün)
  static const int _overdueRangeDays = 30;

  // Helper getters for pet properties
  String get _petId => _currentPet.id;
  String get _petName => _currentPet.name;
  DateTime get _petBirthDate => _currentPet.birthDate;
  String? get _petBreed => _currentPet.breed;
  String? get _petPhotoPath => _currentPet.photoPath;
  bool get _isPetCat => _currentPet is Cat;
  bool get _isPetDog => _currentPet is Dog;
  PetType get _petType => _isPetCat ? PetType.cat : PetType.dog;

  @override
  void initState() {
    super.initState();
    _currentPet = widget.cat;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    await ref.read(remindersProvider.notifier).loadReminders();
    await ref.read(weightProvider.notifier).loadWeightRecords(_petId);
  }

  /// Tekrar frekansına göre sonraki tarihi hesapla
  DateTime? _calculateNextDate(DateTime current, String frequency) {
    switch (frequency) {
      case 'daily':
        return current.add(const Duration(days: 1));
      case 'weekly':
        return current.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(current.year, current.month + 1, current.day);
      case 'quarterly':
        return DateTime(current.year, current.month + 3, current.day);
      case 'biannual':
        return DateTime(current.year, current.month + 6, current.day);
      case 'yearly':
        return DateTime(current.year + 1, current.month, current.day);
      default:
        if (frequency.startsWith('custom_')) {
          final days = int.tryParse(frequency.substring(7));
          if (days != null) return current.add(Duration(days: days));
        }
        return null;
    }
  }

  /// Bir reminder için tüm gecikmiş occurence'ları hesapla (home_screen ile aynı mantık)
  List<DateTime> _getOverdueOccurrences(Reminder reminder, Set<String> completedDates) {
    final overdueList = <DateTime>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rangeStart = today.subtract(Duration(days: _overdueRangeDays));

    if (!reminder.isActive) return overdueList;

    if (reminder.frequency == 'once') {
      // Tek seferlik - sadece createdAt tarihinde
      final date = DateTime(reminder.createdAt.year, reminder.createdAt.month, reminder.createdAt.day);
      if (date.isBefore(today) && date.isAfter(rangeStart.subtract(const Duration(days: 1)))) {
        final key = '${reminder.id}_${date.toIso8601String().split('T')[0]}';
        if (!completedDates.contains(key) && !reminder.isCompleted) {
          overdueList.add(date);
        }
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

      // Range içindeki geçmiş tarihleri kontrol et
      while (current.isBefore(today)) {
        final key = '${reminder.id}_${current.toIso8601String().split('T')[0]}';
        if (!completedDates.contains(key)) {
          overdueList.add(current);
        }

        final next = _calculateNextDate(current, reminder.frequency);
        if (next == null) break;
        current = next;
      }
    }

    return overdueList;
  }

  @override
  Widget build(BuildContext context) {
    final allReminders = ref.watch(remindersProvider);
    final weights = ref.watch(weightProvider);
    final completions = ref.watch(completionsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final catReminders = allReminders.where((r) => r.catId == _petId).toList();
    
    // Kategori bazlı görevler
    final vaccines = catReminders.where((r) => r.type == 'vaccine').toList();
    final medicines = catReminders.where((r) => r.type == 'medicine').toList();
    final vetVisits = catReminders.where((r) => r.type == 'vet').toList();
    final grooming = catReminders.where((r) => r.type == 'grooming').toList();
    final food = catReminders.where((r) => r.type == 'food').toList();
    
    // Yaklaşan görevler (7 gün içinde)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcomingTasks = catReminders.where((r) {
      if (!r.isActive || r.nextDate == null) return false;
      final diff = r.nextDate!.difference(today).inDays;
      return diff >= 0 && diff <= 7;
    }).toList()..sort((a, b) => a.nextDate!.compareTo(b.nextDate!));

    // Gecikmiş görevler - home screen ile aynı mantıkla hesapla
    // Her reminder için tüm gecikmiş occurence'ları bul
    final List<Map<String, dynamic>> overdueItems = [];
    for (final reminder in catReminders) {
      final overdueOccurrences = _getOverdueOccurrences(reminder, completions.completedDates);
      for (final date in overdueOccurrences) {
        overdueItems.add({
          'reminder': reminder,
          'date': date,
        });
      }
    }
    // Tarihe göre sırala (en yeniden en eskiye)
    overdueItems.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    // Eski kod için uyumluluk: overdueTasks listesi (reminder listesi olarak)
    final overdueTasks = overdueItems.map((item) => item['reminder'] as Reminder).toSet().toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8F9FA),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            // Header with cat info
            _buildHeader(isDark, weights),
            
            // Uyarılar (varsa)
            if (overdueItems.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildAlertCard(overdueItems, isDark),
              ),

            // Yaklaşan Görevler
            if (upcomingTasks.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildUpcomingSection(upcomingTasks, isDark),
              ),
            
            // Bakım Durumu Kartları
            SliverToBoxAdapter(
              child: _buildCareStatusSection(
                vaccines: vaccines,
                medicines: medicines,
                vetVisits: vetVisits,
                grooming: grooming,
                weights: weights,
                isDark: isDark,
              ),
            ),
            
            // Masraf Özeti
            SliverToBoxAdapter(
              child: _buildExpenseSummarySection(catReminders, completions, isDark),
            ),

            // Tüm Kayıtlar
            SliverToBoxAdapter(
              child: _buildAllRecordsSection(catReminders, isDark),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      floatingActionButton: Container(
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
          .scaleXY(end: 1.05, duration: 2000.ms, curve: Curves.easeInOut),
    );
  }

  Widget _buildHeader(bool isDark, List weights) {
    final latestWeight = weights.isNotEmpty ? weights.first.weight : null;
    
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: () async {
            if (_isPetCat) {
              final updated = await Navigator.push<Cat>(
                context,
                PageTransitions.slide(page: EditCatScreen(cat: _currentPet as Cat)),
              );
              if (updated != null) setState(() => _currentPet = updated);
            } else {
              final updated = await Navigator.push<Dog>(
                context,
                PageTransitions.slide(page: EditDogScreen(dog: _currentPet as Dog)),
              );
              if (updated != null) setState(() => _currentPet = updated);
            }
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: _handleMenuAction,
          itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'delete', child: Row(
              children: [
                Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                SizedBox(width: 12),
                Text('Sil', style: TextStyle(color: AppColors.error)),
              ],
            )),
          ],
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primaryDark,
                AppColors.secondary,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: Row(
                children: [
                  // Profil fotoğrafı with glow effect
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Colors.white, Colors.white.withOpacity(0.9)],
                      ),
                      boxShadow: [
                        ...AppShadows.large,
                        BoxShadow(
                          color: AppColors.primaryLight.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(4),
                    child: CircleAvatar(
                      radius: 46,
                      backgroundColor: AppColors.primary.withOpacity(0.2),
                      backgroundImage: _photoExists(_petPhotoPath)
                          ? (_petPhotoPath!.startsWith('http')
                              ? CachedNetworkImageProvider(_petPhotoPath!)
                              : FileImage(File(_petPhotoPath!)) as ImageProvider)
                          : null,
                      child: !_photoExists(_petPhotoPath)
                          ? const Icon(Icons.pets_rounded, size: 46, color: Colors.white)
                          : null,
                    ),
                  ).animate()
                      .fadeIn(duration: 500.ms)
                      .scale(delay: 100.ms, duration: 500.ms, curve: Curves.elasticOut),
                  const SizedBox(width: 20),

                  // Bilgiler
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _petName,
                          style: AppTypography.displayMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ).animate()
                            .fadeIn(duration: 500.ms, delay: 200.ms)
                            .slideX(begin: -0.2, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
                        if (_petBreed != null && _petBreed!.isNotEmpty)
                          Text(
                            _petBreed!,
                            style: AppTypography.bodyLarge.copyWith(
                              color: Colors.white.withOpacity(0.95),
                            ),
                          ).animate()
                              .fadeIn(duration: 500.ms, delay: 300.ms)
                              .slideX(begin: -0.2, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _buildInfoChip(Icons.cake_outlined, DateHelper.getAge(_petBirthDate))
                                .animate()
                                .fadeIn(duration: 500.ms, delay: 400.ms)
                                .scale(delay: 400.ms, duration: 400.ms),
                            const SizedBox(width: 10),
                            if (latestWeight != null)
                              _buildInfoChip(Icons.monitor_weight_outlined, '${latestWeight.toStringAsFixed(1)} kg')
                                  .animate()
                                  .fadeIn(duration: 500.ms, delay: 500.ms)
                                  .scale(delay: 500.ms, duration: 400.ms),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                text,
                style: AppTypography.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertCard(List<Map<String, dynamic>> overdueItems, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.error.withOpacity(0.15),
            AppColors.error.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.error.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          ...AppShadows.medium,
          BoxShadow(
            color: AppColors.error.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.error.withOpacity(0.3),
                      AppColors.error.withOpacity(0.2),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.error.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 22),
              ),
              const SizedBox(width: 14),
              Text(
                '${overdueItems.length} ${AppLocalizations.get('overdue_tasks')}',
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
            ],
          ).animate()
              .fadeIn(duration: 500.ms)
              .slideX(begin: -0.2, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
          const SizedBox(height: 16),
          ...overdueItems.take(3).map((item) {
            final task = item['reminder'] as Reminder;
            final overdueDate = item['date'] as DateTime;
            final index = overdueItems.indexOf(item);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RecordDetailScreen(record: task, catName: _petName)),
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.error.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _getTypeColor(task.type).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getTypeIcon(task.type),
                          color: _getTypeColor(task.type),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          task.title,
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getRelativeDate(overdueDate),
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate()
                  .fadeIn(duration: 500.ms, delay: (100 * index).ms)
                  .slideX(begin: -0.1, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
            );
          }),
        ],
      ),
    ).animate()
        .fadeIn(duration: 600.ms)
        .slideY(begin: -0.2, end: 0, duration: 600.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildQuickActions(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hızlı İşlemler',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildQuickActionButton(
                icon: Icons.monitor_weight_outlined,
                label: 'Kilo Ekle',
                color: AppColors.warning,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => WeightScreen(cat: _currentPet)),
                ),
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              _buildQuickActionButton(
                icon: Icons.vaccines_outlined,
                label: 'Aşı Ekle',
                color: AppColors.vaccine,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddReminderScreen(
                    preselectedCatId: _petId,
                    initialType: 'vaccine',
                  )),
                ),
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              _buildQuickActionButton(
                icon: Icons.content_cut_outlined,
                label: 'Bakım',
                color: AppColors.grooming,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddReminderScreen(
                    preselectedCatId: _petId,
                    initialType: 'grooming',
                  )),
                ),
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              _buildQuickActionButton(
                icon: Icons.local_hospital_outlined,
                label: 'Veteriner',
                color: AppColors.vet,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddReminderScreen(
                    preselectedCatId: _petId,
                    initialType: 'vet',
                  )),
                ),
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticService.instance.tap();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isDark ? null : [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingSection(List<Reminder> tasks, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Yaklaşan Görevler',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...tasks.take(5).map((task) => _buildUpcomingTaskCard(task, isDark)),
        ],
      ),
    );
  }

  Widget _buildUpcomingTaskCard(Reminder task, bool isDark) {
    final isToday = _isToday(task.nextDate!);
    final isTomorrow = _isTomorrow(task.nextDate!);
    
    return GestureDetector(
      onTap: () {
        HapticService.instance.tap();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RecordDetailScreen(record: task, catName: _petName)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isToday ? Border.all(color: AppColors.primary, width: 2) : null,
          boxShadow: isDark ? null : [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _getTypeColor(task.type).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_getTypeIcon(task.type), color: _getTypeColor(task.type), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${task.time} • ${_getFrequencyText(task.frequency)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isToday 
                    ? AppColors.primary.withOpacity(0.1) 
                    : isTomorrow 
                        ? AppColors.warning.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isToday ? 'Bugün' : isTomorrow ? 'Yarın' : _getRelativeDate(task.nextDate!),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isToday ? AppColors.primary : isTomorrow ? AppColors.warning : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCareStatusSection({
    required List<Reminder> vaccines,
    required List<Reminder> medicines,
    required List<Reminder> vetVisits,
    required List<Reminder> grooming,
    required List weights,
    required bool isDark,
  }) {
    final allReminders = ref.watch(remindersProvider);
    final catReminders = allReminders.where((r) => r.catId == _petId).toList();
    final food = catReminders.where((r) => r.type == 'food').toList();
    final dotcat = catReminders.where((r) => r.type == 'dotcat_complete').toList();
    final exercise = catReminders.where((r) => r.type == 'exercise').toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bakım Durumu',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),

          // Grid of care status cards - 2 columns
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _buildCareCard(
                title: 'DotCat Ürünleri',
                value: '${dotcat.length}',
                subtitle: dotcat.isNotEmpty ? 'Aktif takip' : 'Hatırlatıcı ekle',
                icon: Icons.star_rounded,
                color: AppColors.primary,
                status: dotcat.isNotEmpty ? 'good' : 'warning',
                isDark: isDark,
                onTap: () => _showCategoryDetails('DotCat Ürünleri', dotcat, AppColors.primary),
              ),
              _buildCareCard(
                title: 'Aşılar',
                value: '${vaccines.length}',
                subtitle: _getNextVaccineText(vaccines),
                icon: Icons.vaccines_outlined,
                color: AppColors.vaccine,
                status: _getVaccineStatus(vaccines),
                isDark: isDark,
                onTap: () => _showCategoryDetails('Aşılar', vaccines, AppColors.vaccine),
              ),
              _buildCareCard(
                title: 'İlaç/Parazit',
                value: '${medicines.length}',
                subtitle: _getNextMedicineText(medicines),
                icon: Icons.medication_outlined,
                color: AppColors.medicine,
                status: _getMedicineStatus(medicines),
                isDark: isDark,
                onTap: () => _showCategoryDetails('İlaç & Parazit', medicines, AppColors.medicine),
              ),
              _buildCareCard(
                title: 'Veteriner',
                value: '${vetVisits.length}',
                subtitle: vetVisits.isNotEmpty ? 'Aktif takip' : 'Hatırlatıcı ekle',
                icon: Icons.local_hospital_outlined,
                color: AppColors.vet,
                status: vetVisits.isNotEmpty ? 'good' : 'warning',
                isDark: isDark,
                onTap: () => _showCategoryDetails('Veteriner', vetVisits, AppColors.vet),
              ),
              _buildCareCard(
                title: 'Bakım',
                value: '${grooming.length}',
                subtitle: grooming.isNotEmpty ? 'Aktif takip' : 'Hatırlatıcı ekle',
                icon: Icons.content_cut_outlined,
                color: AppColors.grooming,
                status: grooming.isNotEmpty ? 'good' : 'warning',
                isDark: isDark,
                onTap: () => _showCategoryDetails('Bakım', grooming, AppColors.grooming),
              ),
              _buildCareCard(
                title: 'Mama',
                value: '${food.length}',
                subtitle: food.isNotEmpty ? 'Aktif takip' : 'Hatırlatıcı ekle',
                icon: Icons.restaurant_outlined,
                color: AppColors.food,
                status: food.isNotEmpty ? 'good' : 'warning',
                isDark: isDark,
                onTap: () => _showCategoryDetails('Mama', food, AppColors.food),
              ),
              _buildCareCard(
                title: 'Egzersiz',
                value: '${exercise.length}',
                subtitle: exercise.isNotEmpty ? 'Aktif takip' : 'Hatırlatıcı ekle',
                icon: Icons.fitness_center_outlined,
                color: const Color(0xFFFF9800),
                status: exercise.isNotEmpty ? 'good' : 'warning',
                isDark: isDark,
                onTap: () => _showCategoryDetails('Egzersiz', exercise, const Color(0xFFFF9800)),
              ),
              _buildCareCard(
                title: 'Kilo Takibi',
                value: weights.isNotEmpty ? '${weights.first.weight.toStringAsFixed(1)} kg' : '-',
                subtitle: weights.isNotEmpty
                    ? '${_daysSince(weights.first.recordedAt)} gün önce'
                    : 'Henüz kayıt yok',
                icon: Icons.monitor_weight_outlined,
                color: AppColors.warning,
                status: _getWeightStatus(weights),
                isDark: isDark,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => WeightScreen(cat: _currentPet)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCareCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String status,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final statusColor = status == 'good' 
        ? AppColors.success 
        : status == 'warning' 
            ? AppColors.warning 
            : AppColors.error;
    
    return GestureDetector(
      onTap: () {
        HapticService.instance.tap();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark ? null : [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseSummarySection(List<Reminder> reminders, CompletionsState completions, bool isDark) {
    // Bu pet'e ait reminder ID'leri
    final reminderIds = reminders.map((r) => r.id).toList();

    // Masrafları filtrele
    final expenses = completions.allCompletions
        .where((c) => reminderIds.contains(c.reminderId) && c.hasExpense)
        .toList()
      ..sort((a, b) => b.completedDate.compareTo(a.completedDate));

    if (expenses.isEmpty) {
      return const SizedBox.shrink(); // Masraf yoksa gösterme
    }

    // Para birimlerine göre topla
    final expensesByCurrency = <String, double>{};
    for (final expense in expenses) {
      final currency = expense.currency ?? 'TRY';
      expensesByCurrency[currency] = (expensesByCurrency[currency] ?? 0) + (expense.cost ?? 0);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.get('expense_summary'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Toplam masraf kartları
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isDark ? null : AppShadows.small,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Toplam masraflar
                Text(
                  AppLocalizations.get('total_expenses'),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: expensesByCurrency.entries.map((entry) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${entry.value.toStringAsFixed(2)} ${entry.key}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Son masraflar listesi
                Text(
                  AppLocalizations.get('recent_expenses'),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                ...expenses.take(5).map((expense) {
                  // İlgili reminder'ı bul
                  final reminder = reminders.firstWhere(
                    (r) => r.id == expense.reminderId,
                    orElse: () => reminders.first,
                  );

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.info.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.medical_services_rounded, color: AppColors.info, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reminder.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                expense.vetClinicName ?? DateHelper.formatDate(expense.completedDate),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          expense.formattedCost,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                // Daha fazla göster
                if (expenses.length > 5) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () => _showAllExpenses(expenses, reminders, isDark),
                      child: Text(
                        '${AppLocalizations.get('view_all')} (${expenses.length})',
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAllExpenses(List expenses, List<Reminder> reminders, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
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
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded, color: AppColors.success),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.get('all_expenses'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: expenses.length,
                    itemBuilder: (context, index) {
                      final expense = expenses[index];
                      final reminder = reminders.firstWhere(
                        (r) => r.id == expense.reminderId,
                        orElse: () => reminders.first,
                      );

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.backgroundDark : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  reminder.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                Text(
                                  expense.formattedCost,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateHelper.formatDate(expense.completedDate),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (expense.vetClinicName != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.local_hospital, size: 14, color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    expense.vetClinicName!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (expense.notes != null && expense.notes!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                expense.notes!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAllRecordsSection(List<Reminder> reminders, bool isDark) {
    if (reminders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(Icons.pets_rounded, size: 48, color: AppColors.primary.withOpacity(0.5)),
              const SizedBox(height: 16),
              Text(
                'Henüz kayıt yok',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_petName} için ilk hatırlatıcıyı ekleyerek başlayın',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Tarihe göre grupla
    final sortedReminders = [...reminders]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.get('all_records'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                AppLocalizations.get('x_records').replaceAll('{count}', '${reminders.length}'),
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...sortedReminders.take(10).map((r) => _buildRecordItem(r, isDark)),
          if (reminders.length > 10)
            Center(
              child: TextButton(
                onPressed: () {
                  // TODO: Show all records
                },
                child: Text('Tümünü Gör (${reminders.length})'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecordItem(Reminder reminder, bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticService.instance.tap();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RecordDetailScreen(record: reminder, catName: _petName)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getTypeColor(reminder.type).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_getTypeIcon(reminder.type), color: _getTypeColor(reminder.type), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder.title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(
                    '${reminder.time} • ${_getFrequencyText(reminder.frequency)}',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  void _showCategoryDetails(String title, List<Reminder> items, Color color) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (_, scrollController) => Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.backgroundDark : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(_getCategoryIcon(title), color: color),
                      const SizedBox(width: 12),
                      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => AddReminderScreen(
                              preselectedCatId: _petId,
                              initialType: _getCategoryType(title),
                            ),
                          ));
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Ekle'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox_outlined, size: 48, color: AppColors.textSecondary.withOpacity(0.5)),
                              const SizedBox(height: 16),
                              const Text('Henüz kayıt yok'),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: items.length,
                          itemBuilder: (context, index) => _buildRecordItem(items[index], isDark),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleMenuAction(String action) async {
    if (action == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(_isPetCat ? AppLocalizations.get('delete_cat') : AppLocalizations.get('delete_dog')),
          content: Text(AppLocalizations.get('delete_cat_confirm')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocalizations.get('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppLocalizations.get('delete'), style: const TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      );
      if (confirm == true && mounted) {
        if (_isPetCat) {
          await ref.read(catsProvider.notifier).deleteCat(_petId);
        } else {
          await ref.read(dogsProvider.notifier).deleteDog(_petId);
        }
        if (mounted) Navigator.pop(context);
      }
    }
  }

  // Helper methods
  Color _getTypeColor(String type) {
    switch (type) {
      case 'vaccine': return AppColors.vaccine;
      case 'medicine': return AppColors.medicine;
      case 'vet': return AppColors.vet;
      case 'food': return AppColors.food;
      case 'dotcat_complete': return AppColors.dotcat;
      case 'grooming': return AppColors.grooming;
      case 'exercise': return const Color(0xFFFF9800);
      default: return AppColors.primary;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'vaccine': return Icons.vaccines;
      case 'medicine': return Icons.medication;
      case 'vet': return Icons.local_hospital;
      case 'food': return Icons.restaurant;
      case 'dotcat_complete': return Icons.star_rounded;
      case 'grooming': return Icons.content_cut;
      case 'exercise': return Icons.fitness_center;
      default: return Icons.event;
    }
  }

  IconData _getCategoryIcon(String title) {
    if (title.contains('DotCat')) return Icons.star_rounded;
    if (title.contains('Aşı')) return Icons.vaccines;
    if (title.contains('İlaç')) return Icons.medication;
    if (title.contains('Veteriner')) return Icons.local_hospital;
    if (title.contains('Bakım')) return Icons.content_cut;
    if (title.contains('Mama')) return Icons.restaurant;
    if (title.contains('Egzersiz')) return Icons.fitness_center;
    if (title.contains('Kilo')) return Icons.monitor_weight;
    return Icons.event;
  }

  String _getCategoryType(String title) {
    if (title.contains('DotCat')) return 'dotcat_complete';
    if (title.contains('Aşı')) return 'vaccine';
    if (title.contains('İlaç')) return 'medicine';
    if (title.contains('Veteriner')) return 'vet';
    if (title.contains('Bakım')) return 'grooming';
    if (title.contains('Mama')) return 'food';
    if (title.contains('Egzersiz')) return 'exercise';
    return 'vet';
  }

  void _showQuickAddModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              'Yeni Kayıt Ekle',
              style: AppTypography.headlineLarge.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _buildQuickActionGrid(Icons.star_rounded, 'DotCat', AppColors.primary, 'dotcat_complete'),
                _buildQuickActionGrid(Icons.vaccines, AppLocalizations.get('reminder_type_vaccine'), AppColors.vaccine, 'vaccine'),
                _buildQuickActionGrid(Icons.medication, AppLocalizations.get('reminder_type_medicine'), AppColors.medicine, 'medicine'),
                _buildQuickActionGrid(Icons.local_hospital, AppLocalizations.get('reminder_type_vet'), AppColors.vet, 'vet'),
                _buildQuickActionGrid(Icons.content_cut, AppLocalizations.get('reminder_type_grooming'), AppColors.grooming, 'grooming'),
                _buildQuickActionGrid(Icons.restaurant, AppLocalizations.get('reminder_type_food'), AppColors.food, 'food'),
                _buildQuickActionGrid(Icons.water_drop_rounded, AppLocalizations.get('reminder_type_water'), AppColors.water, 'water'),
                _buildQuickActionGrid(Icons.cleaning_services_rounded, AppLocalizations.get('reminder_type_litter_cleaning'), AppColors.litterCleaning, 'litter_cleaning'),
                _buildQuickActionGrid(Icons.more_horiz_rounded, AppLocalizations.get('more_categories'), AppColors.info, null),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionGrid(IconData icon, String label, Color color, String? type) {
    final isDotCat = label == 'DotCat';

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        if (type == 'weight') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => WeightScreen(cat: _currentPet)),
          );
        } else if (type == null) {
          // Kategori seçim modalı göster
          _showCategorySelectionModal();
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddReminderScreen(
              preselectedCatId: _petId,
              initialType: type,
            )),
          );
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.8)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isDotCat
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset('assets/images/logo.png', width: 28, height: 28),
                    )
                  : Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
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

  void _showCategorySelectionModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categories = getReminderCategories(_petType);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
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
                    AppLocalizations.get('select_category'),
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [category.color, category.color.withOpacity(0.8)]),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(category.icon, color: Colors.white, size: 22),
                      ),
                      title: Text(
                        category.name,
                        style: TextStyle(fontWeight: FontWeight.bold, color: category.color),
                      ),
                      subtitle: Text(
                        '${category.types.length} ${AppLocalizations.get('types')}',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                      ),
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: category.types.map((type) {
                            return InkWell(
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => AddReminderScreen(
                                    preselectedCatId: _petId,
                                    initialType: type.value,
                                  )),
                                );
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
                          }).toList(),
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

  String _getFrequencyText(String frequency) {
    switch (frequency) {
      case 'once': return AppLocalizations.get('once');
      case 'daily': return AppLocalizations.get('daily');
      case 'weekly': return AppLocalizations.get('weekly');
      case 'monthly': return AppLocalizations.get('monthly');
      case 'quarterly': return AppLocalizations.get('quarterly');
      case 'biannual': return AppLocalizations.get('biannual');
      case 'yearly': return AppLocalizations.get('yearly');
      default:
        // Handle custom_X format (e.g., custom_2, custom_14)
        if (frequency.startsWith('custom_')) {
          final days = int.tryParse(frequency.substring(7));
          if (days != null) {
            return AppLocalizations.get('every_x_days_format').replaceAll('{days}', days.toString());
          }
        }
        return frequency;
    }
  }

  String _getRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    final diff = targetDate.difference(today).inDays;

    if (diff == 0) return AppLocalizations.get('today');
    if (diff == 1) return AppLocalizations.get('tomorrow');
    if (diff == -1) return AppLocalizations.get('yesterday');
    if (diff < 0) return AppLocalizations.get('x_days_ago').replaceAll('{days}', '${-diff}');
    if (diff <= 7) return AppLocalizations.get('in_x_days').replaceAll('{days}', '$diff');
    return DateHelper.formatDate(date);
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  bool _isTomorrow(DateTime date) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return date.year == tomorrow.year && date.month == tomorrow.month && date.day == tomorrow.day;
  }

  int _daysSince(DateTime date) {
    return DateTime.now().difference(date).inDays;
  }

  String _getWeightStatus(List weights) {
    if (weights.isEmpty) return 'warning';
    final days = _daysSince(weights.first.recordedAt);
    if (days <= 14) return 'good';
    if (days <= 30) return 'warning';
    return 'bad';
  }

  String _getVaccineStatus(List<Reminder> vaccines) {
    if (vaccines.isEmpty) return 'warning';
    final upcoming = vaccines.where((v) => v.nextDate != null && v.nextDate!.isAfter(DateTime.now())).toList();
    if (upcoming.isEmpty) return 'warning';
    return 'good';
  }

  String _getMedicineStatus(List<Reminder> medicines) {
    if (medicines.isEmpty) return 'warning';
    return 'good';
  }

  String _getNextVaccineText(List<Reminder> vaccines) {
    final upcoming = vaccines.where((v) => v.nextDate != null && v.nextDate!.isAfter(DateTime.now())).toList();
    if (upcoming.isEmpty) return vaccines.isEmpty ? AppLocalizations.get('add_vaccine_record') : AppLocalizations.get('no_upcoming_vaccine');
    upcoming.sort((a, b) => a.nextDate!.compareTo(b.nextDate!));
    return AppLocalizations.get('next_colon').replaceAll('{date}', _getRelativeDate(upcoming.first.nextDate!));
  }

  String _getNextMedicineText(List<Reminder> medicines) {
    final upcoming = medicines.where((m) => m.nextDate != null && m.nextDate!.isAfter(DateTime.now())).toList();
    if (upcoming.isEmpty) return medicines.isEmpty ? AppLocalizations.get('add_reminder') : AppLocalizations.get('no_upcoming_short');
    upcoming.sort((a, b) => a.nextDate!.compareTo(b.nextDate!));
    return AppLocalizations.get('next_colon').replaceAll('{date}', _getRelativeDate(upcoming.first.nextDate!));
  }
}
