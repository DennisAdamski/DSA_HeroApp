import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui2/theme/karto_heldensiegel_profil.dart';

/// Kosmetische Zuordnung bleibt unabhängig von Regelbefähigungen.
void main() {
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
