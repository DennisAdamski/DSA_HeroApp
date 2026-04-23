import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/app_storage_paths.dart';
import 'package:dsa_heldenverwaltung/data/storage_directory_tools.dart';
import 'package:dsa_heldenverwaltung/catalog/house_rule_pack.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_config.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/house_rules_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/catalog_management_screen.dart';
import 'package:dsa_heldenverwaltung/ui/screens/catalog_unlock_dialog.dart';

/// Einstellungs-Screen fuer globale, heldenunabhaengige Optionen.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debugModus = ref.watch(debugModusProvider);
    final dunkelModus = ref.watch(dunkelModusProvider);
    final heroStorageLocationAsync = ref.watch(heroStorageLocationProvider);
    final settingsStoragePathAsync = ref.watch(settingsStoragePathProvider);
    final actions = ref.read(settingsActionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Debug-Modus'),
            subtitle: const Text('Variablennamen statt Anzeigebezeichnungen'),
            value: debugModus,
            onChanged: (_) => actions.toggleDebugModus(),
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Dunkelmodus'),
            subtitle: const Text('Dunkles Farbschema'),
            value: dunkelModus,
            onChanged: (_) => actions.toggleDunkelModus(),
          ),
          const Divider(height: 1),
          _UiVarianteSection(),
          const Divider(height: 1),
          _HeroStorageSection(
            heroStorageLocationAsync: heroStorageLocationAsync,
            settingsStoragePathAsync: settingsStoragePathAsync,
          ),
          const Divider(height: 1),
          const _CatalogManagementSection(),
          const Divider(height: 1),
          const _CatalogContentPasswordSection(),
          const Divider(height: 1),
          const _HouseRulesSection(),
          const Divider(height: 1),
          const _AvatarApiSection(),
        ],
      ),
    );
  }
}

