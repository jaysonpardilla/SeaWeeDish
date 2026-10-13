import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/pages/screens/history_screen.dart';
import 'package:frontend/services/app_language.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('history filter chips follow the selected language',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppLanguage.instance.initialize();

    await tester.pumpWidget(
      const MaterialApp(home: HistoryScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Edible'), findsOneWidget);
    expect(find.text('Not edible'), findsOneWidget);
    expect(find.text('Unidentified'), findsOneWidget);

    await AppLanguage.instance.toggleLanguage();
    await tester.pumpAndSettle();

    expect(find.text('Lahat'), findsOneWidget);
    expect(find.text('Nakakain'), findsOneWidget);
    expect(find.text('Hindi Nakakain'), findsOneWidget);
    expect(find.text('Hindi Natukoy'), findsOneWidget);
    expect(find.text('All'), findsNothing);
    expect(find.text('Edible'), findsNothing);
    expect(find.text('Not edible'), findsNothing);
    expect(find.text('Unidentified'), findsNothing);
  });
}