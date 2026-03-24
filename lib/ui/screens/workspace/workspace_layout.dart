part of 'package:dsa_heldenverwaltung/ui/screens/hero_workspace_screen.dart';

/// Layout-Stufen fuer den Workspace je nach verfuegbarer Breite.
enum WorkspaceLayout {
  /// iPhone / schmales Fenster (< 744dp): TabBar oder Bottom Nav.
  compact,

  /// iPad Portrait / mittelbreit (744-1023dp): Collapsed Sidebar + Content.
  medium,

  /// iPad Landscape / breit (1024-1279dp): Ausgeklappte Sidebar + Content.
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

extension _HeroWorkspaceLayoutX on _HeroWorkspaceScreenState {
  /// Klassisches Layout: Attribut-Header oben, darunter der Tab-Inhalt.
  Widget _buildClassicWorkspaceBody(HeroSheet hero) {
    return CodexPageScaffold(
      child: Column(
        children: [
          WorkspaceCoreAttributesHeader(heroId: widget.heroId, hero: hero),
          Expanded(child: _buildWorkspaceTabView()),
        ],
      ),
    );
  }

  /// Helden-Deck-Layout: Navigation links, Inhalt mittig, Detailpanel rechts.
  Widget _buildHeroDeckWorkspaceBody(HeroSheet hero) {
    final activeTabIndex = _activeTabIndex();
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
            tabs: _visibleTabs,
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
          child: CodexPageScaffold(
            child: Column(
              children: [
                WorkspaceCoreAttributesHeader(
                  heroId: widget.heroId,
                  hero: hero,
                ),
                Expanded(child: _buildWorkspaceTabView()),
              ],
            ),
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
    if (width >= kHeroDeckBreakpoint) {
      return WorkspaceLayout.heroDeck;
    }
    if (width >= kTabletBreakpoint) {
      return WorkspaceLayout.expanded;
    }
    if (width >= kMediumBreakpoint) {
      return WorkspaceLayout.medium;
    }
    return WorkspaceLayout.compact;
  }

  /// Medium-Layout: Collapsed Sidebar (Icon-only) + Content-Bereich.
  Widget _buildMediumWorkspaceBody(HeroSheet hero) {
    final activeTabIndex = _activeTabIndex();
    return Row(
      children: [
        SizedBox(
          width: _heroDeckCollapsedWidth,
          child: WorkspaceCommandDeckNavigationPanel(
            tabs: _visibleTabs,
            activeTabIndex: activeTabIndex,
            isExpanded: false,
            isDirty: _tabRegistry.isDirty,
            onToggleExpanded: () {},
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
          child: CodexPageScaffold(
            child: Column(
              children: [
                WorkspaceCoreAttributesHeader(
                  heroId: widget.heroId,
                  hero: hero,
                ),
                Expanded(child: _buildWorkspaceTabView()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Expanded-Layout: ausgeklappte Sidebar + Content, kein Inspector.
  Widget _buildExpandedWorkspaceBody(HeroSheet hero) {
    final activeTabIndex = _activeTabIndex();
    final navigationWidth = _heroDeckExpanded
        ? _heroDeckNavigationWidth
        : _heroDeckCollapsedWidth;
    return Row(
      children: [
        SizedBox(
          width: navigationWidth,
          child: WorkspaceCommandDeckNavigationPanel(
            tabs: _visibleTabs,
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
          child: CodexPageScaffold(
            child: Column(
              children: [
                WorkspaceCoreAttributesHeader(
                  heroId: widget.heroId,
                  hero: hero,
                ),
                Expanded(child: _buildWorkspaceTabView()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Zeigt den Inspector als BottomSheet fuer Medium/Expanded ohne Spalte.
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
        builder: (sheetContext, scrollController) => WorkspaceInspectorPanel(
          heroId: widget.heroId,
          isExpanded: true,
          onToggleExpanded: () => Navigator.of(sheetContext).pop(),
        ),
      ),
    );
  }
}
