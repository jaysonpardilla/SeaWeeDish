// ignore_for_file: use_full_hex_values_for_flutter_colors

import 'package:flutter/material.dart';


class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late final AnimationController _borderController;
  late final Animation<double> _borderAnimation;

  final List<Map<String, String>> _pages = const [
    {
      'title': 'Scan Seaweeds Instantly',
      'subtitle': 'Use your camera to identify marine plants in seconds.',
      'image': 'lib/assets/onboarding/onboard1.png',
      'button': 'Next',
    },
    {
      'title': 'AI Powered Identification',
      'subtitle': 'Advance machine learning helps recognize species with confidence.',
      'image': 'lib/assets/onboarding/onboard2.png',
      'button': 'Next',
    },
    {
      'title': 'Stay Safe While Exploring',
      'subtitle': 'Not all seaweeds are safe to eat. Always verify before consuming.',
      'image': 'lib/assets/onboarding/onboard3.png',
      'button': 'Get Started',
    },
  ];

  TextStyle get _titleTextStyle => TextStyle(
        fontFamily: 'Itim',
        fontSize: 30,
        fontWeight: FontWeight.bold,
        color: Color(0xFF083C7E),
        letterSpacing: 0.5,
        height: 1.0,
      );

  TextStyle get _subtitleTextStyle => const TextStyle(
        fontFamily: 'Itim',
        fontSize: 15,
        color: Color(0xFF395C7A),
        height: 1.3,
      );

  void _goNextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    } else {
      // Navigate to app shell (guest) on the last page
      Navigator.of(context).pushReplacementNamed('/app');
    }
  }

  @override
  void initState() {
    super.initState();

    _borderController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _borderAnimation = Tween<double>(begin: 0, end: 2 * 3.14159).animate(
      CurvedAnimation(parent: _borderController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _borderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                    child: Column(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                page['title']!,
                                textAlign: TextAlign.center,
                                style: _titleTextStyle,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                page['subtitle']!,
                                textAlign: TextAlign.center,
                                style: _subtitleTextStyle,
                              ),
                              const SizedBox(height: 16),
                              Center(
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 300,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(30),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x14000000),
                                          blurRadius: 20,
                                          offset: Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Image.asset(
                                      page['image']!,
                                      fit: BoxFit.cover,
                                      filterQuality: FilterQuality.high,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) {
                        final bool isActive = index == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          width: isActive ? 24 : 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: isActive ? const Color(0xFF2D8B72) : const Color(0xFFB7D0C3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  AnimatedBuilder(
                    animation: _borderAnimation,
                    builder: (context, child) {
                      return Container(
                        width: double.infinity,
                        height: 53,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: SweepGradient(
                            startAngle: 0,
                            endAngle: 2 * 3.14159,
                            transform: GradientRotation(_borderAnimation.value),
                            colors: const [
                              Color(0xFFF00E5FF), // Deep ocean blue
                              Color(0xFF00CFCF), // Bright aqua
                              Color(0xFF4FFFB0), // Sea green
                              Color(0xFF2BE4FF), // Light blue
                              Color.fromARGB(255, 218, 99, 105), // Back to deep blue
                            ],
                            stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                          ),
                        ),
                        padding: const EdgeInsets.all(2.5), // Border thickness
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF0B3D91), // Deep blue
                                Color(0xFF0CA8B3), // Aqua
                                Color(0xFF8BE8CE), // Light green
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x2D0B3D91),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _goNextPage,
                              borderRadius: BorderRadius.circular(16),
                              child: Center(
                                child: Text(
                                  _pages[_currentPage]['button']!,
                                  style: const TextStyle(
                                    fontFamily: 'Itim',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
