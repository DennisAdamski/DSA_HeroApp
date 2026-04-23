import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import 'package:dsa_heldenverwaltung/catalog/house_rule_pack.dart';
import 'package:dsa_heldenverwaltung/catalog/house_rule_pack_admin.dart';
import 'package:dsa_heldenverwaltung/data/house_rule_pack_file_gateway.dart';
import 'package:dsa_heldenverwaltung/data/house_rule_pack_repository.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/house_rule_pack_admin_providers.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/house_rule_pack_editor_screen.dart';

/// Verwaltungsoberflaeche fuer eingebaute und importierte Hausregel-Pakete.
class HouseRulePackManagementScreen extends ConsumerWidget {
  /// Erstellt die Verwaltungsansicht fuer Hausregel-Pakete.
  const HouseRulePackManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(houseRulePackAdminSnapshotProvider);
    final heroStorageLocationAsync = ref.watch(heroStorageLocationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hausregelverwaltung'),
        actions: [
          IconButton(
            tooltip: 'Hausregeln neu laden',
            onPressed: () {
              ref.read(catalogReloadRevisionProvider.notifier).state++;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Hausregel-Pakete werden neu geladen.'),
                ),
              );
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: snapshotAsync.when(
        data: (snapshot) {
          final heroStoragePath =
              heroStorageLocationAsync.valueOrNull?.effectivePath ?? '';
          final packStoragePath = heroStoragePath.isEmpty
              ? ''
              : path.join(
                  heroStoragePath,
                  HouseRulePackRepository.houseRulePackRootDirectory,
                  snapshot.catalogVersion,
                );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _InfoCard(
                title: 'Importierte Hausregel-Pakete',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Neue Hausregeln werden als Pakete im aktiven '
                      'Heldenspeicher abgelegt und nach „Hausregeln neu laden“ '
                      'oder nach dem Speichern sofort wirksam.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (packStoragePath.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SelectableText(
                        packStoragePath,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (snapshot.issues.isNotEmpty) ...[
                _HouseRuleIssueCard(
                  title: 'Probleme in Hausregel-Paketen',
                  issues: snapshot.issues,
                ),
                const SizedBox(height: 16),
              ],
              _PackSectionCard(
                title: 'Importierte Pakete',
                actions: [
                  OutlinedButton.icon(
                    onPressed: () => _importPack(context, ref, snapshot),
                    icon: const Icon(Icons.file_download_outlined),
                    label: const Text('Importieren'),
                  ),
                  FilledButton.icon(
                    onPressed: () => _createNewPack(context),
                    icon: const Icon(Icons.add),
                    label: const Text('+ Hausregelpaket'),
                  ),
                ],
                child: snapshot.importedPacks.isEmpty
                    ? const Text('Noch keine importierten Hausregel-Pakete.')
                    : Column(
                        children: snapshot.importedPacks
                            .map(
                              (entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _HouseRulePackTile(
                                  entry: entry,
                                  onTap: () => _editImportedPack(
                                    context,
                                    entry.manifest,
                                  ),
                                  trailing:
                                      PopupMenuButton<_ImportedPackAction>(
                                        onSelected: (action) async {
                                          switch (action) {
                                            case _ImportedPackAction.edit:
                                              _editImportedPack(
                                                context,
                                                entry.manifest,
                                              );
                                              return;
                                            case _ImportedPackAction.export:
                                              await _exportImportedPack(
                                                context,
                                                ref,
                                                entry,
                                              );
                                              return;
                                            case _ImportedPackAction.delete:
                                              await _deleteImportedPack(
                                                context,
                                                ref,
                                                entry,
                                              );
                                              return;
                                          }
                                        },
                                        itemBuilder: (context) => const [
                                          PopupMenuItem(
                                            value: _ImportedPackAction.edit,
                                            child: Text('Bearbeiten'),
                                          ),
                                          PopupMenuItem(
                                            value: _ImportedPackAction.export,
                                            child: Text('Exportieren'),
                                          ),
                                          PopupMenuItem(
                                            value: _ImportedPackAction.delete,
                                            child: Text('Löschen'),
                                          ),
                                        ],
                                      ),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
              ),
              const SizedBox(height: 16),
              _PackSectionCard(
                title: 'Eingebaute Pakete',
                child: snapshot.builtInPacks.isEmpty
                    ? const Text('Keine eingebauten Hausregel-Pakete gefunden.')
                    : Column(
                        children: snapshot.builtInPacks
                            .map(
                              (entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _HouseRulePackTile(
                                  entry: entry,
                                  trailing: OutlinedButton.icon(
                                    onPressed: () async {
                                      final actions = ref.read(
                                        houseRulePackAdminActionsProvider,
                                      );
                                      final suggestedId = await actions
                                          .suggestCopyPackId(entry.id);
                                      if (!context.mounted) {
                                        return;
                                      }
                                      _openEditor(
                                        context,
                                        initialManifestJson: _cloneManifestJson(
                                          entry.manifest,
                                          newId: suggestedId,
                                        ),
                                        screenTitle:
                                            'Hausregelpaket aus Vorlage klonen',
                                      );
                                    },
                                    icon: const Icon(Icons.copy_outlined),
                                    label: const Text('Als Vorlage klonen'),
                                  ),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Hausregel-Pakete konnten nicht geladen werden: $error',
            ),
          ),
        ),
      ),
    );
  }

  void _createNewPack(BuildContext context) {
    _openEditor(
      context,
      initialManifestJson: const <String, dynamic>{
        'id': '',
        'title': '',
        'description': '',
        'patches': <Map<String, dynamic>>[],
      },
      screenTitle: 'Hausregelpaket anlegen',
    );
  }

  void _editImportedPack(BuildContext context, HouseRulePackManifest manifest) {
    _openEditor(
      context,
      initialManifestJson: manifest.toJson(),
      previousPackId: manifest.id,
      screenTitle: 'Hausregelpaket bearbeiten',
    );
  }

  void _openEditor(
    BuildContext context, {
    required Map<String, dynamic> initialManifestJson,
    required String screenTitle,
    String previousPackId = '',
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HouseRulePackEditorScreen(
          initialManifestJson: initialManifestJson,
          previousPackId: previousPackId,
          screenTitle: screenTitle,
        ),
      ),
    );
  }

  Future<void> _importPack(
    BuildContext context,
    WidgetRef ref,
    HouseRulePackAdminSnapshot snapshot,
  ) async {
    final gateway = ref.read(houseRulePackFileGatewayProvider);
    final rawJson = await gateway.pickImportJson();
    if (!context.mounted) {
      return;
    }
    if (rawJson == null || rawJson.trim().isEmpty) {
      return;
    }

    try {
      final actions = ref.read(houseRulePackAdminActionsProvider);
      final manifest = actions.parseManifestJson(rawJson);
      final existing = snapshot.find(manifest.id);
      var previousPackId = '';
      var manifestJson = manifest.toJson();

      if (existing != null) {
        final resolution = await showDialog<_ImportResolution>(
          context: context,
          builder: (dialogContext) => _ImportConflictDialog(entry: existing),
        );
        if (!context.mounted) {
          return;
        }
        if (resolution == null || resolution == _ImportResolution.cancel) {
          return;
        }
        if (resolution == _ImportResolution.overwrite) {
          previousPackId = existing.id;
        } else {
          final newId = await actions.suggestCopyPackId(manifest.id);
          if (!context.mounted) {
            return;
          }
          manifestJson = _cloneManifestJson(manifest, newId: newId);
        }
      }

      await actions.savePack(
        manifestJson: manifestJson,
        previousPackId: previousPackId,
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hausregelpaket importiert.')),
      );
    } on FormatException catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on Exception catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import fehlgeschlagen: $error')));
    }
  }

  Future<void> _exportImportedPack(
    BuildContext context,
    WidgetRef ref,
    HouseRulePackAdminEntry entry,
  ) async {
    try {
      final actions = ref.read(houseRulePackAdminActionsProvider);
      final payload = await actions.exportPackJson(entry.id);
      final gateway = ref.read(houseRulePackFileGatewayProvider);
      final outcome = await gateway.exportJson(
        fileNameBase: entry.id,
        jsonPayload: payload,
      );
      if (!context.mounted) {
        return;
      }
      if (outcome.result == HouseRulePackExportResult.canceled) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            outcome.location == null
                ? 'Hausregelpaket exportiert.'
                : 'Hausregelpaket exportiert: ${outcome.location}',
          ),
        ),
      );
    } on Exception catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export fehlgeschlagen: $error')));
    }
  }

  Future<void> _deleteImportedPack(
    BuildContext context,
    WidgetRef ref,
    HouseRulePackAdminEntry entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hausregelpaket löschen?'),
        content: Text(
          'Das importierte Paket "${entry.title}" wird aus dem '
          'Heldenspeicher entfernt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    try {
      await ref.read(houseRulePackAdminActionsProvider).deletePack(entry.id);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Hausregelpaket gelöscht.')));
    } on Exception catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Löschen fehlgeschlagen: $error')));
    }
  }
}

enum _ImportedPackAction { edit, export, delete }

enum _ImportResolution { overwrite, copy, cancel }

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

class _PackSectionCard extends StatelessWidget {
  const _PackSectionCard({
    required this.title,
    required this.child,
    this.actions = const <Widget>[],
  });

  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                ...actions,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _HouseRulePackTile extends StatelessWidget {
  const _HouseRulePackTile({
    required this.entry,
    required this.trailing,
    this.onTap,
  });

  final HouseRulePackAdminEntry entry;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      entry.id,
      entry.isBuiltIn ? 'Eingebaut' : 'Importiert',
      entry.isActive ? 'Aktiv' : 'Deaktiviert',
      if (entry.parentPackId.trim().isNotEmpty) 'Parent: ${entry.parentPackId}',
      if (entry.issues.isNotEmpty) 'Warnungen: ${entry.issues.length}',
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        title: Text(entry.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(details.join(' · ')),
            if (entry.description.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(entry.description),
            ],
          ],
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}

class _HouseRuleIssueCard extends StatelessWidget {
  const _HouseRuleIssueCard({required this.title, required this.issues});

