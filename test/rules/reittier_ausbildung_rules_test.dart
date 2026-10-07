import 'package:dsa_heldenverwaltung/catalog/reittier_ausbildung_katalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reittier_ausbildung_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ausbildungsregeln fuer Reittiere (ZBA S. 32–37, per dsa-rules MCP belegt).
void main() {
  const fundiert = ReittierAusbildungsart.fundiert;
  const laendlich = ReittierAusbildungsart.laendlich;
  const unerfahren = ReittierAusbildungsstufe.unerfahren;
  const erprobt = ReittierAusbildungsstufe.erprobt;
  const geschult = ReittierAusbildungsstufe.geschult;

  HeroCompanion pferd(
    ReittierAusbildung ausbildung, {
    String vorteile = '',
    String nachteile = '',
    String familie = '',
    List<HeroCompanionSonderfertigkeit> sf =
        const <HeroCompanionSonderfertigkeit>[],
  }) => HeroCompanion(
    id: 'p1',
    typ: BegleiterTyp.reittier,
    familie: familie,
    vorteile: vorteile,
    nachteile: nachteile,
    sonderfertigkeiten: sf,
    reittierAusbildung: ausbildung,
  );

  const streitross = ReittierAusbildung(
    ausgangsstufe: erprobt,
    ausgangsart: fundiert,
    varianteId: 'pvar_leichtes_streitross',
    schritte: <ReittierAusbildungsschritt>[
      ReittierAusbildungsschritt(nach: geschult, art: fundiert),
    ],
  );

  group('Stand und Modifikationen', () {
    test('ohne Schritte gilt der Ausgangsstand', () {
      const a = ReittierAusbildung(ausgangsstufe: erprobt);

      expect(aktuelleStufe(a), erprobt);
      expect(aktuelleArt(a), laendlich);
      expect(
        reittierAusbildungsModifikationen(a),
        ReittierModifikationen.keine,
      );
    });

    test('geschult als leichtes Streitross: LO +4, AT +1, TP Tritt +1', () {
      expect(aktuelleStufe(streitross), geschult);
      expect(
        reittierAusbildungsModifikationen(streitross),
        const ReittierModifikationen(lo: 4, at: 1, tpTritt: 1),
      );
      expect(
        reittierModifikationsHerkunft(streitross).map((q) => q.bezeichnung),
        <String>[
          'erprobt → geschult (fundiert)',
          'Variante Leichtes Streitross',
        ],
      );
    });

    test('laendlich von ungearbeitet bis erprobt: KK +3, LO +4, AU +2/+1', () {
      const a = ReittierAusbildung(
        schritte: <ReittierAusbildungsschritt>[
          ReittierAusbildungsschritt(nach: unerfahren, art: laendlich),
          ReittierAusbildungsschritt(nach: erprobt, art: laendlich),
        ],
      );

      expect(
        reittierAusbildungsModifikationen(a),
        const ReittierModifikationen(lo: 4, kk: 3, auTrab: 2, auGalopp: 1),
      );
    });

    test('fundiert begonnen, laendlich weitergefuehrt: halbe Werte, '
        'abgerundet', () {
      const a = ReittierAusbildung(
        ausgangsstufe: unerfahren,
        ausgangsart: fundiert,
        schritte: <ReittierAusbildungsschritt>[
          ReittierAusbildungsschritt(nach: erprobt, art: laendlich),
        ],
      );

      expect(
        reittierAusbildungsModifikationen(a),
        const ReittierModifikationen(lo: 2, kk: 1, auTrab: 1),
      );
      expect(istFundiertBegonnenLaendlichWeitergefuehrt(a), isTrue);
    });

    test('eine Ausgangsstufe „geschult“ bringt keine Variantenwerte', () {
      const a = ReittierAusbildung(
        ausgangsstufe: geschult,
        ausgangsart: fundiert,
        varianteId: 'pvar_schweres_streitross',
      );

      expect(
        reittierAusbildungsModifikationen(a),
        ReittierModifikationen.keine,
      );
      expect(istGeschultesKampfpferd(a), isTrue);
    });

    test('Unarten senken die Loyalitaet', () {
      const a = ReittierAusbildung(
        unartIds: <String>['punart_treten', 'punart_scheu', 'punart_laut'],
      );

      expect(
        reittierAusbildungsModifikationen(a),
        const ReittierModifikationen(lo: -3),
      );
    });
  });

  group('naechste Ausbildungsschritte', () {
    test('ab unerfahren gibt es den laendlichen und den fundierten Weg', () {
      final optionen = naechsteAusbildungsschritte(
        const ReittierAusbildung(ausgangsstufe: unerfahren),
      );

      expect(optionen.map((o) => o.schritt.art), <ReittierAusbildungsart>[
        laendlich,
        fundiert,
      ]);
      expect(optionen.every((o) => o.sperrgrund == null), isTrue);
    });

    test('laendlich erprobt kann fundiert geschult werden, erschwert', () {
      final option = naechsteAusbildungsschritte(
        const ReittierAusbildung(ausgangsstufe: erprobt),
      ).single;

      expect(option.schritt.nach, geschult);
      expect(option.brauchtVariante, isTrue);
      expect(option.sperrgrund, isNull);
      expect(option.hinweise.single, contains('bis zu 5'));
    });

    test('nach fundiertem Beginn und laendlicher Weiterfuehrung keine '
        'Schulung mehr', () {
      final option = naechsteAusbildungsschritte(
        const ReittierAusbildung(
          ausgangsstufe: unerfahren,
          ausgangsart: fundiert,
          schritte: <ReittierAusbildungsschritt>[
            ReittierAusbildungsschritt(nach: erprobt, art: laendlich),
          ],
        ),
      ).single;

      expect(option.sperrgrund, contains('keine weitere Schulung'));
    });

    test('ein geschultes Tier hat keinen weiteren Schritt', () {
      expect(naechsteAusbildungsschritte(streitross), isEmpty);
    });
  });

  group('Reiten-Probe (ZBA S. 35)', () {
    test('geschultes Kampfpferd: −2, im Kampf −3', () {
      final c = pferd(streitross);

      expect(reitenProbenModifikator(c, imKampf: false).erschwernis, -2);
      expect(reitenProbenModifikator(c, imKampf: true).erschwernis, -3);
    });

    test('geschult, aber kein Kampfpferd: im Kampf nur −1', () {
      final c = pferd(streitross.copyWith(varianteId: 'pvar_botenpferd'));

      expect(reitenProbenModifikator(c, imKampf: true).erschwernis, -1);
    });

    test('laendlich erprobt im Kampf: Reiten +3, Reiter +3', () {
      final m = reitenProbenModifikator(
        pferd(const ReittierAusbildung(ausgangsstufe: erprobt)),
        imKampf: true,
      );

      expect(m.erschwernis, 3);
      expect(m.reiterKampfErschwernis, 3);
    });

    test('ungearbeitet im Kampf: +6 und beide Haende am Zuegel', () {
      final m = reitenProbenModifikator(
        pferd(const ReittierAusbildung()),
        imKampf: true,
      );

      expect(m.erschwernis, 6);
      expect(m.reiterKampfErschwernis, 3);
    });

    test('Magierpferd erleichtert Zauberkundigen um 1', () {
      final c = pferd(streitross.copyWith(varianteId: 'pvar_magierpferd'));

      expect(
        reitenProbenModifikator(
          c,
          imKampf: false,
          reiterIstZauberer: true,
        ).erschwernis,
        -3,
      );
    });

    test('ohne Ausbildung oder als Vertrauter kein Modifikator', () {
      const ohne = HeroCompanion(id: 'p', typ: BegleiterTyp.reittier);
      final vertrauter = pferd(streitross)
          .copyWith(typ: BegleiterTyp.vertrauter);

      expect(reitenProbenModifikator(ohne, imKampf: true).erschwernis, 0);
      expect(reitenProbenModifikator(vertrauter, imKampf: true).erschwernis, 0);
    });
  });

  group('Pferde-SF nachtraeglich lernen (ZBA S. 36 f.)', () {
    test('allgemeine SF: Abrichten +5', () {
      final l = pferdeSfLernbarkeit(pferd(streitross), 'psf_hinlegen');

      expect(l.sperrgrund, isNull);
      expect(l.erschwernis, kPferdeSfNachtraeglichErschwernis);
      expect(l.talentId, 'tal_abrichten');
    });

    test('Kehrtwende setzt Stopp voraus', () {
      final ohne = pferdeSfLernbarkeit(pferd(streitross), 'psf_kehrtwende');
      final mit = pferdeSfLernbarkeit(
        pferd(
          streitross,
          sf: const <HeroCompanionSonderfertigkeit>[
            HeroCompanionSonderfertigkeit(
              name: 'Stopp',
              katalogId: 'psf_stopp',
            ),
          ],
        ),
        'psf_kehrtwende',
      );

      expect(ohne.sperrgrund, 'Setzt Stopp voraus.');
      expect(mit.sperrgrund, isNull);
    });

    test('Nervositaet hebt Stillstand auf +8, Lernfaehig senkt um 1', () {
      final nervoes = pferdeSfLernbarkeit(
        pferd(streitross, nachteile: 'Nervosität'),
        'psf_stillstand',
      );
      final lernfaehig = pferdeSfLernbarkeit(
        pferd(streitross, vorteile: 'Lernfaehig, Ausdauernd'),
        'psf_stillstand',
      );

      expect(nervoes.erschwernis, kPferdeSfNervositaetErschwernis);
      expect(lernfaehig.erschwernis, kPferdeSfNachtraeglichErschwernis - 1);
    });

    test('spezielle SF und zu schwere Rassen nennen alle Gruende', () {
      final l = pferdeSfLernbarkeit(
        pferd(streitross, familie: 'Tralloper Riese'),
        'psf_capriola',
      );

      expect(l.sperrgrund, contains('Ausbildungsvariante'));
      expect(l.sperrgrund, contains('Tralloper Riese'));
    });

    test('eine schon gefuehrte SF gilt auch als Freitext als erlernt', () {
      final l = pferdeSfLernbarkeit(
        pferd(
          streitross,
          sf: const <HeroCompanionSonderfertigkeit>[
            HeroCompanionSonderfertigkeit(name: 'hinlegen'),
          ],
        ),
        'psf_hinlegen',
      );

      expect(l.sperrgrund, kPferdeSfBereitsErlernt);
    });
  });

  test('Gangarten und Kraftfaktoren werden aus Texten gelesen', () {
    expect(
      reittierGangart(const HeroCompanionSpeed(art: 'Galopp', wert: 15)),
      ReittierGangart.galopp,
    );
    expect(
      reittierGangart(const HeroCompanionSpeed(art: 'zu Fuß', wert: 2)),
      isNull,
    );
    expect(kraftFaktor('x5'), 5);
    expect(kraftFaktor('×6'), 6);
    expect(kraftFaktor('14 x KK'), 14);
    expect(kraftFaktor('viel'), isNull);
  });
}
