import 'dart:typed_data';

import 'package:sqlite3/wasm.dart';

import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_types.dart';

/// Web-Variante: SQLite via WebAssembly, Persistenz in einer IndexedDB.
///
/// Web hat keinen Zugriff auf ein Nutzer-lokales Dateisystem: Es gibt keinen
/// Standardpfad zur Index-Datenbank wie unter Desktop. Der Nutzer muss die
/// am Desktop erzeugte `index.sqlite` einmalig über [importRulesIndexDatabase]
/// hochladen; sie bleibt danach origin-gebunden in der Browser-IndexedDB
/// erhalten und muss nicht bei jedem Seitenaufruf erneut hochgeladen werden.
const _dbFileName = '/index.sqlite';
const _importFileName = '/index.sqlite.import';
const _indexedDbName = 'dsa-rules-index';

Future<WasmSqlite3>? _sqlite3Future;
Future<IndexedDbFileSystem>? _fileSystemFuture;

/// Web bietet die Regelsuche technisch immer an; ob bereits ein Index
/// importiert wurde, klärt erst [openRulesIndexSearch].
bool rulesIndexSearchSupported() => true;

/// Öffnet die zuvor importierte Regel-Volltextsuche oder liefert `null`,
/// wenn noch keine Index-Datenbank importiert wurde.
Future<RulesIndexSearch?> openRulesIndexSearch() async {
  final sqlite = await _ensureSqlite();
  final fs = await _ensureFileSystem();
  if (fs.xAccess(_dbFileName, 0) == 0) {
    return null;
  }
  try {
    final db = sqlite.open(_dbFileName, mode: OpenMode.readOnly);
    return _WasmRulesIndexSearch(db);
  } on SqliteException {
    return null;
  }
}

/// Importiert eine vom Nutzer hochgeladene `index.sqlite` in die IndexedDB
/// und öffnet sie anschließend read-only.
///
/// Validiert die Datei zunächst unter einem temporären Pfad, bevor eine
/// zuvor importierte Datenbank ersetzt wird — ein fehlgeschlagener Import
/// (z. B. versehentlich falsche Datei beim „Index ersetzen") darf eine
/// funktionierende Datenbank nicht zerstören. Wirft eine [FormatException],
/// wenn [bytes] keine gültige Regel-Index-Datenbank enthält (z. B. falsche
/// Datei oder fehlendes FTS5-Schema).
Future<RulesIndexSearch> importRulesIndexDatabase(Uint8List bytes) async {
  final sqlite = await _ensureSqlite();
  final fs = await _ensureFileSystem();
  _disableWalMode(bytes);

  _writeFile(fs, _importFileName, bytes);
  await fs.flush();

  final validated = _tryOpen(sqlite, _importFileName);
  if (validated == null) {
    _deleteFileSync(fs, _importFileName);
    await fs.flush();
    throw const FormatException(
      'Datei ist keine gültige SQLite-Datenbank.',
    );
  }
  try {
    validated.select('SELECT count(*) FROM chunks_fts LIMIT 1');
  } on SqliteException {
    validated.dispose();
    _deleteFileSync(fs, _importFileName);
    await fs.flush();
    throw const FormatException(
      'Datei enthält kein gültiges Regel-Index-Schema.',
    );
  }
  validated.dispose();

  _deleteFileSync(fs, _dbFileName);
  _writeFile(fs, _dbFileName, bytes);
  _deleteFileSync(fs, _importFileName);
  await fs.flush();

  final db = sqlite.open(_dbFileName, mode: OpenMode.readOnly);
  return _WasmRulesIndexSearch(db);
}

CommonDatabase? _tryOpen(WasmSqlite3 sqlite, String path) {
  try {
    return sqlite.open(path, mode: OpenMode.readOnly);
  } on SqliteException {
    return null;
  }
}

void _deleteFileSync(IndexedDbFileSystem fs, String path) {
  if (fs.xAccess(path, 0) != 0) {
    fs.xDelete(path, 0);
  }
}

void _writeFile(IndexedDbFileSystem fs, String path, Uint8List bytes) {
  _deleteFileSync(fs, path);
  final opened = fs.xOpen(
    Sqlite3Filename(path),
    SqlFlag.SQLITE_OPEN_CREATE | SqlFlag.SQLITE_OPEN_READWRITE,
  );
  final file = opened.file;
  try {
    file.xWrite(bytes, 0);
  } finally {
    file.xClose();
  }
}

/// Der dsa-rules-Indexer erzeugt `index.sqlite` im WAL-Journal-Modus
/// (`PRAGMA journal_mode = WAL` in `tool/mcp_dsa_rules/.../schema.sql`).
/// `IndexedDbFileSystem` implementiert kein `xShmMap` (WAL-Shared-Memory);
/// jede Abfrage gegen eine so importierte Datei schlägt sonst mit
/// `SqliteException(26)` ("file is not a database") fehl, obwohl die Datei
/// gültig ist. Da beim Import ohnehin nur die zuletzt aufgeraeumte
/// (gecheckpointete) Haupt-DB-Datei hochgeladen wird — nie eine separate
/// `-wal`-Datei —, reicht es, die Header-Bytes 18/19 (File-Format-Version)
/// von 2 (WAL) auf 1 (Rollback-Journal) zu patchen: Die Seitendaten bleiben
/// unveraendert, nur der deklarierte Journal-Modus wechselt auf den von
/// dieser VFS unterstuetzten Rollback-Modus.
void _disableWalMode(Uint8List bytes) {
  if (bytes.length > 19 && bytes[18] == 2 && bytes[19] == 2) {
    bytes[18] = 1;
    bytes[19] = 1;
  }
}

Future<WasmSqlite3> _ensureSqlite() {
  return _sqlite3Future ??= WasmSqlite3.loadFromUrl(
    Uri.parse('sqlite3.wasm'),
  );
}

Future<IndexedDbFileSystem> _ensureFileSystem() {
  return _fileSystemFuture ??= _initFileSystem();
}

Future<IndexedDbFileSystem> _initFileSystem() async {
  final sqlite = await _ensureSqlite();
  final fs = await IndexedDbFileSystem.open(dbName: _indexedDbName);
  sqlite.registerVirtualFileSystem(fs, makeDefault: true);
  return fs;
}

/// Read-only-Zugriff auf die vom Nutzer importierte Index-Datenbank.
///
/// Spiegelt `_SqliteRulesIndexSearch` aus `rules_index_search_io.dart`;
/// gleiche Abfragen, aber über die `CommonDatabase`-Schnittstelle, die
/// sowohl von der FFI- als auch der WASM-Implementierung erfüllt wird.
class _WasmRulesIndexSearch implements RulesIndexSearch {
  _WasmRulesIndexSearch(this._db);

  final CommonDatabase _db;

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
