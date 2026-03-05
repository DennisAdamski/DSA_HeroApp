import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_magic_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_overview_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/heroes_home_screen.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_command_deck_panel.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_core_attributes_header.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_inspector_panel.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_navigation_guard.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_placeholder_tabs.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_registry.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

/// Mindestbreite in logischen Pixeln ab der das Command-Deck-Layout aktiv wird.
const double _commandDeckBreakpoint = 1280;

/// Breite der Command-Deck-Navigationsleiste in Pixeln.
const double _commandDeckNavigationWidth = 240;

/// Breite des Command-Deck-Inspectors in Pixeln.
const double _commandDeckInspectorWidth = 300;

// Tab-Indizes fuer die Workspace-Tabs.
const int _overviewTabIndex = 0;
const int _talentsTabIndex = 1;
const int _combatTabIndex = 2;
const int _magicTabIndex = 3;
const int _inventoryTabIndex = 4;

/// Zentraler Workspace-Screen fuer die Bearbeitung und Anzeige eines Helden.
///
/// Hostet sechs Tabs (Uebersicht, Talente, Kampf, Magie, Inventar, Notizen)
/// und verwaltet Tab-Navigation mit Discard-Guard fuer ungespeicherte Aenderungen.
/// Auf breiten Bildschirmen (>= 1280 dp) wird das Command-Deck-Layout aktiviert.
class HeroWorkspaceScreen extends ConsumerStatefulWidget {
  const HeroWorkspaceScreen({super.key, required this.heroId});

  /// ID des darzustellenden Helden.
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
        _magicTabIndex,
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

  /// Reagiert auf Aenderungen des TabControllers und leitet den Guard ein.
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

  /// Prueft ob ein Tab-Wechsel erlaubt ist und fuehrt ihn ggf. durch.
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

  /// Zeigt den Discard-Dialog wenn der Tab ungespeicherte Aenderungen hat.
  ///
  /// Gibt `true` zurueck wenn der Tab-Wechsel erlaubt ist.
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

  /// Aktualisiert den Dirty-Zustand eines Tabs und triggert ggf. einen Rebuild.
  void _updateDirty(int tabIndex, bool isDirty) {
    if (!_tabRegistry.updateDirty(tabIndex, isDirty)) {
      return;
    }
    setState(() {});
  }

  /// Aktualisiert den Editing-Zustand eines Tabs und triggert ggf. einen Rebuild.
  void _updateEditing(int tabIndex, bool isEditing) {
    if (!_tabRegistry.updateEditing(tabIndex, isEditing)) {
      return;
    }
    setState(() {});
  }

  /// Registriert eine Discard-Aktion fuer einen Tab.
  void _registerDiscard(int tabIndex, WorkspaceAsyncAction discardAction) {
    _tabRegistry.registerDiscard(tabIndex, discardAction);
  }

  /// Registriert die Edit-Aktionen (start/save/cancel) fuer einen Tab.
  void _registerEditActions(int tabIndex, WorkspaceTabEditActions actions) {
    final wasMissing = _tabRegistry.registerEditActions(tabIndex, actions);
    if (wasMissing && _tabRegistry.activeTabIndex == tabIndex) {
      setState(() {});
    }
  }

  /// Fuehrt eine Edit-Aktion asynchron aus und blockiert doppelte Ausfuehrung.
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

  /// Navigiert zur Heldenauswahl — prueft vorher auf ungespeicherte Aenderungen.
  Future<void> _navigateToHomeWithGuard() async {
    final mayLeave = await _confirmLeaveForTab(_tabRegistry.activeTabIndex);
    if (!mounted || !mayLeave) {
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HeroesHomeScreen()),
    );
  }

  /// Baut die Aktionsschaltflaechen fuer die AppBar (Bearbeiten/Speichern/Abbrechen).
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
      widgets.addAll([
        OutlinedButton.icon(
          key: const ValueKey<String>('talents-be-screen-open'),
          onPressed: () {
            showDialog<void>(
              context: context,
              builder: (_) => TalentBeConfigDialog(
                heroId: widget.heroId,
                combatBaseBe: bePreview.valueOrNull?.beKampf ?? 0,
              ),
            );
          },
          icon: const Icon(Icons.shield_outlined),
          label: const Text('BE konfigurieren'),
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
          label: Text(visibilityMode ? 'Sichtbarkeit aus' : 'Sichtbarkeit'),
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
            visibilityMode ? 'Sichtbarkeit aus' : 'Sichtbarkeit',
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

  /// Fuegt gleichmaessige horizontale Abstaende zwischen Aktions-Widgets ein.
  List<Widget> _buildSpacedWorkspaceActions(List<Widget> actions) {
    if (actions.isEmpty) {
      return const <Widget>[];
    }
    final spaced = <Widget>[const SizedBox(width: 8)];
    for (var index = 0; index < actions.length; index++) {
      if (index > 0) {
        spaced.add(const SizedBox(width: 8));
      }
      spaced.add(actions[index]);
    }
    spaced.add(const SizedBox(width: 12));
    return spaced;
  }

  /// Baut die horizontale TabBar fuer das klassische (schmale) Layout.
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

  /// Baut den TabBarView mit allen sechs Tab-Widgets.
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
        HeroMagicTab(
          heroId: widget.heroId,
          onDirtyChanged: (isDirty) =>
              _updateDirty(_magicTabIndex, isDirty),
          onEditingChanged: (isEditing) =>
              _updateEditing(_magicTabIndex, isEditing),
          onRegisterDiscard: (discardAction) =>
              _registerDiscard(_magicTabIndex, discardAction),
          onRegisterEditActions: (actions) =>
              _registerEditActions(_magicTabIndex, actions),
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
        const WorkspacePlaceholderTab(title: 'Notizen'),
      ],
    );
  }

  /// Klassisches Layout: Attribut-Header oben, darunter der Tab-Inhalt.
  Widget _buildClassicWorkspaceBody(HeroSheet hero) {
    return Column(
      children: [
        WorkspaceCoreAttributesHeader(heroId: widget.heroId, hero: hero),
        Expanded(child: _buildWorkspaceTabView()),
      ],
    );
  }

  /// Command-Deck-Layout: Navigation links, Inhalt mittig, Inspector rechts.
  Widget _buildCommandDeckWorkspaceBody(HeroSheet hero) {
    final activeTabIndex = _tabRegistry.activeTabIndex;
    return Row(
      children: [
        SizedBox(
          width: _commandDeckNavigationWidth,
          child: WorkspaceCommandDeckNavigationPanel(
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
              WorkspaceCoreAttributesHeader(heroId: widget.heroId, hero: hero),
              Expanded(child: _buildWorkspaceTabView()),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        SizedBox(
          width: _commandDeckInspectorWidth,
          child: WorkspaceInspectorPanel(
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
          actions: _buildSpacedWorkspaceActions(_buildWorkspaceActions()),
          bottom: useCommandDeck ? null : _buildWorkspaceTabBar(),
        ),
        body: useCommandDeck
            ? _buildCommandDeckWorkspaceBody(hero)
            : _buildClassicWorkspaceBody(hero),
      ),
    );
  }
}
