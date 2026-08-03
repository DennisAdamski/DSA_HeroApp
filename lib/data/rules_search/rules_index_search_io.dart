import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_types.dart';

/// Prüft, ob die Regelsuche auf dieser Plattform angeboten werden kann.
///
/// Die Index-Datenbank liegt nutzerlokal auf dem Desktop; Mobil-Builds
/// blenden den Einstieg aus, bis ein DB-Transfer unterstützt wird.
bool rulesIndexSearchSupported() {
  return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
}

/// Öffnet die Regel-Volltextsuche read-only oder liefert `null`.
///
/// `null` bedeutet: Plattform ungeeignet oder keine der beiden Quellen
/// (lokal per `dsa-rules-cli refresh` gebaute Datei, per Server-Sync
/// heruntergeladene Cache-Datei) ist vorhanden/lesbar. Der Aufrufer zeigt
/// dann einen Hinweis. Async aus Symmetrie mit der Web-Variante, die die
/// Index-Datei erst asynchron laden kann.
///
/// Die lokal per `dsa-rules-cli refresh` gebaute Datei hat Vorrang vor dem
/// Server-Cache — ein Entwickler/Power-User, der den Index selbst pflegt,
/// soll nicht durch einen alten Server-Stand überstimmt werden.
Future<RulesIndexSearch?> openRulesIndexSearch() async {
  if (!rulesIndexSearchSupported()) {
    return null;
  }
  return _tryOpenAt(_resolveDefaultDbPath()) ??
      _tryOpenAt(_resolveRemoteCacheDbPath());
}

RulesIndexSearch? _tryOpenAt(String path) {
  if (!File(path).existsSync()) {
    return null;
  }
  try {
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    return _SqliteRulesIndexSearch(db);
  } on Object {
    return null;
  }
}

/// Importiert eine per Server-Sync heruntergeladene `index.sqlite` in den
/// Remote-Cache-Pfad und öffnet sie anschließend read-only.
///
/// Schreibt bewusst **nicht** in den von `dsa-rules-cli refresh` gepflegten
/// Standardpfad, um eine lokale Entwickler-Datenbank nicht stillschweigend
/// zu überschreiben. Validate-then-commit wie im Web-Importer: erst unter
/// einem `.tmp`-Pfad schreiben und per Testabfrage gegen `chunks_fts`
/// validieren, bevor ein zuvor funktionierender Cache ersetzt wird — ein
/// abgebrochener/fehlerhafter Download darf keine funktionierende Kopie
/// zerstören.
Future<RulesIndexSearch> importRulesIndexDatabase(Uint8List bytes) async {
  final targetPath = _resolveRemoteCacheDbPath();
  await Directory(_resolveDataDir()).create(recursive: true);

  final tmpPath = '$targetPath.tmp';
  final tmpFile = File(tmpPath);
  await tmpFile.writeAsBytes(bytes, flush: true);

  final Database validated;
  try {
    validated = sqlite3.open(tmpPath, mode: OpenMode.readOnly);
  } on SqliteException {
    await tmpFile.delete();
    throw const FormatException(
      'Datei ist keine gültige SQLite-Datenbank.',
    );
  }
  try {
    validated.select('SELECT count(*) FROM chunks_fts LIMIT 1');
  } on SqliteException {
    validated.dispose();
    await tmpFile.delete();
    throw const FormatException(
      'Datei enthält kein gültiges Regel-Index-Schema.',
    );
  }
  validated.dispose();

  final targetFile = File(targetPath);
  if (await targetFile.exists()) {
    await targetFile.delete();
  }
  await tmpFile.rename(targetPath);

  final db = sqlite3.open(targetPath, mode: OpenMode.readOnly);
  return _SqliteRulesIndexSearch(db);
}

