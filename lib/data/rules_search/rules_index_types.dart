/// Plattformneutrale Typen und Helfer der Regel-Volltextsuche.
///
/// Diese Datei darf weder `dart:io` noch `dart:ffi` importieren, damit sie
/// in Web-Builds kompiliert. Die eigentliche SQLite-Implementierung liegt in
/// `rules_index_search_io.dart`.
library;

/// Kategorien der dsa-rules-Wissensbasis mit Anzeigenamen.
///
/// Die IDs entsprechen den Kategorie-IDs des MCP-Indexers
/// (`tool/mcp_dsa_rules/src/dsa_rules_mcp/config.py`).
enum RulesSourceCategory {
  /// Offizielle Regelwerke (Standardsuche).
  regelbuecher('regelbuecher', 'Regelbücher'),

  /// Eigene Hausregeln (Standardsuche).
  hausregeln('hausregeln', 'Hausregeln'),

  /// Zusatzinformationen (nur auf Wunsch).
  zusatzinformationen('zusatzinformationen', 'Zusatzinfos'),

  /// Regionalbücher (nur auf Wunsch).
  regionalbuecher('regionalbuecher', 'Regionalbücher');

  const RulesSourceCategory(this.id, this.label);

  /// Persistierte Kategorie-ID in der Index-Datenbank.
  final String id;

  /// Anzeigename für Filter-Chips und Trefferliste.
  final String label;

  /// Liefert die Kategorie zur persistierten ID oder `null`.
  static RulesSourceCategory? fromId(String id) {
    for (final category in RulesSourceCategory.values) {
      if (category.id == id) {
        return category;
      }
    }
    return null;
  }
}

/// Ein Suchtreffer aus der FTS5-Volltextsuche der Regel-Wissensbasis.
class RulesSearchHit {
  /// Erzeugt einen unveränderlichen Suchtreffer.
  const RulesSearchHit({
    required this.chunkId,
    required this.sourceTitle,
    required this.category,
    required this.pageStart,
    required this.pageEnd,
    required this.snippet,
  });

  /// ID des Text-Chunks für das Nachladen des Volltexts.
  final int chunkId;

  /// Titel des Quelldokuments.
  final String sourceTitle;

  /// Kategorie des Quelldokuments (`null` bei unbekannter ID).
  final RulesSourceCategory? category;

  /// Erste Seite des Chunks im Quelldokument.
  final int pageStart;

  /// Letzte Seite des Chunks im Quelldokument.
  final int pageEnd;

  /// Hervorgehobener Textausschnitt rund um die Treffer-Tokens.
  final String snippet;
}

/// Plattformunabhängige Schnittstelle für die Regel-Volltextsuche.
///
/// Implementierungen werden über `rules_index_search.dart` aufgelöst; auf
/// Plattformen ohne lokale Wissensbasis existiert keine Implementierung.
abstract class RulesIndexSearch {
  /// Volltextsuche über die gewählten Kategorien.
  List<RulesSearchHit> search(
    String query, {
    required Set<RulesSourceCategory> categories,
    int limit = 20,
  });

  /// Lädt den vollen Text eines Chunks inklusive Nachbar-Chunks.
  String loadChunkContext(int chunkId, {int window = 1});

  /// Gibt die zugrunde liegenden Ressourcen frei.
  void dispose();
}

/// Baut einen sicheren FTS5-MATCH-Ausdruck aus einer Nutzereingabe.
///
/// Tokens werden gequotet und mit implizitem UND verknüpft; an das letzte
/// Token wird ein Präfix-Stern angehängt, damit Tippen während der Suche
/// sinnvolle Treffer liefert. Leere Eingaben ergeben einen leeren Ausdruck.
String buildRulesMatchExpression(String rawQuery) {
  final tokens = rawQuery
      .split(RegExp(r'\s+'))
      .map((token) => token.replaceAll('"', ''))
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
  if (tokens.isEmpty) {
    return '';
  }
  final quoted = <String>[];
  for (var index = 0; index < tokens.length; index++) {
    final isLast = index == tokens.length - 1;
    final token = tokens[index];
    quoted.add(isLast ? '"$token" *' : '"$token"');
  }
  return quoted.join(' ');
}
