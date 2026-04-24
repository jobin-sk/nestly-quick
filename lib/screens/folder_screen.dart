import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../theme/colors.dart';

//folder screen shows all lists inside a single folder
//user gets here by tapping a folder card on the dashboard
//basically a scoped down dashboard that only shows whats in this folder
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

  //long press menu on a list card. rename, pin, delete
  //same pattern as dashboard_screens list menu
  void _showListMenu(BuildContext context, String listId, String listName, bool isPinned) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            //grey swipe bar at top of sheet
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text(listName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.dark)),
            const SizedBox(height: 16),

            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
              title: const Text('Rename', style: TextStyle(fontSize: 15, color: AppColors.dark)),
              onTap: () {
                Navigator.pop(context);
                _showRenameListSheet(context, listId, listName);
              },
            ),

            //pin icon changes between filled and outlined based on current state
            ListTile(
              leading: Icon(
                isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: AppColors.primary,
              ),
              title: Text(
                isPinned ? 'Unpin from Top' : 'Pin to Top',
                style: const TextStyle(fontSize: 15, color: AppColors.dark),
              ),
              onTap: () async {
                Navigator.pop(context);
                //flip the pinned state in firestore
                await _firestore.collection('lists').doc(listId).update({
                  'isPinned': !isPinned,
                });
              },
            ),

            //red for destructive action so user knows this is serious
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.danger),
              title: Text('Delete List', style: TextStyle(fontSize: 15, color: AppColors.danger)),
              onTap: () {
                Navigator.pop(context);
                _deleteList(context, listId, listName);
              },
            ),
          ],
        ),
      ),
    );
  }

  //rename sheet for a list inside the folder
  void _showRenameListSheet(BuildContext context, String listId, String currentName) {
    //pre fill with current name so user only has to edit
    final nameController = TextEditingController(text: currentName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        //viewInsets.bottom keeps text field above keyboard
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
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text('Rename List',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.dark)),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'List name',
                hintStyle: TextStyle(color: AppColors.subtext),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                await _firestore.collection('lists').doc(listId).update({
                  'name': nameController.text.trim(),
                });
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  //delete a single list plus all its items and categories
  //same batch pattern as dashboard_screens delete. atomic so no orphans if network drops
  Future<void> _deleteList(BuildContext context, String listId, String listName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete List?',
            style: TextStyle(color: AppColors.dark, fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('"$listName" and all its items will be permanently deleted.',
            style: const TextStyle(color: AppColors.subtext, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.subtext)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final batch = _firestore.batch();
      //delete items, categories, then the list itself in one atomic write
      final items = await _firestore.collection('items').where('listId', isEqualTo: listId).get();
      for (final item in items.docs) {
        batch.delete(item.reference);
      }
      final categories = await _firestore.collection('categories').where('listId', isEqualTo: listId).get();
      for (final cat in categories.docs) {
        batch.delete(cat.reference);
      }
      batch.delete(_firestore.collection('lists').doc(listId));
      await batch.commit();
    }
  }

  //edit folder sheet. lets user rename the folder or delete it entirely
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
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text('Edit Folder',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.dark)),
            const SizedBox(height: 16),
            const Text('Folder Name',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
            const SizedBox(height: 6),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                hintText: 'e.g. Birthdays',
                hintStyle: TextStyle(color: AppColors.subtext),
              ),
            ),
            const SizedBox(height: 16),
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
            //delete folder button in outlined style so its less aggressive than solid red
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
          ],
        ),
      ),
    );
  }

  //confirm popup before wiping folder and all its lists
  //shows the list count so user knows exactly what theyre about to destroy
  void _showDeleteConfirmation(BuildContext context, String folderName, List<DocumentSnapshot> lists) {
    final listCount = lists.length;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder?',
            style: TextStyle(color: AppColors.dark, fontSize: 16, fontWeight: FontWeight.w700)),
        //pluralize based on count so it reads naturally
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

  //cascading delete. nukes every list in the folder plus all their items and categories, then the folder itself
  //all in one batch so its atomic, and jumps back to dashboard since this folder wont exist anymore
  Future<void> _deleteFolderAndContents(List<DocumentSnapshot> lists) async {
    final batch = _firestore.batch();
    //loop each list. for each one delete its items, its categories, then the list
    for (final list in lists) {
      final items = await _firestore.collection('items').where('listId', isEqualTo: list.id).get();
      for (final item in items.docs) {
        batch.delete(item.reference);
      }
      final categories = await _firestore.collection('categories').where('listId', isEqualTo: list.id).get();
      for (final cat in categories.docs) {
        batch.delete(cat.reference);
      }
      batch.delete(list.reference);
    }
    //finally delete the folder itself
    batch.delete(_firestore.collection('folders').doc(widget.folderId));
    await batch.commit();
    //go back to dashboard since the screen we were on doesnt exist anymore
    if (mounted) context.go('/dashboard');
  }

  //create list sheet. key difference from dashboards version is this auto assigns the folderId
  //so the new list shows up inside this folder instead of on the dashboard
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
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text('New List in Folder',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.dark)),
            const SizedBox(height: 16),
            const Text('List Name',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
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
                //folderId pre set to this folder so the new list ends up here
                await _firestore.collection('lists').add({
                  'name': nameController.text.trim(),
                  'ownerId': _userId,
                  'folderId': widget.folderId,
                  'memberIds': [_userId],
                  'lastEditedBy': _userId,
                  'isPinned': false,
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
    //nested streambuilders same as dashboard. outer gets folder doc for name, inner gets lists inside it
    return StreamBuilder(
      stream: _firestore.collection('folders').doc(widget.folderId).snapshots(),
      builder: (context, AsyncSnapshot<DocumentSnapshot> folderSnapshot) {
        final folderName = folderSnapshot.data?['name'] ?? 'Folder';

        return StreamBuilder(
          stream: _firestore
              .collection('lists')
              .where('folderId', isEqualTo: widget.folderId)
              .snapshots(),
          builder: (context, AsyncSnapshot<QuerySnapshot> listSnapshot) {
            final allLists = listSnapshot.data?.docs ?? [];

            //split into pinned and unpinned buckets then concat so pinned show up first
            final pinnedLists = allLists.where((d) {
              final data = d.data() as Map<String, dynamic>?;
              return data?['isPinned'] == true;
            }).toList();
            final unpinnedLists = allLists.where((d) {
              final data = d.data() as Map<String, dynamic>?;
              return data?['isPinned'] != true;
            }).toList();
            final lists = [...pinnedLists, ...unpinnedLists];

            return Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.dark),
                  //go not pop because we want to guarantee we land on dashboard even if navigation got weird
                  onPressed: () => context.go('/dashboard'),
                ),
                title: Text('📁 $folderName',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.dark)),
                actions: [
                  //pencil icon opens the edit folder sheet
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppColors.dark),
                    onPressed: () => _showEditFolderSheet(context, folderName, lists),
                  ),
                ],
              ),
              body: lists.isEmpty
              //empty state when folder has no lists yet
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_open, size: 64, color: AppColors.border),
                    const SizedBox(height: 16),
                    const Text('No lists in this folder',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.subtext)),
                    const SizedBox(height: 8),
                    const Text('Tap + to create a list',
                        style: TextStyle(fontSize: 14, color: AppColors.subtext)),
                  ],
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: lists.length,
                itemBuilder: (context, index) {
                  final list = lists[index];
                  final data = list.data() as Map<String, dynamic>?;
                  final isPinned = data?['isPinned'] == true;
                  //more than one member means its shared with someone else
                  final isShared = (list['memberIds'] as List).length > 1;

                  return GestureDetector(
                    onTap: () => context.push('/dashboard/list/${list.id}'),
                    onLongPress: () => _showListMenu(context, list.id, list['name'], isPinned),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        //pinned wins over shared for border color. purple for pinned, pink for shared
                        border: Border.all(
                          color: isPinned ? AppColors.primary : (isShared ? AppColors.pink : AppColors.border),
                          width: isPinned || isShared ? 1.5 : 1,
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
                                Row(
                                  children: [
                                    Text(list['name'],
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.dark)),
                                    //tiny pin icon next to pinned list names
                                    if (isPinned) ...[
                                      const SizedBox(width: 6),
                                      const Icon(Icons.push_pin, size: 12, color: AppColors.primary),
                                    ],
                                  ],
                                ),
                                //live item count plus done count
                                StreamBuilder(
                                  stream: _firestore.collection('items').where('listId', isEqualTo: list.id).snapshots(),
                                  builder: (context, AsyncSnapshot<QuerySnapshot> itemSnap) {
                                    final items = itemSnap.data?.docs ?? [];
                                    final total = items.length;
                                    final done = items.where((d) => d['isComplete'] == true).length;
                                    return Text(
                                      isShared ? '$total items · $done done · Shared' : '$total items · $done done',
                                      style: TextStyle(fontSize: 12, color: isShared ? AppColors.pink : AppColors.subtext),
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
              //plus button opens the create list sheet. new lists auto go into this folder
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