/// Ermittelt das Datenverzeichnis der Index-Datenbank(en).
///
/// Entspricht der Auflösung des MCP-Servers: `DSA_MCP_DATA_DIR` hat Vorrang,
/// danach `%LOCALAPPDATA%/dsa-rules-mcp`, sonst `~/.local/share/dsa-rules-mcp`.
String _resolveDataDir() {
  final override = Platform.environment['DSA_MCP_DATA_DIR'];
  if (override != null && override.isNotEmpty) {
    return override;
  }
  final localAppData = Platform.environment['LOCALAPPDATA'];
  if (localAppData != null && localAppData.isNotEmpty) {
    return '$localAppData${Platform.pathSeparator}dsa-rules-mcp';
  }
  final home = Platform.environment['HOME'] ?? '';
  return '$home/.local/share/dsa-rules-mcp';
}

/// Standardpfad der lokal per `dsa-rules-cli refresh` gebauten Datenbank.
String _resolveDefaultDbPath() =>
    '${_resolveDataDir()}${Platform.pathSeparator}index.sqlite';

/// Pfad der per Server-Sync heruntergeladenen Cache-Datenbank.
String _resolveRemoteCacheDbPath() =>
    '${_resolveDataDir()}${Platform.pathSeparator}index_remote.sqlite';

/// Read-only-Zugriff auf die vom dsa-rules MCP-Indexer erzeugte SQLite-DB.
///
/// Die Datenbank wird ausschließlich lesend geöffnet; Indexpflege bleibt
/// Aufgabe des Python-Tools (`dsa-rules-cli refresh`). Die Suche nutzt nur
/// den FTS5-Anteil der hybriden Wissensbasis (keine Embeddings).
class _SqliteRulesIndexSearch implements RulesIndexSearch {
  _SqliteRulesIndexSearch(this._db);

  final Database _db;

  @override
  void dispose() {
    _db.dispose();
  }

  @override
  List<RulesSearchHit> search(
    String query, {
    required Set<RulesSourceCategory> categories,
    int limit = 20,
  }) {
    final matchExpression = buildRulesMatchExpression(query);
    if (matchExpression.isEmpty || categories.isEmpty) {
      return const <RulesSearchHit>[];
    }
    final placeholders = List.filled(categories.length, '?').join(', ');
    final sql =
        '''
        SELECT c.id AS chunk_id,
               s.title AS source_title,
               s.category AS category,
               c.page_start AS page_start,
               c.page_end AS page_end,
               snippet(chunks_fts, 0, '»', '«', ' … ', 18) AS snippet
        FROM chunks_fts
        JOIN chunks c ON c.id = chunks_fts.rowid
        JOIN sources s ON s.id = c.source_id
        WHERE chunks_fts MATCH ? AND s.category IN ($placeholders)
        ORDER BY bm25(chunks_fts)
        LIMIT ?
        ''';
    final parameters = <Object>[
      matchExpression,
      ...categories.map((category) => category.id),
      limit,
    ];
    final ResultSet rows;
    try {
      rows = _db.select(sql, parameters);
    } on SqliteException {
      return const <RulesSearchHit>[];
    }
    final hits = <RulesSearchHit>[];
    for (final row in rows) {
      hits.add(
        RulesSearchHit(
          chunkId: row['chunk_id'] as int,
          sourceTitle: row['source_title'] as String,
          category: RulesSourceCategory.fromId(row['category'] as String),
          pageStart: row['page_start'] as int,
          pageEnd: row['page_end'] as int,
          snippet: row['snippet'] as String,
        ),
      );
    }
    return hits;
  }

  @override
  String loadChunkContext(int chunkId, {int window = 1}) {
    const sql = '''
        SELECT text FROM chunks
        WHERE source_id = (SELECT source_id FROM chunks WHERE id = ?)
          AND chunk_index BETWEEN
              (SELECT chunk_index FROM chunks WHERE id = ?) - ?
              AND (SELECT chunk_index FROM chunks WHERE id = ?) + ?
        ORDER BY chunk_index
        ''';
    final ResultSet rows;
    try {
      rows = _db.select(sql, <Object>[
        chunkId,
        chunkId,
        window,
        chunkId,
        window,
      ]);
    } on SqliteException {
      return '';
    }
    final parts = <String>[];
    for (final row in rows) {
      parts.add(row['text'] as String);
    }
    return parts.join('\n\n');
  }
}
