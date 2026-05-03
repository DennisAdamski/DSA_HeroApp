import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/rest_rules.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';
import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';

enum _RestRollMode { digital, manual }

enum _RegenerationMode { none, sleep, bedRest }

/// Vereinheitlichte Rast-Aktivitaet, ersetzt die fruehere Drei-Toggle-UI
/// (Ausruhen / Zustaende / Regeneration).
///
/// Die Aktivitaet steuert intern, welche Sub-Bereiche aktiv sind und mit
/// welchen Default-Modi sie laufen. So muss der Spieler nur einmal
/// auswaehlen, was der Held tut.
enum _RestActivity {
  /// Kurze Pause: nur Erschoepfung-Abbau im Modus `rast` ueber Stunden.
  kurzeRast,

  /// Volle Nachtruhe: Ausdauer + Erschoepfung (Modus `schlaf`) +
  /// 1 Regenerations-Phase fuer LeP/AsP.
  schlaf,

  /// Bettruhe: wie Schlaf, aber mit optionaler zweiter Regen-Phase.
  bettruhe,

  /// Nur Ausdauer regenerieren – kein Schlaf, keine Regeneration.
  nurAusruhen,
}

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
  _RestActivity _activity = _RestActivity.kurzeRast;

  /// Stunden fuer den Erschoepfung-Abbau – bei `kurzeRast` vom Spieler
  /// frei waehlbar, bei `schlaf`/`bettruhe` als fester Wert (8h) verwendet.
  int _conditionHours = 1;

  bool _applySecondPhase = true;

  _RestRollMode _auRollMode = _RestRollMode.digital;
  String _auManualRoll = '';
  int? _auDigitalRoll;
  _RestRollMode _auKoMode = _RestRollMode.digital;
  String _auKoManual = '';
  int? _auKoDigital;

  // ---- Computed Getters ueber [_activity] ----

  /// Au-Regeneration laeuft bei allen Aktivitaeten ausser `kurzeRast`.
  bool get _applyAuRecovery => _activity != _RestActivity.kurzeRast;

  /// Erschoepfung-Abbau laeuft bei allen Aktivitaeten ausser `nurAusruhen`.
  bool get _applyConditionRecovery => _activity != _RestActivity.nurAusruhen;

  /// LeP/AsP-Regeneration laeuft bei `schlaf` und `bettruhe`.
  bool get _applyRegeneration =>
      _activity == _RestActivity.schlaf || _activity == _RestActivity.bettruhe;

  /// Bei `kurzeRast` baut der `rast`-Modus langsamer ab, sonst gilt `schlaf`.
  RestConditionMode get _conditionMode => _activity == _RestActivity.kurzeRast
      ? RestConditionMode.rast
      : RestConditionMode.schlaf;

  /// Effektive Stunden fuer den Erschoepfung-Abbau – bei Schlaf/Bettruhe
  /// fest 8h, bei kurzeRast vom Spieler vorgegeben.
  int get _effectiveConditionHours =>
      _activity == _RestActivity.kurzeRast ? _conditionHours : 8;

  _RegenerationMode get _regenerationMode {
    switch (_activity) {
      case _RestActivity.schlaf:
        return _RegenerationMode.sleep;
      case _RestActivity.bettruhe:
        return _RegenerationMode.bedRest;
      case _RestActivity.kurzeRast:
      case _RestActivity.nurAusruhen:
        return _RegenerationMode.none;
    }
  }

  int _weatherModifier = 0;
  int _sleepSiteModifier = 0;
  bool _hasBadCamp = false;
  bool _hasNightDisturbance = false;
  bool _hasWatchDuty = false;
  bool _isIll = false;
  int _extraModifier = 0;

  _RestRollMode _phase1LepMode = _RestRollMode.digital;
  String _phase1LepManual = '';
  int? _phase1LepDigital;
  _RestRollMode _phase1AspMode = _RestRollMode.digital;
  String _phase1AspManual = '';
  int? _phase1AspDigital;
  _RestRollMode _phase1KoMode = _RestRollMode.digital;
  String _phase1KoManual = '';
  int? _phase1KoDigital;
  _RestRollMode _phase1InMode = _RestRollMode.digital;
  String _phase1InManual = '';
  int? _phase1InDigital;

  _RestRollMode _phase2LepMode = _RestRollMode.digital;
  String _phase2LepManual = '';
  int? _phase2LepDigital;
  _RestRollMode _phase2AspMode = _RestRollMode.digital;
  String _phase2AspManual = '';
  int? _phase2AspDigital;
  _RestRollMode _phase2KoMode = _RestRollMode.digital;
  String _phase2KoManual = '';
  int? _phase2KoDigital;
  _RestRollMode _phase2InMode = _RestRollMode.digital;
  String _phase2InManual = '';
  int? _phase2InDigital;

  int? _manualInt(String raw) => int.tryParse(raw.trim());

  int _rollSum(int count, int sides) {
    var total = 0;
    for (var index = 0; index < count; index++) {
      total += _random.nextInt(sides) + 1;
    }
    return total;
  }

  int? _resolveRoll(_RestRollMode mode, int? digitalValue, String manualValue) {
    if (mode == _RestRollMode.digital) {
      return digitalValue;
    }
    return _manualInt(manualValue);
  }

  void _appendRestRollLog(
    List<DiceLogEntry> entries, {
    required String title,
    required String diceLabel,
    required _RestRollMode mode,
    required int? digitalValue,
    required String manualValue,
  }) {
    final value = _resolveRoll(mode, digitalValue, manualValue);
    if (value == null) {
      return;
    }
    entries.add(
      diceLogEntryFromRoll(
        title: title,
        subtitle: mode == _RestRollMode.manual
            ? '$diceLabel manuell'
            : '$diceLabel (Summe)',
        diceValues: <int>[value],
        total: value,
      ),
    );
  }

  void _appendRestProbeLog(
    List<DiceLogEntry> entries, {
    required String title,
    required int targetValue,
    required _RestRollMode mode,
    required int? digitalValue,
    required String manualValue,
  }) {
    final value = _resolveRoll(mode, digitalValue, manualValue);
    if (value == null) {
      return;
    }
    entries.add(
      diceLogEntryFromSimpleCheck(
        title: title,
        subtitle: mode == _RestRollMode.manual
            ? 'Zielwert $targetValue, manuell'
            : 'Zielwert $targetValue',
        roll: value,
        targetValue: targetValue,
      ),
    );
  }

  List<DiceLogEntry> _buildAppliedRestLogEntries(
    HeroComputedSnapshot computed,
  ) {
    final entries = <DiceLogEntry>[];
    if (_applyAuRecovery) {
      _appendRestRollLog(
        entries,
        title: 'Rast: Ausdauerwurf',
        diceLabel: '3W6',
        mode: _auRollMode,
        digitalValue: _auDigitalRoll,
        manualValue: _auManualRoll,
      );
      _appendRestProbeLog(
        entries,
        title: 'Rast: KO-Probe (Ausruhen)',
        targetValue: computed.effectiveAttributes.ko,
        mode: _auKoMode,
        digitalValue: _auKoDigital,
        manualValue: _auKoManual,
      );
    }
    if (!_applyRegeneration || _regenerationMode == _RegenerationMode.none) {
      return entries;
    }
    _appendRecoveryPhaseLogEntries(
      entries,
      phaseLabel: 'Phase 1',
      computed: computed,
      lepMode: _phase1LepMode,
      lepDigitalValue: _phase1LepDigital,
      lepManualValue: _phase1LepManual,
      aspMode: _phase1AspMode,
      aspDigitalValue: _phase1AspDigital,
      aspManualValue: _phase1AspManual,
      koMode: _phase1KoMode,
      koDigitalValue: _phase1KoDigital,
      koManualValue: _phase1KoManual,
      inMode: _phase1InMode,
      inDigitalValue: _phase1InDigital,
      inManualValue: _phase1InManual,
    );
    if (_regenerationMode == _RegenerationMode.bedRest && _applySecondPhase) {
      _appendRecoveryPhaseLogEntries(
        entries,
        phaseLabel: 'Phase 2',
        computed: computed,
        lepMode: _phase2LepMode,
        lepDigitalValue: _phase2LepDigital,
        lepManualValue: _phase2LepManual,
        aspMode: _phase2AspMode,
        aspDigitalValue: _phase2AspDigital,
        aspManualValue: _phase2AspManual,
        koMode: _phase2KoMode,
        koDigitalValue: _phase2KoDigital,
        koManualValue: _phase2KoManual,
        inMode: _phase2InMode,
        inDigitalValue: _phase2InDigital,
        inManualValue: _phase2InManual,
      );
    }
    return entries;
  }

  void _appendRecoveryPhaseLogEntries(
    List<DiceLogEntry> entries, {
    required String phaseLabel,
    required HeroComputedSnapshot computed,
    required _RestRollMode lepMode,
    required int? lepDigitalValue,
    required String lepManualValue,
    required _RestRollMode aspMode,
    required int? aspDigitalValue,
    required String aspManualValue,
    required _RestRollMode koMode,
    required int? koDigitalValue,
    required String koManualValue,
    required _RestRollMode inMode,
    required int? inDigitalValue,
    required String inManualValue,
  }) {
    _appendRestRollLog(
      entries,
      title: 'Regeneration $phaseLabel: LeP-Wurf',
      diceLabel: '1W6',
      mode: lepMode,
      digitalValue: lepDigitalValue,
      manualValue: lepManualValue,
    );
    _appendRestProbeLog(
      entries,
      title: 'Regeneration $phaseLabel: KO-Probe',
      targetValue: computed.effectiveAttributes.ko,
      mode: koMode,
      digitalValue: koDigitalValue,
      manualValue: koManualValue,
    );
    if (!computed.resourceActivation.magic.isEnabled) {
      return;
    }
    _appendRestRollLog(
      entries,
      title: 'Regeneration $phaseLabel: AsP-Wurf',
      diceLabel: '1W6',
      mode: aspMode,
      digitalValue: aspDigitalValue,
      manualValue: aspManualValue,
    );
    _appendRestProbeLog(
      entries,
      title: 'Regeneration $phaseLabel: IN-Probe',
      targetValue: computed.effectiveAttributes.inn,
      mode: inMode,
      digitalValue: inDigitalValue,
      manualValue: inManualValue,
    );
  }

  bool _probeSucceeded({
    required _RestRollMode mode,
    required int? digitalValue,
    required String manualValue,
    required int target,
  }) {
    final rolled = _resolveRoll(mode, digitalValue, manualValue);
    if (rolled == null) {
      return false;
    }
    if (rolled == 1) {
      return true;
    }
    if (rolled == 20) {
      return false;
    }
    return rolled <= target;
  }

  RestEnvironmentInput get _environment => RestEnvironmentInput(
    weatherModifier: _weatherModifier,
    sleepSiteModifier: _sleepSiteModifier,
    hasBadCamp: _hasBadCamp,
    hasNightDisturbance: _hasNightDisturbance,
    hasWatchDuty: _hasWatchDuty,
    extraModifier: _extraModifier,
    isIll: _isIll,
  );

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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildActivitySelector(context, heroState, computed),
        if (_activity == _RestActivity.kurzeRast) ...[
          const SizedBox(height: 12),
          _buildConditionHoursCard(context),
        ],
        if (_applyAuRecovery) ...[
          const SizedBox(height: 12),
          _buildAuSection(context, computed.effectiveAttributes.ko),
        ],
        if (_applyRegeneration) ...[
          const SizedBox(height: 12),
          _buildRegenerationSection(context, computed),
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
                onPressed: () => _applyPreview(heroState, computed),
                child: const Text('Übernehmen'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivitySelector(
    BuildContext context,
    HeroState heroState,
    HeroComputedSnapshot computed,
  ) {
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
                onPressed: () =>
                    _confirmAndApplyFullRestore(heroState, computed),
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
                  for (final activity in _RestActivity.values)
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

  IconData _activityIcon(_RestActivity activity) {
    switch (activity) {
      case _RestActivity.kurzeRast:
        return Icons.schedule;
      case _RestActivity.schlaf:
        return Icons.bedtime;
      case _RestActivity.bettruhe:
        return Icons.hotel;
      case _RestActivity.nurAusruhen:
        return Icons.weekend;
    }
  }

  String _activityLabel(_RestActivity activity) {
    switch (activity) {
      case _RestActivity.kurzeRast:
        return 'Kurze Rast';
      case _RestActivity.schlaf:
        return 'Schlaf';
      case _RestActivity.bettruhe:
        return 'Bettruhe';
      case _RestActivity.nurAusruhen:
        return 'Nur ausruhen';
    }
  }

  String _activitySubtitle(_RestActivity activity) {
    switch (activity) {
      case _RestActivity.kurzeRast:
        return 'Zustände';
      case _RestActivity.schlaf:
        return 'Ausdauer + Regeneration';
      case _RestActivity.bettruhe:
        return 'Bis zu zwei Phasen';
      case _RestActivity.nurAusruhen:
        return 'Nur Ausdauer';
    }
  }

  String _activityDescription(_RestActivity activity) {
    switch (activity) {
      case _RestActivity.kurzeRast:
        return 'Baut nur Überanstrengung & Erschöpfung ab '
            '(Rast-Tempo, Stunden frei wählbar).';
      case _RestActivity.schlaf:
        return 'Volle Nachtruhe: Ausdauer-Erholung, Erschöpfung-Abbau im '
            'Schlaftempo (8 h) und eine Regenerationsphase für LeP/AsP.';
      case _RestActivity.bettruhe:
        return 'Wie Schlaf, aber mit optionaler zweiter '
            'Regenerationsphase für LeP/AsP.';
      case _RestActivity.nurAusruhen:
        return 'Nur die Ausdauer wird regeneriert – kein Schlaf, keine '
            'Regeneration, kein Erschöpfung-Abbau.';
    }
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
              label: 'Ausdauerwurf',
              keyPrefix: 'rest-au-roll',
              mode: _auRollMode,
              digitalValue: _auDigitalRoll,
              manualValue: _auManualRoll,
              helperText: '3W6',
              onModeChanged: (value) => setState(() => _auRollMode = value),
              onManualChanged: (value) => setState(() => _auManualRoll = value),
              onDigitalRoll: () =>
                  setState(() => _auDigitalRoll = _rollSum(3, 6)),
            ),
            const SizedBox(height: 12),
            _buildProbeInput(
              label: 'KO-Probe',
              keyPrefix: 'rest-au-ko',
              targetValue: koTarget,
              mode: _auKoMode,
              digitalValue: _auKoDigital,
              manualValue: _auKoManual,
              onModeChanged: (value) => setState(() => _auKoMode = value),
              onManualChanged: (value) => setState(() => _auKoManual = value),
              onDigitalRoll: () =>
                  setState(() => _auKoDigital = _rollSum(1, 20)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegenerationSection(
    BuildContext context,
    HeroComputedSnapshot computed,
  ) {
    final abilities = collectRestAbilities(computed.hero);
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
              _regenerationMode == _RegenerationMode.bedRest
                  ? 'Bettruhe: bis zu zwei Phasen LeP/AsP-Regeneration.'
                  : 'Schlafphase: eine Runde LeP/AsP-Regeneration.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_regenerationMode == _RegenerationMode.bedRest)
              SwitchListTile(
                key: const ValueKey<String>('rest-regeneration-second-phase'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Zweite Regenerationsphase anwenden'),
                value: _applySecondPhase,
                onChanged: (value) => setState(() => _applySecondPhase = value),
              ),
            const SizedBox(height: 8),
            _buildEnvironmentSection(),
            const SizedBox(height: 12),
            _buildRecoveryPhaseCard(
              title: 'Phase 1',
              phaseKeyPrefix: 'rest-phase-1',
              lepMode: _phase1LepMode,
              lepDigitalValue: _phase1LepDigital,
              lepManualValue: _phase1LepManual,
              aspMode: _phase1AspMode,
              aspDigitalValue: _phase1AspDigital,
              aspManualValue: _phase1AspManual,
              koMode: _phase1KoMode,
              koDigitalValue: _phase1KoDigital,
              koManualValue: _phase1KoManual,
              inMode: _phase1InMode,
              inDigitalValue: _phase1InDigital,
              inManualValue: _phase1InManual,
              koTarget: computed.effectiveAttributes.ko,
              inTarget: computed.effectiveAttributes.inn,
              onLepModeChanged: (value) =>
                  setState(() => _phase1LepMode = value),
              onLepManualChanged: (value) =>
                  setState(() => _phase1LepManual = value),
              onLepDigitalRoll: () =>
                  setState(() => _phase1LepDigital = _rollSum(1, 6)),
              onAspModeChanged: (value) =>
                  setState(() => _phase1AspMode = value),
              onAspManualChanged: (value) =>
                  setState(() => _phase1AspManual = value),
              onAspDigitalRoll: () =>
                  setState(() => _phase1AspDigital = _rollSum(1, 6)),
              onKoModeChanged: (value) => setState(() => _phase1KoMode = value),
              onKoManualChanged: (value) =>
                  setState(() => _phase1KoManual = value),
              onKoDigitalRoll: () =>
                  setState(() => _phase1KoDigital = _rollSum(1, 20)),
              onInModeChanged: (value) => setState(() => _phase1InMode = value),
              onInManualChanged: (value) =>
                  setState(() => _phase1InManual = value),
              onInDigitalRoll: () =>
                  setState(() => _phase1InDigital = _rollSum(1, 20)),
              showAspFields: computed.resourceActivation.magic.isEnabled,
              abilities: abilities,
              magicLeadAttribute: computed.hero.magicLeadAttribute,
            ),
            if (_regenerationMode == _RegenerationMode.bedRest &&
                _applySecondPhase) ...[
              const SizedBox(height: 12),
              _buildRecoveryPhaseCard(
                title: 'Phase 2',
                phaseKeyPrefix: 'rest-phase-2',
                lepMode: _phase2LepMode,
                lepDigitalValue: _phase2LepDigital,
                lepManualValue: _phase2LepManual,
                aspMode: _phase2AspMode,
                aspDigitalValue: _phase2AspDigital,
                aspManualValue: _phase2AspManual,
                koMode: _phase2KoMode,
                koDigitalValue: _phase2KoDigital,
                koManualValue: _phase2KoManual,
                inMode: _phase2InMode,
                inDigitalValue: _phase2InDigital,
                inManualValue: _phase2InManual,
                koTarget: computed.effectiveAttributes.ko,
                inTarget: computed.effectiveAttributes.inn,
                onLepModeChanged: (value) =>
                    setState(() => _phase2LepMode = value),
                onLepManualChanged: (value) =>
                    setState(() => _phase2LepManual = value),
                onLepDigitalRoll: () =>
                    setState(() => _phase2LepDigital = _rollSum(1, 6)),
                onAspModeChanged: (value) =>
                    setState(() => _phase2AspMode = value),
                onAspManualChanged: (value) =>
                    setState(() => _phase2AspManual = value),
                onAspDigitalRoll: () =>
                    setState(() => _phase2AspDigital = _rollSum(1, 6)),
                onKoModeChanged: (value) =>
                    setState(() => _phase2KoMode = value),
                onKoManualChanged: (value) =>
                    setState(() => _phase2KoManual = value),
                onKoDigitalRoll: () =>
                    setState(() => _phase2KoDigital = _rollSum(1, 20)),
                onInModeChanged: (value) =>
                    setState(() => _phase2InMode = value),
                onInManualChanged: (value) =>
                    setState(() => _phase2InManual = value),
                onInDigitalRoll: () =>
                    setState(() => _phase2InDigital = _rollSum(1, 20)),
                showAspFields: computed.resourceActivation.magic.isEnabled,
                abilities: abilities,
                magicLeadAttribute: computed.hero.magicLeadAttribute,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEnvironmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Äußere Umstände', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          key: const ValueKey<String>('rest-weather-modifier'),
          initialValue: _weatherModifier,
          decoration: const InputDecoration(
            labelText: 'Wetter',
            border: OutlineInputBorder(),
          ),
          items: const <DropdownMenuItem<int>>[
            DropdownMenuItem<int>(value: 0, child: Text('Kein Malus')),
            DropdownMenuItem<int>(value: -1, child: Text('-1')),
            DropdownMenuItem<int>(value: -2, child: Text('-2')),
            DropdownMenuItem<int>(value: -3, child: Text('-3')),
            DropdownMenuItem<int>(value: -4, child: Text('-4')),
            DropdownMenuItem<int>(value: -5, child: Text('-5')),
          ],
          onChanged: (value) => setState(() => _weatherModifier = value ?? 0),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          key: const ValueKey<String>('rest-sleep-site-modifier'),
          initialValue: _sleepSiteModifier,
          decoration: const InputDecoration(
            labelText: 'Lagerstätte',
            border: OutlineInputBorder(),
          ),
          items: const <DropdownMenuItem<int>>[
            DropdownMenuItem<int>(value: 0, child: Text('0')),
            DropdownMenuItem<int>(value: 1, child: Text('+1')),
            DropdownMenuItem<int>(value: 2, child: Text('+2')),
          ],
          onChanged: (value) => setState(() => _sleepSiteModifier = value ?? 0),
        ),
        SwitchListTile(
          key: const ValueKey<String>('rest-bad-camp'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Schlechter Lagerplatz'),
          value: _hasBadCamp,
          onChanged: (value) => setState(() => _hasBadCamp = value),
        ),
        SwitchListTile(
          key: const ValueKey<String>('rest-night-disturbance'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Ruhestörung'),
          value: _hasNightDisturbance,
          onChanged: (value) => setState(() => _hasNightDisturbance = value),
        ),
        SwitchListTile(
          key: const ValueKey<String>('rest-watch-duty'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Wache gehalten'),
          value: _hasWatchDuty,
          onChanged: (value) => setState(() => _hasWatchDuty = value),
        ),
        SwitchListTile(
          key: const ValueKey<String>('rest-is-ill'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Held ist erkrankt'),
          value: _isIll,
          onChanged: (value) => setState(() => _isIll = value),
        ),
        TextFormField(
          key: const ValueKey<String>('rest-extra-modifier'),
          initialValue: '$_extraModifier',
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Freier Rest-Modifikator',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              _extraModifier = int.tryParse(value.trim()) ?? 0;
            });
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Effektiver Umweltmodifikator: '
          '${computeRestEnvironmentModifier(_environment)}',
        ),
      ],
    );
  }

  Widget _buildRecoveryPhaseCard({
    required String title,
    required String phaseKeyPrefix,
    required _RestRollMode lepMode,
    required int? lepDigitalValue,
    required String lepManualValue,
    required _RestRollMode aspMode,
    required int? aspDigitalValue,
    required String aspManualValue,
    required _RestRollMode koMode,
    required int? koDigitalValue,
    required String koManualValue,
    required _RestRollMode inMode,
    required int? inDigitalValue,
    required String inManualValue,
    required int koTarget,
    required int inTarget,
    required ValueChanged<_RestRollMode> onLepModeChanged,
    required ValueChanged<String> onLepManualChanged,
    required VoidCallback onLepDigitalRoll,
    required ValueChanged<_RestRollMode> onAspModeChanged,
    required ValueChanged<String> onAspManualChanged,
    required VoidCallback onAspDigitalRoll,
    required ValueChanged<_RestRollMode> onKoModeChanged,
    required ValueChanged<String> onKoManualChanged,
    required VoidCallback onKoDigitalRoll,
    required ValueChanged<_RestRollMode> onInModeChanged,
    required ValueChanged<String> onInManualChanged,
    required VoidCallback onInDigitalRoll,
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
              label: 'LeP-Wurf',
              keyPrefix: '$phaseKeyPrefix-lep',
              mode: lepMode,
              digitalValue: lepDigitalValue,
              manualValue: lepManualValue,
              helperText: '1W6',
              onModeChanged: onLepModeChanged,
              onManualChanged: onLepManualChanged,
              onDigitalRoll: onLepDigitalRoll,
            ),
            const SizedBox(height: 8),
            _buildProbeInput(
              label: 'KO-Probe',
              keyPrefix: '$phaseKeyPrefix-ko',
              targetValue: koTarget,
              mode: koMode,
              digitalValue: koDigitalValue,
              manualValue: koManualValue,
              onModeChanged: onKoModeChanged,
              onManualChanged: onKoManualChanged,
              onDigitalRoll: onKoDigitalRoll,
            ),
            if (showAspFields) ...[
              const SizedBox(height: 8),
              _buildRollInput(
                label: abilities.hasMasterfulRegeneration
                    ? 'AsP-Wurf / Leiteigenschaft'
                    : 'AsP-Wurf',
                keyPrefix: '$phaseKeyPrefix-asp',
                mode: aspMode,
                digitalValue: aspDigitalValue,
                manualValue: aspManualValue,
                helperText: abilities.hasMasterfulRegeneration
                    ? '1W6 oder Leiteigenschaft/3'
                    : '1W6',
                onModeChanged: onAspModeChanged,
                onManualChanged: onAspManualChanged,
                onDigitalRoll: onAspDigitalRoll,
              ),
              const SizedBox(height: 8),
              _buildProbeInput(
                label: 'IN-Probe',
                keyPrefix: '$phaseKeyPrefix-in',
                targetValue: inTarget,
                mode: inMode,
                digitalValue: inDigitalValue,
                manualValue: inManualValue,
                onModeChanged: onInModeChanged,
                onManualChanged: onInManualChanged,
                onDigitalRoll: onInDigitalRoll,
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

  Widget _buildRollInput({
    required String label,
    required String keyPrefix,
    required _RestRollMode mode,
    required int? digitalValue,
    required String manualValue,
    required String helperText,
    required ValueChanged<_RestRollMode> onModeChanged,
    required ValueChanged<String> onManualChanged,
    required VoidCallback onDigitalRoll,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        SegmentedButton<_RestRollMode>(
          segments: const <ButtonSegment<_RestRollMode>>[
            ButtonSegment<_RestRollMode>(
              value: _RestRollMode.digital,
              label: Text('Digital'),
            ),
            ButtonSegment<_RestRollMode>(
              value: _RestRollMode.manual,
              label: Text('Manuell'),
            ),
          ],
          selected: <_RestRollMode>{mode},
          onSelectionChanged: (selection) => onModeChanged(selection.first),
        ),
        const SizedBox(height: 8),
        if (mode == _RestRollMode.digital)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: ValueKey<String>('$keyPrefix-digital-roll'),
                onPressed: onDigitalRoll,
                icon: const Icon(Icons.casino_outlined),
                label: const Text('Würfeln'),
              ),
              Text(
                digitalValue == null ? 'Noch kein Wurf' : '$digitalValue',
                key: ValueKey<String>('$keyPrefix-digital-value'),
              ),
            ],
          )
        else
          TextFormField(
            key: ValueKey<String>('$keyPrefix-manual'),
            initialValue: manualValue,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: helperText,
              border: const OutlineInputBorder(),
            ),
            onChanged: onManualChanged,
          ),
      ],
    );
  }

  Widget _buildProbeInput({
    required String label,
    required String keyPrefix,
    required int targetValue,
    required _RestRollMode mode,
    required int? digitalValue,
    required String manualValue,
    required ValueChanged<_RestRollMode> onModeChanged,
    required ValueChanged<String> onManualChanged,
    required VoidCallback onDigitalRoll,
  }) {
    final succeeded = _probeSucceeded(
      mode: mode,
      digitalValue: digitalValue,
      manualValue: manualValue,
      target: targetValue,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label (Zielwert $targetValue)'),
        const SizedBox(height: 6),
        SegmentedButton<_RestRollMode>(
          segments: const <ButtonSegment<_RestRollMode>>[
            ButtonSegment<_RestRollMode>(
              value: _RestRollMode.digital,
              label: Text('Digital'),
            ),
            ButtonSegment<_RestRollMode>(
              value: _RestRollMode.manual,
              label: Text('Manuell'),
            ),
          ],
          selected: <_RestRollMode>{mode},
          onSelectionChanged: (selection) => onModeChanged(selection.first),
        ),
        const SizedBox(height: 8),
        if (mode == _RestRollMode.digital)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: ValueKey<String>('$keyPrefix-digital-roll'),
                onPressed: onDigitalRoll,
                icon: const Icon(Icons.casino_outlined),
                label: const Text('Würfeln'),
              ),
              Text(
                digitalValue == null ? 'Noch kein Wurf' : '$digitalValue',
                key: ValueKey<String>('$keyPrefix-digital-value'),
              ),
            ],
          )
        else
          TextFormField(
            key: ValueKey<String>('$keyPrefix-manual'),
            initialValue: manualValue,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '1W20',
              border: OutlineInputBorder(),
            ),
            onChanged: onManualChanged,
          ),
        const SizedBox(height: 4),
        Text(succeeded ? 'Probe gelungen' : 'Probe nicht gelungen'),
      ],
    );
  }

  _RestPreview _buildPreview(
    HeroState heroState,
    HeroComputedSnapshot computed,
  ) {
    final derived = computed.derivedStats;
    var nextLep = heroState.currentLep;
    var nextAu = heroState.currentAu;
    var nextAsp = heroState.currentAsp;
    var nextUeber = heroState.ueberanstrengung;
    var nextErsch = heroState.erschoepfung;
    final notes = <String>[];

    if (_applyAuRecovery) {
      final auBaseRoll =
          _resolveRoll(_auRollMode, _auDigitalRoll, _auManualRoll) ?? 0;
      final auResult = computeRestAuRecovery(
        currentAu: nextAu,
        maxAu: derived.maxAu,
        baseRoll: auBaseRoll,
        koProbeSucceeded: _probeSucceeded(
          mode: _auKoMode,
          digitalValue: _auKoDigital,
          manualValue: _auKoManual,
          target: computed.effectiveAttributes.ko,
        ),
      );
      nextAu = (nextAu + auResult.recovered).clamp(0, derived.maxAu);
      notes.add('Ausruhen: +${auResult.recovered} Au');
    }

    if (_applyConditionRecovery) {
      final conditionResult = computeConditionRecovery(
        currentUeberanstrengung: nextUeber,
        currentErschoepfung: nextErsch,
        hours: _effectiveConditionHours,
        mode: _conditionMode,
      );
      nextUeber = conditionResult.remainingUeberanstrengung;
      nextErsch = conditionResult.remainingErschoepfung;
      notes.add(
        'Zustände: -${conditionResult.reducedUeberanstrengung} Überanstrengung, '
        '-${conditionResult.reducedErschoepfung} Erschöpfung',
      );
    }

    if (_applyRegeneration && _regenerationMode != _RegenerationMode.none) {
      final phase1 = _applyRecoveryPhase(
        heroState: heroState,
        computed: computed,
        abilities: collectRestAbilities(computed.hero),
        notes: notes,
        currentLep: nextLep,
        currentAsp: nextAsp,
        phaseLabel: 'Phase 1',
        lepMode: _phase1LepMode,
        lepDigitalValue: _phase1LepDigital,
        lepManualValue: _phase1LepManual,
        aspMode: _phase1AspMode,
        aspDigitalValue: _phase1AspDigital,
        aspManualValue: _phase1AspManual,
        koMode: _phase1KoMode,
        koDigitalValue: _phase1KoDigital,
        koManualValue: _phase1KoManual,
        inMode: _phase1InMode,
        inDigitalValue: _phase1InDigital,
        inManualValue: _phase1InManual,
      );
      nextLep = phase1.nextLep;
      nextAsp = phase1.nextAsp;

      if (_regenerationMode == _RegenerationMode.bedRest && _applySecondPhase) {
        final phase2 = _applyRecoveryPhase(
          heroState: heroState,
          computed: computed,
          abilities: collectRestAbilities(computed.hero),
          notes: notes,
          currentLep: nextLep,
          currentAsp: nextAsp,
          phaseLabel: 'Phase 2',
          lepMode: _phase2LepMode,
          lepDigitalValue: _phase2LepDigital,
          lepManualValue: _phase2LepManual,
          aspMode: _phase2AspMode,
          aspDigitalValue: _phase2AspDigital,
          aspManualValue: _phase2AspManual,
          koMode: _phase2KoMode,
          koDigitalValue: _phase2KoDigital,
          koManualValue: _phase2KoManual,
          inMode: _phase2InMode,
          inDigitalValue: _phase2InDigital,
          inManualValue: _phase2InManual,
        );
        nextLep = phase2.nextLep;
        nextAsp = phase2.nextAsp;
      }
    }

    return _RestPreview(
      currentLep: heroState.currentLep,
      nextLep: nextLep,
      currentAu: heroState.currentAu,
      nextAu: nextAu,
      currentAsp: heroState.currentAsp,
      nextAsp: nextAsp,
      currentUeberanstrengung: heroState.ueberanstrengung,
      nextUeberanstrengung: nextUeber,
      currentErschoepfung: heroState.erschoepfung,
      nextErschoepfung: nextErsch,
      regenerationNotes: notes,
    );
  }

  ({int nextLep, int nextAsp}) _applyRecoveryPhase({
    required HeroState heroState,
    required HeroComputedSnapshot computed,
    required RestAbilitySummary abilities,
    required List<String> notes,
    required int currentLep,
    required int currentAsp,
    required String phaseLabel,
    required _RestRollMode lepMode,
    required int? lepDigitalValue,
    required String lepManualValue,
    required _RestRollMode aspMode,
    required int? aspDigitalValue,
    required String aspManualValue,
    required _RestRollMode koMode,
    required int? koDigitalValue,
    required String koManualValue,
    required _RestRollMode inMode,
    required int? inDigitalValue,
    required String inManualValue,
  }) {
    final derived = computed.derivedStats;
    final result = computeRestRecoveryPhase(
      abilities: abilities,
      effectiveAttributes: computed.effectiveAttributes,
      environment: _environment,
      lepRoll: _resolveRoll(lepMode, lepDigitalValue, lepManualValue) ?? 0,
      aspRoll: _resolveRoll(aspMode, aspDigitalValue, aspManualValue) ?? 0,
      koProbeSucceeded: _probeSucceeded(
        mode: koMode,
        digitalValue: koDigitalValue,
        manualValue: koManualValue,
        target: computed.effectiveAttributes.ko,
      ),
      inProbeSucceeded: _probeSucceeded(
        mode: inMode,
        digitalValue: inDigitalValue,
        manualValue: inManualValue,
        target: computed.effectiveAttributes.inn,
      ),
      magicLeadAttribute: computed.hero.magicLeadAttribute,
      magicEnabled: computed.resourceActivation.magic.isEnabled,
    );
    final lepGain = min(result.lepRecovered, derived.maxLep - currentLep);
    final aspGain = min(result.aspRecovered, derived.maxAsp - currentAsp);
    final nextAsp = (currentAsp + aspGain).clamp(0, derived.maxAsp);
    notes.add('$phaseLabel: +$lepGain LeP, +$aspGain AsP');
    return (
      nextLep: (currentLep + lepGain).clamp(0, derived.maxLep),
      nextAsp: nextAsp,
    );
  }

  Future<void> _applyPreview(
    HeroState heroState,
    HeroComputedSnapshot computed,
  ) async {
    final preview = _buildPreview(heroState, computed);
    final updated = heroState.copyWith(
      currentLep: preview.nextLep,
      currentAu: preview.nextAu,
      currentAsp: preview.nextAsp,
      ueberanstrengung: preview.nextUeberanstrengung,
      erschoepfung: preview.nextErschoepfung,
    );
    await _saveAndClose(
      updated,
      diceLogEntries: _buildAppliedRestLogEntries(computed),
    );
  }

  Future<void> _confirmAndApplyFullRestore(
    HeroState heroState,
    HeroComputedSnapshot computed,
  ) async {
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
    if (confirmed != true) {
      return;
    }
    final updated = buildFullRestoreState(
      currentState: heroState,
      derivedStats: computed.derivedStats,
    );
    await _saveAndClose(updated);
  }

  Future<void> _saveAndClose(
    HeroState updated, {
    List<DiceLogEntry> diceLogEntries = const <DiceLogEntry>[],
  }) async {
    final nextState = updated.withAppendedDiceLogEntries(diceLogEntries);
    await ref.read(heroActionsProvider).saveHeroState(widget.heroId, nextState);
    if (!mounted) {
      return;
    }
    widget.onApplied?.call();
  }
}

