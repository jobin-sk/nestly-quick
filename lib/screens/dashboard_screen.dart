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

  // Search query — filters lists and folders by name
  String _searchQuery = '';

  // Returns the current user's ID
  String get _userId => _auth.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'My Lists',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.dark,
          ),
        ),
        actions: [
          // Profile icon — navigates to settings
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, color: AppColors.dark),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search lists and items...',
                hintStyle: const TextStyle(color: AppColors.subtext, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: AppColors.subtext),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),

          // Main list — streams folders and lists from Firestore in real time
          Expanded(
            child: StreamBuilder(
              // Listen to folders owned by the current user
              stream: _firestore
                  .collection('folders')
                  .where('ownerId', isEqualTo: _userId)
                  .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> folderSnapshot) {
                return StreamBuilder(
                  // Listen to lists where user is owner or member
                  stream: _firestore
                      .collection('lists')
                      .where('memberIds', arrayContains: _userId)
                      .snapshots(),
                  builder: (context, AsyncSnapshot<QuerySnapshot> listSnapshot) {

                    // Show loading spinner while data is coming in
                    if (folderSnapshot.connectionState == ConnectionState.waiting ||
                        listSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      );
                    }

                    final folders = folderSnapshot.data?.docs ?? [];
                    final allLists = listSnapshot.data?.docs ?? [];

                    // Only show lists that are NOT inside a folder
                    final standaloneLists = allLists
                        .where((doc) => doc['folderId'] == null)
                        .toList();

                    // Apply search filter
                    final filteredFolders = folders
                        .where((doc) => doc['name']
                        .toString()
                        .toLowerCase()
                        .contains(_searchQuery))
                        .toList();

                    final filteredLists = standaloneLists
                        .where((doc) => doc['name']
                        .toString()
                        .toLowerCase()
                        .contains(_searchQuery))
                        .toList();

                    // Show empty state if user has no lists or folders
                    if (filteredFolders.isEmpty && filteredLists.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.list_alt_rounded,
                              size: 64,
                              color: AppColors.border,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No lists yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.subtext,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tap + to create your first list',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.subtext,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Build the scrollable list of folders and lists
                    return ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      itemCount: filteredFolders.length + filteredLists.length,
                      onReorder: (oldIndex, newIndex) {
                        // TODO: persist reorder order to Firestore
                      },
                      itemBuilder: (context, index) {
                        // Show folders first then standalone lists
                        if (index < filteredFolders.length) {
                          final folder = filteredFolders[index];
                          return _FolderCard(
                            key: ValueKey(folder.id),
                            folderId: folder.id,
                            name: folder['name'],
                            userId: _userId,
                          );
                        } else {
                          final list = filteredLists[index - filteredFolders.length];
                          return _ListCard(
                            key: ValueKey(list.id),
                            listId: list.id,
                            name: list['name'],
                            userId: _userId,
                            isShared: (list['memberIds'] as List).length > 1,
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

      // Speed dial FAB — expands to show New List and New Folder options
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

  // Bottom sheet for creating a new folder
  void _showCreateFolderSheet(BuildContext context) {
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
              'New Folder',
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'e.g. Birthdays',
                hintStyle: TextStyle(color: AppColors.subtext),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                // Create folder document in Firestore
                await _firestore.collection('folders').add({
                  'name': nameController.text.trim(),
                  'ownerId': _userId,
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

  // Bottom sheet for creating a new list
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
              'New List',
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'e.g. Groceries',
                hintStyle: TextStyle(color: AppColors.subtext),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                // Create list document in Firestore
                await _firestore.collection('lists').add({
                  'name': nameController.text.trim(),
                  'ownerId': _userId,
                  'folderId': null,
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
}

// Reusable folder card widget
class _FolderCard extends StatelessWidget {
  final String folderId;
  final String name;
  final String userId;

  const _FolderCard({
    super.key,
    required this.folderId,
    required this.name,
    required this.userId,
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
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.folder_outlined, color: AppColors.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.dark,
                    ),
                  ),
                  // Shows how many lists are inside this folder
                  StreamBuilder(
                    stream: FirebaseFirestore.instance
                        .collection('lists')
                        .where('folderId', isEqualTo: folderId)
                        .snapshots(),
                    builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                      final count = snapshot.data?.docs.length ?? 0;
                      return Text(
                        '$count ${count == 1 ? 'list' : 'lists'} inside',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.subtext,
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
  }
}

// Reusable list card widget
class _ListCard extends StatelessWidget {
  final String listId;
  final String name;
  final String userId;
  final bool isShared;

  const _ListCard({
    super.key,
    required this.listId,
    required this.name,
    required this.userId,
    required this.isShared,
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
            // Shared lists have a pink border to distinguish them
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
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.dark,
                    ),
                  ),
                  // Shows item count and shared status
                  StreamBuilder(
                    stream: FirebaseFirestore.instance
                        .collection('items')
                        .where('listId', isEqualTo: listId)
                        .snapshots(),
                    builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                      final items = snapshot.data?.docs ?? [];
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
  }
}