import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'app_router.dart';
import 'services/notification_service.dart';
import 'services/paystack_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

/// Initialize non-critical services in the background to avoid blocking startup
void _initializeNonCriticalServices() {
  Future.microtask(() async {
    try {
      // Initialize notification service
      await NotificationService.instance.init();
      
      // Initialize Paystack Service
      PaystackService().initialize();
    } catch (e) {
      print('Non-critical service initialization error: $e');
    }
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set the status bar to transparent immediately
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Loads critical services first 
  try {
    // Loads environment variables
    await dotenv.load(fileName: ".env");
    
    // Initialize Firebase (CRITICAL - must complete before app launch)
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Initialize notification service (non-blocking - defer to background)
    _initializeNonCriticalServices();
    
  } catch (e) {
    print(' Initialization error: $e');
  }
  runApp(
    const ProviderScope(
      child: CarelinkApp(),
    ),
  );
}