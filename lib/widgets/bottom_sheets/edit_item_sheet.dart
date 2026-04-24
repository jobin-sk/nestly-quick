import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/colors.dart';

//bottom sheet that opens when user long presses an item and picks edit
//pre fills the fields with the items existing values so user can change whatever
class EditItemSheet extends StatefulWidget {
  //DocumentSnapshot is firestores wrapper for a single document (this specific item)
  final DocumentSnapshot item;
  //list of category docs for the parent list so user can change which category the item belongs to
  final List<DocumentSnapshot> categories;

  const EditItemSheet({
    super.key,
    required this.item,
    required this.categories,
  });

  @override
  State<EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends State<EditItemSheet> {
  //firestore instance lets us read and write documents
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  //late means we promise to initialize these before theyre used (in initState below)
  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  late TextEditingController _notesController;

  //currently selected category, null means uncategorized (the None chip)
  String? _selectedCategoryId;

  //initState runs once when the sheet opens, used here to pre fill everything
  @override
  void initState() {
    super.initState();
    //?? '' means if the field is null use empty string so the controller doesnt crash
    _nameController = TextEditingController(text: widget.item['name'] ?? '');
    _quantityController = TextEditingController(text: widget.item['quantity'] ?? '');
    _notesController = TextEditingController(text: widget.item['notes'] ?? '');
    _selectedCategoryId = widget.item['categoryId'];
  }

  //clean up controllers when sheet closes so we dont leak memory
  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  //saves the updated item back to firestore
  Future<void> _saveChanges() async {
    //bail out if the user cleared the name field, items cant be nameless
    if (_nameController.text.trim().isEmpty) return;

    //update just overwrites these fields on the existing doc, everything else stays the same
    await _firestore.collection('items').doc(widget.item.id).update({
      'name': _nameController.text.trim(),
      //if quantity is empty store null so we dont show "x" on the item row for nothing
      'quantity': _quantityController.text.trim().isEmpty
          ? null
          : _quantityController.text.trim(),
      'notes': _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      'categoryId': _selectedCategoryId,
      //server timestamp so the time is consistent across devices not whatever the phones clock says
      'updatedAt': FieldValue.serverTimestamp(),
    });

    //mounted check since we awaited firestore, user might have closed the sheet already
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      //viewInsets.bottom is the keyboard height, this pushes the sheet up so fields arent hidden
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        //min so the column only takes as much vertical space as it needs
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          //little grey bar at the top of the sheet, visual cue that you can swipe it down
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
            'Edit Item',
            style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 16),

          //item name field
          const Text('Item Name',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
          const SizedBox(height: 6),
          TextField(
            controller: _nameController,
            //autofocus pops the keyboard open as soon as the sheet opens
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'e.g. Milk',
              hintStyle: TextStyle(color: AppColors.subtext),
            ),
          ),
          const SizedBox(height: 12),

          //quantity field, optional because not every item has a count
          const Text('Quantity (optional)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
          const SizedBox(height: 6),
          TextField(
            controller: _quantityController,
            decoration: const InputDecoration(
              hintText: 'e.g. x2',
              hintStyle: TextStyle(color: AppColors.subtext),
            ),
          ),
          const SizedBox(height: 12),

          //notes field for extra info like "check if we already have this"
          const Text('Notes (optional)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
          const SizedBox(height: 6),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              hintText: 'e.g. Check if we have this already',
              hintStyle: TextStyle(color: AppColors.subtext),
            ),
          ),
          const SizedBox(height: 16),

          //category picker, done as colored chips instead of a dropdown so the colors are visible
          const Text('Category',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
          const SizedBox(height: 10),

          //if no categories exist for this list show a hint instead of an empty chip row
          if (widget.categories.isEmpty)
            Text(
              'No categories yet — add one from the list view',
              style: TextStyle(fontSize: 12, color: AppColors.subtext),
            )
          else
          //Wrap lays chips out in rows and wraps to a new row when it runs out of space
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                //None chip lets user pick no category (uncategorized)
                GestureDetector(
                  onTap: () => setState(() => _selectedCategoryId = null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      //highlight the chip when its the selected one
                      color: _selectedCategoryId == null
                          ? AppColors.primaryLight
                          : AppColors.backgroundAlt,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _selectedCategoryId == null
                            ? AppColors.primary
                            : AppColors.border,
                        width: _selectedCategoryId == null ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      'None',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _selectedCategoryId == null
                            ? AppColors.primary
                            : AppColors.subtext,
                      ),
                    ),
                  ),
                ),

                //spread operator (...) turns the list returned by map into individual children
                //one chip per category, each uses its own color as the background
                ...widget.categories.map((cat) {
                  final isSelected = _selectedCategoryId == cat.id;
                  //color is stored as hex string like "#FFAABB" in firestore
                  //this strips the # and adds FF (full opacity) to turn it into a Color object
                  final catColor = Color(
                    int.parse('0xFF${cat['color'].toString().replaceAll('#', '')}'),
                  );

                  return GestureDetector(
                    //tap the selected chip again to deselect it back to None
                    onTap: () => setState(() => _selectedCategoryId = isSelected ? null : cat.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        //full color when selected, faded version when not (easy visual diff)
                        color: isSelected ? catColor : catColor.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          //checkmark shows up only on the selected chip so it really stands out
                          if (isSelected) ...[
                            const Icon(Icons.check, size: 14, color: AppColors.dark),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            cat['name'],
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.dark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          const SizedBox(height: 20),

          //save button, style comes from app wide theme in main.dart
          ElevatedButton(
            onPressed: _saveChanges,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              'Save Changes',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}