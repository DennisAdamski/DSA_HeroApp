import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/combat_config/armor_piece.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_tab_spec.dart';

/// Inspector-Seitenleiste fuer den Desktop-Command-Deck-Modus.
///
/// Zeigt bearbeitbare Ressourcen (LeP, Au, AsP, KaP), direkte Modifikationen
/// (Ini, Ausweichen, AT, PA, MR, GS) sowie eine Ruestungszusammenfassung an.
/// Wird nur im breiten Layout (Command-Deck) neben dem Tab-Inhalt angezeigt.
class WorkspaceInspectorPanel extends ConsumerWidget {
  const WorkspaceInspectorPanel({
    super.key,
    required this.heroId,
    required this.activeTabIndex,
    required this.isEditing,
    required this.isDirty,
  });

  /// ID des aktuell angezeigten Helden.
  final String heroId;

  /// Index des aktuell aktiven Tabs (benoetigt fuer Tab-Metadaten).
  final int activeTabIndex;

  /// Gibt an, ob sich der aktive Tab im Bearbeitungsmodus befindet.
  final bool isEditing;

  /// Gibt an, ob der aktive Tab ungespeicherte Aenderungen hat.
  final bool isDirty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = workspaceTabs[activeTabIndex];
    final stateText = isEditing ? 'Bearbeitungsmodus' : 'Lesemodus';
    final dirtyText = isDirty ? 'Ungespeicherte Aenderungen' : 'Alles gespeichert';

    final hero = ref.watch(heroByIdProvider(heroId));
    final heroStateAsync = ref.watch(heroStateProvider(heroId));
    final computedAsync = ref.watch(heroComputedProvider(heroId));

