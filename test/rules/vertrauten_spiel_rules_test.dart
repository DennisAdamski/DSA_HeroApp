// Spieltischregeln der Vertrauten (WdZ S. 124 f.): Regeneration, Vereinigung,
// Loyalität; Ritualkosten und Proben (WdZ S. 126–128).
import 'package:dsa_heldenverwaltung/catalog/vertrautenmagie_preset.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/begleiter_zustand.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/vertrauten_spiel_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/vertrauten_zauber_probe_rules.dart';
import 'package:flutter_test/flutter_test.dart';

HeroCompanion _vertrauter({
  int maxLep = 24,
  int maxAsp = 5,
  int? loyalitaet = 15,
  BegleiterTyp typ = BegleiterTyp.vertrauter,
}) => HeroCompanion(
  id: 'v',
  name: 'Mira',
  typ: typ,
  maxLep: maxLep,
  startLep: maxLep,
  maxAsp: maxAsp,
  startAsp: maxAsp,
  loyalitaet: loyalitaet,
  kl: 6,
  inn: 7,
  ch: 9,
  mu: 8,
);

const _leer = HeroState(
  currentLep: 10,
  currentAsp: 12,
  currentKap: 0,
  currentAu: 10,
);

HeroSheet _hexe(HeroCompanion c) => HeroSheet(
  id: 'h',
  name: 'Hexe',
  level: 1,
  attributes: const Attributes(
    mu: 12,
    kl: 12,
    inn: 12,
    ch: 12,
    ff: 12,
    ge: 12,
    ko: 12,
    kk: 12,
  ),
  companions: [c],
);

