import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui2/theme/karto_heldensiegel_profil.dart';

/// Kosmetische Zuordnung bleibt unabhängig von Regelbefähigungen.
void main() {
  test(
    'alle Kulturaliase bleiben eindeutig und erhalten beide Befähigungen',
    () {
      for (final kultur in KartoSiegelKultur.values) {
        for (final alias in kultur.aliase) {
          final profil = KartoSiegelProfil.ausAngaben(
            rasse: 'Mensch',
            kultur: alias,
            magisch: true,
            karmal: true,
          );
          expect(profil.kultur, kultur, reason: alias);
          expect(profil.magisch, isTrue);
          expect(profil.karmal, isTrue);
        }
      }
      expect(
        KartoSiegelProfil.ausAngaben(
          rasse: 'Mensch',
          kultur: 'Bornländisch',
        ).kultur,
        KartoSiegelKultur.bornlaender,
      );
      final gemischt = KartoSiegelProfil.ausAngaben(
        rasse: 'Mensch',
        kultur: 'Andergast / Nostria',
      );
      expect(gemischt.kultur, isNull);
      expect(gemischt.assetPfad, endsWith('/mensch.png'));
    },
  );

  for (final kultur in {
    'Thorwal': 'thorwaler',
    'Thorwaler': 'thorwaler',
    'Norbarden-Sippe': 'norbarden',
    'Novadis': 'novadis',
    'Mittelreich': 'mittelreicher',
    'Horasreich': 'horasier',
    'Tulamiden': 'tulamiden',
    'Nivesen': 'nivesen',
    'Bornland': 'bornlaender',
    'Maraskan': 'maraskaner',
    'Al’Anfa': 'alanfaner',
    'Andergast': 'andergaster',
    'Nostria': 'nostrier',
  }.entries) {
    test(
      'Kultur ${kultur.key} wählt das Bildasset ohne Befähigungen zu erfinden',
      () {
        final profil = KartoSiegelProfil.ausAngaben(
          rasse: 'Mensch',
          kultur: kultur.key,
        );
        expect(
          profil.assetPfad,
          'assets/ui/heldensiegel_v1/${kultur.value}.png',
        );
        expect(profil.magisch, isFalse);
        expect(profil.karmal, isFalse);
      },
    );
  }

  test('Kultur hat Vorrang vor alten Rassenangaben, unbekannte Kulturen bleiben offen', () {
    expect(
      KartoSiegelProfil.ausAngaben(
        rasse: 'Thorwaler',
        kultur: 'Novadis',
      ).assetPfad,
      endsWith('/novadis.png'),
    );
    expect(
      KartoSiegelProfil.ausAngaben(
        rasse: 'Thorwaler',
        kultur: 'Unbekannte Kultur',
      ).assetPfad,
      endsWith('/mensch.png'),
    );
    expect(
      KartoSiegelProfil.ausAngaben(
        rasse: 'Mensch',
        kultur: 'Thorwal / Norbarden',
      ).assetPfad,
      endsWith('/mensch.png'),
    );
    expect(
      KartoSiegelProfil.ausAngaben(rasse: 'Thorwaler').assetPfad,
      endsWith('/thorwaler.png'),
    );
    expect(
      KartoSiegelProfil.ausAngaben(
        rasse: 'Halbelf',
        kultur: 'Thorwal',
      ).assetPfad,
      endsWith('/thorwaler.png'),
    );
    expect(
      KartoSiegelProfil.ausAngaben(rasse: 'Achaz', kultur: 'Thorwal').assetPfad,
      endsWith('/achaz.png'),
    );
  });

  test('alle Spezies und neutrale Angaben haben ein fertiges Bildmotiv', () {
    for (final motiv in KartoSiegelMotiv.values) {
      final datei = motiv == KartoSiegelMotiv.echse ? 'achaz' : motiv.name;
      expect(
        KartoSiegelProfil(motiv: motiv).assetPfad,
        'assets/ui/heldensiegel_v1/$datei.png',
      );
    }
    final unbekannt = KartoSiegelProfil.ausAngaben(rasse: 'Unbekannt');
    expect(unbekannt.assetPfad, endsWith('/neutral.png'));
    final ohneKultur = KartoSiegelProfil.ausAngaben(rasse: 'Mittelländer');
    expect(ohneKultur.kultur, isNull, reason: 'Rasse ersetzt keine Kultur');
    expect(ohneKultur.assetPfad, endsWith('/mensch.png'));
  });

  for (final eintrag in {
    'Mensch': KartoSiegelMotiv.mensch,
    'Mittelländer': KartoSiegelMotiv.mensch,
    'Auelf': KartoSiegelMotiv.elf,
    'Waldelfen': KartoSiegelMotiv.elf,
    'Halbelf': KartoSiegelMotiv.halbelf,
    'Halb-Elf': KartoSiegelMotiv.halbelf,
    'Halbelf (Auelf / Mittelländer)': KartoSiegelMotiv.halbelf,
    'Mensch / Elf': KartoSiegelMotiv.neutral,
    'Zwerg / Goblin': KartoSiegelMotiv.neutral,
    'Halbelf / Zwerg': KartoSiegelMotiv.neutral,
    'Ambosszwerg': KartoSiegelMotiv.zwerg,
    'Achaz': KartoSiegelMotiv.echse,
    'Echsenmensch': KartoSiegelMotiv.echse,
    'Ork': KartoSiegelMotiv.ork,
    'Goblin': KartoSiegelMotiv.goblin,
    '': KartoSiegelMotiv.neutral,
    'Unbekannt': KartoSiegelMotiv.neutral,
    'Menschenfreund': KartoSiegelMotiv.neutral,
  }.entries) {
    test('${eintrag.key} erhält ein eigenes profanes Motiv', () {
      final profil = KartoSiegelProfil.ausAngaben(rasse: eintrag.key);
      expect(profil.motiv, eintrag.value);
      expect(profil.magisch, isFalse);
      expect(profil.karmal, isFalse);
    });
  }

  test(
    'Schreibvarianten bleiben gleich und beide Befähigungen bleiben erhalten',
    () {
      final profil = KartoSiegelProfil.ausAngaben(
        rasse: '  HALBELF  ',
        magisch: true,
        karmal: true,
      );
      expect(profil.motiv, KartoSiegelMotiv.halbelf);
      expect(profil.magisch, isTrue);
      expect(profil.karmal, isTrue);
      expect(
        profil,
        KartoSiegelProfil.ausAngaben(
          rasse: 'Halbelf',
          magisch: true,
          karmal: true,
        ),
      );
    },
  );
}
