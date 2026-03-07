import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/combat_config/armor_piece.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';

/// Inspector-Seitenleiste fuer den Desktop-Command-Deck-Modus.
///
/// Zeigt bearbeitbare Ressourcen (LeP, Au, AsP, KaP), einen manuellen
/// BE-Override, direkte Modifikationen (Ini, GS, Ausweichen, PA, AT, RS)
/// sowie eine Ruestungszusammenfassung. Wird nur im breiten Layout
/// (>= 1280dp) neben dem Tab-Inhalt angezeigt.
class WorkspaceInspectorPanel extends ConsumerWidget {
  const WorkspaceInspectorPanel({super.key, required this.heroId});

  final String heroId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              // --- Held ---
              if (hero != null)
                _HeldCard(hero: hero),
              const SizedBox(height: 10),
              // --- Ressourcen ---
              if (heroState != null && derived != null)
                _ResourcenCard(
                  heroId: heroId,
                  heroState: heroState,
                  derived: derived,
                ),
              const SizedBox(height: 10),
              // --- Manueller BE ---
              _ManuellerBeCard(heroId: heroId, combat: combat),
              const SizedBox(height: 10),
              // --- Modifikationen ---
              if (hero != null)
                _ModifikationenCard(heroId: heroId, hero: hero),
              const SizedBox(height: 10),
              // --- Kampfwerte (berechnet) ---
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
// Held-Karte
// ---------------------------------------------------------------------------

class _HeldCard extends StatelessWidget {
  const _HeldCard({required this.hero});

