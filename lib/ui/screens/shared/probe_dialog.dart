import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';

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
  late ProbeRollMode _mode;
  late bool _specializationApplied;
  late final TextEditingController _modifierController;
  late final List<TextEditingController> _manualDiceControllers;
  ProbeResult? _result;

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
    _rollDigital();
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

  void _rollDigital() {
    final input = createDigitalProbeRollInput(
      widget.request,
      roller: _roller,
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

  void _setMode(ProbeRollMode mode) {
    if (_mode == mode) {
      return;
    }
    setState(() {
      _mode = mode;
      if (_mode == ProbeRollMode.digital) {
        _rollDigital();
      } else {
        _updateManualResult();
      }
    });
  }

  void _refreshResult() {
    if (_mode == ProbeRollMode.digital) {
      _rollDigital();
      return;
    }
    _updateManualResult();
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
              const SizedBox(height: 12),
              _buildDiceSection(),
              const SizedBox(height: 12),
              _buildResultSection(result),
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
          onPressed: _refreshResult,
          icon: const Icon(Icons.casino_outlined),
          label: Text(
            _mode == ProbeRollMode.digital ? 'Neu würfeln' : 'Auswerten',
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
          onChanged: (_) => _refreshResult(),
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
              _refreshResult();
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
      final values = _result?.diceValues ?? const <int>[];
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List<Widget>.generate(widget.request.diceSpec.count, (
              index,
            ) {
              final value = index < values.length ? values[index].toString() : '?';
              return Chip(
                label: Text(
                  'W${widget.request.diceSpec.sides} #${index + 1}: $value',
                ),
              );
            }),
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

  Widget _buildResultSection(ProbeResult? result) {
    if (result == null) {
      return const Text('Noch keine gültige Auswertung vorhanden.');
    }

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

    return Card(
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
    );
  }
}
