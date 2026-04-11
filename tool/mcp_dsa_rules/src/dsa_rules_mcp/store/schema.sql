PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS meta (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS sources (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    category     TEXT NOT NULL,
    path         TEXT NOT NULL UNIQUE,
    title        TEXT NOT NULL,
    mtime        REAL NOT NULL,
    sha256       TEXT NOT NULL,
    page_count   INTEGER NOT NULL,
    indexed_at   TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_sources_category ON sources (category);

CREATE TABLE IF NOT EXISTS chunks (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    source_id    INTEGER NOT NULL REFERENCES sources (id) ON DELETE CASCADE,
    chunk_index  INTEGER NOT NULL,
    page_start   INTEGER NOT NULL,
    page_end     INTEGER NOT NULL,
    text         TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_chunks_source ON chunks (source_id);

CREATE VIRTUAL TABLE IF NOT EXISTS chunks_fts USING fts5 (
    text,
    content = 'chunks',
    content_rowid = 'id',
    tokenize = 'unicode61 remove_diacritics 2'
);

CREATE TRIGGER IF NOT EXISTS chunks_ai AFTER INSERT ON chunks BEGIN
    INSERT INTO chunks_fts (rowid, text) VALUES (new.id, new.text);
END;

CREATE TRIGGER IF NOT EXISTS chunks_ad AFTER DELETE ON chunks BEGIN
    INSERT INTO chunks_fts (chunks_fts, rowid, text) VALUES ('delete', old.id, old.text);
END;

CREATE TRIGGER IF NOT EXISTS chunks_au AFTER UPDATE ON chunks BEGIN
    INSERT INTO chunks_fts (chunks_fts, rowid, text) VALUES ('delete', old.id, old.text);
    INSERT INTO chunks_fts (rowid, text) VALUES (new.id, new.text);
END;

CREATE TABLE IF NOT EXISTS chunks_vec (
    chunk_id    INTEGER PRIMARY KEY REFERENCES chunks (id) ON DELETE CASCADE,
    dim         INTEGER NOT NULL,
    embedding   BLOB NOT NULL
);