class _RestSectionSurface extends StatelessWidget {
  const _RestSectionSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final codex = context.codexTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: codex.panelRaised.withValues(alpha: isDark ? 0.38 : 0.55),
        borderRadius: BorderRadius.circular(codex.panelRadius),
        border: Border.all(color: codex.rule),
      ),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }
}

class _RestActivityTile extends StatelessWidget {
  const _RestActivityTile({
    required this.activity,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onSelected,
  });

  final _RestActivity activity;
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final ValueChanged<_RestActivity> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final codex = context.codexTheme;
    final borderRadius = BorderRadius.circular(codex.panelRadius);
    final selectedBackground = codex.brass.withValues(alpha: 0.14);
    final defaultBackground = codex.panel.withValues(alpha: 0.62);
    final borderColor = selected ? codex.brass : codex.rule;
    final foregroundColor = selected ? codex.brass : codex.inkMuted;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: () => onSelected(activity),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? selectedBackground : defaultBackground,
              borderRadius: borderRadius,
              border: Border.all(color: borderColor, width: selected ? 1.4 : 1),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: foregroundColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check_circle, size: 18, color: codex.brass),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RestNumberStepper extends StatelessWidget {
  const _RestNumberStepper({
    required this.value,
    required this.decreaseTooltip,
    required this.increaseTooltip,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int value;
  final String decreaseTooltip;
  final String increaseTooltip;
  final VoidCallback? onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final codex = context.codexTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: codex.panel.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(codex.panelRadius),
        border: Border.all(color: codex.rule),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RestStepperButton(
            tooltip: decreaseTooltip,
            icon: Icons.remove,
            onPressed: onDecrease,
          ),
          SizedBox(
            width: 34,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
          ),
          _RestStepperButton(
            tooltip: increaseTooltip,
            icon: Icons.add,
            onPressed: onIncrease,
          ),
        ],
      ),
    );
  }
}

class _RestStepperButton extends StatelessWidget {
  const _RestStepperButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      padding: EdgeInsets.zero,
      iconSize: 18,
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}

class _RestPreview {
  const _RestPreview({
    required this.currentLep,
    required this.nextLep,
    required this.currentAu,
    required this.nextAu,
    required this.currentAsp,
    required this.nextAsp,
    required this.currentUeberanstrengung,
    required this.nextUeberanstrengung,
    required this.currentErschoepfung,
    required this.nextErschoepfung,
    required this.regenerationNotes,
  });

  final int currentLep;
  final int nextLep;
  final int currentAu;
  final int nextAu;
  final int currentAsp;
  final int nextAsp;
  final int currentUeberanstrengung;
  final int nextUeberanstrengung;
  final int currentErschoepfung;
  final int nextErschoepfung;
  final List<String> regenerationNotes;
}
