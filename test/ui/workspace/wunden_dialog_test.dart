import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/house_rules/house_rule_registry.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/house_rules_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/probe_quick_search.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/wunden_detail_dialog.dart';

// Wunden nach Gesamt- und Zonensystem in der Oberfläche (ARCH-05 (6)).
const _attribute = Attributes(
  mu: 12,
  kl: 12,
  inn: 12,
  ch: 12,
  ff: 12,
  ge: 12,
  ko: 12,
  kk: 12,
);

const _held = HeroSheet(
  id: 'demo',
  name: 'Rondra',
  level: 1,
  attributes: _attribute,
  talents: <String, HeroTalentEntry>{
    'tal_selbstbeherrschung': HeroTalentEntry(talentValue: 7),
    'tal_menschenkenntnis': HeroTalentEntry(talentValue: 5),
  },
);

// Eine Kopfwunde (INI-Wurf 7) und eine Wunde am linken Arm.
const _zustand = HeroState(
  currentLep: 30,
  currentAsp: 0,
  currentKap: 0,
  currentAu: 20,
  wpiZustand: WundZustand(
    wundenProZone: <WundZone, int>{WundZone.kopf: 1, WundZone.linkerArm: 1},
    kopfIniMalus: 7,
  ),
);

const _katalog = RulesCatalog(
  version: 'test_catalog',
  source: 'test',
  talents: <TalentDef>[
    TalentDef(
      id: 'tal_menschenkenntnis',
      name: 'Menschenkenntnis',
      group: 'Gesellschaft',
      steigerung: 'C',
      attributes: <String>['KL', 'IN', 'CH'],
    ),
    TalentDef(
      id: 'tal_selbstbeherrschung',
      name: 'Selbstbeherrschung',
      group: 'Körperlich',
      steigerung: 'D',
      attributes: <String>['MU', 'KO', 'KK'],
    ),
  ],
  spells: <SpellDef>[],
  weapons: <WeaponDef>[],
);

Finder _key(String schluessel) => find.byKey(ValueKey<String>(schluessel));

