import 'package:carelink/screens/role_shell.dart';
import 'package:carelink/screens/login_screen.dart';
import 'package:carelink/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/notification_service.dart';
import '../app_router.dart'; // Optional: keep if you use named routes

class RoleLoaderScreen extends ConsumerWidget {
  const RoleLoaderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final role = ref.watch(roleProvider);
    final onboarded = ref.watch(onboardedProvider);

    // Show loading while fetching user/role/onboarding data
    if (auth.isLoading || role.isLoading || onboarded.isLoading) {
      return const _Loading();
    }

    final user = auth.value;
    final userRole = role.value;
    final isOnboarded = onboarded.value ?? false;

    // If no user logged in → go to login
    if (user == null) {
      Future.microtask(() {
        if (!context.mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      });
      return const _Loading();
    }

    // Ensure notification token saved for this user
    Future.microtask(() async {
      try {
        await NotificationService.instance.ensureUserTokenSaved();
      } catch (_) {
        // Ignore silently
      }
    });

    // If user not onboarded → send to onboarding
    if (!isOnboarded) {
      Future.microtask(() {
        if (!context.mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      });
      return const _Loading();
    }

    // Route based on role
    if (userRole == 'caregiver') {
      Future.microtask(() {
        if (!context.mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RoleShell(role: 'caregiver')),
        );
      });
      return const _Loading();
    }

    if (userRole == 'client') {
      Future.microtask(() {
        if (!context.mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RoleShell(role: 'client')),
        );
      });
      return const _Loading();
    }

    // Fallback — missing role or invalid state
    Future.microtask(() {
      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    });

    return const _Loading();
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          color: Colors.green,
        ),
      ),
    );
  }
}
