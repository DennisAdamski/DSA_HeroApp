import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/domain/trefferzonen.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/trefferzonen_rules.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/animated_dice_row.dart';

/// Oeffnet den gemeinsamen Dialog fuer die Wuerfel-Engine.
Future<void> showProbeDialog({
  required BuildContext context,
  required ResolvedProbeRequest request,
  void Function(ProbeResult result)? onResolved,
  void Function(DiceLogEntry entry)? onDiceLogEntry,
}) {
  return showAdaptiveDetailSheet<void>(
    context: context,
    builder: (_) => ProbeDialog(
      request: request,
      onResolved: onResolved,
      onDiceLogEntry: onDiceLogEntry,
    ),
  );
}

/// Gemeinsamer Dialog fuer digitale und manuelle Probeauswertung.
class ProbeDialog extends StatefulWidget {
  /// Erzeugt den Dialog fuer eine vollstaendig aufgeloeste Probe.
  const ProbeDialog({
    super.key,
    required this.request,
    this.rollTrefferzone,
    this.onResolved,
    this.onDiceLogEntry,
  });

  /// Aufgeloeste Probe inklusive Zielwerte und Wuerfelkonfiguration.
  final ResolvedProbeRequest request;

  /// Optionale Test-Hook fuer deterministische Trefferzonen-Wuerfe.
  final int Function()? rollTrefferzone;

  /// Wird einmalig pro abgeschlossener Probe aufgerufen.
  ///
  /// Feuert nach einem digitalen Wurf (Animation beendet), nach dem Klick
  /// auf "Auswerten" im manuellen Modus und beim festen Wurf
  /// (`fixedRollTotal`). Reine Modifikator-Aenderungen ("live refresh")
  /// loesen keinen Aufruf aus.
  final void Function(ProbeResult result)? onResolved;

  /// Wird fuer Nebenwuerfe innerhalb des Dialogs aufgerufen.
  final void Function(DiceLogEntry entry)? onDiceLogEntry;

  @override
  State<ProbeDialog> createState() => _ProbeDialogState();
}

class _ProbeDialogState extends State<ProbeDialog> {
  final DiceRoller _roller = RandomDiceRoller();
  final DiceRollController _diceController = DiceRollController();
  final DiceRollController _trefferzonenDiceController = DiceRollController();
  late ProbeRollMode _mode;
  late bool _specializationApplied;
  late final TextEditingController _modifierController;
  late final List<TextEditingController> _manualDiceControllers;
  ProbeResult? _result;
  List<int>? _lastDigitalValues;
  bool _isAnimating = false;

  TrefferzonenErgebnis? _trefferzonenErgebnis;
  TrefferzonenErgebnis? _pendingTrefferzonenErgebnis;
  int? _pendingTrefferzonenRoll;
  bool _isTrefferzonenAnimating = false;
  int _trefferzonenWunden = 1;

  static const DiceSpec _trefferzonenDiceSpec = DiceSpec(count: 1, sides: 20);

  @override
  void initState() {
    super.initState();
    _mode = ProbeRollMode.digital;
    _specializationApplied = widget.request.initialSpecializationApplied;
    _modifierController = TextEditingController(
      text: widget.request.initialSituationalModifier.toString(),
    );
    _manualDiceControllers = List<TextEditingController>.generate(
      widget.request.diceSpec.count,
      (_) => TextEditingController(),
    );
  }

