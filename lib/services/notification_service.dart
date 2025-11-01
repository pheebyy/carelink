import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // Local notifications init
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _local.initialize(initSettings);

    if (!kIsWeb) {
      // Android channel for heads-up
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'carelink_high_importance',
        'CareLink Notifications',
        description: 'Important messages and job updates',
        importance: Importance.high,
      );
      await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
    }

    // Request permission (iOS/macOS/Web)
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // Background handler is registered in main via FirebaseMessaging.onBackgroundMessage

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final notification = message.notification;
      if (notification != null) {
        await showLocalNotification(notification.title ?? 'CareLink', notification.body ?? '');
      }
    });

    // Token refresh listener
    _messaging.onTokenRefresh.listen((token) => _saveToken(token));

    _initialized = true;
  }

  Future<void> showLocalNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'carelink_high_importance',
      'CareLink Notifications',
      channelDescription: 'Important messages and job updates',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());
    await _local.show(DateTime.now().millisecondsSinceEpoch ~/ 1000, title, body, details);
  }

  Future<void> ensureUserTokenSaved() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(token);
    }
  }

  Future<void> _saveToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    await userRef.set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'notificationSettings': {
        'messages': true,
        'applications': true,
        'hires': true,
      }
    }, SetOptions(merge: true));
  }
}
