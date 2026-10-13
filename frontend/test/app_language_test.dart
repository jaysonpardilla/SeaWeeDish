import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/services/app_language.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loads translations, switches languages, and persists the selection',
      () async {
    final language = AppLanguage.instance;
    await language.initialize();

    expect(
      language.translate(
        'onboarding_screen.dart',
        'Discover. Identify. Thrive.',
      ),
      'Discover. Identify. Thrive.',
    );

    await language.toggleLanguage();

    expect(language.isFilipino, isTrue);
    expect(
      language.translate(
        'onboarding_screen.dart',
        'Discover. Identify. Thrive.',
      ),
      'Tumuklas. Kumilala. Umunlad.',
    );

    await language.initialize();
    expect(language.isFilipino, isTrue);

    await language.toggleLanguage();
    expect(language.isFilipino, isFalse);
  });
}
