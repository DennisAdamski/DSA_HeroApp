import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// Baut eine minimale, gültige Regel-Index-Datenbank (Teilmenge des Schemas
/// aus `tool/mcp_dsa_rules/src/dsa_rules_mcp/store/schema.sql`, ohne WAL/
/// Trigger/Vektor-Tabelle, die für Tests irrelevant sind) und liefert ihre
/// Rohbytes zurück.
Uint8List buildMinimalRulesIndexBytes() {
  final tempDir = Directory.systemTemp.createTempSync('rules_index_fixture');
  final path = p.join(tempDir.path, 'fixture.sqlite');
  final db = sqlite3.open(path);
  try {
    db.execute('''
      CREATE TABLE sources (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        path TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        mtime REAL NOT NULL,
        sha256 TEXT NOT NULL,
        page_count INTEGER NOT NULL,
        indexed_at TEXT NOT NULL
      );

      CREATE TABLE chunks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_id INTEGER NOT NULL REFERENCES sources (id),
        chunk_index INTEGER NOT NULL,
        page_start INTEGER NOT NULL,
        page_end INTEGER NOT NULL,
        text TEXT NOT NULL
      );

      CREATE VIRTUAL TABLE chunks_fts USING fts5 (
        text,
        content = 'chunks',
        content_rowid = 'id'
      );
    ''');
    db.execute(
      'INSERT INTO sources (category, path, title, mtime, sha256, '
      'page_count, indexed_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [
        'regelbuecher',
        'fixture.pdf',
        'Fixture-Regelwerk',
        0.0,
        'deadbeef',
        1,
        '2026-08-01T00:00:00Z',
      ],
    );
    db.execute(
      'INSERT INTO chunks (source_id, chunk_index, page_start, page_end, '
      'text) VALUES (1, 0, 1, 1, ?)',
      ['Ausweichen erschwert eine Behinderung um den Wert der Behinderung.'],
    );
    db.execute(
      'INSERT INTO chunks_fts (rowid, text) VALUES (?, ?)',
      [1, 'Ausweichen erschwert eine Behinderung um den Wert der Behinderung.'],
    );
  } finally {
    db.dispose();
  }
  final bytes = File(path).readAsBytesSync();
  tempDir.deleteSync(recursive: true);
  return bytes;
}
