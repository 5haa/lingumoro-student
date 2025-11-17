import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  Function(dynamic)? _onNotificationTap;

  /// Initialize local notifications
  Future<void> initialize({Function(dynamic)? onNotificationTap}) async {
    if (_initialized) return;

    _onNotificationTap = onNotificationTap;

    // Android initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationTap(response);
      },
    );

    _initialized = true;
    print('Local Notification Service initialized');
  }

  /// Handle notification tap
  void _handleNotificationTap(NotificationResponse response) {
    if (_onNotificationTap != null && response.payload != null) {
      try {
        // Try to parse as JSON
        final data = jsonDecode(response.payload!);
        _onNotificationTap!(data);
      } catch (e) {
        // If not JSON, pass as string
        _onNotificationTap!(response.payload);
      }
    }
  }

  /// Show a notification
  Future<void> showNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
    int id = 0,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'lingumoro_channel',
      'Lingumoro Notifications',
      channelDescription: 'Notifications for Lingumoro app',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Convert payload to JSON string
    String? payloadString;
    if (payload != null) {
      try {
        payloadString = jsonEncode(payload);
      } catch (e) {
        print('Error encoding payload: $e');
      }
    }

    await _notificationsPlugin.show(
      id,
      title,
      body,
      details,
      payload: payloadString,
    );
  }

  /// Show notification with custom sound
  Future<void> showNotificationWithSound({
    required String title,
    required String body,
    String? soundFile,
    Map<String, dynamic>? payload,
    int id = 0,
  }) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'lingumoro_channel_sound',
      'Lingumoro Notifications with Sound',
      channelDescription: 'Notifications with custom sound',
      importance: Importance.high,
      priority: Priority.high,
      sound: soundFile != null ? RawResourceAndroidNotificationSound(soundFile) : null,
      enableVibration: true,
      playSound: true,
    );

    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: soundFile,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    String? payloadString;
    if (payload != null) {
      try {
        payloadString = jsonEncode(payload);
      } catch (e) {
        print('Error encoding payload: $e');
      }
    }

    await _notificationsPlugin.show(
      id,
      title,
      body,
      details,
      payload: payloadString,
    );
  }

  /// Cancel a notification
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notificationsPlugin.pendingNotificationRequests();
  }

  /// Schedule a notification
  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledDate,
    Map<String, dynamic>? payload,
    int id = 0,
  }) async {
    // Note: Scheduled notifications require additional setup
    // This is a placeholder for future implementation
    print('Scheduled notifications not yet implemented');
  }
}

