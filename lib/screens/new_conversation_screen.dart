import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../Models/usermodel.dart';
import 'conversations_chat_screen.dart';

class NewConversationScreen extends StatefulWidget {
  const NewConversationScreen({super.key});

  @override
  State<NewConversationScreen> createState() => _NewConversationScreenState();
}

class _NewConversationScreenState extends State<NewConversationScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // Debounce timer for search
  Timer? _debounceTimer;
  
  // Stream - created once, not on every rebuild
  Stream<QuerySnapshot<Map<String, dynamic>>>? _usersStream;

  @override
  void initState() {
    super.initState();
    
    // Check if user is authenticated
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint('ERROR: No authenticated user found!');
      // Don't initialize stream if user is not authenticated
      return;
    }
    
    // Initialize the stream - query all users
    // Note: This requires Firestore security rules to allow reading users collection
    try {
      _usersStream = FirebaseFirestore.instance
          .collection('users')
          .snapshots();
      debugPrint('Users stream initialized successfully for user: ${currentUser.uid}');
    } catch (e) {
      debugPrint('Error initializing users stream: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Perform efficient search with debouncing
  void _onSearchChanged(String value) {
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    final query = value.toLowerCase().trim();
    setState(() => _searchQuery = query); // Update immediately for UI feedback
    
    // Don't need additional debounce timer - just filter on the current state
    debugPrint('Search query changed to: $query');
  }

  // Efficient user matching function
  bool _matchesSearch(Map<String, dynamic> userData, String query) {
    if (query.isEmpty) return true;
    
    // Cache converted strings for efficiency
    final name = (userData['name'] ?? '').toString().toLowerCase();
    final email = (userData['email'] ?? '').toString().toLowerCase();
    
    // Match by name prefix or email prefix (more relevant than contains)
    return name.startsWith(query) || email.startsWith(query);
  }

  Future<void> _startConversation(AppUser recipient) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final currentUser = FirebaseAuth.instance.currentUser!;

    // Check if conversation already exists
    final existing = await FirebaseFirestore.instance
        .collection('conversations')
        .where('participantIds',
            arrayContains: uid)
        .get();

    String? conversationId;
    for (final doc in existing.docs) {
      final participants = List<String>.from(doc['participantIds'] ?? []);
      if (participants.contains(recipient.uid) && participants.length == 2) {
        conversationId = doc.id;
        break;
      }
    }

    // Create new conversation if it doesn't exist
    if (conversationId == null) {
      final docRef =
          await FirebaseFirestore.instance.collection('conversations').add({
        'participantIds': [uid, recipient.uid],
        'participantNames': [
          currentUser.displayName ?? 'User',
          recipient.name ?? 'User'
        ],
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'title': recipient.name ?? 'Chat',
        'unreadCount': {
          uid: 0,
          recipient.uid: 0,
        },
      });
      conversationId = docRef.id;
    }

    if (mounted) {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConversationChatScreen(
            conversationId: conversationId!,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey.shade800),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'New Message',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,  // Use debounced search
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close, color: Colors.grey.shade600),
                        onPressed: () {
                          _searchController.clear();
                          _debounceTimer?.cancel();
                          setState(() => _searchQuery = '');
                          debugPrint('Search cleared');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // Users list
          Expanded(
            child: _usersStream == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'Please log in to view users',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _usersStream,
              builder: (context, snap) {
                debugPrint('StreamBuilder state: hasData=${snap.hasData}, hasError=${snap.hasError}, connectionState=${snap.connectionState}');
                
                if (snap.hasError) {
                  debugPrint('Error in stream: ${snap.error}');
                  debugPrint('Error stack trace: ${snap.stackTrace}');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading users',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.red.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            '${snap.error}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                
                if (!snap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.green),
                  );
                }

                var docs = snap.data!.docs
                    .where((doc) => doc.id != uid) // Exclude current user
                    .toList();

                debugPrint('Total users loaded: ${docs.length}');

                // Filter by search query efficiently
                if (_searchQuery.isNotEmpty) {
                  docs = docs.where((doc) {
                    return _matchesSearch(doc.data(), _searchQuery);
                  }).toList();
                  debugPrint('Filtered to ${docs.length} results for: $_searchQuery');
                }

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No users available'
                              : 'No users found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final user = AppUser.fromMap(docs[index].id, data);

                    return InkWell(
                      onTap: () => _startConversation(user),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Avatar
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: user.profilePhotoUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        user.profilePhotoUrl!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Icon(
                                      Icons.person,
                                      color: Colors.green.shade600,
                                      size: 28,
                                    ),
                            ),
                            const SizedBox(width: 12),
                            // User info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.name ?? 'User',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          user.email,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (user.role.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: user.role == 'caregiver'
                                                ? Colors.blue.shade100
                                                : Colors.orange.shade100,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            user.role,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: user.role == 'caregiver'
                                                  ? Colors.blue.shade700
                                                  : Colors.orange.shade700,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.chevron_right, color: Colors.grey.shade400),
                          ],
                        ),
                      ),
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
