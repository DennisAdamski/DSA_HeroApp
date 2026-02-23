import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_transfer_bundle.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_basis_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_overview_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/heroes_home_screen.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

const int _overviewTabIndex = 0;
const int _basisTabIndex = 1;

class HeroWorkspaceScreen extends ConsumerStatefulWidget {
  const HeroWorkspaceScreen({super.key, required this.heroId});

  final String heroId;

  @override
  ConsumerState<HeroWorkspaceScreen> createState() =>
      _HeroWorkspaceScreenState();
}

class _HeroWorkspaceScreenState extends ConsumerState<HeroWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  int _activeTabIndex = 0;
  bool _handlingTabChange = false;
  bool _revertingTabChange = false;
  bool _runningEditAction = false;

  final Map<int, bool> _dirtyByTab = <int, bool>{
    _overviewTabIndex: false,
    _basisTabIndex: false,
  };
  final Map<int, bool> _editingByTab = <int, bool>{
    _overviewTabIndex: false,
    _basisTabIndex: false,
  };
  final Map<int, WorkspaceAsyncAction> _discardByTab =
      <int, WorkspaceAsyncAction>{};
  final Map<int, WorkspaceTabEditActions> _editActionsByTab =
      <int, WorkspaceTabEditActions>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _tabController.addListener(_onTabControllerChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabControllerChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabControllerChanged() {
    if (_handlingTabChange || _revertingTabChange) {
      return;
    }
    final nextIndex = _tabController.index;
    if (nextIndex == _activeTabIndex) {
      return;
    }
    _handleTabChangeAttempt(nextIndex);
  }

  Future<void> _handleTabChangeAttempt(int nextIndex) async {
    if (_handlingTabChange) {
      return;
    }
    _handlingTabChange = true;
    final fromIndex = _activeTabIndex;
    final mayLeave = await _confirmLeaveForTab(fromIndex);
    if (!mounted) {
      return;
    }

    if (mayLeave) {
      setState(() {
        _activeTabIndex = nextIndex;
      });
    } else {
      _revertingTabChange = true;
      _tabController.animateTo(fromIndex);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _revertingTabChange = false;
      });
    }

    _handlingTabChange = false;
  }

  Future<bool> _confirmLeaveForTab(int tabIndex) async {
    final isDirty = _dirtyByTab[tabIndex] ?? false;
    if (!isDirty) {
      return true;
    }

    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) {
      return false;
    }

    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Ungespeicherte Änderungen verwerfen?'),
          content: const Text(
            'Wenn du fortfährst, gehen die ungespeicherten Änderungen '
            'im aktuellen Tab verloren.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Nein'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Ja'),
            ),
          ],
        );
      },
    );

    if (discard != true) {
      return false;
    }

    final discardAction = _discardByTab[tabIndex];
    if (discardAction != null) {
      await discardAction();
    }

    if (!mounted) {
      return false;
    }

    setState(() {
      _dirtyByTab[tabIndex] = false;
    });
    return true;
  }

  bool _isEditableTab(int tabIndex) {
    return tabIndex == _overviewTabIndex || tabIndex == _basisTabIndex;
  }

  void _updateDirty(int tabIndex, bool isDirty) {
    if ((_dirtyByTab[tabIndex] ?? false) == isDirty) {
      return;
    }
    setState(() {
      _dirtyByTab[tabIndex] = isDirty;
    });
  }

  void _updateEditing(int tabIndex, bool isEditing) {
    if ((_editingByTab[tabIndex] ?? false) == isEditing) {
      return;
    }
    setState(() {
      _editingByTab[tabIndex] = isEditing;
    });
  }

  void _registerDiscard(int tabIndex, WorkspaceAsyncAction discardAction) {
    _discardByTab[tabIndex] = discardAction;
  }

  void _registerEditActions(int tabIndex, WorkspaceTabEditActions actions) {
    final wasMissing = !_editActionsByTab.containsKey(tabIndex);
    _editActionsByTab[tabIndex] = actions;
    if (wasMissing && _activeTabIndex == tabIndex) {
      setState(() {});
    }
  }

  Future<void> _runEditAction(WorkspaceAsyncAction? action) async {
    if (_runningEditAction || action == null) {
      return;
    }
    setState(() {
      _runningEditAction = true;
    });
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          _runningEditAction = false;
        });
      }
    }
  }

  Future<void> _navigateToHomeWithGuard() async {
    final mayLeave = await _confirmLeaveForTab(_activeTabIndex);
    if (!mounted || !mayLeave) {
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HeroesHomeScreen()),
    );
  }

  Widget _buildGlobalActionHeader(BuildContext context) {
    if (_isEditableTab(_activeTabIndex)) {
      final isEditing = _editingByTab[_activeTabIndex] ?? false;
      final actions = _editActionsByTab[_activeTabIndex];
      final canRunActions = actions != null;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (isEditing) ...[
              OutlinedButton(
                onPressed: _runningEditAction || !canRunActions
                    ? null
                    : () => _runEditAction(actions.cancel),
                child: const Text('Abbrechen'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _runningEditAction || !canRunActions
                    ? null
                    : () => _runEditAction(actions.save),
                child: const Text('Speichern'),
              ),
            ] else
              FilledButton.icon(
                onPressed: _runningEditAction || !canRunActions
                    ? null
                    : () => _runEditAction(actions.startEdit),
                icon: const Icon(Icons.edit),
                label: const Text('Bearbeiten'),
              ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Tooltip(
            message: 'In diesem Tab noch nicht verfügbar',
            child: OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.edit),
              label: const Text('Bearbeiten'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'In diesem Tab noch nicht verfügbar',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final heroes =
        ref.watch(heroListProvider).valueOrNull ?? const <HeroSheet>[];

    HeroSheet? hero;
    for (final item in heroes) {
      if (item.id == widget.heroId) {
        hero = item;
        break;
      }
    }

    if (hero == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Held')),
        body: const Center(child: Text('Held nicht gefunden.')),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _navigateToHomeWithGuard();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(hero.name),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Heldenauswahl',
            onPressed: _navigateToHomeWithGuard,
          ),
          actions: [
            IconButton(
              onPressed: () => _exportHeroData(context, ref, hero!),
              icon: const Icon(Icons.upload_file),
              tooltip: 'Held exportieren',
            ),
            IconButton(
              onPressed: () => _importHeroData(context, ref),
              icon: const Icon(Icons.download),
              tooltip: 'Held importieren',
            ),
            IconButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                await ref.read(heroActionsProvider).deleteHero(widget.heroId);
                if (!context.mounted) {
                  return;
                }
                navigator.pushReplacement(
                  MaterialPageRoute(builder: (_) => const HeroesHomeScreen()),
                );
              },
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Held loeschen',
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Übersicht'),
              Tab(text: 'Basis'),
              Tab(text: 'Kampf'),
              Tab(text: 'Magie'),
              Tab(text: 'Talente'),
              Tab(text: 'Inventar'),
              Tab(text: 'Notizen'),
            ],
          ),
        ),
        body: Column(
          children: [
            _CoreAttributesHeader(hero: hero),
            _buildGlobalActionHeader(context),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  HeroOverviewTab(
                    heroId: widget.heroId,
                    onDirtyChanged: (isDirty) =>
                        _updateDirty(_overviewTabIndex, isDirty),
                    onEditingChanged: (isEditing) =>
                        _updateEditing(_overviewTabIndex, isEditing),
                    onRegisterDiscard: (discardAction) =>
                        _registerDiscard(_overviewTabIndex, discardAction),
                    onRegisterEditActions: (actions) =>
                        _registerEditActions(_overviewTabIndex, actions),
                  ),
                  HeroBasisTab(
                    heroId: widget.heroId,
                    onDirtyChanged: (isDirty) =>
                        _updateDirty(_basisTabIndex, isDirty),
                    onEditingChanged: (isEditing) =>
                        _updateEditing(_basisTabIndex, isEditing),
                    onRegisterDiscard: (discardAction) =>
                        _registerDiscard(_basisTabIndex, discardAction),
                    onRegisterEditActions: (actions) =>
                        _registerEditActions(_basisTabIndex, actions),
                  ),
                  const _PlaceholderTab(title: 'Kampf'),
                  const _CatalogPlaceholderTab(
                    title: 'Magie',
                    section: _CatalogSection.spells,
                  ),
                  HeroTalentsTab(heroId: widget.heroId),
                  const _CatalogPlaceholderTab(
                    title: 'Inventar',
                    section: _CatalogSection.weapons,
                  ),
                  const _PlaceholderTab(title: 'Notizen'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportHeroData(
    BuildContext context,
    WidgetRef ref,
    HeroSheet hero,
  ) async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      final payload = await ref
          .read(heroActionsProvider)
          .buildExportJson(hero.id);
      final gateway = ref.read(heroTransferFileGatewayProvider);
      final outcome = await gateway.exportJson(
        fileNameBase: hero.name,
        jsonPayload: payload,
      );

      if (!context.mounted) {
        return;
      }

      if (outcome.result.name == 'canceled') {
        return;
      }
      if (outcome.result.name == 'savedToFile') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Held exportiert: ${outcome.location ?? 'Datei gespeichert'}',
            ),
          ),
        );
        return;
      }
      if (outcome.result.name == 'downloaded') {
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

  Future<void> _importHeroData(BuildContext context, WidgetRef ref) async {
    final gateway = ref.read(heroTransferFileGatewayProvider);
    final rawJson = await gateway.pickImportJson();
    if (rawJson == null) {
      return;
    }

    try {
      final actions = ref.read(heroActionsProvider);
      final bundle = await actions.parseImportJson(rawJson);
      if (!context.mounted) {
        return;
      }
      final resolution = await _resolveConflict(context, ref, bundle);
      if (resolution == null) {
        return;
      }

      final importedId = await actions.importHeroBundle(
        bundle,
        resolution: resolution,
      );

      if (!context.mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
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
        SnackBar(content: Text('Import ungueltig: ${error.message}')),
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

  Future<ImportConflictResolution?> _resolveConflict(
    BuildContext context,
    WidgetRef ref,
    HeroTransferBundle bundle,
  ) async {
    final heroes = await ref.read(heroListProvider.future);
    var exists = false;
    for (final hero in heroes) {
      if (hero.id == bundle.hero.id) {
        exists = true;
        break;
      }
    }
    if (!exists) {
      return ImportConflictResolution.overwriteExisting;
    }

    if (!context.mounted) {
      return null;
    }
    return showDialog<ImportConflictResolution>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Held bereits vorhanden'),
          content: const Text(
            'Die importierte Held-ID existiert bereits. Soll der vorhandene Held '
            'ueberschrieben oder als neuer Held importiert werden?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Abbrechen'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(ImportConflictResolution.createNewHero),
              child: const Text('Als neu erstellen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(ImportConflictResolution.overwriteExisting),
              child: const Text('Ueberschreiben'),
            ),
          ],
        );
      },
    );
  }
}

class _CoreAttributesHeader extends StatelessWidget {
  const _CoreAttributesHeader({required this.hero});

  final HeroSheet hero;

  @override
  Widget build(BuildContext context) {
    final effectiveAttributes = computeEffectiveAttributes(hero);
    final attrs = [
      ('MU', effectiveAttributes.mu),
      ('KL', effectiveAttributes.kl),
      ('IN', effectiveAttributes.inn),
      ('CH', effectiveAttributes.ch),
      ('FF', effectiveAttributes.ff),
      ('GE', effectiveAttributes.ge),
      ('KO', effectiveAttributes.ko),
      ('KK', effectiveAttributes.kk),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: attrs
            .map(
              (entry) => Chip(
                label: Text('${entry.$1}: ${entry.$2}'),
                visualDensity: VisualDensity.compact,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('$title wird als naechstes ausgearbeitet.'));
  }
}

enum _CatalogSection { talents, spells, weapons }

class _CatalogPlaceholderTab extends ConsumerWidget {
  const _CatalogPlaceholderTab({required this.title, required this.section});

  final String title;
  final _CatalogSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(rulesCatalogProvider);

    return catalogAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          Center(child: Text('Katalog-Fehler: $error')),
      data: (catalog) {
        final count = switch (section) {
          _CatalogSection.talents => catalog.talents.length,
          _CatalogSection.spells => catalog.spells.length,
          _CatalogSection.weapons => catalog.weapons.length,
        };

        final details = switch (section) {
          _CatalogSection.talents =>
            'mit Waffengattung: ${catalog.talents.where((t) => t.weaponCategory.isNotEmpty).length}',
          _CatalogSection.spells =>
            'mit Verfuegbarkeit: ${catalog.spells.where((s) => s.availability.isNotEmpty).length}',
          _CatalogSection.weapons =>
            'mit Waffengattung: ${catalog.weapons.where((w) => w.weaponCategory.isNotEmpty).length}',
        };

        return Center(
          child: Text(
            '$title: $count Eintraege aus ${catalog.version} geladen ($details).',
          ),
        );
      },
    );
  }
}
