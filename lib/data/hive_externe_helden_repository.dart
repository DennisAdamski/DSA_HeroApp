import 'dart:async';

import 'package:hive/hive.dart';

import 'package:dsa_heldenverwaltung/domain/externer_held.dart';

/// Hive-basierte Persistenz fuer externe Helden (Gruppenmitglieder).
///
/// Externe Helden werden allen lokalen Helden zur Verfuegung gestellt
/// und im `heroStoragePath` abgelegt.
class HiveExterneHeldenRepository {
  HiveExterneHeldenRepository._(this._box);

  static const _boxName = 'externe_helden_v1';

  final Box<Map> _box;

  /// In-memory Index fuer O(1)-Zugriff.
  final Map<String, ExternerHeld> _index = <String, ExternerHeld>{};

  final StreamController<Map<String, ExternerHeld>> _controller =
      StreamController<Map<String, ExternerHeld>>.broadcast();

  StreamSubscription<BoxEvent>? _eventSubscription;

  /// Erstellt und initialisiert das Repository asynchron.
  static Future<HiveExterneHeldenRepository> create({
    required String storagePath,
  }) async {
    final box = await Hive.openBox<Map>(_boxName, path: storagePath);
    final repository = HiveExterneHeldenRepository._(box);
    repository._seedIndex();
    repository._eventSubscription =
        repository._box.watch().listen(repository._handleBoxEvent);
    return repository;
  }

  void _seedIndex() {
    for (final key in _box.keys) {
      final raw = _box.get(key);
      if (raw is Map) {
        try {
          final held = ExternerHeld.fromJson(raw.cast<String, dynamic>());
          if (held.id.isNotEmpty) {
            _index[held.id] = held;
          }
        } on FormatException {
          // Ungueltige Daten ueberspringen.
        }
      }
    }
  }

  void _handleBoxEvent(BoxEvent event) {
    if (event.deleted) {
      _index.remove(event.key.toString());
    } else {
      final raw = event.value;
      if (raw is Map) {
        try {
          final held = ExternerHeld.fromJson(raw.cast<String, dynamic>());
          if (held.id.isNotEmpty) {
            _index[held.id] = held;
          }
        } on FormatException {
          // Ungueltige Daten ignorieren.
        }
      }
    }
    _controller.add(Map<String, ExternerHeld>.unmodifiable(_index));
  }

  /// Reaktiver Stream aller externen Helden.
  Stream<Map<String, ExternerHeld>> watchAll() async* {
    yield Map<String, ExternerHeld>.unmodifiable(_index);
    yield* _controller.stream;
  }

  /// Laedt einen externen Helden anhand seiner ID.
  ExternerHeld? loadById(String id) => _index[id];

  /// Gibt alle aktuell geladenen externen Helden zurueck.
  Map<String, ExternerHeld> loadAll() =>
      Map<String, ExternerHeld>.unmodifiable(_index);

  /// Speichert oder aktualisiert einen externen Helden.
  Future<void> save(ExternerHeld held) async {
    await _box.put(held.id, held.toJson());
  }

  /// Loescht einen externen Helden anhand seiner ID.
  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  /// Gibt Ressourcen frei.
  Future<void> close() async {
    await _eventSubscription?.cancel();
    await _controller.close();
    await _box.close();
  }
}
