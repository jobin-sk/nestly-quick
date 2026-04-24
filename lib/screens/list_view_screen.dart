import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../theme/colors.dart';
import '../widgets/bottom_sheets/edit_item_sheet.dart';

//the actual list view screen. shows items, lets user add/edit/complete/delete them
//handles swipe gestures, category filter chips, and the completed section at the bottom
//this is the core of the app basically. teacher will spend the most time in here
class ListViewScreen extends StatefulWidget {
  final String listId;
  const ListViewScreen({super.key, required this.listId});

  @override
  State<ListViewScreen> createState() => _ListViewScreenState();
}

class _ListViewScreenState extends State<ListViewScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  //flag to stop the "all done" dialog from popping up more than once per visit
  bool _completedDialogShowing = false;

  //currently selected category filter. null means show all categories
  String? _selectedCategoryId;

  String get _userId => _auth.currentUser!.uid;

  //marks an item as complete
  //also updates the list doc so dashboard knows this list changed
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

  //unchecks a completed item back to active
  Future<void> _uncompleteItem(String itemId) async {
    await _firestore.collection('items').doc(itemId).update({
      'isComplete': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  //deletes an item after confirmation popup
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
      //bump the list updatedAt so anyone sharing sees something changed
      await _firestore.collection('lists').doc(widget.listId).update({
        'lastEditedBy': _userId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  //nukes every completed item at once. batch keeps it atomic
  Future<void> _clearCompleted(List<DocumentSnapshot> completedItems) async {
    final batch = _firestore.batch();
    for (final item in completedItems) {
      batch.delete(item.reference);
    }
    await batch.commit();
  }

  //shows a celebration popup when user checks off the last item
  //three choices. clear the list, delete it entirely, or keep it for reference
  void _showAllCompletedDialog(List<DocumentSnapshot> completedItems) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Everything\'s Done!',
            style: TextStyle(color: AppColors.dark, fontSize: 20, fontWeight: FontWeight.w700),
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
              //pop back to dashboard FIRST then delete, otherwise the screen tries to render a deleted list and crashes
              context.go('/dashboard');
              await _clearCompleted(completedItems);
              await _firestore.collection('lists').doc(widget.listId).delete();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete Entire List'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              //flag so this popup doesnt show up again unless user adds a new item
              await _firestore.collection('lists').doc(widget.listId).update({
                'allCompletedDismissed': true,
              });
            },
            child: const Text('Keep for Reference',
                style: TextStyle(color: AppColors.subtext)),
          ),
        ],
      ),
    );
  }

  //opens the edit item sheet. defined in its own file for reuse
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

  //add item sheet. bigger than edit because it also lets user add a category inline
  //StatefulBuilder lets us setState inside the sheet without making the whole screen stateful
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
        //setSheetState only rebuilds this sheet not the whole screen behind it
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
              //streambuilder inside the sheet so if user adds a new category it shows up in the dropdown live
              StreamBuilder(
                stream: _firestore
                    .collection('categories')
                    .where('listId', isEqualTo: widget.listId)
                    .snapshots(),
                builder: (context, AsyncSnapshot<QuerySnapshot> catSnapshot) {
                  final liveCategories = catSnapshot.data?.docs ?? [];
                  return DropdownButtonFormField<String>(
                    initialValue: selectedCategoryId,
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
                      //special __new__ option at the top opens the add category sheet
                      const DropdownMenuItem<String>(
                        value: '__new__',
                        child: Text('+ Add new category',
                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ),
                      ...liveCategories.map((cat) => DropdownMenuItem<String>(
                        value: cat.id,
                        child: Row(
                          children: [
                            //small color square next to category name for visual id
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
                        //dont close the add item sheet. open add category on top of it
                        _showAddCategorySheet(context);
                      } else {
                        setSheetState(() => selectedCategoryId = value);
                      }
                    },
                  );
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
                  //add the item doc with all fields, leave empty optionals as null
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
                  //also bump the lists updatedAt and flip allCompletedDismissed off
                  //so the celebration popup can show again next time everything gets checked off
                  await _firestore.collection('lists').doc(widget.listId).update({
                    'lastEditedBy': _userId,
                    'updatedAt': FieldValue.serverTimestamp(),
                    'allCompletedDismissed': false,
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

  //add category sheet. shows available colors, disables taken ones
  void _showAddCategorySheet(BuildContext context) {
    final nameController = TextEditingController();

    //12 pastel colors, enough for any reasonable list
    final allColors = [
      '#DBEAFE', '#EDE9FE', '#FCE7F3', '#FFEDD5',
      '#FEE2E2', '#DCFCE7', '#FEF9C3', '#CFFAFE',
      '#FEE2CC', '#F3E8FF', '#D1FAE5', '#FFE4E6',
    ];

    String? selectedColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      //streambuilder streams existing categories so we know which colors are already taken
      builder: (context) => StreamBuilder(
        stream: _firestore
            .collection('categories')
            .where('listId', isEqualTo: widget.listId)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> catSnapshot) {
          //pull the color from each existing category doc
          final usedColors = catSnapshot.data?.docs
              .map((d) => d['color'].toString())
              .toList() ?? [];
          //filter out already used colors so user cant pick a duplicate
          final availableColors = allColors.where((c) => !usedColors.contains(c)).toList();

          //auto select the first available color so user doesnt have to tap one manually
          //??= means "assign only if current value is null"
          selectedColor ??= availableColors.isNotEmpty ? availableColors.first : null;

          return StatefulBuilder(
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

                  //if all 12 colors are in use show a hint instead of an empty picker
                  if (availableColors.isEmpty)
                    const Text(
                      'All colors are in use — delete a category to free up a color',
                      style: TextStyle(fontSize: 12, color: AppColors.subtext),
                    )
                  else
                  //wrap lays out color swatches, 4 per row filling the sheet width
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableColors.map((color) {
                        final isSelected = selectedColor == color;
                        final c = Color(int.parse('0xFF${color.replaceAll('#', '')}'));
                        return GestureDetector(
                          onTap: () => setSheetState(() => selectedColor = color),
                          child: Container(
                            //dynamic width based on screen size so 4 swatches always fit per row
                            width: (MediaQuery.of(context).size.width - 72) / 4,
                            height: 40,
                            decoration: BoxDecoration(
                              color: c,
                              borderRadius: BorderRadius.circular(8),
                              //purple border on the selected swatch
                              border: Border.all(
                                color: isSelected ? AppColors.primary : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, size: 18, color: AppColors.dark)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    //null onPressed disables the button when no colors are available
                    onPressed: availableColors.isEmpty ? null : () async {
                      if (nameController.text.trim().isEmpty) return;
                      if (selectedColor == null) return;
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
          );
        },
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
          //pop goes back to wherever user came from (dashboard or folder screen)
          onPressed: () => context.pop(),
        ),
        //list name in the app bar, streams live so renames update instantly
        title: StreamBuilder(
          stream: _firestore.collection('lists').doc(widget.listId).snapshots(),
          builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
            //if the list was deleted by the owner the doc wont exist, just show blank title
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Text('');
            }
            final name = snapshot.data?['name'] ?? 'List';
            return Text(name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.dark));
          },
        ),
        actions: [
          //pencil icon opens the add category sheet
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.dark),
            onPressed: () => _showAddCategorySheet(context),
          ),
          //link icon opens the share screen
          IconButton(
            icon: const Icon(Icons.link, color: AppColors.dark),
            onPressed: () => context.push('/dashboard/list/${widget.listId}/share'),
          ),
        ],
      ),
      //nested streambuilders. outer for categories so filter chips update live, inner for items
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
              //split items into active and completed for the two sections of the list
              final activeItems = allItems.where((d) => d['isComplete'] == false).toList();
              final completedItems = allItems.where((d) => d['isComplete'] == true).toList();

              //apply category filter to active items only. completed items always show regardless
              final filteredActive = _selectedCategoryId == null
                  ? activeItems
                  : activeItems.where((d) => d['categoryId'] == _selectedCategoryId).toList();

              //addPostFrameCallback runs AFTER the current frame finishes drawing
              //without this showing a dialog during build would crash
              WidgetsBinding.instance.addPostFrameCallback((_) {
                //show the celebration dialog if every item is completed and user hasnt dismissed it yet
                if (allItems.isNotEmpty &&
                    activeItems.isEmpty &&
                    completedItems.isNotEmpty &&
                    !_completedDialogShowing) {
                  _firestore.collection('lists').doc(widget.listId).get().then((doc) {
                    final data = doc.data();
                    final dismissed = data?['allCompletedDismissed'] ?? false;
                    if (!dismissed && mounted) {
                      setState(() => _completedDialogShowing = true);
                      _showAllCompletedDialog(completedItems);
                    }
                  });
                }
                //reset the flag so dialog can show again if all items get completed a second time
                if (activeItems.isNotEmpty) {
                  _completedDialogShowing = false;
                }
              });

              return Column(
                children: [
                  //category filter chips at the top, horizontal scroll
                  if (categories.isNotEmpty)
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        children: [
                          //"all" chip clears the filter
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
                          //one chip per category with its own color
                          ...categories.map((cat) {
                            final isSelected = _selectedCategoryId == cat.id;
                            final color = Color(int.parse('0xFF${cat['color'].toString().replaceAll('#', '')}'));
                            return GestureDetector(
                              //tap selected chip again to deselect (back to all)
                              onTap: () => setState(() => _selectedCategoryId = isSelected ? null : cat.id),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                decoration: BoxDecoration(
                                  //full color when selected, faded when not
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

                  //main items list
                  Expanded(
                    child: allItems.isEmpty
                    //empty state when list has no items at all
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
                        //active items up top. each one swipeable and tappable to edit
                        ...filteredActive.map((item) => _ItemRow(
                          key: ValueKey(item.id),
                          item: item,
                          categories: categories,
                          onComplete: () => _completeItem(item.id),
                          onDelete: () => _deleteItem(item.id, item['name']),
                          onTap: () => _showEditItemSheet(context, item, categories),
                        )),

                        //divider separating active from completed, only shows if anything is completed
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
                          //completed items section below the divider
                          ...completedItems.map((item) => _CompletedItemRow(
                            key: ValueKey(item.id),
                            item: item,
                            onUncomplete: () => _uncompleteItem(item.id),
                          )),
                          //clear completed shortcut button
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
      //plus button at bottom right. fetches categories then opens add item sheet
      //fresh fetch instead of using the live stream so we get the categories even if stream hasnt fired yet
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

//active item row. swipeable both directions, tap to edit
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
    //find this items category if it has one. firstOrNull returns null instead of throwing if no match
    final category = categories.where((c) => c.id == item['categoryId']).firstOrNull;
    //default background is plain, gets tinted by category color if set
    Color tintColor = AppColors.background;
    if (category != null) {
      tintColor = Color(int.parse('0xFF${category['color'].toString().replaceAll('#', '')}'));
    }
    final addedBy = item['addedBy'] ?? '';

    //Dismissible is the built in swipe widget. handles the animation and gesture detection
    return Dismissible(
      key: ValueKey(item.id),
      //background shows when swiping right. green check icon on the left
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.check_circle_outline, color: Colors.green),
      ),
      //secondaryBackground shows when swiping left. red delete icon on the right
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: AppColors.dangerLight, borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete_outline, color: AppColors.danger),
      ),
      //returning false stops the automatic dismiss animation. we handle it ourselves via firestore updates instead
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onComplete();
          return false;
        } else {
          onDelete();
          return false;
        }
      },
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
              //empty circle on the left, visual cue for "not done yet"
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
                    //item name plus quantity if there is one
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
              //avatar of whoever added this item. useful on shared lists
              _InitialsWidget(userId: addedBy),
            ],
          ),
        ),
      ),
    );
  }
}

//completed item row. faded out, has line through the text, only swipes one way to undo
class _CompletedItemRow extends StatelessWidget {
  final DocumentSnapshot item;
  final VoidCallback onUncomplete;

  const _CompletedItemRow({super.key, required this.item, required this.onUncomplete});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('completed_${item.id}'),
      //left swipe reveals an undo icon so user can put item back to active
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.undo, color: AppColors.primary),
      ),
      //right swipe does nothing visual. kept blank so the widget still renders
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) onUncomplete();
        return false;
      },
      //Opacity 0.5 fades the whole row so it looks "done"
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
              //filled purple circle with white check, visual cue for "done"
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
                    //strikethrough reinforces completed state
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

//small avatar widget showing the initial of whoever added an item
//lives as a separate widget so each row can fetch its own user data without blocking the parent
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
        //first letter of username
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