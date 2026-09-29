import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/rules/derived/rest_outcome_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/rest_rules.dart';
import 'package:dsa_heldenverwaltung/state/ablauf_providers.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';
import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/karto_variante.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';

part 'rest/rest_panel_widgets.dart';
part 'rest/rest_roll_inputs.dart';

/// Öffnet den Rast-Dialog für einen Helden.
Future<void> showRestDialog({
  required BuildContext context,
  required String heroId,
}) {
  return showAdaptiveDetailSheet<void>(
    context: context,
    builder: (sheetContext) => AlertDialog(
      key: const ValueKey<String>('rest-dialog'),
      title: const Text('Rast'),
      content: SizedBox(
        width: kDialogWidthMedium,
        child: SingleChildScrollView(
          child: RestPanel(
            heroId: heroId,
            onApplied: () => Navigator.of(sheetContext).pop(),
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('rest-dialog-close'),
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('Schließen'),
        ),
      ],
    ),
  );
}

/// Eingebetteter Rast-Inhalt.
///
/// Rendert Übersicht, Au-, Zustand-, Regenerations- und Aktionsbereiche
/// inline, ohne eigene Dialog-Hülle. Wird von [showRestDialog] in einen
/// [AlertDialog] gewrapt und vom `Rast`-Tab des Inspectors direkt eingebettet.
///
/// Das Panel sammelt nur Eingaben. Gerechnet wird in
/// `rest_outcome_rules.dart`, gespeichert über den Ablauf
/// `RastAbschliessen` (ARCH-05); Speicherfehler zeigt das Panel selbst an.
class RestPanel extends ConsumerStatefulWidget {
  const RestPanel({super.key, required this.heroId, this.onApplied});

  final String heroId;

  /// Wird aufgerufen, nachdem `Übernehmen` oder `Fullrestore` erfolgreich
  /// angewendet wurden. Im Dialog-Modus schließt der Caller damit den Dialog,
  /// im eingebetteten Modus bleibt das Panel sichtbar.
  final VoidCallback? onApplied;

  @override
  ConsumerState<RestPanel> createState() => _RestPanelState();
}

class _RestPanelState extends ConsumerState<RestPanel> {
  final Random _random = Random();

  /// Zentrale Aktivitaets-Auswahl. Steuert alle Sub-Bereiche.
  RestActivity _activity = RestActivity.kurzeRast;

  /// Stunden fuer den Erschoepfung-Abbau bei `kurzeRast`; Schlaf und
  /// Bettruhe verrechnen fest 8 h (siehe [RestActivityRules]).
  int _conditionHours = 1;

  bool _applySecondPhase = true;

  /// Eingaben je Wurf; welche davon zaehlen, entscheidet die Regel.
  final Map<RestRollSlot, _RestRollInput> _rolls =
      <RestRollSlot, _RestRollInput>{
        for (final slot in RestRollSlot.values) slot: _RestRollInput(),
      };

  /// Äußere Umstände der Regeneration.
  RestEnvironmentInput _environment = const RestEnvironmentInput();

  /// Sperrt beide Aktionen, solange ein Speichervorgang laeuft.
  bool _schreibt = false;

  /// Zuletzt gescheiterter Speichervorgang, im Panel angezeigt.
  String? _fehler;

  int _rollSum(int count, int sides) {
    var total = 0;
    for (var index = 0; index < count; index++) {
      total += _random.nextInt(sides) + 1;
    }
    return total;
  }

  // Wuerfelt digital: 3W6 fuer Ausdauer, 1W20 fuer Proben, sonst 1W6.
  void _wuerfle(RestRollSlot slot) {
    final int wert;
    switch (slot) {
      case RestRollSlot.auRoll:
        wert = _rollSum(3, 6);
      case RestRollSlot.auKoProbe:
      case RestRollSlot.phase1KoProbe:
      case RestRollSlot.phase1InProbe:
      case RestRollSlot.phase2KoProbe:
      case RestRollSlot.phase2InProbe:
        wert = _rollSum(1, 20);
      case RestRollSlot.phase1Lep:
      case RestRollSlot.phase1Asp:
      case RestRollSlot.phase2Lep:
      case RestRollSlot.phase2Asp:
        wert = _rollSum(1, 6);
    }
    setState(() => _rolls[slot]!.digital = wert);
  }

  // Uebersetzt die Eingaben des Panels in die Eingaben der Rastregel.
  RestOutcomeInput _eingabe(
    HeroComputedSnapshot computed,
    RestAbilitySummary abilities,
  ) {
    final derived = computed.derivedStats;
    final rolls = <RestRollSlot, int>{};
    for (final entry in _rolls.entries) {
      final value = entry.value.value;
      if (value != null) {
        rolls[entry.key] = value;
      }
    }
    return RestOutcomeInput(
      activity: _activity,
      requestedConditionHours: _conditionHours,
      applySecondPhase: _applySecondPhase,
      rolls: rolls,
      environment: _environment,
      abilities: abilities,
      effectiveAttributes: computed.effectiveAttributes,
      magicLeadAttribute: computed.hero.magicLeadAttribute,
      magicEnabled: computed.resourceActivation.magic.isEnabled,
      maxLep: derived.maxLep,
      maxAu: derived.maxAu,
      maxAsp: derived.maxAsp,
    );
  }

  Set<RestRollSlot> get _manuelleWuerfe => <RestRollSlot>{
    for (final entry in _rolls.entries)
      if (entry.value.mode == _RestRollMode.manual) entry.key,
  };

  @override
  Widget build(BuildContext context) {
    final hero = ref.watch(heroByIdProvider(widget.heroId));
    final heroStateAsync = ref.watch(heroStateProvider(widget.heroId));
    final computedAsync = ref.watch(heroComputedProvider(widget.heroId));
    final heroState = heroStateAsync.valueOrNull;
    final computed = computedAsync.valueOrNull;

    if (hero == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Held nicht gefunden.'),
      );
    }
    if (heroState == null || computed == null) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final abilities = collectRestAbilities(
      computed.hero,
      catalog: ref.watch(rulesCatalogProvider).valueOrNull,
    );
    final regenerationPhases = _activity.regenerationPhases(
      applySecondPhase: _applySecondPhase,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildActivitySelector(context),
        if (_activity == RestActivity.kurzeRast) ...[
          const SizedBox(height: 12),
          _buildConditionHoursCard(context),
        ],
        if (_activity.recoversAu) ...[
          const SizedBox(height: 12),
          _buildAuSection(context, computed.effectiveAttributes.ko),
        ],
        if (regenerationPhases > 0) ...[
          const SizedBox(height: 12),
          _buildRegenerationSection(context, computed, abilities),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                key: const ValueKey<String>('rest-dialog-apply'),
                onPressed: _schreibt
                    ? null
                    : () => _uebernehmeRast(computed, abilities),
                child: const Text('Übernehmen'),
              ),
            ],
          ),
        ),
        if (_fehler != null) ...[
          const SizedBox(height: 8),
          Text(
            _fehler!,
            key: const ValueKey<String>('rest-dialog-save-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _buildActivitySelector(BuildContext context) {
    final theme = Theme.of(context);
    final codex = context.codexTheme;
    return _RestSectionSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.nights_stay, size: 18, color: codex.brass),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Aktivität', style: theme.textTheme.titleSmall),
              ),
              IconButton(
                key: const ValueKey<String>('rest-dialog-full-restore'),
                tooltip: 'Fullrestore anwenden',
                style: IconButton.styleFrom(
                  foregroundColor: codex.brass,
                  backgroundColor: codex.brass.withValues(alpha: 0.14),
                  side: BorderSide(color: codex.brassMuted),
                ),
                onPressed: _schreibt ? null : _confirmAndApplyFullRestore,
                icon: const Icon(Icons.auto_fix_high),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 8.0;
              final useGrid = constraints.maxWidth >= 360;
              final tileWidth = useGrid
                  ? (constraints.maxWidth - spacing) / 2
                  : constraints.maxWidth;
              return Wrap(
                key: const ValueKey<String>('rest-activity'),
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final activity in RestActivity.values)
                    SizedBox(
                      width: tileWidth,
                      child: _RestActivityTile(
                        activity: activity,
                        icon: _activityIcon(activity),
                        label: _activityLabel(activity),
                        subtitle: _activitySubtitle(activity),
                        selected: _activity == activity,
                        onSelected: (value) {
                          setState(() => _activity = value);
                        },
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            _activityDescription(_activity),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildConditionHoursCard(BuildContext context) {
    final theme = Theme.of(context);
    final codex = context.codexTheme;
    return _RestSectionSurface(
      child: Row(
        children: [
          Icon(Icons.schedule, size: 18, color: codex.brass),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stunden Rast', style: theme.textTheme.labelLarge),
                const SizedBox(height: 2),
                Text('Rast-Tempo', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          _RestNumberStepper(
            value: _conditionHours,
            decreaseTooltip: 'Stunden verringern',
            increaseTooltip: 'Stunden erhöhen',
            onDecrease: _conditionHours > 0
                ? () => setState(() => _conditionHours--)
                : null,
            onIncrease: () => setState(() => _conditionHours++),
          ),
        ],
      ),
    );
  }

  Widget _buildAuSection(BuildContext context, int koTarget) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ausruhen', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              '3W6 Au, bei gelungener KO-Probe 3W6+6.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _buildRollInput(
              slot: RestRollSlot.auRoll,
              label: 'Ausdauerwurf',
              keyPrefix: 'rest-au-roll',
              helperText: '3W6',
            ),
            const SizedBox(height: 12),
            _buildProbeInput(
              slot: RestRollSlot.auKoProbe,
              label: 'KO-Probe',
              keyPrefix: 'rest-au-ko',
              targetValue: koTarget,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegenerationSection(
    BuildContext context,
    HeroComputedSnapshot computed,
    RestAbilitySummary abilities,
  ) {
    final isBedRest = _activity == RestActivity.bettruhe;
    Widget phaseCard(int phase) {
      return _buildRecoveryPhaseCard(
        title: 'Phase ${phase + 1}',
        phaseKeyPrefix: 'rest-phase-${phase + 1}',
        slots: kRestPhaseSlots[phase],
        koTarget: computed.effectiveAttributes.ko,
        inTarget: computed.effectiveAttributes.inn,
        showAspFields: computed.resourceActivation.magic.isEnabled,
        abilities: abilities,
        magicLeadAttribute: computed.hero.magicLeadAttribute,
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Regeneration', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              isBedRest
                  ? 'Bettruhe: bis zu zwei Phasen LeP/AsP-Regeneration.'
                  : 'Schlafphase: eine Runde LeP/AsP-Regeneration.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (isBedRest)
              SwitchListTile(
                key: const ValueKey<String>('rest-regeneration-second-phase'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Zweite Regenerationsphase anwenden'),
                value: _applySecondPhase,
                onChanged: (value) => setState(() => _applySecondPhase = value),
              ),
            const SizedBox(height: 8),
            _RestEnvironmentSection(
              environment: _environment,
              onChanged: (value) => setState(() => _environment = value),
            ),
            const SizedBox(height: 12),
            phaseCard(0),
            if (isBedRest && _applySecondPhase) ...[
              const SizedBox(height: 12),
              phaseCard(1),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecoveryPhaseCard({
    required String title,
    required String phaseKeyPrefix,
    required RestPhaseSlots slots,
    required int koTarget,
    required int inTarget,
    required bool showAspFields,
    required RestAbilitySummary abilities,
    required String magicLeadAttribute,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _buildRollInput(
              slot: slots.lep,
              label: 'LeP-Wurf',
              keyPrefix: '$phaseKeyPrefix-lep',
              helperText: '1W6',
            ),
            const SizedBox(height: 8),
            _buildProbeInput(
              slot: slots.koProbe,
              label: 'KO-Probe',
              keyPrefix: '$phaseKeyPrefix-ko',
              targetValue: koTarget,
            ),
            if (showAspFields) ...[
              const SizedBox(height: 8),
              _buildRollInput(
                slot: slots.asp,
                label: abilities.hasMasterfulRegeneration
                    ? 'AsP-Wurf / Leiteigenschaft'
                    : 'AsP-Wurf',
                keyPrefix: '$phaseKeyPrefix-asp',
                helperText: abilities.hasMasterfulRegeneration
                    ? '1W6 oder Leiteigenschaft/3'
                    : '1W6',
              ),
              const SizedBox(height: 8),
              _buildProbeInput(
                slot: slots.inProbe,
                label: 'IN-Probe',
                keyPrefix: '$phaseKeyPrefix-in',
                targetValue: inTarget,
              ),
              if (abilities.hasMasterfulRegeneration)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Leiteigenschaft: '
                    '${magicLeadAttribute.isEmpty ? 'nicht gesetzt' : magicLeadAttribute}',
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // Bindet die Eingabe eines Wurfs an den Panelzustand.
  _RestRollModeInput Function(String manualLabel) _modeInput(
    RestRollSlot slot,
    String keyPrefix,
  ) {
    final input = _rolls[slot]!;
    return (manualLabel) => _RestRollModeInput(
      input: input,
      keyPrefix: keyPrefix,
      manualLabel: manualLabel,
      onModeChanged: (mode) => setState(() => input.mode = mode),
      onManualChanged: (value) => setState(() => input.manual = value),
      onRoll: () => _wuerfle(slot),
    );
  }

  Widget _buildRollInput({
    required RestRollSlot slot,
    required String label,
    required String keyPrefix,
    required String helperText,
  }) {
    return _RestRollField(
      label: label,
      helperText: helperText,
      modeInput: _modeInput(slot, keyPrefix),
    );
  }

  Widget _buildProbeInput({
    required RestRollSlot slot,
    required String label,
    required String keyPrefix,
    required int targetValue,
  }) {
    return _RestProbeField(
      label: label,
      targetValue: targetValue,
      succeeded: isRestProbeSuccessful(
        roll: _rolls[slot]!.value,
        target: targetValue,
      ),
      modeInput: _modeInput(slot, keyPrefix),
    );
  }

  // Einziger Schreibweg des Panels. [_schreibt] verhindert doppeltes
  // Uebernehmen; ein Fehler bleibt im Panel stehen, der Dialog offen.
  Future<void> _schreibe(Future<void> Function() aktion) async {
    if (_schreibt) {
      return;
    }
    setState(() {
      _schreibt = true;
      _fehler = null;
    });
    try {
      await aktion();
      if (mounted) {
        widget.onApplied?.call();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _fehler = 'Rast konnte nicht gespeichert werden: ${_text(error)}';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _schreibt = false);
      }
    }
  }

  String _text(Object error) =>
      error is StateError ? error.message : error.toString();

  Future<void> _uebernehmeRast(
    HeroComputedSnapshot computed,
    RestAbilitySummary abilities,
  ) {
    final eingabe = _eingabe(computed, abilities);
    final manuelleWuerfe = _manuelleWuerfe;
    return _schreibe(
      () => ref
          .read(rastAbschliessenProvider)
          .uebernehmeRast(
            heroId: widget.heroId,
            eingabe: eingabe,
            manuelleWuerfe: manuelleWuerfe,
          ),
    );
  }

  Future<void> _confirmAndApplyFullRestore() async {
    if (_schreibt) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Fullrestore anwenden?'),
          content: const Text(
            'Setzt LeP, Au, AsP und KaP auf Maximum, entfernt alle Wunden '
            'und baut Erschöpfung sowie Überanstrengung vollständig ab.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Anwenden'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    // Maxima erst nach der Bestaetigung lesen, damit waehrenddessen
    // gespeicherte Aenderungen einfliessen.
    final computed = ref.read(heroComputedProvider(widget.heroId)).valueOrNull;
    if (computed == null) {
      return;
    }
    await _schreibe(
      () => ref
          .read(rastAbschliessenProvider)
          .vollstaendigeErholung(
            heroId: widget.heroId,
            werte: computed.derivedStats,
          ),
    );
  }
}
