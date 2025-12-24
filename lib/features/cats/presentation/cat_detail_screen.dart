import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/localization.dart';
import '../../../core/utils/date_helper.dart';
import '../../../core/utils/page_transitions.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../data/models/cat.dart';
import '../../reminders/providers/reminders_provider.dart';
import '../../weight/providers/weight_provider.dart';
import '../../reminders/presentation/add_reminder_screen.dart';
import '../../reminders/presentation/record_detail_screen.dart';
import '../../weight/presentation/weight_screen.dart';
import '../providers/cats_provider.dart';
import 'edit_cat_screen.dart';

bool _photoExists(String? path) {
  if (path == null || path.isEmpty) return false;
  // URL ise her zaman true
  if (path.startsWith('http://') || path.startsWith('https://')) return true;
  return File(path).existsSync();
}

class CatDetailScreen extends ConsumerStatefulWidget {
  final Cat cat;
  const CatDetailScreen({super.key, required this.cat});

  @override
  ConsumerState<CatDetailScreen> createState() => _CatDetailScreenState();
}

class _CatDetailScreenState extends ConsumerState<CatDetailScreen> {
  String? _selectedFilter;
  late Cat _currentCat;

  @override
  void initState() {
    super.initState();
    _currentCat = widget.cat;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    // loadRemindersForCat artık state'i değiştirmiyor - bug düzeltildi
    // Tüm reminder'lar zaten yüklü, sadece filtreleme yapılıyor
    await ref.read(remindersProvider.notifier).loadReminders();
    await ref.read(weightProvider.notifier).loadWeightRecords(_currentCat.id);
  }

