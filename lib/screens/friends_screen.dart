import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/colors.dart';

//friends screen has 4 sections
//search results, incoming friend requests, pending requests you sent, and accepted friends
//each section is a streambuilder so it updates live when firestore changes
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final _searchController = TextEditingController();

  //holds the search results so we can show them without another network call on every keystroke
  List<DocumentSnapshot> _searchResults = [];
  bool _isSearching = false;

  //shorthand getter for the current users id since we use it in every query below
  String get _userId => _auth.currentUser!.uid;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  //searches for users by username as the user types
  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    //firestore range query trick. \uf8ff is a very high unicode char
    //so this returns every username that starts with the query string
    final results = await _firestore
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: query.trim())
        .where('username', isLessThanOrEqualTo: '${query.trim()}\uf8ff')
        .get();
    setState(() {
      //filter yourself out of your own search results
      _searchResults = results.docs.where((doc) => doc.id != _userId).toList();
      _isSearching = false;
    });
  }

  //sends a friend request
  Future<void> _sendFriendRequest(String receiverId) async {
    //check if weve already sent one to this user so we dont spam duplicates
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
    //add a friends doc with status pending
    await _firestore.collection('friends').add({
      'requesterId': _userId,
      'receiverId': receiverId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    //also drop a notification in the receivers feed so they see it next time they open alerts
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

  //accept and decline just flip the status field on the friends doc
  //the streambuilders pick up the change automatically and re render the sections
  Future<void> _acceptRequest(String friendId) async {
    await _firestore.collection('friends').doc(friendId).update({'status': 'accepted'});
  }

  Future<void> _declineRequest(String friendId) async {
    await _firestore.collection('friends').doc(friendId).update({'status': 'declined'});
  }

  //removing a friend fully deletes the doc so they can be re added later if they want
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

  //tiny helper that safely casts a snapshots data to a map
  //saves us writing the same cast on every section below
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

          //search bar. onChanged fires _searchUsers on every keystroke
          TextField(
            controller: _searchController,
            onChanged: _searchUsers,
            decoration: InputDecoration(
              hintText: 'Search by username...',
              hintStyle: const TextStyle(color: AppColors.subtext, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: AppColors.subtext),
              //x button only shows up once the user has typed something
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

          //spinner while a search is in flight
          if (_isSearching)
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),

          //SECTION 1 search results
          //only renders if we have results. spread operator unpacks them into the parent list
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
                //add button next to each search result
                trailing: ElevatedButton(
                  onPressed: () => _sendFriendRequest(user.id),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    //shrinks the button tap target to the actual visual size
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Add', style: TextStyle(fontSize: 13)),
                ),
              );
            }),
            const SizedBox(height: 16),
          ],

          //SECTION 2 incoming friend requests
          //streams all friends docs where YOU are the receiver and status is pending
          StreamBuilder(
            stream: _firestore
                .collection('friends')
                .where('receiverId', isEqualTo: _userId)
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
              final requests = snapshot.data?.docs ?? [];
              //SizedBox.shrink is an empty widget. hides the whole section when theres nothing
              if (requests.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('FRIEND REQUESTS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.subtext, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  //futurebuilder inside the map to look up the requesters username
                  //since friends doc only stores ids not names
                  ...requests.map((req) => FutureBuilder(
                    future: _firestore.collection('users').doc(req['requesterId']).get(),
                    builder: (context, AsyncSnapshot<DocumentSnapshot> userSnap) {
                      final data = _getUserData(userSnap.data);
                      final username = data?['username'] ?? '';
                      final avatarColor = data?['avatarColor'] ?? '#7C3AED';
                      return _UserRow(
                        username: username,
                        avatarColor: avatarColor,
                        //accept and decline buttons side by side
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

          //SECTION 3 pending requests YOU sent
          //same idea as section 2 but flipped. you are the requester waiting for them to respond
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
                        //no buttons here, just a pending badge since the other user hasnt responded yet
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

          //SECTION 4 accepted friends
          //friendships are a single doc so we have to check both requesterId and receiverId
          //to catch friendships where you were either side of the original request
          StreamBuilder(
            stream: _firestore
                .collection('friends')
                .where('status', isEqualTo: 'accepted')
                .snapshots(),
            builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
              final allFriends = snapshot.data?.docs ?? [];
              //filter down to only friendships involving the current user
              final friends = allFriends
                  .where((doc) => doc['requesterId'] == _userId || doc['receiverId'] == _userId)
                  .toList();

              //empty state with an icon and a hint telling user to search
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
                    //figure out who the other user is. if you sent the request its the receiver, otherwise its the requester
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
                          //remove friend icon button, opens the confirm dialog from _removeFriend
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

//private reusable row widget. every section above uses this for consistent look
//trailing is a Widget so each section can pass in whatever buttons or badges it needs
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
    //same hex to Color conversion used everywhere else in the app
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
          //colored circle with first initial of username
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
          //whatever the parent section passed in, add button, accept/decline, pending badge, or remove icon
          trailing,
        ],
      ),
    );
  }
}