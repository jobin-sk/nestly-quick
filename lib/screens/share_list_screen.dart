// ============================================================
// share_list_screen.dart
// lib/screens/share_list_screen.dart
// ============================================================
import 'package:flutter/material.dart';

class ShareListScreen extends StatelessWidget {
  final String listId;
  const ShareListScreen({super.key, required this.listId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Share List: $listId')),
    );
  }
}