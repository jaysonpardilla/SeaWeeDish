import 'package:flutter/material.dart';
import '../../widgets/navigation.dart';
import 'home_screen.dart';
import 'scan_screen.dart';
import 'learning_screen.dart';
import 'history_screen.dart';
import 'mapping_screen.dart';

/// Enum for organizing screen indices - makes code more readable
enum AppScreen {
  home(0),
  learning(1),
  scan(2),
  history(3),
  mapping(4);

  final int value;
  const AppScreen(this.value);
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final GlobalKey<State<LearningScreen>> _learningScreenKey = 
  GlobalKey<State<LearningScreen>>();
  int _currentIndex = 0;
  int _previousIndex = 0;

  List<Widget> get _pages => [
    HomeScreen(onTabChanged: _onTabChanged),
    LearningScreen(key: _learningScreenKey),
    ScanScreen(onTabChanged: _onTabChanged),
    const HistoryScreen(),
    const MappingScreen(),
  ];

  /// Handle tab changes and cleanup for specific screens
  void _onTabChanged(int index) {
    _clearSearchIfLeavingLearning(index);
    
    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = index;
    });
  }

  /// Clear learning screen search when navigating away from it
  void _clearSearchIfLeavingLearning(int newIndex) {
    final isLeavingLearning = 
        _previousIndex == AppScreen.learning.value && 
        newIndex != AppScreen.learning.value;
    
    if (!isLeavingLearning) return;

    try {
      final learningState = _learningScreenKey.currentState;
      if (learningState != null) {
        (learningState as dynamic).clearSearch();
      }
    } catch (e) {
      debugPrint('Error clearing learning screen search: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF8FBFC),
      body: Stack(
        children: [
          // Content fills entire screen based on current tab
          IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          // Navigation bar positioned at bottom (hidden when on Scan tab)
          if (_currentIndex != AppScreen.scan.value)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: BottomNavigation(
                currentIndex: _currentIndex,
                onTabChanged: _onTabChanged,
              ),
            ),
        ],
      ),
    );
  }
}
