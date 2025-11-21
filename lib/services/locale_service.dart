import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService extends ChangeNotifier {
  static const String _localeKey = 'selected_language_code';
  Locale _locale = const Locale('en', '');

  LocaleService() {
    _loadLocale();
  }

  Locale get locale => _locale;

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_localeKey) ?? 'en';
    _locale = Locale(languageCode, '');
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    
    _locale = locale;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
  }

  Future<void> setLocaleFromLanguageCode(String languageCode) async {
    await setLocale(Locale(languageCode, ''));
  }

  bool isRTL() {
    return _locale.languageCode == 'ar';
  }

  String getLanguageName() {
    switch (_locale.languageCode) {
      case 'ar':
        return 'العربية';
      case 'es':
        return 'Español';
      case 'en':
      default:
        return 'English';
    }
  }

  TextDirection getTextDirection() {
    return isRTL() ? TextDirection.rtl : TextDirection.ltr;
  }

  String? getFontFamily() {
    return _locale.languageCode == 'ar' ? 'Arabic' : null;
  }
}

