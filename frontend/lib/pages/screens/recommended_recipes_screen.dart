// ignore_for_file: sort_child_properties_last

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class RecommendedDishesScreen extends StatefulWidget {
  final String? speciesName;

  const RecommendedDishesScreen({super.key, this.speciesName});

  @override
  State<RecommendedDishesScreen> createState() => _RecommendedDishesScreenState();
}

class _RecommendedDishesScreenState extends State<RecommendedDishesScreen> {
  List<dynamic> _recipes = [];
  bool _loading = true;
  String? _error;

  static const Map<String, String> _filenameMap = {
    'caulerpa lentilifera': 'caulerpa_lentillifera_recipes.json',
    'caulerpa lentillifera': 'caulerpa_lentillifera_recipes.json',
    'caulerpa sertularioides': 'caulerpa_sertularioides_recipes.json',
    'kappaphycus': 'kappaphycus_alvarezii_recipes.json',
    'kappaphycus alvarezii': 'kappaphycus_alvarezii_recipes.json',
    'sargassum muticum': 'sargassum_muticum_recipes.json',
    'ulva lactuca': 'ulva_lactuca_recipes.json',
  };

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  String _normalize(String s) {
    return s.trim().toLowerCase();
  }

  Future<void> _loadRecipes() async {
    setState(() {
      _loading = true;
      _error = null;
      _recipes = [];
    });

    final species = _normalize(widget.speciesName ?? '');
    String? filename = _filenameMap[species];

    // fallback: try a simple generated filename
    if (filename == null && species.isNotEmpty) {
      final gen = species.replaceAll(RegExp(r'[^a-z0-9 ]'), '').replaceAll(' ', '_');
      filename = '${gen}_recipes.json';
    }

    if (filename == null || filename.isEmpty) {
      setState(() {
        _error = 'No species provided or mapping not found.';
        _loading = false;
      });
      return;
    }

    try {
      final jsonStr = await rootBundle.loadString('lib/assets/recipes/$filename');
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      final recipes = data['recipes'] as List<dynamic>? ?? [];
      setState(() {
        _recipes = recipes;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'No recipes found for "${widget.speciesName ?? 'this species'}".';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recommended Recipes', style: TextStyle(color: Color.fromARGB(255, 66, 66, 66), fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0C3A5D), Color(0xFF0B2537)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadRecipes,
              child: const Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0CA8B3)),
            )
          ],
        ),
      );
    }

    if (_recipes.isEmpty) {
      return const Center(
        child: Text('No recipes available.', style: TextStyle(color: Colors.white70)),
      );
    }

    return ListView.separated(
      itemCount: _recipes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _recipes[index] as Map<String, dynamic>;
        final title = item['title'] ?? 'Untitled';
        final description = item['description'] ?? '';

        return Card(
          color: const Color(0xFF142D40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            collapsedIconColor: Colors.white,
            iconColor: Colors.white,
            title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            subtitle: Text(description, style: const TextStyle(color: Colors.white70)),
            children: _buildExpandedContent(item),
          ),
        );
      },
    );
  }

  List<Widget> _buildExpandedContent(Map<String, dynamic> item) {
    final List<Widget> children = [];

    if (item.containsKey('ingredients')) {
      final ings = List<String>.from(item['ingredients'] ?? []);
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ingredients', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              ...ings.map((i) => Text('• $i', style: const TextStyle(color: Colors.white70))).toList(),
            ],
          ),
        ),
      );
    }

    if (item.containsKey('instructions')) {
      final instr = List<String>.from(item['instructions'] ?? []);
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Instructions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              ...instr.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• $s', style: const TextStyle(color: Colors.white70)),
                  )),
            ],
          ),
        ),
      );
    }

    return children;
  }
}
