import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/app_storage_paths.dart';
import 'package:dsa_heldenverwaltung/data/storage_directory_tools.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_config.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/catalog_management_screen.dart';

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
          const _AvatarApiSection(),
        ],
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
