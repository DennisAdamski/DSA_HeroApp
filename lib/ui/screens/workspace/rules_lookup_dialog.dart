import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_remote_client.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_search.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_sync_service.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_types.dart';
import 'package:dsa_heldenverwaltung/state/rules_index_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/catalog_unlock_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/kurzregeln_panel.dart';

/// Prüft, ob der Regel-Nachschlag auf dieser Plattform angeboten werden kann.
///
/// Immer wahr: die mitgelieferten Kurzregeln laufen überall offline. Ob
/// zusätzlich die Wissensbasis-Volltextsuche möglich ist, entscheidet
/// [rulesIndexSearchSupported] (Desktop und Web ja, Mobil nein).
bool isRulesLookupSupported() => true;

/// Öffnet den Regel-Nachschlag-Dialog.
Future<void> showRulesLookupDialog({required BuildContext context}) {
  return showDialog<void>(
    context: context,
    builder: (_) => const RegelnNachschlagDialog(),
  );
}

/// Regel-Nachschlag mit zwei Reitern.
///
/// „Kurzregeln“ ist der Standardreiter und zeigt das mitgelieferte, eigene
/// Kompendium; es funktioniert ohne Wissensbasis. „Wissensbasis“ ist die
/// Volltextsuche ([RulesLookupDialog]) und entfällt auf Plattformen ohne
/// Index-Unterstützung (Mobil), dort bleiben nur die Kurzregeln.
class RegelnNachschlagDialog extends StatelessWidget {
  /// Erzeugt den Dialog.
  const RegelnNachschlagDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final mitWissensbasis = rulesIndexSearchSupported();
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 640),
        child: mitWissensbasis ? const _Reiter() : const KurzregelnPanel(),
      ),
    );
  }
}

