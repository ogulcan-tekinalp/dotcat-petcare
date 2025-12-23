import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/localization.dart';
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
      body: cats.isEmpty
          ? _buildEmptyState(context, isDark)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: cats.length,
              itemBuilder: (context, index) {
                final cat = cats[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildCatCard(context, cat, isDark),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddCatScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCatCard(BuildContext context, dynamic cat, bool isDark) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CatDetailScreen(cat: cat))),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              backgroundImage: cat.photoPath != null ? FileImage(File(cat.photoPath!)) : null,
              child: cat.photoPath == null ? const Icon(Icons.pets, size: 30, color: AppColors.primary) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cat.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.cake, size: 14, color: context.textSecondary),
                      const SizedBox(width: 4),
                      Text(cat.ageText, style: TextStyle(fontSize: 13, color: context.textSecondary)),
                      if (cat.breed != null) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.pets, size: 14, color: context.textSecondary),
                        const SizedBox(width: 4),
                        Flexible(child: Text(cat.breed!, style: TextStyle(fontSize: 13, color: context.textSecondary), overflow: TextOverflow.ellipsis)),
                      ],
                    ],
                  ),
                  if (cat.weight != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.monitor_weight, size: 14, color: context.textSecondary),
                        const SizedBox(width: 4),
                        Text('${cat.weight} kg', style: TextStyle(fontSize: 13, color: context.textSecondary)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.pets, size: 60, color: AppColors.primary.withOpacity(0.5)),
            ),
            const SizedBox(height: 24),
            Text(AppLocalizations.get('no_cats_yet'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(AppLocalizations.get('add_your_cat'), style: TextStyle(fontSize: 14, color: context.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddCatScreen())),
              icon: const Icon(Icons.add),
              label: Text(AppLocalizations.get('add_cat')),
            ),
          ],
        ),
      ),
    );
  }
}
