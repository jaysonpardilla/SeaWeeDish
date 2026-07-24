// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'dart:convert';
import 'seaweed_detail_screen.dart';

class LearningScreen extends StatefulWidget {
  const LearningScreen({super.key});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  List<Seaweed> allSeaweeds = [];
  List<Seaweed> filteredSeaweeds = [];
  String selectedCategory = 'All';
  String searchQuery = '';
  bool isLoading = true;
  final List<String> categories = ['All', 'Edible', 'Not Edible', 'Green Algae', 'Red Algae', 'Brown Algae'];
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadSeaweeds();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSeaweeds() async {
    try {
      print('🔍 Attempting to load JSON...');
      
      String response;
      try {
        // Try the primary path first
        response = await DefaultAssetBundle.of(context).loadString('assets/philippine_seaweeds_50.json');
        print('✅ Loaded from assets/philippine_seaweeds_50.json');
      } catch (e1) {
        print('⚠️ Failed with assets/ path: $e1');
        try {
          // Try with lib/assets path
          response = await DefaultAssetBundle.of(context).loadString('lib/assets/philippine_seaweeds_50.json');
          print('✅ Loaded from lib/assets/philippine_seaweeds_50.json');
        } catch (e2) {
          print('❌ Failed with lib/assets/ path: $e2');
          rethrow;
        }
      }
      
      final List<dynamic> data = jsonDecode(response);
      print('✅ JSON decoded successfully. Total entries: ${data.length}');
      
      setState(() {
        allSeaweeds = data.map((e) {
          try {
            return Seaweed.fromJson(e);
          } catch (e) {
            print('Error parsing entry: $e');
            rethrow;
          }
        }).toList();
        print('✅ Seaweeds parsed: ${allSeaweeds.length}');
        if (allSeaweeds.isNotEmpty) {
          print('First seaweed: ${allSeaweeds[0].commonName}');
        }
        
        // Randomize the "All" category by default
        filteredSeaweeds = List.from(allSeaweeds)..shuffle();
        print('✅ FilteredSeaweeds ready: ${filteredSeaweeds.length}');
        isLoading = false;
      });
    } catch (e) {
      print('❌ FATAL Error loading seaweeds: $e');
      setState(() {
        filteredSeaweeds = [];
        isLoading = false;
      });
    }
  }

  void _filterSeaweeds(String category) {
    setState(() {
      selectedCategory = category;
      _applyFilters();
    });
  }

  void _onSearchChanged() {
    setState(() {
      searchQuery = _searchController.text.toLowerCase();
      _applyFilters();
    });
  }

  void _applyFilters() {
    List<Seaweed> filtered = allSeaweeds;

    // Apply category filter
    if (selectedCategory == 'All') {
      filtered = List.from(allSeaweeds);
    } else if (selectedCategory == 'Edible') {
      filtered = filtered.where((s) => s.edible.toLowerCase().contains('edible') && !s.edible.toLowerCase().contains('not')).toList();
    } else if (selectedCategory == 'Not Edible') {
      filtered = filtered.where((s) => s.edible.toLowerCase().contains('not')).toList();
    } else {
      filtered = filtered.where((s) => s.type == selectedCategory).toList();
    }

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((s) => 
        s.commonName.toLowerCase().contains(searchQuery) ||
        s.scientificName.toLowerCase().contains(searchQuery) ||
        s.description.toLowerCase().contains(searchQuery)
      ).toList();
    } else if (selectedCategory == 'All') {
      // Only shuffle when no search query and "All" is selected
      filtered.shuffle();
    }

    filteredSeaweeds = filtered;
  }

  void clearSearch() {
    setState(() {
      _searchController.clear();
      _searchFocusNode.unfocus();
      searchQuery = '';
      _applyFilters();
    });
  }

  Future<void> _onRefresh() async {
    // Simulate a small delay for the refresh animation
    await Future.delayed(const Duration(milliseconds: 500));
    
    setState(() {
      // Shuffle the current filtered list to randomly display content
      filteredSeaweeds.shuffle();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading && allSeaweeds.isEmpty) {
      return Container(
        color: const Color(0xFFF8FBFC),
        child: const SafeArea(
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            // Dismiss keyboard when tapping outside search bar
            FocusScope.of(context).unfocus();
          },
          child: Column(
            children: [
              // Fixed header with transparent background
              Container(
                color: const Color.fromARGB(255, 255, 255, 255),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 5),
                      child: Text(
                        'Seaweeds Library',
                        style: const TextStyle(
                          fontFamily: 'Itim',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B7A8A),
                        ),
                      ),
                    ),
                    _buildSearchBar(),
                    _buildCategories(),
                  ],
                ),
              ),
              // Scrollable content with refresh indicator
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _onRefresh,
                  color: const Color.fromARGB(255, 64, 130, 134),
                  backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        _buildLearningGuides(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color.fromARGB(180, 12, 168, 179),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0CA8B3).withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          autofocus: false,
          onChanged: (_) => _onSearchChanged(),
          decoration: InputDecoration(
            hintText: 'Search species...',
            hintStyle: const TextStyle(
              fontSize: 13,
              color: Color(0xFFB0BEC5),
            ),
            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF0CA8B3)),
            suffixIcon: _searchController.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      _onSearchChanged();
                    },
                    child: const Icon(Icons.clear_rounded, color: Color(0xFFB0BEC5)),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildCategories() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            final isSelected = selectedCategory == category;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _filterSeaweeds(category),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF0CA8B3) : Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? const Color.fromARGB(255, 72, 232, 244) : Color(0xFF0CA8B3)
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
                      category,
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

  Widget _buildLearningGuides() {
    if (filteredSeaweeds.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Center(
          child: Text(
            'No seaweeds found for this category',
            style: TextStyle(
              fontSize: 14,
              color: const Color(0xFF395C7A),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: filteredSeaweeds.length,
        itemBuilder: (context, index) {
          final seaweed = filteredSeaweeds[index];
          final Color typeColor = _getTypeColor(seaweed.type);
          final Color edibleColor = _getEdibleColor(seaweed.edible);
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 245, 252, 255),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromARGB(255, 11, 242, 254).withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: seaweed.image.isNotEmpty
                        ? Image.asset(
                            seaweed.image,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              print('❌ Image failed to load: ${seaweed.image}');
                              return Icon(
                                Icons.spa_rounded,
                                color: typeColor,
                                size: 24,
                              );
                            },
                          )
                        : Icon(
                            Icons.spa_rounded,
                            color: typeColor,
                            size: 24,
                          ),
                  ),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      seaweed.commonName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF083C7E),
                      ),
                    ),
                    Text(
                      seaweed.scientificName,
                      style: const TextStyle(
                        fontSize: 9,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF395C7A),
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    seaweed.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF395C7A),
                    ),
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: edibleColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    seaweed.edible,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: edibleColor,
                    ),
                  ),
                ),
                onTap: () {
                  FocusScope.of(context).unfocus();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SeaweedDetailScreen(seaweed: seaweed),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Green Algae':
        return const Color(0xFF00B86B);
      case 'Red Algae':
        return const Color(0xFFE74C3C);
      case 'Brown Algae':
        return const Color(0xFF8B4513);
      default:
        return const Color(0xFF5E7FD8);
    }
  }

  Color _getEdibleColor(String edible) {
    if (edible.toLowerCase().contains('edible') && !edible.toLowerCase().contains('not')) {
      return const Color(0xFF00B86B);
    } else if (edible.toLowerCase().contains('not')) {
      return const Color(0xFFE74C3C);
    } else {
      return const Color(0xFFFFB84D);
    }
  }
}
