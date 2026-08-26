// ignore_for_file: use_full_hex_values_for_flutter_colors, deprecated_member_use
import 'package:flutter/material.dart';
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}
class _OnboardingScreenState extends State<OnboardingScreen> {
  void _goToApp() {
    Navigator.of(context).pushReplacementNamed('/app');
  }
  TextStyle get _titleTextStyle => const TextStyle(
        fontFamily: 'Itim',
        fontSize: 34,
        fontWeight: FontWeight.bold,
        color: Color(0xFF0F3B3D),
        height: 1.1,
      );
  TextStyle get _subtitleTextStyle => const TextStyle(
      fontFamily: 'Lora',
        fontSize: 16,
        color: Color(0xFF5B6B6D),
        height: 1.4,
      );

  TextStyle get _featureTitleStyle => const TextStyle(
      fontFamily: 'Lora',
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF0F3B3D),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'lib/assets/onboarding/onboarding.png',
              fit: BoxFit.contain,
              alignment: Alignment.center,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomLeft,
                  colors: [
                    Color.fromARGB(143, 9, 60, 3),
                    Color.fromARGB(20, 230, 241, 226),
                    Color.fromARGB(213, 22, 51, 36),
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Image.asset(
                        'lib/assets/images/app_icon.png',
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Discover. Identify. Thrive.',
                    textAlign: TextAlign.center,
                    style: _titleTextStyle,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Get curated recipes, cooking tips, and nutritional benefits.',
                    textAlign: TextAlign.center,
                    style: _subtitleTextStyle,
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildFeatureCard(
                        icon: Icons.eco,
                        title: 'Nutrient Rich',
                      ),
                      _buildFeatureCard(
                        icon: Icons.favorite,
                        title: 'Healthy Lifestyle',
                      ),
                      _buildFeatureCard(
                        icon: Icons.autorenew,
                        title: 'Sustainable Choice',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _goToApp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 26, 103, 107),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        side: const BorderSide(
                          color: Color.fromARGB(255, 54, 125, 127),
                          width: 1,
                        ),
                      ),
                      child: const Text(
                        'Get Started',
                        style: TextStyle(
                          fontFamily: 'Itim',
                          fontSize: 18,
                          fontWeight: FontWeight.bold, 
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Let's explore seaweeds together!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 14,
                      color: Color.fromARGB(255, 232, 252, 255),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color.fromARGB(145, 255, 255, 255),
          borderRadius: BorderRadius.circular(18), 
          border: Border.all(
            color: const Color.fromARGB(96, 21, 83, 87),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color.fromARGB(103, 173, 247, 210),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color.fromARGB(215, 226, 250, 239),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: const Color.fromARGB(255, 21, 83, 87),
                size: 22,
              ),
            ),
            const SizedBox(height: 12),
            Text(title, style: _featureTitleStyle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
