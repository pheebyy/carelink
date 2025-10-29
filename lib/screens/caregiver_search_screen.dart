import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

class CaregiverSearchScreen extends StatefulWidget {
  const CaregiverSearchScreen({super.key});

  @override
  State<CaregiverSearchScreen> createState() =>
      _CaregiverSearchScreenState();
}

class _CaregiverSearchScreenState extends State<CaregiverSearchScreen> {
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  double _radius = 10.0;

  final List<String> _allSkills = const [
    'elderly care',
    'disability support',
    'child care',
    'nursing',
    'overnight',
    'cooking'
  ];

  final Set<String> _skills = {};
  Stream<List<DocumentSnapshot>>? _stream;

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  void _search() {
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());

    if (lat == null || lng == null) {
      // Skill-only search fallback
      setState(() {
        _stream = FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'caregiver')
            .where(
              'specializations',
              arrayContainsAny: _skills.isEmpty
                  ? ['elderly care']
                  : _skills.toList(),
            )
            .snapshots()
            .map((s) => s.docs);
      });
      return;
    }

    // Create a geolocation point
    final center = GeoFirePoint(GeoPoint(lat, lng));

    // Use the raw collection reference
    final collectionRef = FirebaseFirestore.instance.collection('users');

    // Get nearby documents using geoflutterfire_plus syntax
    final stream = GeoCollectionReference(collectionRef).within(
      center: center,
      radius: _radius,
      field: 'geo',
    );

    setState(() {
      _stream = stream.map((docs) {
        // Filter by role and skills locally
        return docs.where((d) {
          final data = d.data() as Map<String, dynamic>? ?? {};

          // Check if user is a caregiver
          if (data['role'] != 'caregiver') return false;

          // If no skills selected, return all caregivers
          if (_skills.isEmpty) return true;

          // Check if caregiver has any of the selected skills
          final specializations =
              (data['specializations'] as List?)?.map((e) => e.toString()).toList() ?? [];
          return specializations.any((s) => _skills.contains(s));
        }).toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Caregivers'),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _latCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _lngCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Radius: '),
                    Expanded(
                      child: Slider(
                        value: _radius,
                        min: 1,
                        max: 50,
                        divisions: 49,
                        label: '${_radius.round()} km',
                        onChanged: (v) => setState(() => _radius = v),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: _allSkills
                      .map((s) => FilterChip(
                            label: Text(s),
                            selected: _skills.contains(s),
                            onSelected: (v) =>
                                setState(() => v ? _skills.add(s) : _skills.remove(s)),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _search,
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Search'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _stream == null
                ? const Center(
                    child: Text('Enter location or select skills and search'),
                  )
                : StreamBuilder<List<DocumentSnapshot>>(
                    stream: _stream,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snap.hasData || snap.data!.isEmpty) {
                        return const Center(child: Text('No caregivers found'));
                      }
                      final docs = snap.data!;
                      return ListView.separated(
                        itemCount: docs.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final data =
                              docs[i].data() as Map<String, dynamic>? ?? {};
                          final name = data['name'] ?? data['email'] ?? 'Caregiver';
                          final specializations = (data['specializations'] as List?)
                                  ?.join(', ') ??
                              '';
                          return ListTile(
                            title: Text(name),
                            subtitle: Text(specializations),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

extension on GeoCollectionReference<Map<String, dynamic>> {
  within({required GeoFirePoint center, required double radius, required String field}) {}
}