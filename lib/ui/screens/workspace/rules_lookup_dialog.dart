import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_search.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_types.dart';

/// Prüft, ob die Regelsuche auf dieser Plattform angeboten werden kann.
///
/// Delegiert an die Plattform-Fassade: Desktop und Web ja (Web setzt einen
/// einmaligen Datei-Import voraus), Mobil nein.
bool isRulesLookupSupported() => rulesIndexSearchSupported();

/// Öffnet den Regel-Nachschlag-Dialog.
Future<void> showRulesLookupDialog({required BuildContext context}) {
  return showDialog<void>(
    context: context,
    builder: (_) => const RulesLookupDialog(),
  );
}

/// Dialog für die Volltextsuche in der dsa-rules-Wissensbasis.
///
/// Nutzt die vom MCP-Indexer gepflegte SQLite-Datenbank read-only und
/// bietet eine reine FTS5-Keyword-Suche über wählbare Quellkategorien. Auf
/// Web muss die Index-Datenbank zuvor einmalig hochgeladen werden, da dort
/// kein Zugriff auf einen Nutzer-lokalen Standardpfad möglich ist.
class RulesLookupDialog extends StatefulWidget {
  /// Erzeugt den Dialog.
  const RulesLookupDialog({super.key});

  @override
  State<RulesLookupDialog> createState() => _RulesLookupDialogState();
}

class _RulesLookupDialogState extends State<RulesLookupDialog> {
  RulesIndexSearch? _search;
  bool _loading = true;
  bool _importing = false;
  String? _importError;
  List<RulesSearchHit> _hits = const <RulesSearchHit>[];
  String _query = '';
  bool _searched = false;

