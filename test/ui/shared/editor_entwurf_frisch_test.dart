import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reisebericht.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_begleiter_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_magic_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_notes_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_overview_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_reisebericht_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/editor_entwurf_speichern.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

import '../../test_support/bogen_test_repository.dart';

// Editorentwürfe der Verwaltung (ARCH-05): Beim Speichern wird der Entwurf
// mit dem frisch geladenen Helden abgeglichen. Ein anderer Schreibweg
// speichert nach dem Bearbeitungsbeginn (`BogenTestRepository.fremdeAenderung`);
// seine Felder bleiben stehen, auch im Bereich des Editors, solange der
// Entwurf ihn nicht selbst geändert hat.

const _katalog = RulesCatalog(
  version: 'test',
  source: 'test',
  talents: <TalentDef>[
    TalentDef(
      id: 'tal_a',
      name: 'Athletik',
      group: 'Koerper',
      steigerung: 'C',
      attributes: <String>['Mut', 'Gewandheit', 'Koerperkraft'],
    ),
    TalentDef(
      id: 'tal_nah',
      name: 'Schwerter',
      group: 'Kampftalent',
      type: 'Nahkampf',
      weaponCategory: 'Schwert',
      steigerung: 'D',
      attributes: <String>['Mut', 'Gewandheit', 'Koerperkraft'],
    ),
  ],
  spells: <SpellDef>[],
  weapons: <WeaponDef>[],
  reisebericht: <ReiseberichtDef>[
    ReiseberichtDef(
      id: 'rb_ork',
      name: 'Erster Ork',
      kategorie: 'kampferfahrungen',
      typ: 'checkpoint',
      ap: 10,
    ),
  ],
);

const _abenteuer = HeroAdventureEntry(
  id: 'adv_1',
  title: 'Feuer im Nebel',
  apReward: 40,
);

const _schwert = MainWeaponSlot(
  id: 'w1',
  name: 'Schwert',
  talentId: 'tal_nah',
  weaponType: 'Schwert',
);

const _rabe = HeroCompanion(
  id: 'rabe',
  name: 'Krah',
  typ: BegleiterTyp.vertrauter,
  ini: 10,
  apGesamt: 200,
  apAusgegeben: 0,
);

const _held = HeroSheet(
  id: 'demo',
  name: 'Rondra',
  level: 1,
  apTotal: 1000,
  apSpent: 500,
  apAvailable: 500,
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
  talents: <String, HeroTalentEntry>{'tal_a': HeroTalentEntry(talentValue: 4)},
  combatConfig: CombatConfig(weapons: <MainWeaponSlot>[_schwert]),
  companions: <HeroCompanion>[_rabe],
  adventures: <HeroAdventureEntry>[_abenteuer],
);

typedef _Tab = Widget Function(
  ValueChanged<WorkspaceTabEditActions> registriere,
  ValueChanged<bool> bearbeitet,
);

Widget _talente(
  ValueChanged<WorkspaceTabEditActions> registriere,
  ValueChanged<bool> bearbeitet,
) => HeroTalentsTab(
  heroId: 'demo',
  onDirtyChanged: (_) {},
  onEditingChanged: bearbeitet,
  onRegisterDiscard: (_) {},
  onRegisterEditActions: registriere,
);

Widget _magie(
  ValueChanged<WorkspaceTabEditActions> registriere,
  ValueChanged<bool> bearbeitet,
) => HeroMagicTab(
  heroId: 'demo',
  onDirtyChanged: (_) {},
  onEditingChanged: bearbeitet,
  onRegisterDiscard: (_) {},
  onRegisterEditActions: registriere,
);

Widget _begleiter(
  ValueChanged<WorkspaceTabEditActions> registriere,
  ValueChanged<bool> bearbeitet,
) => HeroBegleiterTab(
  heroId: 'demo',
  onDirtyChanged: (_) {},
  onEditingChanged: bearbeitet,
  onRegisterDiscard: (_) {},
  onRegisterEditActions: registriere,
);

Widget _kampf(
  ValueChanged<WorkspaceTabEditActions> registriere,
  ValueChanged<bool> bearbeitet,
) => HeroCombatTab(
  heroId: 'demo',
  onDirtyChanged: (_) {},
  onEditingChanged: bearbeitet,
  onRegisterDiscard: (_) {},
  onRegisterEditActions: registriere,
);

