import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _messages = true;
  bool _applications = true;
  bool _hires = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data();
    final s = (data?['notificationSettings'] as Map<String, dynamic>?) ?? {};
    setState(() {
      _messages = s['messages'] ?? true;
      _applications = s['applications'] ?? true;
      _hires = s['hires'] ?? true;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'notificationSettings': {
        'messages': _messages,
        'applications': _applications,
        'hires': _hires,
      }
    }, SetOptions(merge: true));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification settings saved')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications'), backgroundColor: Colors.green),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile(
                  title: const Text('Messages'),
                  subtitle: const Text('Notify me when I receive a new message'),
                  value: _messages,
                  onChanged: (v) => setState(() => _messages = v),
                ),
                SwitchListTile(
                  title: const Text('Applications'),
                  subtitle: const Text('Notify me when someone applies to my job'),
                  value: _applications,
                  onChanged: (v) => setState(() => _applications = v),
                ),
                SwitchListTile(
                  title: const Text('Hires'),
                  subtitle: const Text('Notify me when I am hired or a hire is confirmed'),
                  value: _hires,
                  onChanged: (v) => setState(() => _hires = v),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 48)),
                    child: const Text('Save'),
                  ),
                )
              ],
            ),
    );
  }
}
