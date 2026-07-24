import 'package:flutter/material.dart';

class SavedScreens extends StatefulWidget {
  const SavedScreens({super.key});

  @override
  State<SavedScreens> createState() => _SavedScreensState();
}

class _SavedScreensState extends State<SavedScreens> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved'),
        backgroundColor: const Color(0xFF0B7A8A),
      ),
      body: const Center(
        child: Text('Saved Screens'),
      ),
    );
  }
}