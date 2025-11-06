import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class CaregiverSearchScreen extends StatefulWidget {
  const CaregiverSearchScreen({super.key});

  @override
  State<CaregiverSearchScreen> createState() =>
      _CaregiverSearchScreenState();
}

class _CaregiverSearchScreenState extends State<CaregiverSearchScreen> {
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  double _radius = 10.0;
  bool _isLoading = false;
  String? _errorMessage;

  static const List<String> allSkills = [
    'elderly care',
    'disability support',
    'child care',
    'nursing',
    'overnight',
    'cooking',
    'Post-surgery care',
    'dementia care'
  ];

  late final Set<String> _selectedSkills;
  Stream<List<DocumentSnapshot>>? _stream;

  @override
  void initState() {
    super.initState();
    _latCtrl = TextEditingController();
    _lngCtrl = TextEditingController();
    _selectedSkills = {};
  }

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  void _search() {
    // Clear previous error
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());

    // Validate input
    if ((lat == null || lng == null) && _selectedSkills.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter location or select at least one skill';
        _isLoading = false;
      });
      return;
    }

    // If no skills selected, default to all skills
    final skillsToSearch =
        _selectedSkills.isEmpty ? allSkills.toList() : _selectedSkills.toList();

    if (lat == null || lng == null) {
      // Skill-only search
      _performSkillOnlySearch(skillsToSearch);
    } else {
      // Geo + skill search
      _performGeoSearch(lat, lng, skillsToSearch);
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _performSkillOnlySearch(List<String> skills) {
    setState(() {
      _stream = FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'caregiver')
          .where('specializations', arrayContainsAny: skills)
          .snapshots()
          .map((s) => s.docs);
    });
  }

  void _performGeoSearch(double lat, double lng, List<String> skills) {
    final collectionRef = FirebaseFirestore.instance.collection('users');

    // Listen to caregiver documents and filter by distance + skills on the client side.
    setState(() {
      _stream = collectionRef.snapshots().map((snap) {
        return snap.docs.where((d) {
          final data = d.data() as Map<String, dynamic>? ?? {};

          if (data['role'] != 'caregiver') return false;

          // extract geo information (supports GeoPoint or simple map with latitude/longitude)
          double? docLat;
          double? docLng;
          final geo = data['geo'];
          if (geo is GeoPoint) {
            docLat = geo.latitude;
            docLng = geo.longitude;
          } else if (geo is Map) {
            if (geo['geopoint'] is GeoPoint) {
              final gp = geo['geopoint'] as GeoPoint;
              docLat = gp.latitude;
              docLng = gp.longitude;
            } else if (geo['latitude'] is num && geo['longitude'] is num) {
              docLat = (geo['latitude'] as num).toDouble();
              docLng = (geo['longitude'] as num).toDouble();
            }
          }

          if (docLat == null || docLng == null) return false;

          final distanceKm = _distanceInKm(lat, lng, docLat, docLng);
          if (distanceKm > _radius) return false;

          final specializations = (data['specializations'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];

          return specializations.any((s) => skills.contains(s));
        }).toList();
      });
    });
  }

  // Haversine formula to compute distance in kilometers between two coordinates
  double _distanceInKm(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371; // Earth's radius in km
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Caregivers'),
        backgroundColor: Colors.green,
        elevation: 2,
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLocationInputs(),
                  const SizedBox(height: 12),
                  _buildRadiusSlider(),
                  const SizedBox(height: 12),
                  _buildSkillsFilter(),
                  const SizedBox(height: 12),
                  _buildSearchButton(),
                  if (_errorMessage != null) _buildErrorMessage(),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationInputs() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _latCtrl,
            decoration: InputDecoration(
              labelText: 'Latitude',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              hintText: 'e.g., 40.7128',
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _lngCtrl,
            decoration: InputDecoration(
              labelText: 'Longitude',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              hintText: 'e.g., -74.0060',
            ),
            keyboardType: TextInputType.number,
          ),
        ),
      ],
    );
  }

  Widget _buildRadiusSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Search Radius: ${_radius.round()} km',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Slider(
          value: _radius,
          min: 1,
          max: 50,
          divisions: 49,
          label: '${_radius.round()} km',
          onChanged: (v) => setState(() => _radius = v),
        ),
      ],
    );
  }

  Widget _buildSkillsFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Skills (optional)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: allSkills
              .map((skill) => FilterChip(
                    label: Text(skill),
                    selected: _selectedSkills.contains(skill),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedSkills.add(skill);
                        } else {
                          _selectedSkills.remove(skill);
                        }
                      });
                    },
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildSearchButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _search,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          disabledBackgroundColor: Colors.grey,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Icon(Icons.search),
        label: Text(_isLoading ? 'Searching...' : 'Search'),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          border: Border.all(color: Colors.red),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_stream == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Enter location or select skills\nand tap Search',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<List<DocumentSnapshot>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snap.hasError) {
          return Center(
            child: Text(
              'Error: ${snap.error}',
              style: TextStyle(color: Colors.red.shade700),
            ),
          );
        }

        if (!snap.hasData || snap.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_off, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text('No caregivers found'),
              ],
            ),
          );
        }

        final docs = snap.data!;
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>? ?? {};
            return _buildCaregiverTile(data);
          },
        );
      },
    );
  }

  Widget _buildCaregiverTile(Map<String, dynamic> data) {
    final name = data['name'] ?? data['email'] ?? 'Caregiver';
    final specializations =
        (data['specializations'] as List?)?.join(', ') ?? 'No specializations';
    final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;

    return ListTile(
      leading: CircleAvatar(
        child: Text(name[0].toUpperCase()),
      ),
      title: Text(name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(specializations, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (rating > 0)
            Row(
              children: [
                const Icon(Icons.star, size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                Text('$rating/5.0'),
              ],
            ),
        ],
      ),
      isThreeLine: true,
    );
  }
}