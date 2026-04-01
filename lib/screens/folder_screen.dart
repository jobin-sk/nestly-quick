// ============================================================
// folder_screen.dart
// lib/screens/folder_screen.dart
// ============================================================
import 'package:flutter/material.dart';

class FolderScreen extends StatelessWidget {
  final String folderId;
  const FolderScreen({super.key, required this.folderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Folder: $folderId')),
    );
  }
}