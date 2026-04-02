import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../theme/colors.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Tracks visibility toggles for each password field
  bool _currentPasswordVisible = false;
  bool _newPasswordVisible = false;
  bool _confirmPasswordVisible = false;

  // Selected avatar color — loaded from Firestore on init
  String _selectedColor = '#7C3AED';

  // Whether we are currently saving
  bool _isSaving = false;

  // Available avatar colors to pick from
  final List<Map<String, String>> _avatarColors = [
    {'color': '#7C3AED', 'label': 'Purple'},
    {'color': '#E879F9', 'label': 'Pink'},
    {'color': '#3B82F6', 'label': 'Blue'},
    {'color': '#10B981', 'label': 'Green'},
    {'color': '#F59E0B', 'label': 'Amber'},
    {'color': '#EF4444', 'label': 'Red'},
    {'color': '#06B6D4', 'label': 'Cyan'},
    {'color': '#8B5CF6', 'label': 'Violet'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Loads current user data from Firestore to pre-fill the fields
  Future<void> _loadUserData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final doc = await _firestore.collection('users').doc(uid).get();
    final data = doc.data();
    if (data != null) {
      setState(() {
        _usernameController.text = data['username'] ?? '';
        _emailController.text = data['email'] ?? '';
        _selectedColor = data['avatarColor'] ?? '#7C3AED';
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Saves profile changes to Firestore and Firebase Auth
  Future<void> _saveChanges() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // Basic username validation
    if (_usernameController.text.trim().isEmpty) {
      _showError('Username cannot be empty');
      return;
    }
    if (_usernameController.text.trim().length < 4) {
      _showError('Username must be at least 4 characters');
      return;
    }
    if (_usernameController.text.contains(' ')) {
      _showError('Username cannot contain spaces');
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Check username uniqueness if it changed
      final currentDoc = await _firestore.collection('users').doc(uid).get();
      final currentUsername = currentDoc.data()?['username'] ?? '';
      if (_usernameController.text.trim() != currentUsername) {
        final existing = await _firestore
            .collection('users')
            .where('username', isEqualTo: _usernameController.text.trim())
            .get();
        if (existing.docs.isNotEmpty) {
          _showError('Username already taken');
          setState(() => _isSaving = false);
          return;
        }
      }

      // Update Firestore user document
      await _firestore.collection('users').doc(uid).update({
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'avatarColor': _selectedColor,
      });

      // Update email in Firebase Auth if it changed
      if (_emailController.text.trim() != _auth.currentUser?.email) {
        await _auth.currentUser?.updateEmail(_emailController.text.trim());
      }

      // Handle password change if fields are filled
      if (_newPasswordController.text.isNotEmpty) {
        if (_currentPasswordController.text.isEmpty) {
          _showError('Please enter your current password');
          setState(() => _isSaving = false);
          return;
        }
        if (_newPasswordController.text.length < 6) {
          _showError('New password must be at least 6 characters');
          setState(() => _isSaving = false);
          return;
        }
        if (_newPasswordController.text != _confirmPasswordController.text) {
          _showError('New passwords do not match');
          setState(() => _isSaving = false);
          return;
        }

        // Re-authenticate before changing password — required by Firebase
        final credential = EmailAuthProvider.credential(
          email: _auth.currentUser!.email!,
          password: _currentPasswordController.text,
        );
        await _auth.currentUser?.reauthenticateWithCredential(credential);
        await _auth.currentUser?.updatePassword(_newPasswordController.text);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        context.pop();
      }
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
          _showError('Current password is incorrect');
          break;
        case 'requires-recent-login':
          _showError('Please log out and log back in before changing your password');
          break;
        default:
          _showError('Something went wrong — please try again');
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get the current selected color as a Color object
    final avatarColor = Color(
      int.parse('0xFF${_selectedColor.replaceAll('#', '')}'),
    );
    final initial = _usernameController.text.isNotEmpty
        ? _usernameController.text.substring(0, 1).toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.dark),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.dark),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // Avatar preview — updates live as user picks a color
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: avatarColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 3),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Color picker label
            const Center(
              child: Text(
                'Choose Color',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.subtext),
              ),
            ),
            const SizedBox(height: 10),

            // Color swatches row
            Center(
              child: Wrap(
                spacing: 10,
                children: _avatarColors.map((item) {
                  final color = Color(int.parse('0xFF${item['color']!.replaceAll('#', '')}'));
                  final isSelected = _selectedColor == item['color'];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = item['color']!),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        // White ring + primary border when selected
                        border: isSelected
                            ? Border.all(color: AppColors.primary, width: 3)
                            : Border.all(color: Colors.transparent, width: 3),
                        boxShadow: isSelected
                            ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6, spreadRadius: 1)]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 18, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 28),

            const Divider(color: AppColors.border),
            const SizedBox(height: 20),

            // Username field
            const Text('Username', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _usernameController,
              autocorrect: false,
              onChanged: (_) => setState(() {}), // rebuild to update avatar initial
              decoration: const InputDecoration(
                hintText: 'e.g. toddles',
                hintStyle: TextStyle(color: AppColors.subtext),
              ),
            ),
            const SizedBox(height: 16),

            // Email field
            const Text('Email', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                hintText: 'you@email.com',
                hintStyle: TextStyle(color: AppColors.subtext),
              ),
            ),
            const SizedBox(height: 24),

            const Divider(color: AppColors.border),
            const SizedBox(height: 20),

            // Password change section
            const Text(
              'Change Password',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.dark),
            ),
            const SizedBox(height: 4),
            const Text(
              'Leave blank to keep your current password',
              style: TextStyle(fontSize: 12, color: AppColors.subtext),
            ),
            const SizedBox(height: 16),

            // Current password
            const Text('Current Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _currentPasswordController,
              obscureText: !_currentPasswordVisible,
              decoration: InputDecoration(
                hintText: 'Enter current password',
                hintStyle: const TextStyle(color: AppColors.subtext),
                suffixIcon: IconButton(
                  icon: Icon(
                    _currentPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.subtext,
                  ),
                  onPressed: () => setState(() => _currentPasswordVisible = !_currentPasswordVisible),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // New password
            const Text('New Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _newPasswordController,
              obscureText: !_newPasswordVisible,
              decoration: InputDecoration(
                hintText: 'Minimum 6 characters',
                hintStyle: const TextStyle(color: AppColors.subtext),
                suffixIcon: IconButton(
                  icon: Icon(
                    _newPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.subtext,
                  ),
                  onPressed: () => setState(() => _newPasswordVisible = !_newPasswordVisible),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Confirm new password
            const Text('Confirm New Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: !_confirmPasswordVisible,
              decoration: InputDecoration(
                hintText: 'Re-enter new password',
                hintStyle: const TextStyle(color: AppColors.subtext),
                suffixIcon: IconButton(
                  icon: Icon(
                    _confirmPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.subtext,
                  ),
                  onPressed: () => setState(() => _confirmPasswordVisible = !_confirmPasswordVisible),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Save button
            ElevatedButton(
              onPressed: _isSaving ? null : _saveChanges,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isSaving
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
                  : const Text(
                'Save Changes',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}