// ============================================================
// list_view_screen.dart
// lib/screens/list_view_screen.dart
// ============================================================
import 'package:flutter/material.dart';

class ListViewScreen extends StatelessWidget {
  final String listId;
  const ListViewScreen({super.key, required this.listId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('List: $listId')),
    );
  }
}