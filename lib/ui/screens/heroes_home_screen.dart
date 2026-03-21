import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/hero_transfer_file_gateway.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/platform_adaptive.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_workspace_screen.dart';
import 'package:dsa_heldenverwaltung/ui/screens/settings_screen.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_import_export_actions.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/hero_document.dart';

/// Startseite mit Heldenarchiv und Einstieg in den Workspace.
class HeroesHomeScreen extends ConsumerWidget {
  /// Erstellt die Startseite der Heldenverwaltung.
  const HeroesHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heroesAsync = ref.watch(heroListProvider);
    final selectedHeroId = ref.watch(selectedHeroIdProvider);
    const importExportActions = WorkspaceImportExportActions();
    final apple = isApplePlatform(context);

    Future<void> createHero() async {
      final draft = await _showCreateHeroDialog(context);
      if (draft == null || !context.mounted) {
        return;
      }
      final navigator = Navigator.of(context);
      final id = await ref
          .read(heroActionsProvider)
          .createHero(
            name: draft.name,
            rawStartAttributes: draft.rawStartAttributes,
          );
      if (!context.mounted) {
        return;
      }
      navigator.push(
        MaterialPageRoute(builder: (_) => HeroWorkspaceScreen(heroId: id)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('DSA Helden'),
        actions: [
          if (apple)
            IconButton(
              tooltip: 'Neuer Held',
              onPressed: createHero,
              icon: const Icon(Icons.add),
            ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Held importieren',
            onPressed: () => _importHero(
              context: context,
              ref: ref,
              importExportActions: importExportActions,
            ),
            icon: const Icon(Icons.download),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Einstellungen',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            icon: const Icon(Icons.settings),
          ),
          const SizedBox(width: 12),
        ],
      ),
      floatingActionButton: apple
          ? null
          : FloatingActionButton.extended(
              onPressed: createHero,
              icon: const Icon(Icons.add),
              label: const Text('Neuer Held'),
            ),
      body: heroesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Fehler: $error')),
        data: (heroes) => Padding(
          padding: const EdgeInsets.all(20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = switch (constraints.maxWidth) {
                >= 1560 => (constraints.maxWidth - 40) / 3,
                >= 980 => (constraints.maxWidth - 20) / 2,
                _ => constraints.maxWidth,
              };

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HeroPageHeader(
                      title: 'Heldenarchiv',
                      subtitle:
                          'Wähle ein Heldendokument, springe direkt in den Workspace und halte Spielwerte übersichtlich an einer Stelle.',
                      metrics: [
                        HeroMetricChip(
                          label: 'Helden',
                          value: '${heroes.length}',
                        ),
                        HeroMetricChip(
                          label: 'Auswahl',
                          value: selectedHeroId == null ? 'Auto' : 'Fixiert',
                        ),
                        const HeroMetricChip(
                          label: 'Transfer',
                          value: 'JSON',
                          caption: 'Import und Export aktiv',
                        ),
                      ],
                      trailing: apple
                          ? FilledButton.icon(
                              onPressed: createHero,
                              icon: const Icon(Icons.add),
                              label: const Text('Neuer Held'),
                            )
                          : null,
                    ),
                    const SizedBox(height: 20),
                    if (heroes.isEmpty)
                      HeroDocumentSection(
                        title: 'Noch kein Held vorhanden',
                        subtitle:
                            'Erstelle einen neuen Helden oder importiere ein bestehendes Dokument.',
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton.icon(
                              onPressed: createHero,
                              icon: const Icon(Icons.add),
                              label: const Text('Held anlegen'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _importHero(
                                context: context,
                                ref: ref,
                                importExportActions: importExportActions,
                              ),
                              icon: const Icon(Icons.download),
                              label: const Text('Held importieren'),
                            ),
                          ],
                        ),
                      )
                    else
                      Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        children: [
                          for (final hero in heroes)
                            SizedBox(
                              width: cardWidth,
                              child: _HeroSummaryCard(
                                hero: hero,
                                isSelected: selectedHeroId == hero.id,
                                onOpen: () {
                                  ref
                                          .read(selectedHeroIdProvider.notifier)
                                          .state =
                                      hero.id;
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          HeroWorkspaceScreen(heroId: hero.id),
                                    ),
                                  );
                                },
                                onExport: () => _exportSelectedHero(
                                  context: context,
                                  ref: ref,
                                  hero: hero,
                                  importExportActions: importExportActions,
                                ),
                                onDelete: () => _deleteSelectedHero(
                                  context: context,
                                  ref: ref,
                                  hero: hero,
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _deleteSelectedHero({
    required BuildContext context,
    required WidgetRef ref,
    required HeroSheet hero,
  }) async {
    final result = await showAdaptiveConfirmDialog(
      context: context,
      title: 'Held löschen',
      content: 'Soll "${hero.name}" wirklich gelöscht werden?',
      confirmLabel: 'Löschen',
      cancelLabel: 'Abbrechen',
      isDestructive: true,
    );
    if (result != AdaptiveConfirmResult.confirm) {
      return;
    }
    await ref.read(heroActionsProvider).deleteHero(hero.id);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Held gelöscht: ${hero.name}')));
  }

  Future<void> _exportSelectedHero({
    required BuildContext context,
    required WidgetRef ref,
    required HeroSheet hero,
    required WorkspaceImportExportActions importExportActions,
  }) async {
    try {
      final outcome = await importExportActions.exportHeroData(
        ref: ref,
        hero: hero,
      );
      if (!context.mounted) {
        return;
      }
      if (outcome.result == HeroTransferExportResult.canceled) {
        return;
      }
      if (outcome.result == HeroTransferExportResult.savedToFile) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Held exportiert: ${outcome.location ?? 'Datei gespeichert'}',
            ),
          ),
        );
        return;
      }
      if (outcome.result == HeroTransferExportResult.downloaded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Held exportiert und Download gestartet'),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Held exportiert und geteilt')),
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

  Future<void> _importHero({
    required BuildContext context,
    required WidgetRef ref,
    required WorkspaceImportExportActions importExportActions,
  }) async {
    try {
      final importedId = await importExportActions.importHeroData(
        context: context,
        ref: ref,
      );
      if (importedId == null || !context.mounted) {
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => HeroWorkspaceScreen(heroId: importedId),
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Held erfolgreich importiert')),
      );
    } on FormatException catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import ungültig: ${error.message}')),
      );
    } on Exception catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import fehlgeschlagen: $error')));
    }
  }

  Future<_CreateHeroDraft?> _showCreateHeroDialog(BuildContext context) async {
    return showAdaptiveDetailSheet<_CreateHeroDraft>(
      context: context,
      builder: (dialogContext) => const _CreateHeroDialog(),
    );
  }
}

