import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/localization.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/services/haptic_service.dart';
import '../../../data/models/cat.dart';
import '../../../data/models/reminder.dart';
import '../../reminders/providers/reminders_provider.dart';
import '../../weight/providers/weight_provider.dart';
import '../../weight/presentation/weight_screen.dart';

bool _photoExists(String? path) {
  if (path == null || path.isEmpty) return false;
  if (path.startsWith('http://') || path.startsWith('https://')) return true;
  return File(path).existsSync();
}

/// Kapsamlı Sağlık Özeti Ekranı
class HealthSummaryScreen extends ConsumerStatefulWidget {
  final Cat cat;
  const HealthSummaryScreen({super.key, required this.cat});

  @override
  ConsumerState<HealthSummaryScreen> createState() => _HealthSummaryScreenState();
}

class _HealthSummaryScreenState extends ConsumerState<HealthSummaryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    await ref.read(remindersProvider.notifier).loadReminders();
    await ref.read(weightProvider.notifier).loadWeightRecords(widget.cat.id);
  }

  @override
  Widget build(BuildContext context) {
    final allReminders = ref.watch(remindersProvider);
    final weights = ref.watch(weightProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final catReminders = allReminders.where((r) => r.catId == widget.cat.id).toList();
    
    // İstatistikler
    final vaccines = catReminders.where((r) => r.type == 'vaccine').toList();
    final medicines = catReminders.where((r) => r.type == 'medicine').toList();
    final vetVisits = catReminders.where((r) => r.type == 'vet').toList();
    
    // Sağlık skoru hesapla (basit algoritma)
    final healthScore = _calculateHealthScore(catReminders, weights);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Gradient background
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withOpacity(0.8),
                          const Color(0xFF2DD4BF),
                        ],
                      ),
                    ),
                  ),
                  
                  // Pattern overlay
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _PatternPainter(),
                    ),
                  ),
                  
                  // Content
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              // Cat avatar
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: _photoExists(widget.cat.photoPath)
                                      ? (widget.cat.photoPath!.startsWith('http')
                                          ? CachedNetworkImage(
                                              imageUrl: widget.cat.photoPath!,
                                              fit: BoxFit.cover,
                                            )
                                          : Image.file(
                                              File(widget.cat.photoPath!),
                                              fit: BoxFit.cover,
                                            ))
                                      : const Icon(Icons.pets, color: AppColors.primary, size: 30),
                                ),
                              ),
                              const SizedBox(width: 16),
                              
                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${widget.cat.name} Sağlık Özeti',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateHelper.getAge(widget.cat.birthDate),
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Health Score Card
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -30),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildHealthScoreCard(healthScore, isDark),
              ),
            ),
          ),

          // Quick Stats
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildQuickStatCard(
                      icon: Icons.vaccines,
                      label: 'Aşılar',
                      value: vaccines.length.toString(),
                      color: AppColors.vaccine,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuickStatCard(
                      icon: Icons.medication,
                      label: 'İlaçlar',
                      value: medicines.length.toString(),
                      color: AppColors.medicine,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuickStatCard(
                      icon: Icons.local_hospital,
                      label: 'Veteriner',
                      value: vetVisits.length.toString(),
                      color: AppColors.vet,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
          ),

          // Weight Section
          if (weights.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _buildWeightSection(weights, isDark),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
            ),

          // Upcoming Reminders
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildUpcomingSection(catReminders, isDark),
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
          ),

          // Vaccine History
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildVaccineHistorySection(vaccines, isDark),
            ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2, end: 0),
          ),

          // Health Tips
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildHealthTipsSection(isDark),
            ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0),
          ),

          // Age-based recommendations
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: _buildAgeRecommendationsSection(isDark),
            ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.2, end: 0),
          ),
        ],
      ),
    );
  }

  int _calculateHealthScore(List<Reminder> reminders, List<dynamic> weights) {
    int score = 60; // Base score
    
    // Aşı kayıtları (+10)
    if (reminders.any((r) => r.type == 'vaccine')) score += 10;
    
    // Kilo takibi (+10)
    if (weights.isNotEmpty) score += 10;
    
    // Son 30 günde kilo kaydı (+10)
    if (weights.isNotEmpty) {
      final recentWeight = weights.first;
      if (DateTime.now().difference(recentWeight.recordedAt).inDays <= 30) {
        score += 10;
      }
    }
    
    // Düzenli veteriner ziyareti (+10)
    if (reminders.any((r) => r.type == 'vet')) score += 10;
    
    return score.clamp(0, 100);
  }

  Widget _buildHealthScoreCard(int score, bool isDark) {
    Color scoreColor;
    String scoreLabel;
    IconData scoreIcon;
    
    if (score >= 80) {
      scoreColor = AppColors.success;
      scoreLabel = 'Mükemmel';
      scoreIcon = Icons.sentiment_very_satisfied;
    } else if (score >= 60) {
      scoreColor = AppColors.warning;
      scoreLabel = 'İyi';
      scoreIcon = Icons.sentiment_satisfied;
    } else {
      scoreColor = AppColors.error;
      scoreLabel = 'Dikkat Gerekli';
      scoreIcon = Icons.sentiment_dissatisfied;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // Circular Progress
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 8,
                    backgroundColor: scoreColor.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation(scoreColor),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$score',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: scoreColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(scoreIcon, color: scoreColor, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      scoreLabel,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Sağlık skoru düzenli bakım ve takiplere göre hesaplanır.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildQuickStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
            ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightSection(List<dynamic> weights, bool isDark) {
    final latestWeight = weights.first.weight;
    final previousWeight = weights.length > 1 ? weights[1].weight : null;
    final change = previousWeight != null ? latestWeight - previousWeight : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
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
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.monitor_weight, color: AppColors.warning),
              ),
              const SizedBox(width: 12),
              const Text(
                'Kilo Takibi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => WeightScreen(cat: widget.cat)),
                ),
                child: const Text('Detay'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Current weight
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${latestWeight.toStringAsFixed(1)}',
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'kg',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (change != null) ...[
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: change >= 0 
                        ? Colors.green.withOpacity(0.1) 
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        change >= 0 ? Icons.trending_up : Icons.trending_down,
                        size: 16,
                        color: change >= 0 ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)} kg',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: change >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          
          // Chart
          if (weights.length >= 2) ...[
            const SizedBox(height: 20),
            SizedBox(
              height: 150,
              child: _buildWeightChart(weights),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeightChart(List<dynamic> weights) {
    final chartData = weights.take(10).toList().reversed.toList();
    
    final spots = chartData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.weight);
    }).toList();
    
    final minY = chartData.map((w) => w.weight).reduce((a, b) => a < b ? a : b) - 0.5;
    final maxY = chartData.map((w) => w.weight).reduce((a, b) => a > b ? a : b) + 0.5;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 0.5,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withOpacity(0.2),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(1),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: chartData.length - 1.0,
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.warning,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.warning,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.warning.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingSection(List<Reminder> reminders, bool isDark) {
    final upcomingReminders = reminders.where((r) {
      final next = r.nextDate;
      if (next == null) return false;
      return next.isAfter(DateTime.now()) && 
             next.isBefore(DateTime.now().add(const Duration(days: 30)));
    }).take(5).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
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
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.calendar_today, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              const Text(
                'Yaklaşan Hatırlatmalar',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (upcomingReminders.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.event_available,
                      size: 48,
                      color: AppColors.textSecondary.withOpacity(0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Yaklaşan hatırlatma yok',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...upcomingReminders.map((r) => _buildReminderItem(r, isDark)),
        ],
      ),
    );
  }

  Widget _buildReminderItem(Reminder reminder, bool isDark) {
    final typeColor = _getTypeColor(reminder.type);
    final typeIcon = _getTypeIcon(reminder.type);
    final daysUntil = reminder.nextDate != null 
        ? reminder.nextDate!.difference(DateTime.now()).inDays
        : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(typeIcon, color: typeColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  reminder.nextDate != null 
                      ? DateHelper.formatDate(reminder.nextDate!)
                      : '',
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
              color: daysUntil <= 3 ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              daysUntil == 0 ? 'Bugün' : '$daysUntil gün',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: daysUntil <= 3 ? Colors.orange : Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVaccineHistorySection(List<Reminder> vaccines, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
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
                  color: AppColors.vaccine.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.vaccines, color: AppColors.vaccine),
              ),
              const SizedBox(width: 12),
              const Text(
                'Aşı Geçmişi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (vaccines.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.vaccines_outlined,
                      size: 48,
                      color: AppColors.textSecondary.withOpacity(0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Henüz aşı kaydı yok',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...vaccines.take(5).map((v) => _buildVaccineItem(v, isDark)),
        ],
      ),
    );
  }

  Widget _buildVaccineItem(Reminder vaccine, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: AppColors.vaccine,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              vaccine.title,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            DateHelper.formatDate(vaccine.createdAt),
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthTipsSection(bool isDark) {
    final tips = _getHealthTips();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.success.withOpacity(0.1),
            AppColors.primary.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.lightbulb, color: AppColors.success),
              ),
              const SizedBox(width: 12),
              const Text(
                'Sağlık İpuçları',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          ...tips.map((tip) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle, color: AppColors.success, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tip,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  List<String> _getHealthTips() {
    // Yaşa göre ipuçları
    final birthDate = widget.cat.birthDate;
    final ageInMonths = DateTime.now().difference(birthDate).inDays ~/ 30;
    
    if (ageInMonths < 12) {
      return [
        'Yavru kediler için düzenli aşı takvimi çok önemlidir',
        'Yüksek proteinli mama tercih edin',
        'Günlük oyun aktiviteleri gelişimi destekler',
        'İlk yaşta kısırlaştırma düşünülebilir',
      ];
    } else if (ageInMonths < 84) { // 7 yaş altı
      return [
        'Yılda en az bir veteriner kontrolü yapın',
        'Diş sağlığını düzenli kontrol edin',
        'İdeal kiloyu korumaya dikkat edin',
        'Günlük fiziksel aktivite sağlayın',
      ];
    } else {
      return [
        'Yaşlı kediler için 6 ayda bir kontrol önerilir',
        'Eklem sağlığı için uygun beslenme önemli',
        'Davranış değişikliklerini takip edin',
        'Sıcak ve rahat dinlenme alanları sağlayın',
      ];
    }
  }

  Widget _buildAgeRecommendationsSection(bool isDark) {
    final ageInMonths = DateTime.now().difference(widget.cat.birthDate).inDays ~/ 30;
    final ageCategory = _getAgeCategory(ageInMonths);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
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
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Yaşa Göre Öneriler',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      ageCategory.label,
                      style: TextStyle(
                        fontSize: 13,
                        color: ageCategory.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          ...ageCategory.recommendations.map((rec) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(rec.icon, color: ageCategory.color, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rec.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        rec.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  _AgeCategory _getAgeCategory(int ageInMonths) {
    if (ageInMonths < 12) {
      return _AgeCategory(
        label: 'Yavru Kedi (0-1 yaş)',
        color: Colors.orange,
        recommendations: [
          _Recommendation(Icons.vaccines, 'Aşı Takvimi', 'Temel aşılar 8, 12 ve 16. haftalarda'),
          _Recommendation(Icons.restaurant, 'Beslenme', 'Yavru kedilere özel yüksek proteinli mama'),
          _Recommendation(Icons.pets, 'Kısırlaştırma', '6. aydan itibaren değerlendirilebilir'),
        ],
      );
    } else if (ageInMonths < 84) {
      return _AgeCategory(
        label: 'Yetişkin Kedi (1-7 yaş)',
        color: AppColors.primary,
        recommendations: [
          _Recommendation(Icons.local_hospital, 'Yıllık Kontrol', 'Yılda en az bir veteriner ziyareti'),
          _Recommendation(Icons.monitor_weight, 'Kilo Kontrolü', 'İdeal kiloyu korumak önemli'),
          _Recommendation(Icons.cleaning_services, 'Diş Bakımı', 'Düzenli diş kontrolleri'),
        ],
      );
    } else {
      return _AgeCategory(
        label: 'Yaşlı Kedi (7+ yaş)',
        color: Colors.purple,
        recommendations: [
          _Recommendation(Icons.medical_services, '6 Aylık Kontrol', 'Daha sık veteriner takibi'),
          _Recommendation(Icons.favorite, 'Kalp Sağlığı', 'Kardiyak kontroller önemli'),
          _Recommendation(Icons.accessibility, 'Eklem Sağlığı', 'Eklem desteği içeren mama'),
        ],
      );
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'vaccine': return AppColors.vaccine;
      case 'medicine': return AppColors.medicine;
      case 'vet': return AppColors.vet;
      case 'food': return AppColors.food;
      default: return AppColors.primary;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'vaccine': return Icons.vaccines;
      case 'medicine': return Icons.medication;
      case 'vet': return Icons.local_hospital;
      case 'food': return Icons.restaurant;
      default: return Icons.event;
    }
  }
}

class _AgeCategory {
  final String label;
  final Color color;
  final List<_Recommendation> recommendations;

  _AgeCategory({
    required this.label,
    required this.color,
    required this.recommendations,
  });
}

class _Recommendation {
  final IconData icon;
  final String title;
  final String description;

  _Recommendation(this.icon, this.title, this.description);
}

class _PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    // Paw print pattern
    const spacing = 60.0;
    for (double x = 0; x < size.width + spacing; x += spacing) {
      for (double y = 0; y < size.height + spacing; y += spacing) {
        final offset = (y ~/ spacing) % 2 == 0 ? 0.0 : spacing / 2;
        _drawPawPrint(canvas, Offset(x + offset, y), 8, paint);
      }
    }
  }

  void _drawPawPrint(Canvas canvas, Offset center, double size, Paint paint) {
    // Main pad
    canvas.drawOval(
      Rect.fromCenter(center: center, width: size * 1.5, height: size * 1.2),
      paint,
    );

    // Toes
    final toeOffsets = [
      Offset(center.dx - size * 0.7, center.dy - size * 0.8),
      Offset(center.dx - size * 0.2, center.dy - size * 1.1),
      Offset(center.dx + size * 0.2, center.dy - size * 1.1),
      Offset(center.dx + size * 0.7, center.dy - size * 0.8),
    ];

    for (final offset in toeOffsets) {
      canvas.drawCircle(offset, size * 0.35, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

