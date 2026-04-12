import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/hero_transfer_file_gateway.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/app_layout.dart';
import 'package:dsa_heldenverwaltung/ui/config/platform_adaptive.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';
import 'package:dsa_heldenverwaltung/ui/screens/gruppen_uebersicht_screen.dart';
import 'package:dsa_heldenverwaltung/ui/screens/home/hero_home_tablet_panels.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_workspace_screen.dart';
import 'package:dsa_heldenverwaltung/ui/screens/settings_screen.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_import_export_actions.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_empty_state.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_page_scaffold.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_split_view.dart';

/// Startscreen fuer die Heldenauswahl mit iPad-tauglicher Vorschau.
class HeroesHomeScreen extends ConsumerWidget {
  /// Erstellt die Heldenzentrale mit adaptivem Tablet-Layout.
  const HeroesHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heroesAsync = ref.watch(heroListProvider);
    final selectedHeroId = ref.watch(selectedHeroIdProvider);
    const importExportActions = WorkspaceImportExportActions();
    final apple = isApplePlatform(context);
    final layout = appLayoutOf(context);

    Future<void> createHero() async {
      final draft = await _showCreateHeroDialog(context);
      if (draft == null || !context.mounted) {
        return;
      }
      final id = await ref
          .read(heroActionsProvider)
          .createHero(
            name: draft.name,
            rawStartAttributes: draft.rawStartAttributes,
          );
      ref.read(selectedHeroIdProvider.notifier).state = id;
      if (!context.mounted) {
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => HeroWorkspaceScreen(heroId: id)),
      );
    }

    Future<void> openHeroWorkspace(String heroId) async {
      ref.read(selectedHeroIdProvider.notifier).state = heroId;
      if (!context.mounted) {
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => HeroWorkspaceScreen(heroId: heroId)),
      );
    }

    Future<void> showHeroPreviewSheet(HeroSheet hero) async {
      ref.read(selectedHeroIdProvider.notifier).state = hero.id;
      await showAdaptiveDetailSheet<void>(
        context: context,
        builder: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: HeroHomePreviewPanel(
              hero: hero,
              onOpenWorkspace: () {
                Navigator.of(context, rootNavigator: true).pop();
                openHeroWorkspace(hero.id);
              },
              onExportHero: () => _exportSelectedHero(
                context: context,
                ref: ref,
                hero: hero,
                importExportActions: importExportActions,
              ),
              onDeleteHero: () => _deleteSelectedHero(
                context: context,
                ref: ref,
                hero: hero,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('DSA Helden'),
        actions: _buildAppBarActions(
          layout: layout,
          apple: apple,
          onCreateHero: createHero,
          onImportHero: () => _importHero(
            context: context,
            ref: ref,
            importExportActions: importExportActions,
          ),
          onOpenSettings: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
          onOpenGroupOverview: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const GruppenUebersichtScreen()),
          ),
          onShareGroup: () => _showGruppenExportDialog(
            context: context,
            ref: ref,
            importExportActions: importExportActions,
          ),
        ),
      ),
      floatingActionButton:
          layout == AppLayoutClass.compact && !apple
              ? FloatingActionButton.extended(
                  onPressed: createHero,
                  icon: const Icon(Icons.add),
                  label: const Text('Neuer Held'),
                )
              : null,
      body: heroesAsync.when(
        data: (heroes) {
          if (heroes.isEmpty) {
            return CodexPageScaffold(
              padding: EdgeInsets.all(layout.contentPadding),
              child: Center(
                child: CodexEmptyState(
                  title: 'Dein Heldenarchiv ist noch leer',
                  message:
                      'Lege deinen ersten Helden an oder importiere einen bestehenden Bogen, um auf dem iPad mit einem digitalen Heldenbogen zu arbeiten.',
                  assetPath: 'assets/ui/codex/empty_ledger.png',
                  action: FilledButton.icon(
                    onPressed: createHero,
                    icon: const Icon(Icons.add),
                    label: const Text('Ersten Helden anlegen'),
                  ),
                ),
              ),
            );
          }

          final selectedHero = _resolveSelectedHero(
            heroes: heroes,
            selectedHeroId: selectedHeroId,
          );
          final archivePane = HeroHomeArchivePane(
            heroes: heroes,
            selectedHeroId: selectedHero?.id,
            layout: layout,
            onSelectHero: (hero) {
              if (layout.hasPersistentDetailPane) {
                ref.read(selectedHeroIdProvider.notifier).state = hero.id;
                return;
              }
              if (layout == AppLayoutClass.tabletPortrait) {
                showHeroPreviewSheet(hero);
                return;
              }
              openHeroWorkspace(hero.id);
            },
            onExportHero: (hero) => _exportSelectedHero(
              context: context,
              ref: ref,
              hero: hero,
              importExportActions: importExportActions,
            ),
            onDeleteHero: (hero) => _deleteSelectedHero(
              context: context,
              ref: ref,
              hero: hero,
            ),
          );

          if (!layout.hasPersistentDetailPane) {
            return archivePane;
          }

          return CodexSplitView(
            primaryWidth: layout == AppLayoutClass.desktopWide ? 420 : 360,
            primary: archivePane,
            secondary: CodexPageScaffold(
              padding: EdgeInsets.all(layout.contentPadding),
              child: HeroHomePreviewPanel(
                hero: selectedHero!,
                onOpenWorkspace: () => openHeroWorkspace(selectedHero.id),
                onExportHero: () => _exportSelectedHero(
                  context: context,
                  ref: ref,
                  hero: selectedHero,
                  importExportActions: importExportActions,
                ),
                onDeleteHero: () => _deleteSelectedHero(
                  context: context,
                  ref: ref,
                  hero: selectedHero,
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Fehler: $error')),
      ),
    );
  }

  List<Widget> _buildAppBarActions({
    required AppLayoutClass layout,
    required bool apple,
    required Future<void> Function() onCreateHero,
    required Future<void> Function() onImportHero,
    required VoidCallback onOpenSettings,
    required VoidCallback onOpenGroupOverview,
    required Future<void> Function() onShareGroup,
  }) {
    if (layout == AppLayoutClass.compact) {
      return [
        if (apple)
          IconButton(
            tooltip: 'Neuer Held',
            onPressed: onCreateHero,
            icon: const Icon(Icons.add),
          ),
        IconButton(
          tooltip: 'Importieren',
          onPressed: onImportHero,
          icon: const Icon(Icons.download),
        ),
        _HomeGroupMenuButton(
          compact: true,
          onOpenGroupOverview: onOpenGroupOverview,
          onShareGroup: onShareGroup,
        ),
        IconButton(
          tooltip: 'Einstellungen',
          onPressed: onOpenSettings,
          icon: const Icon(Icons.settings),
        ),
        const SizedBox(width: 12),
      ];
    }

    return [
      const SizedBox(width: 8),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: FilledButton.tonalIcon(
          onPressed: onCreateHero,
          icon: const Icon(Icons.add),
          label: const Text('Neuer Held'),
        ),
      ),
      const SizedBox(width: 8),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: OutlinedButton.icon(
          onPressed: onImportHero,
          icon: const Icon(Icons.download),
          label: const Text('Importieren'),
        ),
      ),
      _HomeGroupMenuButton(
        compact: false,
        onOpenGroupOverview: onOpenGroupOverview,
        onShareGroup: onShareGroup,
      ),
      IconButton(
        tooltip: 'Einstellungen',
        onPressed: onOpenSettings,
        icon: const Icon(Icons.settings),
      ),
      const SizedBox(width: 12),
    ];
  }

  HeroSheet? _resolveSelectedHero({
    required List<HeroSheet> heroes,
    required String? selectedHeroId,
  }) {
    for (final hero in heroes) {
      if (hero.id == selectedHeroId) {
        return hero;
      }
    }
    if (heroes.isEmpty) {
      return null;
    }
    return heroes.first;
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
      final result = await importExportActions.importSmartData(
        context: context,
        ref: ref,
      );
      if (result == null || !context.mounted) {
        return;
      }

      if (result.type == ImportResult.gruppe) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const GruppenUebersichtScreen()),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gruppe erfolgreich importiert')),
        );
        return;
      }

      if (result.heroId != null) {
        ref.read(selectedHeroIdProvider.notifier).state = result.heroId;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => HeroWorkspaceScreen(heroId: result.heroId!),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Held erfolgreich importiert')),
        );
      }
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

  Future<void> _showGruppenExportDialog({
    required BuildContext context,
    required WidgetRef ref,
    required WorkspaceImportExportActions importExportActions,
  }) async {
    final heroes = ref.read(heroListProvider).valueOrNull ?? const [];
    if (heroes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keine Helden zum Teilen vorhanden')),
      );
      return;
    }

    final result = await showAdaptiveDetailSheet<_GruppenExportDraft>(
      context: context,
      builder: (dialogContext) => _GruppenExportDialog(heroes: heroes),
    );
    if (result == null || !context.mounted) {
      return;
    }

    try {
      final outcome = await importExportActions.exportGruppenSnapshot(
        ref: ref,
        gruppenName: result.gruppenName,
        heroIds: result.heroIds,
      );
      if (!context.mounted) {
        return;
      }
      if (outcome.result == HeroTransferExportResult.canceled) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gruppe exportiert und geteilt')),
      );
    } on Exception catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export fehlgeschlagen: $error')),
      );
    }
  }

  Future<_CreateHeroDraft?> _showCreateHeroDialog(BuildContext context) async {
    return showAdaptiveDetailSheet<_CreateHeroDraft>(
      context: context,
      builder: (dialogContext) => const _CreateHeroDialog(),
    );
  }
}

