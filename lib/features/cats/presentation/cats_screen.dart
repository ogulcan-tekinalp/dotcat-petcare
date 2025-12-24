import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/localization.dart';
import '../../../core/utils/page_transitions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/constants/app_spacing.dart';
import '../providers/cats_provider.dart';
import 'add_cat_screen.dart';
import 'cat_detail_screen.dart';

class CatsScreen extends ConsumerWidget {
  const CatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(catsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.get('my_cats'))),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(catsProvider.notifier).loadCats();
        },
        child: cats.isEmpty
            ? _buildEmptyState(context, isDark)
            : ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(), // iOS-style smooth scrolling
                ),
                itemCount: cats.length,
                itemBuilder: (context, index) {
                  final cat = cats[index];
                  return _buildCatCard(context, cat, isDark);
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          PageTransitions.fadeSlide(page: const AddCatScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCatCard(BuildContext context, dynamic cat, bool isDark) {
    final isUrl = cat.photoPath != null && (cat.photoPath!.startsWith('http://') || cat.photoPath!.startsWith('https://'));
    
    return AppCard(
      onTap: () => Navigator.push(
        context,
        PageTransitions.slide(page: CatDetailScreen(cat: cat)),
      ),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
            child: cat.photoPath != null
                ? (isUrl
                    ? CachedNetworkImage(
                        imageUrl: cat.photoPath!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 60,
                          height: 60,
                          color: AppColors.primary.withOpacity(0.1),
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.pets, size: 30, color: AppColors.primary),
                        ),
                      )
                    : Image.file(
                        File(cat.photoPath!),
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.pets, size: 30, color: AppColors.primary),
                        ),
                      ))
                : Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.pets, size: 30, color: AppColors.primary),
                  ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cat.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Icon(Icons.cake, size: AppSpacing.iconXs, color: context.textSecondary),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      cat.ageText,
                      style: TextStyle(fontSize: 13, color: context.textSecondary),
                    ),
                    if (cat.breed != null) ...[
                      const SizedBox(width: AppSpacing.md),
                      Icon(Icons.pets, size: AppSpacing.iconXs, color: context.textSecondary),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          cat.breed!,
                          style: TextStyle(fontSize: 13, color: context.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                if (cat.weight != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Icon(Icons.monitor_weight, size: AppSpacing.iconXs, color: context.textSecondary),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '${cat.weight} kg',
                        style: TextStyle(fontSize: 13, color: context.textSecondary),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: context.textSecondary),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return AppEmptyState(
      icon: Icons.pets,
      title: AppLocalizations.get('no_cats_yet'),
      subtitle: AppLocalizations.get('add_your_cat'),
      actionLabel: AppLocalizations.get('add_cat'),
      onAction: () => Navigator.push(
        context,
        PageTransitions.fadeSlide(page: const AddCatScreen()),
      ),
    );
  }
}