Widget _uebersicht(
  ValueChanged<WorkspaceTabEditActions> registriere,
  ValueChanged<bool> bearbeitet,
) => HeroOverviewTab(
  heroId: 'demo',
  onDirtyChanged: (_) {},
  onEditingChanged: bearbeitet,
  onRegisterDiscard: (_) {},
  onRegisterEditActions: registriere,
);

Widget _notizen(
  ValueChanged<WorkspaceTabEditActions> registriere,
  ValueChanged<bool> bearbeitet,
) => HeroNotesTab(
  heroId: 'demo',
  onDirtyChanged: (_) {},
  onEditingChanged: bearbeitet,
  onRegisterDiscard: (_) {},
  onRegisterEditActions: registriere,
);

Widget _reisebericht(
  ValueChanged<WorkspaceTabEditActions> registriere,
  ValueChanged<bool> bearbeitet,
) => HeroReiseberichtTab(
  heroId: 'demo',
  onDirtyChanged: (_) {},
  onEditingChanged: bearbeitet,
  onRegisterDiscard: (_) {},
  onRegisterEditActions: registriere,
);

void main() {
  late BogenTestRepository repo;
  late WorkspaceTabEditActions aktionen;
  late bool bearbeitet;

  Future<void> zeige(
    WidgetTester tester,
    _Tab tab, {
    int lebenspunkte = 10,
    HeroSheet held = _held,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repo = BogenTestRepository(
      heroes: [held],
      states: {
        'demo': HeroState(
          currentLep: lebenspunkte,
          currentAsp: 10,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );
    bearbeitet = false;
    WorkspaceTabEditActions? registriert;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith((ref) async => _katalog),
          appSettingsProvider.overrideWith(
            (ref) => Stream<AppSettings>.value(const AppSettings()),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: tab(
              (aktionen) => registriert = aktionen,
              (wert) => bearbeitet = wert,
            ),
          ),
        ),
      ),
    );
    await _pumpOhneUeberlauf(tester);
    aktionen = registriert!;
    await aktionen.startEdit();
    await _pumpOhneUeberlauf(tester);
  }

  // Startet das Speichern über die registrierte Aktion; ein Dialog bleibt
  // offen, bis der Test ihn bedient. [laufendesSpeichern] endet danach.
  late Future<void> laufendesSpeichern;
  Future<void> speichere(WidgetTester tester) async {
    laufendesSpeichern = aktionen.save();
    await _pumpOhneUeberlauf(tester);
  }

  group('ohne eigene Änderung bleibt eine fremde Änderung stehen', () {
    Future<void> pruefe(
      WidgetTester tester,
      _Tab tab, {
      required HeroSheet Function(HeroSheet held) eigenerBereich,
      required void Function(HeroSheet gespeichert) erwarte,
    }) async {
      await zeige(tester, tab);
      repo.fremdeAenderung = (held) =>
          eigenerBereich(held).copyWith(name: 'Rondra die Kühne');

      await speichere(tester);
      await laufendesSpeichern;

      final gespeichert = await repo.gespeichert('demo');
      expect(repo.bogenSpeicherungen, 1);
      expect(gespeichert.name, 'Rondra die Kühne');
      erwarte(gespeichert);
      expect(bearbeitet, isFalse);
    }

    testWidgets('Talente', (tester) async {
      await pruefe(
        tester,
        _talente,
        eigenerBereich: (held) => held.copyWith(
          talents: const {'tal_a': HeroTalentEntry(talentValue: 9)},
        ),
        erwarte: (held) => expect(held.talents['tal_a']!.talentValue, 9),
      );
    });

    testWidgets('Magie', (tester) async {
      await pruefe(
        tester,
        _magie,
        eigenerBereich: (held) =>
            held.copyWith(representationen: const ['Mag']),
        erwarte: (held) => expect(held.representationen, ['Mag']),
      );
    });

    testWidgets('Begleiter', (tester) async {
      await pruefe(
        tester,
        _begleiter,
        eigenerBereich: (held) =>
            held.copyWith(companions: [_rabe.copyWith(apGesamt: 300)]),
        erwarte: (held) => expect(held.companions.single.apGesamt, 300),
      );
    });

    testWidgets('Kampf', (tester) async {
      const axt = MainWeaponSlot(id: 'w2', name: 'Axt', talentId: 'tal_nah');
      await pruefe(
        tester,
        _kampf,
        eigenerBereich: (held) => held.copyWith(
          combatConfig: held.combatConfig.copyWith(
            weapons: const [_schwert, axt],
          ),
        ),
        erwarte: (held) => expect(
          held.combatConfig.weaponSlots.map((slot) => slot.name),
          ['Schwert', 'Axt'],
        ),
      );
    });

    testWidgets('Übersicht', (tester) async {
      await pruefe(
        tester,
        _uebersicht,
        eigenerBereich: (held) =>
            held.copyWith(attributes: held.attributes.copyWith(mu: 14)),
        erwarte: (held) => expect(held.attributes.mu, 14),
      );
    });

    testWidgets('Notizen: ein inzwischen abgeschlossenes Abenteuer bleibt', (
      tester,
    ) async {
      await pruefe(
        tester,
        _notizen,
        eigenerBereich: (held) => held.copyWith(
          adventures: [
            _abenteuer.copyWith(
              status: HeroAdventureStatus.completed,
              rewardsApplied: true,
            ),
          ],
        ),
        erwarte: (held) {
          final abenteuer = held.adventures.single;
          expect(abenteuer.status, HeroAdventureStatus.completed);
          expect(abenteuer.rewardsApplied, isTrue);
        },
      );
    });
  });

  testWidgets('die Übersicht lässt den Laufzeitzustand unberührt', (
    tester,
  ) async {
    await zeige(tester, _uebersicht, lebenspunkte: -3);
    await tester.enterText(
      find.byKey(const ValueKey<String>('overview-field-name')),
      'Rondrian',
    );

    await speichere(tester);
    await laufendesSpeichern;

    expect((await repo.gespeichert('demo')).name, 'Rondrian');
    expect((await repo.loadHeroState('demo'))!.currentLep, -3);
  });

  group('Reisebericht', () {
    Future<void> hakeOrkAb(WidgetTester tester) async {
      await tester.tap(find.byType(Checkbox).first);
      await _pumpOhneUeberlauf(tester);
    }

    // Der Ork ist bereits abgehakt und seine 10 AP sind gebucht.
    final mitGebuchtemOrk = _held.copyWith(
      apTotal: 1010,
      reisebericht: const HeroReisebericht(
        checkedIds: {'rb_ork'},
        appliedRewardIds: {'rb_ork'},
      ),
    );

    testWidgets('Enthaken nimmt die Belohnung beim Speichern zurück', (
      tester,
    ) async {
      await zeige(tester, _reisebericht, held: mitGebuchtemOrk);
      await hakeOrkAb(tester);
      expect(find.text('Belohnungen zurücknehmen?'), findsOneWidget);
      expect(find.text('10 AP'), findsOneWidget);
      await tester.tap(find.text('Zurücknehmen'));
      await _pumpOhneUeberlauf(tester);
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).first).value,
        isFalse,
      );
      repo.fremdeAenderung = (held) => held.copyWith(name: 'Rondra die Kühne');

      await speichere(tester);
      await laufendesSpeichern;

      final gespeichert = await repo.gespeichert('demo');
      expect(gespeichert.apTotal, 1000);
      expect(gespeichert.reisebericht.checkedIds, isEmpty);
      expect(gespeichert.reisebericht.appliedRewardIds, isEmpty);
      expect(gespeichert.name, 'Rondra die Kühne');
    });

    testWidgets('Abbrechen lässt den Haken und die Buchung stehen', (
      tester,
    ) async {
      await zeige(tester, _reisebericht, held: mitGebuchtemOrk);
      await hakeOrkAb(tester);
      await tester.tap(find.text('Abbrechen'));
      await _pumpOhneUeberlauf(tester);
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).first).value,
        isTrue,
      );

      await speichere(tester);
      await laufendesSpeichern;

      expect(repo.bogenSpeicherungen, 0);
      expect((await repo.gespeichert('demo')).apTotal, 1010);
    });

    testWidgets('bucht die Belohnung auf den gespeicherten Helden', (
      tester,
    ) async {
      await zeige(tester, _reisebericht);
      await hakeOrkAb(tester);
      repo.fremdeAenderung = (held) =>
          held.copyWith(name: 'Rondra die Kühne', apTotal: 1100);

      await speichere(tester);
      await laufendesSpeichern;

      final gespeichert = await repo.gespeichert('demo');
      expect(gespeichert.apTotal, 1110);
      expect(gespeichert.name, 'Rondra die Kühne');
      expect(gespeichert.reisebericht.appliedRewardIds, {'rb_ork'});
    });

    testWidgets('anderswo Gebuchtes wird nicht doppelt gebucht', (
      tester,
    ) async {
      await zeige(tester, _reisebericht);
      await hakeOrkAb(tester);
      repo.fremdeAenderung = (held) => held.copyWith(
        apTotal: 1010,
        reisebericht: const HeroReisebericht(
          checkedIds: {'rb_ork'},
          appliedRewardIds: {'rb_ork'},
        ),
      );

      await speichere(tester);
      expect(find.text(kEditorEntwurfErzwingen), findsNothing);
      await tester.tap(find.text(kEditorEntwurfWeiter));
      await _pumpOhneUeberlauf(tester);
      await laufendesSpeichern;

      expect(repo.bogenSpeicherungen, 0);
      expect(bearbeitet, isTrue);
    });

    testWidgets('ohne Änderung wird nichts überschrieben', (tester) async {
      await zeige(tester, _reisebericht);
      repo.fremdeAenderung = (held) => held.copyWith(
        reisebericht: const HeroReisebericht(
          checkedIds: {'rb_ork'},
          appliedRewardIds: {'rb_ork'},
        ),
      );

      await speichere(tester);
      await laufendesSpeichern;

      expect(repo.bogenSpeicherungen, 0);
      expect(bearbeitet, isFalse);
    });
  });

  group('Talente mit eigener Änderung', () {
    final talentwert = find.byKey(
      const ValueKey<String>('talents-field-tal_a-talentValue'),
    );

    testWidgets('eine fremde Änderung daneben bleibt, AP zählen dazu', (
      tester,
    ) async {
      await zeige(tester, _talente);
      await tester.enterText(talentwert, '7');
      repo.fremdeAenderung = (held) =>
          held.copyWith(name: 'Rondra die Kühne', apTotal: 1100);

      await speichere(tester);
      await laufendesSpeichern;

      final gespeichert = await repo.gespeichert('demo');
      expect(gespeichert.talents['tal_a']!.talentValue, 7);
      expect(gespeichert.name, 'Rondra die Kühne');
      expect(gespeichert.apTotal, 1100);
    });

    testWidgets('bei Überschneidung bleibt „Weiter bearbeiten“ im Entwurf', (
      tester,
    ) async {
      await zeige(tester, _talente);
      await tester.enterText(talentwert, '7');
      repo.fremdeAenderung = (held) => held.copyWith(
        talents: const {'tal_a': HeroTalentEntry(talentValue: 9)},
      );

      await speichere(tester);
      expect(find.text(kEditorEntwurfKonfliktTitel), findsOneWidget);
      expect(find.textContaining('Talente'), findsWidgets);
      await tester.tap(find.text(kEditorEntwurfWeiter));
      await _pumpOhneUeberlauf(tester);
      await laufendesSpeichern;

      expect(repo.bogenSpeicherungen, 0);
      expect(bearbeitet, isTrue);
    });

    testWidgets('„Meine Fassung speichern“ nimmt den Entwurf', (tester) async {
      await zeige(tester, _talente);
      await tester.enterText(talentwert, '7');
      repo.fremdeAenderung = (held) => held.copyWith(
        name: 'Rondra die Kühne',
        talents: const {'tal_a': HeroTalentEntry(talentValue: 9)},
      );

      await speichere(tester);
      await tester.tap(find.text(kEditorEntwurfErzwingen));
      await _pumpOhneUeberlauf(tester);
      await laufendesSpeichern;

      final gespeichert = await repo.gespeichert('demo');
      expect(gespeichert.talents['tal_a']!.talentValue, 7);
      expect(gespeichert.name, 'Rondra die Kühne');
      expect(bearbeitet, isFalse);
    });
  });
}

// Einige Bestandsansichten laufen im Test-Layout über (siehe
// `begleiter_angriff_test.dart`); das hat mit den Schreibwegen nichts zu tun.
Future<void> _pumpOhneUeberlauf(WidgetTester tester) async {
  await tester.pumpAndSettle();
  Object? fehler;
  do {
    fehler = tester.takeException();
    if (fehler != null && !'$fehler'.contains('A RenderFlex overflowed')) {
      throw fehler;
    }
  } while (fehler != null);
}
