import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/held_importieren.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_import_export_actions.dart';

void main() {
  test('ein Import ohne fehlende Bilder meldet Erfolg', () {
    expect(
      importMeldung(const HeldImportErgebnis(heroId: 'h', fehlendeBilder: 0)),
      'Held erfolgreich importiert',
    );
  });

  test('fehlende Bilder werden ausdrücklich genannt', () {
    expect(
      importMeldung(const HeldImportErgebnis(heroId: 'h', fehlendeBilder: 1)),
      'Held importiert – 1 Bild konnte nicht gespeichert werden.',
    );
    expect(
      importMeldung(const HeldImportErgebnis(heroId: 'h', fehlendeBilder: 3)),
      'Held importiert – 3 Bilder konnten nicht gespeichert werden.',
    );
  });
}
