import 'package:carelink/screens/onboarding_screen.dart';
import 'package:carelink/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _googleSignIn = GoogleSignIn();

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  String? _errorMessage;
  String? _selectedRole;
  int _passwordStrength = 0;

  final List<String> _roles = ['Caregiver', 'Client'];

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePassword);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _validatePassword() {
    final p = _passwordController.text;
    int score = 0;
    if (p.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(p)) score++;
    if (RegExp(r'[0-9]').hasMatch(p)) score++;
    if (RegExp(r'[!@#\$&*~]').hasMatch(p)) score++;

    setState(() {
      _passwordStrength = score;
    });
  }

  Color _getPasswordStrengthColor() {
    switch (_passwordStrength) {
      case 0:
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow.shade700;
      case 4:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

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

  /// ✅ Register a new user with email/password and store their role
  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRole == null || _selectedRole!.isEmpty) {
      setState(() => _errorMessage = "Please select a role before signing up.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = userCredential.user!.uid;

      // Store the user info in Firestore
      await _firestore.collection('users').doc(uid).set({
        'email': _emailController.text.trim(),
        'role': _selectedRole!.toLowerCase(), // stored as 'client' or 'caregiver'
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'onboarded': false,
      });

      await userCredential.user!.sendEmailVerification();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Account created! Verification email sent."),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to onboarding after signup
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = e.message ?? "Signup failed");
    } catch (e) {
      setState(() => _errorMessage = "An unexpected error occurred: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// ✅ Sign up or sign in with Google, and ensure role setup
  Future<void> _signupWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
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
      final userDoc = await userDocRef.get();

      if (!userDoc.exists) {
        // Create a new user entry for first-time Google signup
        await userDocRef.set({
          'email': userCredential.user!.email,
          'role': null, // will be chosen later in onboarding
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'onboarded': false,
        });
      }

      if (!mounted) return;

      final userData = (await userDocRef.get()).data();
      final role = userData?['role'];
      final onboarded = userData?['onboarded'] ?? false;

      // Send them to onboarding if missing info
      if (role == null || onboarded == false) {
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
      setState(() => _errorMessage = e.message ?? "Google signup failed");
    } catch (e) {
      setState(() => _errorMessage = "An error occurred: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 🧱 UI Layout
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Create Account"),
        backgroundColor: Colors.green,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 20),
              Image.asset('assets/logo.png', height: 80),
              const SizedBox(height: 24),
              const Text(
                "Join CareLink",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B5E20),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Create your account to get started",
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),

              // Email
              _buildTextField(
                controller: _emailController,
                label: "Email",
                hint: "you@example.com",
                icon: Icons.email_outlined,
                validator: (value) {
                  if (value == null || value.isEmpty) return "Please enter your email";
                  if (!value.contains('@')) return "Enter a valid email";
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Password
              _buildPasswordField(),
              const SizedBox(height: 12),

              // Password strength
              if (_passwordController.text.isNotEmpty)
                _buildPasswordStrengthBar(),
              const SizedBox(height: 20),

              // Confirm password
              _buildConfirmPasswordField(),
              const SizedBox(height: 20),

              // Role dropdown
              _buildRoleDropdown(),
              const SizedBox(height: 24),

              if (_errorMessage != null)
                _buildErrorBox(_errorMessage!),

              const SizedBox(height: 24),

              _isLoading
                  ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.green))
                  : _buildSignUpButton(),

              const SizedBox(height: 20),

              _buildDivider(),

              const SizedBox(height: 20),

              _buildGoogleButton(),

              const SizedBox(height: 20),

              _buildSignInLink(),
            ],
          ),
        ),
      ),
    );
  }

  // 🔹 Reusable Widgets
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.green),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: validator,
    );
  }

  Widget _buildPasswordField() => TextFormField(
        controller: _passwordController,
        obscureText: _hidePassword,
        decoration: InputDecoration(
          labelText: "Password",
          prefixIcon: const Icon(Icons.lock_outline, color: Colors.green),
          suffixIcon: IconButton(
            icon: Icon(_hidePassword ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _hidePassword = !_hidePassword),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return "Please enter a password";
          if (value.length < 8) return "Password must be at least 8 characters";
          return null;
        },
      );

  Widget _buildConfirmPasswordField() => TextFormField(
        controller: _confirmPasswordController,
        obscureText: _hideConfirmPassword,
        decoration: InputDecoration(
          labelText: "Confirm Password",
          prefixIcon: const Icon(Icons.lock_outline, color: Colors.green),
          suffixIcon: IconButton(
            icon: Icon(_hideConfirmPassword ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _hideConfirmPassword = !_hideConfirmPassword),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: (value) {
          if (value != _passwordController.text) return "Passwords do not match";
          return null;
        },
      );

  Widget _buildPasswordStrengthBar() => Row(
        children: [
          Expanded(
            child: LinearProgressIndicator(
              value: _passwordStrength / 4,
              minHeight: 6,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation(_getPasswordStrengthColor()),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _getPasswordStrengthText(),
            style: TextStyle(
              color: _getPasswordStrengthColor(),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );

  Widget _buildRoleDropdown() => DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: "Select your role",
          prefixIcon: const Icon(Icons.person_outline, color: Colors.green),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        value: _selectedRole,
        items: _roles
            .map((role) => DropdownMenuItem(value: role, child: Text(role)))
            .toList(),
        onChanged: (value) => setState(() => _selectedRole = value),
        validator: (value) => (value == null || value.isEmpty)
            ? "Please select your role"
            : null,
      );

  Widget _buildErrorBox(String message) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border.all(color: Colors.red.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

  Widget _buildSignUpButton() => SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _registerUser,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text("Sign Up", style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
      );

  Widget _buildDivider() => Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade300)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text("OR"),
          ),
          Expanded(child: Divider(color: Colors.grey.shade300)),
        ],
      );

  Widget _buildGoogleButton() => SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          onPressed: _isLoading ? null : _signupWithGoogle,
          icon: Image.asset('assets/google_icon.png', height: 24, width: 24),
          label: const Text("Sign up with Google",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.grey.shade300),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );

  Widget _buildSignInLink() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("Already have an account? "),
          GestureDetector(
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
            child: const Text(
              "Sign In",
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
}
