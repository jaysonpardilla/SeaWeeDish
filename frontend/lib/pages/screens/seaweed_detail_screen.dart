// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'learning_screen.dart';

class Seaweed {
  final int id;
  final String commonName;
  final String scientificName;
  final String description;
  final String edible;
  final String type;
  final String foundIn;
  final String season;
  final String habitat;
  final String safetyNotes;
  final String image;
  final String descriptionImage;
  final String identificationGuide;

  Seaweed({
    required this.id,
    required this.commonName,
    required this.scientificName,
    required this.description,
    required this.edible,
    required this.type,
    required this.foundIn,
    required this.season,
    required this.habitat,
    required this.safetyNotes,
    required this.image,
    required this.descriptionImage,
    required this.identificationGuide,
  });

  factory Seaweed.fromJson(Map<String, dynamic> json) {
    return Seaweed(
      id: json['id'],
      commonName: json['common_name'],
      scientificName: json['scientific_name'],
      description: json['description'],
      edible: json['edible'],
      type: json['type'],
      foundIn: json['found_in'],
      season: json['season'],
      habitat: json['habitat'],
      safetyNotes: json['safety_notes'],
      image: json['image'],
      descriptionImage: json['description_image'],
      identificationGuide: json['identification_guide'],
    );
  }
}

class SeaweedDetailScreen extends StatefulWidget {
  final Seaweed seaweed;

  const SeaweedDetailScreen({super.key, required this.seaweed});

  @override
  State<SeaweedDetailScreen> createState() => _SeaweedDetailScreenState();
}

class _SeaweedDetailScreenState extends State<SeaweedDetailScreen> {
  bool isFavorite = false;
  List<Seaweed> similarSeaweeds = [];
  int currentNavIndex = 3; // Learn tab

  @override
  void initState() {
    super.initState();
    _loadFavoriteState();
    _loadSimilarSeaweeds();
  }

  Future<void> _loadFavoriteState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'favorite_seaweed_${widget.seaweed.id}';
      final saved = prefs.getBool(key) ?? false;

