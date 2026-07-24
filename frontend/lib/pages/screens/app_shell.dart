import 'package:flutter/material.dart';
import '../../widgets/navigation.dart';
import 'home_screen.dart';
import 'scan_screen.dart';
import 'learning_screen.dart';
import 'history_screen.dart';
import 'mapping_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final GlobalKey<State<LearningScreen>> _learningScreenKey = GlobalKey<State<LearningScreen>>();
  int _currentIndex = 0;
  int _previousIndex = 0;

  List<Widget> get _pages => [
    HomeScreen(onTabChanged: _onTabChanged),
    LearningScreen(key: _learningScreenKey),
    ScanScreen(onTabChanged: _onTabChanged),
    const HistoryScreen(),
    const MappingScreen(),
  ];

  void _onTabChanged(int index) {
    // Clear search when leaving learning screen (index 1)
    if (_previousIndex == 1 && index != 1) {
      try {
        (_learningScreenKey.currentState as dynamic)?.clearSearch();
      } catch (e) {
        // Silently handle if state is not available
      }
    }
    
    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF8FBFC),
      body: Stack(
        children: [
          // Content fills entire screen
          IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          // Navigation positioned at bottom (hide when Scan tab is active)
          if (_currentIndex != 2)
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
