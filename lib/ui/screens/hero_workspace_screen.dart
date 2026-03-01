import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_overview_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/heroes_home_screen.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_navigation_guard.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_registry.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

const int _overviewTabIndex = 0;
const int _talentsTabIndex = 1;
const int _combatTabIndex = 2;
const int _inventoryTabIndex = 4;
const double _commandDeckBreakpoint = 1280;
const double _commandDeckNavigationWidth = 240;
const double _commandDeckInspectorWidth = 300;

const List<_WorkspaceTabSpec> _workspaceTabs = <_WorkspaceTabSpec>[
  _WorkspaceTabSpec(
    label: 'Uebersicht',
    icon: Icons.dashboard_outlined,
    helper: 'Basisdaten und Ressourcen',
  ),
  _WorkspaceTabSpec(
    label: 'Talente',
    icon: Icons.auto_stories_outlined,
    helper: 'Talentwerte und Spezialisierungen',
  ),
  _WorkspaceTabSpec(
    label: 'Kampf',
    icon: Icons.sports_martial_arts_outlined,
    helper: 'Kampftechniken, Nahkampf, SF/Manoever',
  ),
  _WorkspaceTabSpec(
    label: 'Magie',
    icon: Icons.bolt_outlined,
    helper: 'Katalogansicht fuer Zauber',
  ),
  _WorkspaceTabSpec(
    label: 'Inventar',
    icon: Icons.inventory_2_outlined,
    helper: 'Ausrüstung und Gegenstaende',
  ),
  _WorkspaceTabSpec(
    label: 'Notizen',
    icon: Icons.sticky_note_2_outlined,
    helper: 'Freier Platzhalterbereich',
  ),
];

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

  bool _handlingTabChange = false;
  bool _revertingTabChange = false;
  bool _runningEditAction = false;

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

  List<Widget> _buildWorkspaceActions() {
    final activeTabIndex = _tabRegistry.activeTabIndex;
    final isEditing = _tabRegistry.isEditing(activeTabIndex);
    final tabActions = _tabRegistry.editActionsFor(activeTabIndex);

    VoidCallback? onStartEdit;
    VoidCallback? onSave;
    VoidCallback? onCancel;
    if (!_runningEditAction && tabActions != null) {
      onStartEdit = () => _runEditAction(tabActions.startEdit);
      onSave = () => _runEditAction(tabActions.save);
      onCancel = () => _runEditAction(tabActions.cancel);
    }

    final widgets = <Widget>[];

    if (activeTabIndex == _talentsTabIndex) {
      final visibilityMode = ref.watch(
        talentsVisibilityModeProvider(widget.heroId),
      );
      final bePreview = ref.watch(combatPreviewProvider(widget.heroId));
      final beOverride = ref.watch(talentBeOverrideProvider(widget.heroId));
      final activeBe = beOverride ?? bePreview.valueOrNull?.beKampf ?? 0;
      widgets.addAll([
        OutlinedButton.icon(
          key: const ValueKey<String>('talents-be-screen-open'),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TalentBeConfigScreen(
                  heroId: widget.heroId,
                  combatBaseBe: bePreview.valueOrNull?.beKampf ?? 0,
                ),
              ),
            );
          },
          icon: const Icon(Icons.shield_outlined),
          label: Text('BE konfigurieren ($activeBe)'),
        ),
        FilledButton.icon(
          key: const ValueKey<String>('talents-visibility-mode-toggle'),
          onPressed: () {
            ref
                    .read(talentsVisibilityModeProvider(widget.heroId).notifier)
                    .state =
                !visibilityMode;
          },
          icon: Icon(
            visibilityMode ? Icons.visibility_off_outlined : Icons.visibility,
          ),
          label: Text(
            visibilityMode ? 'Sichtbarkeit beenden' : 'Sichtbarkeit bearbeiten',
          ),
        ),
      ]);
    }

    if (activeTabIndex == _combatTabIndex) {
      final visibilityMode = ref.watch(
        combatTechniquesVisibilityModeProvider(widget.heroId),
      );
      widgets.add(
        FilledButton.icon(
          key: const ValueKey<String>('combat-talents-visibility-mode-toggle'),
          onPressed: () {
            ref
                    .read(
                      combatTechniquesVisibilityModeProvider(
                        widget.heroId,
                      ).notifier,
                    )
                    .state =
                !visibilityMode;
          },
          icon: Icon(
            visibilityMode ? Icons.visibility_off_outlined : Icons.visibility,
          ),
          label: Text(
            visibilityMode ? 'Sichtbarkeit beenden' : 'Sichtbarkeit bearbeiten',
          ),
        ),
      );
    }

    if (isEditing) {
      widgets.addAll([
        OutlinedButton(onPressed: onCancel, child: const Text('Abbrechen')),
        FilledButton(onPressed: onSave, child: const Text('Speichern')),
      ]);
    } else if (_tabRegistry.isEditableTab(activeTabIndex)) {
      widgets.add(
        FilledButton.icon(
          onPressed: onStartEdit,
          icon: const Icon(Icons.edit),
          label: const Text('Bearbeiten'),
        ),
      );
    } else {
      widgets.add(
        OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.edit),
          label: const Text('Bearbeiten'),
        ),
      );
    }
    return widgets;
  }

  PreferredSizeWidget _buildWorkspaceTabBar() {
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      tabs: const [
        Tab(text: '\u00dcbersicht'),
        Tab(text: 'Talente'),
        Tab(text: 'Kampf'),
        Tab(text: 'Magie'),
        Tab(text: 'Inventar'),
        Tab(text: 'Notizen'),
      ],
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
          showInlineActions: false,
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
          showInlineCombatTalentsActions: false,
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

  Widget _buildClassicWorkspaceBody(HeroSheet hero) {
    return Column(
      children: [
        _CoreAttributesHeader(heroId: widget.heroId, hero: hero),
        Expanded(child: _buildWorkspaceTabView()),
      ],
    );
  }

  Widget _buildCommandDeckWorkspaceBody(HeroSheet hero) {
    final activeTabIndex = _tabRegistry.activeTabIndex;
    return Row(
      children: [
        SizedBox(
          width: _commandDeckNavigationWidth,
          child: _CommandDeckNavigationPanel(
            activeTabIndex: activeTabIndex,
            isDirty: _tabRegistry.isDirty,
            onSelectTab: (index) {
              if (_tabController.index == index) {
                return;
              }
              _tabController.animateTo(index);
            },
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Column(
            children: [
              _CoreAttributesHeader(heroId: widget.heroId, hero: hero),
              Expanded(child: _buildWorkspaceTabView()),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        SizedBox(
          width: _commandDeckInspectorWidth,
          child: _WorkspaceInspectorPanel(
            hero: hero,
            activeTabIndex: activeTabIndex,
            isEditing: _tabRegistry.isEditing(activeTabIndex),
            isDirty: _tabRegistry.isDirty(activeTabIndex),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hero = ref.watch(heroByIdProvider(widget.heroId));
    final useCommandDeck =
        MediaQuery.sizeOf(context).width >= _commandDeckBreakpoint;

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
          actions: [..._buildWorkspaceActions()],
          bottom: useCommandDeck ? null : _buildWorkspaceTabBar(),
        ),
        body: useCommandDeck
            ? _buildCommandDeckWorkspaceBody(hero)
            : _buildClassicWorkspaceBody(hero),
      ),
    );
  }
}

class _WorkspaceTabSpec {
  const _WorkspaceTabSpec({
    required this.label,
    required this.icon,
    required this.helper,
  });

  final String label;
  final IconData icon;
  final String helper;
}

class _CommandDeckNavigationPanel extends StatelessWidget {
  const _CommandDeckNavigationPanel({
    required this.activeTabIndex,
    required this.isDirty,
    required this.onSelectTab,
  });

  final int activeTabIndex;
  final bool Function(int tabIndex) isDirty;
  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
              child: Text(
                'Command Deck',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _workspaceTabs.length,
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 12),
                itemBuilder: (context, index) {
                  final tab = _workspaceTabs[index];
                  final selected = index == activeTabIndex;
                  final dirty = isDirty(index);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      selected: selected,
                      selectedTileColor: Theme.of(
                        context,
                      ).colorScheme.secondaryContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      leading: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(tab.icon),
                          if (dirty)
                            Positioned(
                              right: -3,
                              top: -2,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.error,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Text(tab.label),
                      subtitle: Text(
                        tab.helper,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => onSelectTab(index),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceInspectorPanel extends StatelessWidget {
  const _WorkspaceInspectorPanel({
    required this.hero,
    required this.activeTabIndex,
    required this.isEditing,
    required this.isDirty,
  });

  final HeroSheet hero;
  final int activeTabIndex;
  final bool isEditing;
  final bool isDirty;

  @override
  Widget build(BuildContext context) {
    final tab = _workspaceTabs[activeTabIndex];
    final stateText = isEditing ? 'Bearbeitungsmodus' : 'Lesemodus';
    final dirtyText = isDirty
        ? 'Ungespeicherte Aenderungen'
        : 'Alles gespeichert';
    final levelText = hero.level.toString();
    final apAvailableText = hero.apAvailable.toString();

    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Inspector', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tab.label,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(tab.helper),
                      const SizedBox(height: 10),
                      Chip(label: Text(stateText)),
                      const SizedBox(height: 8),
                      Chip(label: Text(dirtyText)),
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
                      Text('Level: $levelText'),
                      Text('AP verfuegbar: $apAvailableText'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Hinweis: Tab-Wechsel und Zurueck-Navigation behalten den '
                    'bestehenden Discard-Guard bei.',
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
    final combatPreviewAsync = ref.watch(combatPreviewProvider(heroId));
    final talentBeOverride = ref.watch(talentBeOverrideProvider(heroId));
    final effectiveAttributes =
        effectiveAsync.valueOrNull ?? computeEffectiveAttributes(hero);
    final state = stateAsync.valueOrNull;
    final derived = derivedAsync.valueOrNull;
    final activeTalentBe =
        talentBeOverride ?? combatPreviewAsync.valueOrNull?.beKampf;

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
      'BE aktuell: ${activeTalentBe?.toString() ?? '-'}',
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
