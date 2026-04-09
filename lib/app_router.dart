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
import 'screens/vitals_ble_screen.dart';
import 'screens/caregiver_active_jobs_screen.dart';
import 'screens/client_job_management_screen.dart';
import 'screens/job_completion_screen.dart';
import 'screens/job_applicants_screen.dart';
import 'screens/review_submission_screen.dart';
import 'screens/caregiver_analytics_dashboard.dart';
import 'screens/caregiver_availability_screen.dart';
import 'screens/job_search_filter_screen.dart';
import 'screens/payment_caregiver_verification_screen.dart';
import 'screens/caregiver_payment_history_screen.dart';
import 'screens/client_payment_history_screen.dart';
import 'screens/dispute_and_refund_screen.dart';
import 'screens/admin_payment_dashboard_screen.dart';
import 'Models/Job_model.dart';
import 'Models/payment_model.dart';


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
        '/vitals-ble': (context) => const VitalsBleScreen(),
        '/caregiver-jobs': (context) => const CaregiveActiveJobsScreen(),
        '/client-jobs': (context) => const ClientJobManagementScreen(),
        '/caregiver-analytics': (context) => const CaregiverAnalyticsDashboard(),
        '/caregiver-availability': (context) => const CaregiverAvailabilityScreen(),
        '/job-search': (context) => const JobSearchFilterScreen(),
        '/caregiver-payment-history': (context) => const CaregiverPaymentHistoryScreen(),
        '/client-payment-history': (context) => const ClientPaymentHistoryScreen(),
        '/admin-payment-dashboard': (context) => const AdminPaymentDashboardScreen(),
      },
      // handle dynamic routes (e.g., /conversation, /job-completion, /review)
      onGenerateRoute: (settings) {
        // ===== CONVERSATION ROUTE =====
        if (settings.name == '/conversation') {
          final args = settings.arguments as Map<String, dynamic>?;
          final id = args?['conversationId'] as String?;
          if (id == null) return null;
          return MaterialPageRoute(
            builder: (_) => ConversationChatScreen(conversationId: id),
          );
        }

        // ===== JOB COMPLETION ROUTE =====
        if (settings.name == '/job-completion') {
          final job = settings.arguments as JobModel?;
          if (job == null) return null;
          return MaterialPageRoute(
            builder: (_) => JobCompletionScreen(job: job),
          );
        }

        // ===== JOB APPLICANTS ROUTE =====
        if (settings.name == '/job-applicants') {
          final job = settings.arguments as JobModel?;
          if (job == null) return null;
          return MaterialPageRoute(
            builder: (_) => JobApplicantsScreen(job: job),
          );
        }

        // ===== REVIEW SUBMISSION ROUTE =====
        if (settings.name == '/review') {
          final job = settings.arguments as JobModel?;
          if (job == null) return null;
          return MaterialPageRoute(
            builder: (_) => ReviewSubmissionScreen(job: job),
          );
        }

        // ===== PAYMENT CAREGIVER VERIFICATION ROUTE =====
        if (settings.name == '/payment-verification') {
          final args = settings.arguments as Map<String, dynamic>?;
          final job = args?['job'] as JobModel?;
          final caregiverId = args?['caregiverId'] as String?;
          if (job == null || caregiverId == null) return null;
          return MaterialPageRoute(
            builder: (_) => PaymentCaregiverVerificationScreen(
              job: job,
              caregiverId: caregiverId,
            ),
          );
        }

        // ===== DISPUTE AND REFUND ROUTE =====
        if (settings.name == '/dispute') {
          final args = settings.arguments as Map<String, dynamic>?;
          final transaction = args?['transaction'] as PaymentTransaction?;
          final transactionId = args?['transactionId'] as String?;
          return MaterialPageRoute(
            builder: (_) => DisputeAndRefundScreen(
              transaction: transaction,
              transactionId: transactionId,
            ),
          );
        }

        return null;
      },
    );
  }
}

