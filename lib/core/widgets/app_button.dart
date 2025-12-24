import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../constants/app_spacing.dart';

enum ButtonVariant { filled, outlined, text, icon }

/// Reusable button widget with multiple variants
class AppButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final Color? color;
  final bool isLoading;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;

  const AppButton({
    super.key,
    this.label,
    this.icon,
    required this.onPressed,
    this.variant = ButtonVariant.filled,
    this.color,
    this.isLoading = false,
    this.height,
    this.padding,
    this.borderRadius,
  }) : assert(label != null || icon != null, 'Either label or icon must be provided');

  @override
  Widget build(BuildContext context) {
    final buttonColor = color ?? AppColors.primary;
    final buttonHeight = height ?? AppSpacing.buttonHeightLg;
    final buttonBorderRadius = borderRadius ?? AppSpacing.radiusMd;
    final buttonPadding = padding ?? const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    );

    Widget button;

    switch (variant) {
      case ButtonVariant.filled:
        button = FilledButton(
          onPressed: isLoading ? null : () {
            HapticFeedback.selectionClick();
            onPressed?.call();
          },
          style: FilledButton.styleFrom(
            backgroundColor: buttonColor,
            foregroundColor: Colors.white,
            padding: buttonPadding,
            minimumSize: Size(0, buttonHeight),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(buttonBorderRadius),
            ),
          ),
          child: _buildButtonContent(),
        );
        break;
      case ButtonVariant.outlined:
        button = OutlinedButton(
          onPressed: isLoading ? null : () {
            HapticFeedback.selectionClick();
            onPressed?.call();
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: buttonColor,
            side: BorderSide(color: buttonColor),
            padding: buttonPadding,
            minimumSize: Size(0, buttonHeight),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(buttonBorderRadius),
            ),
          ),
          child: _buildButtonContent(),
        );
        break;
      case ButtonVariant.text:
        button = TextButton(
          onPressed: isLoading ? null : () {
            HapticFeedback.selectionClick();
            onPressed?.call();
          },
          style: TextButton.styleFrom(
            foregroundColor: buttonColor,
            padding: buttonPadding,
            minimumSize: Size(0, buttonHeight),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(buttonBorderRadius),
            ),
          ),
          child: _buildButtonContent(),
        );
        break;
      case ButtonVariant.icon:
        button = IconButton(
          onPressed: isLoading ? null : () {
            HapticFeedback.selectionClick();
            onPressed?.call();
          },
          icon: isLoading
              ? SizedBox(
                  width: AppSpacing.iconSm,
                  height: AppSpacing.iconSm,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(buttonColor),
                  ),
                )
              : Icon(icon, color: buttonColor),
          style: IconButton.styleFrom(
            minimumSize: Size(buttonHeight, buttonHeight),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(buttonBorderRadius),
            ),
          ),
        );
        break;
    }

    return button;
  }

  Widget _buildButtonContent() {
    if (isLoading) {
      return SizedBox(
        width: AppSpacing.iconSm,
        height: AppSpacing.iconSm,
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (icon != null && label != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSpacing.iconSm),
          const SizedBox(width: AppSpacing.sm),
          Text(label!),
        ],
      );
    }

    if (icon != null) {
      return Icon(icon);
    }

    return Text(label ?? '');
  }
}

