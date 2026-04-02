import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../theme/colors.dart';

class ShareListScreen extends StatelessWidget {
  final String listId;
  const ShareListScreen({super.key, required this.listId});

  String get _userId => FirebaseAuth.instance.currentUser!.uid;

  // Adds a user to the list's memberIds array
  Future<void> _inviteMember(BuildContext context, String userId) async {
    await FirebaseFirestore.instance.collection('lists').doc(listId).update({
      'memberIds': FieldValue.arrayUnion([userId]),
    });

    // Get the list name to use in the notification message
    final listDoc = await FirebaseFirestore.instance.collection('lists').doc(listId).get();
    final listData = listDoc.data() as Map<String, dynamic>?;
    final listName = listData?['name'] ?? 'a list';

    // Get the current user's username for the notification message
    final senderDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .get();
    final senderData = senderDoc.data() as Map<String, dynamic>?;
    final senderUsername = senderData?['username'] ?? 'Someone';

    // Send notification to the invited user
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': userId,
      'type': 'list_shared',
      'message': '$senderUsername shared "$listName" with you',
      'isRead': false,
      'referenceId': listId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite sent!')),
      );
    }
  }

  // Removes a member from the list
  Future<void> _removeMember(BuildContext context, String userId, String username) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member?',
            style: TextStyle(color: AppColors.dark, fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('Remove $username from this list?',
            style: const TextStyle(color: AppColors.subtext, fontSize: 14)),
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
      await FirebaseFirestore.instance.collection('lists').doc(listId).update({
        'memberIds': FieldValue.arrayRemove([userId]),
      });
    }
  }

  // Stops sharing — removes all members except the owner
  Future<void> _stopSharing(BuildContext context, String ownerId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Sharing?',
            style: TextStyle(color: AppColors.dark, fontSize: 16, fontWeight: FontWeight.w700)),
        content: const Text(
          'This will remove all members from this list. Only you will have access.',
          style: TextStyle(color: AppColors.subtext, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.subtext)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Stop Sharing'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Reset memberIds to just the owner
      await FirebaseFirestore.instance.collection('lists').doc(listId).update({
        'memberIds': [ownerId],
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.dark),
          onPressed: () => context.pop(),
        ),
        title: const Text('Share List',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.dark)),
      ),
      body: StreamBuilder(
        // Stream the list document to get memberIds and ownerId in real time
        stream: FirebaseFirestore.instance.collection('lists').doc(listId).snapshots(),
        builder: (context, AsyncSnapshot<DocumentSnapshot> listSnapshot) {
          if (listSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final listData = listSnapshot.data?.data() as Map<String, dynamic>?;
          final ownerId = listData?['ownerId'] ?? '';
          final memberIds = List<String>.from(listData?['memberIds'] ?? []);
          final isOwner = _userId == ownerId;

          return StreamBuilder(
            // Stream accepted friends for the add from friends section
            stream: FirebaseFirestore.instance
                .collection('friends')
                .where('status', isEqualTo: 'accepted')
                .snapshots(),
            builder: (context, AsyncSnapshot<QuerySnapshot> friendsSnapshot) {
              final allFriends = friendsSnapshot.data?.docs ?? [];

              // Filter to friends of the current user who are not already members
              final eligibleFriends = allFriends.where((doc) {
                final isMyFriend = doc['requesterId'] == _userId || doc['receiverId'] == _userId;
                final otherId = doc['requesterId'] == _userId
                    ? doc['receiverId']
                    : doc['requesterId'];
                final alreadyMember = memberIds.contains(otherId);
                return isMyFriend && !alreadyMember;
              }).toList();

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [

                  // Current members section
                  const Text('CURRENT MEMBERS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.subtext, letterSpacing: 1.2)),
                  const SizedBox(height: 10),

                  ...memberIds.map((memberId) => FutureBuilder(
                    future: FirebaseFirestore.instance.collection('users').doc(memberId).get(),
                    builder: (context, AsyncSnapshot<DocumentSnapshot> userSnap) {
                      final data = userSnap.data?.data() as Map<String, dynamic>?;
                      final username = data?['username'] ?? '';
                      final avatarColor = data?['avatarColor'] ?? '#7C3AED';
                      final isThisOwner = memberId == ownerId;
                      final color = Color(int.parse('0xFF${avatarColor.replaceAll('#', '')}'));
                      final initial = username.isNotEmpty
                          ? username.substring(0, 1).toUpperCase()
                          : '?';

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
                            // Avatar circle
                            Container(
                              width: 36, height: 36,
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
                            // Owner or Member tag
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isThisOwner ? AppColors.primaryLight : AppColors.backgroundAlt,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isThisOwner ? 'Owner' : 'Member',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isThisOwner ? AppColors.primary : AppColors.subtext,
                                ),
                              ),
                            ),
                            // Remove button — only owner can remove others, can't remove self
                            if (isOwner && !isThisOwner)
                              IconButton(
                                icon: Icon(Icons.remove_circle_outline, color: AppColors.danger, size: 20),
                                onPressed: () => _removeMember(context, memberId, username),
                              ),
                          ],
                        ),
                      );
                    },
                  )),
                  const SizedBox(height: 20),

                  // Add from friends section — only show if there are eligible friends
                  if (eligibleFriends.isNotEmpty) ...[
                    const Text('ADD FROM FRIENDS',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.subtext, letterSpacing: 1.2)),
                    const SizedBox(height: 10),

                    ...eligibleFriends.map((doc) {
                      final otherId = doc['requesterId'] == _userId
                          ? doc['receiverId']
                          : doc['requesterId'];
                      return FutureBuilder(
                        future: FirebaseFirestore.instance.collection('users').doc(otherId).get(),
                        builder: (context, AsyncSnapshot<DocumentSnapshot> userSnap) {
                          final data = userSnap.data?.data() as Map<String, dynamic>?;
                          final username = data?['username'] ?? '';
                          final avatarColor = data?['avatarColor'] ?? '#7C3AED';
                          final color = Color(int.parse('0xFF${avatarColor.replaceAll('#', '')}'));
                          final initial = username.isNotEmpty
                              ? username.substring(0, 1).toUpperCase()
                              : '?';

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
                                  width: 36, height: 36,
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
                                ElevatedButton(
                                  onPressed: () => _inviteMember(context, otherId),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Invite', style: TextStyle(fontSize: 13)),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    }),
                    const SizedBox(height: 20),
                  ],

                  // Stop sharing button — only visible to the owner
                  if (isOwner && memberIds.length > 1)
                    OutlinedButton(
                      onPressed: () => _stopSharing(context, ownerId),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.danger),
                        foregroundColor: AppColors.danger,
                      ),
                      child: const Text('Stop Sharing List',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}