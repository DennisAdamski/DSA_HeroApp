part of 'package:dsa_heldenverwaltung/ui/screens/hero_workspace_screen.dart';

/// Breite der eingeklappten Command-Deck-Rail auf Tablet und Desktop.
const double _commandDeckCollapsedWidth = 64;

/// Breite des ausgefahrenen Command-Decks im iPad-Landscape-Layout.
const double _tabletLandscapeCommandDeckWidth = 200;

/// Breite des ausgefahrenen Command-Decks auf sehr breiten Screens.
const double _desktopWideCommandDeckWidth = 248;

/// Standardbreite des permanenten Inspectors im iPad-Landscape-Layout.
const double _tabletLandscapeInspectorWidth = 220;

/// Standardbreite des permanenten Inspectors auf sehr breiten Screens.
const double _desktopWideInspectorWidth = 320;

/// Eingeklappte Breite des rechten Inspectors auf sehr breiten Screens.
const double _desktopWideInspectorCollapsedWidth = 64;

extension _HeroWorkspaceLayoutX on _HeroWorkspaceScreenState {
  /// Liefert den aktiven Inhaltsbereich als ruhigen digitalen Heldenbogen.
  Widget _buildWorkspaceContentShell(
    HeroSheet hero, {
    required AppLayoutClass layout,
  }) {
    final activeTab = _activeTabSpec();
    final showTabletDesktopHeader =
        layout != AppLayoutClass.compact && activeTab != null;
    return CodexPageScaffold(
      child: Column(
        children: [
          if (showTabletDesktopHeader)
            WorkspaceHeroHeader(
              heroId: widget.heroId,
              hero: hero,
            ),
          if (!showTabletDesktopHeader)
            WorkspaceCoreAttributesHeader(heroId: widget.heroId, hero: hero),
          Expanded(child: _buildWorkspaceTabView()),
        ],
      ),
    );
  }

  /// Liefert den aktuellen Expansionszustand des Command-Decks je Layout.
  bool _isHeroDeckExpandedFor(AppLayoutClass layout) {
    if (!_heroDeckManualPreference &&
        layout == AppLayoutClass.tabletLandscape) {
      return true;
    }
    return _heroDeckExpanded;
  }

  /// Klassisches Smartphone-Layout ohne permanente Seitenleisten.
  Widget _buildCompactWorkspaceBody(HeroSheet hero) {
    return _buildWorkspaceContentShell(hero, layout: AppLayoutClass.compact);
  }

  /// Tablet-Portrait: Icon-Rail links, Fokusinhalt mittig.
  Widget _buildTabletPortraitWorkspaceBody(HeroSheet hero) {
    final activeTabIndex = _activeTabIndex();
    return CodexSplitView(
      railWidth: _commandDeckCollapsedWidth,
      rail: WorkspaceCommandDeckNavigationPanel(
        tabs: _visibleTabs,
        activeTabIndex: activeTabIndex,
        isExpanded: false,
        isDirty: _tabRegistry.isDirty,
        onToggleExpanded: null,
        onSelectTab: (index) {
          if (_tabController.index == index) {
            return;
          }
          _tabController.animateTo(index);
        },
      ),
      primary: _buildWorkspaceContentShell(
        hero,
        layout: AppLayoutClass.tabletPortrait,
      ),
    );
  }

  /// Tablet-Landscape: ausgeklapptes Command-Deck plus permanenter Inspector.
  Widget _buildTabletLandscapeWorkspaceBody(HeroSheet hero) {
    final activeTabIndex = _activeTabIndex();
    final heroDeckExpanded = _isHeroDeckExpandedFor(
      AppLayoutClass.tabletLandscape,
    );
    final navigationWidth = heroDeckExpanded
        ? _tabletLandscapeCommandDeckWidth
        : _commandDeckCollapsedWidth;
    return CodexSplitView(
      railWidth: navigationWidth,
      rail: WorkspaceCommandDeckNavigationPanel(
        tabs: _visibleTabs,
        activeTabIndex: activeTabIndex,
        isExpanded: heroDeckExpanded,
        isDirty: _tabRegistry.isDirty,
        onToggleExpanded: () =>
            _toggleHeroDeckExpanded(AppLayoutClass.tabletLandscape),
        onSelectTab: (index) {
          if (_tabController.index == index) {
            return;
          }
          _tabController.animateTo(index);
        },
      ),
      primary: _buildWorkspaceContentShell(
        hero,
        layout: AppLayoutClass.tabletLandscape,
      ),
      secondaryWidth: _tabletLandscapeInspectorWidth,
      secondary: WorkspaceInspectorPanel(
        heroId: widget.heroId,
        isExpanded: true,
      ),
    );
  }

  /// Sehr breites Layout mit zuschaltbarem Inspector.
  Widget _buildDesktopWideWorkspaceBody(HeroSheet hero) {
    final activeTabIndex = _activeTabIndex();
    final heroDeckExpanded = _isHeroDeckExpandedFor(AppLayoutClass.desktopWide);
    final navigationWidth = heroDeckExpanded
        ? _desktopWideCommandDeckWidth
        : _commandDeckCollapsedWidth;
    final detailsWidth = _workspaceDetailsExpanded
        ? _desktopWideInspectorWidth
        : _desktopWideInspectorCollapsedWidth;
    return CodexSplitView(
      railWidth: navigationWidth,
      rail: WorkspaceCommandDeckNavigationPanel(
        tabs: _visibleTabs,
        activeTabIndex: activeTabIndex,
        isExpanded: heroDeckExpanded,
        isDirty: _tabRegistry.isDirty,
        onToggleExpanded: () =>
            _toggleHeroDeckExpanded(AppLayoutClass.desktopWide),
        onSelectTab: (index) {
          if (_tabController.index == index) {
            return;
          }
          _tabController.animateTo(index);
        },
      ),
      primary: _buildWorkspaceContentShell(
        hero,
        layout: AppLayoutClass.desktopWide,
      ),
      secondaryWidth: detailsWidth,
      secondary: WorkspaceInspectorPanel(
        heroId: widget.heroId,
        isExpanded: _workspaceDetailsExpanded,
        onToggleExpanded: _toggleWorkspaceDetailsExpanded,
      ),
    );
  }

  /// Zeigt den Inspector auf iPad Portrait als grosses Detail-Sheet.
  void _showInspectorSheet() {
    showAdaptiveDetailSheet<void>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(18),
        child: WorkspaceInspectorPanel(
          heroId: widget.heroId,
          isExpanded: true,
          onToggleExpanded: () => Navigator.of(sheetContext).pop(),
        ),
      ),
    );
  }
}
