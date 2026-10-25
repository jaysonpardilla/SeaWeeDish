// ignore_for_file: unused_field, deprecated_member_use

import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/app_language.dart';

class BottomNavigation extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTabChanged;

  const BottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTabChanged,
  });

  @override
  State<BottomNavigation> createState() => _BottomNavigationState();
}

class _BottomNavigationState extends State<BottomNavigation>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  bool _animationsInitialized = false;

  // Design Constants
  static const Color _backgroundColor = Colors.transparent;
  static const Color _activeIndicatorColor = Color.fromARGB(255, 11, 120, 147);
  static const Color _iconColorInactive = Color.fromARGB(255, 83, 85, 87);
  static const Color _iconColorActive = Colors.white;
  static const double _navBarHeight = 70;
  static const double _indicatorSize = 52;
  static const double _itemSpacing = 24;
  static const Duration _animationDuration = Duration(milliseconds: 400);

  final List<NavItem> _navItems = [
    NavItem(icon: Icons.home_rounded, label: 'Home'),
    NavItem(icon: Icons.menu_book_rounded, label: 'Learn'),
    NavItem(icon: Icons.camera_alt_rounded, label: 'Scan'),
    NavItem(icon: Icons.history_rounded, label: 'History'),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    if (!_animationsInitialized) {
      _animationController = AnimationController(
        duration: _animationDuration,
        vsync: this,
      );

      _animationsInitialized = true;
      _updateAnimation();
    }
  }

  @override
  void didUpdateWidget(BottomNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    _slideAnimation = Tween<double>(
      begin: widget.currentIndex.toDouble() - 0.5,
      end: widget.currentIndex.toDouble() - 0.5,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.fastOutSlowIn,
      ),
    );
    _animationController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _animationsInitialized = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ensure animations are initialized (for hot reload safety)
    if (!_animationsInitialized) {
      _initializeAnimations();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 12, right: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
          child: Container(
            height: _navBarHeight,
            decoration: BoxDecoration(
              color: const Color.fromARGB(122, 17, 178, 181),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0x2935D2F8), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x2935D2F8),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                _navItems.length,
                (index) => _buildNavItem(index),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final isActive = widget.currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => widget.onTabChanged(index),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Animated background circle for active item
            AnimatedContainer(
              duration: _animationDuration,
              curve: Curves.fastOutSlowIn,
              width: isActive ? _indicatorSize : 0,
              height: isActive ? _indicatorSize : 0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _activeIndicatorColor,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: _activeIndicatorColor.withOpacity(0.5),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
            ),

            // Icon with active label underneath
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  duration: _animationDuration,
                  curve: Curves.fastOutSlowIn,
                  scale: 1.0,
                  child: Icon(
                    _navItems[index].icon,
                    color: isActive ? _iconColorActive : _iconColorInactive,
                    size: 33,
                  ),
                ),
                if (isActive) ...[
                  Text(
                    appText('navigation.dart', _navItems[index].label),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class NavItem {
  final IconData icon;
  final String label;

  NavItem({
    required this.icon,
    required this.label,
  });
}
