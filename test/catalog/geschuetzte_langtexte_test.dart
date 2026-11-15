import 'dart:convert';
import 'dart:io';

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
    'kraeuter.json': ['beschreibung'],
  };

  geschuetzt.forEach((datei, felder) {
    for (final feld in felder) {
      test('$datei: $feld ist verschluesselt (v3)', () {
        final klartext = <String>[
          for (final eintrag in _eintraege(datei))
            if (_istKlartext(eintrag[feld]))
              '${eintrag['id'] ?? eintrag['name']}',
        ];

        expect(klartext, isEmpty);
      });
    }
  });
}

/// Einträge einer Katalogdatei: Top-Level-Liste oder, wie beim
/// Kräuterkatalog, die Liste `kraeuter` eines Objekts.
List<Map<String, dynamic>> _eintraege(String datei) {
  if (datei != 'kraeuter.json') return ladeKatalogDatei(datei);
  var text = File('assets/catalogs/house_rules_v1/$datei').readAsStringSync();
  if (text.startsWith('﻿')) text = text.substring(1);
  final daten = jsonDecode(text) as Map<String, dynamic>;
  return (daten['kraeuter'] as List).cast<Map<String, dynamic>>();
}

bool _istKlartext(Object? wert) {
  if (wert == null) return false;
  if (wert is String) {
    return wert.trim().isNotEmpty && !wert.startsWith('enc:3:');
  }
  if (wert is List) return wert.isNotEmpty;
  return true;
}
