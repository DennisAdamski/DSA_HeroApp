/// Generisches Feld-Diff fuer Sync-Konflikte zwischen lokalem und
/// Online-Stand eines Datenobjekts (z.B. `HeroSheet.toJson()`).
///
/// Verglichen werden die `toJson()`-Maps beider Seiten, analog zur
/// Kanonisierung in `stableContentHash`. Das Ergebnis enthaelt nur die
/// Unterschiede, damit die Konflikt-UI kompakt bleiben kann.
library;

/// Art eines einzelnen Diff-Eintrags.
enum SyncDiffKind {
  /// Wert existiert auf beiden Seiten, unterscheidet sich aber.
  changed,

  /// Wert existiert nur in der lokalen Version.
  onlyLocal,

  /// Wert existiert nur in der Online-Version.
  onlyRemote,
}

/// Einzelner Unterschied zwischen lokaler und Online-Version.
class SyncDiffEntry {
  /// Erstellt einen Diff-Eintrag fuer einen Pfad im Datenobjekt.
  const SyncDiffEntry({
    required this.path,
    required this.kind,
    this.localValue,
    this.remoteValue,
  });

  /// Pfadsegmente zum Feld, z.B. `['talents', 'klettern', 'taw']`.
  final List<String> path;

  /// Art des Unterschieds.
  final SyncDiffKind kind;

  /// Roher JSON-Wert der lokalen Seite (`null` bei [SyncDiffKind.onlyRemote]).
  final Object? localValue;

  /// Roher JSON-Wert der Online-Seite (`null` bei [SyncDiffKind.onlyLocal]).
  final Object? remoteValue;
}

/// Ergebnis eines Objektvergleichs zwischen lokaler und Online-Version.
class SyncObjectDiff {
  /// Erstellt ein unveraenderliches Diff-Ergebnis.
  const SyncObjectDiff({
    this.entries = const <SyncDiffEntry>[],
    this.truncated = false,
    this.localMissing = false,
    this.remoteMissing = false,
  });

  /// Alle gefundenen Unterschiede in natuerlicher Feldreihenfolge.
  final List<SyncDiffEntry> entries;

  /// True, wenn der Vergleich beim Eintragslimit abgebrochen wurde.
  final bool truncated;

  /// True, wenn die lokale Seite komplett fehlt.
  final bool localMissing;

  /// True, wenn die Online-Seite geloescht wurde oder fehlt.
  final bool remoteMissing;

  /// Ob sich mindestens ein Wert unterscheidet.
  bool get hatAenderungen =>
      entries.isNotEmpty || localMissing || remoteMissing;
}

/// Vergleicht zwei JSON-Maps rekursiv und liefert nur die Unterschiede.
///
/// [ignoredTopLevelKeys] blendet Felder aus, die keine inhaltliche
/// Aenderung darstellen (Zeitstempel, Schema-Version) — konsistent zu
/// `heroContentHash`. [maxEntries] begrenzt die Ergebnisgroesse; bei
/// Erreichen wird [SyncObjectDiff.truncated] gesetzt.
SyncObjectDiff computeSyncObjectDiff(
  Map<String, dynamic>? local,
  Map<String, dynamic>? remote, {
  Set<String> ignoredTopLevelKeys = const {'lastModified', 'schemaVersion'},
  int maxEntries = 200,
}) {
  if (local == null || remote == null) {
    return SyncObjectDiff(
      localMissing: local == null,
      remoteMissing: remote == null,
    );
  }
  final collector = _DiffCollector(maxEntries);
  _diffMaps(
    local,
    remote,
    const <String>[],
    collector,
    ignoredKeys: ignoredTopLevelKeys,
  );
  return SyncObjectDiff(
    entries: List<SyncDiffEntry>.unmodifiable(collector.entries),
    truncated: collector.truncated,
  );
}

/// Formatiert einen JSON-Wert kompakt fuer die Anzeige in der Konflikt-UI.
///
/// Lange Texte werden auf [maxLength] Zeichen gekuerzt; Maps und Listen
/// werden nur zusammengefasst statt vollstaendig ausgegeben.
String formatSyncDiffValue(Object? value, {int maxLength = 80}) {
  if (value == null) {
    return '—';
  }
  if (value is Map) {
    return '{…} (${value.length} Felder)';
  }
  if (value is Iterable) {
    return '[…] (${value.length} Einträge)';
  }
  final text = value.toString();
  if (text.isEmpty) {
    return '(leer)';
  }
  if (text.length <= maxLength) {
    return text;
  }
  return '${text.substring(0, maxLength)}…';
}

class _DiffCollector {
  _DiffCollector(this.maxEntries);

  final int maxEntries;
  final List<SyncDiffEntry> entries = <SyncDiffEntry>[];
  bool truncated = false;

  bool get isFull => entries.length >= maxEntries;

  void add(SyncDiffEntry entry) {
    if (isFull) {
      truncated = true;
      return;
    }
    entries.add(entry);
  }
}

