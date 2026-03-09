import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/platform_adaptive.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_magic_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_notes_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_overview_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_bottom_navigation.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_command_deck_panel.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_core_attributes_header.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_inspector_panel.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_navigation_guard.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_registry.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

/// Layout-Stufen fuer den Workspace je nach verfuegbarer Breite.
enum WorkspaceLayout {
  /// iPhone / schmales Fenster (< 744dp): TabBar oder Bottom Nav.
  compact,
  /// iPad Portrait / mittelbreit (744–1023dp): Collapsed Sidebar + Content.
  medium,
  /// iPad Landscape / breit (1024–1279dp): Ausgeklappte Sidebar + Content.
  expanded,
  /// Desktop / sehr breit (>= 1280dp): Drei-Spalten Helden-Deck.
  heroDeck,
}

/// Breite der ausgefahrenen Helden-Deck-Navigationsleiste in Pixeln.
const double _heroDeckNavigationWidth = 240;

/// Breite der eingeklappten Helden-Deck-Umschaltleiste in Pixeln.
const double _heroDeckCollapsedWidth = 56;

/// Breite des ausgefahrenen rechten Workspace-Panels in Pixeln.
const double _heroDeckInspectorWidth = 300;

/// Breite der eingeklappten rechten Workspace-Umschaltleiste in Pixeln.
const double _heroDeckInspectorCollapsedWidth = 56;

// Tab-Indizes fuer die Workspace-Tabs.
const int _overviewTabIndex = 0;
const int _talentsTabIndex = 1;
const int _combatTabIndex = 2;
const int _magicTabIndex = 3;
const int _inventoryTabIndex = 4;
const int _notesTabIndex = 5;