/// Abschnitt zum Ein- und Ausschalten registrierter Hausregel-Gruppen.
class _HouseRulesSection extends ConsumerWidget {
  const _HouseRulesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final disabled = ref.watch(disabledHouseRulePackIdsProvider);
    final actions = ref.read(settingsActionsProvider);
    final packCatalogAsync = ref.watch(houseRulePackCatalogProvider);
    final issuesAsync = ref.watch(houseRuleIssueSnapshotProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hausregeln', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Optionale Regelpakete liegen ueber dem offiziellen Katalog. '
            'Deaktivierte Pakete blenden ihre Inhalte und Ueberschreibungen aus, '
            'ohne bestehende Heldendaten zu loeschen.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          packCatalogAsync.when(
            data: (catalog) {
              final roots = catalog.roots;
              if (roots.isEmpty) {
                return Text(
                  'Keine Hausregel-Pakete gefunden.',
                  style: theme.textTheme.bodySmall,
                );
              }
              return Column(
                children: [
                  ...roots.map(
                    (root) => _HouseRuleGroup(
                      root: root,
                      catalog: catalog,
                      disabled: disabled,
                      onToggle: (packId, enabled) =>
                          actions.setHouseRuleEnabled(packId, enabled),
                    ),
                  ),
                  const SizedBox(height: 8),
                  issuesAsync.maybeWhen(
                    data: (issues) {
                      if (issues.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return _HouseRuleIssuesCard(issues: issues);
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) => Text(
              'Hausregel-Pakete konnten nicht geladen werden: $error',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Darstellung einer Hausregel-Gruppe (Root + Kinder).
class _HouseRuleGroup extends StatelessWidget {
  const _HouseRuleGroup({
    required this.root,
    required this.catalog,
    required this.disabled,
    required this.onToggle,
  });

  final HouseRulePackManifest root;
  final HouseRulePackCatalog catalog;
  final Set<String> disabled;
  final void Function(String packId, bool enabled) onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rootEnabled = !disabled.contains(root.id);
    final children = catalog.childrenOf(root.id);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            title: Text(root.title),
            subtitle: Text(
              root.isBuiltIn
                  ? root.description
                  : '${root.description}\nImportiertes Paket',
            ),
            value: rootEnabled,
            onChanged: (value) => onToggle(root.id, value),
          ),
          if (children.isNotEmpty) ...[
            const Divider(height: 1),
            ...children.map(
              (child) => _HouseRuleChildTile(
                child: child,
                childDisabled: disabled.contains(child.id),
                parentEnabled: rootEnabled,
                onToggle: onToggle,
                captionStyle: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Eine Unter-Hausregel. Bei deaktiviertem Parent nicht bedienbar,
/// behaelt aber den gespeicherten Zustand.
class _HouseRuleChildTile extends StatelessWidget {
  const _HouseRuleChildTile({
    required this.child,
    required this.childDisabled,
    required this.parentEnabled,
    required this.onToggle,
    required this.captionStyle,
  });

  final HouseRulePackManifest child;
  final bool childDisabled;
  final bool parentEnabled;
  final void Function(String packId, bool enabled) onToggle;
  final TextStyle? captionStyle;

  @override
  Widget build(BuildContext context) {
    final ownEnabled = !childDisabled;
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: SwitchListTile(
        title: Text(child.title),
        subtitle: Text(
          parentEnabled
              ? child.description
              : '${child.description}\n(Parent-Regel deaktiviert)',
          style: captionStyle,
        ),
        isThreeLine: !parentEnabled,
        value: ownEnabled,
        onChanged: parentEnabled ? (value) => onToggle(child.id, value) : null,
      ),
    );
  }
}

/// Sichtbare Problemliste fuer Paketkonflikte oder Ladefehler.
class _HouseRuleIssuesCard extends StatelessWidget {
  const _HouseRuleIssuesCard({required this.issues});

  final List<HouseRulePackIssue> issues;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Probleme in Hausregel-Paketen',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 8),
            ...issues.map(
              (issue) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  [
                    if (issue.packTitle.isNotEmpty) issue.packTitle,
                    issue.message,
                    if (issue.entryId.isNotEmpty) 'Eintrag: ${issue.entryId}',
                  ].join(' • '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogManagementSection extends ConsumerWidget {
  const _CatalogManagementSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heroStorageLocation = ref.watch(heroStorageLocationProvider);
    final effectivePath =
        heroStorageLocation.valueOrNull?.effectivePath ?? 'Wird geladen …';
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Katalogverwaltung', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Alle Basis-Katalogdaten können hier eingesehen werden. Eigene Einträge werden als Custom-Kataloge im Heldenspeicher abgelegt und lassen sich dadurch über einen Cloud-Ordner synchronisieren.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          _PathInfoTile(
            label: 'Aktiver Speicher für Custom-Kataloge',
            value: effectivePath,
          ),
          const SizedBox(height: 12),
          Text(
            'Hinweis: Änderungen aus einem synchronisierten Ordner werden erst nach „Katalog neu laden“ oder nach einem App-Neustart sichtbar.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CatalogManagementScreen(),
                ),
              );
            },
            icon: const Icon(Icons.library_books_outlined),
            label: const Text('Katalogverwaltung öffnen'),
          ),
        ],
      ),
    );
  }
}

/// Abschnitt fuer die visuelle Darstellungsvariante.
class _UiVarianteSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variante = ref.watch(uiVarianteProvider);
    final actions = ref.read(settingsActionsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Darstellung', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SegmentedButton<UiVariante>(
            segments: const <ButtonSegment<UiVariante>>[
              ButtonSegment(
                value: UiVariante.klassisch,
                label: Text('Klassisch'),
                icon: Icon(Icons.palette_outlined),
              ),
              ButtonSegment(
                value: UiVariante.codex,
                label: Text('Codex'),
                icon: Icon(Icons.auto_stories),
              ),
            ],
            selected: <UiVariante>{variante},
            onSelectionChanged: (selected) {
              actions.setUiVariante(selected.first);
            },
          ),
          const SizedBox(height: 8),
          Text(
            variante == UiVariante.codex
                ? 'Pergament-und-Messing-Aesthetik mit Texturen und dekorativen Elementen.'
                : 'Schlichtes Material-Design ohne dekorative Elemente.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Abschnitt fuer den konfigurierbaren Heldenspeicher.
class _HeroStorageSection extends ConsumerWidget {
  const _HeroStorageSection({
    required this.heroStorageLocationAsync,
    required this.settingsStoragePathAsync,
  });

  final AsyncValue<HeroStorageLocation> heroStorageLocationAsync;
  final AsyncValue<String> settingsStoragePathAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final actions = ref.read(settingsActionsProvider);

    return heroStorageLocationAsync.when(
      data: (location) {
        final settingsStoragePath = settingsStoragePathAsync.valueOrNull;
        final canOpenDirectory =
            location.isAccessible && canOpenStorageDirectory();

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Heldenspeicher', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Heldendaten werden getrennt von den App-Einstellungen '
                'gespeichert. Ein benutzerdefinierter Pfad eignet sich z. B. '
                'für einen Cloud-Ordner.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              _PathInfoTile(
                label: 'Aktiver Heldenspeicher',
                value: location.effectivePath,
              ),
              const SizedBox(height: 12),
              _PathInfoTile(
                label: 'Lokaler Einstellungsordner',
                value: settingsStoragePath ?? 'Wird geladen ...',
              ),
              if (location.usesCustomPath) ...[
                const SizedBox(height: 12),
                Text(
                  'Benutzerdefinierter Pfad aktiv',
                  style: theme.textTheme.labelLarge,
                ),
              ],
              if (location.validationError != null) ...[
                const SizedBox(height: 12),
                Text(
                  location.validationError!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (location.customPathSupported) ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: () =>
                          _selectHeroStoragePath(context: context, ref: ref),
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Ordner wählen'),
                    ),
                    OutlinedButton.icon(
                      onPressed: location.usesCustomPath
                          ? () async {
                              await actions.clearHeroStoragePath();
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Heldenspeicher auf Standardpfad zurückgesetzt.',
                                  ),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Standard verwenden'),
                    ),
                    OutlinedButton.icon(
                      onPressed: canOpenDirectory
                          ? () => _openStorageFolder(
                              context: context,
                              path: location.effectivePath,
                            )
                          : null,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Ordner öffnen'),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  'Ein benutzerdefinierter Heldenspeicher ist auf dieser '
                  'Plattform derzeit nicht verfügbar.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Hinweis: App-Einstellungen werden nie in den Heldenspeicher '
                'synchronisiert.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Warnung: Dieselben Heldendaten sollten nicht gleichzeitig '
                'auf mehreren Geraeten bearbeitet werden, wenn ein '
                'Cloud-Ordner verwendet wird.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Speicherorte konnten nicht geladen werden: $error'),
      ),
    );
  }

  Future<void> _selectHeroStoragePath({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    final selectedPath = await ref
        .read(storageDirectoryPickerProvider)
        .pickDirectory(dialogTitle: 'Heldenspeicher wählen');
    if (!context.mounted) {
      return;
    }
    if (selectedPath == null || selectedPath.trim().isEmpty) {
      return;
    }

    await ref.read(settingsActionsProvider).setHeroStoragePath(selectedPath);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Heldenspeicher aktualisiert.')),
    );
  }

  Future<void> _openStorageFolder({
    required BuildContext context,
    required String path,
  }) async {
    try {
      await openStorageDirectory(path);
    } on Exception catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ordner konnte nicht geöffnet werden: $error')),
      );
    }
  }
}

/// Abschnitt fuer den Katalog-Inhaltsschutz.
class _CatalogContentPasswordSection extends ConsumerWidget {
  const _CatalogContentPasswordSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final visible = ref.watch(catalogContentVisibleProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Katalog-Inhaltsschutz', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Bestimmte Kataloginhalte (lange Erklärungen, Wirkung, '
            'Varianten) sind verschlüsselt und können mit dem '
            'passenden Passwort freigeschaltet werden. '
            'Eigens erstellte Einträge sind davon nicht betroffen.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (visible) ...[
            Row(
              children: [
                Icon(Icons.lock_open, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Katalog-Inhalte freigeschaltet',
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _removePassword(context, ref),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Passwort entfernen'),
            ),
          ] else
            FilledButton.icon(
              onPressed: () =>
                  showCatalogUnlockDialog(context: context, ref: ref),
              icon: const Icon(Icons.lock_open),
              label: const Text('Inhalte freischalten'),
            ),
        ],
      ),
    );
  }

  Future<void> _removePassword(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Passwort entfernen?'),
        content: const Text(
          'Geschützte Kataloginhalte werden danach wieder '
          'als gesperrt angezeigt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(settingsActionsProvider).setCatalogContentPassword(null);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Katalog-Passwort entfernt.')));
  }
}