void _diffMaps(
  Map<dynamic, dynamic> local,
  Map<dynamic, dynamic> remote,
  List<String> path,
  _DiffCollector collector, {
  Set<String> ignoredKeys = const <String>{},
}) {
  if (collector.isFull) {
    collector.truncated = true;
    return;
  }
  // Lokale Key-Reihenfolge zuerst, damit die natuerliche toJson()-Ordnung
  // erhalten bleibt; danach nur-online vorhandene Keys.
  final keys = <String>[
    for (final key in local.keys) key.toString(),
    for (final key in remote.keys)
      if (!local.containsKey(key)) key.toString(),
  ];
  for (final key in keys) {
    if (collector.isFull) {
      collector.truncated = true;
      return;
    }
    if (ignoredKeys.contains(key)) {
      continue;
    }
    final childPath = [...path, key];
    final hasLocal = local.containsKey(key);
    final hasRemote = remote.containsKey(key);
    if (hasLocal && !hasRemote) {
      collector.add(
        SyncDiffEntry(
          path: childPath,
          kind: SyncDiffKind.onlyLocal,
          localValue: local[key],
        ),
      );
      continue;
    }
    if (!hasLocal && hasRemote) {
      collector.add(
        SyncDiffEntry(
          path: childPath,
          kind: SyncDiffKind.onlyRemote,
          remoteValue: remote[key],
        ),
      );
      continue;
    }
    _diffValues(local[key], remote[key], childPath, collector);
  }
}

void _diffValues(
  Object? local,
  Object? remote,
  List<String> path,
  _DiffCollector collector,
) {
  if (_deepEquals(local, remote)) {
    return;
  }
  if (local is Map && remote is Map) {
    _diffMaps(local, remote, path, collector);
    return;
  }
  if (local is List && remote is List) {
    _diffLists(local, remote, path, collector);
    return;
  }
  collector.add(
    SyncDiffEntry(
      path: path,
      kind: SyncDiffKind.changed,
      localValue: local,
      remoteValue: remote,
    ),
  );
}

void _diffLists(
  List<dynamic> local,
  List<dynamic> remote,
  List<String> path,
  _DiffCollector collector,
) {
  if (_isPrimitiveList(local) && _isPrimitiveList(remote)) {
    // Mengenbasiert: reine Umsortierung ergibt kein Diff.
    for (final value in local) {
      if (!remote.any((other) => _deepEquals(value, other))) {
        collector.add(
          SyncDiffEntry(
            path: path,
            kind: SyncDiffKind.onlyLocal,
            localValue: value,
          ),
        );
      }
    }
    for (final value in remote) {
      if (!local.any((other) => _deepEquals(value, other))) {
        collector.add(
          SyncDiffEntry(
            path: path,
            kind: SyncDiffKind.onlyRemote,
            remoteValue: value,
          ),
        );
      }
    }
    return;
  }

  final localById = _tryKeyById(local);
  final remoteById = _tryKeyById(remote);
  if (localById != null && remoteById != null) {
    // Nach id keyen: Umsortierung ergibt kein Diff, Aenderungen werden
    // pro Element rekursiv verglichen.
    for (final entry in localById.entries) {
      final remoteElement = remoteById[entry.key];
      final childPath = [...path, _listElementLabel(entry.value, entry.key)];
      if (remoteElement == null) {
        collector.add(
          SyncDiffEntry(
            path: childPath,
            kind: SyncDiffKind.onlyLocal,
            localValue: entry.value,
          ),
        );
        continue;
      }
      _diffValues(entry.value, remoteElement, childPath, collector);
    }
    for (final entry in remoteById.entries) {
      if (localById.containsKey(entry.key)) {
        continue;
      }
      collector.add(
        SyncDiffEntry(
          path: [...path, _listElementLabel(entry.value, entry.key)],
          kind: SyncDiffKind.onlyRemote,
          remoteValue: entry.value,
        ),
      );
    }
    return;
  }

  // Index-Fallback fuer gemischte oder id-lose Listen.
  final sharedLength =
      local.length < remote.length ? local.length : remote.length;
  for (var i = 0; i < sharedLength; i++) {
    _diffValues(local[i], remote[i], [...path, '[$i]'], collector);
  }
  for (var i = sharedLength; i < local.length; i++) {
    collector.add(
      SyncDiffEntry(
        path: [...path, '[$i]'],
        kind: SyncDiffKind.onlyLocal,
        localValue: local[i],
      ),
    );
  }
  for (var i = sharedLength; i < remote.length; i++) {
    collector.add(
      SyncDiffEntry(
        path: [...path, '[$i]'],
        kind: SyncDiffKind.onlyRemote,
        remoteValue: remote[i],
      ),
    );
  }
}

bool _isPrimitiveList(List<dynamic> values) {
  return values.every(
    (value) => value == null || value is String || value is num || value is bool,
  );
}

/// Versucht, eine Listen-Elemente-Map nach String-`id` zu keyen.
///
/// Liefert `null`, wenn nicht alle Elemente Maps mit eindeutiger
/// String-`id` sind.
Map<String, Map<dynamic, dynamic>>? _tryKeyById(List<dynamic> values) {
  final result = <String, Map<dynamic, dynamic>>{};
  for (final value in values) {
    if (value is! Map) {
      return null;
    }
    final id = value['id'];
    if (id is! String || id.isEmpty || result.containsKey(id)) {
      return null;
    }
    result[id] = value;
  }
  return result;
}

/// Anzeigename fuer ein id-gekeytes Listenelement (bevorzugt `name`).
String _listElementLabel(Map<dynamic, dynamic> element, String id) {
  final name = element['name'];
  if (name is String && name.trim().isNotEmpty) {
    return name.trim();
  }
  return id;
}

bool _deepEquals(Object? a, Object? b) {
  if (identical(a, b)) {
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) {
      return false;
    }
    for (final key in a.keys) {
      if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) {
        return false;
      }
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) {
        return false;
      }
    }
    return true;
  }
  return a == b;
}
