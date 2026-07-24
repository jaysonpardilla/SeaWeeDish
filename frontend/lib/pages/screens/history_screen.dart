// ignore_for_file: deprecated_member_use

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _selectedFilter = 0;
  String searchQuery = '';
  bool _sortAscending = true;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final List<String> _filters = ['All', 'Edible', 'Not edible', 'Unidentified'];

  List<Map<String, dynamic>> _allScans = [];
  List<Map<String, dynamic>> _filteredScans = [];

  @override
  void initState() {
    super.initState();
    _loadSavedHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSavedHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final storedHistory = prefs.getStringList('device_scan_history') ?? [];

    final history = storedHistory
        .map((item) => jsonDecode(item) as Map<String, dynamic>)
        .toList();

    if (!mounted) return;

    setState(() {
      _allScans = history;
      _applyFilters();
    });
  }

  void _applyFilters() {
    final filter = _filters[_selectedFilter];
    final filtered = _allScans.where((scan) {
      final matchesFilter = filter == 'All' ||
          (filter == 'Edible' && scan['status'] == 'Edible') ||
          (filter == 'Not edible' && scan['status'] == 'Not edible') ||
          (filter == 'Unidentified' && scan['status'] == 'Unidentified');
      final matchesQuery = searchQuery.isEmpty ||
          (scan['name'] as String).toLowerCase().contains(searchQuery) ||
          (scan['date'] as String).toLowerCase().contains(searchQuery) ||
          (scan['status'] as String).toLowerCase().contains(searchQuery);
      return matchesFilter && matchesQuery;
    }).toList();

    // Apply sorting
    if (_sortAscending) {
      filtered.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    } else {
      filtered.sort((a, b) => (b['name'] as String).compareTo(a['name'] as String));
    }

    setState(() {
      _filteredScans = filtered;
    });
  }

  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(milliseconds: 400));
    await _loadSavedHistory();
  }

  void _showSortFilterMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sort & Filter',
              style: TextStyle(
                fontFamily: 'Itim',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0B7A8A),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sort Order',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF083C7E),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _sortAscending = true;
                        _applyFilters();
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: _sortAscending ? const Color(0xFF0CA8B3) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF0CA8B3),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Text(
                          'Ascending (A-Z)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _sortAscending ? Colors.white : const Color(0xFF0B7A8A),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _sortAscending = false;
                        _applyFilters();
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: !_sortAscending ? const Color(0xFF0CA8B3) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF0CA8B3),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Text(
                          'Descending (Z-A)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: !_sortAscending ? Colors.white : const Color(0xFF0B7A8A),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Filter by Category',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF083C7E),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_filters.length, (index) {
                final isSelected = _selectedFilter == index;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedFilter = index;
                      _applyFilters();
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF0CA8B3) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF0CA8B3),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      _filters[index],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF0B7A8A),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: Column(
            children: [
              // Fixed header with transparent background
              Container(
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Scan History',
                            style: const TextStyle(
                              fontFamily: 'Itim',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0B7A8A),
                            ),
                          ),
                          GestureDetector(
                            onTap: _showSortFilterMenu,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFD9F4F7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.all(8),
                              child: const Icon(
                                Icons.sort,
                                color: Color(0xFF0B7A8A),
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildFilterBar(),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _onRefresh,
                  color: const Color(0xFF0CA8B3),
                  backgroundColor: Colors.white,
                  child: _buildScanHistory(),
                ), 
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _filters.length,
          itemBuilder: (context, index) {
            final isSelected = index == _selectedFilter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedFilter = index;
                    _applyFilters();
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF0CA8B3) : Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF0CA8B3) : const Color(0xFF0CA8B3),
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF0CA8B3).withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: Text(
                      _filters[index],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF083C7E),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildScanHistory() {
    if (_filteredScans.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 300),
          Center(
            child: Text(
              'No history matches your search or filter.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF395C7A),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      itemCount: _filteredScans.length,
      itemBuilder: (context, index) {
        final scan = _filteredScans[index];
        final statusColor = _statusColor(scan['status'] as String);
        return Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: GestureDetector(
            onTap: () {
              // Navigate to detail screen
            },
            child: Container(
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 245, 252, 255),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFBDEAF1), Color(0xFFEBF8FB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _buildHistoryImage(scan),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            scan['name'] as String,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF083C7E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Confidence: ${scan['confidence']}%',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF9AA5B1),
                            ),
                          ),
                          Text(
                            scan['date'] as String,
                            style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF6B7A8D),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text(
                        scan['status'] as String,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryImage(Map<String, dynamic> scan) {
    final imageData = scan['imageData'];
    if (imageData is String && imageData.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(imageData),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Text(
                scan['emoji'] as String,
                style: const TextStyle(fontSize: 28),
              ),
            );
          },
        );
      } catch (e) {
        return Center(
          child: Text(
            scan['emoji'] as String,
            style: const TextStyle(fontSize: 28),
          ),
        );
      }
    }

    return Center(
      child: Text(
        scan['emoji'] as String,
        style: const TextStyle(fontSize: 28),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Edible':
        return const Color(0xFF00B86B);
      case 'Not edible':
        return const Color(0xFFE53935);
      default:
        return const Color(0xFF6B7A8D);
    }
  }
}
