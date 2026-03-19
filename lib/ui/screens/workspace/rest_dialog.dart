import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/rest_rules.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';

enum _RestRollMode { digital, manual }

enum _RegenerationMode { none, sleep, bedRest }

/// Öffnet den Rast-Dialog für einen Helden.
Future<void> showRestDialog({
  required BuildContext context,
  required String heroId,
}) {
  return showAdaptiveDetailSheet<void>(
    context: context,
    builder: (_) => _RestDialog(heroId: heroId),
  );
}

class _RestDialog extends ConsumerStatefulWidget {
  const _RestDialog({required this.heroId});

  final String heroId;

  @override
  ConsumerState<_RestDialog> createState() => _RestDialogState();
}

class _RestDialogState extends ConsumerState<_RestDialog> {
  final Random _random = Random();

  bool _applyAuRecovery = false;
  bool _applyConditionRecovery = false;
  bool _applyRegeneration = false;

  _RestRollMode _auRollMode = _RestRollMode.digital;
  String _auManualRoll = '';
  int? _auDigitalRoll;
  _RestRollMode _auKoMode = _RestRollMode.digital;
  String _auKoManual = '';
  int? _auKoDigital;

  RestConditionMode _conditionMode = RestConditionMode.rast;
  int _conditionHours = 1;

