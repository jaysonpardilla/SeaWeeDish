// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class SafetyTipsScreen extends StatelessWidget {
  const SafetyTipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryGreen = const Color(0xFF005E4D);
    final softBackground = const Color.fromARGB(255, 255, 255, 255);

    return Scaffold(
      backgroundColor: softBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 16,
            color: Color(0xFF005E4D),
          ),
          onPressed: () => Navigator.pop(context),
          splashRadius: 18,
        ),
        title: const Text(
          'Safety & Sustainability Guide',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF005E4D),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF005E4D),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: ListView(
            children: [
              const Text(
                'Essential practices for safe consumption, ecosystem preservation, and responsible harvesting.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF385E59),
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 20),

              _buildInfoCard(
                title: '⚠️ Water Quality & Marine Hazards',
                accentColor: const Color.fromARGB(255, 255, 239, 231),
                iconBg: const Color(0xFFF5B7A0),
                icon: Icons.warning_amber_rounded,
                items: [
                  _buildTipItem(
                    title: 'Red Tide & Harmful Algal Blooms (HABs)',
                    description:
                        'Never harvest seaweed during active Red Tide alerts or HAB advisories. Microscopic toxins settle on fronds and cannot be washed or cooked out.',
                  ),
                  _buildTipItem(
                    title: 'Contaminated Waters & Runoff',
                    description:
                        'Avoid harvesting near industrial ports, agricultural runoff sites, stormwater outlets, or heavy maritime traffic to prevent heavy metal ingestion.',
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _buildInfoCard(
                title: '🌱 Sustainable Harvesting Protocol',
                accentColor: const Color.fromARGB(255, 255, 248, 238),
                iconBg: const Color(0xFFB9E4C5),
                icon: Icons.eco_rounded,
                items: [
                  _buildTipItem(
                    title: 'The 30% Rule',
                    description:
                        'Harvest only up to 1/3 of a single patch. Always leave enough biomass to ensure local marine flora continues to thrive.',
                  ),
                  _buildTipItem(
                    title: 'Protect the Holdfast',
                    description:
                        'Always use clean shears or a knife to cut fronds above the base (holdfast). Never rip plants off rocks—leaving the root-like base allows the seaweed to regenerate.',
                  ),
                  _buildTipItem(
                    title: 'Respect Protected Marine Areas',
                    description:
                        'Verify local coastal laws and ensure you are not harvesting in marine sanctuaries, marine protected areas, or private properties.',
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _buildInfoCard(
                title: '🧼 Handling & Preparation',
                accentColor: const Color.fromARGB(255, 234, 243, 251),
                iconBg: const Color(0xFFB8D9F8),
                icon: Icons.water_drop_rounded,
                items: [
                  _buildTipItem(
                    title: 'Potable Water Rinsing',
                    description:
                        'Thoroughly soak and wash wild seaweed multiple times in clean, running tap water to remove sand, epiphytes, and debris.',
                  ),
                  _buildTipItem(
                    title: 'Cold Storage & Immediate Prep',
                    description:
                        'Freshly harvested seaweed degrades quickly. Keep it chilled and consume within 24–48 hours for optimal safety and texture.',
                  ),
                  _buildTipItem(
                    title: 'Health & Iodine Awareness',
                    description:
                        'Consuming large amounts of marine algae introduces high levels of iodine. Individuals with thyroid conditions or seafood allergies should consume in moderation.',
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _buildInfoCard(
                title: '🛡️ Intertidal Hazards & First Aid',
                accentColor: const Color(0xFFEAECEF),
                iconBg: const Color(0xFFBFCFD3),
                icon: Icons.shield_rounded,
                items: [
                  _buildTipItem(
                    title: 'Marine Contact Hazards',
                    description:
                        'Watch out for stinging organism hitchhikers (jellyfish, fire corals, hydroids) or sea urchins living amongst seaweed fronds in shallow reef waters.',
                  ),
                  _buildTipItem(
                    title: 'Recommended Gear',
                    description:
                        'Always wear protective rubber-soled water shoes or reef boots and protective gloves when harvesting along sharp rocks or coral beds.',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required Color accentColor,
    required Color iconBg,
    required IconData icon,
    required List<Widget> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF005E4D), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF005E4D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...items,
        ],
      ),
    );
  }

  Widget _buildTipItem({
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF123E35),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.justify,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF365C57),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
