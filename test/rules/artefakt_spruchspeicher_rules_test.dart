import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/artefakt_ladung_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/artefakt_spruchspeicher_rules.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';

ArtefaktLadung _ladung(
  String id, {
  bool verbraucht = false,
  List<ArtefaktZauber> zauber = const <ArtefaktZauber>[
    ArtefaktZauber(spellId: 'spell_psy', name: 'Psychostabilis', kostenAsp: 9),
    ArtefaktZauber(
      spellId: 'spell_ill',
      name: 'Illusion auflösen',
      kostenAsp: 6,
    ),
  ],
}) => ArtefaktLadung(id: id, verbraucht: verbraucht, zauber: zauber);

ArtefaktDaten _speicher({
  ArtefaktArt art = ArtefaktArt.spruchspeicherAufladbar,
  List<ArtefaktLadung>? ladungen,
  bool defekt = false,
  int aufladungen = 0,
  int? gesamt,
  MatrixRegelfassung fassung = MatrixRegelfassung.alchimie2012,
}) => ArtefaktDaten(
  art: art,
  regelfassung: fassung,
  ladungen: ladungen ?? [_ladung('a'), _ladung('b'), _ladung('c')],
  defekt: defekt,
  aufladungen: aufladungen,
  gesamtAspErschaffung: gesamt,
);

