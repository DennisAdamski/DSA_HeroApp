import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/schaden_protokoll.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/schaden_ruecknahme_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/schaden_rules.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_dice_log_section.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/schaden/schaden_ruecknahme.dart';

const _held = HeroSheet(
  id: 'demo',
  name: 'Rondra',
  level: 1,
  attributes: Attributes(
    mu: 12,
    kl: 12,
    inn: 12,
    ch: 12,
    ff: 12,
    ge: 12,
    ko: 12,
    kk: 12,
  ),
);

const _leererKatalog = RulesCatalog(
  version: 'test_catalog',
  source: 'test',
  talents: <TalentDef>[],
  spells: <SpellDef>[],
  weapons: <WeaponDef>[],
);

final _zeit = DateTime.utc(2026, 10, 7, 12);

Finder _key(String schluessel) => find.byKey(ValueKey<String>(schluessel));

/// Zustand nach einem Brusttreffer (15 SP, 1 Wunde) wie vom Ablauf gebucht,
/// davor ein alter Schadenseintrag ohne Buchung.
HeroState _getroffen() {
  const vorher = HeroState(
    currentLep: 30,
    currentAsp: 0,
    currentKap: 0,
    currentAu: 20,
  );
  final buchung = SchadensBuchung(
    art: SchadensArt.lebensenergie,
    tp: 15,
    rs: 0,
    zone: WundZone.brust,
    wunden: 1,
  );
  final anwendung = wendeSchadenAn(vorher, buchung);
  final alt = diceLogEntryFromRoll(
    title: schadenProtokollTitel,
    subtitle: 'alter Eintrag',
    diceValues: const <int>[],
    total: 3,
    timestamp: _zeit,
  );
  return anwendung.zustand
      .withBuchung(
        schadensBuchungAus(
          vorher: vorher,
          anwendung: anwendung,
          buchung: buchung,
          id: 'treffer',
          zeitpunkt: _zeit,
        ),
      )
      .withAppendedDiceLogEntries(<DiceLogEntry>[
        alt,
        baueSchadensProtokoll(
          buchung: buchung,
          hinzugefuegteWunden: 1,
          zeitpunkt: _zeit,
          buchungId: 'treffer',
        ),
      ]);
}

class _Repository extends FakeRepository {
  _Repository(HeroState zustand, {this.fehler = false})
    : super(heroes: [_held], states: {'demo': zustand});

  bool fehler;

  @override
  Future<void> saveHeroState(String heroId, HeroState state) async {
    if (fehler) {
      throw StateError('Schreibfehler');
    }
    await super.saveHeroState(heroId, state);
  }
}

Future<void> _zeige(WidgetTester tester, FakeRepository repo) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1200, 2400);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        heroRepositoryProvider.overrideWithValue(repo),
        rulesCatalogProvider.overrideWith((ref) async => _leererKatalog),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Consumer(
              builder: (context, ref, _) {
                final zustand = ref
                    .watch(heroStateProvider('demo'))
                    .valueOrNull;
                if (zustand == null) {
                  return const SizedBox.shrink();
                }
                return InspectorDiceLogSection(
                  entries: zustand.diceLog,
                  aktion: (eintrag) => schadenRuecknahmeAktion(
                    eintrag: eintrag,
                    heroId: 'demo',
                    zustand: zustand,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('nur eine gebuchte Schadensbuchung bekommt „Zurücknehmen“', (
    tester,
  ) async {
    await _zeige(tester, _Repository(_getroffen()));

    expect(find.text('Zurücknehmen'), findsOneWidget);
    expect(_key('dice-log-ruecknahme-treffer'), findsOneWidget);
  });

  testWidgets('die Rückfrage zeigt den Plan, Bestätigen nimmt zurück', (
    tester,
  ) async {
    final repo = _Repository(_getroffen());
    await _zeige(tester, repo);

    await tester.tap(_key('dice-log-ruecknahme-treffer'));
    await tester.pumpAndSettle();
    expect(_key('schaden-ruecknahme-dialog'), findsOneWidget);
    expect(find.text('LeP: 15 → 30'), findsOneWidget);
    expect(find.text('Wunden Brust: 1 → 0'), findsOneWidget);

    await tester.tap(_key('schaden-ruecknahme-bestaetigen'));
    await tester.pumpAndSettle();

    expect(_key('schaden-ruecknahme-dialog'), findsNothing);
    final zustand = (await repo.loadHeroState('demo'))!;
    expect(zustand.currentLep, 30);
    expect(zustand.wpiZustand.wundenInZone(WundZone.brust), 0);
    expect(
      schadensBuchungsStatus(zustand, 'treffer'),
      SchadensBuchungsStatus.zurueckgenommen,
    );
    expect(_key('dice-log-ruecknahme-treffer'), findsNothing);
    expect(_key('dice-log-zurueckgenommen-treffer'), findsOneWidget);
    expect(find.text(schadenRuecknahmeProtokollTitel), findsOneWidget);
    // Die Rücknahme selbst ist nicht zurücknehmbar.
    expect(find.text('Zurücknehmen'), findsNothing);
  });

  testWidgets('über dem Maximum weist die Rückfrage darauf hin', (
    tester,
  ) async {
    final geheilt = _getroffen().copyWith(currentLep: 30);
    await _zeige(tester, _Repository(geheilt));

    await tester.tap(_key('dice-log-ruecknahme-treffer'));
    await tester.pumpAndSettle();

    expect(find.text('LeP: 30 → 45'), findsOneWidget);
    expect(find.textContaining('über dem Maximum'), findsOneWidget);
  });

  testWidgets('ein Speicherfehler erscheint in der Rückfrage', (tester) async {
    final repo = _Repository(_getroffen(), fehler: true);
    await _zeige(tester, repo);

    await tester.tap(_key('dice-log-ruecknahme-treffer'));
    await tester.pumpAndSettle();
    await tester.tap(_key('schaden-ruecknahme-bestaetigen'));
    await tester.pumpAndSettle();

    expect(_key('schaden-ruecknahme-dialog'), findsOneWidget);
    expect(
      find.text('Rücknahme nicht gespeichert: Schreibfehler'),
      findsOneWidget,
    );

    repo.fehler = false;
    await tester.tap(_key('schaden-ruecknahme-bestaetigen'));
    await tester.pumpAndSettle();
    expect(_key('schaden-ruecknahme-dialog'), findsNothing);
    expect((await repo.loadHeroState('demo'))!.currentLep, 30);
  });
}
