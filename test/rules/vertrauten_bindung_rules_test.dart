import 'package:dsa_heldenverwaltung/catalog/vertrauten_typen.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/vertrauten_bindung_rules.dart';
import 'package:flutter_test/flutter_test.dart';

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

HeroSheet _hexe({List<HeroCompanion>? begleiter, int apTotal = 1000}) =>
    HeroSheet(
      id: 'hexe',
      name: 'Hexe',
      level: 1,
      apTotal: apTotal,
      apSpent: 500,
      apAvailable: apTotal - 500,
      attributes: _attribute,
      companions:
          begleiter ??
          const [
            HeroCompanion(id: 'v', name: 'Mira', typ: BegleiterTyp.vertrauter),
          ],
    );

void main() {
  group('vertrautenBindungskosten (WdZ S. 123 f.)', () {
    test('Katze ohne Zusatzpunkte kostet 80 AP', () {
      expect(
        vertrautenBindungskosten(
          const VertrautenGenerierung(artId: 'vart_katze'),
        ).summe,
        80,
      );
    });

    test('Kröte 100 AP, je Punkt 2 AP, AsP/LeP 5 AP, AuP 2 AP', () {
      final kosten = vertrautenBindungskosten(
        const VertrautenGenerierung(
          artId: 'vart_kroete',
          punkte: {'kl': 3, 'inn': 2},
          zusatzAsp: 3,
          zusatzLep: 1,
          zusatzAup: 2,
        ),
      );
      expect(kosten.grundkosten, 100);
      expect(kosten.punkte, 10);
      expect(kosten.zusatzpunkte, 24);
      expect(kosten.summe, 134);
    });

    test('Machtvoller Vertrauter: 120 AP und 5 AP je Punkt über Maximum', () {
      final kosten = vertrautenBindungskosten(
        const VertrautenGenerierung(
          artId: 'vart_katze',
          machtvoll: true,
          // MU 7 + 4 = 11, Maximum 9: zwei Punkte darüber.
          punkte: {'mu': 4},
        ),
      );
      expect(kosten.grundkosten, 120);
      expect(kosten.punkte, 8);
      expect(kosten.ueberMaximum, 10);
      expect(kosten.summe, 138);
    });
  });

  group('vertrautenGenerierungsFehler', () {
    test('höchstens 20 Punkte und das Tabellenmaximum', () {
      final fehler = vertrautenGenerierungsFehler(
        const VertrautenGenerierung(
          artId: 'vart_katze',
          punkte: {'mu': 3, 'ge': 6, 'ko': 5, 'ch': 5, 'inn': 5},
          zusatzAsp: 4,
        ),
      );
      expect(fehler, contains(startsWith('Höchstens 20 Punkte')));
      expect(fehler, contains('MU höchstens 9 (Tabellenmaximum).'));
      expect(fehler, contains('Höchstens +3 AsP.'));
    });

    test('Machtvolle Vertraute haben freie Werte', () {
      expect(
        vertrautenGenerierungsFehler(
          const VertrautenGenerierung(
            artId: 'vart_katze',
            machtvoll: true,
            punkte: {'mu': 30},
            zusatzAsp: 10,
          ),
        ),
        isEmpty,
      );
    });
  });

  group('bucheVertrautenBindung', () {
    test('setzt Startwerte und bucht die Kosten bei der Hexe', () {
      final held = bucheVertrautenBindung(
        _hexe(),
        begleiterId: 'v',
        generierung: const VertrautenGenerierung(
          artId: 'vart_kroete',
          punkte: {'kl': 2},
          zusatzAsp: 1,
        ),
      );
      final v = held.companions.single;

      expect(held.apSpent, 500 + 100 + 4 + 5);
      expect(v.kl, 6);
      expect(v.maxAsp, 16);
      expect(v.startAsp, 16);
      expect(v.loyalitaet, 15);
      expect(v.gattung, 'Kröte');
      expect(v.angriffe, isEmpty);
      expect(v.vertrautenBindung!.artId, 'vart_kroete');
      expect(v.vertrautenBindung!.bindungskosten, 109);
      final kategorie = v.ritualCategories.single;
      expect(kategorie.ownKnowledge!.value, 3);
      expect(
        kategorie.rituals.map((r) => r.name),
        unorderedEquals(['Krötenschlag', 'Zwiegespräch']),
      );
    });

    test('Flieger bekommen Boden- und Luftangriff in DK H', () {
      final v = bucheVertrautenBindung(
        _hexe(),
        begleiterId: 'v',
        generierung: const VertrautenGenerierung(artId: 'vart_eule'),
      ).companions.single;

      expect(v.angriffe.map((a) => (a.at, a.pa, a.dk)), [
        (1, 2, 'H'),
        (12, 5, 'H'),
      ]);
      expect(v.geschwindigkeiten.map((g) => g.wert), [1, 12]);
      expect(v.ruestungsTeile.single.rs, 2);
      expect(v.ritualCategories.single.rituals.single.name, 'Zwiegespräch');
    });

    test('ein schon gebundener Vertrauter wird abgewiesen', () {
      final gebunden = bucheVertrautenBindung(
        _hexe(),
        begleiterId: 'v',
        generierung: const VertrautenGenerierung(artId: 'vart_katze'),
      );
      expect(
        () => bucheVertrautenBindung(
          gebunden,
          begleiterId: 'v',
          generierung: const VertrautenGenerierung(artId: 'vart_katze'),
        ),
        throwsStateError,
      );
    });

    test('zu wenig freie AP der Hexe werden abgewiesen', () {
      expect(
        () => bucheVertrautenBindung(
          _hexe(apTotal: 560),
          begleiterId: 'v',
          generierung: const VertrautenGenerierung(artId: 'vart_katze'),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('frei sind 60 AP'),
          ),
        ),
      );
    });

    test('nur Vertraute lassen sich binden', () {
      expect(
        () => bucheVertrautenBindung(
          _hexe(begleiter: const [HeroCompanion(id: 'v')]),
          begleiterId: 'v',
          generierung: const VertrautenGenerierung(artId: 'vart_katze'),
        ),
        throwsStateError,
      );
    });
  });

  group('Machtvoller Vertrauter mit Vorlage (WdZ S. 124, WdH S. 255)', () {
    const luchs = VertrautenGenerierung(
      artId: 'vart_katze',
      machtvoll: true,
      artName: 'Luchs',
      werte: {
        'mu': 5, // unter der Vorlage: keine Erstattung
        'kl': 8, // Vorlage 4, Maximum 6
        'kk': 12, // körperlich: frei
        'asp': 10, // Vorlage 5
        'lep': 30, // frei
        'rs': 2,
      },
      angriffe: [
        VertrautenAngriffDef(name: 'Biss', at: 14, pa: 9, tp: '1W6+3'),
      ],
      geschwindigkeiten: [VertrautenTempoDef('Boden', 14)],
    );

    test('nur geistige Werte, AE und MR kosten', () {
      final kosten = vertrautenBindungskosten(luchs);
      expect(kosten.grundkosten, 120);
      expect(kosten.punkte, (4 + 5) * 2);
      expect(kosten.ueberMaximum, 2 * 5);
      expect(kosten.zusatzpunkte, 0);
      expect(kosten.summe, 148);
      expect(vertrautenGenerierungsFehler(luchs), isEmpty);
    });

    test('übernimmt freie Werte, Angriffe und Namen', () {
      final held = bucheVertrautenBindung(
        _hexe(),
        begleiterId: 'v',
        generierung: luchs,
      );
      final v = held.companions.single;
      expect(held.apSpent, 648);
      expect(v.gattung, 'Luchs');
      expect((v.mu, v.kl, v.kk, v.ge), (5, 8, 12, 11));
      expect((v.maxLep, v.startLep, v.maxAsp), (30, 30, 10));
      expect(v.ruestungsTeile.single.rs, 2);
      expect(v.angriffe.single.name, 'Biss');
      expect(v.angriffe.single.at, 14);
      expect(v.geschwindigkeiten.single.wert, 14);
      expect(v.vertrautenBindung!.artId, 'vart_katze');
      expect(v.vertrautenBindung!.machtvoll, isTrue);
    });

    test('negative Werte werden abgewiesen', () {
      expect(
        vertrautenGenerierungsFehler(
          const VertrautenGenerierung(
            artId: 'vart_katze',
            machtvoll: true,
            werte: {'mu': -1},
          ),
        ),
        isNotEmpty,
      );
    });

    test('ohne Machtvoll zählen freie Werte nicht', () {
      final v = bucheVertrautenBindung(
        _hexe(),
        begleiterId: 'v',
        generierung: const VertrautenGenerierung(
          artId: 'vart_katze',
          werte: {'kk': 12},
          artName: 'Luchs',
        ),
      ).companions.single;
      expect(v.kk, 2);
      expect(v.gattung, 'Katze');
    });
  });

  test('erfasseVertrautenBindung ändert keine Werte und bucht nichts', () {
    const rabe = HeroCompanion(
      id: 'v',
      typ: BegleiterTyp.vertrauter,
      mu: 9,
      steigerungen: {'mu': 1},
    );
    final held = erfasseVertrautenBindung(
      _hexe(begleiter: const [rabe]),
      begleiterId: 'v',
      artId: 'vart_rabe',
      machtvoll: false,
    );
    final v = held.companions.single;

    expect(held.apSpent, 500);
    expect(v.mu, 9);
    expect(v.steigerungen, {'mu': 1});
    expect(v.vertrautenBindung!.bindungskosten, isNull);
    expect(v.vertrautenBindung!.artId, 'vart_rabe');
  });
}