  _RegenerationMode _regenerationMode = _RegenerationMode.none;
  bool _applySecondPhase = true;

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
      return const AlertDialog(content: Text('Held nicht gefunden.'));
    }
    if (heroState == null || computed == null) {
      return const AlertDialog(
        content: SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final preview = _buildPreview(heroState, computed);

    return AlertDialog(
      key: const ValueKey<String>('rest-dialog'),
      title: const Text('Rast'),
      content: SizedBox(
        width: kDialogWidthMedium,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(hero.name, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              _buildOverviewCard(context, preview),
              const SizedBox(height: 12),
              _buildAuSection(context, computed.effectiveAttributes.ko),
              const SizedBox(height: 12),
              _buildConditionSection(context),
              const SizedBox(height: 12),
              _buildRegenerationSection(context, computed),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        OutlinedButton(
          key: const ValueKey<String>('rest-dialog-full-restore'),
          onPressed: () => _confirmAndApplyFullRestore(heroState, computed),
          child: const Text('Fullrestore'),
        ),
        FilledButton(
          key: const ValueKey<String>('rest-dialog-apply'),
          onPressed: () => _applyPreview(heroState, computed),
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }

  Widget _buildOverviewCard(BuildContext context, _RestPreview preview) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vorschau', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text('LeP: ${preview.currentLep} → ${preview.nextLep}'),
            Text('Au: ${preview.currentAu} → ${preview.nextAu}'),
            Text('AsP: ${preview.currentAsp} → ${preview.nextAsp}'),
            Text(
              'Überanstrengung: ${preview.currentUeberanstrengung} → '
              '${preview.nextUeberanstrengung}',
            ),
            Text(
              'Erschöpfung: ${preview.currentErschoepfung} → '
              '${preview.nextErschoepfung}',
            ),
            if (preview.regenerationNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...preview.regenerationNotes.map((note) => Text(note)),
            ],
          ],
        ),
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
            SwitchListTile(
              key: const ValueKey<String>('rest-au-enabled'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Ausruhen'),
              subtitle: const Text('3W6 Au, bei gelungener KO-Probe 3W6+6.'),
              value: _applyAuRecovery,
              onChanged: (value) {
                setState(() {
                  _applyAuRecovery = value;
                });
              },
            ),
            if (_applyAuRecovery) ...[
              const SizedBox(height: 8),
              _buildRollInput(
                label: 'Ausdauerwurf',
                keyPrefix: 'rest-au-roll',
                mode: _auRollMode,
                digitalValue: _auDigitalRoll,
                manualValue: _auManualRoll,
                helperText: '3W6',
                onModeChanged: (value) => setState(() => _auRollMode = value),
                onManualChanged: (value) =>
                    setState(() => _auManualRoll = value),
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
                onManualChanged: (value) =>
                    setState(() => _auKoManual = value),
                onDigitalRoll: () =>
                    setState(() => _auKoDigital = _rollSum(1, 20)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConditionSection(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              key: const ValueKey<String>('rest-conditions-enabled'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Zustände'),
              subtitle: const Text(
                'Baut Überanstrengung zuerst, danach Erschöpfung ab.',
              ),
              value: _applyConditionRecovery,
              onChanged: (value) {
                setState(() {
                  _applyConditionRecovery = value;
                });
              },
            ),
            if (_applyConditionRecovery) ...[
              const SizedBox(height: 8),
              SegmentedButton<RestConditionMode>(
                segments: const <ButtonSegment<RestConditionMode>>[
                  ButtonSegment<RestConditionMode>(
                    value: RestConditionMode.rast,
                    label: Text('Rast'),
                  ),
                  ButtonSegment<RestConditionMode>(
                    value: RestConditionMode.schlaf,
                    label: Text('Schlaf'),
                  ),
                ],
                selected: <RestConditionMode>{_conditionMode},
                onSelectionChanged: (selection) {
                  setState(() {
                    _conditionMode = selection.first;
                  });
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(child: Text('Stunden')),
                  IconButton(
                    tooltip: 'Stunden verringern',
                    onPressed: _conditionHours > 0
                        ? () => setState(() => _conditionHours--)
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Text('$_conditionHours'),
                  IconButton(
                    tooltip: 'Stunden erhöhen',
                    onPressed: () => setState(() => _conditionHours++),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
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
            SwitchListTile(
              key: const ValueKey<String>('rest-regeneration-enabled'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Regeneration'),
              subtitle: const Text(
                'Schlafphase oder Bettruhe mit LeP- und AsP-Regeneration.',
              ),
              value: _applyRegeneration,
              onChanged: (value) {
                setState(() {
                  _applyRegeneration = value;
                  if (!value) {
                    _regenerationMode = _RegenerationMode.none;
                  } else if (_regenerationMode == _RegenerationMode.none) {
                    _regenerationMode = _RegenerationMode.sleep;
                  }
                });
              },
            ),
            if (_applyRegeneration) ...[
              const SizedBox(height: 8),
              SegmentedButton<_RegenerationMode>(
                segments: const <ButtonSegment<_RegenerationMode>>[
                  ButtonSegment<_RegenerationMode>(
                    value: _RegenerationMode.sleep,
                    label: Text('Schlafphase'),
                  ),
                  ButtonSegment<_RegenerationMode>(
                    value: _RegenerationMode.bedRest,
                    label: Text('Bettruhe'),
                  ),
                ],
                selected: <_RegenerationMode>{_regenerationMode},
                onSelectionChanged: (selection) {
                  setState(() {
                    _regenerationMode = selection.first;
                  });
                },
              ),
              if (_regenerationMode == _RegenerationMode.bedRest)
                SwitchListTile(
                  key: const ValueKey<String>('rest-regeneration-second-phase'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Zweite Regenerationsphase anwenden'),
                  value: _applySecondPhase,
                  onChanged: (value) =>
                      setState(() => _applySecondPhase = value),
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
                onLepModeChanged: (value) => setState(() => _phase1LepMode = value),
                onLepManualChanged: (value) =>
                    setState(() => _phase1LepManual = value),
                onLepDigitalRoll: () =>
                    setState(() => _phase1LepDigital = _rollSum(1, 6)),
                onAspModeChanged: (value) => setState(() => _phase1AspMode = value),
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
          ],
        ),
      ),
    );
  }

  Widget _buildEnvironmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Äußere Umstände',
          style: Theme.of(context).textTheme.titleSmall,
        ),
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
          onChanged: (value) =>
              setState(() => _sleepSiteModifier = value ?? 0),
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
          Row(
            children: [
              OutlinedButton.icon(
                key: ValueKey<String>('$keyPrefix-digital-roll'),
                onPressed: onDigitalRoll,
                icon: const Icon(Icons.casino_outlined),
                label: const Text('Würfeln'),
              ),
              const SizedBox(width: 12),
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
          Row(
            children: [
              OutlinedButton.icon(
                key: ValueKey<String>('$keyPrefix-digital-roll'),
                onPressed: onDigitalRoll,
                icon: const Icon(Icons.casino_outlined),
                label: const Text('Würfeln'),
              ),
              const SizedBox(width: 12),
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
      final auBaseRoll = _resolveRoll(_auRollMode, _auDigitalRoll, _auManualRoll) ?? 0;
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
        hours: _conditionHours,
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
    await _saveAndClose(updated);
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

  Future<void> _saveAndClose(HeroState updated) async {
    await ref.read(heroActionsProvider).saveHeroState(widget.heroId, updated);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
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
