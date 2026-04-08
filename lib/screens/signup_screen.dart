import 'package:carelink/screens/onboarding_screen.dart';
import 'package:carelink/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:carelink/widgets/auth_ui_tokens.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  late final FirebaseAuth _auth;
  late final FirebaseFirestore _firestore;
  late final GoogleSignIn _googleSignIn;

  late final GlobalKey<FormState> _formKey;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  late final FocusNode _emailFocus;
  late final FocusNode _phoneFocus;
  late final FocusNode _passwordFocus;
  late final FocusNode _confirmPasswordFocus;

  bool _isLoading = false;
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  String? _errorMessage;
  String? _selectedRole;
  int _passwordStrength = 0;

  static const List<String> _roles = ['Caregiver', 'Client'];
  static const String _passwordRegexPattern = r'[!@#\$&*~]';

  @override
  void initState() {
    super.initState();
    _auth = FirebaseAuth.instance;
    _firestore = FirebaseFirestore.instance;
    _googleSignIn = GoogleSignIn();
    
    _formKey = GlobalKey<FormState>();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _emailFocus = FocusNode();
    _phoneFocus = FocusNode();
    _passwordFocus = FocusNode();
    _confirmPasswordFocus = FocusNode();
    
    _passwordController.addListener(_validatePasswordStrength);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  /// Calculate password strength score (0-4)
  void _validatePasswordStrength() {
    final password = _passwordController.text;
    int score = 0;

    if (password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(_passwordRegexPattern).hasMatch(password)) score++;

    if (mounted) {
      setState(() => _passwordStrength = score);
    }
  }

  /// Get color based on password strength
  Color _getPasswordStrengthColor() {
    switch (_passwordStrength) {
      case 0:
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.amber.shade700;
      case 4:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  /// Get text label for password strength
  String _getPasswordStrengthText() {
    switch (_passwordStrength) {
      case 0:
      case 1:
        return 'Weak';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Strong';
      default:
        return '';
    }
  }

  /// Clear error message
  void _clearError() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  /// Show snackbar message
  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Register user with email/password
  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRole == null || _selectedRole!.isEmpty) {
      setState(() => _errorMessage = 'Please select a role before signing up.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Create user account
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = userCredential.user!.uid;

      // Store user info in Firestore
      await _firestore.collection('users').doc(uid).set({
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': _selectedRole!.toLowerCase(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'onboarded': false,
      });

      // Send verification email
      await userCredential.user!.sendEmailVerification();

      if (!mounted) return;

      _showSnackBar('Account created! Verification email sent.', isSuccess: true);

      // Navigate to onboarding
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = _getFirebaseErrorMessage(e));
    } catch (e) {
      setState(() => _errorMessage = 'Something went wrong while creating your account. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Sign up with Google
  Future<void> _signupWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final uid = userCredential.user!.uid;
      final userDocRef = _firestore.collection('users').doc(uid);

      // Check if user exists
      final userDoc = await userDocRef.get();

      if (!userDoc.exists) {
        // Create new user document
        await userDocRef.set({
          'email': userCredential.user!.email,
          'displayName': userCredential.user!.displayName,
          'role': null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'onboarded': false,
        });
      }

      if (!mounted) return;

      // Fetch updated user data
      final userData = (await userDocRef.get()).data();
      final role = userData?['role'];
      final onboarded = userData?['onboarded'] ?? false;

      // Navigate based on onboarding status
      if (role == null || !onboarded) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = _getFirebaseErrorMessage(e));
    } catch (e) {
      setState(() => _errorMessage = 'Something went wrong while signing up with Google. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Get user-friendly Firebase error message
  String _getFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Password is too weak. Use uppercase, numbers, and symbols.';
      case 'email-already-in-use':
        return 'Email is already registered. Try logging in instead.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'operation-not-allowed':
        return 'Sign up is currently disabled. Try again later.';
      default:
        return e.message ?? 'Signup failed. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthUiTokens.screenBackground,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AuthUiTokens.horizontalPadding,
          vertical: AuthUiTokens.sectionGap,
        ),
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).size.height < 700 ? 8 : 20),
                _buildLogo(),
                const SizedBox(height: 20),
                _buildHeader(),
                const SizedBox(height: 28),
                _buildEmailField(),
                const SizedBox(height: 18),
                _buildPhoneField(),
                const SizedBox(height: 18),
                _buildPasswordField(),
                const SizedBox(height: 10),
                if (_passwordController.text.isNotEmpty)
                  _buildPasswordStrengthBar(),
                const SizedBox(height: 18),
                _buildConfirmPasswordField(),
                const SizedBox(height: 18),
                _buildRoleDropdown(),
                const SizedBox(height: 22),
                if (_errorMessage != null) ...[
                  _buildErrorBox(),
                  const SizedBox(height: 20),
                ],
                _buildSignUpButton(),
                const SizedBox(height: 18),
                _buildDivider(),
                const SizedBox(height: 18),
                _buildGoogleButton(),
                const SizedBox(height: 18),
                _buildSignInLink(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Create Account'),
      backgroundColor: AuthUiTokens.primary,
      elevation: 0,
      centerTitle: true,
    );
  }

  Widget _buildLogo() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        'assets/logo.png',
        height: 80,
        width: 80,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.local_hospital,
              size: 40,
              color: Colors.green.shade600,
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const Text(
          'Join CareLink',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B5E20),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Create your account to get started',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      focusNode: _emailFocus,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.username, AutofillHints.email],
      onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_phoneFocus),
      onChanged: (_) => _clearError(),
      decoration: InputDecoration(
        labelText: 'Email',
        hintText: 'you@example.com',
        prefixIcon: const Icon(Icons.email_outlined, color: AuthUiTokens.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AuthUiTokens.inputRadius)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AuthUiTokens.inputRadius),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AuthUiTokens.inputRadius),
          borderSide: const BorderSide(color: Colors.green, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your email';
        }
        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value)) {
          return 'Enter a valid email address';
        }
        return null;
      },
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      focusNode: _phoneFocus,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.telephoneNumber],
      onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocus),
      onChanged: (_) => _clearError(),
      decoration: InputDecoration(
        labelText: 'Phone Number',
        hintText: '+254712345678',
        prefixIcon: const Icon(Icons.phone_outlined, color: AuthUiTokens.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AuthUiTokens.inputRadius)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AuthUiTokens.inputRadius),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AuthUiTokens.inputRadius),
          borderSide: const BorderSide(color: Colors.green, width: 2),
        ),
      ),
      validator: (value) {
        final input = value?.trim() ?? '';
        if (input.isEmpty) {
          return 'Please enter your phone number';
        }

        final digitsOnly = input.replaceAll(RegExp(r'\D'), '');
        if (digitsOnly.length < 9 || digitsOnly.length > 15) {
          return 'Enter a valid phone number';
        }

        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      focusNode: _passwordFocus,
      obscureText: _hidePassword,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.newPassword],
      onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_confirmPasswordFocus),
      onChanged: (_) => _clearError(),
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: const Icon(Icons.lock_outline, color: AuthUiTokens.primary),
        suffixIcon: IconButton(
          tooltip: _hidePassword ? 'Show password' : 'Hide password',
          icon: Icon(
            _hidePassword ? Icons.visibility_off : Icons.visibility,
            color: AuthUiTokens.primary,
          ),
          onPressed: () {
            setState(() => _hidePassword = !_hidePassword);
          },
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AuthUiTokens.inputRadius)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AuthUiTokens.inputRadius),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AuthUiTokens.inputRadius),
          borderSide: const BorderSide(color: Colors.green, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a password';
        }
        if (value.length < 8) {
          return 'Password must be at least 8 characters';
        }
        return null;
      },
    );
  }

  Widget _buildConfirmPasswordField() {
    return TextFormField(
      controller: _confirmPasswordController,
      focusNode: _confirmPasswordFocus,
      obscureText: _hideConfirmPassword,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.newPassword],
      onFieldSubmitted: (_) {
        if (!_isLoading) {
          _registerUser();
        }
      },
      onChanged: (_) => _clearError(),
      decoration: InputDecoration(
        labelText: 'Confirm Password',
        prefixIcon: const Icon(Icons.lock_outline, color: AuthUiTokens.primary),
        suffixIcon: IconButton(
          tooltip: _hideConfirmPassword ? 'Show password' : 'Hide password',
          icon: Icon(
            _hideConfirmPassword ? Icons.visibility_off : Icons.visibility,
            color: AuthUiTokens.primary,
          ),
          onPressed: () {
            setState(() => _hideConfirmPassword = !_hideConfirmPassword);
          },
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AuthUiTokens.inputRadius)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AuthUiTokens.inputRadius),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AuthUiTokens.inputRadius),
          borderSide: const BorderSide(color: Colors.green, width: 2),
        ),
      ),
      validator: (value) {
        if (value != _passwordController.text) {
          return 'Passwords do not match';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordStrengthBar() {
    return Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: _passwordStrength / 4,
            minHeight: 6,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation(_getPasswordStrengthColor()),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _getPasswordStrengthText(),
          style: TextStyle(
            color: _getPasswordStrengthColor(),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleDropdown() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Select your role',
        prefixIcon: const Icon(Icons.person_outline, color: AuthUiTokens.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AuthUiTokens.inputRadius)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AuthUiTokens.inputRadius),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AuthUiTokens.inputRadius),
          borderSide: const BorderSide(color: Colors.green, width: 2),
        ),
      ),
      initialValue: _selectedRole,
      items: _roles
          .map((role) => DropdownMenuItem(
                value: role,
                child: Text(role),
              ))
          .toList(),
      onChanged: (value) {
        setState(() => _selectedRole = value);
        _clearError();
      },
      validator: (value) =>
          value == null || value.isEmpty ? 'Please select your role' : null,
    );
  }

  Widget _buildErrorBox() {
    return Semantics(
      label: 'Signup error',
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border.all(color: Colors.red.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignUpButton() {
    return SizedBox(
      width: double.infinity,
      height: AuthUiTokens.buttonHeight,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _registerUser,
        style: ElevatedButton.styleFrom(
          backgroundColor: AuthUiTokens.primary,
          disabledBackgroundColor: Colors.green.shade200,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AuthUiTokens.inputRadius),
          ),
          elevation: AuthUiTokens.subtleElevation,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Sign Up',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade300)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300)),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: AuthUiTokens.buttonHeight,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _signupWithGoogle,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AuthUiTokens.inputRadius),
          ),
        ),
        icon: _buildGoogleIcon(),
        label: const Text(
          'Sign up with Google',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildGoogleIcon() {
    return SvgPicture.asset(
      'assets/google.svg',
      height: 24,
      width: 24,
      placeholderBuilder: (BuildContext context) => const SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildSignInLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Already have an account? '),
        GestureDetector(
          onTap: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          ),
          child: const Text(
            'Sign In',
            style: TextStyle(
              color: AuthUiTokens.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}