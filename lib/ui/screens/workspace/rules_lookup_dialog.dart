import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_remote_client.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_search.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_sync_service.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_types.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/catalog_unlock_dialog.dart';

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
/// bietet eine reine FTS5-Keyword-Suche über wählbare Quellkategorien. Fehlt
/// die Datenbank, bietet der Leerzustand den Server-Download an (sofern ein
/// Server hinterlegt ist); auf Web außerdem den Datei-Upload, da dort kein
/// Zugriff auf einen Nutzer-lokalen Standardpfad möglich ist.
class RulesLookupDialog extends ConsumerStatefulWidget {
  /// Erzeugt den Dialog.
  ///
  /// [oeffneIndex] und [syncService] ersetzen in Tests den Zugriff auf die
  /// lokale Index-Datenbank und den Server.
  const RulesLookupDialog({super.key, this.oeffneIndex, this.syncService});

  /// Öffnet die Index-Datenbank; ohne Angabe [openRulesIndexSearch].
  final Future<RulesIndexSearch?> Function()? oeffneIndex;

  /// Lädt vom Server; ohne Angabe ein [RulesIndexSyncService].
  final RulesIndexSyncService? syncService;

  @override
  ConsumerState<RulesLookupDialog> createState() => _RulesLookupDialogState();
}

class _RulesLookupDialogState extends ConsumerState<RulesLookupDialog> {
  RulesIndexSearch? _search;
  bool _loading = true;
  bool _importing = false;
  bool _syncing = false;
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
    final search = await (widget.oeffneIndex ?? openRulesIndexSearch)();
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
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const <String>['sqlite'],
    );
    if (file == null) {
      if (!mounted) {
        return;
      }
      setState(() => _importing = false);
      return;
    }
    final bytes = await file.readAsBytes();
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  /// Lädt die Index-Datenbank vom konfigurierten Server und ersetzt den
  /// aktuell geöffneten Index (falls vorhanden) nach erfolgreicher Validierung.
  ///
  /// Setzt voraus, dass der Nutzer das Katalog-Entschlüsselungspasswort
  /// kennt: fehlt es noch, wird zuerst [showCatalogUnlockDialog] geöffnet.
  Future<void> _syncFromServer() async {
    var unlocked = ref.read(catalogContentVisibleProvider);
    if (!unlocked) {
      unlocked = await showCatalogUnlockDialog(context: context, ref: ref);
      if (!unlocked || !mounted) {
        return;
      }
    }

    setState(() {
      _syncing = true;
      _importError = null;
    });
    final config = ref.read(rulesIndexRemoteConfigProvider);
    try {
      final newSearch = await (widget.syncService ?? RulesIndexSyncService())
          .syncFromServer(config);
      final oldSearch = _search;
      if (!mounted) {
        newSearch.dispose();
        return;
      }
      oldSearch?.dispose();
      await ref
          .read(settingsActionsProvider)
          .saveRulesIndexRemoteConfig(
            config.copyWith(lastSyncedAt: DateTime.now()),
          );
      setState(() {
        _search = newSearch;
        _syncing = false;
        _hits = const <RulesSearchHit>[];
        _searched = false;
        _query = '';
      });
    } on RulesIndexDownloadException catch (error) {
      _handleSyncError(
        kIsWeb && error.kind == RulesIndexDownloadErrorKind.network
            ? '${error.message}\n'
                  'Im Browser blockiert der Server den Zugriff häufig (CORS). '
                  'Lade stattdessen die index.sqlite hoch.'
            : error.message,
      );
    } on FormatException catch (error) {
      _handleSyncError(error.message);
    }
  }

  /// Zeigt einen Sync-Fehler im Leerzustand-Hinweistext, oder als Snackbar,
  /// wenn bereits eine funktionierende Suche geöffnet ist.
  void _handleSyncError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _syncing = false;
      _importError = message;
    });
    if (_search != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
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
      return _buildNotice();
    }
    return _buildSearch();
  }

  /// Leerzustand, solange keine Index-Datenbank geöffnet werden kann.
  ///
  /// Nennt zuerst den bequemsten Weg: den Server-Download, sofern für diesen
  /// Build ein Server hinterlegt ist. Der manuelle Weg (Desktop: selbst
  /// bauen, Web: Datei hochladen) steht darunter. Auf Web ist der Upload
  /// immer möglich, der Server-Download scheitert dort an fehlenden
  /// CORS-Freigaben des Servers und verweist dann auf den Upload.
  Widget _buildNotice() {
    final konfiguriert = ref.watch(rulesIndexRemoteConfigProvider).isConfigured;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              kIsWeb
                  ? 'Regel-Wissensbasis noch nicht importiert'
                  : 'Regel-Wissensbasis nicht gefunden',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              konfiguriert
                  ? 'Am einfachsten lädst du die Wissensbasis vom Server. Die '
                        'App fragt dafür einmal das Katalogpasswort ab; danach '
                        'bleibt sie auf diesem Gerät gespeichert.'
                  : 'Für diesen Build ist kein Regel-Server eingerichtet. Die '
                        'Wissensbasis musst du selbst bereitstellen.',
              key: const ValueKey('rules-lookup-notice-server'),
            ),
            const SizedBox(height: 12),
            Text(
              kIsWeb
                  ? 'Alternativ: einmalig am Desktop mit tool/mcp_dsa_rules → '
                        'dsa-rules-cli refresh die index.sqlite erzeugen und '
                        'hier hochladen. Der Import bleibt danach in diesem '
                        'Browser gespeichert.'
                  : 'Alternativ: einmalig selbst aufbauen mit tool/mcp_dsa_rules '
                        '→ dsa-rules-cli refresh.',
              style: theme.textTheme.bodySmall,
            ),
            if (_importError != null) ...[
              const SizedBox(height: 12),
              Text(
                _importError!,
                key: const ValueKey('rules-lookup-notice-error'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Schließen'),
                ),
                if (kIsWeb)
                  OutlinedButton.icon(
                    key: const ValueKey('rules-lookup-import-button'),
                    onPressed: _importing || _syncing ? null : _pickAndImport,
                    icon: _importing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file_outlined),
                    label: const Text('index.sqlite hochladen'),
                  ),
                if (konfiguriert)
                  FilledButton.icon(
                    key: const ValueKey('rules-lookup-sync-button'),
                    onPressed: _syncing || _importing ? null : _syncFromServer,
                    icon: _syncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_download_outlined),
                    label: const Text('Von Server laden'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Baut Suchfeld, Kategorie-Chips und Trefferliste.
  Widget _buildSearch() {
    final config = ref.watch(rulesIndexRemoteConfigProvider);
    final konfiguriert = config.isConfigured;
    final geladen = config.lastSyncedAt?.toLocal();
    final stand = geladen == null
        ? null
        : '${geladen.day.toString().padLeft(2, '0')}.'
              '${geladen.month.toString().padLeft(2, '0')}.${geladen.year}';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              if (stand != null)
                Expanded(
                  child: Text(
                    'Vom Server geladen am $stand',
                    key: const ValueKey('rules-lookup-stand'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                const Spacer(),
              if (konfiguriert)
                IconButton(
                  key: const ValueKey('rules-lookup-sync-icon-button'),
                  tooltip: 'Index vom Server aktualisieren',
                  onPressed: _syncing || _importing ? null : _syncFromServer,
                  icon: _syncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_download_outlined),
                ),
              if (kIsWeb)
                IconButton(
                  key: const ValueKey('rules-lookup-replace-button'),
                  tooltip: 'Index ersetzen',
                  onPressed: _importing || _syncing ? null : _pickAndImport,
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
