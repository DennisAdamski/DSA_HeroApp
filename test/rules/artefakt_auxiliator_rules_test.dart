import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/artefakt_auxiliator_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/artefakt_matrix_rules.dart';

import '../ui2/shell/karto_test_support.dart';

AuxiliatorBerechnung _rechne({
  int? gespeichert = 7,
  int? zfw = 12,
  bool gleich = true,
  bool gelungen = true,
}) => berechneAuxiliatorBonus(
  gespeicherteZfp: gespeichert,
  anwenderZfw: zfw,
  gleicheRepraesentation: gleich,
  spruchGelungen: gelungen,
);

void main() {
  group('Bonus', () {
    test('die gespeicherten ZfP* sind der Bonus eines gelungenen Spruchs', () {
      final b = _rechne();

      expect(b.bonus, 7);
      expect(b.halbiert, isFalse);
      expect(b.gedeckelt, isFalse);
    });

    test('der ZfW des Anwenders deckelt den Bonus', () {
      final b = _rechne(gespeichert: 10, zfw: 6);

      expect(b.bonus, 6);
      expect(b.gedeckelt, isTrue);
      expect(_rechne(gespeichert: 6, zfw: 6).gedeckelt, isFalse);
    });

    test('fremde Repräsentation: nur die Hälfte, abgerundet', () {
      expect(_rechne(gespeichert: 7, gleich: false).bonus, 3);
      expect(_rechne(gespeichert: 8, gleich: false).bonus, 4);
      expect(_rechne(gespeichert: 7, gleich: false).halbiert, isTrue);
    });

    test('erst halbieren, dann deckeln', () {
      // 10 → 5 (fremd), ZfW 8 → 5, nicht 8 → 4.
      final b = _rechne(gespeichert: 10, zfw: 8, gleich: false);

      expect(b.bonus, 5);
      expect(b.gedeckelt, isFalse);
      // 20 → 10, ZfW 8 → 8.
      final c = _rechne(gespeichert: 20, zfw: 8, gleich: false);
      expect(c.bonus, 8);
      expect(c.gedeckelt, isTrue);
    });

    test('ein Spruch, der misslungen wäre, bekommt keinen Bonus', () {
      final b = _rechne(gelungen: false);

      expect(b.bonus, 0);
      expect(b.nichtGelungen, isTrue);
    });

    test('ohne gespeicherte ZfP* gibt es nichts zu addieren', () {
      expect(_rechne(gespeichert: null).bonus, 0);
      expect(_rechne(gespeichert: null).ohneGespeicherteZfp, isTrue);
      expect(_rechne(gespeichert: 0).bonus, 0);
    });

    test('ein unbekannter ZfW begrenzt nicht, mit Hinweis', () {
      final b = _rechne(gespeichert: 9, zfw: null);

      expect(b.bonus, 9);
      expect(b.zfwFehlt, isTrue);
    });

    test('ein negativer ZfW deckelt auf 0', () {
      expect(_rechne(zfw: -2).bonus, 0);
    });
  });

  group('Kosten und Ausfall', () {
    test('Zauberkosten plus 1W3', () {
      expect(auxiliatorKosten(grundkosten: 9, w3: 2), 11);
      expect(auxiliatorKosten(grundkosten: 0, w3: 3), 3);
      expect(auxiliatorKosten(grundkosten: -4, w3: 1), 1);
    });

    test('+2 auf den Ausfallwurf nur bei misslungenem Spruch', () {
      expect(auxiliatorAusfallAufschlag(spruchGelungen: true), 0);
      expect(auxiliatorAusfallAufschlag(spruchGelungen: false), 2);
    });

    test('der Aufschlag verschiebt den Stabilitätswurf', () {
      MatrixAusgang ausgang(int w20, int aufschlag, {int zusatz = 1}) =>
          wertMatrixStabilitaet(
            stabilitaet: MatrixStabilitaet.stabil,
            regelfassung: MatrixRegelfassung.alchimie2012,
            wuerfe: MatrixWuerfe(w20: w20, w20Zusatz: zusatz),
            aufschlag: aufschlag,
          ).ausgang;

      // stabil 2012: 17–19 gehemmt, 20 beschädigt.
      expect(ausgang(15, 0), MatrixAusgang.ok);
      expect(ausgang(15, 2), MatrixAusgang.gehemmt);
      expect(ausgang(18, 0), MatrixAusgang.gehemmt);
      expect(ausgang(18, 2), MatrixAusgang.irreparabel);
    });

    test('unempfindlich: der Aufschlag macht aus der 18 eine 20', () {
      expect(
        matrixBrauchtZusatzwurf(MatrixStabilitaet.unempfindlich, 18),
        isFalse,
      );
      expect(
        matrixBrauchtZusatzwurf(
          MatrixStabilitaet.unempfindlich,
          18,
          aufschlag: 2,
        ),
        isTrue,
      );
      final ausgang = wertMatrixStabilitaet(
        stabilitaet: MatrixStabilitaet.unempfindlich,
        regelfassung: MatrixRegelfassung.alchimie2012,
        wuerfe: const MatrixWuerfe(w20: 18, w20Zusatz: 16),
        aufschlag: 2,
      ).ausgang;
      expect(ausgang, MatrixAusgang.irreparabel);
    });
  });

  group('Repräsentationen', () {
    test('gleich ohne Rücksicht auf Schreibweise und Leerraum', () {
      expect(gleicheRepraesentation(' mag ', 'Mag'), isTrue);
      expect(gleicheRepraesentation('Dru', 'Mag'), isFalse);
    });

    test('eine fehlende Angabe ist unbekannt', () {
      expect(gleicheRepraesentation('', 'Mag'), isNull);
      expect(gleicheRepraesentation('Mag', '  '), isNull);
    });
  });

  group('Prüfung', () {
    const talisman = ArtefaktDaten(
      art: ArtefaktArt.zaubertalisman,
      zauber: <ArtefaktZauber>[ArtefaktZauber(name: 'Ignifaxius', zfpStern: 5)],
    );

    test('ein vollständiger Talisman und ein zauberkundiger Anwender', () {
      final p = pruefeAuxiliator(daten: talisman, maxAsp: 30);

      expect(p.moeglich, isTrue);
      expect(p.hinweise, isEmpty);
    });

    test('ein beschädigter Talisman sperrt', () {
      final p = pruefeAuxiliator(
        daten: talisman.copyWith(defekt: true),
        maxAsp: 30,
      );

      expect(p.moeglich, isFalse);
      expect(p.sperrgrund, contains('beschädigt'));
    });

    test('fehlende Zauberkunde und fehlende Zauber sind Hinweise', () {
      final p = pruefeAuxiliator(
        daten: const ArtefaktDaten(art: ArtefaktArt.zaubertalisman),
        maxAsp: 0,
      );

      expect(p.moeglich, isTrue);
      expect(p.hinweise, hasLength(2));
    });
  });

  group('Kampf', () {
    test('ein Zaubertalisman ist im Kampf kein auslösbares Artefakt', () {
      const talisman = ArtefaktDaten(art: ArtefaktArt.zaubertalisman);

      expect(artefaktImKampfAusloesbar(talisman), isFalse);
      expect(artefaktImKampfAusloesbar(const ArtefaktDaten()), isTrue);
      expect(
        artefaktImKampfAusloesbar(const ArtefaktDaten(defekt: true)),
        isFalse,
      );
    });

    test('die Kennung eines Wirkprofils nennt den Zauber', () {
      expect(
        gefechtsWirkZauberId('zauber::spell_ignifaxius'),
        'spell_ignifaxius',
      );
      expect(gefechtsWirkZauberId('zauber::a:b'), 'a:b');
      expect(gefechtsWirkZauberId('liturgie:kult:x'), isNull);
      expect(gefechtsWirkZauberId('zauber::'), isNull);
      expect(gefechtsWirkZauberId(''), isNull);
    });

    test(
      'passende Auxiliatoren: ausgerüstet, unbeschädigt, gleicher Zauber',
      () {
        const passend = HeroInventoryEntry(
          gegenstand: 'Ring',
          isMagisch: true,
          istAusgeruestet: true,
          artefaktDaten: ArtefaktDaten(
            art: ArtefaktArt.zaubertalisman,
            zauber: <ArtefaktZauber>[
              ArtefaktZauber(spellId: 'spell_ignifaxius', name: 'Ignifaxius'),
            ],
          ),
        );
        final held = testHero().copyWith(
          inventoryEntries: [
            passend,
            passend.copyWith(gegenstand: 'Im Rucksack', istAusgeruestet: false),
            passend.copyWith(
              gegenstand: 'Kaputt',
              artefaktDaten: passend.artefaktDaten!.copyWith(defekt: true),
            ),
            passend.copyWith(
              gegenstand: 'Anderer Zauber',
              artefaktDaten: passend.artefaktDaten!.copyWith(
                zauber: const <ArtefaktZauber>[
                  ArtefaktZauber(spellId: 'spell_balsam', name: 'Balsam'),
                ],
              ),
            ),
            passend.copyWith(
              gegenstand: 'Matrixgeber',
              artefaktDaten: passend.artefaktDaten!.copyWith(
                art: ArtefaktArt.matrixgeber,
              ),
            ),
            passend.copyWith(
              gegenstand: 'Beim Begleiter',
              traegerTyp: InventoryTraeger.begleiter,
            ),
          ],
        );

        expect(
          gefechtsAuxiliatoren(
            held,
            'spell_ignifaxius',
          ).map((e) => e.gegenstand),
          ['Ring'],
        );
        expect(gefechtsAuxiliatoren(held, 'spell_unbekannt'), isEmpty);
      },
    );
  });
}