void main() {
  group('Regeneration (WdZ S. 125)', () {
    test('ein aufgerundetes Zehntel der Maxima je Phase', () {
      expect(vertrautenRegenerationJePhase(24), 3);
      expect(vertrautenRegenerationJePhase(11), 2);
      expect(vertrautenRegenerationJePhase(10), 1);
      expect(vertrautenRegenerationJePhase(1), 1);
      expect(vertrautenRegenerationJePhase(0), 0);
      final z = vertrautenRegeneration(_vertrauter(), phasen: 2);
      expect((z.lep, z.asp), (6, 2));
    });

    test('Körperkontakt bringt einen LeP oder einen AsP zusätzlich', () {
      final lep = vertrautenRegeneration(_vertrauter(), koerperkontakt: true);
      expect((lep.lep, lep.asp), (4, 1));
      final asp = vertrautenRegeneration(
        _vertrauter(),
        koerperkontakt: true,
        wahl: KontaktBonus.asp,
      );
      expect((asp.lep, asp.asp), (3, 2));
    });

    test('ohne Astralenergie entfällt der AsP-Bonus', () {
      final z = vertrautenRegeneration(
        _vertrauter(maxAsp: 0),
        koerperkontakt: true,
        wahl: KontaktBonus.asp,
      );
      expect((z.lep, z.asp), (3, 0));
    });

    test('heilt höchstens bis zum Maximum und lässt Volle unberührt', () {
      final c = _vertrauter();
      final verletzt = _leer.withBegleiterZustand(
        'v',
        const BegleiterZustand(currentLep: 5, currentAsp: 4),
      );
      final nach = mitVertrautenRegeneration(verletzt, c, phasen: 1);
      expect(nach.begleiterZustaende['v']!.currentLep, 8);
      expect(nach, isNot(same(verletzt)));
      // AsP 4 + 1 = 5 ist voll und entfällt.
      expect(nach.begleiterZustaende['v']!.currentAsp, isNull);

      final knapp = _leer.withBegleiterZustand(
        'v',
        const BegleiterZustand(currentLep: 23),
      );
      expect(
        mitVertrautenRegeneration(knapp, c, phasen: 3).begleiterZustaende,
        isEmpty,
      );
      expect(identical(mitVertrautenRegeneration(_leer, c), _leer), isTrue);
    });

    test('mehrere Vertraute und Fremdes in der Rast', () {
      final c = _vertrauter();
      final start = _leer.withBegleiterZustand(
        'v',
        const BegleiterZustand(currentLep: 1),
      );
      final nach = mitVertrautenRast(start, _hexe(c), const [
        VertrautenRast(begleiterId: 'v', koerperkontakt: true),
        VertrautenRast(begleiterId: 'weg'),
      ], phasen: 1);
      expect(nach.begleiterZustaende['v']!.currentLep, 5);
      expect(nach.currentAsp, 12);
      expect(
        identical(
          mitVertrautenRast(start, _hexe(c), const [
            VertrautenRast(begleiterId: 'v'),
          ], phasen: 0),
          start,
        ),
        isTrue,
      );
      final reittier = _vertrauter(typ: BegleiterTyp.reittier);
      expect(
        identical(
          mitVertrautenRast(start, _hexe(reittier), const [
            VertrautenRast(begleiterId: 'v'),
          ], phasen: 1),
          start,
        ),
        isTrue,
      );
    });
  });

  group('Vereinigung und Loyalität (WdZ S. 125)', () {
    test('der Verlust ist der Wurf, höchstens der Vorrat', () {
      expect(vertrautenVereinigungsVerlust(aktuell: 12, wurf: 4), 4);
      expect(vertrautenVereinigungsVerlust(aktuell: 2, wurf: 6), 2);
      expect(vertrautenVereinigungsVerlust(aktuell: -3, wurf: 6), 0);
    });

    test('ein versäumtes Treffen kostet 1 LeP und 1 LO', () {
      final c = _vertrauter();
      final z = mitVersaeumtemTreffenLep(_leer, c);
      expect(z.begleiterZustaende['v']!.currentLep, 23);
      final held = mitVersaeumtemTreffenLo(
        _hexe(c),
        begleiterId: 'v',
        erwarteteLoyalitaet: 15,
      );
      expect(held.companions.single.loyalitaet, 14);
      expect(
        () => mitVersaeumtemTreffenLo(
          held,
          begleiterId: 'v',
          erwarteteLoyalitaet: 15,
        ),
        throwsStateError,
      );
    });

    test('LO +1 höchstens bis 25, nur bei unverändertem Stand', () {
      final held = _hexe(_vertrauter(loyalitaet: 24));
      final plus = mitLoyalitaetPlusEins(
        held,
        begleiterId: 'v',
        erwarteteLoyalitaet: 24,
      );
      expect(plus.companions.single.loyalitaet, 25);
      expect(
        () => mitLoyalitaetPlusEins(
          plus,
          begleiterId: 'v',
          erwarteteLoyalitaet: 25,
        ),
        throwsStateError,
      );
      expect(
        () => mitLoyalitaetPlusEins(
          held,
          begleiterId: 'v',
          erwarteteLoyalitaet: 20,
        ),
        throwsStateError,
      );
    });
  });

  group('Ritualkosten lesen', () {
    test('alle Preset-Texte', () {
      VertrautenRitualKosten k(String text) => parseRitualKosten(text)!;
      expect((k('3 AsP').grund, k('3 AsP').jeSpielrunde), (3, 0));
      expect(
        (
          k('2 AsP pro Spielrunde').grund,
          k('2 AsP pro Spielrunde').jeSpielrunde,
        ),
        (0, 2),
      );
      final tiersinne = k('3 AsP + 2 AsP pro Spielrunde');
      expect((tiersinne.grund, tiersinne.jeSpielrunde), (3, 2));
      expect(tiersinne.gesamt(spielrunden: 4), 11);
      expect(k('Alle AsP, siehe oben').alleAsp, isTrue);
      expect(k('Alle AsP').gesamt(vorrat: 9), 9);
      expect(parseRitualKosten('nach Absprache'), isNull);
      expect(parseRitualKosten(''), isNull);
    });

    test('jedes Ritual des Presets ist lesbar', () {
      for (final r in kVertrautenmagiePresetCategory.rituals) {
        expect(parseRitualKosten(r.kosten), isNotNull, reason: r.name);
      }
    });
  });

  group('Ritualprobe', () {
    HeroRitualEntry ritual(String name) => kVertrautenmagiePresetCategory
        .rituals
        .firstWhere((r) => r.name == name);
    final kategorie = kVertrautenmagiePresetCategory;
    const hexeWerte = Attributes(
      mu: 13,
      kl: 14,
      inn: 15,
      ch: 16,
      ff: 10,
      ge: 11,
      ko: 12,
      kk: 9,
    );

    test('in Kontakt: Eigenschaften der Hexe, RK des Vertrauten', () {
      final probe = vertrautenRitualProbe(
        vertrauter: _vertrauter().copyWith(steigerungen: const {'rk': 2}),
        kategorie: kategorie,
        ritual: ritual('Tiersinne'),
        hexeProbenEigenschaften: hexeWerte,
        koerperkontakt: true,
      )!;
      expect(probe.targets.map((t) => (t.label, t.value)), [
        ('KL', 14),
        ('IN', 15),
        ('IN', 15),
      ]);
      expect(probe.basePool, 5, reason: 'RK 3 + 2 Steigerungen');
      expect(probe.initialSituationalModifier, 0);
    });

    test('allein: Eigenschaften des Vertrauten und 15 Erleichterung', () {
      final probe = vertrautenRitualProbe(
        vertrauter: _vertrauter(),
        kategorie: kategorie,
        ritual: ritual('Tiersinne'),
        hexeProbenEigenschaften: hexeWerte,
        koerperkontakt: false,
      )!;
      expect(probe.targets.map((t) => t.value), [6, 7, 7]);
      expect(probe.initialSituationalModifier, 15);
      expect(probe.subtitle, contains('allein'));
    });

    test('ohne Ritualprobe gibt es keine Anfrage', () {
      expect(
        vertrautenRitualProbe(
          vertrauter: _vertrauter(),
          kategorie: kategorie,
          ritual: const HeroRitualEntry(name: 'Frei'),
          hexeProbenEigenschaften: hexeWerte,
          koerperkontakt: true,
        ),
        isNull,
      );
    });

    test('KL- und LO-Probe nehmen die wirksamen Werte des Tiers', () {
      expect(vertrautenKlProbe(_vertrauter()).targets.single.value, 6);
      expect(vertrautenLoProbe(_vertrauter()).targets.single.value, 15);
      expect(vertrautenChProbe(hexeWerte).targets.single.value, 16);
    });
  });
}
