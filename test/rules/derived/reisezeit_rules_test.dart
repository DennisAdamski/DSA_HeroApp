import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/avesmaps_route.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reise_station.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_unterwegs.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reiseroute_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reisezeit_rules.dart';

HeroAdventureDateValue _d(String tag, String monat, [String jahr = '1043']) =>
    HeroAdventureDateValue(day: tag, month: monat, year: jahr);

AvesmapsRoute _weg(List<AvesmapsRoutenEtappe> etappen) => AvesmapsRoute(
  gefunden: true,
  meilen: etappen.fold<double>(0, (a, e) => a + e.meilen),
  reisetage: 4,
  etappen: etappen,
);

HeroSheet _held({
  List<HeroAdventureEntry> adventures = const <HeroAdventureEntry>[],
  List<HeroReiseStation> stationen = const <HeroReiseStation>[],
  List<HeroCompanion> begleiter = const <HeroCompanion>[],
}) => HeroSheet(
  id: 'held-1',
  name: 'Testheld',
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
  adventures: adventures,
  reiseStationen: stationen,
  companions: begleiter,
);

final DateTime _jetzt = DateTime.utc(2026, 11, 21);

void main() {
  group('Tagesstrecke (Basisregelwerk S. 192, Geographia S. 123)', () {
    test('zu Fuß 30/45, beritten 40/60, Fuhrwerk und Kutsche ×1,25', () {
      expect(reiseTagesstrecke(kReiseMittelFuss, eil: false), 30);
      expect(reiseTagesstrecke(kReiseMittelFuss, eil: true), 45);
      expect(reiseTagesstrecke(kReiseMittelBeritten, eil: false), 40);
      expect(reiseTagesstrecke(kReiseMittelBeritten, eil: true), 60);
      expect(reiseTagesstrecke(kReiseMittelFuhrwerk, eil: false), 30);
      expect(reiseTagesstrecke(kReiseMittelFuhrwerk, eil: true), 37.5);
      expect(reiseTagesstrecke(kReiseMittelKutsche, eil: false), 50);
      expect(reiseTagesstrecke(kReiseMittelKutsche, eil: true), 62.5);
      expect(reiseTagesstrecke('sanfte', eil: false), 30);
    });
  });

  group('reisezeitPlan', () {
    test('Gelände und Wetter multiplizieren, Herleitung je Wegart', () {
      final plan = reisezeitPlan(
        weg: _weg(const <AvesmapsRoutenEtappe>[
          AvesmapsRoutenEtappe(art: 'Reichsstrasse', meilen: 60),
          AvesmapsRoutenEtappe(art: 'Reichsstrasse', meilen: 60),
          AvesmapsRoutenEtappe(art: 'Weg', meilen: 24),
        ]),
        wetter: 'leicht',
      );
      // 120 ÷ (30 × 1,1 × 0,9) = 4,04; 24 ÷ (30 × 0,8 × 0,9) = 1,11.
      expect(plan.zeilen, hasLength(2));
      expect(
        plan.zeilen.first.text,
        'Reichsstraße 120 Meilen ÷ (30 × 1,1 × 0,9) = 4,0 Tage',
      );
      expect(
        plan.zeilen.last.text,
        'Weg 24 Meilen ÷ (30 × 0,8 × 0,9) = 1,1 Tage',
      );
      expect(plan.tage, closeTo(5.15, .01));
      expect(plan.ganzeTage, 6);
      expect(plan.meilen, 144);
    });

    test('Beispiel aus dem Basisregelwerk: Eilmarsch auf dem Karrenweg', () {
      // 45 × 0,8 = 36 Meilen am Tag bei gutem Wetter.
      final plan = reisezeitPlan(
        weg: _weg(const <AvesmapsRoutenEtappe>[
          AvesmapsRoutenEtappe(art: 'Weg', meilen: 36),
        ]),
        tempo: kReiseTempoEil,
      );
      expect(plan.tage, closeTo(1, 1e-9));
      expect(plan.ganzeTage, 1);
      expect(plan.hinweise, contains(contains('jeden zweiten Tag')));
    });

    test('Eile gilt nur auf befestigten Wegen', () {
      final plan = reisezeitPlan(
        weg: _weg(const <AvesmapsRoutenEtappe>[
          AvesmapsRoutenEtappe(art: 'Strasse', meilen: 45),
          AvesmapsRoutenEtappe(art: 'Pfad', meilen: 24),
        ]),
        tempo: kReiseTempoEil,
      );
      // Straße 45 ÷ 45 = 1; Pfad 24 ÷ (30 × 0,8) = 1.
      expect(plan.tage, closeTo(2, 1e-9));
      expect(plan.hinweise, contains(contains('befestigten Wegen')));
    });

    test('Sturm und heftiger Regen vereiteln den Eilmarsch', () {
      final plan = reisezeitPlan(
        weg: _weg(const <AvesmapsRoutenEtappe>[
          AvesmapsRoutenEtappe(art: 'Strasse', meilen: 21),
        ]),
        tempo: kReiseTempoEil,
        wetter: 'dauerregen',
      );
      // 21 ÷ (30 × 0,7) = 1.
      expect(plan.tage, closeTo(1, 1e-9));
      expect(plan.hinweise.first, contains('vereitelt'));
    });

    test('Fuhrwerk und Kutsche fahren abseits der Straßen wie zu Fuß', () {
      final plan = reisezeitPlan(
        weg: _weg(const <AvesmapsRoutenEtappe>[
          AvesmapsRoutenEtappe(art: 'Strasse', meilen: 50),
          AvesmapsRoutenEtappe(art: 'querfeldein', meilen: 22.5),
        ]),
        mittel: kReiseMittelKutsche,
      );
      // Straße 50 ÷ 50 = 1; querfeldein 22,5 ÷ (30 × 0,75) = 1.
      expect(plan.tage, closeTo(2, 1e-9));
    });

    test('Wasser mit fester Tagesstrecke, Umsteigen zu Fuß', () {
      final plan = reisezeitPlan(
        weg: _weg(const <AvesmapsRoutenEtappe>[
          AvesmapsRoutenEtappe(art: 'Flussweg', meilen: 60),
          AvesmapsRoutenEtappe(art: 'Umsteigen', meilen: 3),
          AvesmapsRoutenEtappe(art: 'Seeweg', meilen: 240),
        ]),
        mittel: kReiseMittelBeritten,
        wetter: 'hitze',
      );
      // Fluss 60 ÷ 30 = 2; See 240 ÷ 120 = 2; Umsteigen 3 ÷ (30 × 0,8).
      expect(plan.tage, closeTo(4.125, 1e-9));
      expect(plan.zeilen.first.text, 'Fluss 60 Meilen ÷ 30 = 2,0 Tage');
      expect(plan.hinweise, contains(contains('auf dem Wasser')));
    });

    test('unbekannte Wegart zählt wie Straße und wird genannt', () {
      final plan = reisezeitPlan(
        weg: _weg(const <AvesmapsRoutenEtappe>[
          AvesmapsRoutenEtappe(art: 'Teleport', meilen: 30),
        ]),
      );
      expect(plan.tage, closeTo(1, 1e-9));
      expect(plan.hinweise.single, contains('Teleport'));
    });

    test('ohne Etappen gilt die Strecke als Straße', () {
      final plan = reisezeitPlan(
        weg: const AvesmapsRoute(gefunden: true, meilen: 60),
      );
      expect(plan.tage, closeTo(2, 1e-9));
      expect(plan.gespeicherteTage, 2);
    });
  });

  group('Datum und Vorschläge', () {
    test('Ankunft über Monats- und Jahresgrenzen', () {
      expect(
        reiseDatumPlus(_d('28', 'rahja'), 4)!.anzeigeText,
        '2. Namenlose Tage 1043 BF',
      );
      expect(reiseDatumPlus(_d('4', 'namenlose_tage'), 3)!.day, '2');
      expect(reiseDatumPlus(const HeroAdventureDateValue(), 3), isNull);
      expect(
        reiseTageZwischenDaten(_d('28', 'rahja'), _d('2', 'praios', '1044')),
        9,
      );
    });

    test('Reittier belegt beritten vor', () {
      expect(reisemittelVorschlag(_held()), kReiseMittelFuss);
      expect(
        reisemittelVorschlag(
          _held(
            begleiter: const <HeroCompanion>[
              HeroCompanion(id: 'r', typ: BegleiterTyp.reittier),
            ],
          ),
        ),
        kReiseMittelBeritten,
      );
    });

    test('Abreise aus dem laufenden Abenteuer, sonst letzte Station', () {
      final mitAbenteuer = _held(
        adventures: <HeroAdventureEntry>[
          HeroAdventureEntry(id: 'a', currentAventurianDate: _d('7', 'boron')),
        ],
      );
      expect(reiseAbreiseVorschlag(mitAbenteuer).day, '7');
      final ohne = _held(
        stationen: <HeroReiseStation>[
          HeroReiseStation(id: 's1', ort: 'A', datum: _d('3', 'efferd')),
          HeroReiseStation(id: 's2', ort: 'B', datum: _d('9', 'efferd')),
        ],
      );
      expect(reiseAbreiseVorschlag(ohne).day, '9');
    });
  });

  group('reiseAntreten', () {
    const von = ReiseOrt(name: 'Gareth', ortId: 'g', kartenX: 1, kartenY: 2);
    const nach = ReiseOrt(name: 'Punin', ortId: 'p', kartenX: 3, kartenY: 4);
    final anreise = HeroReiseAnreise(
      abreise: _d('1', 'boron'),
      mittel: kReiseMittelFuss,
      geplanteTage: 5.15,
      meilen: 144,
    );

    test('legt Ausgangs- und Ankunftsstation an, setzt das Abenteuerdatum', () {
      final held = reiseAntreten(
        held: _held(
          adventures: <HeroAdventureEntry>[
            HeroAdventureEntry(
              id: 'a',
              currentAventurianDate: _d('1', 'boron'),
            ),
          ],
        ),
        von: von,
        nach: nach,
        anreise: anreise,
        ankunft: _d('7', 'boron'),
        adventureId: 'a',
        ausgangsId: 'aus',
        zielId: 'ziel',
        jetzt: _jetzt,
        abenteuerDatumSetzen: true,
      );
      final sortiert = sortiereReiseStationen(held.reiseStationen);
      expect(sortiert.map((s) => s.id), <String>['aus', 'ziel']);
      expect(sortiert.first.ort, 'Gareth');
      expect(sortiert.first.datum.day, '1');
      expect(sortiert.first.ortId, 'g');
      expect(sortiert.last.anreise!.geplanteTage, 5.15);
      expect(sortiert.last.adventureId, 'a');
      expect(held.adventures.single.currentAventurianDate.day, '7');
    });

    test('keine zweite Ausgangsstation, fehlender Verweis wird ergänzt', () {
      final held = reiseAntreten(
        held: _held(
          stationen: <HeroReiseStation>[
            HeroReiseStation(id: 's1', ort: 'gareth', datum: _d('1', 'boron')),
          ],
        ),
        von: von,
        nach: nach,
        anreise: anreise,
        ankunft: _d('7', 'boron'),
        adventureId: '',
        ausgangsId: 'aus',
        zielId: 'ziel',
        jetzt: _jetzt,
      );
      expect(held.reiseStationen.map((s) => s.id), <String>['s1', 'ziel']);
      expect(held.reiseStationen.first.ortId, 'g');
    });

    test('Ist und Plan nebeneinander', () {
      final held = reiseAntreten(
        held: _held(),
        von: von,
        nach: nach,
        anreise: anreise,
        ankunft: _d('10', 'boron'),
        adventureId: '',
        ausgangsId: 'aus',
        zielId: 'ziel',
        jetzt: _jetzt,
      );
      final etappe = reiseEtappen(held.reiseStationen).last;
      expect(reisePlanVergleichText(etappe), 'Plan 6 Tage · 3 Tage länger');
      expect(reisePlanText(etappe.station.anreise), 'Plan 6 Tage · zu Fuß');
    });
  });

  group('Unterwegs', () {
    final unterwegs = HeroUnterwegs(
      ziel: 'Punin',
      vonOrt: 'Gareth',
      vonKartenX: 0,
      vonKartenY: 0,
      zielKartenX: 100,
      zielKartenY: 0,
      anreise: HeroReiseAnreise(abreise: _d('1', 'boron'), geplanteTage: 4),
    );

    test('Reisetag, Anteil und Lage auf der Luftlinie', () {
      final lage = unterwegsLage(unterwegs, heute: _d('3', 'boron'));
      expect(lage.tag, 3);
      expect(lage.text, 'Tag 3 von 4');
      expect(lage.anteil, .5);
      expect(lage.kartenX, 50);
      expect(lage.kartenY, 0);
    });

    test('Lage folgt der Linie nach Länge', () {
      final lage = unterwegsLage(
        unterwegs,
        heute: _d('3', 'boron'),
        linie: const <(double, double)>[(0, 0), (0, 30), (40, 30)],
      );
      // Länge 70, Hälfte 35: 5 Einheiten nach dem Knick.
      expect(lage.kartenX, closeTo(5, 1e-9));
      expect(lage.kartenY, closeTo(30, 1e-9));
    });

    test('über dem Plan und ohne Datum', () {
      expect(
        unterwegsLage(unterwegs, heute: _d('5', 'boron')).text,
        'Tag 5 · Ankunft erwartet',
      );
      expect(
        unterwegsLage(unterwegs, heute: _d('8', 'boron')).text,
        'Tag 8 · 3 Tage über Plan',
      );
      expect(
        unterwegsLage(unterwegs, heute: const HeroAdventureDateValue()).text,
        'Plan 4 Tage',
      );
    });

    test('Anhalten legt eine Rast ohne Plan an', () {
      final lage = unterwegsLage(unterwegs, heute: _d('3', 'boron'));
      final held = reiseUnterwegsAnhalten(
        held: _held(),
        u: unterwegs,
        lage: lage,
        heute: _d('3', 'boron'),
        ausgangsId: 'aus',
        rastId: 'rast',
        jetzt: _jetzt,
      );
      final rast = held.reiseStationen.last;
      expect(held.reiseStationen.first.ort, 'Gareth');
      expect(rast.ort, 'Rast zwischen Gareth und Punin');
      expect(rast.kartenX, 50);
      expect(rast.ortId, isEmpty);
      expect(rast.anreise!.geplanteTage, isNull);
      expect(rast.anreise!.abreise.day, '1');
    });
  });
}
