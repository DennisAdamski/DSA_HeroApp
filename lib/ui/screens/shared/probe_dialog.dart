import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/domain/trefferzonen.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/trefferzonen_rules.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/animated_dice_row.dart';

/// Oeffnet den gemeinsamen Dialog fuer die Wuerfel-Engine.
Future<void> showProbeDialog({
  required BuildContext context,
  required ResolvedProbeRequest request,
}) {
  return showAdaptiveDetailSheet<void>(
    context: context,
    builder: (_) => ProbeDialog(request: request),
  );
}

/// Gemeinsamer Dialog fuer digitale und manuelle Probeauswertung.
class ProbeDialog extends StatefulWidget {
  /// Erzeugt den Dialog fuer eine vollstaendig aufgeloeste Probe.
  const ProbeDialog({super.key, required this.request});

  /// Aufgeloeste Probe inklusive Zielwerte und Wuerfelkonfiguration.
  final ResolvedProbeRequest request;

  @override
  State<ProbeDialog> createState() => _ProbeDialogState();
}

class _ProbeDialogState extends State<ProbeDialog> {
  final DiceRoller _roller = RandomDiceRoller();
  final DiceRollController _diceController = DiceRollController();
  late ProbeRollMode _mode;
  late bool _specializationApplied;
  late final TextEditingController _modifierController;
  late final List<TextEditingController> _manualDiceControllers;
  ProbeResult? _result;
  List<int>? _lastDigitalValues;
  bool _isAnimating = false;

  // --- Trefferzonen ---
  final DiceRollController _trefferzonenDiceController = DiceRollController();
  TrefferzonenErgebnis? _trefferzonenErgebnis;
  bool _isTrefferzonenAnimating = false;
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
    // Kein Auto-Wurf beim Oeffnen – der Nutzer startet den Wurf manuell.
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

  // ---------------------------------------------------------------------------
  // Wurf-Logik
  // ---------------------------------------------------------------------------

  /// Startet den animierten Digitalwurf.
  void _startDigitalRoll() {
    if (_isAnimating) return;

    // Trefferzonen-Ergebnis bei neuem Schadenswurf zuruecksetzen.
    _resetTrefferzone();

    // Fester Wurf: keine Animation nötig.
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
      return;
    }

    // Würfelwerte vorausberechnen (werden erst nach Animation angezeigt).
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

  /// Wird vom AnimatedDiceRow aufgerufen, sobald die Animation abgeschlossen ist.
  void _onRollComplete() {
    if (!mounted) return;
    _applyDigitalResult();
    setState(() => _isAnimating = false);
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

  /// Aktualisiert das Ergebnis bei Modifikator-/Spezialisierungsänderungen,
  /// ohne einen neuen Digitalwurf auszulösen.
  void _liveRefresh() {
    if (_mode == ProbeRollMode.manual) {
      _updateManualResult();
      return;
    }
    // Digital: vorhandene Würfelwerte neu auswerten (kein neuer Wurf).
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
        // Wechsel zu Digital: Idle-Zustand, kein Autowurf.
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
    } else {
      _updateManualResult();
    }
  }

  // ---------------------------------------------------------------------------
  // Trefferzonen
  // ---------------------------------------------------------------------------

  void _rollTrefferzone() {
    if (_isTrefferzonenAnimating) return;
    final roll = math.Random().nextInt(20) + 1;
    final ergebnis = resolveTrefferzone(
      roll: roll,
      tabelle: humanoidTrefferzonenTabelle,
    );
    setState(() {
      _isTrefferzonenAnimating = true;
      _trefferzonenErgebnis = null;
    });
    _trefferzonenDiceController.startRoll([roll]);
    // Ergebnis wird nach Animation in _onTrefferzonenRollComplete gesetzt.
    _pendingTrefferzonenErgebnis = ergebnis;
  }

  TrefferzonenErgebnis? _pendingTrefferzonenErgebnis;

  void _onTrefferzonenRollComplete() {
    if (!mounted) return;
    setState(() {
      _isTrefferzonenAnimating = false;
      _trefferzonenErgebnis = _pendingTrefferzonenErgebnis;
      _pendingTrefferzonenErgebnis = null;
    });
  }

  void _resetTrefferzone() {
    _trefferzonenDiceController.reset();
    _trefferzonenErgebnis = null;
    _pendingTrefferzonenErgebnis = null;
    _isTrefferzonenAnimating = false;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

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
          label: Text(
            _mode == ProbeRollMode.digital ? 'Würfeln' : 'Auswerten',
          ),
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
        Chip(label: Text('Spezialisierung: +${widget.request.specializationBonus}')),
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

    // Manueller Modus: Texteingabe-Felder
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
    // Nur fuer Schadensproben mit vorhandenem Ergebnis anzeigen.
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
        Text(
          'Trefferzonen',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        // Würfelbereich
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
                  onPressed:
                      _isTrefferzonenAnimating ? null : _rollTrefferzone,
                  icon: const Icon(Icons.casino_outlined),
                  label: const Text('Trefferzone würfeln'),
                )
              : OutlinedButton.icon(
                  onPressed:
                      _isTrefferzonenAnimating ? null : _rollTrefferzone,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Neu würfeln'),
                ),
        ),
        // Ergebnis anzeigen
        if (ergebnis != null) ...[
          const SizedBox(height: 8),
          _buildTrefferzonenErgebnis(ergebnis),
        ],
      ],
    );
  }

  Widget _buildTrefferzonenErgebnis(TrefferzonenErgebnis ergebnis) {
    final eintrag = ergebnis.eintrag;
    final gsLabel = eintrag.gezielterSchlagMod > 0
        ? '+${eintrag.gezielterSchlagMod}'
        : '${eintrag.gezielterSchlagMod}';

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
              '${ergebnis.roll != ergebnis.effektiverRoll ? ' → ${ergebnis.effektiverRoll}' : ''}'
              '  •  Gezielter Schlag: $gsLabel',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              '1./2. Wunde',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 2),
            Text(eintrag.wundEffektBeschreibung),
            const SizedBox(height: 8),
            Text(
              '3. Wunde',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 2),
            Text(eintrag.dritteWundeBeschreibung),
          ],
        ),
      ),
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
      lines.add(
        'Zielwerte: ${result.effectiveTargetValues.join(', ')}',
      );
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
