import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:go_router/go_router.dart';
import '../theme/colors.dart';

//main landing screen after login. shows all folders and lists the user owns or is a member of
//also handles creating new folders/lists via the floating action button
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  //what the user typed in the search bar. lowercased for case insensitive matching
  String _searchQuery = '';

  //shorthand getter for current user id since its used in almost every query below
  String get _userId => _auth.currentUser!.uid;

  //safely reads isPinned from any doc. returns false if the field doesnt exist
  //needed because older docs from before pinning was added wont have this field
  bool _isPinned(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return data?['isPinned'] == true;
  }

  //flips the pinned state on a list doc
  Future<void> _togglePinList(String listId, bool currentlyPinned) async {
    await _firestore.collection('lists').doc(listId).update({'isPinned': !currentlyPinned});
  }

  //same but for folder docs
  Future<void> _togglePinFolder(String folderId, bool currentlyPinned) async {
    await _firestore.collection('folders').doc(folderId).update({'isPinned': !currentlyPinned});
  }

  //long press menu on a list card. shows rename, pin, delete options
  void _showListMenu(BuildContext context, String listId, String listName, bool isPinned) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            //little grey swipe bar at the top of the sheet
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            Text(listName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.dark)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
              title: const Text('Rename', style: TextStyle(fontSize: 15, color: AppColors.dark)),
              //pop the menu first so the rename sheet doesnt stack on top of it awkwardly
              onTap: () { Navigator.pop(context); _showRenameSheet(context, listId, listName, isFolder: false); },
            ),
            ListTile(
              //filled pin if already pinned, outlined if not. makes the toggle state obvious
              leading: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined, color: AppColors.primary),
              title: Text(isPinned ? 'Unpin from Top' : 'Pin to Top', style: const TextStyle(fontSize: 15, color: AppColors.dark)),
              onTap: () async { Navigator.pop(context); await _togglePinList(listId, isPinned); },
            ),
            ListTile(
              //red for the destructive action so its visually obvious
              leading: Icon(Icons.delete_outline, color: AppColors.danger),
              title: Text('Delete List', style: TextStyle(fontSize: 15, color: AppColors.danger)),
              onTap: () { Navigator.pop(context); _deleteList(listId, listName); },
            ),
          ],
        ),
      ),
    );
  }

  //same as list menu but for folders. almost identical code, could be refactored into one function
  void _showFolderMenu(BuildContext context, String folderId, String folderName, bool isPinned) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            Text(folderName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.dark)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
              title: const Text('Rename', style: TextStyle(fontSize: 15, color: AppColors.dark)),
              onTap: () { Navigator.pop(context); _showRenameSheet(context, folderId, folderName, isFolder: true); },
            ),
            ListTile(
              leading: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined, color: AppColors.primary),
              title: Text(isPinned ? 'Unpin from Top' : 'Pin to Top', style: const TextStyle(fontSize: 15, color: AppColors.dark)),
              onTap: () async { Navigator.pop(context); await _togglePinFolder(folderId, isPinned); },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.danger),
              title: Text('Delete Folder', style: TextStyle(fontSize: 15, color: AppColors.danger)),
              onTap: () { Navigator.pop(context); _deleteFolder(folderId, folderName); },
            ),
          ],
        ),
      ),
    );
  }

  //shared rename sheet for both lists and folders. isFolder flag tells us which collection to update
  void _showRenameSheet(BuildContext context, String id, String currentName, {required bool isFolder}) {
    //pre fill with the current name so user just has to edit instead of re type everything
    final nameController = TextEditingController(text: currentName);
    showModalBottomSheet(
      context: context,
      //scrollControlled lets the sheet resize when keyboard opens
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        //viewInsets.bottom is keyboard height. keeps fields reachable
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
                //ternary picks the right collection based on the isFolder flag
                await _firestore.collection(isFolder ? 'folders' : 'lists').doc(id).update({'name': nameController.text.trim()});
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  //deletes a list plus all its items and categories
  //uses a batch so its one atomic operation. either everything deletes or nothing does
  Future<void> _deleteList(String listId, String listName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete List?', style: TextStyle(color: AppColors.dark, fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('"$listName" and all its items will be permanently deleted.', style: const TextStyle(color: AppColors.subtext, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: AppColors.subtext))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      //batch collects all writes then commits them at once, no orphaned items left if any step fails
      final batch = _firestore.batch();
      //delete every item belonging to this list
      final items = await _firestore.collection('items').where('listId', isEqualTo: listId).get();
      for (final item in items.docs) batch.delete(item.reference);
      //delete every category belonging to this list
      final categories = await _firestore.collection('categories').where('listId', isEqualTo: listId).get();
      for (final cat in categories.docs) batch.delete(cat.reference);
      //finally delete the list itself
      batch.delete(_firestore.collection('lists').doc(listId));
      await batch.commit();
    }
  }

  //deletes a folder plus every list inside it plus every item/category in those lists
  //nested cleanup, same batch approach so the whole thing is atomic
  Future<void> _deleteFolder(String folderId, String folderName) async {
    //pre fetch the lists so we can tell user how many things will be deleted in the confirm dialog
    final listsInFolder = await _firestore.collection('lists').where('folderId', isEqualTo: folderId).get();
    final listCount = listsInFolder.docs.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder?', style: TextStyle(color: AppColors.dark, fontSize: 16, fontWeight: FontWeight.w700)),
        //pluralize based on count so it reads naturally (1 list vs 3 lists)
        content: Text('"$folderName" and all $listCount ${listCount == 1 ? 'list' : 'lists'} inside it — including all items — will be permanently deleted.',
            style: const TextStyle(color: AppColors.subtext, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: AppColors.subtext))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger), child: const Text('Delete Everything')),
        ],
      ),
    );
    if (confirmed == true) {
      final batch = _firestore.batch();
      //for each list, nuke its items and categories then the list itself
      for (final list in listsInFolder.docs) {
        final items = await _firestore.collection('items').where('listId', isEqualTo: list.id).get();
        for (final item in items.docs) batch.delete(item.reference);
        final categories = await _firestore.collection('categories').where('listId', isEqualTo: list.id).get();
        for (final cat in categories.docs) batch.delete(cat.reference);
        batch.delete(list.reference);
      }
      //finally delete the folder itself
      batch.delete(_firestore.collection('folders').doc(folderId));
      await batch.commit();
    }
  }

  //bottom sheet for creating a new folder
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
                await _firestore.collection('folders').add({'name': nameController.text.trim(), 'ownerId': _userId, 'isPinned': false});
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Create Folder'),
            ),
          ],
        ),
      ),
    );
  }

  //bottom sheet for creating a new list
  //creates the list then jumps straight into it so user can start adding items
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
                //docRef holds the newly created docs reference so we can jump to it after
                //memberIds starts with just the creator. more get added when sharing
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
                if (mounted) { Navigator.pop(context); context.push('/dashboard/list/${docRef.id}'); }
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
        title: const Text('My Lists', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.dark)),
        actions: [
          //avatar in the top right that jumps to settings when tapped
          //streambuilder so it updates immediately if user changes their avatar color
          StreamBuilder(
            stream: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).snapshots(),
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
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: AppColors.primary, width: 2)),
                  child: Center(child: Text(initial, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          //search bar at the top filters the list by name as user types
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              //lowercase the query once so we dont do it on every filter check below
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
          //nested streambuilders. outer streams folders, inner streams lists
          //both need to be live so adding a list or folder updates the UI instantly
          Expanded(
            child: StreamBuilder(
              stream: _firestore.collection('folders').where('ownerId', isEqualTo: _userId).snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> folderSnapshot) {
                return StreamBuilder(
                  //arrayContains is the firestore operator for "userId is in this array field"
                  //this is how we get lists the user created AND lists theyve been added to via sharing
                  stream: _firestore.collection('lists').where('memberIds', arrayContains: _userId).snapshots(),
                  builder: (context, AsyncSnapshot<QuerySnapshot> listSnapshot) {
                    //show spinner until BOTH streams have loaded
                    if (folderSnapshot.connectionState == ConnectionState.waiting || listSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                    }

                    final folders = folderSnapshot.data?.docs ?? [];
                    final allLists = listSnapshot.data?.docs ?? [];
                    //standalone lists are the ones NOT inside a folder, those show on dashboard
                    //lists inside folders only show when user opens that folder
                    final standaloneLists = allLists.where((doc) => doc['folderId'] == null).toList();

                    //apply search filter. contains is a substring match not strict equality
                    final filteredFolders = folders.where((doc) => doc['name'].toString().toLowerCase().contains(_searchQuery)).toList();
                    final filteredLists = standaloneLists.where((doc) => doc['name'].toString().toLowerCase().contains(_searchQuery)).toList();

                    //split into pinned and unpinned buckets so we can show pinned at the top
                    final pinnedFolders = filteredFolders.where((d) => _isPinned(d)).toList();
                    final unpinnedFolders = filteredFolders.where((d) => !_isPinned(d)).toList();
                    final pinnedLists = filteredLists.where((d) => _isPinned(d)).toList();
                    final unpinnedLists = filteredLists.where((d) => !_isPinned(d)).toList();

                    //build a unified list where pinned items come first then unpinned
                    //each entry tagged with type so we know whether to render a folder card or list card
                    final orderedItems = [
                      ...pinnedFolders.map((d) => {'doc': d, 'type': 'folder', 'pinned': true}),
                      ...pinnedLists.map((d) => {'doc': d, 'type': 'list', 'pinned': true}),
                      ...unpinnedFolders.map((d) => {'doc': d, 'type': 'folder', 'pinned': false}),
                      ...unpinnedLists.map((d) => {'doc': d, 'type': 'list', 'pinned': false}),
                    ];

                    //empty state when user has no folders or lists yet
                    if (orderedItems.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.list_alt_rounded, size: 64, color: AppColors.border),
                            const SizedBox(height: 16),
                            const Text('No lists yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.subtext)),
                            const SizedBox(height: 8),
                            const Text('Tap + to create your first list', style: TextStyle(fontSize: 14, color: AppColors.subtext)),
                          ],
                        ),
                      );
                    }

                    //scrollable list that shows folders and lists in the right order
                    //ValueKey helps flutter track each item so it rebuilds efficiently when things change
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
                              key: ValueKey('folder_${doc.id}'),
                              folderId: doc.id,
                              name: doc['name'],
                              userId: _userId,
                              isPinned: isPinned,
                            ),
                          );
                        } else {
                          //shared if more than just the owner is in memberIds
                          final isShared = (doc['memberIds'] as List).length > 1;
                          return GestureDetector(
                            onLongPress: () => _showListMenu(context, doc.id, doc['name'], isPinned),
                            child: _ListCard(
                              key: ValueKey('list_${doc.id}'),
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
      //SpeedDial is the expandable floating action button from the flutter_speed_dial package
      //tap the + and it fans out into New Folder and New List options
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

//private folder card widget. shows folder name, pin icon, and how many lists are inside
class _FolderCard extends StatelessWidget {
  final String folderId;
  final String name;
  final String userId;
  final bool isPinned;

  const _FolderCard({super.key, required this.folderId, required this.name, required this.userId, required this.isPinned});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      //tap pushes to the folder screen showing the lists inside
      onTap: () => context.push('/dashboard/folder/$folderId'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primaryLighter,
          borderRadius: BorderRadius.circular(12),
          //pinned folders get a purple border to stand out
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
                      Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.dark)),
                      //little pin icon next to name when pinned
                      if (isPinned) ...[const SizedBox(width: 6), const Icon(Icons.push_pin, size: 12, color: AppColors.primary)],
                    ],
                  ),
                  //live count of lists inside this folder
                  StreamBuilder(
                    stream: FirebaseFirestore.instance.collection('lists').where('folderId', isEqualTo: folderId).snapshots(),
                    builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                      final count = snapshot.data?.docs.length ?? 0;
                      return Text('$count ${count == 1 ? 'list' : 'lists'} inside', style: const TextStyle(fontSize: 12, color: AppColors.subtext));
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

//private list card widget. shows name, pin icon, item counts, and shared status
class _ListCard extends StatelessWidget {
  final String listId;
  final String name;
  final String userId;
  final bool isShared;
  final bool isPinned;

  const _ListCard({super.key, required this.listId, required this.name, required this.userId, required this.isShared, required this.isPinned});

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
          //pinned takes priority over shared for border color. shared uses pink, pinned uses purple
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
                      Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.dark)),
                      if (isPinned) ...[const SizedBox(width: 6), const Icon(Icons.push_pin, size: 12, color: AppColors.primary)],
                    ],
                  ),
                  //live count of items and how many are done
                  //shared lists also show the Shared tag in pink
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