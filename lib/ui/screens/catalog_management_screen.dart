import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_runtime_data.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_crypto.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/catalog_entry_editor_screen.dart';

/// Einstiegsscreen für die Verwaltung synchronisierbarer Custom-Kataloge.
class CatalogManagementScreen extends ConsumerWidget {
  /// Erstellt die Katalogverwaltung innerhalb der Einstellungen.
  const CatalogManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(catalogAdminSnapshotProvider);
    final heroStorageLocationAsync = ref.watch(heroStorageLocationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Katalogverwaltung'),
        actions: [
          IconButton(
            tooltip: 'Katalog neu laden',
            onPressed: () {
              ref.read(catalogActionsProvider).reloadCatalog();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Katalog wird neu geladen.')),
              );
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: snapshotAsync.when(
        data: (snapshot) {
          final heroStoragePath =
              heroStorageLocationAsync.valueOrNull?.effectivePath ??
              'Wird geladen …';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _InfoCard(
                title: 'Custom-Kataloge im Heldenspeicher',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Basis-Kataloge bleiben schreibgeschützt. Eigene Einträge werden im aktiven Heldenspeicher abgelegt und können dadurch über einen synchronisierten Ordner zwischen Geräten mitlaufen.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      heroStoragePath,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Änderungen aus Cloud-Sync werden in v1 nicht automatisch überwacht. Nutze bei Bedarf „Katalog neu laden“.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (snapshot.issues.isNotEmpty) ...[
                _IssueCard(
                  issues: snapshot.issues,
                  title: 'Probleme in Custom-Katalogen',
                ),
                const SizedBox(height: 16),
              ],
              for (final section in editableCatalogSections) ...[
                _CatalogSectionTile(
                  snapshot: snapshot.section(section),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CatalogSectionScreen(section: section),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Katalogdaten konnten nicht geladen werden: $error'),
          ),
        ),
      ),
    );
  }
}

/// Zeigt alle Einträge einer einzelnen Katalogsektion an.
class CatalogSectionScreen extends ConsumerStatefulWidget {
  /// Erstellt die Verwaltungsansicht für eine Sektion.
  const CatalogSectionScreen({super.key, required this.section});

  /// Angezeigte Katalogsektion.
  final CatalogSectionId section;

  @override
  ConsumerState<CatalogSectionScreen> createState() =>
      _CatalogSectionScreenState();
}

class _CatalogSectionScreenState extends ConsumerState<CatalogSectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  _CatalogEntrySourceFilter _sourceFilter = _CatalogEntrySourceFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshotAsync = ref.watch(catalogAdminSnapshotProvider);
    return Scaffold(
      appBar: AppBar(title: Text(widget.section.displayName)),
      body: snapshotAsync.when(
        data: (snapshot) {
          final sectionSnapshot = snapshot.section(widget.section);
          final entries = _filteredEntries(sectionSnapshot);
          final sectionChildren = <Widget>[
              _InfoCard(
                title: widget.section.displayName,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Basis: ${sectionSnapshot.baseEntries.length} · Custom: ${sectionSnapshot.customEntries.length}',
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Navigator.of(context).push<bool>(
                            MaterialPageRoute<bool>(
                              builder: (_) => CatalogEntryEditorScreen(
                                section: widget.section,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: Text('+ ${widget.section.singularLabel}'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Suchen',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Alle'),
                          selected:
                              _sourceFilter == _CatalogEntrySourceFilter.all,
                          onSelected: (_) {
                            setState(
                              () =>
                                  _sourceFilter = _CatalogEntrySourceFilter.all,
                            );
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Basis'),
                          selected:
                              _sourceFilter == _CatalogEntrySourceFilter.base,
                          onSelected: (_) {
                            setState(
                              () => _sourceFilter =
                                  _CatalogEntrySourceFilter.base,
                            );
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Custom'),
                          selected:
                              _sourceFilter == _CatalogEntrySourceFilter.custom,
                          onSelected: (_) {
                            setState(
                              () => _sourceFilter =
                                  _CatalogEntrySourceFilter.custom,
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (sectionSnapshot.issues.isNotEmpty) ...[
                const SizedBox(height: 16),
                _IssueCard(
                  issues: sectionSnapshot.issues,
                  title: 'Fehlerhafte Custom-Dateien',
                ),
              ],
              const SizedBox(height: 16),
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('Keine Einträge für den aktuellen Filter.'),
                  ),
                ),
              for (final entry in entries) ...[
                Card(
                  child: ListTile(
                    title: Text(entry.name),
                    subtitle: Text(
                      '${entry.id} · ${entry.isCustom ? 'Custom' : 'Basis'}',
                    ),
                    trailing: entry.isCustom
                        ? const Icon(Icons.edit_outlined)
                        : const Icon(Icons.lock_outline),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CatalogEntryDetailScreen(
                            section: widget.section,
                            entryId: entry.id,
                            isCustom: entry.isCustom,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
          ];
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sectionChildren.length,
            itemBuilder: (_, index) => sectionChildren[index],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Sektion konnte nicht geladen werden: $error'),
          ),
        ),
      ),
    );
  }

  List<CatalogAdminEntry> _filteredEntries(
    CatalogSectionAdminSnapshot sectionSnapshot,
  ) {
    final allEntries = <CatalogAdminEntry>[
      ...sectionSnapshot.baseEntries,
      ...sectionSnapshot.customEntries,
    ]..sort((a, b) => a.name.compareTo(b.name));
    final searchNeedle = _searchController.text.trim().toLowerCase();
    return allEntries
        .where((entry) {
          if (_sourceFilter == _CatalogEntrySourceFilter.base &&
              entry.isCustom) {
            return false;
          }
          if (_sourceFilter == _CatalogEntrySourceFilter.custom &&
              !entry.isCustom) {
            return false;
          }
          if (searchNeedle.isEmpty) {
            return true;
          }
          final haystack = '${entry.name} ${entry.id}'.trim().toLowerCase();
          return haystack.contains(searchNeedle);
        })
        .toList(growable: false);
  }
}

/// Detailansicht eines einzelnen Katalogeintrags.
class CatalogEntryDetailScreen extends ConsumerWidget {
  /// Erstellt die Detailansicht für einen Eintrag.
  const CatalogEntryDetailScreen({
    super.key,
    required this.section,
    required this.entryId,
    required this.isCustom,
  });

  /// Zugehörige Katalogsektion.
  final CatalogSectionId section;

  /// Stabile ID des Eintrags.
  final String entryId;

  /// Gibt an, ob der Eintrag aus dem Heldenspeicher stammt.
  final bool isCustom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(catalogAdminSnapshotProvider);
    final encoder = const JsonEncoder.withIndent('  ');
    return Scaffold(
      appBar: AppBar(title: Text(section.singularLabel)),
      body: snapshotAsync.when(
        data: (snapshot) {
          final sectionSnapshot = snapshot.section(section);
          final entries = isCustom
              ? sectionSnapshot.customEntries
              : sectionSnapshot.baseEntries;
          CatalogAdminEntry? entry;
          for (final value in entries) {
            if (value.id == entryId) {
              entry = value;
              break;
            }
          }
          if (entry == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Der Eintrag ist nicht mehr vorhanden.'),
              ),
            );
          }
          final resolvedEntry = entry;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _InfoCard(
                title: resolvedEntry.name,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ID: ${resolvedEntry.id}'),
                    const SizedBox(height: 8),
                    Text(
                      'Quelle: ${resolvedEntry.isCustom ? 'Custom' : 'Basis'}',
                    ),
                    if (resolvedEntry.filePath.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SelectableText(resolvedEntry.filePath),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (resolvedEntry.isCustom)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Navigator.of(context).push<bool>(
                          MaterialPageRoute<bool>(
                            builder: (_) => CatalogEntryEditorScreen(
                              section: section,
                              initialEntry: resolvedEntry.data,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Bearbeiten'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Custom-Eintrag löschen?'),
                            content: Text(
                              'Der Eintrag "${resolvedEntry.name}" wird aus dem Heldenspeicher entfernt.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(false),
                                child: const Text('Abbrechen'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(true),
                                child: const Text('Löschen'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true) {
                          return;
                        }
                        await ref
                            .read(catalogActionsProvider)
                            .deleteCustomEntry(
                              section: section,
                              entryId: resolvedEntry.id,
                            );
                        if (!context.mounted) {
                          return;
                        }
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Löschen'),
                    ),
                  ],
                )
              else
                Text(
                  'Basis-Einträge sind schreibgeschützt und können hier nur eingesehen werden.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 16),
              Builder(builder: (context) {
                final visible = resolvedEntry.isCustom ||
                    ref.watch(catalogContentVisibleProvider);
                final displayData = visible
                    ? resolvedEntry.data
                    : _redactEncryptedFields(resolvedEntry.data);
                return _InfoCard(
                  title: 'JSON',
                  child: SelectableText(encoder.convert(displayData)),
                );
              }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Eintrag konnte nicht geladen werden: $error'),
          ),
        ),
      ),
    );
  }
}

/// Ersetzt verschluesselte `enc:`-Werte durch `[gesperrt]`.
Map<String, dynamic> _redactEncryptedFields(Map<String, dynamic> data) {
  final redacted = <String, dynamic>{};
  for (final entry in data.entries) {
    if (isEncryptedValue(entry.value)) {
      redacted[entry.key] = '[gesperrt]';
    } else {
      redacted[entry.key] = entry.value;
    }
  }
  return redacted;
}

enum _CatalogEntrySourceFilter { all, base, custom }

class _CatalogSectionTile extends StatelessWidget {
  const _CatalogSectionTile({required this.snapshot, required this.onTap});

  final CatalogSectionAdminSnapshot snapshot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final issuesLabel = snapshot.issues.isEmpty
        ? ''
        : ' · Fehler: ${snapshot.issues.length}';
    return Card(
      child: ListTile(
        title: Text(snapshot.section.displayName),
        subtitle: Text(
          'Basis: ${snapshot.baseEntries.length} · Custom: ${snapshot.customEntries.length}$issuesLabel',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({required this.issues, required this.title});

  final List<CatalogIssue> issues;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 12),
            for (final issue in issues.take(8)) ...[
              Text(
                issue.message,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
              if (issue.filePath.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: SelectableText(
                    issue.filePath,
                    style: TextStyle(color: colorScheme.onErrorContainer),
                  ),
                ),
              const SizedBox(height: 8),
            ],
            if (issues.length > 8)
              Text(
                '… und ${issues.length - 8} weitere Hinweise.',
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
          ],
        ),
      ),
    );
  }
}
