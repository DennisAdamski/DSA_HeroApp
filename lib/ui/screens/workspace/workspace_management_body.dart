import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/rules_lookup_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_management_coordinator.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_breakpoints.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_stroke.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_ornamente.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_seitenkopf.dart';

/// Zeigt die bestehende Heldenverwaltung ohne äußere Navigation und Inspector.
///
/// Nur die neue Oberfläche benutzt diesen Körper; sein Kopf ist deshalb der
/// Kartograph-Seitenkopf, und die Fläche bleibt durchsichtig, damit das Papier
/// des Arbeitsbereichs durchscheint. Tabs und Bearbeitung kommen unverändert
/// aus dem gemeinsamen [WorkspaceManagementCoordinator].
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
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Abstand.bahn),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Breite.lesespalte),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const KartoKompassrose(groesse: 96),
                const SizedBox(height: Abstand.block),
                Text(
                  'Während einer offenen Entwicklung sind Korrekturen am '
                  'Heldenbogen gesperrt. Wechsle zur Entwicklung, um die '
                  'Planung fortzusetzen, zu übernehmen oder zu verwerfen.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.fliess,
                ),
              ],
            ),
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
        final rand = kartoBreiteFuer(constraints.maxWidth).seitenrand;
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
            // Durchsichtig: das Papier des Arbeitsbereichs traegt den Grund.
            Material(
              type: MaterialType.transparency,
              child: _ManagementHeader(
                coordinator: _coordinator,
                compact: compact,
                rand: rand,
                actions: actions,
              ),
            ),
            Expanded(
              child: Padding(
                // Die Tabs bringen eigenen Innenabstand mit; zusammen stehen
                // sie so buendig unter dem Seitenkopf.
                padding: EdgeInsets.symmetric(
                  horizontal: (rand - Abstand.weit).clamp(0, rand),
                ),
                child: TabBarView(
                  controller: _coordinator.tabController,
                  children: _coordinator.buildTabContents(),
                ),
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
    required this.rand,
    required this.actions,
  });

  final WorkspaceManagementCoordinator coordinator;
  final bool compact;
  final double rand;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final activeTab = coordinator.activeTab;
    final token = KartoTheme.of(context);
    final texte = Theme.of(context).textTheme;
    // Die oberste Ebene setzt Unterstrich und Schrift ausdruecklich; die
    // verschachtelten Reiter der Tabs nehmen die ruhigere Pille aus dem
    // Feinschliff und bleiben so als zweite Ebene erkennbar.
    final tabs = TabBar(
      controller: coordinator.tabController,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      padding: EdgeInsets.symmetric(horizontal: rand - Abstand.weit),
      labelPadding: const EdgeInsets.symmetric(horizontal: Abstand.weit),
      labelColor: token.schrift,
      unselectedLabelColor: token.schriftLeise,
      labelStyle: texte.labelLarge?.copyWith(color: token.schrift),
      unselectedLabelStyle: texte.labelLarge?.copyWith(
        color: token.schriftLeise,
      ),
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: token.meer, width: Strich.ufer),
      ),
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: token.hoehenlinie,
      tabs: coordinator.visibleTabs
          .map((tab) => Tab(text: tab.label))
          .toList(growable: false),
    );
    final actionRow = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var i = 0; i < actions.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: Abstand.normal),
            actions[i],
          ],
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(
            rand,
            compact ? Abstand.block : Abstand.bahn,
            rand,
            0,
          ),
          child: activeTab == null
              ? const SizedBox.shrink()
              : KartoSeitenkopf(
                  // Schmal wird jede Zeile ueber den Reitern gebraucht.
                  kontext: compact ? null : 'Heldenbogen',
                  titel: activeTab.label,
                  unterzeile: activeTab.helper,
                  kompakt: compact,
                  titelSchluessel: const ValueKey<String>(
                    'management-active-title',
                  ),
                  unterzeileSchluessel: const ValueKey<String>(
                    'management-active-helper',
                  ),
                  aktion: actions.isEmpty ? null : actionRow,
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