class _HomeGroupMenuButton extends StatelessWidget {
  const _HomeGroupMenuButton({
    required this.compact,
    required this.onOpenGroupOverview,
    required this.onShareGroup,
  });

  final bool compact;
  final VoidCallback onOpenGroupOverview;
  final Future<void> Function() onShareGroup;

  @override
  Widget build(BuildContext context) {
    final trigger = compact
        ? const Icon(Icons.group)
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.group, size: 18),
                SizedBox(width: 8),
                Text('Gruppe'),
              ],
            ),
          );

    return PopupMenuButton<String>(
      tooltip: 'Gruppe',
      onSelected: (value) {
        switch (value) {
          case 'teilen':
            onShareGroup();
          case 'uebersicht':
            onOpenGroupOverview();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'teilen',
          child: ListTile(
            leading: Icon(Icons.share),
            title: Text('Gruppe teilen'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'uebersicht',
          child: ListTile(
            leading: Icon(Icons.people_outline),
            title: Text('Gruppenübersicht'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      child: compact
          ? trigger
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: trigger,
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

class _GruppenExportDraft {
  const _GruppenExportDraft({
    required this.gruppenName,
    required this.heroIds,
  });

  final String gruppenName;
  final List<String> heroIds;
}

class _GruppenExportDialog extends StatefulWidget {
  const _GruppenExportDialog({required this.heroes});

  final List<HeroSheet> heroes;

  @override
  State<_GruppenExportDialog> createState() => _GruppenExportDialogState();
}

class _GruppenExportDialogState extends State<_GruppenExportDialog> {
  late final TextEditingController _nameController;
  late final Map<String, bool> _selectedHeroes;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Meine Gruppe');
    _selectedHeroes = {for (final hero in widget.heroes) hero.id: true};
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedHeroes.values.where((v) => v).length;

    return AlertDialog(
      title: const Text('Gruppe teilen'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: kDialogWidthSmall,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Gruppenname',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ...widget.heroes.map(
                (hero) => CheckboxListTile(
                  value: _selectedHeroes[hero.id] ?? false,
                  title: Text(hero.name),
                  subtitle: Text('Level ${hero.level}'),
                  dense: true,
                  onChanged: (value) {
                    setState(() {
                      _selectedHeroes[hero.id] = value ?? false;
                    });
                  },
                ),
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
          onPressed: selectedCount == 0
              ? null
              : () {
                  final heroIds = _selectedHeroes.entries
                      .where((entry) => entry.value)
                      .map((entry) => entry.key)
                      .toList(growable: false);
                  Navigator.of(context).pop(
                    _GruppenExportDraft(
                      gruppenName: _nameController.text.trim(),
                      heroIds: heroIds,
                    ),
                  );
                },
          child: Text('Teilen ($selectedCount)'),
        ),
      ],
    );
  }
}
