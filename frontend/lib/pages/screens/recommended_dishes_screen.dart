import 'package:flutter/material.dart';

class RecommendedDishesScreen extends StatelessWidget {
  const RecommendedDishesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final thumbnails = List.generate(
      6,
      (index) => 'Recommended Dish ${index + 1}',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recommended Dishes'),
        backgroundColor: const Color(0xFF0CA8B3),
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
          padding: const EdgeInsets.all(6.0),
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.85,
            children: thumbnails.map((title) {
              return Card(
                color: const Color(0xFF142D40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                          color: Colors.white12,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_fill,
                            color: Color(0xFF0CA8B3),
                            size: 56,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