/// Reiterleiste und Reiterinhalte des Regel-Nachschlags.
class _Reiter extends StatelessWidget {
  const _Reiter();

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(
                key: ValueKey('rules-lookup-tab-kurzregeln'),
                text: 'Kurzregeln',
              ),
              Tab(
                key: ValueKey('rules-lookup-tab-wissensbasis'),
                text: 'Wissensbasis',
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                KurzregelnPanel(),
                RulesLookupDialog(eingebettet: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
  /// lokale Index-Datenbank und den Server. [eingebettet] lässt den
  /// Dialograhmen weg, wenn der Inhalt in einem Reiter liegt.
  const RulesLookupDialog({
    super.key,
    this.oeffneIndex,
    this.syncService,
    this.eingebettet = false,
  });

  /// Ob der Inhalt ohne eigenen Dialograhmen in einem Reiter steht.
  final bool eingebettet;

  /// Öffnet die Index-Datenbank; ohne Angabe [openRulesIndexSearch].
  final Future<RulesIndexSearch?> Function()? oeffneIndex;

  /// Lädt vom Server; ohne Angabe ein [RulesIndexSyncService].
  final RulesIndexSyncService? syncService;

  @override
  ConsumerState<RulesLookupDialog> createState() => _RulesLookupDialogState();
}

class _RulesLookupDialogState extends ConsumerState<RulesLookupDialog>
    with AutomaticKeepAliveClientMixin {
  RulesIndexSearch? _search;
  bool _loading = true;
  bool _importing = false;
  bool _syncing = false;
  String? _importError;
  List<RulesSearchHit> _hits = const <RulesSearchHit>[];
  String _query = '';
  bool _searched = false;

  /// Ob der Nutzer das Aktualisieren selbst angestoßen hat und eine
  /// Rückmeldung erwartet, auch wenn nichts Neues da ist.
  bool _manuellAktualisiert = false;

  /// Standardmäßig durchsuchte Kategorien (wie beim MCP-Server).
  final Set<RulesSourceCategory> _categories = <RulesSourceCategory>{
    RulesSourceCategory.regelbuecher,
    RulesSourceCategory.hausregeln,
  };

  // Hält Suchtext und geöffneten Index beim Reiterwechsel am Spieltisch.
  @override
  bool get wantKeepAlive => widget.eingebettet;

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

  /// Öffnet die Datenbank neu, nachdem im Hintergrund eine neue Fassung
  /// installiert wurde.
  Future<void> _neuLaden() async {
    _search?.dispose();
    setState(() {
      _search = null;
      _loading = true;
      _hits = const <RulesSearchHit>[];
      _searched = false;
      _query = '';
    });
    await _load();
  }

  /// Reagiert auf das Hintergrundladen: neue Fassung öffnen, bei manuellem
  /// Aktualisieren auch „schon aktuell“ melden.
  void _beiSyncAenderung(
    RulesIndexSyncState? vorher,
    RulesIndexSyncState jetzt,
  ) {
    if (vorher != null && jetzt.revision != vorher.revision) {
      _manuellAktualisiert = false;
      _neuLaden();
      return;
    }
    if (_manuellAktualisiert &&
        vorher != null &&
        vorher.running &&
        jetzt.phase == RulesIndexSyncPhase.done) {
      _manuellAktualisiert = false;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Die Wissensbasis ist aktuell.')),
      );
    }
    if (jetzt.phase == RulesIndexSyncPhase.failed) _manuellAktualisiert = false;
  }

  /// Startet das Laden über die Cloud; [pruefen] fragt nur nach einer neueren
  /// Fassung, sonst wird immer geladen.
  void _cloudStarten({required bool pruefen}) {
    _manuellAktualisiert = pruefen;
    ref.read(rulesIndexAutoSyncProvider.notifier).start(force: !pruefen);
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
    super.build(context);
    ref.listen<RulesIndexSyncState>(
      rulesIndexAutoSyncProvider,
      _beiSyncAenderung,
    );
    if (widget.eingebettet) {
      return _buildContent();
    }
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
    final cloud = ref.watch(rulesIndexCloudAvailableProvider);
    // Der Cloud-Weg ersetzt den NAS-Weg, wo ein Build ihn hat.
    final konfiguriert =
        !cloud && ref.watch(rulesIndexRemoteConfigProvider).isConfigured;
    final sync = ref.watch(rulesIndexAutoSyncProvider);
    final angemeldet = ref.watch(rulesIndexSignedInProvider);
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
            if (cloud)
              _buildCloudStatus(sync, angemeldet: angemeldet)
            else
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
                if (cloud && angemeldet && !sync.running)
                  FilledButton.icon(
                    key: const ValueKey('rules-lookup-cloud-button'),
                    onPressed: _importing
                        ? null
                        : () => _cloudStarten(pruefen: false),
                    icon: const Icon(Icons.cloud_download_outlined),
                    label: Text(
                      sync.phase == RulesIndexSyncPhase.failed
                          ? 'Erneut versuchen'
                          : 'Wissensbasis laden',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Zustand des Cloud-Ladens im Leerzustand: Fortschritt, Fehler oder die
  /// Aufforderung, sich anzumelden beziehungsweise zu laden.
  Widget _buildCloudStatus(
    RulesIndexSyncState sync, {
    required bool angemeldet,
  }) {
    final theme = Theme.of(context);
    if (sync.running) {
      final fraction = sync.fraction;
      final text = switch (sync.phase) {
        RulesIndexSyncPhase.preparing => 'Wird vorbereitet …',
        RulesIndexSyncPhase.installing => 'Wird eingerichtet …',
        _ =>
          sync.total > 0
              ? 'Wissensbasis wird geladen … ${_megabyte(sync.received)} von '
                    '${_megabyte(sync.total)} MB'
              : 'Wissensbasis wird geladen …',
      };
      return Column(
        key: const ValueKey('rules-lookup-cloud-laeuft'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: fraction),
          const SizedBox(height: 8),
          Text(
            'Das läuft im Hintergrund; du kannst den Dialog schließen und '
            'weiterspielen.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      );
    }
    if (!angemeldet) {
      return const Text(
        'Zum Laden der Wissensbasis bitte anmelden. Danach startet der '
        'Download von selbst.',
        key: ValueKey('rules-lookup-cloud-anmelden'),
      );
    }
    if (sync.phase == RulesIndexSyncPhase.failed) {
      return Text(
        sync.message ?? 'Die Wissensbasis konnte nicht geladen werden.',
        key: const ValueKey('rules-lookup-cloud-fehler'),
        style: TextStyle(color: theme.colorScheme.error),
      );
    }
    return const Text(
      'Die Wissensbasis (etwa 120 MB) wird einmal geladen und bleibt auf '
      'diesem Gerät gespeichert.',
      key: ValueKey('rules-lookup-cloud-bereit'),
    );
  }

  String _megabyte(int bytes) => (bytes / 1048576).toStringAsFixed(0);

  /// Baut Suchfeld, Kategorie-Chips und Trefferliste.
  Widget _buildSearch() {
    final config = ref.watch(rulesIndexRemoteConfigProvider);
    final cloud = ref.watch(rulesIndexCloudAvailableProvider);
    final cloudLaeuft = ref.watch(rulesIndexAutoSyncProvider).running;
    final konfiguriert = cloud || config.isConfigured;
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
                  onPressed: _syncing || _importing || cloudLaeuft
                      ? null
                      : (cloud
                            ? () => _cloudStarten(pruefen: true)
                            : _syncFromServer),
                  icon: _syncing || cloudLaeuft
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
