import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/spell_def.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_magie_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung_uebersicht_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/zauber_herleitung_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import '../test_support/hero_fixtures.dart';
import '../test_support/real_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EchterKatalog katalog;

  setUpAll(() async {
    katalog = await ladeEchtenRegelkatalog();
  });

  const spell = SpellDef(
    id: 'spell_test',
    name: 'Testzauber',
    tradition: 'Gildenmagie',
    steigerung: 'C',
    attributes: <String>['KL', 'IN', 'CH'],
  );

  HeroComputedSnapshot snapshot(Map<String, HeroSpellEntry> zauber) {
    final bundle = ladeBestandsheld(Bestandsheld.geodeMagisch);
    return buildHeroComputedSnapshot(
      hero: bundle.hero.copyWith(spells: zauber),
      state: bundle.state,
      catalog: katalog.catalog,
      epicAdvantagesActive: false,
    );
  }

  group('herleiteZfw', () {
    test('ZfW* ist ZfW plus Modifikator, beide als Schritte', () {
      final h = herleiteZfw(const HeroSpellEntry(spellValue: 9, modifier: -2));
      expect(h.wert, 7);
      expect(h.sichtbareSchritte.map((s) => s.bezeichnung), [
        kZfwSchritt,
        kZfwModifikatorSchritt,
      ]);
    });

    test('ohne Modifikator bleibt nur der ZfW sichtbar', () {
      final h = herleiteZfw(const HeroSpellEntry(spellValue: 5));
      expect(h.sichtbareSchritte.map((s) => s.bezeichnung), [kZfwSchritt]);
    });
  });

  group('zauberProbenwertFuer', () {
    test('liefert Probenwerte der Kette und ZfW*', () {
      final s = snapshot({
        'spell_test': const HeroSpellEntry(spellValue: 8, modifier: 1),
      });
      final wert = zauberProbenwertFuer(snapshot: s, spell: spell)!;
      expect(wert.zfw, 9);
      expect(wert.ziele.map((z) => z.label), ['KL', 'IN', 'CH']);
      expect(wert.ziele[0].value, s.probenEigenschaften.kl);
      expect(wert.ziele[1].value, s.probenEigenschaften.inn);
      expect(wert.ziele[2].value, s.probenEigenschaften.ch);
    });

    test('Wundverluste senken die Probenwerte', () {
      final s = snapshot({'spell_test': const HeroSpellEntry(spellValue: 8)});
      final verletzt = zauberProbenwertAus(
        eintrag: s.hero.spells['spell_test']!,
        spell: spell,
        probenEigenschaften: s.probenEigenschaften.copyWith(
          kl: s.probenEigenschaften.kl - 2,
        ),
      )!;
      expect(verletzt.ziele[0].value, s.probenEigenschaften.kl - 2);
    });

    test('ohne ZfW, ohne Eintrag oder mit unklarer Kette keine Probe', () {
      expect(
        zauberProbenwertFuer(
          snapshot: snapshot({'spell_test': const HeroSpellEntry()}),
          spell: spell,
        ),
        isNull,
      );
      expect(
        zauberProbenwertFuer(snapshot: snapshot({}), spell: spell),
        isNull,
      );
      const kaputt = SpellDef(
        id: 'spell_test',
        name: 'Kaputt',
        tradition: 'x',
        steigerung: 'C',
        attributes: <String>['KL', 'Zorn', 'CH'],
      );
      expect(
        zauberProbenwertAus(
          eintrag: const HeroSpellEntry(spellValue: 5),
          spell: kaputt,
          probenEigenschaften: const Attributes.zero(),
        ),
        isNull,
      );
    });

    test('Gefecht und Suche würfeln dieselbe Zauberprobe', () {
      final s = snapshot({
        'spell_test': const HeroSpellEntry(spellValue: 8, modifier: 1),
      });
      final wert = zauberProbenwertFuer(snapshot: s, spell: spell)!;
      final gefecht = gefechtsZauberprobe(s, spell)!;
      final suche = zauberprobeAus(wert: wert, titel: spell.name);
      expect(gefecht.basePool, suche.basePool);
      expect(
        gefecht.targets.map((t) => (t.label, t.value)),
        suche.targets.map((t) => (t.label, t.value)),
      );
    });
  });

  group('Übersicht', () {
    test('aktivierte Zauber stehen als letzter Bereich und sind suchbar', () {
      final spells = katalog.catalog.spells.take(2).toList();
      final s = snapshot({
        spells[0].id: const HeroSpellEntry(spellValue: 7, modifier: 2),
        spells[1].id: const HeroSpellEntry(),
      });
      final zauber = sammleZauberHerleitungen(
        snapshot: s,
        zauber: katalog.catalog.spells,
      );
      expect(zauber.map((z) => z.id), [spells[0].id]);
      final eintraege = sammleHerleitungen(
        eigenschaften: s.eigenschaftHerleitungen,
        basiswerte: s.derivedStats.herleitungen,
        kampf: s.combatPreviewStats,
        zauber: zauber,
      );
      final bereiche = eintraege.map((e) => e.bereich.index).toList();
      expect(bereiche, orderedEquals(List<int>.of(bereiche)..sort()));
      final eintrag = eintraege.singleWhere(
        (e) => e.id == 'zauber-${spells[0].id}',
      );
      expect(eintrag.bereich, HerleitungsBereich.zauber);
      expect(eintrag.ergebnisText, '9');
      expect(
        filtereHerleitungen(eintraege, 'zauber modifikator').map((e) => e.id),
        contains('zauber-${spells[0].id}'),
      );
    });
  });
}
