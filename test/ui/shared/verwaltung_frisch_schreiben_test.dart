import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_note_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_begleiter_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_notes_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

import '../../test_support/bogen_test_repository.dart';

// Sofortbuchungen der Verwaltung (ARCH-05): Abenteuerabschluss und
// Vertrauten-Steigerung buchen auf den gespeicherten Helden. Ein anderer
// Schreibweg speichert nach dem Aufbau (`BogenTestRepository.fremdeAenderung`);
// seine Felder bleiben stehen, und nichts wird doppelt gebucht.

const _katalog = RulesCatalog(
  version: 'test',
  source: 'test',
  talents: <TalentDef>[],
  spells: <SpellDef>[],
  weapons: <WeaponDef>[],
);

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

const _abenteuer = HeroAdventureEntry(
  id: 'adv_1',
  title: 'Feuer im Nebel',
  apReward: 40,
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
  name: 'Hexe',
  level: 1,
  apTotal: 1000,
  apSpent: 500,
  apAvailable: 500,
  attributes: _attribute,
  adventures: [_abenteuer],
  companions: [_rabe],
);

void main() {
  late BogenTestRepository repo;

  Future<WorkspaceTabEditActions?> zeige(
    WidgetTester tester,
    Widget Function(ValueChanged<WorkspaceTabEditActions> registriere) tab,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repo = BogenTestRepository(
      heroes: [_held],
      states: const {
        'demo': HeroState(
          currentLep: 10,
          currentAsp: 10,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );
    WorkspaceTabEditActions? aktionen;
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
          home: Scaffold(body: tab((registriert) => aktionen = registriert)),
        ),
      ),
    );
    await _pumpOhneUeberlauf(tester);
    return aktionen;
  }

  group('Abenteuer abschließen', () {
    Widget notizen(ValueChanged<WorkspaceTabEditActions> registriere) {
      return HeroNotesTab(
        heroId: 'demo',
        onDirtyChanged: (_) {},
        onEditingChanged: (_) {},
        onRegisterDiscard: (_) {},
        onRegisterEditActions: registriere,
      );
    }

    Future<void> schliesseAb(WidgetTester tester) async {
      await tester.tap(find.text('Abenteuer'));
      await _pumpOhneUeberlauf(tester);
      final knopf = find.byKey(
        const ValueKey<String>('notes-adventure-complete-adv_1'),
      );
      await tester.ensureVisible(knopf);
      await tester.tap(knopf);
      await _pumpOhneUeberlauf(tester);
      final speichern = find.byKey(
        const ValueKey<String>('notes-adventure-complete-dialog-save'),
      );
      await tester.ensureVisible(speichern);
      await tester.tap(speichern);
      await _pumpOhneUeberlauf(tester);
    }

    testWidgets('bucht auf den gespeicherten Stand und behält Notizen', (
      tester,
    ) async {
      await zeige(tester, notizen);
      // Inzwischen: 100 AP gebucht und dem Abenteuer eine Notiz gegeben.
      repo.fremdeAenderung = (held) => held.copyWith(
        apTotal: held.apTotal + 100,
        adventures: [
          _abenteuer.copyWith(
            notes: const [HeroNoteEntry(title: 'Spur im Nebel')],
          ),
        ],
      );

      await schliesseAb(tester);

      final gespeichert = await repo.gespeichert('demo');
      final abenteuer = gespeichert.adventures.single;
      expect(gespeichert.apTotal, 1140);
      expect(abenteuer.rewardsApplied, isTrue);
      expect(abenteuer.notes.single.title, 'Spur im Nebel');
    });

    testWidgets(
      'ein inzwischen abgeschlossenes Abenteuer bucht nicht doppelt',
      (tester) async {
        await zeige(tester, notizen);
        repo.fremdeAenderung = (held) => held.copyWith(
          adventures: [
            _abenteuer.copyWith(
              status: HeroAdventureStatus.completed,
              rewardsApplied: true,
            ),
          ],
        );

        await schliesseAb(tester);

        expect(repo.bogenSpeicherungen, 0);
        expect(
          find.textContaining('Das Abenteuer wurde bereits abgeschlossen.'),
          findsOneWidget,
        );
      },
    );
  });

  group('Vertrauten-Steigerung', () {
    Future<void> steigereIni(
      WidgetTester tester,
      WorkspaceTabEditActions aktionen,
    ) async {
      await aktionen.startEdit();
      await _pumpOhneUeberlauf(tester);
      final knopf = find.byTooltip('INI steigern');
      await tester.ensureVisible(knopf);
      await tester.tap(knopf);
      await _pumpOhneUeberlauf(tester);
      await tester.tap(find.byTooltip('Wert steigern'));
      await _pumpOhneUeberlauf(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byIcon(Icons.trending_up),
        ),
      );
      await _pumpOhneUeberlauf(tester);
    }

    Widget begleiter(ValueChanged<WorkspaceTabEditActions> registriere) {
      return HeroBegleiterTab(
        heroId: 'demo',
        onDirtyChanged: (_) {},
        onEditingChanged: (_) {},
        onRegisterDiscard: (_) {},
        onRegisterEditActions: registriere,
      );
    }

    testWidgets('bucht auf den gespeicherten Begleiter', (tester) async {
      final aktionen = await zeige(tester, begleiter);
      repo.fremdeAenderung = (held) => held.copyWith(
        name: 'Hexe vom Sumpf',
        companions: [_rabe.copyWith(apGesamt: 300)],
      );

      await steigereIni(tester, aktionen!);

      final gespeichert = await repo.gespeichert('demo');
      final rabe = gespeichert.companions.single;
      expect(rabe.steigerungen['ini'], 1);
      expect(rabe.apAusgegeben, greaterThan(0));
      expect(rabe.apGesamt, 300);
      expect(gespeichert.name, 'Hexe vom Sumpf');
    });

    testWidgets('ein inzwischen gesteigerter Wert wird abgewiesen', (
      tester,
    ) async {
      final aktionen = await zeige(tester, begleiter);
      repo.fremdeAenderung = (held) => held.copyWith(
        companions: [
          _rabe.copyWith(steigerungen: const {'ini': 1}),
        ],
      );

      await steigereIni(tester, aktionen!);

      expect(repo.bogenSpeicherungen, 0);
      expect(
        find.textContaining('Der Vertraute wurde inzwischen gesteigert'),
        findsOneWidget,
      );
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
