import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ad_service.dart';

/// Premium subscription status
enum PremiumStatus {
  free,
  premium,
  loading,
  error,
}

/// Premium feature identifiers
class PremiumFeatures {
  static const String noAds = 'no_ads';
  static const String aiChat = 'ai_chat';
  static const String familySharing = 'family_sharing';
  static const String unlimitedPets = 'unlimited_pets';
  static const String advancedInsights = 'advanced_insights';
}

/// Entitlement identifiers in RevenueCat
class Entitlements {
  // PetCare Pro entitlement - configured in RevenueCat dashboard
  static const String petCarePro = 'PetCare Pro';
}

/// Product identifiers - configured in App Store Connect / Google Play Console
class ProductIds {
  static const String monthlySubscription = 'monthly'; // 19,90 TL
  static const String yearlySubscription = 'yearly';   // 199,90 TL
}

/// Provider for premium status
final premiumStatusProvider = StateNotifierProvider<PremiumNotifier, PremiumStatus>((ref) {
  return PremiumNotifier();
});

/// Provider for checking if a specific feature is available
final isPremiumFeatureAvailableProvider = Provider.family<bool, String>((ref, featureId) {
  final status = ref.watch(premiumStatusProvider);
  return status == PremiumStatus.premium;
});

/// State notifier for premium status
class PremiumNotifier extends StateNotifier<PremiumStatus> {
  PremiumNotifier() : super(PremiumStatus.loading);

  void setStatus(PremiumStatus status) {
    state = status;
  }
}

/// Service for managing premium subscriptions via RevenueCat
class PremiumService {
  static final PremiumService instance = PremiumService._init();

  PremiumService._init();

  bool _isInitialized = false;
  bool _isPremium = false;
  CustomerInfo? _customerInfo;
  Offerings? _offerings;

  // RevenueCat API Keys
  static const String _revenueCatApiKeyIOS = 'appl_caKdNIEErkPvrhEqyTDXwMMbtNk';
  static const String _revenueCatApiKeyAndroid = 'test_yTWPOlNqUlNEaVHoqqvmxVkjUEf'; // TODO: Add Android key when available

  // Promo code prefix for validation
  static const String _promoCodePrefix = 'DOTCAT';

  // Preference keys
  static const String _prefKeyPromoCodeUsed = 'promo_code_used';
  static const String _prefKeyPromoExpiry = 'promo_expiry';

  /// Initialize RevenueCat
  Future<void> init({String? userId}) async {
    if (_isInitialized) return;

    try {
      // Configure RevenueCat
      late PurchasesConfiguration configuration;

      if (Platform.isIOS) {
        configuration = PurchasesConfiguration(_revenueCatApiKeyIOS);
      } else if (Platform.isAndroid) {
        configuration = PurchasesConfiguration(_revenueCatApiKeyAndroid);
      } else {
        throw UnsupportedError('Unsupported platform');
      }

      // Set user ID if available
      if (userId != null) {
        configuration.appUserID = userId;
      }

      await Purchases.configure(configuration);
      _isInitialized = true;

      // Check initial premium status
      await refreshPremiumStatus();

      // Listen to customer info changes
      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        _updatePremiumStatus(customerInfo);
      });

