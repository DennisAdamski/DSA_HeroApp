import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/advancement/advancement_catalog.dart';
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
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_management_body.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_management_coordinator.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/probe_quick_search.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/rules_lookup_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_spec.dart';
import 'package:dsa_heldenverwaltung/ui/screens/settings_screen.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';

part 'workspace/workspace_layout.dart';
part 'workspace/workspace_advancement.dart';

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
  late final WorkspaceManagementCoordinator _management;
  bool _heroDeckExpanded = false;
  bool _workspaceDetailsExpanded = true;
  bool _catalogPrewarmScheduled = false;

  @override
  void initState() {
    super.initState();
    _management = WorkspaceManagementCoordinator(
      heroId: widget.heroId,
      vsync: this,
      contextProvider: () => context,
      hostIsMounted: () => mounted,
    );
    _management.addListener(_rebuildFromManagement);
  }

  /// Aktualisiert den klassischen Rahmen bei Änderungen des Koordinators.
  void _rebuildFromManagement() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _management.removeListener(_rebuildFromManagement);
    _management.dispose();
    super.dispose();
  }

  /// Liefert den aktiven sichtbaren Tab-Index.
  int _activeTabIndex() => _management.activeTabIndex;

  /// Liefert die aktuell aktive sichtbare Tab-Definition.
  WorkspaceTabSpec? _activeTabSpec() => _management.activeTab;

  /// Waermt den Regelkatalog nach dem ersten Frame fuer spaetere Tabwechsel an.
  void _scheduleCatalogPrewarmIfNeeded() {
    if (_catalogPrewarmScheduled ||
        !_management.visibleTabs.any(
          (tab) => tab.id == WorkspaceTabIds.magic,
        )) {
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

  /// Zeigt den Discard-Dialog, wenn der Tab ungespeicherte Aenderungen hat.
  ///
  /// Gibt `true` zurueck, wenn der Tab-Wechsel erlaubt ist.
  Future<bool> _confirmLeaveForTab(String tabId) {
    return _management.confirmLeaveForTab(tabId);
  }

  /// Fuehrt eine Edit-Aktion asynchron aus und blockiert doppelte Ausfuehrung.
  Future<void> _runEditAction(WorkspaceAsyncAction? action) {
    return _management.runEditAction(action);
  }

  /// Navigiert zur Heldenauswahl und prueft vorher auf ungespeicherte Aenderungen.
  Future<void> _navigateToHomeWithGuard() async {
    if (!await _confirmLeaveAdvancement() || !mounted) return;
    final activeTabId = _management.activeTabId;
    final mayLeave = activeTabId == null
        ? true
        : await _confirmLeaveForTab(activeTabId);
    if (!mounted || !mayLeave) {
      return;
    }
    Navigator.of(context).pop();
  }

  /// Baut die Schaltflaeche fuer die Proben-Schnellsuche.
  ///
  /// Die Suche ist tab-unabhaengig immer verfuegbar, damit im Spiel jede
  /// Probe ohne Tab-Wechsel erreichbar bleibt.
  Widget _buildProbeQuickSearchAction() {
    return Tooltip(
      message: 'Probe suchen und würfeln',
      child: IconButton(
        key: const ValueKey('workspace-probe-quick-search'),
        onPressed: () => showProbeQuickSearch(
          context: context,
          ref: ref,
          heroId: widget.heroId,
        ),
        icon: const Icon(Icons.casino_outlined),
      ),
    );
  }

  /// Baut die Schaltflaeche fuer den Regel-Nachschlag (nur Desktop).
  ///
  /// Liefert `null`, wenn die Plattform keine lokale Wissensbasis hat.
  Widget? _buildRulesLookupAction() {
    if (!isRulesLookupSupported()) {
      return null;
    }
    return Tooltip(
      message: 'Regeln nachschlagen',
      child: IconButton(
        key: const ValueKey('workspace-rules-lookup'),
        onPressed: () => showRulesLookupDialog(context: context),
        icon: const Icon(Icons.menu_book_outlined),
      ),
    );
  }

  /// Baut die tab-unabhaengigen Spiel-Aktionen (Probensuche, Regelsuche).
  List<Widget> _buildGlobalPlayActions() {
    final rulesLookup = _buildRulesLookupAction();
    return <Widget>[_buildProbeQuickSearchAction(), ?rulesLookup];
  }

  /// Baut die Aktionsschaltflaechen fuer die AppBar.
  List<Widget> _buildWorkspaceActions({required bool isCompactLayout}) {
    if (_advancementSession != null) {
      return _buildAdvancementActions(isCompactLayout: isCompactLayout);
    }
    return buildWorkspaceManagementActions(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      coordinator: _management,
      compact: isCompactLayout,
      globalActions: _buildGlobalPlayActions(),
      additionalIdleAction: _buildStartAdvancementAction(
        isCompactLayout: isCompactLayout,
      ),
    );
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
      controller: _management.tabController,
      isScrollable: true,
      tabs: _management.visibleTabs
          .map((tab) => Tab(text: tab.label))
          .toList(growable: false),
    );
  }

  /// Baut den TabBarView mit allen aktuell sichtbaren Tab-Widgets.
  Widget _buildWorkspaceTabView() {
    if (_management.visibleTabs.isEmpty) {
      return const Center(child: Text('Keine Bereiche verfügbar.'));
    }

    return TabBarView(
      controller: _management.tabController,
      children: _management.buildTabContents(),
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

  /// Faehrt das Detailpanel aus, damit die Steigerungshistorie sichtbar wird.
  void _expandWorkspaceDetails() {
    setState(() {
      _workspaceDetailsExpanded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hero = ref.watch(heroByIdProvider(widget.heroId));
    final session = ref.watch(advancementSessionProvider(widget.heroId));
    ref.watch(rulesCatalogProvider);
    final layout = appLayoutOf(context);

    if (hero == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Held')),
        body: const Center(child: Text('Held nicht gefunden.')),
      );
    }

    _management.syncHero(hero);
    _scheduleCatalogPrewarmIfNeeded();

    final apple = isApplePlatform(context);
    final hasVisibleTabs = _management.visibleTabs.isNotEmpty;
    final isCompactLayout = layout == AppLayoutClass.compact;
    final useBottomNav =
        session == null && isCompactLayout && apple && hasVisibleTabs;
    final showTabBar =
        session == null && isCompactLayout && !apple && hasVisibleTabs;
    final showInspectorAction =
        layout == AppLayoutClass.tabletPortrait ||
        layout == AppLayoutClass.compact;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _navigateToHomeWithGuard();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            session == null ? hero.name : '${hero.name} · Steigern',
            overflow: TextOverflow.ellipsis,
          ),
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
            if (session == null &&
                !(_management.activeTabId != null &&
                    _management.isEditing(_management.activeTabId!)))
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
                tabs: _management.visibleTabs,
                activeTabIndex: _activeTabIndex(),
                onSelectTab: (index) {
                  if (_management.tabController.index == index) {
                    return;
                  }
                  _management.tabController.animateTo(index);
                },
              )
            : null,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Offstage(
              offstage: session != null,
              child: TickerMode(
                enabled: session == null,
                child: switch (layout) {
                  AppLayoutClass.compact => _buildCompactWorkspaceBody(hero),
                  AppLayoutClass.tabletPortrait =>
                    _buildTabletPortraitWorkspaceBody(hero),
                  AppLayoutClass.tabletLandscape =>
                    _buildTabletLandscapeWorkspaceBody(hero),
                  AppLayoutClass.desktopWide => _buildDesktopWideWorkspaceBody(
                    hero,
                  ),
                },
              ),
            ),
            if (session != null) _buildAdvancementBody(layout),
          ],
        ),
      ),
    );
  }
}
