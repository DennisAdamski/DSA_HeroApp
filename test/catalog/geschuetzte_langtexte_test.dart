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
/// `liste[].feld` meint das Feld in jedem Element der Liste (wie im Tool).
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
    'alchimika.json': ['wirkung', 'qualitaeten[].wirkung'],
    'vertrautenmagie_rituale.json': ['wirkung', 'technik'],
  };

  geschuetzt.forEach((datei, felder) {
    for (final feld in felder) {
      test('$datei: $feld ist verschluesselt (v3)', () {
        final klartext = <String>[
          for (final eintrag in _eintraege(datei))
            for (final wert in _werte(eintrag, feld))
              if (_istKlartext(wert)) '${eintrag['id'] ?? eintrag['name']}',
        ];

        expect(klartext, isEmpty);
      });
    }
  });

  // Spiegelt `PROTECTED_PACK_FIELDS` und `PACK_MANIFEST_GLOB` im Tool.
  const paketFelder = <String>['erklarung_lang', 'wirkung', 'variants'];
  final manifeste =
      Directory('assets/catalogs/house_rules_v1/packs')
          .listSync()
          .whereType<Directory>()
          .map((ordner) => File('${ordner.path}/manifest.json'))
          .where((datei) => datei.existsSync())
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('es gibt eingebaute Hausregel-Pakete', () {
    expect(manifeste, isNotEmpty);
  });

  for (final manifest in manifeste) {
    final name = manifest.parent.uri.pathSegments
        .where((s) => s.isNotEmpty)
        .last;
    test('Paket $name: Langtexte sind verschluesselt (v3)', () {
      final klartext = <String>[
        for (final eintrag in _paketEintraege(manifest))
          for (final feld in paketFelder)
            if (_istKlartext(eintrag[feld]))
              '${eintrag['id'] ?? eintrag['name'] ?? '(setFields)'}:$feld',
      ];

      expect(klartext, isEmpty);
    });
  }
}

Object? _lese(File datei) {
  var text = datei.readAsStringSync();
  if (text.startsWith('﻿')) text = text.substring(1);
  return jsonDecode(text);
}

/// Einträge einer Katalogdatei: Top-Level-Liste oder, wie beim
/// Kräuterkatalog und der Vertrautenmagie, eine Liste in einem Objekt.
List<Map<String, dynamic>> _eintraege(String datei) {
  const verschachtelt = <String, String>{
    'kraeuter.json': 'kraeuter',
    'vertrautenmagie_rituale.json': 'rituals',
  };
  final schluessel = verschachtelt[datei];
  if (schluessel == null) return ladeKatalogDatei(datei);
  final daten = _lese(
    File('assets/catalogs/house_rules_v1/$datei'),
  ) as Map<String, dynamic>;
  return (daten[schluessel] as List).cast<Map<String, dynamic>>();
}

/// Werte von [feld] in [eintrag]; `liste[].feld` liefert einen je Element.
List<Object?> _werte(Map<String, dynamic> eintrag, String feld) {
  final teile = feld.split('[].');
  if (teile.length == 1) return <Object?>[eintrag[feld]];
  final liste = eintrag[teile.first];
  if (liste is! List) return const <Object?>[];
  return <Object?>[
    for (final element in liste)
      if (element is Map<String, dynamic>)
        ..._werte(element, teile.sublist(1).join('[].')),
  ];
}

/// `addEntries` und `setFields` aller Patches eines Paket-Manifests.
List<Map<String, dynamic>> _paketEintraege(File manifest) {
  final daten = _lese(manifest) as Map<String, dynamic>;
  return <Map<String, dynamic>>[
    for (final patch
        in (daten['patches'] as List? ?? const []).cast<Map>()) ...[
      ...((patch['addEntries'] as List?) ?? const [])
          .cast<Map<String, dynamic>>(),
      if (patch['setFields'] is Map<String, dynamic>)
        patch['setFields'] as Map<String, dynamic>,
    ],
  ];
}

bool _istKlartext(Object? wert) {
  if (wert == null) return false;
  if (wert is String) {
    return wert.trim().isNotEmpty && !wert.startsWith('enc:3:');
  }
  if (wert is List) return wert.isNotEmpty;
  return true;
}
