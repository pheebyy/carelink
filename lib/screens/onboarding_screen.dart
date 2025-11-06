import 'package:carelink/screens/caregiverdashboard.dart';
import 'package:carelink/screens/client_dashboard.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentScreen = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _currentScreen = index),
        children: const [
          _IntroScreen(
            index: 0,
            imagePath: 'assets/Help.jpg',
            title: 'Welcome to CareCare',
            description:
                'Connecting caregivers with families in need of support and compassion.',
            accentColor: Colors.blue,
          ),
          _IntroScreen(
            index: 1,
            imagePath: 'assets/Patient.jpg',
            title: 'Quality Care',
            description:
                'Find trusted caregivers or clients matched to your skills and availability.',
            accentColor: Colors.purple,
          ),
          _IntroScreen(
            index: 2,
            imagePath: 'assets/disabled children.jpg',
            title: 'Make a Difference',
            description:
                'Build meaningful connections and provide exceptional care services.',
            accentColor: Colors.orange,
          ),
          OnboardingFormScreen(),
        ],
      ),
      bottomSheet: _currentScreen < 3 ? _buildBottomNav() : null,
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentScreen > 0)
            TextButton.icon(
              onPressed: () => _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              ),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
            )
          else
            const SizedBox(width: 80),
          _buildPageIndicator(),
          ElevatedButton.icon(
            onPressed: () => _pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.arrow_forward),
            label: Text(_currentScreen == 2 ? 'Start' : 'Next'),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      children: List.generate(
        4,
        (index) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index == _currentScreen
                ? Colors.green
                : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }
}

class _IntroScreen extends StatelessWidget {
  final int index;
  final String imagePath;
  final String title;
  final String description;
  final Color accentColor;

  const _IntroScreen({
    required this.index,
    required this.imagePath,
    required this.title,
    required this.description,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [accentColor.withOpacity(0.1), Colors.white],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor.withOpacity(0.2),
                      ),
                      child: Icon(
                        _getIconForScreen(),
                        size: 32,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForScreen() {
    switch (index) {
      case 0:
        return Icons.handshake;
      case 1:
        return Icons.health_and_safety;
      case 2:
        return Icons.favorite;
      default:
        return Icons.info;
    }
  }
}

class OnboardingFormScreen extends StatefulWidget {
  const OnboardingFormScreen({super.key});

  @override
  State<OnboardingFormScreen> createState() => _OnboardingFormScreenState();
}

class _OnboardingFormScreenState extends State<OnboardingFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _latCtrl;
  late TextEditingController _lngCtrl;
  late TextEditingController _availabilityCtrl;

  static const List<String> _allSkills = [
    'elderly care',
    'disability support',
    'child care',
    'nursing',
    'overnight',
    'cooking'
  ];
  static const List<String> _roles = ['caregiver', 'client'];

  final Set<String> _selectedSkills = {};
  String? _selectedRole;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _latCtrl = TextEditingController();
    _lngCtrl = TextEditingController();
    _availabilityCtrl = TextEditingController();
    _loadExistingUserRole();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _availabilityCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingUserRole() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final role = doc.data()?['role']?.toString().toLowerCase();

      if (role != null && mounted) {
        setState(() => _selectedRole = role);
      }
    } catch (e) {
      debugPrint('Error loading user role: $e');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRole == null || _selectedRole!.isEmpty) {
      _showSnackBar('Please select a role before continuing.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

      // Parse location data if provided
      Map<String, dynamic>? geoData;
      final lat = double.tryParse(_latCtrl.text.trim());
      final lng = double.tryParse(_lngCtrl.text.trim());

      if (lat != null && lng != null) {
        final geoPoint = GeoFirePoint(GeoPoint(lat, lng));
        geoData = geoPoint.data;
      }

      // Update user profile
      await userRef.set({
        'name': _nameCtrl.text.trim(),
        'role': _selectedRole!.toLowerCase(),
        'availability': _availabilityCtrl.text.trim(),
        'specializations': _selectedSkills.toList(),
        if (geoData != null) 'geo': geoData,
        'onboarded': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      // Navigate to appropriate dashboard
      _navigateToDashboard();
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
      debugPrint('Save error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _navigateToDashboard() {
    final destination = _selectedRole == 'caregiver'
        ? const CaregiverDashboard()
        : const ClientDashboard();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.green.shade50, Colors.white],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                const SizedBox(height: 24),
                _buildHeader(),
                const SizedBox(height: 28),
                _buildFormContainer(),
                const SizedBox(height: 24),
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Colors.green.shade400, Colors.green.shade600],
            ),
          ),
          child: const Icon(Icons.person_add, size: 40, color: Colors.white),
        ),
        const SizedBox(height: 16),
        const Text(
          'Complete Your Profile',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Help us get to know you better',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildFormContainer() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRoleSelector(),
          const SizedBox(height: 16),
          _buildNameField(),
          const SizedBox(height: 16),
          _buildAvailabilityField(),
          const SizedBox(height: 20),
          _buildSkillsSection(),
          const SizedBox(height: 20),
          _buildLocationSection(),
        ],
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select your role',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedRole,
          items: _roles
              .map((r) => DropdownMenuItem(
                    value: r,
                    child: Text(r.replaceFirst(r[0], r[0].toUpperCase())),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _selectedRole = v),
          validator: (v) =>
              v == null || v.isEmpty ? 'Please select a role' : null,
          decoration: _inputDecoration(
            label: 'Role',
            icon: Icons.person,
          ),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameCtrl,
      keyboardType: TextInputType.name,
      textInputAction: TextInputAction.next,
      decoration: _inputDecoration(
        label: 'Full Name',
        hint: 'Enter your full name',
        icon: Icons.person,
      ),
      validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
    );
  }

  Widget _buildAvailabilityField() {
    return TextFormField(
      controller: _availabilityCtrl,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.next,
      decoration: _inputDecoration(
        label: 'Availability',
        hint: 'e.g., Weekdays 9 AM - 5 PM',
        icon: Icons.access_time,
      ),
    );
  }

  Widget _buildSkillsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Skills',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _allSkills.map((skill) {
            final isSelected = _selectedSkills.contains(skill);
            return FilterChip(
              label: Text(skill),
              selected: isSelected,
              backgroundColor: Colors.grey.shade100,
              selectedColor: Colors.green.shade100,
              side: BorderSide(
                color: isSelected ? Colors.green : Colors.grey.shade300,
                width: 2,
              ),
              labelStyle: TextStyle(
                color: isSelected ? Colors.green.shade700 : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (selected) {
                setState(() {
                  selected
                      ? _selectedSkills.add(skill)
                      : _selectedSkills.remove(skill);
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Location (Optional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _latCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                decoration: _inputDecoration(
                  label: 'Latitude',
                  icon: Icons.location_on,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _lngCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                decoration: _inputDecoration(
                  label: 'Longitude',
                  icon: Icons.location_on,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade500, Colors.green.shade700],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Complete Setup',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.green),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.green, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14),
    );
  }
}