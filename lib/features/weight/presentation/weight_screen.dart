import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/utils/localization.dart';
import '../../../core/services/insights_service.dart';
import '../../../data/models/cat.dart';
import '../../../data/models/weight_record.dart';
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
    
    // İdeal kilo aralığı
    final insightsService = InsightsService.instance;
    final idealRange = insightsService.getIdealWeightRange(widget.cat);
    final trend = weights.length >= 3 ? insightsService.calculateWeightTrend(weights) : WeightTrend.insufficient;
    
    // Mevcut kilo durumu
    String weightStatus = 'normal';
    Color statusColor = AppColors.success;
    if (latest != null) {
      if (latest.weight < idealRange.min) {
        weightStatus = 'underweight';
        statusColor = AppColors.warning;
      } else if (latest.weight > idealRange.max) {
        weightStatus = 'overweight';
        statusColor = AppColors.error;
      }
    }

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
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // Mevcut kilo kartı
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
          const SizedBox(height: 16),
          
          // İdeal kilo ve trend kartı
          _buildIdealWeightCard(isDark, latest?.weight, idealRange, weightStatus, statusColor, trend),
          const SizedBox(height: 16),

          // Kilo önerileri
          _buildWeightInsights(isDark, weightStatus, trend, latest?.weight, idealRange),
          const SizedBox(height: 24),
          
          if (weights.length >= 2) ...[
            Text(AppLocalizations.get('last_6_months'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              height: 220,
              padding: const EdgeInsets.fromLTRB(8, 24, 16, 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
              ),
              child: _buildLineChart(ref.read(weightProvider.notifier).getLast6Months(), idealRange, isDark),
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
  
  Widget _buildIdealWeightCard(bool isDark, double? currentWeight, IdealWeightRange idealRange, String status, Color statusColor, WeightTrend trend) {
    String statusText;
    IconData statusIcon;
    String trendText;
    IconData trendIcon;
    Color trendColor;
    
    switch (status) {
      case 'underweight':
        statusText = AppLocalizations.get('underweight');
        statusIcon = Icons.warning_amber_rounded;
        break;
      case 'overweight':
        statusText = AppLocalizations.get('overweight');
        statusIcon = Icons.warning_amber_rounded;
        break;
      default:
        statusText = AppLocalizations.get('ideal_weight');
        statusIcon = Icons.check_circle_rounded;
    }
    
    switch (trend) {
      case WeightTrend.increasing:
        trendText = AppLocalizations.get('weight_increasing');
        trendIcon = Icons.trending_up_rounded;
        trendColor = currentWeight != null && currentWeight > idealRange.max 
            ? AppColors.warning : AppColors.info;
        break;
      case WeightTrend.decreasing:
        trendText = AppLocalizations.get('weight_decreasing');
        trendIcon = Icons.trending_down_rounded;
        trendColor = currentWeight != null && currentWeight < idealRange.min 
            ? AppColors.warning : AppColors.info;
        break;
      case WeightTrend.stable:
        trendText = AppLocalizations.get('weight_stable');
        trendIcon = Icons.trending_flat_rounded;
        trendColor = AppColors.success;
        break;
      case WeightTrend.insufficient:
        trendText = AppLocalizations.get('need_more_data');
        trendIcon = Icons.info_outline_rounded;
        trendColor = AppColors.textSecondary;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.get('ideal_range'),
                      style: TextStyle(fontSize: 12, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${idealRange.min.toStringAsFixed(1)} - ${idealRange.max.toStringAsFixed(1)} kg',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getCategoryText(idealRange.category),
                      style: TextStyle(fontSize: 11, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 4),
                        Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(trendIcon, size: 16, color: trendColor),
                      const SizedBox(width: 4),
                      Text(trendText, style: TextStyle(color: trendColor, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // Görsel kilo barı
          if (currentWeight != null) ...[
            const SizedBox(height: 16),
            _buildWeightBar(currentWeight, idealRange, statusColor),
          ],
        ],
      ),
    );
  }
  
  Widget _buildWeightBar(double currentWeight, IdealWeightRange idealRange, Color statusColor) {
    // Bar genişliği: min-2kg ile max+2kg arasında
    final barMin = idealRange.min - 2;
    final barMax = idealRange.max + 2;
    final barRange = barMax - barMin;
    
    // Pozisyonlar (0-1 arası)
    final idealStartPos = (idealRange.min - barMin) / barRange;
    final idealEndPos = (idealRange.max - barMin) / barRange;
    final currentPos = ((currentWeight - barMin) / barRange).clamp(0.0, 1.0);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 24,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return Stack(
                children: [
                  // Alt bar (gri)
                  Container(
                    height: 8,
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  // İdeal aralık (yeşil)
                  Positioned(
                    left: width * idealStartPos,
                    top: 8,
                    child: Container(
                      width: width * (idealEndPos - idealStartPos),
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  // Mevcut kilo işareti
                  Positioned(
                    left: (width * currentPos) - 8,
                    top: 0,
                    child: Container(
                      width: 16,
                      height: 24,
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${barMin.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            Text('${barMax.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
      ],
    );
  }
  
  String _getCategoryText(String category) {
    switch (category) {
      case 'kitten': return AppLocalizations.get('kitten_range');
      case 'senior': return AppLocalizations.get('senior_cat_range');
      default: return AppLocalizations.get('adult_cat_range');
    }
  }
  
  Widget _buildLineChart(List<WeightRecord> weights, IdealWeightRange idealRange, bool isDark) {
    if (weights.isEmpty) return const SizedBox();
    
    // Veriden spot'lar oluştur
    final spots = <FlSpot>[];
    for (int i = 0; i < weights.length; i++) {
      spots.add(FlSpot(i.toDouble(), weights[i].weight));
    }
    
    final maxWeight = weights.map((w) => w.weight).reduce((a, b) => a > b ? a : b);
    final minWeight = weights.map((w) => w.weight).reduce((a, b) => a < b ? a : b);
    
    // Y ekseni için aralık (ideal kilo dahil)
    final yMin = [minWeight - 0.5, idealRange.min - 0.5].reduce((a, b) => a < b ? a : b);
    final yMax = [maxWeight + 0.5, idealRange.max + 0.5].reduce((a, b) => a > b ? a : b);
    
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.1),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 1,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toStringAsFixed(1)}',
                  style: TextStyle(fontSize: 10, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= weights.length) return const Text('');
                final date = weights[index].recordedAt;
                return Text(
                  '${date.day}/${date.month}',
                  style: TextStyle(fontSize: 9, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (weights.length - 1).toDouble(),
        minY: yMin,
        maxY: yMax,
        lineBarsData: [
          // İdeal aralık üst sınırı (noktalı çizgi)
          LineChartBarData(
            spots: [FlSpot(0, idealRange.max), FlSpot((weights.length - 1).toDouble(), idealRange.max)],
            isCurved: false,
            color: AppColors.success.withOpacity(0.5),
            dotData: const FlDotData(show: false),
            dashArray: [5, 5],
            barWidth: 1,
          ),
          // İdeal aralık alt sınırı (noktalı çizgi)
          LineChartBarData(
            spots: [FlSpot(0, idealRange.min), FlSpot((weights.length - 1).toDouble(), idealRange.min)],
            isCurved: false,
            color: AppColors.success.withOpacity(0.5),
            dotData: const FlDotData(show: false),
            dashArray: [5, 5],
            barWidth: 1,
          ),
          // Kilo çizgisi
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppColors.weight,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final weight = weights[index].weight;
                Color dotColor;
                if (weight < idealRange.min) {
                  dotColor = AppColors.warning;
                } else if (weight > idealRange.max) {
                  dotColor = AppColors.error;
                } else {
                  dotColor = AppColors.success;
                }
                return FlDotCirclePainter(
                  radius: 5,
                  color: dotColor,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.weight.withOpacity(0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.spotIndex;
                if (index < 0 || index >= weights.length) return null;
                final record = weights[index];
                return LineTooltipItem(
                  '${record.weight} kg\n${DateHelper.formatDate(record.recordedAt)}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                );
              }).toList();
            },
          ),
        ),
      ),
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

  Widget _buildWeightInsights(bool isDark, String weightStatus, WeightTrend trend, double? currentWeight, IdealWeightRange idealRange) {
    final insights = <Map<String, dynamic>>[];

    // Kilo durumuna göre öneriler
    if (weightStatus == 'overweight') {
      insights.add({
        'icon': Icons.trending_down,
        'color': AppColors.error,
        'title': 'Fazla Kilolu',
        'message': 'Kediniz ideal kilonun üzerinde. Veterinerinizle görüşün.',
      });
      insights.add({
        'icon': Icons.restaurant,
        'color': AppColors.food,
        'title': 'Beslenme',
        'message': 'Günlük mama miktarını azaltmayı düşünün.',
      });
    } else if (weightStatus == 'underweight') {
      insights.add({
        'icon': Icons.trending_up,
        'color': AppColors.warning,
        'title': 'Zayıf',
        'message': 'Kediniz ideal kilonun altında. Veteriner kontrolü önerilir.',
      });
    } else {
      insights.add({
        'icon': Icons.check_circle,
        'color': AppColors.success,
        'title': 'İdeal Kilo',
        'message': 'Kediniz sağlıklı kilo aralığında!',
      });
    }

    // Trend'e göre öneriler
    if (trend == WeightTrend.increasing) {
      insights.add({
        'icon': Icons.fitness_center,
        'color': Colors.orange,
        'title': 'Egzersiz',
        'message': 'Kilo artışı tespit edildi. Oyun ve egzersiz süresini artırın.',
      });
    } else if (trend == WeightTrend.decreasing) {
      insights.add({
        'icon': Icons.medical_services,
        'color': AppColors.vet,
        'title': 'Kontrol',
        'message': 'Kilo kaybı tespit edildi. İştah durumunu kontrol edin.',
      });
    }

    if (insights.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lightbulb_outline, size: 18, color: AppColors.warning),
            const SizedBox(width: 8),
            const Text('Öneriler', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        ...insights.map((insight) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (insight['color'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: (insight['color'] as Color).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (insight['color'] as Color).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(insight['icon'] as IconData, size: 20, color: insight['color'] as Color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        insight['title'] as String,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        insight['message'] as String,
                        style: TextStyle(fontSize: 12, color: context.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }
}