void main() {
  Future<void> zeige(
    WidgetTester tester, {
    HeroSheet held = _held,
    bool episch = false,
    required Future<void> Function(BuildContext context, WidgetRef ref) oeffnen,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(
            FakeRepository(heroes: [held], states: {'demo': _zustand}),
          ),
          rulesCatalogProvider.overrideWith((ref) async => _katalog),
          isHouseRuleActiveProvider(EpicRuleKeys.advantages)
              .overrideWithValue(episch),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => oeffnen(context, ref),
                child: const Text('öffnen'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('öffnen'));
    await tester.pumpAndSettle();
  }

  Future<void> zeigeWunden(
    WidgetTester tester, {
    HeroSheet held = _held,
    bool episch = false,
  }) {
    return zeige(
      tester,
      held: held,
      episch: episch,
      oeffnen: (context, _) =>
          showWundenDetailDialog(context: context, heroId: 'demo'),
    );
  }

  String modifikator(WidgetTester tester) =>
      tester.widget<TextField>(_key('probe-dialog-modifier')).controller!.text;

  testWidgets('Zusammenfassung nach Gesamt- und Zonensystem mit Armrollen', (
    tester,
  ) async {
    await zeigeWunden(tester);

    // Kopf + linker Arm: allgemein je −2, Kopf INI-Basis −2 und MU/KL/IN,
    // Arm KK/FF und AT/PA nur am Schildarm (WdS S. 58, 108 f.).
    expect(
      find.text(
        'AT −4  PA −4  FK −4  INI-Basis −6  GS −2  Schildarm AT/PA −2  '
        'Proben: MU −2, KL −2, IN −2, FF −2, GE −4, KK −2',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Proben −'), findsNothing);
    expect(
      tester.widget<Text>(_key('wunden-armrolle-linkerArm')).data,
      'Schildarm',
    );
    expect(
      tester.widget<Text>(_key('wunden-armrolle-rechterArm')).data,
      'Schwertarm',
    );
    expect(
      find.text('Kopf: aktuelle INI −7 (laufender Kampf)'),
      findsOneWidget,
    );
  });

  testWidgets('Linkshänder: der linke Arm ist der Schwertarm', (tester) async {
    await zeigeWunden(
      tester,
      held: _held.copyWith(vorteileText: 'Linkshänder'),
    );

    expect(
      tester.widget<Text>(_key('wunden-armrolle-linkerArm')).data,
      'Schwertarm',
    );
    expect(find.textContaining('Schwertarm AT/PA −2'), findsOneWidget);
    expect(find.textContaining('Schildarm AT/PA'), findsNothing);
  });

  testWidgets('SB-Probe würfelt gegen die Probenwerte, ohne pauschalen Abzug', (
    tester,
  ) async {
    await zeigeWunden(tester);

    expect(
      find.text('SB-Probe erschwert um 4 × 2 Wunden insgesamt = 8'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Zählt alle bisher erlittenen Wunden, auch unterdrückte '
        '(WdS S. 83, 111).',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('SB-Probe (TaW 7)'));
    await tester.pumpAndSettle();

    // MU −2 (Kopf), KK −2 (Arm), KO unverändert.
    expect(
      find.byKey(const ValueKey<String>('probe-dialog-eigenschaften')),
      findsOneWidget,
    );
    expect(find.text('MU: 10 | KO: 12 | KK: 10'), findsOneWidget);
    expect(modifikator(tester), '-8');
    // TaW* der Selbstbeherrschung ist aufklappbar hergeleitet (ARCH-04).
    expect(find.text('TaW* herleiten'), findsOneWidget);
  });

  testWidgets('epische KO halbiert die SB-Erschwernis', (tester) async {
    await zeigeWunden(
      tester,
      held: _held.copyWith(
        isEpisch: true,
        epicMainAttributes: const Attributes(
          mu: 0,
          kl: 1,
          inn: 0,
          ch: 0,
          ff: 0,
          ge: 0,
          ko: 1,
          kk: 0,
        ),
      ),
      episch: true,
    );

    expect(
      find.text('SB-Probe erschwert um 4 × 2 Wunden insgesamt = 8, halbiert 4'),
      findsOneWidget,
    );
    expect(
      find.text('Bei 2 Wunden aus einem Treffer: +4; bei 3: +6 (halbiert)'),
      findsOneWidget,
    );
    await tester.tap(find.text('SB-Probe (TaW 7)'));
    await tester.pumpAndSettle();
    expect(modifikator(tester), '-4');
  });

  DiceLogEntry protokoll(String titel, ProbeType art) => DiceLogEntry(
    timestamp: DateTime.utc(2026, 10, 23, 8),
    type: art,
    title: titel,
    subtitle: '',
    success: true,
    diceValues: const [9, 15, 5],
    targetValue: 10,
  );

  // Öffnet die Probe eines Protokolleintrags wie die Protokollansicht. Die
  // Provider sind vorher geladen, weil dort der Bogen ohnehin offen ist.
  Future<bool?> wiederhole(
    WidgetTester tester,
    DiceLogEntry eintrag, {
    bool mitHinweis = false,
  }) async {
    late BuildContext kontext;
    late WidgetRef bezug;
    await zeige(
      tester,
      oeffnen: (context, ref) async {
        kontext = context;
        bezug = ref;
        ref.listenManual(heroComputedProvider('demo'), (_, _) {});
        ref.listenManual(heroRulesCatalogProvider('demo'), (_, _) {});
      },
    );
    await tester.pumpAndSettle();
    bool? ergebnis;
    if (mitHinweis) {
      unawaited(
        wiederholeProbeMitHinweis(
          context: kontext,
          ref: bezug,
          heroId: 'demo',
          entry: eintrag,
        ),
      );
    } else {
      unawaited(
        wiederholeProbe(
          context: kontext,
          ref: bezug,
          heroId: 'demo',
          entry: eintrag,
        ).then((gefunden) => ergebnis = gefunden),
      );
    }
    await tester.pumpAndSettle();
    return ergebnis;
  }

  testWidgets('Nochmal würfeln: öffnet die Probe aus dem Protokoll mit den '
      'aktuellen Werten (SPIEL-05)', (tester) async {
    await wiederhole(
      tester,
      protokoll('Talentprobe: Menschenkenntnis', ProbeType.talent),
    );

    // Dieselben gesenkten Werte wie in der Schnellsuche, keine alten
    // Modifikatoren.
    expect(find.textContaining('KL: 10'), findsOneWidget);
    expect(find.textContaining('CH: 12'), findsOneWidget);
    expect(modifikator(tester), '0');
  });

  testWidgets('Nochmal würfeln: eine Eigenschaftsprobe öffnet ihren Dialog', (
    tester,
  ) async {
    await wiederhole(
      tester,
      protokoll('Eigenschaftsprobe: CH', ProbeType.attribute),
    );
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.textContaining('CH'), findsWidgets);
  });

  testWidgets('Nochmal würfeln: eine unbekannte Probe öffnet nichts und '
      'meldet das', (tester) async {
    await wiederhole(
      tester,
      protokoll('Talentprobe: Drachenreiten', ProbeType.talent),
      mitHinweis: true,
    );

    expect(find.byType(Dialog), findsNothing);
    expect(find.textContaining('nicht wiederholen'), findsOneWidget);
  });

  testWidgets('Nochmal würfeln: Titel und Probeart müssen zusammenpassen', (
    tester,
  ) async {
    // Der Titel ist eine Talentprobe, die Art ein Zauber.
    await wiederhole(
      tester,
      protokoll('Talentprobe: Menschenkenntnis', ProbeType.spell),
      mitHinweis: true,
    );
    expect(find.byType(Dialog), findsNothing);
    expect(find.textContaining('nicht wiederholen'), findsOneWidget);
  });
  testWidgets('Schnellsuche: Talentprobe mit gesenkten Werten, ohne '
      'Startabzug', (tester) async {
    await zeige(
      tester,
      oeffnen: (context, ref) =>
          showProbeQuickSearch(context: context, ref: ref, heroId: 'demo'),
    );

    Finder kachel(String name, String detail) => find.descendant(
      of: _key('probe-quick-search-attribute-$name'),
      matching: find.text(detail),
    );
    // MU −2 (Kopf), GE −4 (allgemein je Wunde), CH unberührt.
    expect(
      kachel('MU', 'Eigenschaftsprobe · Wert 10 (Wunden −2)'),
      findsOneWidget,
    );
    expect(
      kachel('GE', 'Eigenschaftsprobe · Wert 8 (Wunden −4)'),
      findsOneWidget,
    );
    expect(kachel('CH', 'Eigenschaftsprobe · Wert 12'), findsOneWidget);
    await tester.enterText(_key('probe-quick-search-field'), 'Menschen');
    await tester.pumpAndSettle();
    await tester.tap(_key('probe-quick-search-talent-Menschenkenntnis'));
    await tester.pumpAndSettle();

    expect(find.textContaining('KL: 10'), findsOneWidget);
    expect(find.textContaining('IN: 10'), findsOneWidget);
    expect(find.textContaining('CH: 12'), findsOneWidget);
    expect(modifikator(tester), '0');
  });
}
