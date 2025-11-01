import 'package:carelink/screens/conversations_chat_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/role_loader_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/role_shell.dart';
import 'screens/onboarding_screen.dart';


// ─────────────── Providers ───────────────
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final roleProvider = StreamProvider<String?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((d) => d.data()?['role'] as String?);
});

final onboardedProvider = StreamProvider<bool?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((d) => d.data()?['onboarded'] as bool?);
});

// ─────────────── App Entry ───────────────
class CarelinkApp extends ConsumerWidget {
  const CarelinkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Carelink',
      initialRoute: '/loading',
      routes: {
        '/loading': (context) => const RoleLoaderScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/forgot': (context) => const ForgotPasswordScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/caregiver': (context) => const RoleShell(role: 'caregiver'),
        '/client': (context) => const RoleShell(role: 'client'),
      },
      // handle dynamic routes (e.g., /conversation)
      onGenerateRoute: (settings) {
        if (settings.name == '/conversation') {
          final args = settings.arguments as Map<String, dynamic>?;
          final id = args?['conversationId'] as String?;
          if (id == null) return null;
          return MaterialPageRoute(
            builder: (_) => ConversationChatScreen(conversationId: id),
          );
        }
        return null;
      },
    );
  }
}

