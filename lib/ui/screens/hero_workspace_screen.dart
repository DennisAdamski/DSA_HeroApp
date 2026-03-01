import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/hero_transfer_file_gateway.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_overview_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/heroes_home_screen.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_global_action_header.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_import_export_actions.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_navigation_guard.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_registry.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

const int _overviewTabIndex = 0;
const int _talentsTabIndex = 1;
const int _combatTabIndex = 2;
const int _inventoryTabIndex = 4;
const double _tacticalBoardBreakpoint = 1280;
const double _tacticalStatusWidth = 300;

enum _TacticalViewMode { read, edit, validate }

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
  late final WorkspaceTabRegistry _tabRegistry;
  final WorkspaceImportExportActions _importExportActions =
      const WorkspaceImportExportActions();

  bool _handlingTabChange = false;
  bool _revertingTabChange = false;
  bool _runningEditAction = false;
  _TacticalViewMode _viewMode = _TacticalViewMode.read;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabRegistry = WorkspaceTabRegistry(
      editableTabs: const <int>{
        _overviewTabIndex,
        _talentsTabIndex,
        _combatTabIndex,
        _inventoryTabIndex,
      },
    );
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
    if (nextIndex == _tabRegistry.activeTabIndex) {
      return;
    }
    _handleTabChangeAttempt(nextIndex);
  }

  Future<void> _handleTabChangeAttempt(int nextIndex) async {
    if (_handlingTabChange) {
      return;
    }
    _handlingTabChange = true;
    final fromIndex = _tabRegistry.activeTabIndex;
    final mayLeave = await _confirmLeaveForTab(fromIndex);
    if (!mounted) {
      return;
    }

    if (mayLeave) {
      setState(() {
        _tabRegistry.activeTabIndex = nextIndex;
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
    if (!_tabRegistry.isDirty(tabIndex)) {
      return true;
    }

    if (!mounted) {
      return false;
    }

    final discard = await showWorkspaceDiscardDialog(context);
    if (!discard) {
      return false;
    }

    final discardAction = _tabRegistry.discardActionFor(tabIndex);
    if (discardAction != null) {
      await discardAction();
    }

    if (!mounted) {
      return false;
    }

    if (_tabRegistry.updateDirty(tabIndex, false)) {
      setState(() {});
    }
    return true;
  }

  void _updateDirty(int tabIndex, bool isDirty) {
    if (!_tabRegistry.updateDirty(tabIndex, isDirty)) {
      return;
    }
    setState(() {});
  }

  void _updateEditing(int tabIndex, bool isEditing) {
    if (!_tabRegistry.updateEditing(tabIndex, isEditing)) {
      return;
    }
    setState(() {});
  }

  void _registerDiscard(int tabIndex, WorkspaceAsyncAction discardAction) {
    _tabRegistry.registerDiscard(tabIndex, discardAction);
  }

  void _registerEditActions(int tabIndex, WorkspaceTabEditActions actions) {
    final wasMissing = _tabRegistry.registerEditActions(tabIndex, actions);
    if (wasMissing && _tabRegistry.activeTabIndex == tabIndex) {
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
    final mayLeave = await _confirmLeaveForTab(_tabRegistry.activeTabIndex);
    if (!mounted || !mayLeave) {
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HeroesHomeScreen()),
    );
  }

  Widget _buildGlobalActionHeader() {
    final activeTabIndex = _tabRegistry.activeTabIndex;
    final tabActions = _tabRegistry.editActionsFor(activeTabIndex);
    VoidCallback? onStartEdit;
    VoidCallback? onSave;
    VoidCallback? onCancel;
    if (!_runningEditAction && tabActions != null) {
      onStartEdit = () => _runEditAction(tabActions.startEdit);
      onSave = () => _runEditAction(tabActions.save);
      onCancel = () => _runEditAction(tabActions.cancel);
    }

    return WorkspaceGlobalActionHeader(
      isEditableTab: _tabRegistry.isEditableTab(activeTabIndex),
      isEditing: _tabRegistry.isEditing(activeTabIndex),
      onStartEdit: onStartEdit,
      onSave: onSave,
      onCancel: onCancel,
    );
  }

  Widget _buildWorkspaceTabView() {
    return TabBarView(
      controller: _tabController,
      children: [
        HeroOverviewTab(
          heroId: widget.heroId,
          onDirtyChanged: (isDirty) => _updateDirty(_overviewTabIndex, isDirty),
          onEditingChanged: (isEditing) =>
              _updateEditing(_overviewTabIndex, isEditing),
          onRegisterDiscard: (discardAction) =>
              _registerDiscard(_overviewTabIndex, discardAction),
          onRegisterEditActions: (actions) =>
              _registerEditActions(_overviewTabIndex, actions),
        ),
        HeroTalentsTab(
          heroId: widget.heroId,
          onDirtyChanged: (isDirty) => _updateDirty(_talentsTabIndex, isDirty),
          onEditingChanged: (isEditing) =>
              _updateEditing(_talentsTabIndex, isEditing),
          onRegisterDiscard: (discardAction) =>
              _registerDiscard(_talentsTabIndex, discardAction),
          onRegisterEditActions: (actions) =>
              _registerEditActions(_talentsTabIndex, actions),
        ),
        HeroCombatTab(
          heroId: widget.heroId,
          onDirtyChanged: (isDirty) => _updateDirty(_combatTabIndex, isDirty),
          onEditingChanged: (isEditing) =>
              _updateEditing(_combatTabIndex, isEditing),
          onRegisterDiscard: (discardAction) =>
              _registerDiscard(_combatTabIndex, discardAction),
          onRegisterEditActions: (actions) =>
              _registerEditActions(_combatTabIndex, actions),
        ),
        const _CatalogPlaceholderTab(
          title: 'Magie',
          section: _CatalogSection.spells,
        ),
        HeroInventoryTab(
          heroId: widget.heroId,
          onDirtyChanged: (isDirty) =>
              _updateDirty(_inventoryTabIndex, isDirty),
          onEditingChanged: (isEditing) =>
              _updateEditing(_inventoryTabIndex, isEditing),
          onRegisterDiscard: (discardAction) =>
              _registerDiscard(_inventoryTabIndex, discardAction),
          onRegisterEditActions: (actions) =>
              _registerEditActions(_inventoryTabIndex, actions),
        ),
        const _PlaceholderTab(title: 'Notizen'),
      ],
    );
  }

  Widget _buildTacticalModeSelector() {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainer,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [
          SegmentedButton<_TacticalViewMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment<_TacticalViewMode>(
                value: _TacticalViewMode.read,
                icon: Icon(Icons.visibility_outlined),
                label: Text('Lesen'),
              ),
              ButtonSegment<_TacticalViewMode>(
                value: _TacticalViewMode.edit,
                icon: Icon(Icons.edit_outlined),
                label: Text('Edit-Ansicht'),
              ),
              ButtonSegment<_TacticalViewMode>(
                value: _TacticalViewMode.validate,
                icon: Icon(Icons.rule_outlined),
                label: Text('Validieren'),
              ),
            ],
            selected: <_TacticalViewMode>{_viewMode},
            onSelectionChanged: (next) {
              if (next.isEmpty) {
                return;
              }
              setState(() {
                _viewMode = next.first;
              });
            },
          ),
          Text(switch (_viewMode) {
            _TacticalViewMode.read => 'Leseansicht mit Fokus auf Uebersicht',
            _TacticalViewMode.edit => 'Arbeitsansicht mit editierbaren Daten',
            _TacticalViewMode.validate => 'Pruefansicht mit Statusfokus',
          }, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  String _tabLabelForIndex(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return 'Uebersicht';
      case 1:
        return 'Talente';
      case 2:
        return 'Kampf';
      case 3:
        return 'Magie';
      case 4:
        return 'Inventar';
      case 5:
        return 'Notizen';
      default:
        return 'Unbekannt';
    }
  }

  Widget _buildTacticalStandardBody(HeroSheet hero) {
    final headerTone = _viewMode == _TacticalViewMode.edit
        ? Theme.of(context).colorScheme.secondaryContainer
        : Theme.of(context).colorScheme.surface;
    return Column(
      children: [
        _buildTacticalModeSelector(),
        _CoreAttributesHeader(heroId: widget.heroId, hero: hero),
        ColoredBox(color: headerTone, child: _buildGlobalActionHeader()),
        Expanded(child: _buildWorkspaceTabView()),
      ],
    );
  }

  Widget _buildTacticalWideBody(HeroSheet hero) {
    final activeTabIndex = _tabRegistry.activeTabIndex;
    final headerTone = _viewMode == _TacticalViewMode.edit
        ? Theme.of(context).colorScheme.secondaryContainer
        : Theme.of(context).colorScheme.surface;
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              _buildTacticalModeSelector(),
              _CoreAttributesHeader(heroId: widget.heroId, hero: hero),
              ColoredBox(color: headerTone, child: _buildGlobalActionHeader()),
              Expanded(child: _buildWorkspaceTabView()),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        SizedBox(
          width: _tacticalStatusWidth,
          child: _TacticalStatusPanel(
            hero: hero,
            activeTabLabel: _tabLabelForIndex(activeTabIndex),
            isEditing: _tabRegistry.isEditing(activeTabIndex),
            isDirty: _tabRegistry.isDirty(activeTabIndex),
            mode: _viewMode,
            isEditableTab: _tabRegistry.isEditableTab(activeTabIndex),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hero = ref.watch(heroByIdProvider(widget.heroId));
    final useTacticalWide =
        MediaQuery.sizeOf(context).width >= _tacticalBoardBreakpoint;

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
              onPressed: () => _exportHeroData(context, ref, hero),
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
              Tab(text: 'Talente'),
              Tab(text: 'Kampf'),
              Tab(text: 'Magie'),
              Tab(text: 'Inventar'),
              Tab(text: 'Notizen'),
            ],
          ),
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFFF2F7FA), Color(0xFFE8EEF3)],
            ),
          ),
          child: useTacticalWide
              ? _buildTacticalWideBody(hero)
              : _buildTacticalStandardBody(hero),
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
      final outcome = await _importExportActions.exportHeroData(
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

  Future<void> _importHeroData(BuildContext context, WidgetRef ref) async {
    try {
      final importedId = await _importExportActions.importHeroData(
        context: context,
        ref: ref,
      );
      if (importedId == null) {
        return;
      }

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
}

class _TacticalStatusPanel extends StatelessWidget {
  const _TacticalStatusPanel({
    required this.hero,
    required this.activeTabLabel,
    required this.isEditing,
    required this.isDirty,
    required this.mode,
    required this.isEditableTab,
  });

  final HeroSheet hero;
  final String activeTabLabel;
  final bool isEditing;
  final bool isDirty;
  final _TacticalViewMode mode;
  final bool isEditableTab;

  @override
  Widget build(BuildContext context) {
    String modeLabel(_TacticalViewMode current) {
      switch (current) {
        case _TacticalViewMode.read:
          return 'Lesen';
        case _TacticalViewMode.edit:
          return 'Bearbeiten';
        case _TacticalViewMode.validate:
          return 'Validieren';
      }
    }

    final statusText = isDirty
        ? 'Aenderungen offen'
        : 'Keine offenen Aenderungen';
    final tabEditText = isEditableTab ? 'Editierbarer Tab' : 'Read-only Tab';

    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Taktikstatus',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Modus: ${modeLabel(mode)}'),
                      const SizedBox(height: 6),
                      Text('Aktiver Bereich: $activeTabLabel'),
                      const SizedBox(height: 6),
                      Chip(
                        label: Text(
                          isEditing ? 'Im Edit-Modus' : 'Nicht im Edit-Modus',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Chip(label: Text(statusText)),
                      const SizedBox(height: 8),
                      Chip(label: Text(tabEditText)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hero.name,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Text('Level: ${hero.level}'),
                      Text('AP gesamt: ${hero.apTotal}'),
                      Text('AP verfuegbar: ${hero.apAvailable}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Hinweis: Die fachliche Validierung bleibt unveraendert; '
                    'dieses Panel verdichtet nur den aktuellen Bearbeitungsstatus.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoreAttributesHeader extends ConsumerWidget {
  const _CoreAttributesHeader({required this.heroId, required this.hero});

  final String heroId;
  final HeroSheet hero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveAsync = ref.watch(effectiveAttributesProvider(heroId));
    final stateAsync = ref.watch(heroStateProvider(heroId));
    final derivedAsync = ref.watch(derivedStatsProvider(heroId));
    final effectiveAttributes =
        effectiveAsync.valueOrNull ?? computeEffectiveAttributes(hero);
    final state = stateAsync.valueOrNull;
    final derived = derivedAsync.valueOrNull;

    String resourceText(int? current, int? max) {
      final currentText = current?.toString() ?? '-';
      final maxText = max?.toString() ?? '-';
      return '$currentText/$maxText';
    }

    final chips = <String>[
      'MU: ${effectiveAttributes.mu}',
      'KL: ${effectiveAttributes.kl}',
      'IN: ${effectiveAttributes.inn}',
      'CH: ${effectiveAttributes.ch}',
      'FF: ${effectiveAttributes.ff}',
      'GE: ${effectiveAttributes.ge}',
      'KO: ${effectiveAttributes.ko}',
      'KK: ${effectiveAttributes.kk}',
      'LEP: ${resourceText(state?.currentLep, derived?.maxLep)}',
      'AU: ${resourceText(state?.currentAu, derived?.maxAu)}',
      'ASP: ${resourceText(state?.currentAsp, derived?.maxAsp)}',
      'KAP: ${resourceText(state?.currentKap, derived?.maxKap)}',
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
        children: chips
            .map(
              (entry) => Chip(
                label: Text(entry),
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
