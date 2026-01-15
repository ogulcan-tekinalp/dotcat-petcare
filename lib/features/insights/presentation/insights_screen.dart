import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/insights_service.dart';
import '../../../core/services/insights_notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/localization.dart';
import '../../../core/widgets/app_toast.dart';
import '../../cats/providers/cats_provider.dart';
import '../../reminders/providers/reminders_provider.dart';
import '../../reminders/providers/completions_provider.dart';
import '../../weight/providers/weight_provider.dart';
import '../../reminders/presentation/add_reminder_screen.dart';
import '../../weight/presentation/weight_screen.dart';

/// Akıllı Öneriler Ekranı - Gerçek zamanlı güncel verilerle
class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  bool _isLoading = true;
  List<Insight> _insights = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Tüm verileri yeniden yükle
      await ref.read(remindersProvider.notifier).loadReminders();
      
      // Her kedi için kilo verilerini yükle
      final cats = ref.read(catsProvider);
      for (final cat in cats) {
        await ref.read(weightProvider.notifier).loadWeightRecords(cat.id);
      }
      
      // Insights'ları güncelle
      _generateInsights();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateInsights() async {
    final cats = ref.read(catsProvider);
    final reminders = ref.read(remindersProvider);
    final completions = ref.read(completionsProvider);
    final weights = ref.read(weightProvider);

    final insights = await InsightsService.instance.generateInsights(
      cats: cats,
      reminders: reminders,
      weightRecords: weights,
      completedDates: completions.completedDates,
    );

    // Filter out snoozed AND dismissed insights
    final filteredInsights = <Insight>[];
    for (final insight in insights) {
      final isSnoozed = await InsightsNotificationService.instance.isInsightSnoozed(insight.id);
      final isDismissed = await InsightsNotificationService.instance.isInsightDismissed(insight.id);

      if (!isSnoozed && !isDismissed) {
        filteredInsights.add(insight);
      }
    }

    setState(() => _insights = filteredInsights);
  }

  @override
  Widget build(BuildContext context) {
    // Provider'ları watch et - değişince rebuild olsun
    ref.listen(remindersProvider, (_, __) => _generateInsights());
    ref.listen(completionsProvider, (_, __) => _generateInsights());
    ref.listen(weightProvider, (_, __) => _generateInsights());
    ref.listen(catsProvider, (_, __) => _generateInsights());

    final cats = ref.watch(catsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(AppLocalizations.get('insights')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _insights.isEmpty
                ? _buildEmptyState(isDark)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _insights.length,
                    itemBuilder: (context, index) {
                      final insight = _insights[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildInsightCard(context, insight, isDark, cats),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 80,
              color: AppColors.success.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.get('insights_empty_title'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.get('insights_empty_message'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard(BuildContext context, Insight insight, bool isDark, List cats) {
    return GestureDetector(
      onTap: insight.actionRoute != null
          ? () => _handleAction(context, insight, cats)
          : null,
      onLongPress: () => _showInsightOptions(context, insight),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: insight.priority == InsightPriority.high 
                ? insight.color.withOpacity(0.5)
                : Colors.transparent,
            width: insight.priority == InsightPriority.high ? 2 : 0,
          ),
          boxShadow: isDark ? null : [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: insight.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(insight.icon, color: insight.color, size: 24),
              ),
              const SizedBox(width: 16),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Priority badge + Title
                    Row(
                      children: [
                        if (insight.priority == InsightPriority.high)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              AppLocalizations.get('important'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            insight.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        // Dismiss button
                        IconButton(
                          icon: Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                          onPressed: () => _dismissInsight(insight),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Description
                    Text(
                      insight.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),

                    // Action button
                    if (insight.actionLabel != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: insight.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              insight.actionLabel!,
                              style: TextStyle(
                                color: insight.color,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward, color: insight.color, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, Insight insight, List cats) {
    final route = insight.actionRoute;
    final data = insight.actionData;
    
    if (route == null) return;
    
    // Hatırlatıcı ekleme
    if (route.contains('/reminder/add')) {
      String? catId = data?['catId'];
      String? type = data?['type'];
      String? title = data?['title'];
      String? subType = data?['subType'];
      
      // Eğer catId yoksa ve kedi varsa ilk kediyi seç
      if (catId == null && cats.isNotEmpty) {
        catId = cats.first.id;
      }
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddReminderScreen(
            initialType: type,
            preselectedCatId: catId,
            initialTitle: title,
            initialSubType: subType,
          ),
        ),
      ).then((_) => _loadData()); // Geri dönünce yenile
      return;
    }
    
    // Kilo ekleme
    if (route.contains('/weight/add')) {
      if (cats.isEmpty) return;
      
      final catId = data?['catId'];
      dynamic targetCat;
      
      if (catId != null) {
        try {
          targetCat = cats.firstWhere((c) => c.id == catId);
        } catch (_) {
          targetCat = cats.first;
        }
      } else {
        targetCat = cats.first;
      }
      
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => WeightScreen(cat: targetCat)),
      ).then((_) => _loadData()); // Geri dönünce yenile
      return;
    }
    
    // Kedi ekleme
    if (route == '/cat/add') {
      Navigator.pop(context);
      return;
    }
    
    // Ana sayfa
    if (route == '/home') {
      Navigator.pop(context);
      return;
    }
  }

  void _showInsightOptions(BuildContext context, Insight insight) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          padding: const EdgeInsets.all(20),
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
              Text(
                insight.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.access_time, color: AppColors.info),
                title: Text(AppLocalizations.get('snooze_3days')),
                subtitle: Text(AppLocalizations.get('snooze_3days_subtitle')),
                onTap: () {
                  Navigator.pop(context);
                  _snoozeInsight(insight, days: 3);
                },
              ),
              ListTile(
                leading: const Icon(Icons.access_time, color: AppColors.warning),
                title: Text(AppLocalizations.get('snooze_7days')),
                subtitle: Text(AppLocalizations.get('snooze_7days_subtitle')),
                onTap: () {
                  Navigator.pop(context);
                  _snoozeInsight(insight, days: 7);
                },
              ),
              ListTile(
                leading: const Icon(Icons.close, color: AppColors.error),
                title: Text(AppLocalizations.get('dismiss_insight')),
                subtitle: Text(AppLocalizations.get('dismiss_insight_subtitle')),
                onTap: () {
                  Navigator.pop(context);
                  _dismissInsight(insight);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _snoozeInsight(Insight insight, {required int days}) async {
    await InsightsNotificationService.instance.snoozeInsight(insight.id, days: days);

    if (!mounted) return;

    AppToast.show(
      context,
      message: AppLocalizations.get('snoozed_for_days').replaceAll('{days}', days.toString()),
      type: ToastType.info,
    );

    // Remove from current list
    setState(() {
      _insights.removeWhere((i) => i.id == insight.id);
    });
  }

  Future<void> _dismissInsight(Insight insight) async {
    await InsightsNotificationService.instance.dismissInsight(insight.id);

    if (!mounted) return;

    AppToast.show(
      context,
      message: AppLocalizations.get('insight_dismissed'),
      type: ToastType.success,
    );

    // Remove from current list
    setState(() {
      _insights.removeWhere((i) => i.id == insight.id);
    });
  }
}
