import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../theme/app_theme.dart';
import '../constants/app_spacing.dart';
import 'app_button.dart';

/// Reusable empty state widget
class AppEmptyState extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;
  final String? lottieAsset; // Optional Lottie animation path

  const AppEmptyState({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconColor,
    this.lottieAsset,
  }) : assert(icon != null || lottieAsset != null, 'Either icon or lottieAsset must be provided');

  @override
  Widget build(BuildContext context) {
    final emptyIconColor = iconColor ?? AppColors.primary.withOpacity(0.5);

    return Semantics(
      label: title,
      hint: subtitle,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (lottieAsset != null)
                SizedBox(
                  width: 200,
                  height: 200,
                  child: Lottie.asset(
                    lottieAsset!,
                    fit: BoxFit.contain,
                    repeat: true,
                  ),
                )
              else if (icon != null)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: emptyIconColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: AppSpacing.iconXl,
                    color: emptyIconColor,
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18 * MediaQuery.textScaleFactorOf(context),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 14 * MediaQuery.textScaleFactorOf(context),
                    color: context.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: actionLabel!,
                  onPressed: onAction!,
                  variant: ButtonVariant.filled,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

