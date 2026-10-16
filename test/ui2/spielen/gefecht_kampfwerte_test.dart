import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_ansicht.dart';

import '../../rules/gefecht_meisterparade_rules_test.dart' as mp;
import 'gefecht_test_support.dart';

const _katalog = RulesCatalog(
  version: 'test',
  source: 'test',
  talents: [],
  spells: [],
  weapons: [],
  maneuvers: [],
);

Future<ProviderContainer> _starte(
  WidgetTester tester, {
  required Size groesse,
  int wurf = 6,
  int ansageFolgemalus = 0,
}) async {
  tester.view.physicalSize = groesse;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      heroComputedProvider('rondra')
          .overrideWith((ref) => AsyncData(mp.mpSnapshot())),
      rulesCatalogProvider.overrideWith((ref) async => _katalog),
    ],
  );
  addTearDown(container.dispose);
  final ctl = container.read(gefechtProvider('rondra').notifier)
    ..beginnen(wurf);
  ctl.setzen(
    container
        .read(gefechtProvider('rondra'))!
        .copyWith(
          dk: 'N',
          ansageFolgemalus: ansageFolgemalus,
          kontext: const Gefechtskontext(
            angriffsart: Gefechtsangriffsart.nahkampf,
            finte: 0,
            schildWmWirksam: true,
            situationsZuschlag: 0,
          ),
        ),
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: GefechtAnsicht(heroId: 'rondra', bestand: GefechtsTestBestand()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Finder _kachel(String id) => find.byKey(ValueKey('gefecht-kampfwert-$id'));

void main() {
  testWidgets('Kampfwerte stehen sichtbar in der Gefechtsansicht', (
    tester,
  ) async {
    await _starte(tester, groesse: const Size(1200, 1400));
    expect(find.byKey(const ValueKey('gefecht-kampfwerte')), findsOneWidget);
    for (final id in ['ini', 'at', 'pa', 'aw', 'rs', 'be']) {
      expect(_kachel(id), findsOneWidget, reason: id);
    }
  });

  testWidgets('Antippen zeigt die Herleitung als Dialog (breit)', (
    tester,
  ) async {
    await _starte(tester, groesse: const Size(1200, 1400));
    await tester.tap(_kachel('ini'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('INI-Wurf (Sitzung)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('gefecht-kampfwert-blatt')),
      findsOneWidget,
    );
  });

  testWidgets('Antippen zeigt die Herleitung als Blatt (schmal)', (
    tester,
  ) async {
    await _starte(tester, groesse: const Size(400, 1400));
    await tester.ensureVisible(_kachel('pa'));
    await tester.tap(_kachel('pa'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.byKey(const ValueKey('gefecht-kampfwert-blatt')),
      findsOneWidget,
    );
  });

  testWidgets('Aktuelle Erschwernis erscheint als Zielwert und im Blatt', (
    tester,
  ) async {
    await _starte(tester, groesse: const Size(1200, 1400), ansageFolgemalus: 3);
    expect(
      find.byKey(const ValueKey('gefecht-kampfwert-at-aktuell')),
      findsOneWidget,
    );
    await tester.tap(_kachel('at'));
    await tester.pumpAndSettle();
    expect(find.text('Aktuell im Gefecht'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('gefecht-kampfwert-zielwert')),
      findsOneWidget,
    );
    expect(find.text('Ansagefolgemalus'), findsWidgets);
  });

  testWidgets('INI-Verlust ändert die angezeigte INI', (tester) async {
    final container = await _starte(
      tester,
      groesse: const Size(1200, 1400),
      wurf: 10,
    );
    String ini() => tester
        .widgetList<Text>(
          find.descendant(of: _kachel('ini'), matching: find.byType(Text)),
        )
        .map((t) => t.data)
        .whereType<String>()
        .firstWhere((t) => int.tryParse(t) != null);
    final vorher = int.parse(ini());
    container
        .read(gefechtProvider('rondra').notifier)
        .setzen(
          container.read(gefechtProvider('rondra'))!.copyWith(iniVerlust: 4),
        );
    await tester.pumpAndSettle();
    expect(int.parse(ini()), vorher - 4);
  });
}