    final heroState = heroStateAsync.valueOrNull;
    final derived = computedAsync.valueOrNull?.derivedStats;
    final combat = computedAsync.valueOrNull?.combatPreviewStats;

    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Inspector', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              // --- Tab-Info ---
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tab.label,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(tab.helper),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Chip(label: Text(stateText)),
                          Chip(label: Text(dirtyText)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // --- Held ---
              if (hero != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hero.name,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        Text('Level: ${hero.level}'),
                        Text('AP verfuegbar: ${hero.apAvailable}'),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              // --- Ressourcen ---
              if (heroState != null && derived != null)
                _ResourcenCard(
                  heroId: heroId,
                  heroState: heroState,
                  derived: derived,
                ),
              const SizedBox(height: 10),
              // --- Kampfwerte / Modifikationen ---
              if (derived != null && combat != null)
                _KampfwerteCard(derived: derived, combat: combat),
              const SizedBox(height: 10),
              // --- Ruestung ---
              if (hero != null && combat != null)
                _RuestungCard(hero: hero, combat: combat),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ressourcen-Karte: LeP, Au, AsP, KaP (bearbeitbar mit +/- Schaltflaechen)
// ---------------------------------------------------------------------------

class _ResourcenCard extends ConsumerWidget {
  const _ResourcenCard({
    required this.heroId,
    required this.heroState,
    required this.derived,
  });

  final String heroId;
  final HeroState heroState;
  final DerivedStats derived;

  Future<void> _updateState(
    WidgetRef ref,
    HeroState updated,
  ) async {
    await ref.read(heroActionsProvider).saveHeroState(heroId, updated);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ressourcen', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            _ResourceRow(
              label: 'LeP',
              current: heroState.currentLep,
              max: derived.maxLep,
              onDecrement: () => _updateState(
                ref,
                heroState.copyWith(currentLep: heroState.currentLep - 1),
              ),
              onIncrement: () => _updateState(
                ref,
                heroState.copyWith(
                  currentLep: (heroState.currentLep + 1).clamp(
                    heroState.currentLep,
                    derived.maxLep,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            _ResourceRow(
              label: 'Au',
              current: heroState.currentAu,
              max: derived.maxAu,
              onDecrement: () => _updateState(
                ref,
                heroState.copyWith(currentAu: heroState.currentAu - 1),
              ),
              onIncrement: () => _updateState(
                ref,
                heroState.copyWith(
                  currentAu: (heroState.currentAu + 1).clamp(
                    heroState.currentAu,
                    derived.maxAu,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            _ResourceRow(
              label: 'AsP',
              current: heroState.currentAsp,
              max: derived.maxAsp,
              onDecrement: () => _updateState(
                ref,
                heroState.copyWith(currentAsp: heroState.currentAsp - 1),
              ),
              onIncrement: () => _updateState(
                ref,
                heroState.copyWith(
                  currentAsp: (heroState.currentAsp + 1).clamp(
                    heroState.currentAsp,
                    derived.maxAsp,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            _ResourceRow(
              label: 'KaP',
              current: heroState.currentKap,
              max: derived.maxKap,
              onDecrement: () => _updateState(
                ref,
                heroState.copyWith(currentKap: heroState.currentKap - 1),
              ),
              onIncrement: () => _updateState(
                ref,
                heroState.copyWith(
                  currentKap: (heroState.currentKap + 1).clamp(
                    heroState.currentKap,
                    derived.maxKap,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Einzelne Ressourcenzeile mit Bezeichnung, Stepper-Knoepfen und Anzeige.
class _ResourceRow extends StatelessWidget {
  const _ResourceRow({
    required this.label,
    required this.current,
    required this.max,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String label;
  final int current;
  final int max;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLow = max > 0 && current <= (max / 3).ceil();

    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          width: 28,
          height: 28,
          child: IconButton.outlined(
            padding: EdgeInsets.zero,
            iconSize: 14,
            icon: const Icon(Icons.remove),
            tooltip: '$label verringern',
            onPressed: onDecrement,
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 44,
          child: Text(
            '$current',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isLow ? colorScheme.error : null,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Text(
          '/ $max',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 28,
          height: 28,
          child: IconButton.outlined(
            padding: EdgeInsets.zero,
            iconSize: 14,
            icon: const Icon(Icons.add),
            tooltip: '$label erhoehen',
            onPressed: current < max ? onIncrement : null,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Kampfwerte-Karte: Ini, Ausweichen, AT, PA, MR, GS (nur Anzeige)
// ---------------------------------------------------------------------------

class _KampfwerteCard extends StatelessWidget {
  const _KampfwerteCard({required this.derived, required this.combat});

  final DerivedStats derived;
  final CombatPreviewStats combat;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kampfwerte',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
            _StatRow(label: 'Initiative', value: combat.initiative.toString()),
            _StatRow(label: 'Ausweichen', value: combat.ausweichen.toString()),
            _StatRow(label: 'AT-Basis', value: derived.atBase.toString()),
            _StatRow(label: 'PA-Basis', value: derived.paBase.toString()),
            _StatRow(label: 'MR', value: derived.mr.toString()),
            _StatRow(label: 'GS', value: derived.gs.toString()),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ruestungs-Karte: RS, BE, aktive Stuecke (nur Anzeige)
// ---------------------------------------------------------------------------

class _RuestungCard extends StatelessWidget {
  const _RuestungCard({required this.hero, required this.combat});

  final HeroSheet hero;
  final CombatPreviewStats combat;

  @override
  Widget build(BuildContext context) {
    final armorPieces = hero.combatConfig.armor.pieces
        .where((ArmorPiece p) => p.isActive)
        .toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ruestung', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            _StatRow(label: 'RS gesamt', value: combat.rsTotal.toString()),
            _StatRow(label: 'BE (Kampf)', value: combat.beKampf.toString()),
            if (armorPieces.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Angelegte Stuecke:',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              for (final ArmorPiece piece in armorPieces)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          piece.name,
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'RS ${piece.rs}  BE ${piece.be}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
            ] else
              Text(
                'Keine Ruestung angelegt',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hilfswidget: Bezeichnung + Wert in einer Zeile
// ---------------------------------------------------------------------------

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
