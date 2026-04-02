import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../theme/colors.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  // Returns the left border color based on notification type
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

  // Returns a human readable title based on notification type
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

  // Formats the timestamp into a readable string like "2 hours ago"
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

  // Clears all notifications for the current user
  Future<void> _clearAll(String userId, List<DocumentSnapshot> docs) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    for (final doc in docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // Marks a notification as read and navigates to the relevant list
  Future<void> _handleTap(BuildContext context, DocumentSnapshot doc) async {
    // Mark as read
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(doc.id)
        .update({'isRead': true});

    // Navigate to the referenced list if there is one
    final referenceId = doc['referenceId'];
    if (referenceId != null && context.mounted) {
      context.push('/dashboard/list/$referenceId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    // Calculate the cutoff date — notifications older than 7 days are hidden
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
          // Clear all button
          TextButton(
            onPressed: () async {
              // Will be wired up once we have the docs list
            },
            child: const Text(
              'Clear all',
              style: TextStyle(color: AppColors.primary, fontSize: 14),
            ),
          ),
        ],
      ),
      body: StreamBuilder(
        // Stream notifications for this user created within the last 7 days
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: userId)
            .where('createdAt', isGreaterThan: cutoff)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          // Empty state
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
              // Last 7 days label
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

              // Notification list
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
                          // Unread notifications have a slightly tinted background
                          color: isRead ? AppColors.background : AppColors.primaryLighter,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            children: [
                              // Colored left border strip based on notification type
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
                                      // Notification title
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _getTitle(type),
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                                              color: AppColors.dark,
                                            ),
                                          ),
                                          // Unread dot indicator
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
                                      // Notification message
                                      Text(
                                        message,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.subtext,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      // Timestamp
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

              // Clear all button at bottom — wired to actual docs
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