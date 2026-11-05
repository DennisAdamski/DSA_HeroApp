import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/feiertag_loader.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/aventurian_holiday_rules.dart';
import 'package:dsa_heldenverwaltung/state/feiertag_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abenteuer_dialoge.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

Finder _key(String name) => find.byKey(ValueKey<String>(name));

// Die eingecheckte Katalogdatei; rootBundle lädt in der FakeAsync-Zone nicht.
final FeiertagKatalog _katalog = parseFeiertage(
  jsonDecode(File(feiertageAssetPfad).readAsStringSync()) as List<dynamic>,
);

void main() {
  late HeroAdventureDateValue? ergebnis;
  late List<Uri> geoeffnet;

  Future<void> zeige(
    WidgetTester tester, {
    HeroAdventureDateValue initial = const HeroAdventureDateValue(),
    bool linkGelingt = true,
    double skalierung = 1,
  }) async {
    ergebnis = null;
    geoeffnet = [];
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          feiertagKatalogProvider.overrideWith((ref) async => _katalog),
        ],
        child: MaterialApp(
          theme: buildKartoTheme(
            brightness: Brightness.light,
            centerAppBarTitle: false,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(skalierung)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  ergebnis = await showDialog<HeroAdventureDateValue>(
                    context: context,
                    builder: (_) => KartoDatumDialog(
                      initial: initial,
                      oeffneLink: (uri) async {
                        geoeffnet.add(uri);
                        return linkGelingt;
                      },
                    ),
                  );
                },
                child: const Text('öffnen'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('öffnen'));
    await tester.pumpAndSettle();
  }

  Future<void> waehleMonat(WidgetTester tester, String label) async {
    await tester.tap(_key('karto-abenteuer-monat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('ohne Datum steht ein Hinweis statt Feiertage', (tester) async {
    await zeige(tester);
    expect(
      find.text('Tag und Monat wählen, um Feiertage zu sehen.'),
      findsOneWidget,
    );
    expect(_key('karto-datum-feiertag-0'), findsNothing);
    expect(_key('karto-datum-feiertage-wiki'), findsOneWidget);
  });

  testWidgets('zeigt Feiertage zum gewählten Tag und folgt der Eingabe', (
    tester,
  ) async {
    await zeige(tester);
    await tester.enterText(_key('karto-abenteuer-tag'), '4');
    await waehleMonat(tester, 'Rondra');

    expect(find.textContaining('Tag des Schwures'), findsOneWidget);
    expect(find.text('morgen'), findsOneWidget);
    expect(find.text('5. Rondra · Tag des Schwures'), findsOneWidget);
    expect(find.text('Rondra · zwölfgöttergläubige Lande'), findsWidgets);
    expect(
      find.textContaining('Nationalfeiertag im Mittelreich'),
      findsOneWidget,
    );

    // Ein anderer Tag ändert die Liste sofort.
    await tester.enterText(_key('karto-abenteuer-tag'), '22');
    await tester.pump();
    expect(find.textContaining('Tag des Schwures'), findsNothing);
    expect(find.textContaining('Maraskanisches Neujahrsfest'), findsOneWidget);
  });

  testWidgets('vorbelegtes Datum zeigt sofort Feiertage', (tester) async {
    await zeige(
      tester,
      initial: const HeroAdventureDateValue(
        day: '5',
        month: 'rondra',
        year: '1043',
      ),
    );
    expect(find.text('heute'), findsOneWidget);
    expect(find.text('5. Rondra · Tag des Schwures'), findsOneWidget);
  });

  testWidgets('ohne Feiertag im Fenster steht ein Hinweis', (tester) async {
    // Rund um den 15. Praios liegt weder in den 7 Tagen davor noch in den 14
    // danach ein Fest (1.–3. Praios, dann erst der 5. Rondra).
    await zeige(
      tester,
      initial: const HeroAdventureDateValue(day: '15', month: 'praios'),
    );
    expect(find.text('Keine Feiertage in der Nähe.'), findsOneWidget);
  });

  testWidgets('Speichern liefert das Datum unverändert zurück', (tester) async {
    await zeige(tester);
    await tester.enterText(_key('karto-abenteuer-tag'), '12');
    await waehleMonat(tester, 'Phex');
    await tester.enterText(_key('karto-abenteuer-jahr'), '1043');
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();

    expect(ergebnis?.day, '12');
    expect(ergebnis?.month, 'phex');
    expect(ergebnis?.year, '1043');
  });

  testWidgets('der Wiki-Link öffnet die Feiertagsliste', (tester) async {
    await zeige(tester);
    await tester.tap(_key('karto-datum-feiertage-wiki'));
    await tester.pumpAndSettle();

    expect(geoeffnet, [Uri.parse(feiertagWikiListeUrl)]);
    expect(find.text('Der Link konnte nicht geöffnet werden.'), findsNothing);
  });

  testWidgets('ein fehlgeschlagener Link meldet es', (tester) async {
    await zeige(tester, linkGelingt: false);
    await tester.tap(_key('karto-datum-feiertage-wiki'));
    await tester.pumpAndSettle();

    expect(find.text('Der Link konnte nicht geöffnet werden.'), findsOneWidget);
  });

  testWidgets('bleibt bei großer Schrift und vielen Treffern bedienbar', (
    tester,
  ) async {
    await zeige(
      tester,
      initial: const HeroAdventureDateValue(day: '8', month: 'rondra'),
      skalierung: 2,
    );
    expect(tester.takeException(), isNull);
    // Der Link liegt unter der Liste und ist erreichbar.
    await tester.ensureVisible(_key('karto-datum-feiertage-wiki'));
    await tester.pump();
    expect(_key('karto-datum-feiertage-wiki'), findsOneWidget);
  });
}
