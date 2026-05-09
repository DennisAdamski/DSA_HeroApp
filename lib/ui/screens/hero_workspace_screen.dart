import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/app_layout.dart';
import 'package:dsa_heldenverwaltung/ui/config/platform_adaptive.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_page_scaffold.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_split_view.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_bottom_navigation.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_command_deck_panel.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_core_attributes_header.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_hero_header.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_inspector_panel.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_navigation_guard.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_registry.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_spec.dart';
import 'package:dsa_heldenverwaltung/ui/screens/settings_screen.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';

part 'workspace/workspace_layout.dart';

/// Zentraler Workspace-Screen fuer die Bearbeitung und Anzeige eines Helden.
///
/// Hostet die sichtbaren Workspace-Tabs eines Helden und verwaltet
/// Tab-Navigation mit Discard-Guard fuer ungespeicherte Aenderungen.
/// Auf breiten Bildschirmen (>= 1280 dp) wird das Helden-Deck-Layout aktiviert.
class HeroWorkspaceScreen extends ConsumerStatefulWidget {
  /// Erstellt den Workspace-Screen fuer einen einzelnen Helden.
  const HeroWorkspaceScreen({super.key, required this.heroId});

  /// ID des darzustellenden Helden.
  final String heroId;

  @override
  ConsumerState<HeroWorkspaceScreen> createState() =>
      _HeroWorkspaceScreenState();
}