/// Abschnitt fuer die KI-Bildgenerierungs-API-Konfiguration.
class _AvatarApiSection extends ConsumerStatefulWidget {
  const _AvatarApiSection();

  @override
  ConsumerState<_AvatarApiSection> createState() => _AvatarApiSectionState();
}

class _AvatarApiSectionState extends ConsumerState<_AvatarApiSection> {
  final _apiKeyController = TextEditingController();
  AvatarApiProvider _selectedProvider = AvatarApiProvider.openaiDalle3;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(appSettingsProvider).valueOrNull;
    if (settings != null) {
      _apiKeyController.text = settings.avatarApiConfig.apiKey;
      _selectedProvider = settings.avatarApiConfig.provider;
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bildgenerierung', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Über eine KI-API können Heldenporträts generiert werden. '
            'Die Kosten werden über deinen eigenen API-Schlüssel abgerechnet.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<AvatarApiProvider>(
            initialValue: _selectedProvider,
            decoration: const InputDecoration(
              labelText: 'Anbieter',
              border: OutlineInputBorder(),
            ),
            items: AvatarApiProvider.values
                .map(
                  (p) => DropdownMenuItem(value: p, child: Text(p.displayName)),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedProvider = value);
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKeyController,
            obscureText: _obscureKey,
            decoration: InputDecoration(
              labelText: 'API-Schluessel',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureKey ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saveConfig,
            icon: const Icon(Icons.save),
            label: const Text('Speichern'),
          ),
          const SizedBox(height: 12),
          Text(
            'Der API-Schlüssel wird nur lokal auf diesem Gerät gespeichert '
            'und nie an Dritte übertragen.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _saveConfig() async {
    final config = AvatarApiConfig(
      provider: _selectedProvider,
      apiKey: _apiKeyController.text.trim(),
    );
    await ref.read(settingsActionsProvider).saveAvatarApiConfig(config);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bildgenerierung-Einstellungen gespeichert.'),
      ),
    );
  }
}

class _PathInfoTile extends StatelessWidget {
  const _PathInfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            SelectableText(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