/// Kartenhafte Kurzübersicht eines Helden für die Startseite.
class _HeroSummaryCard extends ConsumerWidget {
  const _HeroSummaryCard({
    required this.hero,
    required this.isSelected,
    required this.onOpen,
    required this.onExport,
    required this.onDelete,
  });

  final HeroSheet hero;
  final bool isSelected;
  final VoidCallback onOpen;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final computed = ref.watch(heroComputedProvider(hero.id)).valueOrNull;
    final derived = computed?.derivedStats;
    final state = computed?.state;
    final resourceActivation = computed?.resourceActivation;
    final nameParts = hero.name.trim().split(RegExp(r'\s+'));
    final initials = nameParts
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.substring(0, 1).toUpperCase())
        .join();
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: isSelected
          ? colorScheme.secondaryContainer.withValues(alpha: 0.55)
          : colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? colorScheme.secondary
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: onOpen,
                leading: CircleAvatar(
                  radius: 26,
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.onPrimaryContainer,
                  child: Text(
                    initials.isEmpty ? 'H' : initials,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                title: Text(
                  hero.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${hero.background.rasse.isEmpty ? 'Unbekannte Herkunft' : hero.background.rasse} · ${hero.background.profession.isEmpty ? 'Ohne Profession' : hero.background.profession}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  HeroMetricChip(label: 'Stufe', value: '${hero.level}'),
                  HeroMetricChip(
                    label: 'AP frei',
                    value: '${hero.apAvailable}',
                  ),
                  HeroMetricChip(
                    label: 'Magie',
                    value: resourceActivation?.magic.isEnabled == true
                        ? 'Ja'
                        : 'Nein',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  HeroMetricChip(
                    label: 'LeP',
                    value: state == null || derived == null
                        ? '-'
                        : '${state.currentLep}/${derived.maxLep}',
                    backgroundColor: colorScheme.errorContainer.withValues(
                      alpha: 0.72,
                    ),
                    foregroundColor: colorScheme.onErrorContainer,
                  ),
                  HeroMetricChip(
                    label: 'Au',
                    value: state == null || derived == null
                        ? '-'
                        : '${state.currentAu}/${derived.maxAu}',
                    backgroundColor: colorScheme.tertiaryContainer.withValues(
                      alpha: 0.72,
                    ),
                    foregroundColor: colorScheme.onTertiaryContainer,
                  ),
                  HeroMetricChip(
                    label: 'AT/PA',
                    value: computed == null
                        ? '-'
                        : '${computed.combatPreviewStats.at}/${computed.combatPreviewStats.pa}',
                  ),
                  HeroMetricChip(
                    label: 'INI',
                    value: computed == null
                        ? '-'
                        : '${computed.combatPreviewStats.initiative}',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: onExport,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Export'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Löschen'),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 4, top: 10),
                    child: Icon(Icons.arrow_forward),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateHeroDialog extends StatefulWidget {
  const _CreateHeroDialog();

  @override
  State<_CreateHeroDialog> createState() => _CreateHeroDialogState();
}

class _CreateHeroDialogState extends State<_CreateHeroDialog> {
  late final TextEditingController _nameController;
  late final Map<String, TextEditingController> _attributeControllers;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _attributeControllers = <String, TextEditingController>{
      'mu': TextEditingController(text: '11'),
      'kl': TextEditingController(text: '11'),
      'inn': TextEditingController(text: '11'),
      'ch': TextEditingController(text: '11'),
      'ff': TextEditingController(text: '11'),
      'ge': TextEditingController(text: '11'),
      'ko': TextEditingController(text: '11'),
      'kk': TextEditingController(text: '11'),
    };
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final controller in _attributeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Neuen Helden anlegen'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: kDialogWidthSmall,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey<String>('create-hero-name'),
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _attributeFields(_attributeControllers),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              _CreateHeroDraft(
                name: _nameController.text.trim(),
                rawStartAttributes: Attributes(
                  mu: _readCreateAttributeValue(_attributeControllers, 'mu'),
                  kl: _readCreateAttributeValue(_attributeControllers, 'kl'),
                  inn: _readCreateAttributeValue(_attributeControllers, 'inn'),
                  ch: _readCreateAttributeValue(_attributeControllers, 'ch'),
                  ff: _readCreateAttributeValue(_attributeControllers, 'ff'),
                  ge: _readCreateAttributeValue(_attributeControllers, 'ge'),
                  ko: _readCreateAttributeValue(_attributeControllers, 'ko'),
                  kk: _readCreateAttributeValue(_attributeControllers, 'kk'),
                ),
              ),
            );
          },
          child: const Text('Anlegen'),
        ),
      ],
    );
  }

  List<Widget> _attributeFields(
    Map<String, TextEditingController> attributeControllers,
  ) {
    final labels = <(String, String)>[
      ('MU', 'mu'),
      ('KL', 'kl'),
      ('IN', 'inn'),
      ('CH', 'ch'),
      ('FF', 'ff'),
      ('GE', 'ge'),
      ('KO', 'ko'),
      ('KK', 'kk'),
    ];

    return labels
        .map(
          (entry) => SizedBox(
            width: 88,
            child: TextField(
              key: ValueKey<String>('create-hero-${entry.$2}'),
              controller: attributeControllers[entry.$2],
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: entry.$1,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        )
        .toList(growable: false);
  }

  int _readCreateAttributeValue(
    Map<String, TextEditingController> attributeControllers,
    String key,
  ) {
    final value = int.tryParse(attributeControllers[key]!.text.trim()) ?? 8;
    if (value < 0) {
      return 0;
    }
    if (value > 99) {
      return 99;
    }
    return value;
  }
}

class _CreateHeroDraft {
  const _CreateHeroDraft({
    required this.name,
    required this.rawStartAttributes,
  });

  final String name;
  final Attributes rawStartAttributes;
}
