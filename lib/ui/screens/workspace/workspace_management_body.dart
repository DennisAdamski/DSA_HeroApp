import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/rules_lookup_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_management_coordinator.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';

/// Zeigt die bestehende Heldenverwaltung ohne äußere Navigation und Inspector.
class WorkspaceManagementBody extends ConsumerStatefulWidget {
  /// Erstellt die Verwaltungsfläche und meldet ihren aktuellen Leave-Guard.
  const WorkspaceManagementBody({
    super.key,
    required this.heroId,
    required this.korrekturenGesperrt,
    required this.onVerlassenRegistriert,
  });

  /// ID des verwalteten Helden.
  final String heroId;

  /// Sperrt alle Änderungen am Heldenbogen während einer Planung.
  final bool korrekturenGesperrt;

  /// Registriert den Guard für Wechsel aus der Verwaltungsfläche.
  final ValueChanged<KartoVerlassenPruefung?> onVerlassenRegistriert;

  /// Erstellt den Zustand für Koordination und Guard-Registrierung.
  @override
  ConsumerState<WorkspaceManagementBody> createState() {
    return _WorkspaceManagementBodyState();
  }
}

class _WorkspaceManagementBodyState
    extends ConsumerState<WorkspaceManagementBody>
    with TickerProviderStateMixin {
  late final WorkspaceManagementCoordinator _coordinator;

  @override
  void initState() {
    super.initState();
    _coordinator = WorkspaceManagementCoordinator(
      heroId: widget.heroId,
      vsync: this,
      contextProvider: () => context,
      hostIsMounted: () => mounted,
    );
    _coordinator.addListener(_rebuild);
    widget.onVerlassenRegistriert(_coordinator.confirmLeave);
  }

  @override
  void didUpdateWidget(covariant WorkspaceManagementBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onVerlassenRegistriert != widget.onVerlassenRegistriert) {
      oldWidget.onVerlassenRegistriert(null);
      widget.onVerlassenRegistriert(_coordinator.confirmLeave);
    }
  }

  void _rebuild() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.onVerlassenRegistriert(null);
    _coordinator.removeListener(_rebuild);
    _coordinator.dispose();
    super.dispose();
  }

  /// Baut Sperr-, Lade-, Fehler- oder Verwaltungszustand des Helden.
  @override
  Widget build(BuildContext context) {
    if (widget.korrekturenGesperrt) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Während einer offenen Entwicklung sind Korrekturen am '
            'Heldenbogen gesperrt. Wechsle zur Entwicklung, um die Planung '
            'fortzusetzen, zu übernehmen oder zu verwerfen.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final index = ref.watch(heroIndexProvider);
    final snapshot = index.valueOrNull;
    if (index.hasError) {
      return const Center(
        child: Text('Heldenverwaltung konnte nicht geladen werden.'),
      );
    }
    if (snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final hero = snapshot.byId[widget.heroId];
    if (hero == null) return const Center(child: Text('Held nicht gefunden.'));
    _coordinator.syncHero(hero);
    if (_coordinator.visibleTabs.isEmpty) {
      return const Center(child: Text('Keine Bereiche verfügbar.'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 744;
        final actions = buildWorkspaceManagementActions(
          context: context,
          ref: ref,
          heroId: widget.heroId,
          coordinator: _coordinator,
          compact: compact,
          globalActions: _buildGlobalActions(),
        );
        return Column(
          children: <Widget>[
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: _ManagementHeader(
                coordinator: _coordinator,
                compact: compact,
                actions: actions,
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _coordinator.tabController,
                children: _coordinator.buildTabContents(),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildGlobalActions() {
    if (!isRulesLookupSupported()) {
      return const <Widget>[];
    }
    return <Widget>[
      IconButton(
        key: const ValueKey<String>('management-rules-lookup'),
        tooltip: 'Regeln nachschlagen',
        onPressed: () => showRulesLookupDialog(context: context),
        icon: const Icon(Icons.menu_book_outlined),
      ),
    ];
  }
}

class _ManagementHeader extends StatelessWidget {
  const _ManagementHeader({
    required this.coordinator,
    required this.compact,
    required this.actions,
  });

  final WorkspaceManagementCoordinator coordinator;
  final bool compact;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final activeTab = coordinator.activeTab;
    final tabs = TabBar(
      controller: coordinator.tabController,
      isScrollable: true,
      tabs: coordinator.visibleTabs
          .map((tab) => Tab(text: tab.label))
          .toList(growable: false),
    );
    final actionRow = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(children: <Widget>[...actions, const SizedBox(width: 8)]),
    );
    final heading = activeTab == null
        ? const SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                activeTab.label,
                key: const ValueKey<String>('management-active-title'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                activeTab.helper,
                key: const ValueKey<String>('management-active-helper'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: heading,
          ),
          if (actions.isNotEmpty) ...<Widget>[
            Align(alignment: Alignment.centerRight, child: actionRow),
            const SizedBox(height: 4),
          ],
          tabs,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(child: heading),
              if (actions.isNotEmpty) Flexible(child: actionRow),
            ],
          ),
        ),
        tabs,
      ],
    );
  }
}

/// Baut die gemeinsamen Editor- und Abschnittsaktionen der Verwaltung.
List<Widget> buildWorkspaceManagementActions({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required WorkspaceManagementCoordinator coordinator,
  required bool compact,
  List<Widget> globalActions = const <Widget>[],
  Widget? additionalIdleAction,
}) {
  final activeTab = coordinator.activeTab;
  if (activeTab == null) {
    return globalActions;
  }
  final tabId = activeTab.id;
  final isEditing = coordinator.isEditing(tabId);
  final tabActions = coordinator.editActionsFor(tabId);
  final widgets = <Widget>[];
  if (!isEditing) {
    widgets.addAll(globalActions);
    if (additionalIdleAction != null) {
      widgets.add(additionalIdleAction);
    }
  }
  final headerActions = <WorkspaceHeaderAction>[
    ...activeTab.buildHeaderActions(
      context: context,
      ref: ref,
      heroId: heroId,
      isCompactLayout: compact,
    ),
    ...(tabActions?.headerActions ?? const <WorkspaceHeaderAction>[]),
  ];
  for (final action in headerActions) {
    final visible = isEditing ? action.showWhenEditing : action.showWhenIdle;
    if (visible) {
      widgets.add(action.builder(context));
    }
  }

  final enabled = !coordinator.isRunningEditAction && tabActions != null;
  if (isEditing) {
    widgets.addAll(
      _buildEditingActions(
        coordinator: coordinator,
        actions: tabActions,
        enabled: enabled,
        compact: compact,
      ),
    );
  } else if (coordinator.isEditableTab(tabId)) {
    widgets.add(
      _buildStartEditingAction(
        coordinator: coordinator,
        actions: tabActions,
        enabled: enabled,
        compact: compact,
      ),
    );
  }
  return widgets;
}

Widget _buildStartEditingAction({
  required WorkspaceManagementCoordinator coordinator,
  required WorkspaceTabEditActions? actions,
  required bool enabled,
  required bool compact,
}) {
  final onPressed = enabled
      ? () => coordinator.runEditAction(actions?.startEdit)
      : null;
  if (compact) {
    return IconButton(
      tooltip: 'Bearbeiten',
      onPressed: onPressed,
      icon: const Icon(Icons.edit),
    );
  }
  return FilledButton.icon(
    onPressed: onPressed,
    icon: const Icon(Icons.edit),
    label: const Text('Bearbeiten'),
  );
}

List<Widget> _buildEditingActions({
  required WorkspaceManagementCoordinator coordinator,
  required WorkspaceTabEditActions? actions,
  required bool enabled,
  required bool compact,
}) {
  final cancel = enabled
      ? () => coordinator.runEditAction(actions?.cancel)
      : null;
  final save = enabled ? () => coordinator.runEditAction(actions?.save) : null;
  if (compact) {
    return <Widget>[
      IconButton(
        tooltip: 'Abbrechen',
        onPressed: cancel,
        icon: const Icon(Icons.close),
      ),
      IconButton(
        tooltip: 'Speichern',
        onPressed: save,
        icon: const Icon(Icons.check),
      ),
    ];
  }
  return <Widget>[
    OutlinedButton(onPressed: cancel, child: const Text('Abbrechen')),
    FilledButton(onPressed: save, child: const Text('Speichern')),
  ];
}
