import 'dart:convert';

import 'package:hive_ce/hive.dart';

import 'package:dsa_heldenverwaltung/domain/avesmaps_route.dart';

/// Ein gemerkter Reiseweg samt Abrufzeit.
class GemerkteAvesmapsRoute {
  /// Erstellt den Eintrag.
  const GemerkteAvesmapsRoute({required this.route, required this.abgerufen});

  /// Der Weg (oder die Antwort ohne Weg).
  final AvesmapsRoute route;

  /// Wann er abgerufen wurde (UTC).
  final DateTime abgerufen;
}

/// Lokaler Zwischenspeicher für Reisewege von Avesmaps, Schlüssel ist
/// [AvesmapsRoutenAnfrage.schluessel].
abstract interface class AvesmapsRoutenSpeicher {
  /// Alle gemerkten Wege.
  Future<Map<String, GemerkteAvesmapsRoute>> alle();

  /// Merkt einen Weg.
  Future<void> merke(String schluessel, GemerkteAvesmapsRoute eintrag);

  /// Entfernt die Wege mit den [schluessel]n.
  Future<void> entferne(Iterable<String> schluessel);
}

/// Speicher nur für die Laufzeit (Tests, Plattformen ohne Ablage).
class FluechtigerAvesmapsRoutenSpeicher implements AvesmapsRoutenSpeicher {
  final Map<String, GemerkteAvesmapsRoute> _eintraege =
      <String, GemerkteAvesmapsRoute>{};

  @override
  Future<Map<String, GemerkteAvesmapsRoute>> alle() async =>
      Map<String, GemerkteAvesmapsRoute>.of(_eintraege);

  @override
  Future<void> merke(String schluessel, GemerkteAvesmapsRoute eintrag) async {
    _eintraege[schluessel] = eintrag;
  }

  @override
  Future<void> entferne(Iterable<String> schluessel) async {
    schluessel.forEach(_eintraege.remove);
  }
}

/// Hive-basierter [AvesmapsRoutenSpeicher] (`avesmaps_routen_v1`).
///
/// Liegt wie das Ortsverzeichnis im Heldenspeicher; je Weg ein JSON-Text.
class HiveAvesmapsRoutenSpeicher implements AvesmapsRoutenSpeicher {
  /// Erstellt den Speicher im Pfad [speicherPfad].
  HiveAvesmapsRoutenSpeicher({required this.speicherPfad});

  static const String _boxName = 'avesmaps_routen_v1';

  /// Heldenspeicherpfad, in dem die Box liegt.
  final String speicherPfad;

  Future<Box<String>>? _boxFuture;

  Future<Box<String>> _box() async {
    final vorhanden = _boxFuture;
    if (vorhanden != null) {
      final box = await vorhanden;
      if (box.isOpen) return box;
    }
    // Fester Boxname: siehe `HiveAvesmapsOrteSpeicher`.
    if (Hive.isBoxOpen(_boxName)) {
      await Hive.box<String>(_boxName).close();
    }
    final neu = Hive.openBox<String>(_boxName, path: speicherPfad);
    _boxFuture = neu;
    return neu;
  }

  @override
  Future<Map<String, GemerkteAvesmapsRoute>> alle() async {
    final box = await _box();
    final ergebnis = <String, GemerkteAvesmapsRoute>{};
    for (final schluessel in box.keys) {
      if (schluessel is! String) continue;
      final eintrag = _lies(box.get(schluessel));
      if (eintrag != null) ergebnis[schluessel] = eintrag;
    }
    return ergebnis;
  }

  @override
  Future<void> merke(String schluessel, GemerkteAvesmapsRoute eintrag) async {
    final box = await _box();
    await box.put(
      schluessel,
      jsonEncode(<String, Object?>{
        'abgerufen': eintrag.abgerufen.toUtc().toIso8601String(),
        'route': eintrag.route.toJson(),
      }),
    );
  }

  @override
  Future<void> entferne(Iterable<String> schluessel) async {
    final liste = schluessel.toList();
    if (liste.isEmpty) return;
    await (await _box()).deleteAll(liste);
  }

  GemerkteAvesmapsRoute? _lies(String? roh) {
    if (roh == null) return null;
    final Object? gelesen;
    try {
      gelesen = jsonDecode(roh);
    } on FormatException {
      return null;
    }
    if (gelesen is! Map) return null;
    final abgerufen = DateTime.tryParse('${gelesen['abgerufen']}');
    final route = AvesmapsRoute.ausJson(gelesen['route']);
    if (abgerufen == null || route == null) return null;
    return GemerkteAvesmapsRoute(route: route, abgerufen: abgerufen.toUtc());
  }

  /// Schließt die Box, sofern sie geöffnet wurde.
  Future<void> close() async {
    final vorhanden = _boxFuture;
    if (vorhanden == null) return;
    final box = await vorhanden;
    if (box.isOpen) await box.close();
  }
}
