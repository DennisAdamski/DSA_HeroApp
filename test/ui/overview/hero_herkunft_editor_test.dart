import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_background.dart';
import 'package:dsa_heldenverwaltung/domain/hero_herkunft.dart';
import 'package:dsa_heldenverwaltung/domain/hero_merkmal.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_herkunft_migration_rules.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_overview_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

import '../../test_support/bogen_test_repository.dart';

// Herkunftsmodifikatoren und Merkmalsherkunft in der Übersicht (ARCH-02):
// Der Entwurf trifft Vorschau und gespeicherten Stand, Abbrechen erhält den
// Ursprung, und eine Paralleländerung wird nie still überschrieben.

const _katalog = RulesCatalog(
  version: 'test',
  source: 'test',
  talents: <TalentDef>[],
  spells: <SpellDef>[],
  weapons: <WeaponDef>[],
);

HeroSheet _held({HeroBackground? background}) {
  return HeroSheet(
    id: 'demo',
    name: 'Rondra',
    level: 1,
    attributes: const Attributes(
      mu: 14,
      kl: 12,
      inn: 13,
      ch: 11,
      ff: 10,
      ge: 12,
      ko: 14,
      kk: 13,
    ),
    background:
        background ??
        const HeroBackground(
          rasseModText: 'LEP+10, MR-4',
          professionModText: 'Hausnotiz',
        ),
    vorteilEintraege: const <HeroMerkmal>[
      HeroMerkmal(text: 'Eigener Tick', zuordnung: HeroMerkmalZuordnung.frei),
    ],
    vorteileText: 'Eigener Tick',
  );
}

BogenTestRepository _repo({HeroSheet? held}) {
  return BogenTestRepository(
    heroes: <HeroSheet>[held ?? _held()],
    states: <String, HeroState>{
      'demo': const HeroState(
        currentLep: 10,
        currentAsp: 0,
        currentKap: 0,
        currentAu: 10,
      ),
    },
  );
}

