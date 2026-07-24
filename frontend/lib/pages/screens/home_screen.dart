// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) onTabChanged;

  const HomeScreen({super.key, required this.onTabChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _commonSeaweeds = [];
  List<Map<String, dynamic>> _recentScans = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadHomeData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadRecentScans();
    }
  }

  Future<void> _loadHomeData() async {
    await Future.wait([
      _loadCommonSeaweeds(),
      _loadRecentScans(),
    ]);
  }

  Future<void> _loadCommonSeaweeds() async {
    try {
      final response = await rootBundle.loadString('lib/assets/philippine_seaweeds_50.json');
      final List<dynamic> data = jsonDecode(response);
      final seaweeds = data.map((item) => item as Map<String, dynamic>).toList();

      final random = Random();
      seaweeds.shuffle(random);

      final displayed = seaweeds.take(9).map((item) {
        final isEdible = random.nextBool();
        final status = isEdible ? 'Edible' : 'Not edible';
        final statusColor = isEdible ? Colors.green : Colors.red;

        return {
          'name': item['common_name'] ?? 'Seaweed',
          'status': status,
          'statusColor': statusColor,
          'distance': '${1 + random.nextInt(4)}.${random.nextInt(9)} km',
          'image': item['image'] ?? '',
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _commonSeaweeds = displayed;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _commonSeaweeds = [];
      });
    }
  }

  Future<void> _loadRecentScans() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedHistory = prefs.getStringList('device_scan_history') ?? [];
      final history = storedHistory
          .map((item) => jsonDecode(item) as Map<String, dynamic>)
          .toList();

      final sorted = [...history]
        ..sort((a, b) {
          final first = (a['createdAt'] ?? 0) as int;
          final second = (b['createdAt'] ?? 0) as int;
          return second.compareTo(first);
        });

      if (!mounted) return;
      setState(() {
        _recentScans = sorted.take(3).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _recentScans = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FBFC),
        child: SafeArea(
          top: false,
          bottom: true,
          child: RefreshIndicator(
            onRefresh: _refreshData,
            color: const Color(0xFF0B7A8A),
            backgroundColor: Colors.white,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                // Top Banner Image
                _buildTopBanner(),
                
                // Quick Actions
                _buildQuickActions(),
                
                // Nearby Seaweeds
                _buildNearbySeaweeds(),
                
                // Recent Scans
                _buildRecentScans(),
                
                // Info Cards Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  child: Row(
                    children: [
                      Expanded(child: _buildDidYouKnowCard()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildSafetyReminderCard()),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      )
    );
  }

  Future<void> _refreshData() async {
    await _loadHomeData();
    await Future.delayed(const Duration(milliseconds: 400));
  }

  Widget _buildTopBanner() {
    return Container(
      width: double.infinity,
      height: 275,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'lib/assets/images/home-banner.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.05),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with "See All" link
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontFamily: 'Itim',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0B7A8A),
                ),
              ),
              GestureDetector(
                onTap: () {
                  // Navigate to see all actions
                },
                child: Row(
                  children: [
                    const Text(
                      'See All',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0B7A8A),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Color(0xFF0B7A8A),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          // Quick Actions Grid
          GridView(
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: false,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            children: [
              _buildQuickActionTile(
                icon: Icons.image_outlined,
                title: 'Upload Image',
                subtitle: 'From gallery',
                backgroundColor: const Color(0xFFD9F4F7),
                iconColor: const Color(0xFF0B7A8A),
                onTap: () => widget.onTabChanged(2),
              ),
              _buildQuickActionTile(
                icon: Icons.location_on_outlined,
                title: 'View Map',
                subtitle: 'Explore nearby\nseaweeds',
                backgroundColor: const Color(0xFFD9F4F7),
                iconColor: const Color(0xFF0B7A8A),
                onTap: () => widget.onTabChanged(4),
              ),
              _buildQuickActionTile(
                icon: Icons.menu_book_outlined,
                title: 'Learn',
                subtitle: 'Stay informed',
                backgroundColor: const Color(0xFFD9F4F7),
                iconColor: const Color(0xFF0B7A8A),
                onTap: () => widget.onTabChanged(1),
              ),
              _buildQuickActionTile(
                icon: Icons.security_outlined,
                title: 'Safety Tips',
                subtitle: 'Guidelines for\nsafe use',
                backgroundColor: const Color(0xFFD9F4F7),
                iconColor: const Color(0xFF0B7A8A),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color backgroundColor,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap ?? () {
        // Handle action
      },
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor.withOpacity(1),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon Container
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 24,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 3),
            // Title
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Color.fromARGB(255, 6, 66, 75),
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 2),
            // Subtitle
            Expanded(
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0B7A8A),
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbySeaweeds() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 1, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Common Seaweeds',
                    style: TextStyle(
                      fontFamily: 'Itim',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B7A8A),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => widget.onTabChanged(1),
                child: Row(
                  children: [
                    const Text(
                      'See All',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0B7A8A),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Color(0xFF0B7A8A),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Seaweeds Grid
          GridView.builder(
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: false,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 0,
              crossAxisSpacing: 8,
              childAspectRatio: 0.8,
            ),
            itemCount: _commonSeaweeds.length,
            itemBuilder: (context, index) {
              final seaweed = _commonSeaweeds[index];
              return GestureDetector(
                onTap: () => widget.onTabChanged(1),
                child: _buildSeaweedCard(
                  name: seaweed['name'] as String,
                  status: seaweed['status'] as String,
                  statusColor: seaweed['statusColor'] as Color,
                  distance: seaweed['distance'] as String,
                  imagePath: seaweed['image'] as String,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSeaweedCard({
    required String name,
    required String status,
    required Color statusColor,
    required String distance,
    required String imagePath,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image Container with Distance Badge
        Stack(
          children: [
            Container(
              width: double.infinity,
              height: 85,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey[300],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _buildImageFromPath(imagePath),
              ),
            ),
            // Distance Badge
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2DBE89),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  distance,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Seaweed Name
        Text(
          name,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0B7A8A),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        // Status Badge
        Row(
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    final normalized = status.toLowerCase();
    if (normalized.contains('edible')) {
      return Colors.green;
    }
    if (normalized.contains('unidentified')) {
      return Colors.orange;
    }
    return Colors.red;
  }

  Widget _buildImageFromPath(String imagePath) {
    final isAsset = imagePath.startsWith('lib/assets/') || imagePath.startsWith('assets/');

    if (isAsset) {
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: const Center(
              child: Icon(Icons.image, color: Colors.grey),
            ),
          );
        },
      );
    }

    return Image.network(
      imagePath,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.grey[300],
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0B7A8A)),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[300],
          child: const Center(
            child: Icon(Icons.image, color: Colors.grey),
          ),
        );
      },
    );
  }

  Widget _buildDidYouKnowCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEBF8F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD4EFE9),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Seaweed Illustration
          Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFD9F4F7).withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.spa,
              size: 35,
              color: Color(0xFF0B7A8A),
            ),
          ),
          const SizedBox(height: 12),
          // Content
          const Text(
            'Did You Know?',
            style: TextStyle(
              fontFamily: 'Itim',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0B7A8A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Some seaweeds are rich in antioxidants, but others can be harmful. Identify before you consume!',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF4A6A74),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              // Navigate to learn more
            },
            child: Row(
              children: [
                const Text(
                  'Learn more',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0B7A8A),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward,
                  size: 11,
                  color: Color(0xFF0B7A8A),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyReminderCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFEF4E8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFE8C9),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Check Icon
          Container(
            width: double.infinity,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFF2DBE89).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(
                Icons.check_circle_outline,
                size: 35,
                color: Color(0xFF2DBE89),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Content
          const Text(
            'Safety Reminder',
            style: TextStyle(
              fontFamily: 'Itim',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFFD97706),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Avoid consuming unidentified seaweeds. When in doubt, don\'t eat it.',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF7C5D1F),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2DBE89).withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shield,
                  size: 13,
                  color: Color(0xFF2DBE89),
                ),
                SizedBox(width: 4),
                Text(
                  'Stay Safe',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2DBE89),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentScans() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Scans',
                style: TextStyle(
                  fontFamily: 'Itim',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0B7A8A),
                ),
              ),
              GestureDetector(
                onTap: () => widget.onTabChanged(3),
                child: Row(
                  children: [
                    const Text(
                      'See all',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0B7A8A),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Color(0xFF0B7A8A),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Recent Scans List
          if (_recentScans.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No recent scans yet.',
                style: TextStyle(fontSize: 12, color: Color(0xFF6C7A80)),
              ),
            )
          else
            Column(
              children: List.generate(
                _recentScans.length,
                (index) {
                  final scan = _recentScans[index];
                  final status = (scan['status'] ?? 'Unidentified').toString();
                  final confidence = scan['confidence'] ?? '—';
                  final statusColor = _getStatusColor(status);
                  final imageData = scan['imageData'] as String?;

                  return GestureDetector(
                    onTap: () => widget.onTabChanged(3),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.grey[300],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: imageData != null && imageData.isNotEmpty
                                  ? Image.memory(
                                      base64Decode(imageData),
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Center(
                                          child: Icon(Icons.broken_image_outlined, color: Colors.grey),
                                        );
                                      },
                                    )
                                  : _buildImageFromPath('lib/assets/images/seaweeds-images/Ulva lactuca.jpg'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (scan['name'] ?? 'Unknown').toString(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0B7A8A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Confidence: $confidence',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF6C7A80),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

}