import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:privatelm/l10n/app_translations.dart';

void main() {
  tearDown(() {
    Get.locale = null;
    Intl.defaultLocale = null;
  });

  Widget app(Locale locale) => GetMaterialApp(
        translations: AppTranslations(),
        locale: locale,
        fallbackLocale: AppTranslations.english,
        supportedLocales: AppTranslations.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Column(children: [
            Text('Settings'.tr),
            Text('@size GB'.trParams({'size': '1.5'})),
            Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ]),
        ),
      );

  testWidgets('shows French and switches back to English', (tester) async {
    await tester.pumpWidget(app(AppTranslations.french));
    expect(find.text('Paramètres'), findsOneWidget);
    expect(find.text('1.5 Go'), findsOneWidget);
    // Flutter's own widgets follow the app language too.
    expect(find.text('Annuler'), findsOneWidget);

    await _apply(tester, 'en');
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('1.5 GB'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('formats dates in French', (tester) async {
    await tester.pumpWidget(app(AppTranslations.french));
    await _apply(tester, 'fr');
    expect(DateFormat.yMMMd().format(DateTime(2026, 11, 9)), '9 nov. 2026');
  });

  test('picks the language for each saved choice', () {
    expect(AppTranslations.localeFor('fr'), AppTranslations.french);
    expect(AppTranslations.localeFor('en'), AppTranslations.english);
  });

  testWidgets('follows the phone language for "system"', (tester) async {
    tester.platformDispatcher.localeTestValue = const Locale('fr', 'CA');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    expect(AppTranslations.localeFor(AppTranslations.system),
        AppTranslations.french);

    tester.platformDispatcher.localeTestValue = const Locale('de', 'DE');
    expect(AppTranslations.localeFor(AppTranslations.system),
        AppTranslations.english);
  });
}

/// Switches language. The switch rebuilds the app and waits for that frame,
/// so pump while it runs.
Future<void> _apply(WidgetTester tester, String language) async {
  final done = AppTranslations.apply(language);
  await tester.pumpAndSettle();
  await done;
}
