import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _timeZoneInitialized = false;

  Future<void> init() async {
    if (_initialized) return;

    await _configureLocalTimezone();

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
      await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    }

    await _local
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _local
        .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

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

  Future<void> _configureLocalTimezone() async {
    if (_timeZoneInitialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);
    _timeZoneInitialized = true;
  }

  int _stableReminderId(String key) {
    // Use FNV-1a to get a deterministic int ID from a document id.
    const int fnvPrime = 16777619;
    int hash = 2166136261;
    for (final codeUnit in key.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * fnvPrime) & 0x7fffffff;
    }
    return hash;
  }

  DateTime? _parseTimeOfDay(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    final formats = <DateFormat>[
      DateFormat('h:mm a'),
      DateFormat('h a'),
      DateFormat('HH:mm'),
      DateFormat('H:mm'),
    ];

    for (final format in formats) {
      try {
        return format.parseStrict(value);
      } catch (_) {
        // Try next format.
      }
    }
    return null;
  }

  tz.TZDateTime _nextInstanceForTime(DateTime parsedTime) {
    final nowLocal = DateTime.now();
    var nextLocal = DateTime(
      nowLocal.year,
      nowLocal.month,
      nowLocal.day,
      parsedTime.hour,
      parsedTime.minute,
    );

    if (!nextLocal.isAfter(nowLocal)) {
      nextLocal = nextLocal.add(const Duration(days: 1));
    }

    return tz.TZDateTime.from(nextLocal.toUtc(), tz.UTC);
  }

  Future<void> scheduleMedicationReminder({
    required String carePlanId,
    required String title,
    required String time,
  }) async {
    await init();

    final parsed = _parseTimeOfDay(time);
    if (parsed == null) return;

    final reminderId = _stableReminderId(carePlanId);
    final scheduleAt = _nextInstanceForTime(parsed);

    const androidDetails = AndroidNotificationDetails(
      'carelink_medication_reminders',
      'Medication Reminders',
      channelDescription: 'Daily medication reminder alerts',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _local.zonedSchedule(
      reminderId,
      'Medication Reminder',
      'Time to take $title',
      scheduleAt,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'medication:$carePlanId',
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelMedicationReminder(String carePlanId) async {
    await init();
    await _local.cancel(_stableReminderId(carePlanId));
  }

  Future<void> syncMedicationRemindersForUser(String userId) async {
    if (userId.isEmpty) return;
    await init();

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('carePlans')
        .where('type', isEqualTo: 'medication')
        .get();

    final activePlanIds = <String>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final time = (data['time'] ?? '').toString().trim();
      final isCompleted = data['isCompleted'] == true;
      final title = (data['title'] ?? 'your medication').toString().trim();

      if (time.isEmpty || isCompleted) {
        await cancelMedicationReminder(doc.id);
        continue;
      }

      activePlanIds.add(doc.id);
      await scheduleMedicationReminder(
        carePlanId: doc.id,
        title: title.isEmpty ? 'your medication' : title,
        time: time,
      );
    }

    final pending = await _local.pendingNotificationRequests();
    for (final request in pending) {
      final payload = request.payload ?? '';
      if (!payload.startsWith('medication:')) continue;

      final planId = payload.replaceFirst('medication:', '');
      if (!activePlanIds.contains(planId)) {
        await _local.cancel(request.id);
      }
    }
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