  @override
  void dispose() {
    _modifierController.dispose();
    for (final controller in _manualDiceControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  int get _situationalModifier =>
      int.tryParse(_modifierController.text.trim()) ?? 0;

  /// Startet den animierten Digitalwurf.
  void _startDigitalRoll() {
    if (_isAnimating) return;

    _resetTrefferzone();

    if (widget.request.fixedRollTotal != null) {
      final input = createDigitalProbeRollInput(
        widget.request,
        roller: _roller,
        situationalModifier: _situationalModifier,
        specializationApplied: _specializationApplied,
      );
      setState(() {
        _result = evaluateProbe(widget.request, input);
      });
      _notifyResolved();
      return;
    }

    final input = createDigitalProbeRollInput(
      widget.request,
      roller: _roller,
      situationalModifier: _situationalModifier,
      specializationApplied: _specializationApplied,
    );
    _lastDigitalValues = input.diceValues.toList();
    setState(() {
      _isAnimating = true;
      _result = null;
    });
    _diceController.startRoll(_lastDigitalValues!);
  }

  /// Wird vom [AnimatedDiceRow] aufgerufen, sobald die Animation endet.
  void _onRollComplete() {
    if (!mounted) return;
    _applyDigitalResult();
    setState(() {
      _isAnimating = false;
    });
    _notifyResolved();
  }

  /// Feuert `onResolved` einmalig fuer das aktuelle Ergebnis.
  void _notifyResolved() {
    final result = _result;
    final callback = widget.onResolved;
    if (result == null || callback == null) return;
    callback(result);
  }

  /// Wertet den letzten Digitalwurf mit den aktuellen Modifikatoren aus.
  void _applyDigitalResult() {
    final values = _lastDigitalValues;
    if (values == null) return;

    final input = ProbeRollInput(
      mode: ProbeRollMode.digital,
      diceValues: List<int>.unmodifiable(values),
      situationalModifier: _situationalModifier,
      specializationApplied: _specializationApplied,
    );
    setState(() {
      _result = evaluateProbe(widget.request, input);
    });
  }

  void _updateManualResult() {
    final values = <int>[];
    for (final controller in _manualDiceControllers) {
      final parsed = int.tryParse(controller.text.trim());
      if (parsed == null) {
        setState(() {
          _result = null;
        });
        return;
      }
      values.add(parsed);
    }

    final input = ProbeRollInput(
      mode: ProbeRollMode.manual,
      diceValues: List<int>.unmodifiable(values),
      situationalModifier: _situationalModifier,
      specializationApplied: _specializationApplied,
    );
    if (!isValidManualProbeInput(widget.request, input)) {
      setState(() {
        _result = null;
      });
      return;
    }

    setState(() {
      _result = evaluateProbe(widget.request, input);
    });
  }

  /// Aktualisiert das Ergebnis ohne einen neuen Digitalwurf auszulösen.
  void _liveRefresh() {
    if (_mode == ProbeRollMode.manual) {
      _updateManualResult();
      return;
    }

    if (_lastDigitalValues != null && !_isAnimating) {
      _applyDigitalResult();
    }
  }

  void _setMode(ProbeRollMode mode) {
    if (_mode == mode) return;
    if (mode == ProbeRollMode.manual) {
      _diceController.reset();
    }
    setState(() {
      _mode = mode;
      _isAnimating = false;
      if (mode != ProbeRollMode.manual) {
        _result = null;
      }
    });
    if (mode == ProbeRollMode.manual) {
      _updateManualResult();
    }
  }

  void _onActionButton() {
    if (_mode == ProbeRollMode.digital) {
      _startDigitalRoll();
      return;
    }
    _updateManualResult();
    _notifyResolved();
  }

  int _nextTrefferzonenRoll() =>
      widget.rollTrefferzone?.call() ?? math.Random().nextInt(20) + 1;

  void _setTrefferzonenWunden(int nextValue) {
    final clamped = nextValue.clamp(1, maxWundenProZone);
    if (clamped == _trefferzonenWunden) return;
    setState(() {
      _trefferzonenWunden = clamped;
    });
  }

  void _rollTrefferzone() {
    if (_isTrefferzonenAnimating) return;
    final roll = _nextTrefferzonenRoll();
    final ergebnis = resolveTrefferzone(
      roll: roll,
      tabelle: humanoidTrefferzonenTabelle,
    );
    setState(() {
      _isTrefferzonenAnimating = true;
      _trefferzonenWunden = 1;
      _trefferzonenErgebnis = null;
    });
    _trefferzonenDiceController.startRoll([roll]);
    _pendingTrefferzonenErgebnis = ergebnis;
    _pendingTrefferzonenRoll = roll;
  }

  void _onTrefferzonenRollComplete() {
    if (!mounted) return;
    final ergebnis = _pendingTrefferzonenErgebnis;
    final roll = _pendingTrefferzonenRoll;
    setState(() {
      _isTrefferzonenAnimating = false;
      _trefferzonenErgebnis = ergebnis;
      _pendingTrefferzonenErgebnis = null;
      _pendingTrefferzonenRoll = null;
    });
    if (ergebnis != null && roll != null) {
      widget.onDiceLogEntry?.call(
        diceLogEntryFromRoll(
          title: 'Trefferzone',
          subtitle: ergebnis.label,
          diceValues: <int>[roll],
          diceSpec: _trefferzonenDiceSpec,
        ),
      );
    }
  }

  void _resetTrefferzone() {
    _trefferzonenDiceController.reset();
    _trefferzonenWunden = 1;
    _trefferzonenErgebnis = null;
    _pendingTrefferzonenErgebnis = null;
    _pendingTrefferzonenRoll = null;
    _isTrefferzonenAnimating = false;
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return AlertDialog(
      title: Text(widget.request.title),
      content: SizedBox(
        width: kDialogWidthMedium,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.request.subtitle.trim().isNotEmpty)
                Text(widget.request.subtitle),
              const SizedBox(height: 8),
              Text(
                widget.request.ruleHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              _buildSummary(),
              const SizedBox(height: 12),
              _buildControls(),
              const SizedBox(height: 16),
              _buildDiceSection(),
              const SizedBox(height: 12),
              _buildResultSection(result),
              _buildTrefferzonenSection(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
        FilledButton.icon(
          onPressed: _isAnimating ? null : _onActionButton,
          icon: const Icon(Icons.casino_outlined),
          label: Text(_mode == ProbeRollMode.digital ? 'Würfeln' : 'Auswerten'),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    final chips = <Widget>[
      Chip(label: Text(widget.request.diceSpec.label)),
      for (final target in widget.request.targets)
        Chip(label: Text('${target.label}: ${target.value}')),
      if (widget.request.usesCompensationPool)
        Chip(label: Text('Pool: ${widget.request.basePool}')),
      if (widget.request.supportsSpecialization)
        Chip(
          label: Text(
            'Spezialisierung: +${widget.request.specializationBonus}',
          ),
        ),
    ];
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _buildControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<ProbeRollMode>(
          segments: const <ButtonSegment<ProbeRollMode>>[
            ButtonSegment<ProbeRollMode>(
              value: ProbeRollMode.digital,
              label: Text('Digital'),
              icon: Icon(Icons.casino_outlined),
            ),
            ButtonSegment<ProbeRollMode>(
              value: ProbeRollMode.manual,
              label: Text('Manuell'),
              icon: Icon(Icons.edit_outlined),
            ),
          ],
          selected: <ProbeRollMode>{_mode},
          onSelectionChanged: (selection) => _setMode(selection.first),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey<String>('probe-dialog-modifier'),
          controller: _modifierController,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'-?[0-9]*')),
          ],
          decoration: const InputDecoration(
            labelText: 'Situativer Modifikator',
            border: OutlineInputBorder(),
            helperText: 'Positive Werte erleichtern, negative erschweren.',
          ),
          onChanged: (_) => _liveRefresh(),
        ),
        if (widget.request.supportsSpecialization) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            key: const ValueKey<String>('probe-dialog-specialization'),
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Spezialisierung anwenden (+${widget.request.specializationBonus})',
            ),
            value: _specializationApplied,
            onChanged: (value) {
              setState(() {
                _specializationApplied = value;
              });
              _liveRefresh();
            },
          ),
        ],
      ],
    );
  }

  Widget _buildDiceSection() {
    if (widget.request.fixedRollTotal != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Fester Wurf: ${widget.request.fixedRollTotal}',
            key: const ValueKey<String>('probe-dialog-fixed-roll'),
          ),
        ),
      );
    }

    if (_mode == ProbeRollMode.digital) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Center(
            child: AnimatedDiceRow(
              diceSpec: widget.request.diceSpec,
              controller: _diceController,
              onRollComplete: _onRollComplete,
              probeType: widget.request.type,
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List<Widget>.generate(_manualDiceControllers.length, (
            index,
          ) {
            return SizedBox(
              width: 96,
              child: TextField(
                key: ValueKey<String>('probe-dialog-die-$index'),
                controller: _manualDiceControllers[index],
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9]*')),
                ],
                decoration: InputDecoration(
                  labelText: 'Wurf ${index + 1}',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => _updateManualResult(),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTrefferzonenSection() {
    if (widget.request.type != ProbeType.damage || _result == null) {
      return const SizedBox.shrink();
    }

    final ergebnis = _trefferzonenErgebnis;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        Text('Trefferzonen', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Center(
              child: AnimatedDiceRow(
                diceSpec: _trefferzonenDiceSpec,
                controller: _trefferzonenDiceController,
                onRollComplete: _onTrefferzonenRollComplete,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: ergebnis == null
              ? OutlinedButton.icon(
                  onPressed: _isTrefferzonenAnimating ? null : _rollTrefferzone,
                  icon: const Icon(Icons.casino_outlined),
                  label: const Text('Trefferzone würfeln'),
                )
              : OutlinedButton.icon(
                  onPressed: _isTrefferzonenAnimating ? null : _rollTrefferzone,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Neu würfeln'),
                ),
        ),
        if (ergebnis != null) ...[
          const SizedBox(height: 8),
          _buildTrefferzonenErgebnis(ergebnis),
        ],
      ],
    );
  }

  Widget _buildTrefferzonenErgebnis(TrefferzonenErgebnis ergebnis) {
    final eintrag = ergebnis.eintrag;
    final hatZusatzwuerfe =
        eintrag.zusatzwuerfeErsteBisDritteWunde.isNotEmpty ||
        eintrag.zusatzwuerfeDritteWunde.isNotEmpty;
    final zusatzwuerfe = resolveTrefferzonenZusatzwuerfe(
      eintrag: eintrag,
      wunden: _trefferzonenWunden,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ergebnis.label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'W20: ${ergebnis.roll}'
              '${ergebnis.roll != ergebnis.effektiverRoll ? ' → ${ergebnis.effektiverRoll}' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text('1./2. Wunde', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 2),
            Text(eintrag.wundEffektBeschreibung),
            const SizedBox(height: 8),
            Text('3. Wunde', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 2),
            Text(eintrag.dritteWundeBeschreibung),
            if (hatZusatzwuerfe) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              _buildTrefferzonenWundenStepper(),
              const SizedBox(height: 12),
              for (final zusatzwurf in zusatzwuerfe) ...[
                _TrefferzonenZusatzwurfCard(
                  key: ValueKey<String>(
                    'trefferzonen-zusatz-${zusatzwurf.label}-${zusatzwurf.diceSpec.label}',
                  ),
                  zusatzwurf: zusatzwurf,
                  onDiceLogEntry: widget.onDiceLogEntry,
                ),
                const SizedBox(height: 8),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrefferzonenWundenStepper() {
    final canDecrease = _trefferzonenWunden > 1;
    final canIncrease = _trefferzonenWunden < maxWundenProZone;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Wunden durch Treffer',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 2),
              Text(
                'Steuert die separat zu würfelnden W6-Effekte.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '$_trefferzonenWunden',
                  key: const ValueKey<String>('trefferzonen-wunden-value'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Wunden erhöhen',
                    visualDensity: VisualDensity.compact,
                    onPressed: canIncrease
                        ? () => _setTrefferzonenWunden(_trefferzonenWunden + 1)
                        : null,
                    icon: const Icon(Icons.arrow_drop_up),
                  ),
                  IconButton(
                    tooltip: 'Wunden verringern',
                    visualDensity: VisualDensity.compact,
                    onPressed: canDecrease
                        ? () => _setTrefferzonenWunden(_trefferzonenWunden - 1)
                        : null,
                    icon: const Icon(Icons.arrow_drop_down),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultSection(ProbeResult? result) {
    if (result == null) return const SizedBox.shrink();

    final lines = <String>[];
    if (widget.request.usesCompensationPool) {
      lines.add('Pool Start: ${result.compensationPoolStart}');
      if (result.appliedAttributePenalty != 0) {
        lines.add('Attributmalus: ${result.appliedAttributePenalty}');
      }
      lines.add('Verbleibender Pool: ${result.remainingPool}');
    }

    if (widget.request.usesSummedTotal) {
      lines.add('Gesamtergebnis: ${result.total}');
    } else if (widget.request.usesBinaryCheck) {
      lines.add('Wurf: ${result.diceValues.join(', ')}');
      lines.add('Zielwert: ${result.effectiveTargetValues.join(', ')}');
    } else {
      lines.add('Würfe: ${result.diceValues.join(', ')}');
      lines.add('Zielwerte: ${result.effectiveTargetValues.join(', ')}');
      lines.add('Überschreitungen: ${result.targetOverflows.join(', ')}');
    }

    if (result.automaticOutcome != AutomaticOutcome.none) {
      lines.add(
        result.automaticOutcome == AutomaticOutcome.success
            ? 'Automatischer Erfolg'
            : 'Automatisches Misslingen',
      );
    }
    if (result.specialExperience) {
      lines.add('Spezielle Erfahrung');
    }

    final headline = widget.request.usesSummedTotal
        ? 'Ergebnis'
        : (result.success ? 'Erfolg' : 'Misslungen');

    return AnimatedOpacity(
      opacity: 1,
      duration: const Duration(milliseconds: 300),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headline,
                key: const ValueKey<String>('probe-dialog-result-headline'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...lines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(line),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Separater W6-Wurf fuer Trefferzonen-Effekte.
class _TrefferzonenZusatzwurfCard extends StatefulWidget {
  const _TrefferzonenZusatzwurfCard({
    super.key,
    required this.zusatzwurf,
    this.onDiceLogEntry,
  });

  final TrefferzonenZusatzwurfErgebnis zusatzwurf;
  final void Function(DiceLogEntry entry)? onDiceLogEntry;

  @override
  State<_TrefferzonenZusatzwurfCard> createState() =>
      _TrefferzonenZusatzwurfCardState();
}

class _TrefferzonenZusatzwurfCardState
    extends State<_TrefferzonenZusatzwurfCard> {
  final DiceRollController _controller = DiceRollController();
  final DiceRoller _roller = RandomDiceRoller();
  List<int>? _values;
  bool _isAnimating = false;

  void _roll() {
    if (_isAnimating) return;
    final spec = widget.zusatzwurf.diceSpec;
    final values = List<int>.generate(
      spec.count,
      (_) => _roller.rollDie(spec.sides),
    );
    setState(() {
      _values = values;
      _isAnimating = true;
    });
    _controller.startRoll(values);
  }

  void _onRollComplete() {
    if (!mounted) return;
    setState(() {
      _isAnimating = false;
    });
    final values = _values;
    if (values == null) {
      return;
    }
    widget.onDiceLogEntry?.call(
      diceLogEntryFromRoll(
        title: widget.zusatzwurf.label,
        subtitle: widget.zusatzwurf.diceSpec.label,
        diceValues: values,
        diceSpec: widget.zusatzwurf.diceSpec,
      ),
    );
  }

  int _computeTotal() {
    final values = _values;
    if (values == null) {
      return widget.zusatzwurf.diceSpec.modifier;
    }
    return values.fold<int>(0, (sum, value) => sum + value) +
        widget.zusatzwurf.diceSpec.modifier;
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.zusatzwurf.diceSpec;
    final hasResult = _values != null;
    final modifierLabel = spec.modifier == 0
        ? ''
        : ' (${spec.modifier >= 0 ? '+' : ''}${spec.modifier})';

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.zusatzwurf.label,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 2),
            Text(
              widget.zusatzwurf.detailText,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Center(
              child: AnimatedDiceRow(
                diceSpec: spec,
                controller: _controller,
                onRollComplete: _onRollComplete,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.center,
              child: OutlinedButton.icon(
                onPressed: _isAnimating ? null : _roll,
                icon: Icon(hasResult ? Icons.refresh : Icons.casino_outlined),
                label: Text(
                  hasResult
                      ? '${spec.label} neu würfeln'
                      : '${spec.label} würfeln',
                ),
              ),
            ),
            if (hasResult) ...[
              const SizedBox(height: 8),
              Text('Würfe: ${_values!.join(', ')}$modifierLabel'),
              Text('Gesamt: ${_computeTotal()}'),
            ],
          ],
        ),
      ),
    );
  }
}