  final HeroSheet hero;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(hero.name, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text('Level: ${hero.level}'),
            Text('AP verfuegbar: ${hero.apAvailable}'),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ressourcen-Karte: LeP, Au, AsP, KaP (bearbeitbar mit +/-)
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

  Future<void> _save(WidgetRef ref, HeroState updated) async {
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
              onDecrement: () => _save(
                ref,
                heroState.copyWith(currentLep: heroState.currentLep - 1),
              ),
              onIncrement: () => _save(
                ref,
                heroState.copyWith(currentLep: heroState.currentLep + 1),
              ),
            ),
            const SizedBox(height: 6),
            _ResourceRow(
              label: 'Au',
              current: heroState.currentAu,
              max: derived.maxAu,
              onDecrement: () => _save(
                ref,
                heroState.copyWith(currentAu: heroState.currentAu - 1),
              ),
              onIncrement: () => _save(
                ref,
                heroState.copyWith(currentAu: heroState.currentAu + 1),
              ),
            ),
            const SizedBox(height: 6),
            _ResourceRow(
              label: 'AsP',
              current: heroState.currentAsp,
              max: derived.maxAsp,
              onDecrement: () => _save(
                ref,
                heroState.copyWith(currentAsp: heroState.currentAsp - 1),
              ),
              onIncrement: () => _save(
                ref,
                heroState.copyWith(currentAsp: heroState.currentAsp + 1),
              ),
            ),
            const SizedBox(height: 6),
            _ResourceRow(
              label: 'KaP',
              current: heroState.currentKap,
              max: derived.maxKap,
              onDecrement: () => _save(
                ref,
                heroState.copyWith(currentKap: heroState.currentKap - 1),
              ),
              onIncrement: () => _save(
                ref,
                heroState.copyWith(currentKap: heroState.currentKap + 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ressourcenzeile: Label | – | Wert / Max | +
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
    final isLow = max > 0 && current <= (max / 3).ceil();
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        _StepButton(icon: Icons.remove, tooltip: '$label verringern', onPressed: onDecrement),
        const SizedBox(width: 4),
        SizedBox(
          width: 44,
          child: Text(
            '$current',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isLow ? Theme.of(context).colorScheme.error : null,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Text(
          '/ $max',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 4),
        _StepButton(
          icon: Icons.add,
          tooltip: '$label erhoehen',
          onPressed: current < max ? onIncrement : null,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Manueller BE-Override (laufzeitseitig, nicht persistiert)
// ---------------------------------------------------------------------------

class _ManuellerBeCard extends ConsumerWidget {
  const _ManuellerBeCard({required this.heroId, required this.combat});

  final String heroId;
  final CombatPreviewStats? combat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final override = ref.watch(talentBeOverrideProvider(heroId));
    final displayed = override ?? (combat?.beKampf ?? 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manueller BE',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _StepButton(
                  icon: Icons.remove,
                  tooltip: 'BE verringern',
                  onPressed: () {
                    ref.read(talentBeOverrideProvider(heroId).notifier).state =
                        displayed - 1;
                  },
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 44,
                  child: Text(
                    '$displayed',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 4),
                _StepButton(
                  icon: Icons.add,
                  tooltip: 'BE erhoehen',
                  onPressed: () {
                    ref.read(talentBeOverrideProvider(heroId).notifier).state =
                        displayed + 1;
                  },
                ),
                const SizedBox(width: 8),
                if (override != null)
                  TextButton.icon(
                    onPressed: () {
                      ref
                          .read(talentBeOverrideProvider(heroId).notifier)
                          .state = null;
                    },
                    icon: const Icon(Icons.clear, size: 14),
                    label: const Text('Entfernen'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                  ),
                if (override == null)
                  Text(
                    '(berechnet)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Modifikationen: Ini, GS, Ausweichen, PA, AT, RS (aus persistentMods)
// ---------------------------------------------------------------------------

class _ModifikationenCard extends ConsumerWidget {
  const _ModifikationenCard({required this.heroId, required this.hero});

  final String heroId;
  final HeroSheet hero;

  Future<void> _saveMods(WidgetRef ref, StatModifiers mods) async {
    await ref
        .read(heroActionsProvider)
        .saveHero(hero.copyWith(persistentMods: mods));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mods = hero.persistentMods;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Modifikationen',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
            _ModRow(
              label: 'Ini',
              value: mods.iniBase,
              onDecrement: () => _saveMods(
                ref,
                mods.copyWith(iniBase: mods.iniBase - 1),
              ),
              onIncrement: () => _saveMods(
                ref,
                mods.copyWith(iniBase: mods.iniBase + 1),
              ),
            ),
            const SizedBox(height: 6),
            _ModRow(
              label: 'GS',
              value: mods.gs,
              onDecrement: () =>
                  _saveMods(ref, mods.copyWith(gs: mods.gs - 1)),
              onIncrement: () =>
                  _saveMods(ref, mods.copyWith(gs: mods.gs + 1)),
            ),
            const SizedBox(height: 6),
            _ModRow(
              label: 'AW',
              value: mods.ausweichen,
              onDecrement: () => _saveMods(
                ref,
                mods.copyWith(ausweichen: mods.ausweichen - 1),
              ),
              onIncrement: () => _saveMods(
                ref,
                mods.copyWith(ausweichen: mods.ausweichen + 1),
              ),
            ),
            const SizedBox(height: 6),
            _ModRow(
              label: 'PA',
              value: mods.pa,
              onDecrement: () =>
                  _saveMods(ref, mods.copyWith(pa: mods.pa - 1)),
              onIncrement: () =>
                  _saveMods(ref, mods.copyWith(pa: mods.pa + 1)),
            ),
            const SizedBox(height: 6),
            _ModRow(
              label: 'AT',
              value: mods.at,
              onDecrement: () =>
                  _saveMods(ref, mods.copyWith(at: mods.at - 1)),
              onIncrement: () =>
                  _saveMods(ref, mods.copyWith(at: mods.at + 1)),
            ),
            const SizedBox(height: 6),
            _ModRow(
              label: 'RS',
              value: mods.rs,
              onDecrement: () =>
                  _saveMods(ref, mods.copyWith(rs: mods.rs - 1)),
              onIncrement: () =>
                  _saveMods(ref, mods.copyWith(rs: mods.rs + 1)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modifikatorzeile: Label | – | Wert (vorzeichenbehaftet) | +
class _ModRow extends StatelessWidget {
  const _ModRow({
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String label;
  final int value;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final sign = value > 0 ? '+' : '';
    final color = value > 0
        ? Theme.of(context).colorScheme.primary
        : value < 0
            ? Theme.of(context).colorScheme.error
            : null;
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        _StepButton(icon: Icons.remove, tooltip: '$label verringern', onPressed: onDecrement),
        const SizedBox(width: 4),
        SizedBox(
          width: 44,
          child: Text(
            '$sign$value',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 4),
        _StepButton(icon: Icons.add, tooltip: '$label erhoehen', onPressed: onIncrement),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Kampfwerte-Karte: berechnete Endwerte (nur Anzeige)
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
            Text('Kampfwerte', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            _StatRow(label: 'Initiative', value: combat.initiative.toString()),
            _StatRow(label: 'Ausweichen', value: combat.ausweichen.toString()),
            _StatRow(label: 'AT', value: combat.at.toString()),
            _StatRow(label: 'PA', value: combat.pa.toString()),
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
// Hilfswidgets
// ---------------------------------------------------------------------------

/// Kompakter Schaltknopf fuer Stepper-Interaktionen.
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton.outlined(
        padding: EdgeInsets.zero,
        iconSize: 14,
        icon: Icon(icon),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

/// Bezeichnung + berechneter Wert in einer Zeile (Lesemodus).
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
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
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
