import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing AdMob ads throughout the app
/// Handles interstitial ads for reminder creation and completion
class AdService {
  static final AdService instance = AdService._init();

  AdService._init();

  bool _isInitialized = false;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;

  // Counters for ad frequency control
  int _reminderAddCount = 0;
  int _reminderCompleteCount = 0;

  // Premium status cache
  bool _isPremium = false;

  // Ad Unit IDs - Production IDs
  static String get _interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-7903410197958783/5434435632';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-7903410197958783/5434435632';
    }
    throw UnsupportedError('Unsupported platform');
  }

  // Preference keys
  static const String _prefKeyReminderAddCount = 'ad_reminder_add_count';
  static const String _prefKeyReminderCompleteCount = 'ad_reminder_complete_count';
  static const String _prefKeyLastAdShown = 'ad_last_shown';

  /// Initialize the AdMob SDK
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;

      // Load counters from preferences
      final prefs = await SharedPreferences.getInstance();
      _reminderAddCount = prefs.getInt(_prefKeyReminderAddCount) ?? 0;
      _reminderCompleteCount = prefs.getInt(_prefKeyReminderCompleteCount) ?? 0;

      debugPrint('AdService: Initialized successfully');

      // Preload an interstitial ad
      await _loadInterstitialAd();
    } catch (e) {
      debugPrint('AdService: Failed to initialize: $e');
    }
  }

  /// Set premium status (call this when user subscription changes)
  void setPremiumStatus(bool isPremium) {
    _isPremium = isPremium;
    debugPrint('AdService: Premium status set to $_isPremium');

    // If user becomes premium, dispose current ad
    if (_isPremium && _interstitialAd != null) {
      _interstitialAd!.dispose();
      _interstitialAd = null;
      _isInterstitialAdReady = false;
    }
  }

  /// Check if user is premium
  bool get isPremium => _isPremium;

  /// Load an interstitial ad
  Future<void> _loadInterstitialAd() async {
    if (_isPremium) return; // Don't load ads for premium users

    await InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          debugPrint('AdService: Interstitial ad loaded');

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              debugPrint('AdService: Ad dismissed');
              ad.dispose();
              _interstitialAd = null;
              _isInterstitialAdReady = false;
              // Preload next ad
              _loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('AdService: Ad failed to show: $error');
              ad.dispose();
              _interstitialAd = null;
              _isInterstitialAdReady = false;
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('AdService: Failed to load interstitial ad: $error');
          _isInterstitialAdReady = false;
        },
      ),
    );
  }

  /// Called when user adds a new reminder
  /// Shows ad after the first pet and first reminder (starting from 2nd reminder)
  Future<bool> onReminderAdded({
    required int totalPets,
    required int totalReminders,
  }) async {
    if (_isPremium) return false;

    // Don't show ad for first pet's first reminder
    // totalReminders is the count BEFORE adding, so 0 means this is the first
    if (totalPets <= 1 && totalReminders <= 0) {
      debugPrint('AdService: Skipping ad for first reminder');
      return false;
    }

    _reminderAddCount++;
    await _saveCounters();

    // Show ad every 2nd reminder addition (50% of the time after first)
    if (_reminderAddCount % 2 == 0) {
      return await _showInterstitialAd();
    }

    return false;
  }

  /// Called when user completes a reminder
  /// Shows ad with 30% probability
  Future<bool> onReminderCompleted() async {
    if (_isPremium) return false;

    _reminderCompleteCount++;
    await _saveCounters();

    // 30% chance to show ad on completion
    final random = Random();
    if (random.nextDouble() < 0.30) {
      // Check if we haven't shown an ad in the last 2 minutes
      final prefs = await SharedPreferences.getInstance();
      final lastAdShown = prefs.getInt(_prefKeyLastAdShown) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (now - lastAdShown < 120000) {
        // 2 minutes
        debugPrint('AdService: Skipping ad, too soon since last ad');
        return false;
      }

      return await _showInterstitialAd();
    }

    return false;
  }

  /// Show interstitial ad
  Future<bool> _showInterstitialAd() async {
    if (!_isInterstitialAdReady || _interstitialAd == null) {
      debugPrint('AdService: Ad not ready');
      await _loadInterstitialAd();
      return false;
    }

    try {
      await _interstitialAd!.show();

      // Record when ad was shown
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _prefKeyLastAdShown,
        DateTime.now().millisecondsSinceEpoch,
      );

      debugPrint('AdService: Interstitial ad shown');
      return true;
    } catch (e) {
      debugPrint('AdService: Error showing ad: $e');
      return false;
    }
  }

  /// Save counters to preferences
  Future<void> _saveCounters() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyReminderAddCount, _reminderAddCount);
    await prefs.setInt(_prefKeyReminderCompleteCount, _reminderCompleteCount);
  }

  /// Reset ad counters (useful for testing)
  Future<void> resetCounters() async {
    _reminderAddCount = 0;
    _reminderCompleteCount = 0;
    await _saveCounters();
    debugPrint('AdService: Counters reset');
  }

  /// Dispose resources
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialAdReady = false;
  }
}
