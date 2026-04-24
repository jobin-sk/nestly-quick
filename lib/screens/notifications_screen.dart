import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../theme/colors.dart';

//shows the last 7 days of notifications for the current user
//reads live from firestore so new ones show up without refreshing
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  //returns the left border color based on notification type
  //gives each type a quick visual cue without needing to read the title
  Color _getBorderColor(String type) {
    switch (type) {
      case 'list_shared':
        return AppColors.pink;
      case 'list_deleted':
        return AppColors.danger;
      case 'friend_request':
        return AppColors.primary;
      case 'item_added':
      case 'item_removed':
      default:
        return AppColors.primaryLight;
    }
  }

  //turns the raw type string from firestore into a readable title
  String _getTitle(String type) {
    switch (type) {
      case 'list_shared':
        return 'List Shared With You';
      case 'list_deleted':
        return 'List Deleted';
      case 'friend_request':
        return 'Friend Request';
      case 'item_added':
        return 'Item Added';
      case 'item_removed':
        return 'Item Removed';
      default:
        return 'Notification';
    }
  }

  //formats the firestore timestamp into relative time like "2h ago"
  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final now = DateTime.now();
    final time = timestamp.toDate();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }

  //wipes every notification for this user in one go
  //batch lets us delete multiple docs as a single atomic write instead of one network call per doc
  Future<void> _clearAll(String userId, List<DocumentSnapshot> docs) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    for (final doc in docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  //marks a notification as read and jumps to the list it points at if there is one
  Future<void> _handleTap(BuildContext context, DocumentSnapshot doc) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(doc.id)
        .update({'isRead': true});

    //referenceId points to the related list so user can jump straight to it
    final referenceId = doc['referenceId'];
    if (referenceId != null && context.mounted) {
      context.push('/dashboard/list/$referenceId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    //cutoff is 7 days ago. anything older gets filtered out of the query
    final cutoff = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(days: 7)),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.dark),
        ),
        actions: [
          //placeholder clear all in the app bar. real one is at the bottom since it needs the docs list
          TextButton(
            onPressed: () async {
              //gets wired up once we have the docs list
            },
            child: const Text(
              'Clear all',
              style: TextStyle(color: AppColors.primary, fontSize: 14),
            ),
          ),
        ],
      ),
      //streambuilder listens to firestore and auto rebuilds when data changes
      //this is what makes notifications appear live without the user refreshing
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: userId)
            .where('createdAt', isGreaterThan: cutoff)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          //spinner while firestore is loading for the first time
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          //?? [] means if snapshot.data is null default to empty list instead of crashing
          final docs = snapshot.data?.docs ?? [];

          //empty state when there are no notifications
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 64, color: AppColors.border),
                  const SizedBox(height: 16),
                  const Text(
                    'No notifications',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.subtext),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You\'re all caught up!',
                    style: TextStyle(fontSize: 14, color: AppColors.subtext),
                  ),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //small header above the list
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Text(
                  'Last 7 days',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.subtext,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              //scrollable list of notification cards
              //expanded takes up all remaining vertical space so the list scrolls instead of overflowing
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final type = doc['type'] ?? '';
                    final message = doc['message'] ?? '';
                    final isRead = doc['isRead'] ?? false;
                    final timestamp = doc['createdAt'] as Timestamp?;

                    return GestureDetector(
                      onTap: () => _handleTap(context, doc),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          //unread cards get a subtle purple tint to stand out from read ones
                          color: isRead ? AppColors.background : AppColors.primaryLighter,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        //IntrinsicHeight forces the colored strip to match the cards height
                        child: IntrinsicHeight(
                          child: Row(
                            children: [
                              //colored strip on the left side of the card
                              Container(
                                width: 4,
                                decoration: BoxDecoration(
                                  color: _getBorderColor(type),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    bottomLeft: Radius.circular(12),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          //title goes bold when unread so it stands out
                                          Text(
                                            _getTitle(type),
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                                              color: AppColors.dark,
                                            ),
                                          ),
                                          //purple dot on unread notifications
                                          if (!isRead)
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: AppColors.primary,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        message,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.subtext,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _formatTime(timestamp),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.subtext,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              //real clear all button at the bottom. has the docs list so it actually works
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: TextButton(
                  onPressed: () => _clearAll(userId!, docs),
                  child: const Text(
                    'Clear all notifications',
                    style: TextStyle(color: AppColors.danger, fontSize: 13),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}