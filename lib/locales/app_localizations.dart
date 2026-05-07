import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { en, am }

class AppLocalizations {
  static Map<String, dynamic> _translations = {};
  static Map<String, dynamic> _fallbackTranslations = {};
  static AppLanguage _currentLanguage = AppLanguage.en;
  
  static const String _prefKey = 'app_language';
  static const String _assetPath = 'assets/locales';

  static Future<void> load(AppLanguage language) async {
    try {
      // Always load English as fallback
      final String enJsonString = await rootBundle.loadString('$_assetPath/en.json');
      _fallbackTranslations = json.decode(enJsonString);

      if (language == AppLanguage.en) {
        _translations = _fallbackTranslations;
      } else {
        final String jsonString = await rootBundle.loadString('$_assetPath/${language.name}.json');
        _translations = json.decode(jsonString);
      }
      
      _currentLanguage = language;
      
      // Save the selected language
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, language.name);
    } catch (e) {
      print('Error loading translations for ${language.name}: $e');
      _translations = _fallbackTranslations;
      _currentLanguage = AppLanguage.en;
    }
  }

  static Future<AppLanguage> getSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLang = prefs.getString(_prefKey);
      if (savedLang != null) {
        return AppLanguage.values.firstWhere(
          (e) => e.name == savedLang,
          orElse: () => AppLanguage.en,
        );
      }
    } catch (e) {
      print('Error reading saved language: $e');
    }
    return AppLanguage.en;
  }
  
  static String get(String key) {
    final keys = key.split('.');
    
    // First try the current language
    dynamic value = _translations;
    bool found = true;
    for (final k in keys) {
      if (value is Map<String, dynamic> && value.containsKey(k)) {
        value = value[k];
      } else {
        found = false;
        break;
      }
    }
    
    if (found) return value.toString();

    // Fallback to English
    value = _fallbackTranslations;
    found = true;
    for (final k in keys) {
      if (value is Map<String, dynamic> && value.containsKey(k)) {
        value = value[k];
      } else {
        found = false;
        break;
      }
    }
    
    if (found) return value.toString();
    
    return key; // Return key if translation not found anywhere
  }
  
  static String format(String key, {Map<String, String>? replacements}) {
    String result = get(key);
    
    if (replacements != null) {
      replacements.forEach((placeholder, replacement) {
        result = result.replaceAll('{$placeholder}', replacement);
      });
    }
    
    return result;
  }
  
  static AppLanguage get currentLanguage => _currentLanguage;
  
  static String getLanguageDisplayName(AppLanguage language) {
    switch (language) {
      case AppLanguage.en:
        return 'English';
      case AppLanguage.am:
        return 'አማርኛ';
    }
  }
}

class LanguageNotifier extends Notifier<AppLanguage> {
  @override
  AppLanguage build() {
    return AppLocalizations.currentLanguage;
  }
  
  Future<void> changeLanguage(AppLanguage language) async {
    await AppLocalizations.load(language);
    state = language;
  }
}

final languageProvider = NotifierProvider<LanguageNotifier, AppLanguage>(LanguageNotifier.new);

// Extension for easy access to translations
extension AppLocalizationsExtension on WidgetRef {
  String t(String key, {Map<String, String>? replacements}) {
    if (replacements != null) {
      return AppLocalizations.format(key, replacements: replacements);
    }
    return AppLocalizations.get(key);
  }
}
