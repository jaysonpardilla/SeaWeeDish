import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/widgets.dart';

class AppLanguage extends ChangeNotifier {
  AppLanguage._();

  static final AppLanguage instance = AppLanguage._();

  static const _dictionaryAsset = 'lib/assets/app_translations.json';
  static const _preferenceKey = 'is_filipino_language';

  Map<String, dynamic> _dictionary = {};
  bool _isFilipino = false;

  bool get isFilipino => _isFilipino;

  Future<void> initialize() async {
    final dictionaryJson = await rootBundle.loadString(_dictionaryAsset);
    final decoded = jsonDecode(dictionaryJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Translation dictionary must be a JSON object.');
    }
    _dictionary = decoded;

    final preferences = await SharedPreferences.getInstance();
    _isFilipino = preferences.getBool(_preferenceKey) ?? false;
  }

  String translate(String pageId, String englishText) {
    final page = _dictionary[pageId];
    if (page is! Map<String, dynamic>) return englishText;

    final translation = page[englishText];
    if (translation is! Map<String, dynamic>) return englishText;

    final languageKey = _isFilipino ? 'filipino' : 'english';
    return translation[languageKey] as String? ?? englishText;
  }

  Future<void> toggleLanguage() async {
    final nextLanguage = !_isFilipino;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_preferenceKey, nextLanguage);
    _isFilipino = nextLanguage;
    notifyListeners();
  }
}

String appText(String pageId, String englishText) =>
    AppLanguage.instance.translate(pageId, englishText);

mixin AppLanguageAwareStateMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    AppLanguage.instance.addListener(_handleLanguageChanged);
  }

  @override
  void dispose() {
    AppLanguage.instance.removeListener(_handleLanguageChanged);
    super.dispose();
  }

  void _handleLanguageChanged() {
    if (mounted) setState(() {});
  }
}
