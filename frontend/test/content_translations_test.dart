import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/pages/screens/seaweed_detail_screen.dart';
import 'package:frontend/services/app_language.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('species and recipe assets contain complete Filipino content', () async {
    await AppLanguage.instance.initialize();

    final species = jsonDecode(
      await rootBundle.loadString('lib/assets/philippine_seaweeds_50.json'),
    ) as List<dynamic>;
    expect(species, isNotEmpty);
    for (final entry in species.cast<Map<String, dynamic>>()) {
      final filipino = entry['filipino'] as Map<String, dynamic>;
      for (final field in [
        'description',
        'edible',
        'type',
        'found_in',
        'season',
        'habitat',
        'safety_notes',
        'identification_guide',
      ]) {
        expect(filipino[field], isA<String>(),
            reason: '${entry['common_name']}.$field');
        expect((filipino[field] as String).trim(), isNotEmpty);
      }
    }

    const recipeFiles = [
      'caulerpa_lentillifera_recipes.json',
      'caulerpa_sertularioides_recipes.json',
      'kappaphycus_alvarezii_recipes.json',
      'padina_australis.json',
      'sargassum_muticum_recipes.json',
      'turbinaria_ornata.json',
      'ulva_lactuca_recipes.json',
    ];

    for (final filename in recipeFiles) {
      final data = jsonDecode(
        await rootBundle.loadString('lib/assets/recipes/$filename'),
      ) as Map<String, dynamic>;
      final recipes = data['recipes'] as List<dynamic>;
      for (final entry in recipes.cast<Map<String, dynamic>>()) {
        final filipino = entry['filipino'] as Map<String, dynamic>;
        expect(filipino['title'], isA<String>(), reason: filename);
        expect(filipino['description'], isA<String>(), reason: filename);
        expect(filipino['ingredients'], hasLength(entry['ingredients'].length));
        expect(
            filipino['instructions'], hasLength(entry['instructions'].length));
        expect(
            (filipino['ingredients'] as List)
                .every((item) => item is String && item.trim().isNotEmpty),
            isTrue);
        expect(
            (filipino['instructions'] as List)
                .every((item) => item is String && item.trim().isNotEmpty),
            isTrue);
      }
    }
  });

  test('seaweed model resolves translated detail fields', () async {
    await AppLanguage.instance.initialize();
    final records = jsonDecode(
      await rootBundle.loadString('lib/assets/philippine_seaweeds_50.json'),
    ) as List<dynamic>;
    final seaweed = Seaweed.fromJson(records.first as Map<String, dynamic>);
    final filipinoDescription = seaweed.filipino['description'] as String;
    expect(seaweed.displayText('description', seaweed.description),
        seaweed.description);
    await AppLanguage.instance.toggleLanguage();

    expect(
      seaweed.displayText('description', seaweed.description),
      filipinoDescription,
    );
    expect(seaweed.displayText('type', seaweed.type), 'Algang Luntian');
    expect(seaweed.displayText('edible', seaweed.edible), 'Nakakain');
  });

  test('recipe content has Filipino title, description, ingredients and steps',
      () async {
    await AppLanguage.instance.initialize();
    await AppLanguage.instance.toggleLanguage();

    final data = jsonDecode(
      await rootBundle.loadString(
        'lib/assets/recipes/caulerpa_lentillifera_recipes.json',
      ),
    ) as Map<String, dynamic>;
    final recipe =
        (data['recipes'] as List<dynamic>).first as Map<String, dynamic>;
    final filipino = recipe['filipino'] as Map<String, dynamic>;

    expect(filipino['title'],
        'Klasikong Filipino Ensaladang Lato (Salad ng Seaweed)');
    expect(
      filipino['description'],
      'Klasikong ulam na ipinapares ang malutong na lato sa hiniwang kamatis at sibuyas, at opsyonal na itlog na maalat.',
    );
    expect(
      (filipino['ingredients'] as List).first,
      '250 g sariwang Caulerpa lentillifera (lato)',
    );
    expect(
      (filipino['instructions'] as List).first,
      startsWith('Ilagay ang sariwang lato sa mangkok ng malamig na tubig.'),
    );
  });

  test('cleaning step translations are available', () async {
    await AppLanguage.instance.initialize();
    await AppLanguage.instance.toggleLanguage();

    expect(
      appText(
        'result_screen.dart',
        'Pick and Sort: Look through the green grape-like clusters and pull out small rocks, tiny shells, or bits of other plants.',
      ),
      'Pumili at Mag-ayos: Suriin ang mga kumpol na berdeng kahawig ng ubas at alisin ang maliliit na bato, kabibe, o piraso ng ibang halaman.',
    );
    expect(
      appText(
        'result_screen.dart',
        'Desalinate and Drain: Shake off the excess water and let it drain. The cleaned seaweed is now ready to be eaten fresh, pickled, or added to your favorite dishes.',
      ),
      'Bawasan ang Alat at Patuluin: Alugin upang maalis ang sobrang tubig at hayaang tumulo ang natitira. Maaari na itong kainin nang sariwa, atsarahin, o idagdag sa paborito mong putahe.',
    );
  });
}
