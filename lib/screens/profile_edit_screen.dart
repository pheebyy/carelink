import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _genderCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final _availabilityCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _specializationsCtrl = TextEditingController();

  final _fs = FirestoreService();
  final _storage = StorageService();

  bool _loading = false;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data();
    if (data != null) {
      setState(() {
        _nameCtrl.text = data['name'] ?? '';
        _ageCtrl.text = data['age']?.toString() ?? '';
        _genderCtrl.text = data['gender'] ?? '';
        _experienceCtrl.text = data['experienceYears']?.toString() ?? '';
        _availabilityCtrl.text = data['availability'] ?? '';
        _locationCtrl.text = data['location'] ?? '';
        _specializationsCtrl.text = (data['specializations'] as List?)?.join(', ') ?? '';
        _photoUrl = data['profilePhotoUrl'];
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _genderCtrl.dispose();
    _experienceCtrl.dispose();
    _availabilityCtrl.dispose();
    _locationCtrl.dispose();
    _specializationsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null) return;

    final ageText = _ageCtrl.text.trim();
    final expText = _experienceCtrl.text.trim();
    final parsedAge = ageText.isEmpty ? null : int.tryParse(ageText);
    final parsedExp = expText.isEmpty ? null : int.tryParse(expText);

    if (ageText.isNotEmpty && parsedAge == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Age must be a valid number')),
      );
      return;
    }

    if (expText.isNotEmpty && parsedExp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Experience must be a valid number')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _fs.updateUser(uid, {
        'name': _nameCtrl.text.trim(),
        'age': parsedAge,
        'gender': _genderCtrl.text.trim(),
        'experienceYears': parsedExp,
        'availability': _availabilityCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'specializations': _specializationsCtrl.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
      });

      // Keep FirebaseAuth profile in sync where available.
      if (user != null) {
        await user.updateDisplayName(_nameCtrl.text.trim());
        if (_photoUrl != null && _photoUrl!.isNotEmpty) {
          await user.updatePhotoURL(_photoUrl);
        }
        await user.reload();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null) return;
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
      );
      if (image == null) return;

      final extension = image.name.contains('.')
          ? image.name.split('.').last.toLowerCase()
          : 'jpeg';
      final bytes = await image.readAsBytes();

      setState(() => _loading = true);

      final url = await _storage.uploadProfilePhoto(
        uid: uid,
        bytes: bytes,
        contentType: 'image/$extension',
      );

      // Keep FirebaseAuth photo URL in sync.
      await user?.updatePhotoURL(url);
      await user?.reload();

      if (!mounted) return;
      setState(() => _photoUrl = url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo updated'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile'), backgroundColor: Colors.green),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                      child: _photoUrl == null ? const Icon(Icons.person, size: 48) : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _pickAndUploadPhoto,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                          child: const Icon(Icons.edit, color: Colors.white, size: 18),
                        ),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ageCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Age', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _genderCtrl,
                decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _experienceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Years of Experience', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _specializationsCtrl,
                decoration: const InputDecoration(labelText: 'Specializations (comma separated)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _availabilityCtrl,
                decoration: const InputDecoration(labelText: 'Availability', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationCtrl,
                decoration: const InputDecoration(labelText: 'Location', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48), backgroundColor: Colors.green),
                      child: const Text('Save Profile'),
                    ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout from your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);

              try {
                setState(() => _loading = true);

                // Sign out from Firebase
                await FirebaseAuth.instance.signOut();

                if (mounted) {
                  // Navigate to login screen and clear all previous routes
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/login',
                    (route) => false,
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error logging out: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _loading = false);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.white),
            ),
          )
        ],
      ),
    );
  }
}