class _HeroWorkspaceScreenState extends ConsumerState<HeroWorkspaceScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late final WorkspaceTabRegistry _tabRegistry;
  List<WorkspaceTabSpec> _visibleTabs = const <WorkspaceTabSpec>[];

  bool _handlingTabChange = false;
  bool _revertingTabChange = false;
  bool _runningEditAction = false;
  bool _heroDeckExpanded = false;
  bool _workspaceDetailsExpanded = true;
  bool _catalogPrewarmScheduled = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _tabRegistry = WorkspaceTabRegistry();
    _tabController.addListener(_onTabControllerChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabControllerChanged);
    _tabController.dispose();
    super.dispose();
  }

  /// Erstellt die Host-Callbacks fuer einen einzelnen Workspace-Tab.
  WorkspaceTabCallbacks _callbacksForTab(String tabId) {
    return WorkspaceTabCallbacks(
      onDirtyChanged: (isDirty) => _updateDirty(tabId, isDirty),
      onEditingChanged: (isEditing) => _updateEditing(tabId, isEditing),
      onRegisterDiscard: (discardAction) =>
          _registerDiscard(tabId, discardAction),
      onRegisterEditActions: (actions) => _registerEditActions(tabId, actions),
    );
  }

  /// Synchronisiert sichtbare Tabs und TabController mit der aktuellen Registry.
  void _syncVisibleTabs(List<WorkspaceTabSpec> tabs) {
    final nextTabIds = tabs.map((tab) => tab.id).toList(growable: false);
    final currentTabIds = _visibleTabs
        .map((tab) => tab.id)
        .toList(growable: false);
    if (listEquals(nextTabIds, currentTabIds)) {
      return;
    }

    _visibleTabs = List<WorkspaceTabSpec>.unmodifiable(tabs);
    if (_visibleTabs.isEmpty) {
      _replaceTabController(length: 1, initialIndex: 0);
      _tabRegistry.activeTabId = null;
      return;
    }

    final previousActiveTabId = _tabRegistry.activeTabId;
    final hasPreviousActiveTab =
        previousActiveTabId != null &&
        _visibleTabs.any((tab) => tab.id == previousActiveTabId);
    final resolvedActiveTabId = hasPreviousActiveTab
        ? previousActiveTabId
        : _visibleTabs.first.id;
    final initialIndex = _visibleTabs.indexWhere(
      (tab) => tab.id == resolvedActiveTabId,
    );

    _replaceTabController(
      length: _visibleTabs.length,
      initialIndex: initialIndex < 0 ? 0 : initialIndex,
    );
    _tabRegistry.activeTabId = resolvedActiveTabId;
  }

  /// Erstellt den TabController neu fuer eine geaenderte sichtbare Tab-Liste.
  void _replaceTabController({required int length, required int initialIndex}) {
    _tabController.removeListener(_onTabControllerChanged);
    _tabController.dispose();
    _tabController = TabController(
      length: length,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController.addListener(_onTabControllerChanged);
  }

  /// Liefert den aktiven sichtbaren Tab-Index.
  int _activeTabIndex() {
    if (_visibleTabs.isEmpty) {
      return 0;
    }
    final activeTabId = _tabRegistry.activeTabId;
    if (activeTabId == null) {
      return 0;
    }
    final index = _visibleTabs.indexWhere((tab) => tab.id == activeTabId);
    return index < 0 ? 0 : index;
  }

  /// Liefert die aktuell aktive sichtbare Tab-Definition.
  WorkspaceTabSpec? _activeTabSpec() {
    if (_visibleTabs.isEmpty) {
      return null;
    }
    return _visibleTabs[_activeTabIndex()];
  }

  /// Waermt den Regelkatalog nach dem ersten Frame fuer spaetere Tabwechsel an.
  void _scheduleCatalogPrewarmIfNeeded() {
    if (_catalogPrewarmScheduled ||
        !_visibleTabs.any((tab) => tab.id == WorkspaceTabIds.magic)) {
      return;
    }
    _catalogPrewarmScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        ref
            .read(rulesCatalogProvider.future)
            .then<void>((_) {}, onError: (Object error, StackTrace stack) {}),
      );
    });
  }

  /// Reagiert auf Aenderungen des TabControllers und leitet den Guard ein.
  void _onTabControllerChanged() {
    if (_handlingTabChange || _revertingTabChange || _visibleTabs.isEmpty) {
      return;
    }
    final nextIndex = _tabController.index;
    final nextTabId = _visibleTabs[nextIndex].id;
    if (nextTabId == _tabRegistry.activeTabId) {
      return;
    }
    _handleTabChangeAttempt(nextIndex);
  }

  /// Prueft, ob ein Tab-Wechsel erlaubt ist und fuehrt ihn ggf. durch.
  Future<void> _handleTabChangeAttempt(int nextIndex) async {
    if (_handlingTabChange || _visibleTabs.isEmpty) {
      return;
    }

    _handlingTabChange = true;
    try {
      final fromTabId = _tabRegistry.activeTabId;
      final nextTabId = _visibleTabs[nextIndex].id;
      final mayLeave = fromTabId == null
          ? true
          : await _confirmLeaveForTab(fromTabId);
      if (!mounted) {
        return;
      }

      if (mayLeave) {
        setState(() {
          _tabRegistry.activeTabId = nextTabId;
        });
        return;
      }

      final fromIndex = _visibleTabs.indexWhere((tab) => tab.id == fromTabId);
      _revertingTabChange = true;
      _tabController.animateTo(fromIndex < 0 ? 0 : fromIndex);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _revertingTabChange = false;
      });
    } finally {
      _handlingTabChange = false;
    }
  }

  /// Zeigt den Discard-Dialog, wenn der Tab ungespeicherte Aenderungen hat.
  ///
  /// Gibt `true` zurueck, wenn der Tab-Wechsel erlaubt ist.
  Future<bool> _confirmLeaveForTab(String tabId) async {
    if (!_tabRegistry.isDirty(tabId)) {
      return true;
    }

    if (!mounted) {
      return false;
    }

    final result = await showWorkspaceDiscardDialog(context);
    if (result == AdaptiveConfirmResult.cancel) {
      return false;
    }

    if (result == AdaptiveConfirmResult.save) {
      final saveAction = _tabRegistry.editActionsFor(tabId)?.save;
      if (saveAction == null) {
        return false;
      }
      await saveAction();
    } else {
      final discardAction = _tabRegistry.discardActionFor(tabId);
      if (discardAction != null) {
        await discardAction();
      }
    }

    if (!mounted) {
      return false;
    }

    if (_tabRegistry.updateDirty(tabId, false)) {
      setState(() {});
    }
    return true;
  }

  /// Aktualisiert den Dirty-Zustand eines Tabs und triggert ggf. einen Rebuild.
  void _updateDirty(String tabId, bool isDirty) {
    if (!_tabRegistry.updateDirty(tabId, isDirty)) {
      return;
    }
    setState(() {});
  }

  /// Aktualisiert den Editing-Zustand eines Tabs und triggert ggf. einen Rebuild.
  void _updateEditing(String tabId, bool isEditing) {
    if (!_tabRegistry.updateEditing(tabId, isEditing)) {
      return;
    }
    setState(() {});
  }

  /// Registriert eine Discard-Aktion fuer einen Tab.
  void _registerDiscard(String tabId, WorkspaceAsyncAction discardAction) {
    _tabRegistry.registerDiscard(tabId, discardAction);
  }

  /// Registriert die Edit-Aktionen eines Tabs.
  void _registerEditActions(String tabId, WorkspaceTabEditActions actions) {
    final wasMissing = _tabRegistry.registerEditActions(tabId, actions);
    if (wasMissing && _tabRegistry.activeTabId == tabId) {
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

  /// Navigiert zur Heldenauswahl und prueft vorher auf ungespeicherte Aenderungen.
  Future<void> _navigateToHomeWithGuard() async {
    final activeTabId = _tabRegistry.activeTabId;
    final mayLeave = activeTabId == null
        ? true
        : await _confirmLeaveForTab(activeTabId);
    if (!mounted || !mayLeave) {
      return;
    }
    Navigator.of(context).pop();
  }

  /// Baut die Aktionsschaltflaechen fuer die AppBar.
  List<Widget> _buildWorkspaceActions({required bool isCompactLayout}) {
    final activeTab = _activeTabSpec();
    if (activeTab == null) {
      return const <Widget>[];
    }

    final activeTabId = activeTab.id;
    final isEditing = _tabRegistry.isEditing(activeTabId);
    final tabActions = _tabRegistry.editActionsFor(activeTabId);
    final useCompactIconOnlyEditActions =
        isCompactLayout && activeTab.useCompactIconOnlyEditActions;

    VoidCallback? onStartEdit;
    VoidCallback? onSave;
    VoidCallback? onCancel;
    if (!_runningEditAction && tabActions != null) {
      onStartEdit = () => _runEditAction(tabActions.startEdit);
      onSave = () => _runEditAction(tabActions.save);
      onCancel = () => _runEditAction(tabActions.cancel);
    }

    final widgets = <Widget>[];
    final headerActions = <WorkspaceHeaderAction>[
      ...activeTab.buildHeaderActions(
        context: context,
        ref: ref,
        heroId: widget.heroId,
        isCompactLayout: isCompactLayout,
      ),
      ...(tabActions?.headerActions ?? const <WorkspaceHeaderAction>[]),
    ];
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
            child: IconButton(onPressed: onSave, icon: const Icon(Icons.check)),
          ),
        ]);
      } else {
        widgets.addAll([
          OutlinedButton(onPressed: onCancel, child: const Text('Abbrechen')),
          FilledButton(onPressed: onSave, child: const Text('Speichern')),
        ]);
      }
    } else if (_tabRegistry.isEditableTab(activeTabId)) {
      if (useCompactIconOnlyEditActions) {
        widgets.add(
          Tooltip(
            message: 'Bearbeiten',
            child: IconButton(
              onPressed: onStartEdit,
              icon: const Icon(Icons.edit),
            ),
          ),
        );
      } else {
        widgets.add(
          FilledButton.icon(
            onPressed: onStartEdit,
            icon: const Icon(Icons.edit),
            label: const Text('Bearbeiten'),
          ),
        );
      }
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

  /// Baut die horizontale TabBar fuer das klassische Layout.
  PreferredSizeWidget _buildWorkspaceTabBar() {
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      tabs: _visibleTabs
          .map((tab) => Tab(text: tab.label))
          .toList(growable: false),
    );
  }

  /// Baut den TabBarView mit allen aktuell sichtbaren Tab-Widgets.
  Widget _buildWorkspaceTabView() {
    if (_visibleTabs.isEmpty) {
      return const Center(child: Text('Keine Bereiche verfügbar.'));
    }

    return TabBarView(
      controller: _tabController,
      children: _visibleTabs
          .map(
            (tab) => tab.buildContent(
              heroId: widget.heroId,
              callbacks: _callbacksForTab(tab.id),
            ),
          )
          .toList(growable: false),
    );
  }

  /// Schaltet das linke Helden-Deck je Layout zwischen ein- und ausgefahren um.
  void _toggleHeroDeckExpanded(AppLayoutClass layout) {
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

  @override
  Widget build(BuildContext context) {
    final hero = ref.watch(heroByIdProvider(widget.heroId));
    final layout = appLayoutOf(context);

    if (hero == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Held')),
        body: const Center(child: Text('Held nicht gefunden.')),
      );
    }

    final allTabs = buildWorkspaceTabs(
      heroId: widget.heroId,
      callbacksForTab: _callbacksForTab,
    );
    _tabRegistry.setEditableTabs(
      allTabs.where((tab) => tab.isEditable).map((tab) => tab.id),
    );
    _syncVisibleTabs(visibleWorkspaceTabsForHero(hero: hero, tabs: allTabs));
    _scheduleCatalogPrewarmIfNeeded();

    final apple = isApplePlatform(context);
    final hasVisibleTabs = _visibleTabs.isNotEmpty;
    final isCompactLayout = layout == AppLayoutClass.compact;
    final useBottomNav = isCompactLayout && apple && hasVisibleTabs;
    final showTabBar = isCompactLayout && !apple && hasVisibleTabs;
    final showInspectorAction = layout == AppLayoutClass.tabletPortrait;

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
            ..._buildSpacedWorkspaceActions(
              _buildWorkspaceActions(isCompactLayout: isCompactLayout),
            ),
            if (!(_tabRegistry.activeTabId != null &&
                _tabRegistry.isEditing(_tabRegistry.activeTabId!)))
              IconButton(
                tooltip: 'Einstellungen',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
                icon: const Icon(Icons.settings),
              ),
          ],
          bottom: showTabBar ? _buildWorkspaceTabBar() : null,
        ),
        bottomNavigationBar: useBottomNav
            ? WorkspaceBottomNavigation(
                tabs: _visibleTabs,
                activeTabIndex: _activeTabIndex(),
                onSelectTab: (index) {
                  if (_tabController.index == index) {
                    return;
                  }
                  _tabController.animateTo(index);
                },
              )
            : null,
        body: switch (layout) {
          AppLayoutClass.compact => _buildCompactWorkspaceBody(hero),
          AppLayoutClass.tabletPortrait => _buildTabletPortraitWorkspaceBody(
            hero,
          ),
          AppLayoutClass.tabletLandscape => _buildTabletLandscapeWorkspaceBody(
            hero,
          ),
          AppLayoutClass.desktopWide => _buildDesktopWideWorkspaceBody(hero),
        },
      ),
    );
  }
}
