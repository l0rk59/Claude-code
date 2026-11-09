import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart' show Locale;
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'fr.dart';

/// UI translations.
///
/// The English text is the key: `'Settings'.tr` shows "Paramètres" in
/// French and falls back to "Settings" when a translation is missing.
/// Text with values uses `@name` placeholders:
/// `'Version @version'.trParams({'version': v})`.
///
/// Logs, API payloads and prompts sent to models stay in English.
class AppTranslations extends Translations {
  static const english = Locale('en', 'US');
  static const french = Locale('fr', 'FR');

  static const supportedLocales = [english, french];

  /// Saved language choices: follow the phone, or a fixed language.
  static const system = 'system';
  static const languageCodes = [system, 'en', 'fr'];

  @override
  Map<String, Map<String, String>> get keys => {'fr_FR': fr};

  /// The locale for a saved language choice ('system', 'en' or 'fr').
  static Locale localeFor(String language) {
    final code = language == system
        ? PlatformDispatcher.instance.locale.languageCode
        : language;
    return code == 'fr' ? french : english;
  }

  /// Switches the app to [language] and its date formats.
  static Future<void> apply(String language) async {
    final locale = localeFor(language);
    Intl.defaultLocale = locale.toString();
    if (Get.locale != locale) await Get.updateLocale(locale);
  }
}
