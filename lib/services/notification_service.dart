import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Background message handler — MUST be a top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCM background message: ${message.notification?.title}');
}

/// Centralized service for Firebase Cloud Messaging (push notifications).
class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'edusync_channel',
    'EduSync Notifications',
    description: 'Alerts for new activities, grades, and announcements.',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static bool get _isFirebaseAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Initialize FCM and local notifications. Call once in main() after Firebase.
  static Future<void> initialize() async {
    if (!_isFirebaseAvailable) return;

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Initialize local notification plugin
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const linuxInit = LinuxInitializationSettings(defaultActionName: 'Open EduSync');

    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
        linux: linuxInit,
      ),
    );

    // Create high-priority Android notification channel
    if (!kIsWeb && Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }

    // Request permission from user (Android 13+, iOS)
    await _requestPermission();

    // Listen to foreground messages and show local notification
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app was in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    // Check if app was opened from a terminated state via notification
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _handleMessageTap(initial);
    }
  }

  static Future<void> _requestPermission() async {
    if (!_isFirebaseAvailable) return;
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('FCM permission: ${settings.authorizationStatus}');
  }

  /// Get the FCM device token for this device.
  static Future<String?> getToken() async {
    if (!_isFirebaseAvailable) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('FCM getToken error: $e');
      return null;
    }
  }

  /// Subscribe to a Firestore class topic so students receive class-wide pushes.
  static Future<void> subscribeToClass(String classId) async {
    if (!_isFirebaseAvailable) return;
    try {
      await FirebaseMessaging.instance.subscribeToTopic('class_$classId');
      debugPrint('FCM subscribed to class_$classId');
    } catch (e) {
      debugPrint('FCM subscribeToClass error: $e');
    }
  }

  /// Unsubscribe from a class topic (called when student is removed).
  static Future<void> unsubscribeFromClass(String classId) async {
    if (!_isFirebaseAvailable) return;
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic('class_$classId');
    } catch (e) {
      debugPrint('FCM unsubscribeFromClass error: $e');
    }
  }

  /// Show a local notification immediately (for foreground messages).
  static Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _localNotifications.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF5B2D8E),
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: notification.title ?? 'EduSync',
      body: notification.body ?? '',
      payload: message.data['screen'],
    );
  }

  static void _handleMessageTap(RemoteMessage message) {
    debugPrint('FCM notification tapped: ${message.data}');
    // Navigation from notification can be wired here using a navigator key
  }

  // ---------------------------------------------------------------------------
  // Convenience methods to show well-formatted EduSync notifications locally
  // ---------------------------------------------------------------------------

  /// Notify when a new activity is posted.
  static Future<void> notifyNewActivity({
    required String activityTitle,
    required String subject,
    required String deadline,
  }) async {
    await showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '📚 New Activity: $activityTitle',
      body: '$subject · Due $deadline',
      payload: 'activities',
    );
  }

  /// Notify student when a grade is posted.
  static Future<void> notifyGradePosted({
    required String activityTitle,
    required String grade,
    required String totalPoints,
  }) async {
    await showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '✅ Grade Posted: $activityTitle',
      body: 'You scored $grade / $totalPoints',
      payload: 'grades',
    );
  }

  /// Notify about a new announcement.
  static Future<void> notifyAnnouncement({
    required String title,
    required String message,
  }) async {
    await showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '📢 $title',
      body: message,
      payload: 'announcements',
    );
  }

  /// Notify teacher when a student submits an activity.
  static Future<void> notifySubmissionReceived({
    required String studentName,
    required String activityTitle,
  }) async {
    await showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '📥 New Submission',
      body: '$studentName submitted "$activityTitle"',
      payload: 'submissions',
    );
  }
}