  @override
  Widget build(BuildContext context) {
    final allReminders = ref.watch(remindersProvider);
    final weights = ref.watch(weightProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final allRecords = allReminders.where((r) => r.catId == _currentCat.id).toList();
    final filteredRecords = _selectedFilter == null 
        ? allRecords 
        : allRecords.where((r) => r.type == _selectedFilter).toList();

    // En son kayıtlar önce
    filteredRecords.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () async {
                  final updatedCat = await Navigator.push<Cat>(
                    context,
                    PageTransitions.slide(page: EditCatScreen(cat: _currentCat)),
                  );
                  if (updatedCat != null) {
                    setState(() => _currentCat = updatedCat);
                  }
                },
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(AppLocalizations.get('delete_cat')),
                        content: Text(AppLocalizations.get('delete_cat_confirm')),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.get('cancel'))),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppLocalizations.get('delete'), style: const TextStyle(color: AppColors.error))),
                        ],
                      ),
                    );
                    if (confirm == true && mounted) {
                      await ref.read(catsProvider.notifier).deleteCat(_currentCat.id);
                      if (mounted) Navigator.pop(context);
                    }
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete, color: AppColors.error, size: 20), const SizedBox(width: 8), Text(AppLocalizations.get('delete'), style: const TextStyle(color: AppColors.error))])),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (_photoExists(_currentCat.photoPath))
                    _currentCat.photoPath!.startsWith('http')
                        ? CachedNetworkImage(
                            imageUrl: _currentCat.photoPath!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [AppColors.primary.withOpacity(0.8), AppColors.primary],
                                ),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(color: Colors.white38),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [AppColors.primary.withOpacity(0.8), AppColors.primary],
                                ),
                              ),
                              child: const Center(child: Icon(Icons.pets, size: 80, color: Colors.white38)),
                            ),
                          )
                        : Image.file(File(_currentCat.photoPath!), fit: BoxFit.cover)
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.primary.withOpacity(0.8), AppColors.primary],
                        ),
                      ),
                      child: const Center(child: Icon(Icons.pets, size: 80, color: Colors.white38)),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_currentCat.name, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                            child: Text(DateHelper.getAge(_currentCat.birthDate), style: const TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                          if (_currentCat.breed != null && _currentCat.breed!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                              child: Text(_currentCat.breed!, style: const TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                          ],
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Quick Actions
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                _buildQuickActionButton(Icons.add, AppLocalizations.get('add_record'), AppColors.primary, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => AddReminderScreen(preselectedCatId: _currentCat.id)));
                }),
                const SizedBox(width: 12),
                _buildQuickActionButton(Icons.monitor_weight, AppLocalizations.get('weight'), AppColors.warning, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => WeightScreen(cat: _currentCat)));
                }),
              ]),
            ),
          ),

          // Filter chips
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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

          // Records header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Text(AppLocalizations.get('records'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('${filteredRecords.length} ${AppLocalizations.get('items')}', style: TextStyle(fontSize: 13, color: context.textSecondary)),
                ],
              ),
            ),
          ),

          // Records list
          if (filteredRecords.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(children: [
                    Icon(Icons.inbox_outlined, size: 48, color: context.textSecondary),
                    const SizedBox(height: 16),
                    Text(AppLocalizations.get('no_records'), style: TextStyle(color: context.textSecondary)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddReminderScreen(preselectedCatId: _currentCat.id))),
                      icon: const Icon(Icons.add),
                      label: Text(AppLocalizations.get('add_record')),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    ),
                  ]),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final record = filteredRecords[index];
                  return _buildRecordCard(record, isDark);
                }, childCount: filteredRecords.length),
              ),
            ),

          // Weight summary with chart
          if (weights.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WeightScreen(cat: _currentCat))),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.monitor_weight, color: AppColors.warning),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(AppLocalizations.get('latest_weight'), style: TextStyle(fontSize: 12, color: context.textSecondary)),
                              Text('${weights.first.weight.toStringAsFixed(2)} kg', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            ]),
                          ),
                          Icon(Icons.chevron_right, color: context.textSecondary),
                        ]),
                        if (weights.length >= 2) ...[
                          const SizedBox(height: 16),
                          Text(AppLocalizations.get('weight_trend'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textSecondary)),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 120,
                            child: _buildWeightChart(weights),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddReminderScreen(preselectedCatId: _currentCat.id))),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildQuickActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? color.withOpacity(0.15) : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String? type, String label, IconData icon) {
    final isSelected = _selectedFilter == type;
    Color chipColor = AppColors.primary;
    if (type == 'dotcat_complete') chipColor = AppColors.dotcat;
    else if (type == 'vaccine') chipColor = AppColors.vaccine;
    else if (type == 'medicine') chipColor = AppColors.medicine;
    else if (type == 'vet') chipColor = AppColors.vet;
    else if (type == 'food') chipColor = AppColors.food;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? chipColor : Colors.grey.shade300),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: isSelected ? chipColor : AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 13, color: isSelected ? chipColor : AppColors.textSecondary, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
        ]),
      ),
    );
  }

  Widget _buildRecordCard(dynamic record, bool isDark) {
    Color typeColor;
    IconData icon;
    switch (record.type) {
      case 'vaccine': typeColor = AppColors.vaccine; icon = Icons.vaccines; break;
      case 'medicine': typeColor = AppColors.medicine; icon = Icons.medication; break;
      case 'vet': typeColor = AppColors.vet; icon = Icons.local_hospital; break;
      case 'food': typeColor = AppColors.food; icon = Icons.restaurant; break;
      case 'dotcat_complete': typeColor = AppColors.dotcat; icon = Icons.pets; break;
      default: typeColor = AppColors.primary; icon = Icons.event;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecordDetailScreen(record: record, catName: _currentCat.name))),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: typeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: typeColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(record.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.repeat, size: 12, color: context.textSecondary),
                  const SizedBox(width: 4),
                  Text(_getFrequencyText(record.frequency), style: TextStyle(fontSize: 12, color: context.textSecondary)),
                  const SizedBox(width: 12),
                  Icon(Icons.access_time, size: 12, color: context.textSecondary),
                  const SizedBox(width: 4),
                  Text(record.time, style: TextStyle(fontSize: 12, color: context.textSecondary)),
                ]),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(DateHelper.formatShortDate(record.createdAt), style: TextStyle(fontSize: 11, color: context.textSecondary)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: typeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(_getTypeText(record.type), style: TextStyle(fontSize: 10, color: typeColor, fontWeight: FontWeight.w500)),
              ),
            ]),
          ]),
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
      default: return frequency;
    }
  }

  String _getTypeText(String type) {
    switch (type) {
      case 'vaccine': return AppLocalizations.get('vaccine');
      case 'medicine': return AppLocalizations.get('medicine');
      case 'vet': return AppLocalizations.get('vet');
      case 'food': return AppLocalizations.get('food');
      case 'dotcat_complete': return 'dotcat';
      default: return type;
    }
  }

  Widget _buildWeightChart(List<dynamic> weights) {
    if (weights.length < 2) return const SizedBox.shrink();
    
    // Son 10 kaydı al ve ters çevir (en eski önce)
    final chartData = weights.take(10).toList().reversed.toList();
    final minWeight = chartData.map((w) => w.weight).reduce((a, b) => a < b ? a : b);
    final maxWeight = chartData.map((w) => w.weight).reduce((a, b) => a > b ? a : b);
    final weightRange = maxWeight - minWeight;
    final padding = weightRange * 0.2; // %20 padding
    
    return CustomPaint(
      painter: WeightChartPainter(
        data: chartData,
        minWeight: minWeight - padding,
        maxWeight: maxWeight + padding,
        color: AppColors.warning,
      ),
      size: Size.infinite,
    );
  }
}

class WeightChartPainter extends CustomPainter {
  final List<dynamic> data;
  final double minWeight;
  final double maxWeight;
  final Color color;

  WeightChartPainter({
    required this.data,
    required this.minWeight,
    required this.maxWeight,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();
    
    final stepX = size.width / (data.length - 1);
    final weightRange = maxWeight - minWeight;

    // İlk noktayı ayarla
    final firstY = size.height - ((data[0].weight - minWeight) / weightRange * size.height);
    path.moveTo(0, firstY);
    fillPath.moveTo(0, firstY);

    // Çizgiyi çiz
    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - ((data[i].weight - minWeight) / weightRange * size.height);
      
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // Fill path'i tamamla
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    // Fill'i çiz
    canvas.drawPath(fillPath, fillPaint);
    
    // Çizgiyi çiz
    canvas.drawPath(path, paint);

    // Noktaları çiz
    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - ((data[i].weight - minWeight) / weightRange * size.height);
      canvas.drawCircle(Offset(x, y), 3, pointPaint);
    }
  }

  @override
  bool shouldRepaint(WeightChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.minWeight != minWeight ||
        oldDelegate.maxWeight != maxWeight;
  }
}
