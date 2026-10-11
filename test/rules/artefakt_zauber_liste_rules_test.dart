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
      gefechtsMatrixgeber(
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
      final bereit = gefechtsMatrixgeber(
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
}