Future<WorkspaceTabEditActions> _zeige(
  WidgetTester tester,
  BogenTestRepository repo, {
  double breite = 900,
}) async {
  tester.view.physicalSize = Size(breite, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  WorkspaceTabEditActions? aktionen;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        heroRepositoryProvider.overrideWithValue(repo),
        rulesCatalogProvider.overrideWith((ref) async => _katalog),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: HeroOverviewTab(
            heroId: 'demo',
            onDirtyChanged: (_) {},
            onEditingChanged: (_) {},
            onRegisterDiscard: (_) {},
            onRegisterEditActions: (a) => aktionen = a,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return aktionen!;
}

Future<void> _sichtbar(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    240,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

// Fügt über den Dialog einen Eigenschafts-Modifikator hinzu.
Future<void> _fuegeHinzu(
  WidgetTester tester,
  HeroHerkunft herkunft, {
  String ziel = 'KK',
  String betrag = '2',
}) async {
  final knopf = find.byKey(ValueKey('herkunft-add-${herkunft.name}'));
  await _sichtbar(tester, knopf);
  await tester.tap(knopf);
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(const ValueKey('herkunft-dialog-ziel-eigenschaft')),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(ziel).last);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('herkunft-dialog-betrag')),
    betrag,
  );
  await tester.tap(find.byKey(const ValueKey('herkunft-dialog-uebernehmen')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ohne Änderung bleibt die Herkunft beim Speichern unberührt', (
    tester,
  ) async {
    final repo = _repo();
    final aktionen = await _zeige(tester, repo);
    await aktionen.startEdit();
    await tester.pumpAndSettle();
    await aktionen.save();
    await tester.pumpAndSettle();

    final gespeichert = await repo.gespeichert('demo');
    // Die Migration übernimmt `saveHero`; Texte bleiben, wie sie waren.
    expect(gespeichert.background.rasseModText, 'LEP+10, MR-4');
    expect(gespeichert.background.professionModText, 'Hausnotiz');
    expect(
      gespeichert.background.herkunftsModifikatoren!.rasse.map((e) => e.text),
      ['LEP+10', 'MR-4'],
    );
  });

  testWidgets('Änderungen treffen Vorschau und gespeicherten Stand', (
    tester,
  ) async {
    final repo = _repo();
    final aktionen = await _zeige(tester, repo);
    await aktionen.startEdit();
    await tester.pumpAndSettle();

    await _fuegeHinzu(tester, HeroHerkunft.rasse);
    await _sichtbar(tester, find.byKey(const ValueKey('herkunft-rasse')));
    expect(find.text('KK+2'), findsOneWidget);

    // Vorschau: ein AsP-Eintrag in der Profession aktiviert Magie schon im
    // Entwurf, ohne dass etwas gespeichert ist.
    final professionKnopf = find.byKey(
      const ValueKey('herkunft-add-profession'),
    );
    await _sichtbar(tester, professionKnopf);
    await tester.tap(professionKnopf);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Basiswert'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('herkunft-dialog-ziel-basiswert')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ASP').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('herkunft-dialog-betrag')),
      '3',
    );
    await tester.tap(find.byKey(const ValueKey('herkunft-dialog-uebernehmen')));
    await tester.pumpAndSettle();
    expect(
      (await repo.gespeichert('demo')).background.rasseModText,
      'LEP+10, MR-4',
    );

    final oeffnen = find.byKey(
      const ValueKey('overview-resource-settings-open'),
    );
    await _sichtbar(tester, oeffnen);
    await tester.tap(oeffnen);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('overview-resource-status-magic')),
          )
          .data,
      'Aktuell: aktiviert (automatisch)',
    );
    await tester.tap(
      find.byKey(const ValueKey('overview-resource-settings-close')),
    );
    await tester.pumpAndSettle();

    await aktionen.save();
    await tester.pumpAndSettle();
    final gespeichert = await repo.gespeichert('demo');
    expect(gespeichert.background.rasseModText, 'LEP+10, MR-4, KK+2');
    expect(gespeichert.background.professionModText, 'Hausnotiz, ASP+3');
    final container = gespeichert.background.herkunftsModifikatoren!;
    expect(container.rasse.map((e) => e.text), ['LEP+10', 'MR-4', 'KK+2']);
    expect(container.profession.last.ziel, 'ASP');
    expect(gleicheHerkunftAb(gespeichert.background).abweichungen, isEmpty);
  });

  testWidgets('Abbrechen erhält den Ursprung', (tester) async {
    final repo = _repo();
    final aktionen = await _zeige(tester, repo);
    await aktionen.startEdit();
    await tester.pumpAndSettle();
    await _fuegeHinzu(tester, HeroHerkunft.kultur);
    expect(find.text('KK+2'), findsOneWidget);

    await aktionen.cancel();
    await tester.pumpAndSettle();
    expect(find.text('KK+2'), findsNothing);
    final gespeichert = await repo.gespeichert('demo');
    expect(gespeichert.background.kulturModText, isEmpty);
    expect(gespeichert.background.herkunftsModifikatoren, isNull);
    expect(repo.bogenSpeicherungen, 0);
  });

  testWidgets('den letzten Eintrag löschen bleibt über den Neustart gelöscht', (
    tester,
  ) async {
    final repo = _repo(
      held: _held(background: const HeroBackground(rasseModText: 'LEP+10')),
    );
    var aktionen = await _zeige(tester, repo);
    await aktionen.startEdit();
    await tester.pumpAndSettle();
    final chip = find.byKey(const ValueKey('herkunft-chip-rasse-0'));
    await _sichtbar(tester, chip);
    await tester.tap(
      find.descendant(of: chip, matching: find.byIcon(Icons.clear)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Keine Einträge'), findsWidgets);
    await aktionen.save();
    await tester.pumpAndSettle();

    var gespeichert = await repo.gespeichert('demo');
    expect(gespeichert.background.rasseModText, isEmpty);
    expect(gespeichert.background.herkunftsModifikatoren!.rasse, isEmpty);

    // „Neustart“: Tab neu aufbauen und noch einmal speichern; der Alttext
    // darf nicht wieder auftauchen.
    await tester.pumpWidget(const SizedBox());
    aktionen = await _zeige(tester, repo);
    await aktionen.startEdit();
    await tester.pumpAndSettle();
    await aktionen.save();
    await tester.pumpAndSettle();
    gespeichert = await repo.gespeichert('demo');
    expect(gespeichert.background.herkunftsModifikatoren!.rasse, isEmpty);
    expect(gespeichert.background.rasseModText, isEmpty);
  });

  testWidgets('eine Textabweichung wird erst im Bearbeiten aufgelöst', (
    tester,
  ) async {
    final basis = herkunftZumSpeichern(
      const HeroBackground(rasseModText: 'LEP+10'),
    );
    final repo = _repo(
      held: _held(background: basis.copyWith(rasseModText: 'LEP+12')),
    );
    final aktionen = await _zeige(tester, repo);
    await _sichtbar(
      tester,
      find.byKey(const ValueKey('herkunft-abweichung-rasse')),
    );
    expect(
      find.byKey(const ValueKey('herkunft-text-uebernehmen-rasse')),
      findsNothing,
    );

    await aktionen.startEdit();
    await tester.pumpAndSettle();
    final uebernehmen = find.byKey(
      const ValueKey('herkunft-text-uebernehmen-rasse'),
    );
    await _sichtbar(tester, uebernehmen);
    await tester.tap(uebernehmen);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('herkunft-abweichung-rasse')),
      findsNothing,
    );
    await aktionen.save();
    await tester.pumpAndSettle();

    final gespeichert = await repo.gespeichert('demo');
    expect(gespeichert.background.rasseModText, 'LEP+12');
    expect(
      gespeichert.background.herkunftsModifikatoren!.rasse.single.betrag,
      12,
    );
  });

  testWidgets('Liste behalten stellt den Text wieder her', (tester) async {
    final basis = herkunftZumSpeichern(
      const HeroBackground(rasseModText: 'LEP+10'),
    );
    final repo = _repo(
      held: _held(background: basis.copyWith(rasseModText: 'LEP+12')),
    );
    final aktionen = await _zeige(tester, repo);
    await aktionen.startEdit();
    await tester.pumpAndSettle();
    final behalten = find.byKey(
      const ValueKey('herkunft-liste-behalten-rasse'),
    );
    await _sichtbar(tester, behalten);
    await tester.tap(behalten);
    await tester.pumpAndSettle();
    await aktionen.save();
    await tester.pumpAndSettle();
    final gespeichert = await repo.gespeichert('demo');
    expect(gespeichert.background.rasseModText, 'LEP+10');
  });

  testWidgets('Paralleländerung während des Editors wird nie still '
      'überschrieben', (tester) async {
    final repo = _repo();
    final aktionen = await _zeige(tester, repo);
    await aktionen.startEdit();
    await tester.pumpAndSettle();
    await _fuegeHinzu(tester, HeroHerkunft.rasse);

    // Ein anderer Weg ändert dieselbe Herkunft, bevor gespeichert wird.
    repo.fremdeAenderung = (held) {
      final basis = herkunftZumSpeichern(held.background);
      final container = basis.herkunftsModifikatoren!;
      return held.copyWith(
        background: basis.copyWith(
          rasseModText: 'LEP+99',
          herkunftsModifikatoren: container.copyWith(
            rasse: [container.rasse.first.copyWith(betrag: 99, text: 'LEP+99')],
          ),
        ),
      );
    };
    // Speichern wartet auf die Rückfrage; erst die Antwort beendet es.
    final speichern = aktionen.save();
    await tester.pumpAndSettle();

    // Der Nutzer wird gefragt statt überschrieben.
    expect(find.text('Weiter bearbeiten'), findsOneWidget);
    expect(find.text('Meine Fassung speichern'), findsOneWidget);
    expect(repo.bogenSpeicherungen, 0);
    await tester.tap(find.text('Weiter bearbeiten'));
    await tester.pumpAndSettle();
    await speichern;
    expect(repo.bogenSpeicherungen, 0);
  });

  group('Merkmalsherkunft', () {
    Future<void> trait(WidgetTester tester) async {
      await _sichtbar(
        tester,
        find.byKey(const ValueKey('overview-trait-herkunft-vorteile-0')),
      );
    }

    testWidgets('Herkunft ändern setzt und entfernt die Angabe', (
      tester,
    ) async {
      final repo = _repo();
      final aktionen = await _zeige(tester, repo);
      await aktionen.startEdit();
      await tester.pumpAndSettle();
      await trait(tester);

      await tester.tap(
        find.byKey(const ValueKey('overview-trait-herkunft-vorteile-0')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('merkmal-herkunft-kultur')));
      await tester.pumpAndSettle();
      expect(find.text('Eigener Tick · Kultur'), findsOneWidget);
      await aktionen.save();
      await tester.pumpAndSettle();
      var gespeichert = await repo.gespeichert('demo');
      expect(gespeichert.vorteilEintraege.single.herkunft, HeroHerkunft.kultur);
      expect(gespeichert.vorteileText, 'Eigener Tick');

      await aktionen.startEdit();
      await tester.pumpAndSettle();
      await trait(tester);
      await tester.tap(
        find.byKey(const ValueKey('overview-trait-herkunft-vorteile-0')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('merkmal-herkunft-nicht-angegeben')),
      );
      await tester.pumpAndSettle();
      await aktionen.save();
      await tester.pumpAndSettle();
      gespeichert = await repo.gespeichert('demo');
      expect(gespeichert.vorteilEintraege.single.herkunft, isNull);
    });

    testWidgets('Abbrechen des Dialogs ändert nichts', (tester) async {
      final repo = _repo();
      final aktionen = await _zeige(tester, repo);
      await aktionen.startEdit();
      await tester.pumpAndSettle();
      await trait(tester);
      await tester.tap(
        find.byKey(const ValueKey('overview-trait-herkunft-vorteile-0')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('merkmal-herkunft-abbrechen')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Eigener Tick'), findsOneWidget);
      await aktionen.save();
      await tester.pumpAndSettle();
      final gespeichert = await repo.gespeichert('demo');
      expect(gespeichert.vorteilEintraege.single.herkunft, isNull);
    });
  });

  group('offene Planung', () {
    // Eine Planung beginnt erst, nachdem das Bearbeiten schon läuft.
    Future<ProviderContainer> planungStarten(WidgetTester tester) async {
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HeroOverviewTab)),
      );
      container
          .read(advancementSessionProvider('demo').notifier)
          .start(hero: _held(), catalog: _katalog);
      return container;
    }

    testWidgets('Abbrechen der Rückfrage erhält Sitzung und Daten', (
      tester,
    ) async {
      final repo = _repo();
      final aktionen = await _zeige(tester, repo);
      await aktionen.startEdit();
      await tester.pumpAndSettle();
      final container = await planungStarten(tester);
      final sitzung = container.read(advancementSessionProvider('demo'));

      final knopf = find.byKey(const ValueKey('herkunft-add-rasse'));
      await _sichtbar(tester, knopf);
      await tester.tap(knopf);
      await tester.pumpAndSettle();
      expect(find.text('Geplante Entwicklung verwerfen?'), findsOneWidget);
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('herkunft-dialog-modus')), findsNothing);
      expect(container.read(advancementSessionProvider('demo')), same(sitzung));
      expect(repo.bogenSpeicherungen, 0);
    });

    testWidgets('Verwerfen erlaubt die Änderung', (tester) async {
      final repo = _repo();
      final aktionen = await _zeige(tester, repo);
      await aktionen.startEdit();
      await tester.pumpAndSettle();
      final container = await planungStarten(tester);

      final knopf = find.byKey(const ValueKey('herkunft-add-rasse'));
      await _sichtbar(tester, knopf);
      await tester.tap(knopf);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Planung verwerfen und bearbeiten'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('herkunft-dialog-modus')),
        findsOneWidget,
      );
      expect(container.read(advancementSessionProvider('demo')), isNull);
    });
  });

  testWidgets('schmale Ansicht 360 px mit Textfaktor 2 ohne Overflow', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repo = _repo();
    final aktionen = await _zeige(tester, repo, breite: 360);
    await aktionen.startEdit();
    await tester.pumpAndSettle();
    await _sichtbar(tester, find.byKey(const ValueKey('herkunft-rasse')));
    await _sichtbar(tester, find.byKey(const ValueKey('herkunft-add-rasse')));
    expect(tester.takeException(), isNull);
  });
}
