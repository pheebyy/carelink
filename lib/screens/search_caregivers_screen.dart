import 'package:carelink/Models/usermodel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SearchCaregiversScreen extends StatefulWidget {
  const SearchCaregiversScreen({super.key});

  @override
  State<SearchCaregiversScreen> createState() => _SearchCaregiversScreenState();
}

class _SearchCaregiversScreenState extends State<SearchCaregiversScreen> {
  final _searchController = TextEditingController();
  String _selectedFilter = 'all'; // all, rating, experience, location
  String _selectedSort = 'rating'; // rating, name, experience
  final _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<List<AppUser>> _searchCaregivers(String query) {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'caregiver')
        .snapshots()
        .map((snapshot) {
      final caregivers = snapshot.docs
          .map((doc) => AppUser.fromMap(doc.id, doc.data()))
          .toList();

      // Filter by search query
      if (query.isNotEmpty) {
        caregivers.removeWhere((caregiver) {
          final name = (caregiver.name ?? '').toLowerCase();
          final location = (caregiver.location ?? '').toLowerCase();
          final spec = caregiver.specializations?.map((e) => e.toLowerCase()).join(' ') ?? '';
          final q = query.toLowerCase();

          return !name.contains(q) && !location.contains(q) && !spec.contains(q);
        });
      }

      // Sort
      switch (_selectedSort) {
        case 'rating':
          caregivers.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
          break;
        case 'name':
          caregivers.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
          break;
        case 'experience':
          caregivers.sort((a, b) => (b.experienceYears ?? 0).compareTo(a.experienceYears ?? 0));
          break;
      }

      return caregivers;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey.shade800),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Find Caregivers',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search TextField
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, location, or skills',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
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
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
                const SizedBox(height: 16),

                // Filter & Sort Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Sort dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedSort,
                          underline: const SizedBox(),
                          items: [
                            const DropdownMenuItem(
                              value: 'rating',
                              child: Text('Sort by Rating'),
                            ),
                            const DropdownMenuItem(
                              value: 'name',
                              child: Text('Sort by Name'),
                            ),
                            const DropdownMenuItem(
                              value: 'experience',
                              child: Text('Sort by Experience'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedSort = value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Filter chips
                      FilterChip(
                        label: const Text('All'),
                        selected: _selectedFilter == 'all',
                        onSelected: (selected) {
                          setState(() => _selectedFilter = 'all');
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('⭐ High Rated'),
                        selected: _selectedFilter == 'rating',
                        onSelected: (selected) {
                          setState(() => _selectedFilter = 'rating');
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('📚 Experienced'),
                        selected: _selectedFilter == 'experience',
                        onSelected: (selected) {
                          setState(() => _selectedFilter = 'experience');
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Caregivers List
          Expanded(
            child: StreamBuilder<List<AppUser>>(
              stream: _searchCaregivers(_searchController.text),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: Colors.green),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        const Text('Error loading caregivers'),
                      ],
                    ),
                  );
                }

                final caregivers = snapshot.data ?? [];

                if (caregivers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No caregivers found',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your search criteria',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: caregivers.length,
                  itemBuilder: (context, index) {
                    final caregiver = caregivers[index];
                    return _buildCaregiverCard(caregiver);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaregiverCard(AppUser caregiver) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Name, Rating
          Row(
            children: [
              // Avatar
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                  image: caregiver.profilePhotoUrl != null
                      ? DecorationImage(
                          image: NetworkImage(caregiver.profilePhotoUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: caregiver.profilePhotoUrl == null
                    ? Icon(Icons.person, size: 30, color: Colors.green.shade600)
                    : null,
              ),
              const SizedBox(width: 12),

              // Name and Rating
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      caregiver.name ?? 'Caregiver',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (caregiver.rating != null) ...[
                          Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            '${caregiver.rating!.toStringAsFixed(1)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '•',
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Icon(Icons.location_on, size: 12, color: Colors.grey.shade600),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            caregiver.location ?? 'Location not set',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Experience
          if (caregiver.experienceYears != null)
            Row(
              children: [
                Icon(Icons.work_outline, size: 14, color: Colors.blue),
                const SizedBox(width: 6),
                Text(
                  '${caregiver.experienceYears} years experience',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),

          // Specializations
          if (caregiver.specializations != null && caregiver.specializations!.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Specializations',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: caregiver.specializations!.map((spec) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        spec,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          const SizedBox(height: 12),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Opening profile of ${caregiver.name}'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
                // TODO: Navigate to caregiver profile detail screen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'View Profile',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
