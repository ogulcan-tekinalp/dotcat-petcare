import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/localization.dart';
import 'app_button.dart';

/// Empty State türleri
enum EmptyStateType {
  noCats,
  noReminders,
  noWeight,
  noVaccines,
  noInsights,
  noHistory,
  noSearch,
  error,
}

/// Güzel Empty State Widget
class EmptyState extends StatelessWidget {
  final EmptyStateType type;
  final String? customTitle;
  final String? customMessage;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double iconSize;
  
  const EmptyState({
    super.key,
    required this.type,
    this.customTitle,
    this.customMessage,
    this.actionLabel,
    this.onAction,
    this.iconSize = 100,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final config = _getConfig(type);
    
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // İllüstrasyon
          _buildIllustration(config, isDark),
          const SizedBox(height: 24),
          
          // Başlık
          Text(
            customTitle ?? config.title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          
          // Mesaj
          Text(
            customMessage ?? config.message,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          
          // Aksiyon butonu
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 24),
            AppButton(
              label: actionLabel!,
              onPressed: onAction!,
              icon: config.actionIcon,
              variant: ButtonVariant.filled,
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildIllustration(_EmptyStateConfig config, bool isDark) {
    return Container(
      width: iconSize + 40,
      height: iconSize + 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            config.color.withOpacity(0.1),
            config.color.withOpacity(0.05),
          ],
        ),
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ana ikon
          Icon(
            config.icon,
            size: iconSize,
            color: config.color.withOpacity(0.7),
          ),
          
          // Dekoratif küçük ikonlar
          if (config.decorativeIcons != null)
            ...config.decorativeIcons!.asMap().entries.map((entry) {
              final index = entry.key;
              final icon = entry.value;
              final angle = (index * 72) * 3.14159 / 180; // 72 derece aralıklarla
              final radius = iconSize / 2 + 20;
              
              return Positioned(
                left: (iconSize + 40) / 2 + radius * cos(angle) - 10,
                top: (iconSize + 40) / 2 + radius * sin(angle) - 10,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: config.color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 12, color: config.color),
                ),
              );
            }),
        ],
      ),
    );
  }
  
  _EmptyStateConfig _getConfig(EmptyStateType type) {
    switch (type) {
      case EmptyStateType.noCats:
        return _EmptyStateConfig(
          icon: Icons.pets_rounded,
          title: AppLocalizations.get('no_cats_yet'),
          message: AppLocalizations.get('add_your_first_cat'),
          color: AppColors.primary,
          actionIcon: Icons.add_rounded,
          decorativeIcons: [Icons.favorite, Icons.star, Icons.auto_awesome],
        );
        
      case EmptyStateType.noReminders:
        return _EmptyStateConfig(
          icon: Icons.notifications_none_rounded,
          title: AppLocalizations.get('no_reminders'),
          message: AppLocalizations.get('add_reminder_desc'),
          color: AppColors.warning,
          actionIcon: Icons.add_alarm_rounded,
          decorativeIcons: [Icons.schedule, Icons.event_note],
        );
        
      case EmptyStateType.noWeight:
        return _EmptyStateConfig(
          icon: Icons.monitor_weight_outlined,
          title: AppLocalizations.get('no_weight_records'),
          message: AppLocalizations.get('add_first_weight'),
          color: AppColors.weight,
          actionIcon: Icons.add_rounded,
        );
        
      case EmptyStateType.noVaccines:
        return _EmptyStateConfig(
          icon: Icons.vaccines_outlined,
          title: AppLocalizations.get('no_vaccines'),
          message: AppLocalizations.get('add_vaccine_desc'),
          color: AppColors.vaccine,
          actionIcon: Icons.add_rounded,
        );
        
      case EmptyStateType.noInsights:
        return _EmptyStateConfig(
          icon: Icons.lightbulb_outline_rounded,
          title: AppLocalizations.get('no_insights'),
          message: AppLocalizations.get('no_insights_desc'),
          color: AppColors.success,
        );
        
      case EmptyStateType.noHistory:
        return _EmptyStateConfig(
          icon: Icons.history_rounded,
          title: AppLocalizations.get('no_history'),
          message: AppLocalizations.get('no_history_desc'),
          color: AppColors.info,
        );
        
      case EmptyStateType.noSearch:
        return _EmptyStateConfig(
          icon: Icons.search_off_rounded,
          title: AppLocalizations.get('no_results'),
          message: AppLocalizations.get('try_different_search'),
          color: AppColors.textSecondary,
        );
        
      case EmptyStateType.error:
        return _EmptyStateConfig(
          icon: Icons.error_outline_rounded,
          title: AppLocalizations.get('something_went_wrong'),
          message: AppLocalizations.get('try_again_later'),
          color: AppColors.error,
          actionIcon: Icons.refresh_rounded,
        );
    }
  }
}

class _EmptyStateConfig {
  final IconData icon;
  final String title;
  final String message;
  final Color color;
  final IconData? actionIcon;
  final List<IconData>? decorativeIcons;
  
  _EmptyStateConfig({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
    this.actionIcon,
    this.decorativeIcons,
  });
}

// Math functions
double cos(double x) => _cos(x);
double sin(double x) => _sin(x);

double _cos(double x) {
  // Taylor series approximation
  x = x % (2 * 3.14159);
  double result = 1;
  double term = 1;
  for (int i = 1; i <= 10; i++) {
    term *= -x * x / ((2 * i - 1) * (2 * i));
    result += term;
  }
  return result;
}

double _sin(double x) {
  // Taylor series approximation  
  x = x % (2 * 3.14159);
  double result = x;
  double term = x;
  for (int i = 1; i <= 10; i++) {
    term *= -x * x / ((2 * i) * (2 * i + 1));
    result += term;
  }
  return result;
}