/// Zentraler Workspace-Screen fuer die Bearbeitung und Anzeige eines Helden.
///
/// Hostet sechs Tabs (Status, Talente, Kampf, Magie, Inventar, Notizen)
/// und verwaltet Tab-Navigation mit Discard-Guard fuer ungespeicherte Aenderungen.
/// Auf breiten Bildschirmen (>= 1280 dp) wird das Helden-Deck-Layout aktiviert.
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
  bool _heroDeckExpanded = true;
  bool _workspaceDetailsExpanded = true;

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
        _notesTabIndex,
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
    Navigator.of(context).pop();
  }

  /// Baut die Aktionsschaltflaechen fuer die AppBar (Bearbeiten/Speichern/Abbrechen).
  List<Widget> _buildWorkspaceActions() {
    final activeTabIndex = _tabRegistry.activeTabIndex;
    final isEditing = _tabRegistry.isEditing(activeTabIndex);
    final tabActions = _tabRegistry.editActionsFor(activeTabIndex);
    final isCompactLayout =
        _layoutForWidth(MediaQuery.sizeOf(context).width) ==
        WorkspaceLayout.compact;
    final useCompactIconOnlyEditActions =
        isCompactLayout && activeTabIndex == _talentsTabIndex;

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
      final bePreview = ref.watch(combatPreviewProvider(widget.heroId));
      void openBeDialog() {
        showDialog<void>(
          context: context,
          builder: (_) => TalentBeConfigDialog(
            heroId: widget.heroId,
            combatBaseBe: bePreview.valueOrNull?.beKampf ?? 0,
          ),
        );
      }
      widgets.add(
        isCompactLayout
            ? Tooltip(
                message: 'BE konfigurieren',
                child: IconButton(
                  key: const ValueKey<String>('talents-be-screen-open'),
                  onPressed: openBeDialog,
                  icon: const Icon(Icons.shield_outlined),
                ),
              )
            : OutlinedButton.icon(
                key: const ValueKey<String>('talents-be-screen-open'),
                onPressed: openBeDialog,
                icon: const Icon(Icons.shield_outlined),
                label: const Text('BE konfigurieren'),
              ),
      );
    }

    final headerActions =
        tabActions?.headerActions ?? const <WorkspaceHeaderAction>[];
    for (final action in headerActions) {
      final shouldShow = isEditing
          ? action.showWhenEditing
          : action.showWhenIdle;
      if (!shouldShow) {
        continue;
      }
      widgets.add(action.builder(context));
    }

    if (isEditing) {
      if (useCompactIconOnlyEditActions) {
        widgets.addAll([
          Tooltip(
            message: 'Abbrechen',
            child: IconButton(
              onPressed: onCancel,
              icon: const Icon(Icons.close),
            ),
          ),
          Tooltip(
            message: 'Speichern',
            child: IconButton(
              onPressed: onSave,
              icon: const Icon(Icons.check),
            ),
          ),
        ]);
      } else {
        widgets.addAll([
          OutlinedButton(onPressed: onCancel, child: const Text('Abbrechen')),
          FilledButton(onPressed: onSave, child: const Text('Speichern')),
        ]);
      }
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
        Tab(text: 'Status'),
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
          onDirtyChanged: (isDirty) => _updateDirty(_magicTabIndex, isDirty),
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
        HeroNotesTab(
          heroId: widget.heroId,
          onDirtyChanged: (isDirty) => _updateDirty(_notesTabIndex, isDirty),
          onEditingChanged: (isEditing) =>
              _updateEditing(_notesTabIndex, isEditing),
          onRegisterDiscard: (discardAction) =>
              _registerDiscard(_notesTabIndex, discardAction),
          onRegisterEditActions: (actions) =>
              _registerEditActions(_notesTabIndex, actions),
        ),
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

  /// Schaltet das linke Helden-Deck zwischen ein- und ausgefahren um.
  void _toggleHeroDeckExpanded() {
    setState(() {
      _heroDeckExpanded = !_heroDeckExpanded;
    });
  }

  /// Schaltet das rechte Workspace-Detailpanel zwischen ein- und ausgefahren um.
  void _toggleWorkspaceDetailsExpanded() {
    setState(() {
      _workspaceDetailsExpanded = !_workspaceDetailsExpanded;
    });
  }

  /// Helden-Deck-Layout: Navigation links, Inhalt mittig, Detailpanel rechts.
  Widget _buildHeroDeckWorkspaceBody(HeroSheet hero) {
    final activeTabIndex = _tabRegistry.activeTabIndex;
    final navigationWidth = _heroDeckExpanded
        ? _heroDeckNavigationWidth
        : _heroDeckCollapsedWidth;
    final detailsWidth = _workspaceDetailsExpanded
        ? _heroDeckInspectorWidth
        : _heroDeckInspectorCollapsedWidth;
    return Row(
      children: [
        SizedBox(
          width: navigationWidth,
          child: WorkspaceCommandDeckNavigationPanel(
            activeTabIndex: activeTabIndex,
            isExpanded: _heroDeckExpanded,
            isDirty: _tabRegistry.isDirty,
            onToggleExpanded: _toggleHeroDeckExpanded,
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
          width: detailsWidth,
          child: WorkspaceInspectorPanel(
            heroId: widget.heroId,
            isExpanded: _workspaceDetailsExpanded,
            onToggleExpanded: _toggleWorkspaceDetailsExpanded,
          ),
        ),
      ],
    );
  }

  /// Ermittelt das passende Layout anhand der verfuegbaren Breite.
  WorkspaceLayout _layoutForWidth(double width) {
    if (width >= kHeroDeckBreakpoint) return WorkspaceLayout.heroDeck;
    if (width >= kTabletBreakpoint) return WorkspaceLayout.expanded;
    if (width >= kMediumBreakpoint) return WorkspaceLayout.medium;
    return WorkspaceLayout.compact;
  }

  /// Medium-Layout: Collapsed Sidebar (Icon-only) + Content-Bereich.
  Widget _buildMediumWorkspaceBody(HeroSheet hero) {
    final activeTabIndex = _tabRegistry.activeTabIndex;
    return Row(
      children: [
        SizedBox(
          width: _heroDeckCollapsedWidth,
          child: WorkspaceCommandDeckNavigationPanel(
            activeTabIndex: activeTabIndex,
            isExpanded: false,
            isDirty: _tabRegistry.isDirty,
            onToggleExpanded: () {},
            onSelectTab: (index) {
              if (_tabController.index == index) return;
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
      ],
    );
  }

  /// Expanded-Layout: Ausgeklappte Sidebar + Content, kein Inspector.
  Widget _buildExpandedWorkspaceBody(HeroSheet hero) {
    final activeTabIndex = _tabRegistry.activeTabIndex;
    final navigationWidth = _heroDeckExpanded
        ? _heroDeckNavigationWidth
        : _heroDeckCollapsedWidth;
    return Row(
      children: [
        SizedBox(
          width: navigationWidth,
          child: WorkspaceCommandDeckNavigationPanel(
            activeTabIndex: activeTabIndex,
            isExpanded: _heroDeckExpanded,
            isDirty: _tabRegistry.isDirty,
            onToggleExpanded: _toggleHeroDeckExpanded,
            onSelectTab: (index) {
              if (_tabController.index == index) return;
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
      ],
    );
  }

  /// Zeigt den Inspector als BottomSheet (fuer Medium/Expanded ohne Inspector-Spalte).
  void _showInspectorSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        builder: (sheetContext, scrollController) =>
            WorkspaceInspectorPanel(
          heroId: widget.heroId,
          isExpanded: true,
          onToggleExpanded: () => Navigator.of(sheetContext).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hero = ref.watch(heroByIdProvider(widget.heroId));
    final width = MediaQuery.sizeOf(context).width;
    final layout = _layoutForWidth(width);

    if (hero == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Held')),
        body: const Center(child: Text('Held nicht gefunden.')),
      );
    }

    final apple = isApplePlatform(context);
    final useBottomNav = layout == WorkspaceLayout.compact && apple;
    final showTabBar = layout == WorkspaceLayout.compact && !apple;
    final showInspectorAction =
        layout == WorkspaceLayout.medium ||
        layout == WorkspaceLayout.expanded;

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
            key: const ValueKey<String>('workspace-back-button'),
            icon: Icon(apple ? Icons.arrow_back_ios : Icons.arrow_back),
            tooltip: 'Heldenauswahl',
            onPressed: _navigateToHomeWithGuard,
          ),
          actions: [
            if (showInspectorAction)
              IconButton(
                tooltip: 'Detailpanel',
                icon: const Icon(Icons.info_outline),
                onPressed: _showInspectorSheet,
              ),
            ..._buildSpacedWorkspaceActions(_buildWorkspaceActions()),
          ],
          bottom: showTabBar ? _buildWorkspaceTabBar() : null,
        ),
        bottomNavigationBar: useBottomNav
            ? WorkspaceBottomNavigation(
                activeTabIndex: _tabRegistry.activeTabIndex,
                onSelectTab: (index) {
                  if (_tabController.index == index) return;
                  _tabController.animateTo(index);
                },
              )
            : null,
        body: switch (layout) {
          WorkspaceLayout.compact => _buildClassicWorkspaceBody(hero),
          WorkspaceLayout.medium => _buildMediumWorkspaceBody(hero),
          WorkspaceLayout.expanded => _buildExpandedWorkspaceBody(hero),
          WorkspaceLayout.heroDeck => _buildHeroDeckWorkspaceBody(hero),
        },
      ),
    );
  }
}