  /// Standardmäßig durchsuchte Kategorien (wie beim MCP-Server).
  final Set<RulesSourceCategory> _categories = <RulesSourceCategory>{
    RulesSourceCategory.regelbuecher,
    RulesSourceCategory.hausregeln,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final search = await openRulesIndexSearch();
    if (!mounted) {
      search?.dispose();
      return;
    }
    setState(() {
      _search = search;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _search?.dispose();
    super.dispose();
  }

  /// Führt die Suche mit aktueller Eingabe und Kategorie-Auswahl aus.
  void _runSearch() {
    final search = _search;
    if (search == null) {
      return;
    }
    final hits = search.search(_query, categories: _categories);
    setState(() {
      _hits = hits;
      _searched = true;
    });
  }

  /// Merkt die Eingabe und sucht live ab drei Zeichen.
  void _onQueryChanged(String value) {
    _query = value;
    if (value.trim().length >= 3) {
      _runSearch();
    } else if (_searched) {
      setState(() {
        _hits = const <RulesSearchHit>[];
        _searched = false;
      });
    }
  }

  /// Schaltet eine Quellkategorie um und aktualisiert die Treffer.
  void _toggleCategory(RulesSourceCategory category, bool selected) {
    setState(() {
      if (selected) {
        _categories.add(category);
      } else {
        _categories.remove(category);
      }
    });
    if (_query.trim().length >= 3) {
      _runSearch();
    }
  }

  /// Öffnet die Detailansicht mit dem vollen Chunk-Kontext.
  void _openHitDetail(RulesSearchHit hit) {
    final search = _search;
    if (search == null) {
      return;
    }
    final text = search.loadChunkContext(hit.chunkId);
    showDialog<void>(
      context: context,
      builder: (detailContext) => AlertDialog(
        title: Text(hit.sourceTitle),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Text(text.isEmpty ? 'Kein Text verfügbar.' : text),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(detailContext).pop(),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  /// Lässt den Nutzer eine `index.sqlite` auswählen und importiert sie.
  ///
  /// Wird sowohl für den Erstimport (Web-Leerzustand) als auch zum
  /// Ersetzen einer bereits importierten Datenbank verwendet.
  Future<void> _pickAndImport() async {
    setState(() {
      _importError = null;
      _importing = true;
    });
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['sqlite'],
      withData: true,
    );
    final bytes = result != null && result.files.isNotEmpty
        ? result.files.first.bytes
        : null;
    if (bytes == null) {
      if (!mounted) {
        return;
      }
      setState(() => _importing = false);
      return;
    }
    try {
      final newSearch = await importRulesIndexDatabase(bytes);
      final oldSearch = _search;
      if (!mounted) {
        newSearch.dispose();
        return;
      }
      oldSearch?.dispose();
      setState(() {
        _search = newSearch;
        _importing = false;
        _hits = const <RulesSearchHit>[];
        _searched = false;
        _query = '';
      });
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _importing = false;
        _importError = error.message;
      });
      if (_search != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 640),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
    if (_search == null) {
      return kIsWeb ? _buildImportNotice() : _buildUnavailableNotice();
    }
    return _buildSearch();
  }

  /// Hinweis, wenn die Index-Datenbank fehlt oder nicht lesbar ist (Desktop).
  Widget _buildUnavailableNotice() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Regel-Wissensbasis nicht gefunden',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          const Text(
            'Die Suche nutzt die lokale Index-Datenbank des dsa-rules '
            'MCP-Servers. Bitte einmalig den Index aufbauen:\n\n'
            'tool/mcp_dsa_rules → dsa-rules-cli refresh',
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Schließen'),
            ),
          ),
        ],
      ),
    );
  }

  /// Hinweis auf Web, solange noch keine Index-Datenbank importiert wurde.
  Widget _buildImportNotice() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Regel-Wissensbasis noch nicht importiert',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          const Text(
            'Die Suche nutzt eine lokal importierte Index-Datenbank. Bitte '
            'einmalig am Desktop mit tool/mcp_dsa_rules → '
            'dsa-rules-cli refresh erzeugen und die entstandene '
            'index.sqlite hier hochladen. Der Import bleibt danach in '
            'diesem Browser gespeichert.',
          ),
          if (_importError != null) ...[
            const SizedBox(height: 12),
            Text(
              _importError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Schließen'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                key: const ValueKey('rules-lookup-import-button'),
                onPressed: _importing ? null : _pickAndImport,
                icon: _importing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_outlined),
                label: const Text('index.sqlite hochladen'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Baut Suchfeld, Kategorie-Chips und Trefferliste.
  Widget _buildSearch() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (kIsWeb)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  key: const ValueKey('rules-lookup-replace-button'),
                  tooltip: 'Index ersetzen',
                  onPressed: _importing ? null : _pickAndImport,
                  icon: _importing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file_outlined),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            key: const ValueKey('rules-lookup-search-field'),
            autofocus: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.menu_book_outlined),
              hintText: 'Regel suchen (z. B. „Ausweichen Behinderung“) …',
            ),
            onChanged: _onQueryChanged,
            onSubmitted: (_) => _runSearch(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final category in RulesSourceCategory.values)
                FilterChip(
                  key: ValueKey('rules-lookup-category-${category.name}'),
                  label: Text(category.label),
                  visualDensity: VisualDensity.compact,
                  selected: _categories.contains(category),
                  onSelected: (selected) => _toggleCategory(category, selected),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Flexible(child: _buildResults()),
      ],
    );
  }

  /// Baut die Trefferliste oder passende Leerzustände.
  Widget _buildResults() {
    if (!_searched) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text('Mindestens drei Zeichen eingeben, um zu suchen.'),
        ),
      );
    }
    if (_hits.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('Keine Treffer gefunden.')),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: _hits.length,
      itemBuilder: (context, index) {
        final hit = _hits[index];
        final categoryLabel = hit.category?.label ?? 'Unbekannt';
        final pages = hit.pageStart == hit.pageEnd
            ? 'S. ${hit.pageStart}'
            : 'S. ${hit.pageStart}–${hit.pageEnd}';
        return ListTile(
          key: ValueKey('rules-lookup-hit-${hit.chunkId}'),
          dense: true,
          title: Text(
            hit.snippet,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text('$categoryLabel · ${hit.sourceTitle} · $pages'),
          onTap: () => _openHitDetail(hit),
        );
      },
    );
  }
}