      if (mounted) {
        setState(() {
          isFavorite = saved;
        });
      }
    } catch (e) {
      debugPrint('Failed to load favorite state: $e');
    }
  }

  Future<void> _saveFavoriteState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'favorite_seaweed_${widget.seaweed.id}';
      await prefs.setBool(key, isFavorite);
    } catch (e) {
      debugPrint('Failed to save favorite state: $e');
    }
  }

  Future<void> _loadSimilarSeaweeds() async {
    try {
      String response = await rootBundle.loadString('lib/assets/philippine_seaweeds_50.json');
      final List<dynamic> data = jsonDecode(response);
      
      print('Loaded ${data.length} seaweeds from JSON');
      print('Current seaweed type: ${widget.seaweed.type}');
      
      // Filter by same type and exclude current seaweed
      List<Seaweed> sameType = data
          .map((e) => Seaweed.fromJson(e as Map<String, dynamic>))
          .where((s) => s.type == widget.seaweed.type && s.id != widget.seaweed.id)
          .toList();
      
      print('Found ${sameType.length} seaweeds of same type');
      
      // Shuffle and take 4 random ones
      sameType.shuffle();
      final List<Seaweed> selectedSeaweeds = sameType.take(4).toList();
      
      print('Selected ${selectedSeaweeds.length} random seaweeds');
      
      if (mounted) {
        setState(() {
          similarSeaweeds = selectedSeaweeds;
        });
      }
    } catch (e, stackTrace) {
      print('Error loading similar seaweeds: $e');
      print('Stack trace: $stackTrace');
      // Try with alternative path
      try {
        String response = await rootBundle.loadString('assets/philippine_seaweeds_50.json');
        final List<dynamic> data = jsonDecode(response);
        
        List<Seaweed> sameType = data
            .map((e) => Seaweed.fromJson(e as Map<String, dynamic>))
            .where((s) => s.type == widget.seaweed.type && s.id != widget.seaweed.id)
            .toList();
        
        sameType.shuffle();
        
        if (mounted) {
          setState(() {
            similarSeaweeds = sameType.take(4).toList();
          });
        }
      } catch (e2) {
        print('Error with alternative path: $e2');
      }
    }
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

  List<String> _parseBulletPoints(String text) {
    if (text.isEmpty) return [];
    return text.split(RegExp(r'[•\-\*]\s+|(?<=\.)\s+'))
        .where((s) => s.isNotEmpty && s.length > 5)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _getTypeColor(widget.seaweed.type);
    final edibleColor = _getEdibleColor(widget.seaweed.edible);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Main Content
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: _loadSimilarSeaweeds,
              color: const Color(0xFF0CA8B3),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Top Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          
                            child: const Icon(
                              Icons.arrow_back_rounded,
                              color: Color(0xFF083C7E),
                              size: 20,
                            ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            setState(() {
                              isFavorite = !isFavorite;
                            });
                            await _saveFavoriteState();
                          },
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: isFavorite ? Colors.red : const Color(0xFF083C7E),
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Hero Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(224, 234, 239, 239),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Image
                          ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F0F0),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: widget.seaweed.image.isNotEmpty
                                  ? Image.asset(
                                      widget.seaweed.image,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Icon(
                                          Icons.spa_rounded,
                                          color: typeColor,
                                          size: 40,
                                        );
                                      },
                                    )
                                  : Icon(
                                      Icons.spa_rounded,
                                      color: typeColor,
                                      size: 40,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Right Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.seaweed.commonName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF083C7E),
                                    fontFamily: 'Itim',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.seaweed.scientificName,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                    color: Color(0xFF395C7A),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: edibleColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    widget.seaweed.edible,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: edibleColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.seaweed.description,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF395C7A),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Information Grid
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(224, 234, 239, 239),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(1),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildInfoItem('Type', widget.seaweed.type.split(',')[0].trim(), typeColor, Icons.eco),
                          _buildInfoItem('Habitat', widget.seaweed.habitat.split(',')[0].trim(), const Color(0xFF0CA8B3), Icons.water_drop_rounded),
                          _buildInfoItem('Found In', widget.seaweed.foundIn.split(',')[0].trim(), const Color(0xFFE74C3C), Icons.location_on_rounded),
                          _buildInfoItem('Season', widget.seaweed.season.split(',')[0].trim(), const Color(0xFFFFB84D), Icons.calendar_month_rounded),
                        ],
                      ),
                    ),
                  ),

                  // Identification Guide
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(224, 234, 239, 239),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left: Text Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00B86B).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.check_circle_rounded,
                                        color: Color(0xFF00B86B),
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        'Identification Guide',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF083C7E),
                                          fontFamily: 'Itim',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                ..._parseBulletPoints(widget.seaweed.identificationGuide)
                                    .map((point) => Padding(
                                          padding: const EdgeInsets.only(bottom: 10),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Padding(
                                                padding: EdgeInsets.only(top: 4, right: 8),
                                                child: Icon(
                                                  Icons.check,
                                                  size: 14,
                                                  color: Color(0xFF00B86B),
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  point.trim(),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF395C7A),
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ))
                                    .toList(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Right: Image
                          if (widget.seaweed.descriptionImage.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: 120,
                                height: 150,
                                color: const Color(0xFFF0F0F0),
                                child: Image.asset(
                                  widget.seaweed.descriptionImage,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.image_not_supported_rounded,
                                      color: const Color(0xFF0CA8B3),
                                    );
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Safety Notes
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(224, 234, 239, 239),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0CA8B3).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.shield_rounded,
                                  color: Color(0xFF0CA8B3),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Safety Notes',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF083C7E),
                                    fontFamily: 'Itim',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ..._parseBulletPoints(widget.seaweed.safetyNotes)
                              .map((point) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(top: 4, right: 8),
                                          child: Icon(
                                            Icons.warning_amber_rounded,
                                            size: 14,
                                            color: Color(0xFF0CA8B3),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            point.trim(),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF395C7A),
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ))
                              .toList(),
                        ],
                      ),
                    ),
                  ),

                  // Similar Seaweeds
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10,vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Similar Seaweeds',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF083C7E),
                                fontFamily: 'Itim',
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LearningScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                'See All',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0CA8B3),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 130,
                          child: similarSeaweeds.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No similar seaweeds found',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF395C7A),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: similarSeaweeds.length,
                                  itemBuilder: (context, index) {
                                    final seaweed = similarSeaweeds[index];
                                    final seaweedColor = _getTypeColor(seaweed.type);
                                    final edibleCol = _getEdibleColor(seaweed.edible);

                                    return Padding(
                                      padding: const EdgeInsets.only(right: 10),
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.pop(context);
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => SeaweedDetailScreen(seaweed: seaweed),
                                            ),
                                          );
                                        },
                                        child: SizedBox(
                                          width: 80,
                                          height: 130,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: const Color.fromARGB(224, 234, 239, 239),
                                              borderRadius: BorderRadius.circular(14),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.06),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                ClipRRect(
                                                  borderRadius: const BorderRadius.only(
                                                    topLeft: Radius.circular(14),
                                                    topRight: Radius.circular(14),
                                                  ),
                                                  child: Container(
                                                    width: double.infinity,
                                                    height: 70,
                                                    color: const Color(0xFFF0F0F0),
                                                    child: seaweed.image.isNotEmpty
                                                        ? Image.asset(
                                                            seaweed.image,
                                                            fit: BoxFit.cover,
                                                            errorBuilder: (context, error, stackTrace) {
                                                              return Icon(
                                                                Icons.spa_rounded,
                                                                color: seaweedColor,
                                                                size: 24,
                                                              );
                                                            },
                                                          )
                                                        : Icon(
                                                            Icons.spa_rounded,
                                                            color: seaweedColor,
                                                            size: 24,
                                                          ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(6),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Text(
                                                          seaweed.commonName,
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: const TextStyle(
                                                            fontSize: 9,
                                                            fontWeight: FontWeight.w600,
                                                            color: Color(0xFF083C7E),
                                                            height: 1.2,
                                                          ),
                                                        ),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: edibleCol.withOpacity(0.15),
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Text(
                                                            seaweed.edible,
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: TextStyle(
                                                              fontSize: 7,
                                                              fontWeight: FontWeight.w600,
                                                              color: edibleCol,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
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
                                ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          )
        ],
      
      ),
    );
  }



  Widget _buildInfoItem(String label, String value, Color color, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Center(
            child: Icon(icon, color: color, size: 18),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF395C7A),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 70,
          child: Text(
            value,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF083C7E),
            ),
          ),
        ),
      ],
    );
  }

}