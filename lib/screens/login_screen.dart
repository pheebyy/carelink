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

  /// True while we are silently checking whether a session already exists.
  /// The entire login UI is hidden until this check finishes, preventing any
  /// visual flash of the login form before the automatic redirect fires.
  bool _isCheckingSession = true;

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

  // Checks Firebase for an existing, verified session.
  Future<void> _checkIfUserLoggedIn() async {
    try {
      // Add timeout to prevent infinite waiting
      await _performSessionCheck().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('⏱️ Session check timeout - showing login form');
        },
      );
    } catch (e) {
      print('❌ Session check error: $e');
      // Fall through to show login form
    }

    // No active session (or unverified) — reveal the login form.
    if (mounted) {
      setState(() {
        _isCheckingSession = false;
      });
    }
  }

  Future<void> _performSessionCheck() async {
    final currentUser = _auth.currentUser;

    if (currentUser != null) {
      // Reload to get the freshest email-verification status from Firebase.
      await currentUser.reload();
      final refreshedUser = _auth.currentUser;

      if (refreshedUser != null && refreshedUser.emailVerified) {
        // A valid, verified session exists — redirect immediately.
        // We intentionally do NOT flip _isCheckingSession here because the
        // widget is about to be replaced by a dashboard screen.
        await _routePostLogin(refreshedUser);
        return; // Exit early; setState below must not run after navigation.
      }
    }
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    final message = e.message ?? '';
    print('🔴 Firebase Auth Error - Code: ${e.code}, Message: $message');
    
    // Check for quota/resource exhausted errors
    if (message.contains('quota') || message.contains('resource') || message.contains('exhausted')) {
      return "Service temporarily unavailable. Please try again in a few minutes.";
    }
    
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
        // Check for network-related errors in the message
        if (message.contains('connection') || message.contains('I/O error') || message.contains('reset by peer')) {
          return "Unable to connect to the server. Please check your internet connection and try again.";
        }
        return "Login failed: $message. Please try again.";
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
                    content: Text(
                        '✓ Verification email sent. Please check your inbox.'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Unable to send verification email right now. Please try again.'),
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

  // Check if account is locked due to failed attempts
  bool _isAccountLocked() {
    if (_lockedUntil == null) return false;

    final now = DateTime.now();
    if (now.isBefore(_lockedUntil!)) {
      final remaining = _lockedUntil!.difference(now);
      final minutes = remaining.inMinutes;
      final seconds = remaining.inSeconds % 60;
      final countdown =
          '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
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

  // Track failed login attempts
  void _recordFailedAttempt() {
    _failedAttempts++;
    if (_failedAttempts >= _maxFailedAttempts) {
      _lockedUntil =
          DateTime.now().add(Duration(minutes: _lockoutDurationMinutes));
      _errorMessage = 'Too many failed attempts. Account locked temporarily.';
      _isAccountLocked();
      _startLockoutTicker();
    }
  }

  // Resets failed attempts on successful login
  void _resetFailedAttempts() {
    _failedAttempts = 0;
    _lockedUntil = null;
    _lockoutCountdown = null;
    _lockoutTimer?.cancel();
  }

  // Redirects users to dashboard based on their role
  Future<void> _routePostLogin(User user) async {
    try {
      // Reload user to get latest email verification status
      await user.reload();
      final refreshed = _auth.currentUser;

      if (!mounted) return;

      // Require email verification before proceeding
      if (refreshed != null && !refreshed.emailVerified) {
        await _promptEmailVerification(refreshed);
        // Sign out the user since email is not verified
        await _auth.signOut();
        return;
      }

      // Fetch user document from Firestore
      print('📋 Fetching user document for UID: ${user.uid}');
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      final data = doc.data() ?? {};
      final role = data['role'] as String?;
      final gpsTrackingEnabled = data['gpsTrackingEnabled'] == true;

      print('👤 User role: $role, GPS enabled: $gpsTrackingEnabled');

      if (gpsTrackingEnabled) {
        print('🗺️ Starting GPS tracking...');
        await LocationTrackingService.instance.startTracking(user.uid);
      }

      // Navigate according to role
      if (role == 'caregiver') {
        print('🚀 Navigating to Caregiver Dashboard');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => CaregiverDashboard()),
        );
      } else if (role == 'client') {
        print('🚀 Navigating to Client Dashboard');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ClientDashboard()),
        );
      } else {
        // Role not set, show error
        print('⚠️ User role is not set in Firestore');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Your account setup is incomplete. Please contact support.')),
          );
        }
      }
    } catch (e) {
      print('❌ Login error in _routePostLogin: $e');
      print('📱 Exception type: ${e.runtimeType}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Error: $e')),
      );
    }
  }

  // Improved login logic with minimal retry (only for transient network errors)
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
      // Attempt login - NO RETRIES on resource exhausted errors
      print('🔐 Login attempt for $email');
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
      // Don't record failed attempts on resource/quota errors
      final message = e.message ?? '';
      if (!message.contains('resource') && !message.contains('quota') && !message.contains('exhausted')) {
        _recordFailedAttempt();
      }

      setState(() {
        _errorMessage = _friendlyAuthError(e);
        // If account locked, update message
        if (_isAccountLocked()) {
          _errorMessage =
              'Too many failed attempts. Account locked for $_lockoutDurationMinutes minutes.';
        }
      });
    } catch (e) {
      print('❌ Unexpected login error: $e');
      setState(() {
        final errorStr = e.toString();
        if (errorStr.contains('connection') || errorStr.contains('I/O error') || errorStr.contains('reset by peer')) {
          _errorMessage = 'Unable to connect to the server. Please check your internet connection and try again.';
        } else {
          _errorMessage = 'Something went wrong while signing in. Please try again.';
        }
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
    return _buildLoginForm();
  }

  Widget _buildLoginForm() {
    // ── Session check splash ──────────────────────────────────────────────────
    // Show a plain green splash while we silently verify the existing session.
    // This prevents the login form from flashing on screen before the
    // automatic redirect to a dashboard fires.
    if (_isCheckingSession) {
      return Scaffold(
        backgroundColor: Colors.green.shade600,
        body: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 3,
          ),
        ),
      );
    }

    // ── Normal login UI ───────────────────────────────────────────────────────
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── HEADER (from v1: centered, logo image, "Welcome to CareLink") ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 80, 24, 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.green.shade600,
                    Colors.green.shade400,
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: Image.asset(
                        "assets/logo.png",
                        height: 48,
                        width: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Title
                  const Text(
                    "Welcome to CareLink",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Subtitle
                  Text(
                    "Sign in to manage care plans and services",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                ],
              ),
            ),

            // ── FORM ──────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(AuthUiTokens.horizontalPadding),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Email field
                    TextFormField(
                      controller: _emailController,
                      focusNode: _emailFocus,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [
                        AutofillHints.username,
                        AutofillHints.email,
                      ],
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).requestFocus(_passwordFocus),
                      decoration: InputDecoration(
                        labelText: "Email",
                        hintText: "Enter your email",
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: Colors.green,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              AuthUiTokens.inputRadius),
                          borderSide: BorderSide(
                              color: Colors.grey.shade300, width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              AuthUiTokens.inputRadius),
                          borderSide: BorderSide(
                              color: Colors.grey.shade300, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              AuthUiTokens.inputRadius),
                          borderSide: const BorderSide(
                              color: Colors.green, width: 2),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter your email";
                        }
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                          return "Enter a valid email";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // Password field
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
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: Colors.green,
                        ),
                        suffixIcon: IconButton(
                          tooltip: _showPassword
                              ? 'Hide password'
                              : 'Show password',
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.green,
                          ),
                          onPressed: () {
                            setState(() {
                              _showPassword = !_showPassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              AuthUiTokens.inputRadius),
                          borderSide: BorderSide(
                              color: Colors.grey.shade300, width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              AuthUiTokens.inputRadius),
                          borderSide: BorderSide(
                              color: Colors.grey.shade300, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              AuthUiTokens.inputRadius),
                          borderSide: const BorderSide(
                              color: Colors.green, width: 2),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      autovalidateMode: AutovalidateMode.onUserInteraction,
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
                    const SizedBox(height: 25),

                    // Error message with animation
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
                            const Icon(Icons.lock_clock,
                                size: 16, color: Colors.red),
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

                    // Login button ("Sign In" label from v1)
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade500,
                              Colors.green.shade700,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withValues(
                                  alpha: _isLoading ? 0.08 : 0.2),
                              blurRadius: 8,
                              spreadRadius: 0,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed:
                              (_isLoading || _currentlyLocked) ? null : _loginUser,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity,
                                AuthUiTokens.buttonHeight + 6),
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AuthUiTokens.inputRadius + 2),
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
                                        color:
                                            Colors.white.withValues(alpha: 0.9),
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  _currentlyLocked ? 'Locked' : 'Sign In',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Forgot password — centered below button (from v1)
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        "Reset password",
                        style: TextStyle(
                          color: Colors.green,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Sign up button ("Create new account" label from v1)
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
                          color: Colors.green,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AuthUiTokens.inputRadius),
                        ),
                      ),
                      child: const Text(
                        "Create new account",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
