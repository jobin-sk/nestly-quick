import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/colors.dart';

class EditItemSheet extends StatefulWidget {
  final DocumentSnapshot item;
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  late TextEditingController _notesController;

  // Currently selected category ID — null means uncategorized
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    // Pre-fill all fields with the item's current values
    _nameController = TextEditingController(text: widget.item['name'] ?? '');
    _quantityController = TextEditingController(text: widget.item['quantity'] ?? '');
    _notesController = TextEditingController(text: widget.item['notes'] ?? '');
    _selectedCategoryId = widget.item['categoryId'];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // Saves the updated item to Firestore
  Future<void> _saveChanges() async {
    if (_nameController.text.trim().isEmpty) return;

    await _firestore.collection('items').doc(widget.item.id).update({
      'name': _nameController.text.trim(),
      'quantity': _quantityController.text.trim().isEmpty
          ? null
          : _quantityController.text.trim(),
      'notes': _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      'categoryId': _selectedCategoryId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
            'Edit Item',
            style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 16),

          // Item name field
          const Text('Item Name',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
          const SizedBox(height: 6),
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'e.g. Milk',
              hintStyle: TextStyle(color: AppColors.subtext),
            ),
          ),
          const SizedBox(height: 12),

          // Quantity field
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

          // Notes field
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

          // Category section — shown as colored chips instead of dropdown
          const Text('Category',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
          const SizedBox(height: 10),

          if (widget.categories.isEmpty)
          // No categories exist yet for this list
            Text(
              'No categories yet — add one from the list view',
              style: TextStyle(fontSize: 12, color: AppColors.subtext),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // None chip — deselects any category
                GestureDetector(
                  onTap: () => setState(() => _selectedCategoryId = null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
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

                // One chip per category — uses the category's color as background
                ...widget.categories.map((cat) {
                  final isSelected = _selectedCategoryId == cat.id;
                  final catColor = Color(
                    int.parse('0xFF${cat['color'].toString().replaceAll('#', '')}'),
                  );

                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategoryId = isSelected ? null : cat.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        // Full color when selected, lighter tint when not
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
                          // Checkmark when selected
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

          // Save button
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