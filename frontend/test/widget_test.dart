import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/widgets/navigation.dart';

void main() {
  testWidgets('camera nav item uses the same scale animation as other icons',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BottomNavigation(
            currentIndex: 0,
            onTabChanged: (_) {},
          ),
        ),
      ),
    );

    final cameraIcon = find.byWidgetPredicate(
      (widget) => widget is Icon && widget.icon == Icons.camera_alt_rounded,
    );

    expect(cameraIcon, findsOneWidget);
    expect(
      find.ancestor(of: cameraIcon, matching: find.byType(AnimatedScale)),
      findsOneWidget,
    );
  });
}
