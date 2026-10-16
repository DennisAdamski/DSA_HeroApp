import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung_uebersicht_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import '../test_support/hero_fixtures.dart';
import '../test_support/real_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EchterKatalog katalog;

  setUpAll(() async {
    katalog = await ladeEchtenRegelkatalog();
  });

  List<HerleitungsEintrag> eintraegeFuer(
    Bestandsheld bestand, {
    bool axxeleratus = false,
  }) {
    final bundle = ladeBestandsheld(bestand);
    final zustand = axxeleratus
        ? bundle.state.copyWith(
            activeSpellEffects: const ActiveSpellEffectsState(
              activeEffectIds: <String>[activeSpellEffectAxxeleratus],
            ),
          )
        : bundle.state;
    final snapshot = buildHeroComputedSnapshot(
      hero: bundle.hero,
      state: zustand,
      catalog: katalog.catalog,
      epicAdvantagesActive: true,
    );
    return sammleHerleitungen(
      eigenschaften: snapshot.eigenschaftHerleitungen,
      basiswerte: snapshot.derivedStats.herleitungen,
      kampf: snapshot.combatPreviewStats,
      astral: snapshot.resourceActivation.magic.isEnabled,
      karmal: snapshot.resourceActivation.divine.isEnabled,
    );
  }

  test('sammelt Eigenschaften, Basiswerte und Kampf in fester Ordnung', () {
    final eintraege = eintraegeFuer(Bestandsheld.kriegerNormal);
    final ids = eintraege.map((e) => e.id).toList();
    expect(ids.take(8), <String>[
      'eigenschaft-mu',
      'eigenschaft-kl',
      'eigenschaft-inn',
      'eigenschaft-ch',
      'eigenschaft-ff',
      'eigenschaft-ge',
      'eigenschaft-ko',
      'eigenschaft-kk',
    ]);
    expect(
      ids,
      containsAll(<String>['basiswert-lep', 'kampf-at', 'kampf-ini']),
    );
    final bereiche = eintraege.map((e) => e.bereich.index).toList();
    expect(bereiche, orderedEquals(List<int>.of(bereiche)..sort()));
  });

  test('AsP erscheinen nur bei aktivierter Astralenergie', () {
    final ids = eintraegeFuer(Bestandsheld.kriegerNormal).map((e) => e.id);
    expect(ids, isNot(contains('basiswert-asp')));
    final magier = eintraegeFuer(Bestandsheld.geodeMagisch).map((e) => e.id);
    expect(magier, contains('basiswert-asp'));
  });

  test('jeder Eintrag zeigt den Wert seiner Herleitung', () {
    for (final eintrag in eintraegeFuer(Bestandsheld.kriegerNormal)) {
      if (eintrag.id.endsWith('-tp')) {
        continue;
      }
      expect(eintrag.ergebnisText, '${eintrag.herleitung.wert}');
    }
  });

  group('Suche', () {
    test('leer liefert alles', () {
      final eintraege = eintraegeFuer(Bestandsheld.kriegerNormal);
      expect(filtereHerleitungen(eintraege, '  '), same(eintraege));
    });

    test('findet Schritte über Bezeichnung und Bedingung', () {
      final eintraege = eintraegeFuer(
        Bestandsheld.kriegerNormal,
        axxeleratus: true,
      );
      final treffer = filtereHerleitungen(eintraege, 'axxeleratus');
      final ids = treffer.map((e) => e.id).toSet();
      expect(ids, containsAll(<String>['kampf-pa', 'kampf-ausweichen']));
      for (final eintrag in treffer) {
        final text = eintrag.herleitung.sichtbareSchritte
            .map((s) => '${s.bezeichnung} ${s.bedingung ?? ''}')
            .join(' ')
            .toLowerCase();
        expect(
          text.contains('axxeleratus') ||
              eintrag.titel.toLowerCase().contains('axxeleratus'),
          isTrue,
          reason: eintrag.id,
        );
      }
    });

    test('mehrere Begriffe müssen alle vorkommen', () {
      final eintraege = eintraegeFuer(Bestandsheld.kriegerNormal);
      final nurKampf = filtereHerleitungen(eintraege, 'kampf parade');
      expect(nurKampf.map((e) => e.id), contains('kampf-pa'));
      expect(
        nurKampf.every((e) => e.bereich == HerleitungsBereich.kampf),
        isTrue,
      );
      expect(filtereHerleitungen(eintraege, 'parade xyzunbekannt'), isEmpty);
    });

    test('findet Werte über ihre Quelle', () {
      final eintraege = eintraegeFuer(Bestandsheld.kriegerNormal);
      final treffer = filtereHerleitungen(eintraege, 'basiswert');
      expect(treffer, isNotEmpty);
      for (final eintrag in treffer) {
        final passt =
            eintrag.bereich == HerleitungsBereich.basiswerte ||
            eintrag.titel.toLowerCase().contains('basiswert') ||
            eintrag.herleitung.sichtbareSchritte.any(
              (s) => s.quelle == 'Basiswert',
            );
        expect(passt, isTrue, reason: eintrag.id);
      }
    });
  });

  test('Nebenhandwaffe erscheint als eigener Bereich', () {
    final bundle = ladeBestandsheld(Bestandsheld.kriegerNormal);
    final held = bundle.hero.copyWith(
      combatConfig: const CombatConfig(
        weapons: <MainWeaponSlot>[
          MainWeaponSlot(name: 'Schwert'),
          MainWeaponSlot(name: 'Dolch'),
        ],
        selectedWeaponIndex: 0,
        offhandAssignment: OffhandAssignment(weaponIndex: 1),
      ),
    );
    final snapshot = buildHeroComputedSnapshot(
      hero: held,
      state: bundle.state,
      catalog: katalog.catalog,
      epicAdvantagesActive: true,
    );
    final eintraege = sammleHerleitungen(kampf: snapshot.combatPreviewStats);
    final neben = eintraege
        .where((e) => e.bereich == HerleitungsBereich.nebenhand)
        .toList();
    expect(neben.map((e) => e.id), contains('nebenhand-at'));
    expect(neben.first.titel, contains('Dolch'));
    expect(
      neben.first.herleitung.schritte.any(
        (s) => s.art == HerleitungsArt.grundwert,
      ),
      isTrue,
    );
  });
}
