import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/artefakt_zauber_liste_rules.dart';

import '../ui2/shell/karto_test_support.dart';

const _daten = ArtefaktDaten(
  ausloeserAktionen: 2,
  zauber: <ArtefaktZauber>[
    ArtefaktZauber(
      name: 'Gardianum',
      repraesentation: 'Mag',
      variante: 'Dauerhaft',
      zfw: 12,
      zfpStern: 7,
      kostenAsp: 9,
    ),
    ArtefaktZauber(name: 'Armatrutz', kostenAsp: 6),
  ],
);

const _schiene = HeroInventoryEntry(
  gegenstand: 'Armschiene',
  isMagisch: true,
  istAusgeruestet: true,
  artefaktDaten: _daten,
);

void main() {
  final held = testHero();

  test('die Zauberliste führt jeden Zauber jedes Artefakts', () {
    final liste = artefaktZauberListe(
      held.copyWith(
        inventoryEntries: [
          const HeroInventoryEntry(gegenstand: 'Seil'),
          _schiene,
          _schiene.copyWith(
            gegenstand: 'Ring',
            istAusgeruestet: false,
            artefaktDaten: const ArtefaktDaten(
              defekt: true,
              zauber: <ArtefaktZauber>[ArtefaktZauber(name: 'Flim Flam')],
            ),
          ),
        ],
      ),
    );

    expect(liste.map((e) => e.zauber.name), [
      'Gardianum',
      'Armatrutz',
      'Flim Flam',
    ]);
    expect(liste.first.artefakt.gegenstand, 'Armschiene');
    expect(liste.first.ausgeruestet, isTrue);
    expect(liste.last.ausgeruestet, isFalse);
    expect(liste.last.defekt, isTrue);
    expect(
      liste.first.detail,
      'Variante: Dauerhaft · Mag · ZfW 12 · ZfP* 7 · 9 AsP',
    );
  });

  test('Gegenstände eines Begleiters gehören nicht zur Zauberliste', () {
    final liste = artefaktZauberListe(
      held.copyWith(
        inventoryEntries: [
          _schiene.copyWith(
            traegerTyp: InventoryTraeger.begleiter,
            traegerId: 'b1',
          ),
        ],
      ),
    );

    expect(liste, isEmpty);
    expect(
      gefechtsArtefakte(
        held.copyWith(
          inventoryEntries: [
            _schiene.copyWith(traegerTyp: InventoryTraeger.begleiter),
          ],
        ),
      ),
      isEmpty,
    );
  });

  test(
    'im Kampf stehen nur ausgerüstete, unbeschädigte Matrixgeber bereit',
    () {
      final bereit = gefechtsArtefakte(
        held.copyWith(
          inventoryEntries: [
            _schiene,
            _schiene.copyWith(
              gegenstand: 'Im Rucksack',
              istAusgeruestet: false,
            ),
            _schiene.copyWith(
              gegenstand: 'Kaputt',
              artefaktDaten: _daten.copyWith(defekt: true),
            ),
            const HeroInventoryEntry(gegenstand: 'Seil', istAusgeruestet: true),
          ],
        ),
      );

      expect(bereit.map((e) => e.gegenstand), ['Armschiene']);
    },
  );

  test('die Zusammenfassung nennt Zauber, Kosten und Aktionen', () {
    expect(
      matrixgeberZusammenfassung(_daten),
      'Gardianum + Armatrutz · 15 AsP · 2 Aktionen',
    );
    expect(
      matrixgeberZusammenfassung(
        _daten.copyWith(regelfassung: MatrixRegelfassung.staebeRinge2011),
      ),
      'Gardianum + Armatrutz · 15 AsP ± W6 · 2 Aktionen',
    );
    expect(
      matrixgeberZusammenfassung(
        const ArtefaktDaten(
          zauber: <ArtefaktZauber>[ArtefaktZauber(name: 'Flim Flam')],
        ),
      ),
      'Flim Flam · 1 Aktion',
    );
  });

  group('Spruchspeicher', () {
    const speicher = ArtefaktDaten(
      art: ArtefaktArt.spruchspeicherAufladbar,
      pAsP: 4,
      ladungen: <ArtefaktLadung>[
        ArtefaktLadung(
          id: 'a',
          verbraucht: true,
          zauber: <ArtefaktZauber>[ArtefaktZauber(name: 'Gardianum')],
        ),
        ArtefaktLadung(
          id: 'b',
          zauber: <ArtefaktZauber>[
            ArtefaktZauber(name: 'Armatrutz'),
            ArtefaktZauber(name: 'Gardianum'),
          ],
        ),
      ],
    );
    const stirnreif = HeroInventoryEntry(
      gegenstand: 'Stirnreif',
      isMagisch: true,
      istAusgeruestet: true,
      artefaktDaten: speicher,
    );

    test('die Zauberliste nennt Zauber jeder Ladung samt Status', () {
      final liste = artefaktZauberListe(
        held.copyWith(inventoryEntries: [stirnreif]),
      );

      expect(liste.map((e) => e.zauber.name), [
        'Gardianum',
        'Armatrutz',
        'Gardianum',
      ]);
      expect(liste.map((e) => e.verbraucht), [true, false, false]);
      expect(liste.map((e) => e.ladung?.id), ['a', 'b', 'b']);
    });

    test('ein Matrixgeber hat keine Ladung und gilt nie als verbraucht', () {
      final liste = artefaktZauberListe(
        held.copyWith(inventoryEntries: [_schiene]),
      );

      expect(liste.map((e) => e.ladung), [null, null]);
      expect(liste.map((e) => e.verbraucht), [false, false]);
    });

    test('im Kampf stehen nur Speicher mit freier Ladung bereit', () {
      final leer = stirnreif.copyWith(
        gegenstand: 'Leer',
        artefaktDaten: speicher.copyWith(
          ladungen: [
            for (final l in speicher.ladungen) l.copyWith(verbraucht: true),
          ],
        ),
      );
      final bereit = gefechtsArtefakte(
        held.copyWith(inventoryEntries: [stirnreif, leer, _schiene]),
      );

      expect(bereit.map((e) => e.gegenstand), ['Stirnreif', 'Armschiene']);
    });

    test('die Zusammenfassung nennt freie Zauber, Ladungen und pAsP', () {
      expect(
        artefaktZusammenfassung(speicher),
        'Armatrutz + Gardianum · 1 von 2 Ladungen frei · 1 Aktion · 4 pAsP',
      );
    });

    test('der Ladungstext unterscheidet erloschen, leer und unerfasst', () {
      expect(
        spruchspeicherLadungenText(
          speicher.copyWith(ladungen: const <ArtefaktLadung>[]),
        ),
        'keine Ladung hinterlegt',
      );
      expect(
        spruchspeicherLadungenText(
          const ArtefaktDaten(
            art: ArtefaktArt.spruchspeicherEinmalig,
            ladungen: <ArtefaktLadung>[
              ArtefaktLadung(id: 'a', verbraucht: true),
            ],
          ),
        ),
        'erloschen',
      );
      expect(
        spruchspeicherLadungenText(
          const ArtefaktDaten(
            ladungen: <ArtefaktLadung>[ArtefaktLadung(id: 'a')],
          ),
        ),
        '1 von 1 Ladung frei',
      );
    });

    test('semipermanent: Zauber, Anwendungen je Intervall und Aktionen', () {
      const robe = ArtefaktDaten(
        art: ArtefaktArt.spruchspeicherSemipermanent,
        intervall: ArtefaktIntervall.monat,
        anwendungenProIntervall: 2,
        ausloeserAktionen: 2,
        zauber: <ArtefaktZauber>[ArtefaktZauber(name: 'Aureolus')],
      );

      expect(
        artefaktZusammenfassung(robe),
        'Aureolus · 2 je Monat · 2 Aktionen',
      );
    });

    test(
      'ein semipermanenter Speicher steht im Kampf bereit und listet Zauber',
      () {
        const robe = HeroInventoryEntry(
          gegenstand: 'Robe',
          isMagisch: true,
          istAusgeruestet: true,
          artefaktDaten: ArtefaktDaten(
            art: ArtefaktArt.spruchspeicherSemipermanent,
            zauber: <ArtefaktZauber>[ArtefaktZauber(name: 'Aureolus')],
          ),
        );
        final h = held.copyWith(inventoryEntries: [robe]);

        expect(gefechtsArtefakte(h).map((e) => e.gegenstand), ['Robe']);
        final liste = artefaktZauberListe(h);
        expect(liste.map((e) => e.zauber.name), ['Aureolus']);
        expect(liste.single.ladung, isNull);
        expect(liste.single.verbraucht, isFalse);
      },
    );

    test('ein Matrixgeber behält seine Zusammenfassung', () {
      expect(
        artefaktZusammenfassung(_daten),
        matrixgeberZusammenfassung(_daten),
      );
    });
  });
}
