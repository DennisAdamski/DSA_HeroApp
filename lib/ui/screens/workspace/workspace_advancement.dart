part of 'package:dsa_heldenverwaltung/ui/screens/hero_workspace_screen.dart';

/// Verbindet die eigenständige Steigerungsrunde mit Workspace und Navigation.
extension _WorkspaceAdvancement on _HeroWorkspaceScreenState {
  /// Aktuelle Runde ohne zusätzliche Listener in Aktions-Callbacks.
  AdvancementSession? get _advancementSession =>
      ref.read(advancementSessionProvider(widget.heroId));

  /// Bietet Steigern getrennt von der tabbezogenen manuellen Bearbeitung an.
  Widget _buildStartAdvancementAction({required bool isCompactLayout}) {
    final catalog = ref.read(rulesCatalogProvider).valueOrNull;
    final onPressed = catalog == null || _runningEditAction
        ? null
        : () => _runEditAction(_startAdvancement);
    if (isCompactLayout) {
      return IconButton(
        key: const ValueKey('workspace-start-advancement'),
        tooltip: 'Steigern',
        onPressed: onPressed,
        icon: const Icon(Icons.trending_up),
      );
    }
    return OutlinedButton.icon(
      key: const ValueKey('workspace-start-advancement'),
      onPressed: onPressed,
      icon: const Icon(Icons.trending_up),
      label: const Text('Steigern'),
    );
  }

  /// Beendet alte Tab-Entwürfe über ihren bestehenden Guard, dann startet die Runde.
  Future<void> _startAdvancement() async {
    for (final tab in _visibleTabs) {
      if (!await _confirmLeaveForTab(tab.id) || !mounted) return;
      if (_tabRegistry.isEditing(tab.id)) {
        await _tabRegistry.editActionsFor(tab.id)?.cancel();
      }
    }
    if (!mounted) return;
    final hero = ref.read(heroByIdProvider(widget.heroId));
    final catalog = ref.read(rulesCatalogProvider).valueOrNull;
    if (hero == null || catalog == null) return;
    ref
        .read(advancementSessionProvider(widget.heroId).notifier)
        .start(hero: hero, catalog: catalog);
    _expandWorkspaceDetails();
  }

  /// Zeigt während der Runde ausschließlich ihre Abschlussaktionen.
  List<Widget> _buildAdvancementActions({required bool isCompactLayout}) {
    final session = _advancementSession!;
    final cancel = session.isSaving ? null : () => _confirmLeaveAdvancement();
    final commit = session.canCommit ? () => _commitAdvancement() : null;
    if (isCompactLayout) {
      return [
        IconButton(
          key: const ValueKey('workspace-cancel-advancement'),
          tooltip: 'Steigerungsrunde verlassen',
          onPressed: cancel,
          icon: const Icon(Icons.close),
        ),
        IconButton(
          key: const ValueKey('workspace-commit-advancement'),
          tooltip: 'Änderungen übernehmen',
          onPressed: commit,
          icon: const Icon(Icons.check),
        ),
      ];
    }
    return [
      OutlinedButton(
        key: const ValueKey('workspace-cancel-advancement'),
        onPressed: cancel,
        child: const Text('Abbrechen'),
      ),
      FilledButton.icon(
        key: const ValueKey('workspace-commit-advancement'),
        onPressed: commit,
        icon: session.isSaving
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.check),
        label: const Text('Änderungen übernehmen'),
      ),
    ];
  }

  /// Verwendet dieselbe Historie als feste Seitenleiste und im mobilen Detailpanel.
  Widget _buildAdvancementBody(AppLayoutClass layout) {
    final content = AdvancementCatalog(heroId: widget.heroId);
    final wide = layout == AppLayoutClass.desktopWide;
    if (!wide && layout != AppLayoutClass.tabletLandscape) return content;
    final expanded = !wide || _workspaceDetailsExpanded;
    final width = !expanded
        ? _desktopWideInspectorCollapsedWidth
        : wide
        ? _desktopWideInspectorWidth
        : _tabletLandscapeInspectorWidth;
    return Row(
      children: [
        Expanded(child: content),
        SizedBox(
          width: width,
          child: WorkspaceInspectorPanel(
            heroId: widget.heroId,
            isExpanded: expanded,
            onToggleExpanded: wide ? _toggleWorkspaceDetailsExpanded : null,
          ),
        ),
      ],
    );
  }

  /// Führt die einzige verbindliche Buchung aus und lässt Fehler im Entwurf.
  Future<bool> _commitAdvancement() async {
    try {
      await ref
          .read(advancementSessionProvider(widget.heroId).notifier)
          .commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Steigerungen übernommen.')),
        );
      }
      return true;
    } catch (error) {
      if (mounted) {
        final message = error is StateError ? error.message : '$error';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
      return false;
    }
  }

  /// Schützt geplante Einträge beim Abbrechen und beim Verlassen des Helden.
  Future<bool> _confirmLeaveAdvancement() async {
    final session = _advancementSession;
    if (session == null) return true;
    if (session.isSaving) return false;
    final controller = ref.read(
      advancementSessionProvider(widget.heroId).notifier,
    );
    if (session.entries.isEmpty) {
      controller.discard();
      return true;
    }
    final result = await showAdaptiveConfirmDialog(
      context: context,
      title: 'Steigerungsrunde verlassen?',
      content:
          'Die geplanten Steigerungen sind noch nicht gespeichert. '
          'Du kannst weiter planen, die Runde verwerfen oder gemeinsam übernehmen.',
      cancelLabel: 'Weiter planen',
      confirmLabel: 'Verwerfen',
      saveLabel: session.canCommit ? 'Änderungen übernehmen' : null,
      isDestructive: true,
    );
    if (!mounted || result == AdaptiveConfirmResult.cancel) return false;
    if (result == AdaptiveConfirmResult.save) return _commitAdvancement();
    controller.discard();
    return true;
  }
}
