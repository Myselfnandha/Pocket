import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket/l10n/generated/app_localizations.dart';

void main() {
  group('Pocket Internationalization & Localization Tests', () {
    testWidgets('AppLocalizations loads English strings correctly', (tester) async {
      late AppLocalizations localizations;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              localizations = AppLocalizations.of(context)!;
              return Scaffold(
                body: Text(localizations.totalNetPosition),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(localizations.appTitle, equals('Pocket'));
      expect(localizations.totalNetPosition, equals('TOTAL NET POSITION'));
      expect(localizations.quickAdd, equals('Quick Add'));
      expect(localizations.analytics, equals('Analytics'));
      expect(localizations.wallets, equals('Wallets'));
      expect(localizations.settings, equals('Settings'));

      expect(find.text('TOTAL NET POSITION'), findsOneWidget);
    });
  });
}
