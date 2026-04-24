import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../theme/colors.dart';

//share list screen. shows current members plus a list of friends who arent already members
//owner can invite friends or remove members. non owners can only see the members list
class ShareListScreen extends StatelessWidget {
  final String listId;
  const ShareListScreen({super.key, required this.listId});

  String get _userId => FirebaseAuth.instance.currentUser!.uid;

  //adds a user to the lists memberIds array and drops them a notification
  Future<void> _inviteMember(BuildContext context, String userId) async {
    //arrayUnion adds to the array without duplicates. safer than reading the whole array and rewriting it
    await FirebaseFirestore.instance.collection('lists').doc(listId).update({
      'memberIds': FieldValue.arrayUnion([userId]),
    });

    //grab the list name so we can put it in the notification message
    final listDoc = await FirebaseFirestore.instance.collection('lists').doc(listId).get();
    final listData = listDoc.data();
    final listName = listData?['name'] ?? 'a list';

    //grab the senders username for the same reason
    final senderDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .get();
    final senderData = senderDoc.data();
    final senderUsername = senderData?['username'] ?? 'Someone';

    //drop a notification in the invited users feed so they see it in alerts
    //referenceId points back to this list so tapping the notification jumps straight to it
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

  //removes one member from the list after confirm dialog
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
      //arrayRemove is the opposite of arrayUnion. takes this user out of memberIds
      await FirebaseFirestore.instance.collection('lists').doc(listId).update({
        'memberIds': FieldValue.arrayRemove([userId]),
      });
    }
  }

  //kicks everyone off the list except the owner. basically un shares it
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
      //overwrite memberIds with just the owner. faster than removing each person one at a time
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
      //outer streambuilder listens to the list doc for live member changes
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('lists').doc(listId).snapshots(),
        builder: (context, AsyncSnapshot<DocumentSnapshot> listSnapshot) {
          if (listSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final listData = listSnapshot.data?.data() as Map<String, dynamic>?;
          final ownerId = listData?['ownerId'] ?? '';
          //cast to List<String> so we can use .contains safely below
          final memberIds = List<String>.from(listData?['memberIds'] ?? []);
          //check if current user is the owner. controls what buttons they see
          final isOwner = _userId == ownerId;

          //inner streambuilder listens to accepted friends so the invite list stays fresh
          return StreamBuilder(
            stream: FirebaseFirestore.instance
                .collection('friends')
                .where('status', isEqualTo: 'accepted')
                .snapshots(),
            builder: (context, AsyncSnapshot<QuerySnapshot> friendsSnapshot) {
              final allFriends = friendsSnapshot.data?.docs ?? [];

              //filter down to friends of current user who arent already on the list
              //two checks. first that theyre actually my friend, second that theyre not already a member
              final eligibleFriends = allFriends.where((doc) {
                final isMyFriend = doc['requesterId'] == _userId || doc['receiverId'] == _userId;
                //figure out which side of the friendship the OTHER person is on
                final otherId = doc['requesterId'] == _userId
                    ? doc['receiverId']
                    : doc['requesterId'];
                final alreadyMember = memberIds.contains(otherId);
                return isMyFriend && !alreadyMember;
              }).toList();

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [

                  //SECTION 1 current members of this list
                  const Text('CURRENT MEMBERS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.subtext, letterSpacing: 1.2)),
                  const SizedBox(height: 10),

                  //spread operator unpacks the mapped list into individual children
                  //each member row is a FutureBuilder since memberIds only stores ids not usernames
                  ...memberIds.map((memberId) => FutureBuilder(
                    future: FirebaseFirestore.instance.collection('users').doc(memberId).get(),
                    builder: (context, AsyncSnapshot<DocumentSnapshot> userSnap) {
                      final data = userSnap.data?.data() as Map<String, dynamic>?;
                      final username = data?['username'] ?? '';
                      final avatarColor = data?['avatarColor'] ?? '#7C3AED';
                      //is this specific row the owner of the list
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
                            //avatar circle with users color and first initial
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
                            //owner gets a purple tag. everyone else gets a grey member tag
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
                            //remove button. only visible to the owner and only for non owner rows
                            //this prevents owners from accidentally removing themselves
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

                  //SECTION 2 friends user can invite
                  //only renders if there are eligible friends. hides the header if empty
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
                                //invite button adds them to the lists memberIds
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

                  //stop sharing button. only owner sees it and only when there are other members to kick
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