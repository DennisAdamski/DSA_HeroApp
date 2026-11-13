import 'dart:convert';

import 'package:hive_ce/hive.dart';

import 'package:dsa_heldenverwaltung/domain/avesmaps_ort.dart';

/// Lokaler Zwischenspeicher für das Ortsverzeichnis von Avesmaps.
abstract interface class AvesmapsOrteSpeicher {
  /// Die zuletzt gemerkte Liste oder `null`.
  Future<AvesmapsOrtsliste?> lade();

  /// Ersetzt die gemerkte Liste.
  Future<void> merke(AvesmapsOrtsliste liste);
}

/// Hive-basierter [AvesmapsOrteSpeicher] (`avesmaps_orte_v1`).
///
/// Liegt im Heldenspeicher, nicht im Kontoprofil: Das Verzeichnis ist für
/// alle Konten dasselbe. Der Eintrag ist JSON-Text. Im Web landet die Box in
/// IndexedDB. Die Box wird beim ersten Zugriff geöffnet und nach einem
/// fremden Schließen (Profilwechsel) wieder geöffnet.
class HiveAvesmapsOrteSpeicher implements AvesmapsOrteSpeicher {
  /// Erstellt den Speicher im Pfad [speicherPfad].
  HiveAvesmapsOrteSpeicher({required this.speicherPfad});

  static const String _boxName = 'avesmaps_orte_v1';
  static const String _schluessel = 'orte';

  /// Heldenspeicherpfad, in dem die Box liegt.
  final String speicherPfad;

  Future<Box<String>>? _boxFuture;

  Future<Box<String>> _box() async {
    final vorhanden = _boxFuture;
    if (vorhanden != null) {
      final box = await vorhanden;
      if (box.isOpen) return box;
    }
    final neu = Hive.openBox<String>(_boxName, path: speicherPfad);
    _boxFuture = neu;
    return neu;
  }

  @override
  Future<AvesmapsOrtsliste?> lade() async {
    final roh = (await _box()).get(_schluessel);
    if (roh == null) return null;
    final Object? gelesen;
    try {
      gelesen = jsonDecode(roh);
    } on FormatException {
      return null;
    }
    if (gelesen is! Map) return null;
    final abgerufen = DateTime.tryParse('${gelesen['abgerufen']}');
    final orte = leseAvesmapsOrte(gelesen['orte']);
    if (abgerufen == null || orte.isEmpty) return null;
    return AvesmapsOrtsliste(orte: orte, abgerufen: abgerufen.toUtc());
  }

  @override
  Future<void> merke(AvesmapsOrtsliste liste) async {
    final box = await _box();
    await box.put(
      _schluessel,
      jsonEncode(<String, Object?>{
        'abgerufen': liste.abgerufen.toUtc().toIso8601String(),
        'orte': <Object?>[for (final ort in liste.orte) ort.toJson()],
      }),
    );
  }

  /// Schließt die Box, sofern sie geöffnet wurde.
  Future<void> close() async {
    final vorhanden = _boxFuture;
    if (vorhanden == null) return;
    final box = await vorhanden;
    if (box.isOpen) await box.close();
  }
}
