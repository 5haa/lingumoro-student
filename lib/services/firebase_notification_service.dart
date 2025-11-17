import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_notification_service.dart';

class FirebaseNotificationService {
  static final FirebaseNotificationService _instance = FirebaseNotificationService._internal();
  factory FirebaseNotificationService() => _instance;
  FirebaseNotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final LocalNotificationService _localNotificationService = LocalNotificationService();
  final SupabaseClient _supabase = Supabase.instance.client;

  String? _currentToken;
  Function(Map<String, dynamic>)? _onMessageTap;

  /// Initialize Firebase and request notification permissions
  Future<void> initialize() async {
    try {
      // Request notification permissions
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted notification permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        print('User granted provisional notification permission');
      } else {
        print('User declined or has not accepted notification permission');
        return;
      }

      // Initialize local notification service
      await _localNotificationService.initialize(
        onNotificationTap: (payload) {
          if (_onMessageTap != null && payload != null) {
            try {
              // Parse payload as Map if it's a string
              final data = payload is String 
                  ? {'action': payload} 
                  : payload as Map<String, dynamic>;
              _onMessageTap!(data);
            } catch (e) {
              print('Error parsing notification payload: $e');
            }
          }
        },
      );

      // Get FCM token
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        print('FCM Token: $token');
        await _saveTokenToDatabase(token);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        print('FCM Token refreshed: $newToken');
        _saveTokenToDatabase(newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background message taps
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

      // Check if app was opened from a terminated state
      RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageTap(initialMessage);
      }

      print('Firebase Notification Service initialized successfully');
    } catch (e) {
      print('Error initializing Firebase Notification Service: $e');
    }
  }

  /// Set callback for when notification is tapped
  void setOnMessageTapCallback(Function(Map<String, dynamic>) callback) {
    _onMessageTap = callback;
  }

  /// Save FCM token to Supabase
  Future<void> _saveTokenToDatabase(String token) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('No user logged in, cannot save FCM token');
        return;
      }

      _currentToken = token;

      // Check if token already exists
      final existing = await _supabase
          .from('device_tokens')
          .select()
          .eq('fcm_token', token)
          .maybeSingle();

      if (existing != null) {
        // Update existing token
        await _supabase
            .from('device_tokens')
            .update({
              'is_active': true,
              'last_used_at': DateTime.now().toIso8601String(),
            })
            .eq('fcm_token', token);
      } else {
        // Insert new token
        await _supabase.from('device_tokens').insert({
          'user_id': userId,
          'user_type': 'student',
          'fcm_token': token,
          'platform': _getPlatform(),
          'is_active': true,
        });
      }

      print('FCM token saved to database');
    } catch (e) {
      print('Error saving FCM token to database: $e');
    }
  }

  /// Get platform name
  String _getPlatform() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'android';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ios';
    } else if (defaultTargetPlatform == TargetPlatform.windows) {
      return 'windows';
    } else if (defaultTargetPlatform == TargetPlatform.macOS) {
      return 'macos';
    } else if (defaultTargetPlatform == TargetPlatform.linux) {
      return 'linux';
    } else {
      return 'web';
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('Received foreground message: ${message.messageId}');
    print('Notification: ${message.notification?.title}');
    print('Data: ${message.data}');

    // Show local notification
    if (message.notification != null) {
      _localNotificationService.showNotification(
        title: message.notification!.title ?? 'New Notification',
        body: message.notification!.body ?? '',
        payload: message.data,
      );
    }
  }

  /// Handle message tap (background or terminated)
  void _handleMessageTap(RemoteMessage message) {
    print('Notification tapped: ${message.messageId}');
    print('Data: ${message.data}');

    if (_onMessageTap != null) {
      _onMessageTap!(message.data);
    }
  }

  /// Delete token from database (on logout)
  Future<void> deleteToken() async {
    try {
      if (_currentToken != null) {
        await _supabase
            .from('device_tokens')
            .update({'is_active': false})
            .eq('fcm_token', _currentToken!);
        
        print('FCM token deactivated');
        _currentToken = null;
      }
    } catch (e) {
      print('Error deactivating FCM token: $e');
    }
  }

  /// Subscribe to topic (optional - for broadcast notifications)
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('Subscribed to topic: $topic');
    } catch (e) {
      print('Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('Unsubscribed from topic: $topic');
    } catch (e) {
      print('Error unsubscribing from topic: $e');
    }
  }
}

// Global navigator key for accessing context
class NavigatorKey {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}

