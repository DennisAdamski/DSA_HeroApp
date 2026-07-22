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
/// `null` bedeutet: Plattform ungeeignet, Datei fehlt oder konnte nicht
/// geöffnet werden. Der Aufrufer zeigt dann einen Hinweis auf
/// `dsa-rules-cli refresh`. Async aus Symmetrie mit der Web-Variante, die
/// die Index-Datei erst asynchron laden kann.
Future<RulesIndexSearch?> openRulesIndexSearch() async {
  if (!rulesIndexSearchSupported()) {
    return null;
  }
  final path = _resolveDefaultDbPath();
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

/// Desktop-Variante: Datei-Import ist nur auf Web implementiert, da die
/// Index-Datenbank am Desktop bereits über `_resolveDefaultDbPath()`
/// gefunden wird.
Future<RulesIndexSearch> importRulesIndexDatabase(Uint8List bytes) {
  throw UnsupportedError(
    'Index-Import wird auf dieser Plattform nicht unterstützt.',
  );
}

/// Ermittelt den Standardpfad der Index-Datenbank.
///
/// Entspricht der Auflösung des MCP-Servers: `DSA_MCP_DATA_DIR` hat Vorrang,
/// danach `%LOCALAPPDATA%/dsa-rules-mcp`, sonst `~/.local/share/dsa-rules-mcp`.
String _resolveDefaultDbPath() {
  final override = Platform.environment['DSA_MCP_DATA_DIR'];
  if (override != null && override.isNotEmpty) {
    return '$override${Platform.pathSeparator}index.sqlite';
  }
  final localAppData = Platform.environment['LOCALAPPDATA'];
  if (localAppData != null && localAppData.isNotEmpty) {
    return '$localAppData${Platform.pathSeparator}dsa-rules-mcp'
        '${Platform.pathSeparator}index.sqlite';
  }
  final home = Platform.environment['HOME'] ?? '';
  return '$home/.local/share/dsa-rules-mcp/index.sqlite';
}

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
