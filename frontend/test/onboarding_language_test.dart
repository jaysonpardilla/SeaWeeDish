import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/pages/screens/onboarding_screen.dart';
import 'package:frontend/services/app_language.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onboarding language button updates translated text',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppLanguage.instance.initialize();

    await tester.pumpWidget(
      const MaterialApp(home: OnboardingScreen()),
    );

    expect(find.text('ENG'), findsOneWidget);
    expect(find.text('FIL'), findsOneWidget);
    expect(find.text('Discover. Identify. Thrive.'), findsOneWidget);
    await tester.tap(find.text('ENG'));
    await tester.pumpAndSettle();

    expect(find.text('FIL'), findsOneWidget);
    expect(find.text('Tumuklas. Kumilala. Umunlad.'), findsOneWidget);
    expect(find.text('Discover. Identify. Thrive.'), findsNothing);

    await tester.tap(find.text('FIL'));
    await tester.pumpAndSettle();

    expect(find.text('ENG'), findsOneWidget);
    expect(find.text('Discover. Identify. Thrive.'), findsOneWidget);
    expect(find.text('Tumuklas. Kumilala. Umunlad.'), findsNothing);
  });
}
