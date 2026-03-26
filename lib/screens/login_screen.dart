import 'dart:async';

import 'package:carelink/screens/caregiverdashboard.dart';
import 'package:carelink/screens/client_dashboard.dart';
import 'package:carelink/services/location_tracking_service.dart';
import 'package:carelink/screens/forgot_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carelink/widgets/auth_ui_tokens.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  bool _showPassword = false;
  int _failedAttempts = 0;
  DateTime? _lockedUntil;
  Timer? _lockoutTimer;
  String? _lockoutCountdown;

  static const int _maxFailedAttempts = 5;
  static const int _lockoutDurationMinutes = 15;

  @override
  void initState() {
    super.initState();
    _checkIfUserLoggedIn();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  /// 🔍 Check if user is already logged in
  void _checkIfUserLoggedIn() {
    final currentUser = _auth.currentUser;
    if (currentUser != null && currentUser.emailVerified) {
      // User is logged in and verified, navigate to appropriate dashboard
      _routePostLogin(currentUser);
    }
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return "The email address format is invalid. Please check and try again.";
      case 'user-disabled':
        return "This account has been disabled. Please contact support for assistance.";
      case 'user-not-found':
        return "No account found with this email. Please create an account first.";
      case 'wrong-password':
        return "Incorrect password. Please try again or reset your password.";
      case 'too-many-requests':
        return "Too many login attempts. Please try again later.";
      case 'operation-not-allowed':
        return "Login is currently unavailable. Please try again later.";
      case 'network-request-failed':
        return "Network connection failed. Please check your internet connection.";
      case 'invalid-credential':
        return "Invalid email or password. Please try again.";
      default:
        return "Login failed: ${e.message ?? 'Unknown error'}. Please try again.";
    }
  }

  Future<void> _promptEmailVerification(User user) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Verify your email'),
        content: const Text(
          'Your email is not verified yet. Please check your inbox for a verification link. Without verification, you cannot access your account.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await user.sendEmailVerification();
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✓ Verification email sent. Please check your inbox.'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to send verification email: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Resend Email'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  /// ⏱️ Check if account is locked due to failed attempts
  bool _isAccountLocked() {
    if (_lockedUntil == null) return false;
    
    final now = DateTime.now();
    if (now.isBefore(_lockedUntil!)) {
      final remaining = _lockedUntil!.difference(now);
      final minutes = remaining.inMinutes;
      final seconds = remaining.inSeconds % 60;
      final countdown = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      _lockoutCountdown = countdown;
      _errorMessage = 'Account locked. Try again in $countdown.';
      return true;
    } else {
      // Lockout expired
      _lockedUntil = null;
      _failedAttempts = 0;
      _lockoutCountdown = null;
      _lockoutTimer?.cancel();
      return false;
    }
  }

  bool get _currentlyLocked {
    if (_lockedUntil == null) return false;
    return DateTime.now().isBefore(_lockedUntil!);
  }

  void _startLockoutTicker() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!_isAccountLocked()) {
        setState(() {});
        _lockoutTimer?.cancel();
        return;
      }
      setState(() {});
    });
  }

  /// 📊 Track failed login attempts
  void _recordFailedAttempt() {
    _failedAttempts++;
    if (_failedAttempts >= _maxFailedAttempts) {
      _lockedUntil = DateTime.now().add(Duration(minutes: _lockoutDurationMinutes));
      _errorMessage = 'Too many failed attempts. Account locked temporarily.';
      _isAccountLocked();
      _startLockoutTicker();
    }
  }

  /// ✅ Reset failed attempts on successful login
  void _resetFailedAttempts() {
    _failedAttempts = 0;
    _lockedUntil = null;
    _lockoutCountdown = null;
    _lockoutTimer?.cancel();
  }

  /// 🔑 Redirects users to dashboard based on their role
  Future<void> _routePostLogin(User user) async {
    try {
      // Reload user to get latest email verification status
      await user.reload();
      final refreshed = _auth.currentUser;

      if (!mounted) return;

      // 📨 Require email verification before proceeding
      if (refreshed != null && !refreshed.emailVerified) {
        await _promptEmailVerification(refreshed);
        // Sign out the user since email is not verified
        await _auth.signOut();
        return;
      }

      // Fetch user document from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      final data = doc.data() ?? {};
      final role = data['role'] as String?;
      final gpsTrackingEnabled = data['gpsTrackingEnabled'] == true;

      if (gpsTrackingEnabled) {
        await LocationTrackingService.instance.startTracking(user.uid);
      }

      // 🚪 Navigate according to role
      if (role == 'caregiver') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => CaregiverDashboard()),
        );
      } else if (role == 'client') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ClientDashboard()),
        );
      } else {
        // Role not set, show error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User role not configured. Please contact support.')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during navigation: $e')),
      );
    }
  }

  ///  Improved login logic with account lockout
  Future<void> _loginUser() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if account is locked
    if (_isAccountLocked()) {
      setState(() {});
      return;
    }

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Attempt login
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (cred.user != null) {
        // Reset failed attempts on success
        _resetFailedAttempts();
        await _routePostLogin(cred.user!);
      }
    } on FirebaseAuthException catch (e) {
      // Record failed attempt
      _recordFailedAttempt();
      
      setState(() {
        _errorMessage = _friendlyAuthError(e);
        // If account locked, update message
        if (_isAccountLocked()) {
          _errorMessage = 'Too many failed attempts. Account locked for $_lockoutDurationMinutes minutes.';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthUiTokens.screenBackground,
      body: Stack(
        children: [
          // Gradient background header
          Container(
            height: 250,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.green.shade600, Colors.green.shade400],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AuthUiTokens.horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: const Icon(
                          Icons.lock_outline,
                          size: 32,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Welcome Back!",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Login to continue to your account",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Form card
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AuthUiTokens.horizontalPadding),
                child: Column(
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height < 700 ? 140 : 180),
                    Container(
                      padding: const EdgeInsets.all(AuthUiTokens.horizontalPadding),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AuthUiTokens.cardRadius),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            //  Email field
                            TextFormField(
                              controller: _emailController,
                              focusNode: _emailFocus,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.username, AutofillHints.email],
                              onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocus),
                              decoration: InputDecoration(
                                labelText: "Email Address",
                                hintText: "Enter your email",
                                prefixIcon: const Icon(Icons.email_outlined,
                                    color: AuthUiTokens.primary),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AuthUiTokens.inputRadius),
                                  borderSide: BorderSide(
                                      color: Colors.grey.shade300, width: 1.5),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AuthUiTokens.inputRadius),
                                  borderSide: BorderSide(
                                      color: Colors.grey.shade300, width: 1.5),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AuthUiTokens.inputRadius),
                                  borderSide: const BorderSide(
                                      color: Colors.green, width: 2),
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return "Please enter your email";
                                }
                                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                    .hasMatch(value)) {
                                  return "Enter a valid email";
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),

                            //  Password field
                            TextFormField(
                              controller: _passwordController,
                              focusNode: _passwordFocus,
                              obscureText: !_showPassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onFieldSubmitted: (_) {
                                if (!_isLoading && !_currentlyLocked) {
                                  _loginUser();
                                }
                              },
                              decoration: InputDecoration(
                                labelText: "Password",
                                hintText: "Enter your password",
                                prefixIcon: const Icon(Icons.lock_outline,
                                  color: AuthUiTokens.primary),
                                suffixIcon: IconButton(
                                  tooltip: _showPassword ? 'Hide password' : 'Show password',
                                  icon: Icon(
                                    _showPassword
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: AuthUiTokens.primary,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _showPassword = !_showPassword;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AuthUiTokens.inputRadius),
                                  borderSide: BorderSide(
                                      color: Colors.grey.shade300, width: 1.5),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AuthUiTokens.inputRadius),
                                  borderSide: BorderSide(
                                      color: Colors.grey.shade300, width: 1.5),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AuthUiTokens.inputRadius),
                                  borderSide: const BorderSide(
                                      color: Colors.green, width: 2),
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return "Please enter your password";
                                }
                                if (value.length < 6) {
                                  return "Password must be at least 6 characters";
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Forgot password
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const ForgotPasswordScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Forgot Password?',
                                    style: TextStyle(
                                      color: AuthUiTokens.primary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 8),

                            //  Error message with animation
                            AnimatedOpacity(
                              opacity: _errorMessage != null ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 300),
                              child: _errorMessage != null
                                  ? Padding(
                                      padding: const EdgeInsets.only(bottom: 16.0),
                                      child: Semantics(
                                        label: 'Login error',
                                        liveRegion: true,
                                        child: Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: Colors.red.shade300,
                                              width: 1.2,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.error_rounded,
                                                  color: Colors.red.shade700, size: 20),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  _errorMessage!,
                                                  style: TextStyle(
                                                    color: Colors.red.shade700,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),

                            if (_currentlyLocked)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    const Icon(Icons.lock_clock, size: 16, color: Colors.red),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Locked for ${_lockoutCountdown ?? '--:--'}',
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            //  Login button with improved feedback
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.green.shade500,
                                    Colors.green.shade700
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withValues(alpha: _isLoading ? 0.08 : 0.2),
                                    blurRadius: 8,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: (_isLoading || _currentlyLocked) ? null : _loginUser,
                                style: ElevatedButton.styleFrom(
                                  minimumSize:
                                      const Size(double.infinity, AuthUiTokens.buttonHeight + 6),
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AuthUiTokens.inputRadius + 2),
                                  ),
                                  disabledBackgroundColor: Colors.grey.shade300,
                                ),
                                child: _isLoading
                                    ? Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Signing in...',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white.withValues(alpha: 0.9),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        _currentlyLocked ? 'Locked' : 'Login',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Divider
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12.0),
                                  child: Text(
                                    "Don't have an account?",
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            //  Sign up button
                            OutlinedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SignupScreen(),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                minimumSize:
                                    const Size(double.infinity, AuthUiTokens.buttonHeight),
                                side: const BorderSide(
                                  color: AuthUiTokens.primary,
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AuthUiTokens.inputRadius),
                                ),
                              ),
                              child: const Text(
                                "Create Account",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AuthUiTokens.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}