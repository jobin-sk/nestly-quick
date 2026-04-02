import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../theme/colors.dart';
import '../widgets/bottom_sheets/edit_item_sheet.dart';

class ListViewScreen extends StatefulWidget {
  final String listId;
  const ListViewScreen({super.key, required this.listId});

  @override
  State<ListViewScreen> createState() => _ListViewScreenState();
}

class _ListViewScreenState extends State<ListViewScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Currently selected category filter — null means show all
  String? _selectedCategoryId;

  String get _userId => _auth.currentUser!.uid;

  // Marks an item as complete
  Future<void> _completeItem(String itemId) async {
    await _firestore.collection('items').doc(itemId).update({
      'isComplete': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _firestore.collection('lists').doc(widget.listId).update({
      'lastEditedBy': _userId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Marks a completed item as incomplete
  Future<void> _uncompleteItem(String itemId) async {
    await _firestore.collection('items').doc(itemId).update({
      'isComplete': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Deletes an item after confirmation
  Future<void> _deleteItem(String itemId, String itemName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item?',
            style: TextStyle(color: AppColors.dark, fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('"$itemName" will be permanently removed from this list.',
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
      await _firestore.collection('items').doc(itemId).delete();
      await _firestore.collection('lists').doc(widget.listId).update({
        'lastEditedBy': _userId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Clears all completed items
  Future<void> _clearCompleted(List<DocumentSnapshot> completedItems) async {
    final batch = _firestore.batch();
    for (final item in completedItems) {
      batch.delete(item.reference);
    }
    await batch.commit();
  }

  // Shows prompt when all items are completed
  void _showAllCompletedDialog(List<DocumentSnapshot> completedItems) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Everything\'s Done!',
            style: TextStyle(color: AppColors.dark, fontSize: 16, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center),
        content: const Text('All items are completed. What would you like to do?',
            style: TextStyle(color: AppColors.subtext, fontSize: 14),
            textAlign: TextAlign.center),
        actions: [
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _clearCompleted(completedItems);
            },
            child: const Text('Clear List Contents'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _clearCompleted(completedItems);
              await _firestore.collection('lists').doc(widget.listId).delete();
              if (mounted) context.go('/dashboard');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete Entire List'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep for Reference',
                style: TextStyle(color: AppColors.subtext)),
          ),
        ],
      ),
    );
  }

  // Opens the edit item bottom sheet when an item is tapped
  void _showEditItemSheet(BuildContext context, DocumentSnapshot item, List<DocumentSnapshot> categories) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => EditItemSheet(item: item, categories: categories),
    );
  }

  // Opens the add item bottom sheet
  void _showAddItemSheet(BuildContext context, List<DocumentSnapshot> categories) {
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    final notesController = TextEditingController();
    String? selectedCategoryId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
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
              const Text('Add Item',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.dark)),
              const SizedBox(height: 16),
              const Text('Item Name',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
              const SizedBox(height: 6),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'e.g. Milk',
                  hintStyle: TextStyle(color: AppColors.subtext),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Quantity (optional)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
              const SizedBox(height: 6),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(
                  hintText: 'e.g. x2',
                  hintStyle: TextStyle(color: AppColors.subtext),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Category (optional)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: selectedCategoryId,
                decoration: InputDecoration(
                  hintText: 'Select category...',
                  hintStyle: const TextStyle(color: AppColors.subtext),
                  filled: true,
                  fillColor: AppColors.primaryLighter,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: '__new__',
                    child: Text('+ Add new category',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                  ...categories.map((cat) => DropdownMenuItem<String>(
                    value: cat.id,
                    child: Row(
                      children: [
                        Container(
                          width: 12, height: 12,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Color(int.parse('0xFF${cat['color'].toString().replaceAll('#', '')}')),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        Text(cat['name']),
                      ],
                    ),
                  )),
                ],
                onChanged: (value) {
                  if (value == '__new__') {
                    Navigator.pop(context);
                    _showAddCategorySheet(context);
                  } else {
                    setSheetState(() => selectedCategoryId = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              const Text('Notes (optional)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
              const SizedBox(height: 6),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Check if we have this already',
                  hintStyle: TextStyle(color: AppColors.subtext),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) return;
                  await _firestore.collection('items').add({
                    'listId': widget.listId,
                    'name': nameController.text.trim(),
                    'quantity': quantityController.text.trim().isEmpty
                        ? null : quantityController.text.trim(),
                    'notes': notesController.text.trim().isEmpty
                        ? null : notesController.text.trim(),
                    'categoryId': selectedCategoryId,
                    'isComplete': false,
                    'addedBy': _userId,
                    'createdAt': FieldValue.serverTimestamp(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                  await _firestore.collection('lists').doc(widget.listId).update({
                    'lastEditedBy': _userId,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('Add Item'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Bottom sheet to add a new category
  void _showAddCategorySheet(BuildContext context) {
    final nameController = TextEditingController();
    // Updated to more distinct colors
    final colors = ['#DBEAFE', '#EDE9FE', '#FCE7F3', '#FFEDD5', '#FEE2E2', '#DCFCE7'];
    String selectedColor = colors[0];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
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
              const Text('New Category',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.dark)),
              const SizedBox(height: 16),
              const Text('Category Name',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
              const SizedBox(height: 6),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'e.g. Dairy',
                  hintStyle: TextStyle(color: AppColors.subtext),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Color',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
              const SizedBox(height: 8),
              Row(
                children: colors.map((color) => GestureDetector(
                  onTap: () => setSheetState(() => selectedColor = color),
                  child: Container(
                    width: 36, height: 36,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Color(int.parse('0xFF${color.replaceAll('#', '')}')),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selectedColor == color ? AppColors.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty) return;
                  await _firestore.collection('categories').add({
                    'listId': widget.listId,
                    'name': nameController.text.trim(),
                    'color': selectedColor,
                  });
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('Add Category'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.dark),
          // Use context.pop() so it goes back to wherever you came from
          onPressed: () => context.pop(),
        ),
        title: StreamBuilder(
          stream: _firestore.collection('lists').doc(widget.listId).snapshots(),
          builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
            final name = snapshot.data?['name'] ?? 'List';
            return Text(name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.dark));
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.dark),
            onPressed: () => _showAddCategorySheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.link, color: AppColors.dark),
            onPressed: () => context.push('/dashboard/list/${widget.listId}/share'),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: _firestore
            .collection('categories')
            .where('listId', isEqualTo: widget.listId)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> catSnapshot) {
          final categories = catSnapshot.data?.docs ?? [];

          return StreamBuilder(
            stream: _firestore
                .collection('items')
                .where('listId', isEqualTo: widget.listId)
                .orderBy('createdAt')
                .snapshots(),
            builder: (context, AsyncSnapshot<QuerySnapshot> itemSnapshot) {
              if (itemSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primary));
              }

              final allItems = itemSnapshot.data?.docs ?? [];
              final activeItems = allItems.where((d) => d['isComplete'] == false).toList();
              final completedItems = allItems.where((d) => d['isComplete'] == true).toList();

              final filteredActive = _selectedCategoryId == null
                  ? activeItems
                  : activeItems.where((d) => d['categoryId'] == _selectedCategoryId).toList();

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (allItems.isNotEmpty && activeItems.isEmpty && completedItems.isNotEmpty) {
                  _showAllCompletedDialog(completedItems);
                }
              });

              return Column(
                children: [
                  // Category filter chips
                  if (categories.isNotEmpty)
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _selectedCategoryId = null),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                color: _selectedCategoryId == null ? AppColors.primary : AppColors.primaryLighter,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('All',
                                  style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w500,
                                    color: _selectedCategoryId == null ? Colors.white : AppColors.primary,
                                  )),
                            ),
                          ),
                          ...categories.map((cat) {
                            final isSelected = _selectedCategoryId == cat.id;
                            final color = Color(int.parse('0xFF${cat['color'].toString().replaceAll('#', '')}'));
                            return GestureDetector(
                              onTap: () => setState(() => _selectedCategoryId = isSelected ? null : cat.id),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSelected ? color : color.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(20),
                                  border: isSelected ? Border.all(color: AppColors.primary, width: 1.5) : null,
                                ),
                                child: Text(cat['name'],
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.dark)),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                  // Items list
                  Expanded(
                    child: allItems.isEmpty
                        ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_shopping_cart, size: 64, color: AppColors.border),
                          const SizedBox(height: 16),
                          const Text('No items yet',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.subtext)),
                          const SizedBox(height: 8),
                          const Text('Tap + to add your first item',
                              style: TextStyle(fontSize: 14, color: AppColors.subtext)),
                        ],
                      ),
                    )
                        : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      children: [
                        // Active items — tappable to edit
                        ...filteredActive.map((item) => _ItemRow(
                          key: ValueKey(item.id),
                          item: item,
                          categories: categories,
                          onComplete: () => _completeItem(item.id),
                          onDelete: () => _deleteItem(item.id, item['name']),
                          onTap: () => _showEditItemSheet(context, item, categories),
                        )),

                        // Completed section
                        if (completedItems.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                const Expanded(child: Divider(color: AppColors.border)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    'COMPLETED (${completedItems.length})',
                                    style: const TextStyle(fontSize: 11, color: AppColors.subtext, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                const Expanded(child: Divider(color: AppColors.border)),
                              ],
                            ),
                          ),
                          // Completed items
                          ...completedItems.map((item) => _CompletedItemRow(
                            key: ValueKey(item.id),
                            item: item,
                            onUncomplete: () => _uncompleteItem(item.id),
                          )),
                          // Clear completed button at the bottom of completed section
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => _clearCompleted(completedItems),
                              child: const Text('Clear completed',
                                  style: TextStyle(color: AppColors.danger, fontSize: 12)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () {
          _firestore
              .collection('categories')
              .where('listId', isEqualTo: widget.listId)
              .get()
              .then((snapshot) => _showAddItemSheet(context, snapshot.docs));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

// Active item row with swipe gestures and tap to edit
class _ItemRow extends StatelessWidget {
  final DocumentSnapshot item;
  final List<DocumentSnapshot> categories;
  final VoidCallback onComplete;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _ItemRow({
    super.key,
    required this.item,
    required this.categories,
    required this.onComplete,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final category = categories.where((c) => c.id == item['categoryId']).firstOrNull;
    Color tintColor = AppColors.background;
    if (category != null) {
      tintColor = Color(int.parse('0xFF${category['color'].toString().replaceAll('#', '')}'));
    }
    final addedBy = item['addedBy'] ?? '';

    return Dismissible(
      key: ValueKey(item.id),
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.check_circle_outline, color: Colors.green),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: AppColors.dangerLight, borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete_outline, color: AppColors.danger),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onComplete();
          return false;
        } else {
          onDelete();
          return false;
        }
      },
      // Tap item row to open edit sheet
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: tintColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              // Circle indicator with visible border
              Container(
                width: 20, height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.subtext.withOpacity(0.4), width: 1.5),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['quantity'] != null
                          ? '${item['name']} ${item['quantity']}'
                          : item['name'],
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.dark),
                    ),
                    if (item['notes'] != null)
                      Text(item['notes'],
                          style: const TextStyle(fontSize: 12, color: AppColors.subtext)),
                  ],
                ),
              ),
              _InitialsWidget(userId: addedBy),
            ],
          ),
        ),
      ),
    );
  }
}

// Completed item row
class _CompletedItemRow extends StatelessWidget {
  final DocumentSnapshot item;
  final VoidCallback onUncomplete;

  const _CompletedItemRow({super.key, required this.item, required this.onUncomplete});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('completed_${item.id}'),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.undo, color: AppColors.primary),
      ),
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) onUncomplete();
        return false;
      },
      child: Opacity(
        opacity: 0.5,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 20, height: 20,
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                child: const Icon(Icons.check, size: 13, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item['quantity'] != null
                      ? '${item['name']} ${item['quantity']}'
                      : item['name'],
                  style: const TextStyle(
                    fontSize: 14, color: AppColors.subtext,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Fetches and displays the initial of the user who added an item
class _InitialsWidget extends StatelessWidget {
  final String userId;
  const _InitialsWidget({required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final username = data?['username'] ?? '?';
        final avatarColor = data?['avatarColor'] ?? '#7C3AED';
        // Single letter initial
        final initial = username.isNotEmpty
            ? username.substring(0, 1).toUpperCase()
            : '?';
        final color = Color(int.parse('0xFF${avatarColor.replaceAll('#', '')}'));
        return Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(
            child: Text(initial,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        );
      },
    );
  }
}