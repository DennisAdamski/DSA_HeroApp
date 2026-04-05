import 'dart:async';

import 'package:hive/hive.dart';

import 'package:dsa_heldenverwaltung/domain/gruppen_snapshot.dart';

/// Hive-basierte Persistenz fuer den aktiven [GruppenSnapshot].
///
/// Speichert genau einen Gruppen-Snapshot unter dem Key [_activeKey].
/// Wird im Settings-Pfad abgelegt (nicht im Helden-Pfad), damit der
/// Snapshot geraetelokal bleibt.
class HiveGruppenRepository {
  HiveGruppenRepository._(this._box);

  static const _boxName = 'gruppen_v1';
  static const _activeKey = 'active_gruppe';

  final Box<Map> _box;

  /// Aktuell geladener Snapshot (Cache).
  GruppenSnapshot? _cached;

  final StreamController<GruppenSnapshot?> _controller =
      StreamController<GruppenSnapshot?>.broadcast();

  StreamSubscription<BoxEvent>? _eventSubscription;

  /// Erstellt und initialisiert das Repository asynchron.
  static Future<HiveGruppenRepository> create({
    required String storagePath,
  }) async {
    final box = await Hive.openBox<Map>(_boxName, path: storagePath);
    final repository = HiveGruppenRepository._(box);
    repository._seedCache();
    repository._eventSubscription = repository._box.watch(key: _activeKey)
        .listen(repository._handleBoxEvent);
    return repository;
  }

  void _seedCache() {
    final raw = _box.get(_activeKey);
    if (raw is Map) {
      try {
        _cached = GruppenSnapshot.fromJson(raw.cast<String, dynamic>());
      } on FormatException {
        _cached = null;
      }
    }
  }

  void _handleBoxEvent(BoxEvent event) {
    final raw = event.value;
    if (raw is Map) {
      try {
        _cached = GruppenSnapshot.fromJson(raw.cast<String, dynamic>());
      } on FormatException {
        _cached = null;
      }
    } else {
      _cached = null;
    }
    _controller.add(_cached);
  }

  /// Reaktiver Stream des aktiven Gruppen-Snapshots.
  ///
  /// Gibt sofort den aktuellen Wert (oder `null`) aus.
  Stream<GruppenSnapshot?> watchGruppe() async* {
    yield _cached;
    yield* _controller.stream;
  }

  /// Laedt den aktuellen Snapshot einmalig.
  GruppenSnapshot? loadGruppe() => _cached;

  /// Speichert einen Gruppen-Snapshot dauerhaft.
  Future<void> saveGruppe(GruppenSnapshot snapshot) async {
    await _box.put(_activeKey, snapshot.toJson());
  }

  /// Loescht den gespeicherten Gruppen-Snapshot.
  Future<void> deleteGruppe() async {
    await _box.delete(_activeKey);
  }

  /// Gibt Ressourcen frei.
  Future<void> close() async {
    await _eventSubscription?.cancel();
    await _controller.close();
    await _box.close();
  }
}
