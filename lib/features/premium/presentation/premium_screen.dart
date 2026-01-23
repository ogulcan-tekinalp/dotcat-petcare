import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/localization.dart';
import '../../../core/services/premium_service.dart';

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  bool _isLoading = true;
  bool _isPurchasing = false;
  bool _hasError = false;
  String? _errorMessage;
  Offerings? _offerings;
  Package? _selectedPackage;
  final _promoController = TextEditingController();
  bool _showPromoInput = false;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _loadOfferings() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      debugPrint('PremiumScreen: Loading offerings...');
      final offerings = await PremiumService.instance.getOfferings();

      debugPrint('PremiumScreen: Offerings loaded: ${offerings?.current?.identifier}');
      debugPrint('PremiumScreen: Monthly package: ${offerings?.current?.monthly?.storeProduct.priceString}');
      debugPrint('PremiumScreen: Annual package: ${offerings?.current?.annual?.storeProduct.priceString}');
      debugPrint('PremiumScreen: Available packages: ${offerings?.current?.availablePackages.length}');

      if (offerings?.current == null || offerings!.current!.availablePackages.isEmpty) {
        setState(() {
          _offerings = offerings;
          _hasError = true;
          _errorMessage = AppLocalizations.get('offerings_not_available');
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _offerings = offerings;
        // Default select yearly package (best value)
        _selectedPackage = offerings.current?.annual ?? offerings.current?.monthly;
        _isLoading = false;
        _hasError = false;
      });
    } catch (e) {
      debugPrint('PremiumScreen: Error loading offerings: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  /// Present RevenueCat native paywall
  Future<void> _presentRevenueCatPaywall() async {
    try {
      final result = await PremiumService.instance.presentPaywall();

      if (mounted) {
        if (result == PaywallResult.purchased || result == PaywallResult.restored) {
          ref.read(premiumStatusProvider.notifier).setStatus(PremiumStatus.premium);
          _showSuccessDialog();
        }
      }
    } catch (e) {
      debugPrint('Error presenting paywall: $e');
      // Fallback to custom purchase flow
      _purchase();
    }
  }

  /// Open Customer Center for subscription management
  Future<void> _openCustomerCenter() async {
    await PremiumService.instance.presentCustomerCenter(context);

    // Refresh premium status after returning
    if (mounted) {
      await PremiumService.instance.refreshPremiumStatus();
      final isPremium = PremiumService.instance.isPremium;
      ref.read(premiumStatusProvider.notifier).setStatus(
        isPremium ? PremiumStatus.premium : PremiumStatus.free,
      );
    }
  }

  Future<void> _purchase() async {
    if (_selectedPackage == null) return;

    setState(() => _isPurchasing = true);
    try {
      final success = await PremiumService.instance.purchasePackage(_selectedPackage!);
      if (mounted) {
        setState(() => _isPurchasing = false);
        if (success) {
          ref.read(premiumStatusProvider.notifier).setStatus(PremiumStatus.premium);
          _showSuccessDialog();
        } else {
          _showErrorSnackbar(AppLocalizations.get('purchase_failed'));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPurchasing = false);
        _showErrorSnackbar(AppLocalizations.get('purchase_failed'));
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isPurchasing = true);
    try {
      final success = await PremiumService.instance.restorePurchases();
      if (mounted) {
        setState(() => _isPurchasing = false);
        if (success) {
          ref.read(premiumStatusProvider.notifier).setStatus(PremiumStatus.premium);
          _showSuccessSnackbar(AppLocalizations.get('restore_success'));
        } else {
          _showErrorSnackbar(AppLocalizations.get('restore_failed'));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPurchasing = false);
        _showErrorSnackbar(AppLocalizations.get('restore_failed'));
      }
    }
  }

  Future<void> _applyPromoCode() async {
    final code = _promoController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isPurchasing = true);
    try {
      final expiryDate = await PremiumService.instance.applyPromoCode(code);
      if (mounted) {
        setState(() => _isPurchasing = false);
        if (expiryDate != null) {
          ref.read(premiumStatusProvider.notifier).setStatus(PremiumStatus.premium);
          final dateStr = DateFormat('dd MMM yyyy').format(expiryDate);
          _showSuccessSnackbar(
            AppLocalizations.get('promo_code_applied').replaceAll('{date}', dateStr),
          );
          _promoController.clear();
          setState(() => _showPromoInput = false);
        } else {
          _showErrorSnackbar(AppLocalizations.get('invalid_promo_code'));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPurchasing = false);
        _showErrorSnackbar(AppLocalizations.get('invalid_promo_code'));
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 64),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.get('purchase_success'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.success),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final premiumStatus = ref.watch(premiumStatusProvider);
    final isPremium = premiumStatus == PremiumStatus.premium;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.7),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      const Icon(Icons.workspace_premium, size: 56, color: Colors.white),
                      const SizedBox(height: 12),
                      Text(
                        AppLocalizations.get('premium_title'),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          AppLocalizations.get('premium_subtitle'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: isPremium ? _buildPremiumActiveContent(isDark) : _buildSubscriptionContent(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumActiveContent(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Premium Active Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.success.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.verified, color: AppColors.success, size: 48),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.get('premium_active'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
                if (PremiumService.instance.expiryDate != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    PremiumService.instance.willRenew
                        ? AppLocalizations.get('auto_renews').replaceAll(
                            '{date}',
                            DateFormat('dd MMM yyyy').format(PremiumService.instance.expiryDate!),
                          )
                        : AppLocalizations.get('premium_expires').replaceAll(
                            '{date}',
                            DateFormat('dd MMM yyyy').format(PremiumService.instance.expiryDate!),
                          ),
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Features List
          _buildFeaturesList(isDark),

          const SizedBox(height: 24),

          // Manage Subscription Button - Opens RevenueCat Customer Center
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openCustomerCenter,
              icon: const Icon(Icons.settings),
              label: Text(AppLocalizations.get('manage_subscription')),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Alternative: Direct link to App Store / Play Store subscriptions
          TextButton(
            onPressed: () {
              if (Platform.isIOS) {
                _openUrl('https://apps.apple.com/account/subscriptions');
              } else {
                _openUrl('https://play.google.com/store/account/subscriptions');
              }
            },
            child: Text(
              AppLocalizations.get('manage_in_store'),
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white60
                    : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionContent(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Features List
          _buildFeaturesList(isDark),

          const SizedBox(height: 24),

          // Subscription Plans
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            _buildSubscriptionPlans(isDark),

          const SizedBox(height: 20),

          // Subscribe Button - only show if packages are available
          if (!_hasError && _selectedPackage != null)
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isPurchasing || _selectedPackage == null ? null : _purchase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                ),
                child: _isPurchasing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        AppLocalizations.get('subscribe'),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                      ),
              ),
            ),

          const SizedBox(height: 16),

          // Restore & Promo Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: _isPurchasing ? null : _restorePurchases,
                child: Text(
                  AppLocalizations.get('restore_purchases'),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const Text('•', style: TextStyle(color: Colors.grey)),
              TextButton(
                onPressed: () => setState(() => _showPromoInput = !_showPromoInput),
                child: Text(
                  AppLocalizations.get('promo_code'),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),

          // Promo Code Input
          if (_showPromoInput) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promoController,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.get('enter_promo_code'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isPurchasing ? null : _applyPromoCode,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(AppLocalizations.get('apply')),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // Subscription Note - Required by App Store
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              AppLocalizations.get('subscription_note'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
                height: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Terms & Privacy - Required by App Store
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => _openUrl('https://ogulcan-tekinalp.github.io/dotcat-petcare/terms.html'),
                child: Text(
                  AppLocalizations.get('terms_of_service'),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ),
              Text(
                '•',
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
              TextButton(
                onPressed: () => _openUrl('https://ogulcan-tekinalp.github.io/dotcat-petcare/privacy.html'),
                child: Text(
                  AppLocalizations.get('privacy_policy'),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFeaturesList(bool isDark) {
    final features = [
      {
        'icon': Icons.block,
        'title': AppLocalizations.get('premium_feature_no_ads'),
        'desc': AppLocalizations.get('premium_feature_no_ads_desc'),
        'available': true,
      },
      {
        'icon': Icons.smart_toy,
        'title': AppLocalizations.get('premium_feature_ai_chat'),
        'desc': AppLocalizations.get('premium_feature_ai_chat_desc'),
        'available': false, // Coming soon
      },
      {
        'icon': Icons.family_restroom,
        'title': AppLocalizations.get('premium_feature_family'),
        'desc': AppLocalizations.get('premium_feature_family_desc'),
        'available': false, // Coming soon
      },
      {
        'icon': Icons.pets,
        'title': AppLocalizations.get('premium_feature_unlimited_pets'),
        'desc': AppLocalizations.get('premium_feature_unlimited_pets_desc'),
        'available': true,
      },
      {
        'icon': Icons.insights,
        'title': AppLocalizations.get('premium_feature_insights'),
        'desc': AppLocalizations.get('premium_feature_insights_desc'),
        'available': true,
      },
    ];

    return Column(
      children: features.map((feature) {
        final isAvailable = feature['available'] as bool;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isAvailable
                      ? AppColors.primary.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  feature['icon'] as IconData,
                  color: isAvailable ? AppColors.primary : Colors.grey,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          feature['title'] as String,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isAvailable ? null : Colors.grey,
                          ),
                        ),
                        if (!isAvailable) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              AppLocalizations.get('coming_soon'),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      feature['desc'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              if (isAvailable)
                const Icon(Icons.check_circle, color: AppColors.success, size: 22),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubscriptionPlans(bool isDark) {
    // Show error state with retry button
    if (_hasError) {
      return _buildErrorState(isDark);
    }

    final monthlyPackage = _offerings?.current?.monthly;
    final yearlyPackage = _offerings?.current?.annual;

    // Calculate savings for yearly
    int savingsPercent = 0;
    if (monthlyPackage != null && yearlyPackage != null) {
      final monthlyPrice = monthlyPackage.storeProduct.price;
      final yearlyPrice = yearlyPackage.storeProduct.price;
      final yearlyMonthlyEquivalent = yearlyPrice / 12;
      savingsPercent = ((1 - yearlyMonthlyEquivalent / monthlyPrice) * 100).round();
    }

    // If no offerings available, show error with retry
    if (monthlyPackage == null && yearlyPackage == null) {
      return _buildErrorState(isDark);
    }

    return Column(
      children: [
        // Yearly Plan (Best Value)
        if (yearlyPackage != null)
          _buildPlanCard(
            package: yearlyPackage,
            isSelected: _selectedPackage == yearlyPackage,
            isDark: isDark,
            title: AppLocalizations.get('yearly'),
            price: yearlyPackage.storeProduct.priceString,
            period: AppLocalizations.get('per_year'),
            badge: savingsPercent > 0
                ? AppLocalizations.get('save_percent').replaceAll('{percent}', savingsPercent.toString())
                : AppLocalizations.get('best_value'),
            onTap: () => setState(() => _selectedPackage = yearlyPackage),
          ),

        if (yearlyPackage != null && monthlyPackage != null)
          const SizedBox(height: 12),

        // Monthly Plan
        if (monthlyPackage != null)
          _buildPlanCard(
            package: monthlyPackage,
            isSelected: _selectedPackage == monthlyPackage,
            isDark: isDark,
            title: AppLocalizations.get('monthly'),
            price: monthlyPackage.storeProduct.priceString,
            period: AppLocalizations.get('per_month'),
            onTap: () => setState(() => _selectedPackage = monthlyPackage),
          ),
      ],
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 48,
            color: Colors.orange.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.get('subscription_load_error'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.get('subscription_load_error_desc'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _loadOfferings,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(_isLoading
                  ? AppLocalizations.get('loading')
                  : AppLocalizations.get('retry')),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required Package? package,
    required bool isSelected,
    required bool isDark,
    required String title,
    required String price,
    required String period,
    String? badge,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : (isDark ? AppColors.surfaceDark : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Radio indicator
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),

            // Plan details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Price
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  period,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
