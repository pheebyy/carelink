import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/azure_test_screen.dart';
import 'screens/payment_example_screen.dart';
import 'services/notification_service.dart';
import 'services/azure_communication_service.dart';
import 'services/paystack_service.dart';

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
    
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Initialize notification service (Spark plan - client-side only)
    await NotificationService.instance.init();
    
    // Initialize Paystack Service
    PaystackService().initialize();
    
    // Initialize Azure Communication Service
    AzureCommunicationService().initialize();
  } catch (e) {
    print(' Initialization error: $e');
  }
  runApp(const CareLinkApp());
}

class CareLinkApp extends StatelessWidget {
  const CareLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CareLink',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/login': (context) => const LoginScreen(),
        '/azure-test': (context) => const AzureTestScreen(),
        '/payment-demo': (context) => const PaymentExampleScreen(),
      },
    );
  }
}