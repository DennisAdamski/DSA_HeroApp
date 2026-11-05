import 'package:flutter_test/flutter_test.dart';

import 'catalog_reference_names.dart';

/// Regelbuch-Langtexte duerfen nicht im Klartext im Repo liegen.
///
/// Die Tabelle spiegelt `PROTECTED_FIELDS` in `tool/encrypt_catalog_fields.py`.
/// Neue Felder mit Regelbuchtext dort **und** hier eintragen und das Tool
/// ausfuehren (`docs/hinweise/katalog_sonderfertigkeiten.md`). Leere Werte
/// bleiben leer, weil das Tool leere Strings nie verschluesselt.
void main() {
  const geschuetzt = <String, List<String>>{
    'manoever.json': ['erklarung_lang'],
    'kampf_sonderfertigkeiten.json': ['erklarung_lang'],
    'allgemeine_sonderfertigkeiten.json': ['erklarung_lang'],
    'karmale_sonderfertigkeiten.json': ['erklarung_lang'],
    'magische_sonderfertigkeiten.json': ['erklarung_lang'],
    'magie.json': ['wirkung', 'variants'],
    'kurzregeln.json': ['kurztext', 'hinweise', 'hausregel_text'],
  };

  geschuetzt.forEach((datei, felder) {
    for (final feld in felder) {
      test('$datei: $feld ist verschluesselt (v3)', () {
        final klartext = <String>[
          for (final eintrag in ladeKatalogDatei(datei))
            if (_istKlartext(eintrag[feld]))
              '${eintrag['id'] ?? eintrag['name']}',
        ];

        expect(klartext, isEmpty);
      });
    }
  });
}

bool _istKlartext(Object? wert) {
  if (wert == null) return false;
  if (wert is String) {
    return wert.trim().isNotEmpty && !wert.startsWith('enc:3:');
  }
  if (wert is List) return wert.isNotEmpty;
  return true;
}
