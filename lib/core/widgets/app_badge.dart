import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../constants/app_spacing.dart';

/// Reusable badge widget
class AppBadge extends StatelessWidget {
  final String text;
  final Color? color;
  final Color? textColor;
  final double? fontSize;

  const AppBadge({
    super.key,
    required this.text,
    this.color,
    this.textColor,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = color ?? AppColors.primary;
    final badgeTextColor = textColor ?? Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: badgeTextColor,
          fontSize: fontSize ?? 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