      debugPrint('PremiumService: Initialized successfully');
    } catch (e) {
      debugPrint('PremiumService: Failed to initialize: $e');
    }
  }

  /// Refresh premium status from RevenueCat
  Future<void> refreshPremiumStatus() async {
    try {
      _customerInfo = await Purchases.getCustomerInfo();
      _updatePremiumStatus(_customerInfo!);
    } catch (e) {
      debugPrint('PremiumService: Failed to refresh status: $e');

      // Check for promo code premium
      await _checkPromoCodePremium();
    }
  }

  /// Update premium status based on customer info
  void _updatePremiumStatus(CustomerInfo customerInfo) {
    _customerInfo = customerInfo;

    // Check if user has PetCare Pro entitlement
    final entitlement = customerInfo.entitlements.all[Entitlements.petCarePro];
    _isPremium = entitlement?.isActive ?? false;

    // Update AdService
    AdService.instance.setPremiumStatus(_isPremium);

    debugPrint('PremiumService: Premium status updated to $_isPremium');
    debugPrint('PremiumService: Active entitlements: ${customerInfo.entitlements.active.keys}');
  }

  /// Check if user has premium via promo code
  Future<void> _checkPromoCodePremium() async {
    final prefs = await SharedPreferences.getInstance();
    final promoExpiry = prefs.getInt(_prefKeyPromoExpiry);

    if (promoExpiry != null) {
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(promoExpiry);
      if (expiryDate.isAfter(DateTime.now())) {
        _isPremium = true;
        AdService.instance.setPremiumStatus(true);
        debugPrint('PremiumService: Premium active via promo code until $expiryDate');
      } else {
        // Promo expired, clear it
        await prefs.remove(_prefKeyPromoCodeUsed);
        await prefs.remove(_prefKeyPromoExpiry);
        _isPremium = false;
        AdService.instance.setPremiumStatus(false);
        debugPrint('PremiumService: Promo code expired');
      }
    }
  }

  /// Get available offerings (subscription packages)
  Future<Offerings?> getOfferings() async {
    try {
      _offerings = await Purchases.getOfferings();
      return _offerings;
    } catch (e) {
      debugPrint('PremiumService: Failed to get offerings: $e');
      return null;
    }
  }

  /// Purchase a subscription package
  Future<bool> purchasePackage(Package package) async {
    try {
      final result = await Purchases.purchasePackage(package);
      _updatePremiumStatus(result.customerInfo);
      return _isPremium;
    } on PurchasesErrorCode catch (e) {
      debugPrint('PremiumService: Purchase failed: $e');
      return false;
    }
  }

  /// Restore previous purchases
  Future<bool> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      _updatePremiumStatus(customerInfo);
      return _isPremium;
    } catch (e) {
      debugPrint('PremiumService: Restore failed: $e');
      return false;
    }
  }

  /// Validate and apply a promo code
  /// Returns: null if invalid, or expiry date if valid
  Future<DateTime?> applyPromoCode(String code) async {
    try {
      // Validate code format
      final upperCode = code.toUpperCase().trim();
      if (!upperCode.startsWith(_promoCodePrefix)) {
        debugPrint('PremiumService: Invalid promo code format');
        return null;
      }

      // Check if code was already used
      final prefs = await SharedPreferences.getInstance();
      final usedCode = prefs.getString(_prefKeyPromoCodeUsed);
      if (usedCode == upperCode) {
        debugPrint('PremiumService: Promo code already used');
        return null;
      }

      // In a real app, you would validate the code against your backend
      // For now, we'll accept any code starting with DOTCAT and give 30 days

      // Example code format: DOTCAT-XXXXX-30D (last part is duration)
      int daysToAdd = 30; // Default 30 days

      // Parse duration from code if present
      final parts = upperCode.split('-');
      if (parts.length >= 3) {
        final durationPart = parts.last;
        if (durationPart.endsWith('D')) {
          final days = int.tryParse(durationPart.replaceAll('D', ''));
          if (days != null && days > 0 && days <= 365) {
            daysToAdd = days;
          }
        }
      }

      // Calculate expiry date
      final expiryDate = DateTime.now().add(Duration(days: daysToAdd));

      // Save promo code usage
      await prefs.setString(_prefKeyPromoCodeUsed, upperCode);
      await prefs.setInt(_prefKeyPromoExpiry, expiryDate.millisecondsSinceEpoch);

      // Activate premium
      _isPremium = true;
      AdService.instance.setPremiumStatus(true);

      debugPrint('PremiumService: Promo code applied, premium until $expiryDate');
      return expiryDate;
    } catch (e) {
      debugPrint('PremiumService: Failed to apply promo code: $e');
      return null;
    }
  }

  /// Get current premium status
  bool get isPremium => _isPremium;

  /// Get customer info
  CustomerInfo? get customerInfo => _customerInfo;

  /// Get available packages from the default offering
  List<Package> get availablePackages {
    return _offerings?.current?.availablePackages ?? [];
  }

  /// Get monthly package
  Package? get monthlyPackage {
    return _offerings?.current?.monthly;
  }

  /// Get annual package
  Package? get annualPackage {
    return _offerings?.current?.annual;
  }

  /// Check if a specific feature is available
  bool isFeatureAvailable(String featureId) {
    // All premium features require premium status
    return _isPremium;
  }

  /// Get expiry date of current subscription
  DateTime? get expiryDate {
    final entitlement = _customerInfo?.entitlements.all[Entitlements.petCarePro];
    if (entitlement?.expirationDate != null) {
      return DateTime.parse(entitlement!.expirationDate!);
    }
    return null;
  }

  /// Check if subscription will renew
  bool get willRenew {
    final entitlement = _customerInfo?.entitlements.all[Entitlements.petCarePro];
    return entitlement?.willRenew ?? false;
  }

  /// Get promo code expiry date (if using promo)
  Future<DateTime?> getPromoExpiryDate() async {
    final prefs = await SharedPreferences.getInstance();
    final promoExpiry = prefs.getInt(_prefKeyPromoExpiry);
    if (promoExpiry != null) {
      return DateTime.fromMillisecondsSinceEpoch(promoExpiry);
    }
    return null;
  }

  /// Identify user with RevenueCat (call after authentication)
  Future<void> identifyUser(String userId) async {
    try {
      final customerInfo = await Purchases.logIn(userId);
      _updatePremiumStatus(customerInfo.customerInfo);
      debugPrint('PremiumService: User identified: $userId');
    } catch (e) {
      debugPrint('PremiumService: Failed to identify user: $e');
    }
  }

  /// Log out user from RevenueCat
  Future<void> logOut() async {
    try {
      await Purchases.logOut();
      _isPremium = false;
      _customerInfo = null;
      AdService.instance.setPremiumStatus(false);
      debugPrint('PremiumService: User logged out');
    } catch (e) {
      debugPrint('PremiumService: Failed to log out: $e');
    }
  }

  // ============================================================
  // RevenueCat Paywall Methods
  // ============================================================

  /// Present the RevenueCat Paywall
  /// Returns PaywallResult indicating what happened
  Future<PaywallResult> presentPaywall({
    String? offeringIdentifier,
    bool displayCloseButton = true,
  }) async {
    try {
      final paywallResult = await RevenueCatUI.presentPaywall(
        displayCloseButton: displayCloseButton,
        offering: offeringIdentifier != null
            ? await _getOfferingByIdentifier(offeringIdentifier)
            : null,
      );

      // Refresh status after paywall interaction
      await refreshPremiumStatus();

      debugPrint('PremiumService: Paywall result: $paywallResult');
      return paywallResult;
    } catch (e) {
      debugPrint('PremiumService: Failed to present paywall: $e');
      return PaywallResult.error;
    }
  }

  /// Present the RevenueCat Paywall if user is not premium
  /// Useful for gating premium features
  Future<PaywallResult> presentPaywallIfNeeded({
    String? requiredEntitlementIdentifier,
  }) async {
    try {
      final paywallResult = await RevenueCatUI.presentPaywallIfNeeded(
        requiredEntitlementIdentifier ?? Entitlements.petCarePro,
      );

      // Refresh status after paywall interaction
      await refreshPremiumStatus();

      debugPrint('PremiumService: PaywallIfNeeded result: $paywallResult');
      return paywallResult;
    } catch (e) {
      debugPrint('PremiumService: Failed to present paywall if needed: $e');
      return PaywallResult.error;
    }
  }

  /// Get offering by identifier
  Future<Offering?> _getOfferingByIdentifier(String identifier) async {
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.all[identifier];
    } catch (e) {
      debugPrint('PremiumService: Failed to get offering: $e');
      return null;
    }
  }

  // ============================================================
  // Customer Center Methods
  // ============================================================

  /// Present the Customer Center for subscription management
  /// Allows users to manage subscriptions, request refunds, etc.
  Future<void> presentCustomerCenter(BuildContext context) async {
    try {
      await RevenueCatUI.presentCustomerCenter();

      // Refresh status after customer center interaction
      await refreshPremiumStatus();

      debugPrint('PremiumService: Customer Center presented');
    } catch (e) {
      debugPrint('PremiumService: Failed to present Customer Center: $e');
      // Fallback to manual subscription management
      _showManualSubscriptionManagement(context);
    }
  }

  /// Fallback for Customer Center if not available
  void _showManualSubscriptionManagement(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abonelik Yönetimi'),
        content: const Text(
          'Aboneliğinizi yönetmek için cihaz ayarlarınıza gidin:\n\n'
          'iOS: Ayarlar > Apple ID > Abonelikler\n'
          'Android: Google Play > Abonelikler',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Subscription Info Methods
  // ============================================================

  /// Get subscription management URL
  String? get managementURL {
    return _customerInfo?.managementURL;
  }

  /// Get active subscription product identifier
  String? get activeProductIdentifier {
    final entitlement = _customerInfo?.entitlements.all[Entitlements.petCarePro];
    return entitlement?.productIdentifier;
  }

  /// Check if user is on monthly plan
  bool get isMonthlySubscriber {
    return activeProductIdentifier == ProductIds.monthlySubscription;
  }

  /// Check if user is on yearly plan
  bool get isYearlySubscriber {
    return activeProductIdentifier == ProductIds.yearlySubscription;
  }

  /// Get subscription period type
  String get subscriptionPeriodType {
    if (isMonthlySubscriber) return 'Aylık';
    if (isYearlySubscriber) return 'Yıllık';
    return 'Bilinmiyor';
  }

  /// Get formatted expiry date
  String? get formattedExpiryDate {
    final expiry = expiryDate;
    if (expiry == null) return null;
    return '${expiry.day}/${expiry.month}/${expiry.year}';
  }

  /// Get days until expiry
  int? get daysUntilExpiry {
    final expiry = expiryDate;
    if (expiry == null) return null;
    return expiry.difference(DateTime.now()).inDays;
  }

  /// Check if subscription is in grace period
  bool get isInGracePeriod {
    final entitlement = _customerInfo?.entitlements.all[Entitlements.petCarePro];
    if (entitlement == null) return false;

    // In grace period if entitlement is active but billing issue exists
    return entitlement.isActive &&
           entitlement.periodType == PeriodType.normal &&
           !willRenew;
  }

  /// Get subscription status text for UI
  String getSubscriptionStatusText() {
    if (!_isPremium) return 'Ücretsiz Plan';

    final period = subscriptionPeriodType;
    final expiry = formattedExpiryDate;

    if (willRenew) {
      return '$period Abonelik (Yenileme: $expiry)';
    } else {
      return '$period Abonelik (Bitiş: $expiry)';
    }
  }

  // ============================================================
  // Purchase Specific Products
  // ============================================================

  /// Purchase monthly subscription
  Future<bool> purchaseMonthly() async {
    final package = monthlyPackage;
    if (package == null) {
      debugPrint('PremiumService: Monthly package not available');
      return false;
    }
    return purchasePackage(package);
  }

  /// Purchase yearly subscription
  Future<bool> purchaseYearly() async {
    final package = annualPackage;
    if (package == null) {
      debugPrint('PremiumService: Yearly package not available');
      return false;
    }
    return purchasePackage(package);
  }

  /// Get price string for monthly subscription
  String? get monthlyPriceString {
    return monthlyPackage?.storeProduct.priceString;
  }

  /// Get price string for yearly subscription
  String? get yearlyPriceString {
    return annualPackage?.storeProduct.priceString;
  }

  /// Calculate yearly savings percentage
  int? get yearlySavingsPercent {
    final monthly = monthlyPackage?.storeProduct.price;
    final yearly = annualPackage?.storeProduct.price;

    if (monthly == null || yearly == null || monthly == 0) return null;

    final yearlyIfMonthly = monthly * 12;
    final savings = ((yearlyIfMonthly - yearly) / yearlyIfMonthly * 100).round();
    return savings > 0 ? savings : null;
  }
}
