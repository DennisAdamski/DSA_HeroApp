import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/rules/derived/wund_rules.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/inspector_magie_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/inspector_probe_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/inspector_rast_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/inspector_vitals_tab.dart';
import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';

/// Tab-basierte Inspector-Seitenleiste fuer den Desktop-Workspace.
///
/// Tabs (immer alle vier sichtbar): **Vitals · Magie · Rast · Probe**.
class InspectorPanel extends ConsumerStatefulWidget {
  const InspectorPanel({
    super.key,
    required this.heroId,
    required this.isExpanded,
    this.onToggleExpanded,
  });

  final String heroId;
  final bool isExpanded;
  final VoidCallback? onToggleExpanded;

  @override
  ConsumerState<InspectorPanel> createState() => _InspectorPanelState();
}

class _InspectorPanelState extends ConsumerState<InspectorPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final codex = context.codexTheme;
    final edgeRadius = codex.panelRadius / 2;

    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(edgeRadius),
        bottomLeft: Radius.circular(edgeRadius),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: codex.heroGradientSoft),
        child: SafeArea(
          child: widget.isExpanded
              ? Column(
                  children: [
                    if (widget.onToggleExpanded != null)
                      _InspectorHeader(
                        isExpanded: widget.isExpanded,
                        onToggleExpanded: widget.onToggleExpanded!,
                      ),
                    TabBar(
                      key: const ValueKey<String>('inspector-tab-bar'),
                      controller: _tabController,
                      labelColor: codex.brass,
                      unselectedLabelColor: codex.inkMuted,
                      indicatorColor: codex.brass,
                      tabs: const [
                        Tab(text: 'Vitals'),
                        Tab(text: 'Magie'),
                        Tab(text: 'Rast'),
                        Tab(text: 'Probe'),
                      ],
                    ),
                    Expanded(
                      child: _InspectorTabBodies(
                        heroId: widget.heroId,
                        controller: _tabController,
                      ),
                    ),
                  ],
                )
              : Center(
                  child: _InspectorToggleButton(
                    isExpanded: widget.isExpanded,
                    onPressed: widget.onToggleExpanded,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Kopfzeile fuer den ausgeklappten Inspector mit eindeutiger Toggle-Aktion.
class _InspectorHeader extends StatelessWidget {
  const _InspectorHeader({
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          const Spacer(),
          _InspectorToggleButton(
            isExpanded: isExpanded,
            onPressed: onToggleExpanded,
          ),
        ],
      ),
    );
  }
}

/// Kompakte Seitenleisten-Aktion, die nicht wie ein Drag-Handle wirkt.
class _InspectorToggleButton extends StatelessWidget {
  const _InspectorToggleButton({
    required this.isExpanded,
    required this.onPressed,
  });

  final bool isExpanded;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final codex = context.codexTheme;
    final icon = isExpanded ? Icons.chevron_right : Icons.chevron_left;
    final tooltip = isExpanded ? 'Details ausblenden' : 'Details einblenden';
    return IconButton(
      key: const ValueKey<String>('workspace-details-toggle'),
      tooltip: tooltip,
      style: IconButton.styleFrom(
        foregroundColor: codex.brass,
        backgroundColor: codex.panel.withValues(alpha: 0.72),
        side: BorderSide(color: codex.rule),
      ),
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}

class _InspectorTabBodies extends ConsumerWidget {
  const _InspectorTabBodies({required this.heroId, required this.controller});

  final String heroId;
  final TabController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hero = ref.watch(heroByIdProvider(heroId));
    final heroStateAsync = ref.watch(heroStateProvider(heroId));
    final computedAsync = ref.watch(heroComputedProvider(heroId));

    final heroState = heroStateAsync.valueOrNull;
    final computed = computedAsync.valueOrNull;
    final derived = computed?.derivedStats;
    final combat = computed?.combatPreviewStats;
    final resourceActivation = computed?.resourceActivation;
    final effectiveAttributes = computed?.effectiveAttributes;
    final wundEffekte = computed?.wundEffekte ?? const WundEffekte();
    final wundschwelle = computed?.wundschwelle ?? 0;

    if (hero == null ||
        heroState == null ||
        derived == null ||
        combat == null ||
        effectiveAttributes == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return TabBarView(
      controller: controller,
      children: [
        InspectorVitalsTab(
          heroId: heroId,
          hero: hero,
          heroState: heroState,
          derived: derived,
          combat: combat,
          resourceActivation: resourceActivation,
          wundEffekte: wundEffekte,
          wundschwelle: wundschwelle,
        ),
        InspectorMagieTab(
          heroId: heroId,
          heroState: heroState,
          derived: derived,
          resourceActivation: resourceActivation,
        ),
        InspectorRastTab(
          heroId: heroId,
          heroState: heroState,
          derived: derived,
          resourceActivation: resourceActivation,
        ),
        InspectorProbeTab(
          heroId: heroId,
          heroState: heroState,
          effectiveAttributes: effectiveAttributes,
          combat: combat,
        ),
      ],
    );
  }
}
