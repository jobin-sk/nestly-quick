import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/colors.dart';

//settings screen shows user profile plus account/preferences sections and logout
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.dark),
        ),
      ),
      //streambuilder so if user updates their profile it reflects instantly here
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .snapshots(),
        builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
          //cast the raw doc data to a map so we can read fields off it
          final data = snapshot.data?.data() as Map<String, dynamic>?;
          final username = data?['username'] ?? '';
          final email = data?['email'] ?? '';
          //default purple if user hasnt picked an avatar color yet
          final avatarColor = data?['avatarColor'] ?? '#7C3AED';
          //first letter of username uppercased for the avatar circle
          final initial = username.isNotEmpty
              ? username.substring(0, 1).toUpperCase()
              : '?';
          //same hex to Color conversion we use everywhere for category colors
          final color = Color(
            int.parse('0xFF${avatarColor.replaceAll('#', '')}'),
          );

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            children: [

              //centered avatar circle with the users first initial on their chosen color
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    //purple ring around the avatar for extra pop
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
              const SizedBox(height: 12),
              //username below the avatar
              Center(
                child: Text(
                  username,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              //email in smaller grey text below username
              Center(
                child: Text(
                  email,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.subtext,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              const Divider(color: AppColors.border),
              const SizedBox(height: 16),

              //account section header
              const Text(
                'ACCOUNT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.subtext,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),

              //edit profile row uses the reusable _SettingsRow widget below
              _SettingsRow(
                icon: Icons.person_outline,
                label: 'Edit Profile',
                onTap: () => context.push('/settings/edit-profile'),
              ),
              const SizedBox(height: 16),

              //preferences section header
              const Text(
                'PREFERENCES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.subtext,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),

              //notification settings row is a placeholder for now
              _SettingsRow(
                icon: Icons.notifications_none_rounded,
                label: 'Notification Settings',
                onTap: () {
                  //TODO notification settings screen isnt built yet
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coming soon!')),
                  );
                },
              ),
              const SizedBox(height: 32),

              //log out button opens a confirmation dialog before actually signing out
              //logout has the same redirect bug as login. session clears but screen doesnt bounce to login
              OutlinedButton(
                onPressed: () async {
                  //showDialog returns whatever value we pop with. bool so we can tell confirm from cancel
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text(
                        'Log Out?',
                        style: TextStyle(color: AppColors.dark, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      content: const Text(
                        'Are you sure you want to log out?',
                        style: TextStyle(color: AppColors.subtext, fontSize: 14),
                      ),
                      actions: [
                        //pop with false for cancel
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel', style: TextStyle(color: AppColors.subtext)),
                        ),
                        //pop with true for confirm. red button to signal destructive action
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                          child: const Text('Log Out'),
                        ),
                      ],
                    ),
                  );
                  //only actually sign out if user confirmed
                  if (confirmed == true && context.mounted) {
                    final authService = Provider.of<AuthService>(context, listen: false);
                    await authService.signOut();
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  //red outline and red text so user knows this is a destructive action
                  side: const BorderSide(color: AppColors.danger),
                  foregroundColor: AppColors.danger,
                ),
                child: const Text(
                  'Log Out',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

//private reusable row widget for the settings list
//underscore at the start makes it private to this file so nothing else can import it
class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            //expanded pushes the chevron to the right edge no matter how long the label is
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.dark,
                ),
              ),
            ),
            //chevron on the right hints that tapping the row navigates somewhere
            const Icon(Icons.chevron_right, color: AppColors.subtext, size: 20),
          ],
        ),
      ),
    );
  }
}