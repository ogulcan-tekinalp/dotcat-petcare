import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/notification_service.dart';

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCMService: Background message received: ${message.messageId}');
  // Background'da gelen mesajları işle
  // Notification zaten sistem tarafından gösterilir
}

/// Firebase Cloud Messaging Service
/// 
/// Uzak bildirimler için:
/// - Admin panelinden toplu bildirim gönderme
/// - Aile paylaşımı bildirimleri
/// - Önemli duyurular
/// - Hatırlatıcı backup (uygulama kapalıyken)
class FCMService {
  static final FCMService instance = FCMService._init();
  
  final _messaging = FirebaseMessaging.instance;
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  
  String? _fcmToken;
  String? get fcmToken => _fcmToken;
  
  bool _isInitialized = false;
  
  FCMService._init();
  
  /// Initialize FCM
  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      // Set background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      // Request permission
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      
      debugPrint('FCMService: Permission status: ${settings.authorizationStatus}');
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        // Get FCM token
        _fcmToken = await _messaging.getToken();
        debugPrint('FCMService: Token: $_fcmToken');
        
        // Save token to Firestore for this user
        await _saveTokenToFirestore();
        
        // Listen for token refresh
        _messaging.onTokenRefresh.listen((newToken) {
          _fcmToken = newToken;
          _saveTokenToFirestore();
          debugPrint('FCMService: Token refreshed');
        });
        
        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
        
        // Handle notification taps (app was in background)
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
        
        // Check for initial message (app was terminated)
        final initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          _handleMessageOpenedApp(initialMessage);
        }
        
        _isInitialized = true;
        debugPrint('FCMService: Initialized successfully');
      } else {
        debugPrint('FCMService: Permission denied');
      }
    } catch (e) {
      debugPrint('FCMService: Init error: $e');
    }
  }
  
  /// Save FCM token to Firestore
  Future<void> _saveTokenToFirestore() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || _fcmToken == null) return;
    
    try {
      await _firestore.collection('users').doc(userId).set({
        'fcmTokens': FieldValue.arrayUnion([_fcmToken]),
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('FCMService: Token saved to Firestore');
    } catch (e) {
      debugPrint('FCMService: Error saving token: $e');
    }
  }
  
  /// Remove FCM token from Firestore (logout)
  Future<void> removeTokenFromFirestore() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || _fcmToken == null) return;
    
    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmTokens': FieldValue.arrayRemove([_fcmToken]),
      });
      
      debugPrint('FCMService: Token removed from Firestore');
    } catch (e) {
      debugPrint('FCMService: Error removing token: $e');
    }
  }
  
  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('FCMService: Foreground message: ${message.notification?.title}');
    
    // Show local notification for foreground messages
    if (message.notification != null) {
      NotificationService.instance.showInstantNotification(
        id: message.hashCode,
        title: message.notification!.title ?? 'PetCare',
        body: message.notification!.body ?? '',
      );
    }
  }
  
  /// Handle notification tap (app was in background/terminated)
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('FCMService: Message opened app: ${message.data}');
    
    // Navigate based on payload
    final data = message.data;
    if (data.containsKey('type')) {
      switch (data['type']) {
        case 'reminder':
          // Navigate to reminder detail
          // TODO: Implement navigation
          break;
        case 'cat':
          // Navigate to cat detail
          break;
        case 'announcement':
          // Show announcement dialog
          break;
      }
    }
  }
  
  /// Subscribe to topic (for broadcast messages)
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('FCMService: Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('FCMService: Error subscribing to topic: $e');
    }
  }
  
  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('FCMService: Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('FCMService: Error unsubscribing from topic: $e');
    }
  }
  
  /// Get notification settings
  Future<NotificationSettings> getNotificationSettings() async {
    return await _messaging.getNotificationSettings();
  }
  
  /// Request permission again (if denied before)
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }
}

