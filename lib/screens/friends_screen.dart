import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/colors.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final _searchController = TextEditingController();

  List<DocumentSnapshot> _searchResults = [];
  bool _isSearching = false;

  String get _userId => _auth.currentUser!.uid;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    final results = await _firestore
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: query.trim())
        .where('username', isLessThanOrEqualTo: '${query.trim()}\uf8ff')
        .get();
    setState(() {
      _searchResults = results.docs.where((doc) => doc.id != _userId).toList();
      _isSearching = false;
    });
  }

  Future<void> _sendFriendRequest(String receiverId) async {
    final existing = await _firestore
        .collection('friends')
        .where('requesterId', isEqualTo: _userId)
        .where('receiverId', isEqualTo: receiverId)
        .get();
    if (existing.docs.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request already sent')),
        );
      }
      return;
    }
    await _firestore.collection('friends').add({
      'requesterId': _userId,
      'receiverId': receiverId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _firestore.collection('notifications').add({
      'userId': receiverId,
      'type': 'friend_request',
      'message': 'You have a new friend request',
      'isRead': false,
      'referenceId': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request sent!')),
      );
      setState(() {
        _searchResults = [];
        _searchController.clear();
      });
    }
  }

  Future<void> _acceptRequest(String friendId) async {
    await _firestore.collection('friends').doc(friendId).update({'status': 'accepted'});
  }

  Future<void> _declineRequest(String friendId) async {
    await _firestore.collection('friends').doc(friendId).update({'status': 'declined'});
  }

  Future<void> _removeFriend(String friendId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend?',
            style: TextStyle(color: AppColors.dark, fontSize: 16, fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to remove this friend?',
            style: TextStyle(color: AppColors.subtext, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.subtext)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _firestore.collection('friends').doc(friendId).delete();
    }
  }

  // Helper to safely read user data from a snapshot
  Map<String, dynamic>? _getUserData(DocumentSnapshot? doc) {
    return doc?.data() as Map<String, dynamic>?;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Friends',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.dark)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // Search bar
          TextField(
            controller: _searchController,
            onChanged: _searchUsers,
            decoration: InputDecoration(
              hintText: 'Search by username...',
              hintStyle: const TextStyle(color: AppColors.subtext, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: AppColors.subtext),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear, color: AppColors.subtext),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchResults = []);
                },
              )
                  : null,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
          const SizedBox(height: 8),

          if (_isSearching)
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),

          // Search results — all use null-safe data pattern
          if (_searchResults.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('SEARCH RESULTS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.subtext, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            ..._searchResults.map((user) {
              final data = _getUserData(user);
              final username = data?['username'] ?? '';
              final avatarColor = data?['avatarColor'] ?? '#7C3AED';
              return _UserRow(
                username: username,
                avatarColor: avatarColor,
                trailing: ElevatedButton(
                  onPressed: () => _sendFriendRequest(user.id),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Add', style: TextStyle(fontSize: 13)),
                ),
              );
            }),
            const SizedBox(height: 16),
          ],

          // Incoming friend requests
          StreamBuilder(
            stream: _firestore
                .collection('friends')
                .where('receiverId', isEqualTo: _userId)
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
              final requests = snapshot.data?.docs ?? [];
              if (requests.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('FRIEND REQUESTS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.subtext, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  ...requests.map((req) => FutureBuilder(
                    future: _firestore.collection('users').doc(req['requesterId']).get(),
                    builder: (context, AsyncSnapshot<DocumentSnapshot> userSnap) {
                      final data = _getUserData(userSnap.data);
                      final username = data?['username'] ?? '';
                      final avatarColor = data?['avatarColor'] ?? '#7C3AED';
                      return _UserRow(
                        username: username,
                        avatarColor: avatarColor,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton(
                              onPressed: () => _acceptRequest(req.id),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Accept', style: TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 6),
                            OutlinedButton(
                              onPressed: () => _declineRequest(req.id),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                side: const BorderSide(color: AppColors.border),
                                foregroundColor: AppColors.subtext,
                              ),
                              child: const Text('Decline', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      );
                    },
                  )),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),

          // Pending requests you sent
          StreamBuilder(
            stream: _firestore
                .collection('friends')
                .where('requesterId', isEqualTo: _userId)
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
              final pending = snapshot.data?.docs ?? [];
              if (pending.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PENDING',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.subtext, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  ...pending.map((req) => FutureBuilder(
                    future: _firestore.collection('users').doc(req['receiverId']).get(),
                    builder: (context, AsyncSnapshot<DocumentSnapshot> userSnap) {
                      final data = _getUserData(userSnap.data);
                      final username = data?['username'] ?? '';
                      final avatarColor = data?['avatarColor'] ?? '#7C3AED';
                      return _UserRow(
                        username: username,
                        avatarColor: avatarColor,
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLighter,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Text('Pending',
                              style: TextStyle(fontSize: 12, color: AppColors.subtext)),
                        ),
                      );
                    },
                  )),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),

          // Accepted friends list
          StreamBuilder(
            stream: _firestore
                .collection('friends')
                .where('status', isEqualTo: 'accepted')
                .snapshots(),
            builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
              final allFriends = snapshot.data?.docs ?? [];
              final friends = allFriends
                  .where((doc) => doc['requesterId'] == _userId || doc['receiverId'] == _userId)
                  .toList();

              if (friends.isEmpty) {
                return Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      Icon(Icons.people_outline_rounded, size: 64, color: AppColors.border),
                      const SizedBox(height: 16),
                      const Text('No friends yet',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.subtext)),
                      const SizedBox(height: 8),
                      const Text('Search for someone by username to add them',
                          style: TextStyle(fontSize: 14, color: AppColors.subtext),
                          textAlign: TextAlign.center),
                    ],
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('FRIENDS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.subtext, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  ...friends.map((doc) {
                    final otherId = doc['requesterId'] == _userId
                        ? doc['receiverId']
                        : doc['requesterId'];
                    return FutureBuilder(
                      future: _firestore.collection('users').doc(otherId).get(),
                      builder: (context, AsyncSnapshot<DocumentSnapshot> userSnap) {
                        final data = _getUserData(userSnap.data);
                        final username = data?['username'] ?? '';
                        final avatarColor = data?['avatarColor'] ?? '#7C3AED';
                        return _UserRow(
                          username: username,
                          avatarColor: avatarColor,
                          trailing: IconButton(
                            icon: const Icon(Icons.person_remove_outlined,
                                color: AppColors.subtext, size: 20),
                            onPressed: () => _removeFriend(doc.id),
                          ),
                        );
                      },
                    );
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final String username;
  final String avatarColor;
  final Widget trailing;

  const _UserRow({
    required this.username,
    required this.avatarColor,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse('0xFF${avatarColor.replaceAll('#', '')}'));
    final initial = username.isNotEmpty ? username.substring(0, 1).toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Center(
              child: Text(initial,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(username,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.dark)),
          ),
          trailing,
        ],
      ),
    );
  }
}