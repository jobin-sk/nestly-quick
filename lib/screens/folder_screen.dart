import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:go_router/go_router.dart';
import '../theme/colors.dart';

class FolderScreen extends StatefulWidget {
  final String folderId;
  const FolderScreen({super.key, required this.folderId});

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _userId => _auth.currentUser!.uid;

  // Opens bottom sheet to rename folder or delete it
  void _showEditFolderSheet(BuildContext context, String currentName, List<DocumentSnapshot> lists) {
    final nameController = TextEditingController(text: currentName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sheet handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Edit Folder',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.dark),
            ),
            const SizedBox(height: 16),

            // Rename field
            const Text('Folder Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
            const SizedBox(height: 6),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                hintText: 'e.g. Birthdays',
                hintStyle: TextStyle(color: AppColors.subtext),
              ),
            ),
            const SizedBox(height: 16),

            // Save rename button
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                await _firestore.collection('folders').doc(widget.folderId).update({
                  'name': nameController.text.trim(),
                });
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
            const SizedBox(height: 12),

            // Delete folder button
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                _showDeleteConfirmation(context, currentName, lists);
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.danger),
                foregroundColor: AppColors.danger,
              ),
              child: const Text('Delete Folder'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // Confirmation dialog before deleting folder and all its lists
  void _showDeleteConfirmation(BuildContext context, String folderName, List<DocumentSnapshot> lists) {
    final listCount = lists.length;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Delete Folder?',
          style: TextStyle(color: AppColors.dark, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will permanently delete "$folderName" and all $listCount ${listCount == 1 ? 'list' : 'lists'} inside it. This cannot be undone.',
          style: const TextStyle(color: AppColors.subtext, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.subtext)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteFolderAndContents(lists);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );
  }

  // Deletes all lists inside the folder, their items, then the folder itself
  Future<void> _deleteFolderAndContents(List<DocumentSnapshot> lists) async {
    final batch = _firestore.batch();

    for (final list in lists) {
      // Delete all items belonging to this list
      final items = await _firestore
          .collection('items')
          .where('listId', isEqualTo: list.id)
          .get();
      for (final item in items.docs) {
        batch.delete(item.reference);
      }

      // Delete all categories belonging to this list
      final categories = await _firestore
          .collection('categories')
          .where('listId', isEqualTo: list.id)
          .get();
      for (final cat in categories.docs) {
        batch.delete(cat.reference);
      }

      // Delete the list itself
      batch.delete(list.reference);
    }

    // Delete the folder
    batch.delete(_firestore.collection('folders').doc(widget.folderId));

    await batch.commit();

    // Navigate back to dashboard after deletion
    if (mounted) context.go('/dashboard');
  }

  // Bottom sheet to create a new list inside this folder
  void _showCreateListSheet(BuildContext context) {
    final nameController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'New List in Folder',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.dark),
            ),
            const SizedBox(height: 16),
            const Text('List Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
            const SizedBox(height: 6),
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'e.g. Jimmy\'s Birthday',
                hintStyle: TextStyle(color: AppColors.subtext),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                // Create list with this folder's ID so it appears here
                await _firestore.collection('lists').add({
                  'name': nameController.text.trim(),
                  'ownerId': _userId,
                  'folderId': widget.folderId,
                  'memberIds': [_userId],
                  'lastEditedBy': _userId,
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Create List'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      // Stream the folder document to get its name in real time
      stream: _firestore.collection('folders').doc(widget.folderId).snapshots(),
      builder: (context, AsyncSnapshot<DocumentSnapshot> folderSnapshot) {
        final folderName = folderSnapshot.data?['name'] ?? 'Folder';

        return StreamBuilder(
          // Stream all lists inside this folder
          stream: _firestore
              .collection('lists')
              .where('folderId', isEqualTo: widget.folderId)
              .snapshots(),
          builder: (context, AsyncSnapshot<QuerySnapshot> listSnapshot) {
            final lists = listSnapshot.data?.docs ?? [];

            return Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.dark),
                  onPressed: () => context.go('/dashboard'),
                ),
                title: Text(
                  '📁 $folderName',
                  style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.dark,
                  ),
                ),
                actions: [
                  // Edit icon opens rename/delete sheet
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppColors.dark),
                    onPressed: () => _showEditFolderSheet(context, folderName, lists),
                  ),
                ],
              ),
              body: lists.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_open, size: 64, color: AppColors.border),
                    const SizedBox(height: 16),
                    const Text(
                      'No lists in this folder',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.subtext),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap + to create a list',
                      style: TextStyle(fontSize: 14, color: AppColors.subtext),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: lists.length,
                itemBuilder: (context, index) {
                  final list = lists[index];
                  final isShared = (list['memberIds'] as List).length > 1;
                  return GestureDetector(
                    onTap: () => context.push('/dashboard/list/${list.id}'),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isShared ? AppColors.pink : AppColors.border,
                          width: isShared ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.list_rounded, color: AppColors.primary, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  list['name'],
                                  style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.dark,
                                  ),
                                ),
                                // Live item count for this list
                                StreamBuilder(
                                  stream: _firestore
                                      .collection('items')
                                      .where('listId', isEqualTo: list.id)
                                      .snapshots(),
                                  builder: (context, AsyncSnapshot<QuerySnapshot> itemSnap) {
                                    final items = itemSnap.data?.docs ?? [];
                                    final total = items.length;
                                    final done = items.where((d) => d['isComplete'] == true).length;
                                    return Text(
                                      isShared
                                          ? '$total items · $done done · Shared'
                                          : '$total items · $done done',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isShared ? AppColors.pink : AppColors.subtext,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppColors.subtext),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // FAB (little + sign) to create a new list inside this folder
              floatingActionButton: FloatingActionButton(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                onPressed: () => _showCreateListSheet(context),
                child: const Icon(Icons.add),
              ),
            );
          },
        );
      },
    );
  }
}