void main() {
  group('Ladungen', () {
    test('freie Ladungen sind die noch nicht verbrauchten', () {
      final daten = _speicher(
        ladungen: [_ladung('a', verbraucht: true), _ladung('b')],
      );

      expect(freieLadungen(daten).map((l) => l.id), ['b']);
    });

    test('ein einmaliger Speicher erlischt nach der letzten Ladung', () {
      final voll = _speicher(
        art: ArtefaktArt.spruchspeicherEinmalig,
        ladungen: [_ladung('a', verbraucht: true), _ladung('b')],
      );
      final leer = _speicher(
        art: ArtefaktArt.spruchspeicherEinmalig,
        ladungen: [_ladung('a', verbraucht: true)],
      );

      expect(spruchspeicherErloschen(voll), isFalse);
      expect(spruchspeicherErloschen(leer), isTrue);
    });

    test('ohne hinterlegte Ladung ist nichts erloschen', () {
      final daten = _speicher(
        art: ArtefaktArt.spruchspeicherEinmalig,
        ladungen: const <ArtefaktLadung>[],
      );

      expect(spruchspeicherErloschen(daten), isFalse);
      expect(spruchspeicherAufladbarLeer(daten), isFalse);
    });

    test('nur ein leerer, aufladbarer Speicher ist aufladbar', () {
      final leer = _speicher(ladungen: [_ladung('a', verbraucht: true)]);
      final einmalig = leer.copyWith(art: ArtefaktArt.spruchspeicherEinmalig);

      expect(spruchspeicherAufladbarLeer(leer), isTrue);
      expect(spruchspeicherAufladbarLeer(einmalig), isFalse);
      expect(spruchspeicherAufladbarLeer(_speicher()), isFalse);
    });

    test('auslösbar: Matrixgeber ohne Defekt, Speicher mit freier Ladung', () {
      expect(artefaktAusloesbar(const ArtefaktDaten()), isTrue);
      expect(artefaktAusloesbar(const ArtefaktDaten(defekt: true)), isFalse);
      expect(artefaktAusloesbar(_speicher()), isTrue);
      expect(artefaktAusloesbar(_speicher(defekt: true)), isFalse);
      expect(
        artefaktAusloesbar(
          _speicher(ladungen: [_ladung('a', verbraucht: true)]),
        ),
        isFalse,
      );
      expect(
        artefaktAusloesbar(_speicher(ladungen: const <ArtefaktLadung>[])),
        isFalse,
      );
    });
  });

  group('Auslösen prüfen', () {
    test('mit freier Ladung ist es möglich, ohne Hinweise', () {
      final p = pruefeSpruchspeicherAusloesung(_speicher());

      expect(p.moeglich, isTrue);
      expect(p.hinweise, isEmpty);
    });

    test('ein beschädigter Speicher sperrt', () {
      final p = pruefeSpruchspeicherAusloesung(_speicher(defekt: true));

      expect(p.moeglich, isFalse);
      expect(p.sperrgrund, contains('beschädigt'));
    });

    test('erloschen und leer nennen verschiedene Gründe', () {
      final erloschen = pruefeSpruchspeicherAusloesung(
        _speicher(
          art: ArtefaktArt.spruchspeicherEinmalig,
          ladungen: [_ladung('a', verbraucht: true)],
        ),
      );
      final leer = pruefeSpruchspeicherAusloesung(
        _speicher(ladungen: [_ladung('a', verbraucht: true)]),
      );

      expect(erloschen.sperrgrund, contains('jede magische Wirkung'));
      expect(leer.sperrgrund, contains('aufladen'));
    });

    test('ohne Ladung gibt es nichts auszulösen', () {
      final p = pruefeSpruchspeicherAusloesung(
        _speicher(ladungen: const <ArtefaktLadung>[]),
      );

      expect(p.sperrgrund, contains('keine Ladung'));
    });

    test('eine freie Ladung ohne Zauber ist nur ein Hinweis', () {
      final p = pruefeSpruchspeicherAusloesung(
        _speicher(ladungen: [_ladung('a', zauber: const <ArtefaktZauber>[])]),
      );

      expect(p.moeglich, isTrue);
      expect(p.hinweise.single, contains('keinen Zauber'));
    });
  });

  group('Schaden beim Aufladen', () {
    test('Wege der Alchimie 2012: erst nur die 20, dann jede Aufladung +1', () {
      const f = MatrixRegelfassung.alchimie2012;

      expect(aufladeSchadenAb(f, 0), 20);
      expect(aufladeSchadenAb(f, 1), 19);
      expect(aufladeSchadenAb(f, 4), 16);
      expect(aufladeSchadenAb(f, 19), 1);
      expect(aufladeSchadenAb(f, 40), 1);
      expect(aufladeBeschaedigt(fassung: f, aufladungen: 0, w20: 19), isFalse);
      expect(aufladeBeschaedigt(fassung: f, aufladungen: 0, w20: 20), isTrue);
      expect(aufladeBeschaedigt(fassung: f, aufladungen: 2, w20: 18), isTrue);
      expect(aufladeBeschaedigt(fassung: f, aufladungen: 2, w20: 17), isFalse);
    });

    test('Stäbe, Ringe, Dschinnenlampen 2011: 19–20, ohne Steigerung', () {
      const f = MatrixRegelfassung.staebeRinge2011;

      expect(aufladeSchadenAb(f, 0), 19);
      expect(aufladeSchadenAb(f, 5), 19);
      expect(aufladeBeschaedigt(fassung: f, aufladungen: 3, w20: 18), isFalse);
      expect(aufladeBeschaedigt(fassung: f, aufladungen: 3, w20: 19), isTrue);
    });

    test('ein negativer Zähler gilt wie 0', () {
      expect(aufladeSchadenAb(MatrixRegelfassung.alchimie2012, -3), 20);
    });
  });

  group('Aufladen prüfen', () {
    final leer = _speicher(
      ladungen: [
        _ladung('a', verbraucht: true),
        _ladung('b', verbraucht: true),
      ],
      gesamt: 30,
    );

    test('mit denselben Sprüchen gibt es keine Hinweise', () {
      final p = pruefeAufladung(daten: leer, neu: leer.ladungen);

      expect(p.moeglich, isTrue);
      expect(p.hinweise, isEmpty);
    });

    test('solange eine Ladung übrig ist, geht es nicht', () {
      final p = pruefeAufladung(
        daten: _speicher(
          ladungen: [_ladung('a', verbraucht: true), _ladung('b')],
        ),
        neu: const <ArtefaktLadung>[],
      );

      expect(p.moeglich, isFalse);
      expect(p.sperrgrund, contains('alle Ladungen verbraucht'));
    });

    test('einmalige und beschädigte Speicher lassen sich nicht aufladen', () {
      final einmalig = pruefeAufladung(
        daten: leer.copyWith(art: ArtefaktArt.spruchspeicherEinmalig),
        neu: leer.ladungen,
      );
      final defekt = pruefeAufladung(
        daten: leer.copyWith(defekt: true),
        neu: leer.ladungen,
      );

      expect(einmalig.sperrgrund, contains('aufladbarer'));
      expect(defekt.sperrgrund, contains('beschädigt'));
    });

    test('ein anderer Thesiskern ist nur ein Hinweis', () {
      final p = pruefeAufladung(
        daten: leer,
        neu: [
          _ladung(
            'a',
            zauber: const <ArtefaktZauber>[
              ArtefaktZauber(spellId: 'spell_fulminictus', name: 'Fulminictus'),
            ],
          ),
        ],
      );

      expect(p.moeglich, isTrue);
      expect(p.hinweise.single, contains('Thesiskern'));
    });

    test('abweichende ZfP*, Repräsentation und Modifikation stören nicht', () {
      final p = pruefeAufladung(
        daten: leer,
        neu: [
          for (final l in leer.ladungen)
            l.copyWith(
              zauber: [
                for (final z in l.zauber)
                  z.copyWith(
                    zfpStern: 12,
                    repraesentation: 'Elf',
                    spontaneModifikation: 'Reichweite',
                  ),
              ],
            ),
        ],
      );

      expect(p.hinweise, isEmpty);
    });

    test('freie Zauber werden über den Namen verglichen', () {
      final frei = _speicher(
        ladungen: [
          _ladung(
            'a',
            verbraucht: true,
            zauber: const <ArtefaktZauber>[ArtefaktZauber(name: 'Flim Flam')],
          ),
        ],
      );
      final p = pruefeAufladung(
        daten: frei,
        neu: [
          _ladung(
            'a',
            zauber: const <ArtefaktZauber>[ArtefaktZauber(name: ' flim flam ')],
          ),
        ],
      );

      expect(p.hinweise, isEmpty);
    });

    test('die Gesamt-AsP der Erschaffung sind eine Grenze (Hinweis)', () {
      final p = pruefeAufladung(
        daten: leer.copyWith(gesamtAspErschaffung: 20),
        neu: leer.ladungen,
      );

      expect(p.moeglich, isTrue);
      expect(p.hinweise.single, contains('30 AsP'));
      expect(p.hinweise.single, contains('(20 AsP)'));
    });

    test('ohne Gesamt-AsP gibt es keine Grenze', () {
      final p = pruefeAufladung(
        daten: leer.copyWith(gesamtAspErschaffung: null),
        neu: leer.ladungen,
      );

      expect(p.hinweise, isEmpty);
    });
  });

  group('Änderungen am Bogen', () {
    const eintrag = HeroInventoryEntry(
      gegenstand: 'Stirnreif',
      isMagisch: true,
      instanzId: 'i-1',
      artefaktDaten: ArtefaktDaten(
        art: ArtefaktArt.spruchspeicherAufladbar,
        ladungen: <ArtefaktLadung>[
          ArtefaktLadung(
            id: 'a',
            zauber: <ArtefaktZauber>[ArtefaktZauber(name: 'Psychostabilis')],
          ),
          ArtefaktLadung(id: 'b', verbraucht: true),
        ],
      ),
    );
    final held = HeroSheet(
      id: 'h',
      name: 'Thalion',
      level: 1,
      attributes: const Attributes(
        mu: 12,
        kl: 11,
        inn: 10,
        ch: 10,
        ff: 11,
        ge: 12,
        ko: 11,
        kk: 12,
      ),
      inventoryEntries: const [eintrag],
    );

    ArtefaktDaten gespeichert(HeroSheet h) =>
        h.inventoryEntries.single.artefaktDaten!;

    test('eine Ladung verbrauchen ändert nur diese Ladung', () {
      final neu = mitVerbrauchterLadung(held, eintrag, 'a');

      expect(gespeichert(neu).ladungen.map((l) => l.verbraucht), [true, true]);
      expect(
        gespeichert(neu).ladungen.first.zauber.single.name,
        'Psychostabilis',
      );
      expect(neu.inventoryEntries.single.instanzId, 'i-1');
    });

    test('eine verbrauchte oder fehlende Ladung wirft', () {
      expect(
        () => mitVerbrauchterLadung(held, eintrag, 'b'),
        throwsA(isA<StateError>()),
      );
      expect(
        () => mitVerbrauchterLadung(held, eintrag, 'x'),
        throwsA(isA<StateError>()),
      );
    });

    test('ein inzwischen geänderter Gegenstand wirft', () {
      final fremd = held.copyWith(
        inventoryEntries: [eintrag.copyWith(gegenstand: 'Anderer Name')],
      );

      expect(
        () => mitVerbrauchterLadung(fremd, eintrag, 'a'),
        throwsA(isA<StateError>()),
      );
    });

    test('ein beschädigter Speicher verbraucht nichts', () {
      final kaputt = eintrag.copyWith(
        artefaktDaten: eintrag.artefaktDaten!.copyWith(defekt: true),
      );

      expect(
        () => mitVerbrauchterLadung(
          held.copyWith(inventoryEntries: [kaputt]),
          kaputt,
          'a',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('Aufladen setzt die neuen Ladungen frei und zählt hoch', () {
      final leer = eintrag.copyWith(
        artefaktDaten: eintrag.artefaktDaten!.copyWith(
          ladungen: [
            for (final l in eintrag.artefaktDaten!.ladungen)
              l.copyWith(verbraucht: true),
          ],
        ),
      );
      final leerHeld = held.copyWith(inventoryEntries: [leer]);

      final neu = mitAufgeladenemSpeicher(
        leerHeld,
        leer,
        leer.artefaktDaten!.ladungen,
      );

      expect(gespeichert(neu).ladungen.map((l) => l.verbraucht), [
        false,
        false,
      ]);
      expect(gespeichert(neu).aufladungen, 1);
    });

    test('Aufladen mit übrig gebliebener Ladung wirft', () {
      expect(
        () => mitAufgeladenemSpeicher(
          held,
          eintrag,
          eintrag.artefaktDaten!.ladungen,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('die Beschädigung wird vermerkt, ein zweites Mal ändert nichts', () {
      final kaputt = mitBeschaedigtemArtefakt(held, eintrag);

      expect(gespeichert(kaputt).defekt, isTrue);
      final nochmal = mitBeschaedigtemArtefakt(
        kaputt,
        kaputt.inventoryEntries.single,
      );
      expect(identical(nochmal, kaputt), isTrue);
    });

    test('ein Gegenstand ohne Artefaktdaten wirft', () {
      const normal = HeroInventoryEntry(gegenstand: 'Seil', instanzId: 'i-2');

      expect(
        () => mitVerbrauchterLadung(
          held.copyWith(inventoryEntries: [normal]),
          normal,
          'a',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
