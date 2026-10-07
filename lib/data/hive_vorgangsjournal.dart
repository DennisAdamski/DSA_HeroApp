import 'dart:convert';

import 'package:hive_ce/hive.dart';

import 'package:dsa_heldenverwaltung/data/vorgangsjournal.dart';

/// Hive-basiertes [Vorgangsjournal] im Profilpfad des Heldenspeichers.
///
/// Die Box liegt neben `heroes_v1`/`hero_states_v1`; das Journal gilt damit
/// je Profil (offline bzw. je Konto) und wird nur wiederaufgenommen, wenn
/// dieses Profil geöffnet wird. Einträge liegen als JSON-Text, damit
/// verschachtelte Maps und Listen ohne Typverlust zurückkommen.
class HiveVorgangsjournal implements Vorgangsjournal {
  HiveVorgangsjournal._(this._box);

  static const String _boxName = 'vorgaenge_v1';

  final Box<String> _box;

  /// Öffnet das Journal im angegebenen Profilpfad.
  static Future<HiveVorgangsjournal> create({
    required String storagePath,
  }) async {
    final box = await Hive.openBox<String>(_boxName, path: storagePath);
    return HiveVorgangsjournal._(box);
  }

  @override
  Future<void> merke(String vorgangId, Map<String, Object?> eintrag) async {
    await _box.put(vorgangId, jsonEncode(eintrag));
  }

  @override
  Future<void> erledige(String vorgangId) async {
    await _box.delete(vorgangId);
  }

  @override
  Future<Map<String, Map<String, Object?>>> offene() async {
    final ergebnis = <String, Map<String, Object?>>{};
    for (final schluessel in _box.keys) {
      final roh = _box.get(schluessel);
      if (roh == null) {
        continue;
      }
      final gelesen = jsonDecode(roh);
      if (gelesen is Map) {
        ergebnis['$schluessel'] = gelesen.cast<String, Object?>();
      }
    }
    return ergebnis;
  }

  /// Schließt die zugrunde liegende Hive-Box.
  Future<void> close() async {
    await _box.close();
  }
}