  final String title;
  final List<HouseRulePackIssue> issues;

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
            for (final issue in issues.take(12)) ...[
              Text(
                _formatIssue(issue),
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
              if (issue.filePath.isNotEmpty) ...[
                const SizedBox(height: 4),
                SelectableText(
                  issue.filePath,
                  style: TextStyle(color: colorScheme.onErrorContainer),
                ),
              ],
              const SizedBox(height: 8),
            ],
            if (issues.length > 12)
              Text(
                '… und ${issues.length - 12} weitere Hinweise.',
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
          ],
        ),
      ),
    );
  }

  String _formatIssue(HouseRulePackIssue issue) {
    final parts = <String>[
      if (issue.packTitle.isNotEmpty) issue.packTitle,
      issue.message,
      if (issue.entryId.isNotEmpty) 'Eintrag: ${issue.entryId}',
    ];
    return parts.join(' · ');
  }
}

class _ImportConflictDialog extends StatelessWidget {
  const _ImportConflictDialog({required this.entry});

  final HouseRulePackAdminEntry entry;

  @override
  Widget build(BuildContext context) {
    final canOverwrite = !entry.isBuiltIn;
    return AlertDialog(
      title: const Text('Paket-ID bereits vorhanden'),
      content: Text(
        canOverwrite
            ? 'Die Paket-ID "${entry.id}" existiert bereits als importiertes '
                  'Paket. Soll das Paket überschrieben oder als Kopie '
                  'importiert werden?'
            : 'Die Paket-ID "${entry.id}" ist bereits durch ein eingebautes '
                  'Paket belegt. Das neue Paket kann nur als Kopie importiert '
                  'werden.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_ImportResolution.cancel),
          child: const Text('Abbrechen'),
        ),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(_ImportResolution.copy),
          child: const Text('Als Kopie importieren'),
        ),
        if (canOverwrite)
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(_ImportResolution.overwrite),
            child: const Text('Überschreiben'),
          ),
      ],
    );
  }
}

Map<String, dynamic> _cloneManifestJson(
  HouseRulePackManifest manifest, {
  required String newId,
}) {
  final json =
      jsonDecode(jsonEncode(manifest.toJson())) as Map<String, dynamic>;
  json['id'] = newId;
  final title = (json['title'] as String? ?? '').trim();
  if (title.isNotEmpty) {
    json['title'] = '$title (Kopie)';
  }
  return json;
}
