import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:go_router/go_router.dart';
import '../theme/colors.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _searchQuery = '';

  String get _userId => _auth.currentUser!.uid;

  // Toggles the pinned state of a list
  Future<void> _togglePinList(String listId, bool currentlyPinned) async {
    await _firestore.collection('lists').doc(listId).update({
      'isPinned': !currentlyPinned,
    });
  }

  // Toggles the pinned state of a folder
  Future<void> _togglePinFolder(String folderId, bool currentlyPinned) async {
    await _firestore.collection('folders').doc(folderId).update({
      'isPinned': !currentlyPinned,
    });
  }

  // Shows long press menu for a list card
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
            // Rename option
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
              title: const Text('Rename', style: TextStyle(fontSize: 15, color: AppColors.dark)),
              onTap: () {
                Navigator.pop(context);
                _showRenameSheet(context, listId, listName, isFolder: false);
              },
            ),
            // Pin/Unpin option
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
                await _togglePinList(listId, isPinned);
              },
            ),
            // Delete option
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.danger),
              title: Text('Delete List', style: TextStyle(fontSize: 15, color: AppColors.danger)),
              onTap: () {
                Navigator.pop(context);
                _deleteList(listId, listName);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Rename bottom sheet for lists and folders
  void _showRenameSheet(BuildContext context, String id, String currentName, {required bool isFolder}) {
    final nameController = TextEditingController(text: currentName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            Text('Rename ${isFolder ? 'Folder' : 'List'}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.dark)),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: isFolder ? 'Folder name' : 'List name',
                hintStyle: const TextStyle(color: AppColors.subtext),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                final collection = isFolder ? 'folders' : 'lists';
                await _firestore.collection(collection).doc(id).update({
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

  // Shows long press menu for a folder card
  void _showFolderMenu(BuildContext context, String folderId, String folderName, bool isPinned) {
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
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text(folderName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.dark)),
            const SizedBox(height: 16),
            // Rename option
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
              title: const Text('Rename', style: TextStyle(fontSize: 15, color: AppColors.dark)),
              onTap: () {
                Navigator.pop(context);
                _showRenameSheet(context, folderId, folderName, isFolder: true);
              },
            ),
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
                await _togglePinFolder(folderId, isPinned);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.danger),
              title: Text('Delete Folder',
                  style: TextStyle(fontSize: 15, color: AppColors.danger)),
              onTap: () {
                Navigator.pop(context);
                _deleteFolder(folderId, folderName);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Deletes a standalone list and all its items and categories
  Future<void> _deleteList(String listId, String listName) async {
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
      final items = await _firestore.collection('items').where('listId', isEqualTo: listId).get();
      for (final item in items.docs) batch.delete(item.reference);
      final categories = await _firestore.collection('categories').where('listId', isEqualTo: listId).get();
      for (final cat in categories.docs) batch.delete(cat.reference);
      batch.delete(_firestore.collection('lists').doc(listId));
      await batch.commit();
    }
  }

  // Deletes a folder and everything inside it
  Future<void> _deleteFolder(String folderId, String folderName) async {
    final listsInFolder = await _firestore.collection('lists').where('folderId', isEqualTo: folderId).get();
    final listCount = listsInFolder.docs.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder?',
            style: TextStyle(color: AppColors.dark, fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(
          '"$folderName" and all $listCount ${listCount == 1 ? 'list' : 'lists'} inside it — including all items — will be permanently deleted.',
          style: const TextStyle(color: AppColors.subtext, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.subtext)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final batch = _firestore.batch();
      for (final list in listsInFolder.docs) {
        final items = await _firestore.collection('items').where('listId', isEqualTo: list.id).get();
        for (final item in items.docs) batch.delete(item.reference);
        final categories = await _firestore.collection('categories').where('listId', isEqualTo: list.id).get();
        for (final cat in categories.docs) batch.delete(cat.reference);
        batch.delete(list.reference);
      }
      batch.delete(_firestore.collection('folders').doc(folderId));
      await batch.commit();
    }
  }

  void _showCreateFolderSheet(BuildContext context) {
    final nameController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const Text('New Folder', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.dark)),
            const SizedBox(height: 16),
            TextField(controller: nameController, autofocus: true,
                decoration: const InputDecoration(hintText: 'e.g. Birthdays', hintStyle: TextStyle(color: AppColors.subtext))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                await _firestore.collection('folders').add({
                  'name': nameController.text.trim(),
                  'ownerId': _userId,
                  'isPinned': false,
                });
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Create Folder'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateListSheet(BuildContext context) {
    final nameController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const Text('New List', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.dark)),
            const SizedBox(height: 16),
            TextField(controller: nameController, autofocus: true,
                decoration: const InputDecoration(hintText: 'e.g. Groceries', hintStyle: TextStyle(color: AppColors.subtext))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                final docRef = await _firestore.collection('lists').add({
                  'name': nameController.text.trim(),
                  'ownerId': _userId,
                  'folderId': null,
                  'memberIds': [_userId],
                  'lastEditedBy': _userId,
                  'isPinned': false,
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                if (mounted) {
                  Navigator.pop(context);
                  context.push('/dashboard/list/${docRef.id}');
                }
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Lists',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.dark)),
        actions: [
          StreamBuilder(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser?.uid)
                .snapshots(),
            builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
              final data = snapshot.data?.data() as Map<String, dynamic>?;
              final username = data?['username'] ?? '?';
              final avatarColor = data?['avatarColor'] ?? '#7C3AED';
              final initial = username.isNotEmpty ? username.substring(0, 1).toUpperCase() : '?';
              final color = Color(int.parse('0xFF${avatarColor.replaceAll('#', '')}'));
              return GestureDetector(
                onTap: () => context.go('/settings'),
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: color, shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: Center(
                    child: Text(initial,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search lists...',
                hintStyle: const TextStyle(color: AppColors.subtext, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: AppColors.subtext),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: _firestore.collection('folders').where('ownerId', isEqualTo: _userId).snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> folderSnapshot) {
                return StreamBuilder(
                  stream: _firestore.collection('lists').where('memberIds', arrayContains: _userId).snapshots(),
                  builder: (context, AsyncSnapshot<QuerySnapshot> listSnapshot) {
                    if (folderSnapshot.connectionState == ConnectionState.waiting ||
                        listSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                    }

                    final folders = folderSnapshot.data?.docs ?? [];
                    final allLists = listSnapshot.data?.docs ?? [];
                    final standaloneLists = allLists.where((doc) => doc['folderId'] == null).toList();

                    // Apply search filter
                    final filteredFolders = folders
                        .where((doc) => doc['name'].toString().toLowerCase().contains(_searchQuery))
                        .toList();
                    final filteredLists = standaloneLists
                        .where((doc) => doc['name'].toString().toLowerCase().contains(_searchQuery))
                        .toList();

                    // Sort — pinned items first, then unpinned
                    final pinnedFolders = filteredFolders.where((d) {
                      final data = d.data() as Map<String, dynamic>?;
                      return data?['isPinned'] == true;
                    }).toList();
                    final unpinnedFolders = filteredFolders.where((d) {
                      final data = d.data() as Map<String, dynamic>?;
                      return data?['isPinned'] != true;
                    }).toList();
                    final pinnedLists = filteredLists.where((d) {
                      final data = d.data() as Map<String, dynamic>?;
                      return data?['isPinned'] == true;
                    }).toList();
                    final unpinnedLists = filteredLists.where((d) {
                      final data = d.data() as Map<String, dynamic>?;
                      return data?['isPinned'] != true;
                    }).toList();

                    // Final order: pinned folders + pinned lists, then unpinned folders, then unpinned lists
                    final orderedItems = [
                      ...pinnedFolders.map((d) => {'doc': d, 'type': 'folder', 'pinned': true}),
                      ...pinnedLists.map((d) => {'doc': d, 'type': 'list', 'pinned': true}),
                      ...unpinnedFolders.map((d) => {'doc': d, 'type': 'folder', 'pinned': false}),
                      ...unpinnedLists.map((d) => {'doc': d, 'type': 'list', 'pinned': false}),
                    ];

                    if (orderedItems.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.list_alt_rounded, size: 64, color: AppColors.border),
                            const SizedBox(height: 16),
                            const Text('No lists yet',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.subtext)),
                            const SizedBox(height: 8),
                            const Text('Tap + to create your first list',
                                style: TextStyle(fontSize: 14, color: AppColors.subtext)),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      itemCount: orderedItems.length,
                      itemBuilder: (context, index) {
                        final item = orderedItems[index];
                        final doc = item['doc'] as DocumentSnapshot;
                        final isPinned = item['pinned'] as bool;
                        final type = item['type'] as String;

                        if (type == 'folder') {
                          return GestureDetector(
                            onLongPress: () => _showFolderMenu(context, doc.id, doc['name'], isPinned),
                            child: _FolderCard(
                              key: ValueKey(doc.id),
                              folderId: doc.id,
                              name: doc['name'],
                              userId: _userId,
                              isPinned: isPinned,
                            ),
                          );
                        } else {
                          final isShared = (doc['memberIds'] as List).length > 1;
                          return GestureDetector(
                            onLongPress: () => _showListMenu(context, doc.id, doc['name'], isPinned),
                            child: _ListCard(
                              key: ValueKey(doc.id),
                              listId: doc.id,
                              name: doc['name'],
                              userId: _userId,
                              isShared: isShared,
                              isPinned: isPinned,
                            ),
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: SpeedDial(
        icon: Icons.add,
        activeIcon: Icons.close,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        overlayOpacity: 0.3,
        overlayColor: AppColors.dark,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.create_new_folder_outlined),
            label: 'New Folder',
            backgroundColor: AppColors.primaryLight,
            foregroundColor: AppColors.primary,
            onTap: () => _showCreateFolderSheet(context),
          ),
          SpeedDialChild(
            child: const Icon(Icons.playlist_add_rounded),
            label: 'New List',
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            onTap: () => _showCreateListSheet(context),
          ),
        ],
      ),
    );
  }
}

// Folder card widget
class _FolderCard extends StatelessWidget {
  final String folderId;
  final String name;
  final String userId;
  final bool isPinned;

  const _FolderCard({
    super.key,
    required this.folderId,
    required this.name,
    required this.userId,
    required this.isPinned,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/dashboard/folder/$folderId'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primaryLighter,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isPinned ? AppColors.primary : AppColors.border, width: isPinned ? 1.5 : 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.folder_outlined, color: AppColors.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.dark)),
                      if (isPinned) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.push_pin, size: 12, color: AppColors.primary),
                      ],
                    ],
                  ),
                  StreamBuilder(
                    stream: FirebaseFirestore.instance.collection('lists').where('folderId', isEqualTo: folderId).snapshots(),
                    builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                      final count = snapshot.data?.docs.length ?? 0;
                      return Text('$count ${count == 1 ? 'list' : 'lists'} inside',
                          style: const TextStyle(fontSize: 12, color: AppColors.subtext));
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
  }
}

// List card widget
class _ListCard extends StatelessWidget {
  final String listId;
  final String name;
  final String userId;
  final bool isShared;
  final bool isPinned;

  const _ListCard({
    super.key,
    required this.listId,
    required this.name,
    required this.userId,
    required this.isShared,
    required this.isPinned,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/dashboard/list/$listId'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
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
                      Text(name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.dark)),
                      if (isPinned) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.push_pin, size: 12, color: AppColors.primary),
                      ],
                    ],
                  ),
                  StreamBuilder(
                    stream: FirebaseFirestore.instance.collection('items').where('listId', isEqualTo: listId).snapshots(),
                    builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                      final items = snapshot.data?.docs ?? [];
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
  }
}