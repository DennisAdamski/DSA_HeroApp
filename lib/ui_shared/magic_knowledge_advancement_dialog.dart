import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_options.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_magic_knowledge_rules.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/magic_status_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/tradition_rules.dart';

/// Erfasst einen Erwerbsnachweis ohne den Helden oder die Sitzung zu speichern.
/// [lockSource] bindet den bezahlten Einrichtungsweg an den Neuerwerb.
Future<HeroAdvancementEntry?> showMagicKnowledgeAdvancementDialog({
  required BuildContext context,
  required AdvancementSession session,
  required AdvancementOption option,
  bool lockSource = false,
  bool lockTradition = false,
}) => showDialog<HeroAdvancementEntry>(
  context: context,
  builder: (_) => _MagicKnowledgeDialog(
    session: session,
    option: option,
    lockSource: lockSource,
    lockTradition: lockTradition,
  ),
);

class _MagicKnowledgeDialog extends StatefulWidget {
  const _MagicKnowledgeDialog({
    required this.session,
    required this.option,
    required this.lockSource,
    required this.lockTradition,
  });
  final AdvancementSession session;
  final AdvancementOption option;
  final bool lockSource;
  final bool lockTradition;

  @override
  State<_MagicKnowledgeDialog> createState() => _MagicKnowledgeDialogState();
}

class _MagicKnowledgeDialogState extends State<_MagicKnowledgeDialog> {
  late final _options = Map<String, String>.from(widget.option.options);
  final _reason = TextEditingController();
  final _cost = TextEditingController();
  late final _target = TextEditingController(
    text: widget.option.currentValue < 0
        ? '3'
        : '${widget.option.currentValue + 1}',
  );
  bool _meister = false;

  bool get _representation =>
      widget.option.kind == AdvancementKind.representation;
  bool get _raise => !_representation && widget.option.currentValue >= 0;

  @override
  void dispose() {
    _reason.dispose();
    _cost.dispose();
    _target.dispose();
    super.dispose();
  }

  // Jede Bestätigung wird im Replay wieder gegen denselben Regelstand geprüft.
  Map<String, String> _decision() => {
    ..._options,
    'source': widget.lockSource
        ? 'acquisition'
        : _options['source'] ?? 'acquisition',
    if (_meister) 'meisterentscheid': 'true',
    if (_meister) 'meisterentscheidReason': _reason.text.trim(),
    if (_cost.text.trim().isNotEmpty) 'customApCost': _cost.text.trim(),
    if (!_representation) 'targetValue': _target.text,
    if (!_raise && !_representation) 'startValue': _target.text,
  };

  // Die Oberfläche stellt Befunde dar; alle Kosten und Grenzen liefert das Regelmodul.
  @override
  Widget build(BuildContext context) {
    final decision = _decision();
    final traditions = _representation
        ? traditionenFuerRepraesentation(widget.option.targetId)
        : const <TraditionDef>[];
    final rules = AdvancementContext(
      hero: widget.session.preview,
      catalog: widget.session.catalog,
    );
    final resolved = resolveMagicKnowledge(
      rules,
      widget.option.kind,
      widget.option.targetId,
      decision,
    );
    final cost = int.tryParse(_cost.text.trim()) ?? resolved?.apCost;
    String? reason = resolved?.unavailableReason;
    final target = int.tryParse(_target.text);
    HeroAdvancementEntry? entry;
    if (resolved != null && cost != null) {
      entry = HeroAdvancementEntry(
        id: const Uuid().v4(),
        sessionId: widget.session.sessionId,
        createdAt: DateTime.now().toUtc(),
        kind: widget.option.kind,
        targetId: widget.option.targetId,
        label: resolved.label,
        fromValue: _representation ? null : widget.option.currentValue,
        toValue: _representation ? null : target,
        apCost: cost,
        options: decision,
      );
      try {
        validateMagicKnowledgeEntry(widget.session.preview, entry, resolved);
      } on StateError catch (error) {
        reason = error.message;
      }
    }
    final invalid =
        reason != null ||
        cost == null ||
        (!_representation && target == null) ||
        (_meister && _reason.text.trim().isEmpty);
    return AlertDialog(
      title: Text(widget.option.label),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (traditions.length > 1)
                DropdownButtonFormField<String>(
                  key: const ValueKey('magic-knowledge-tradition'),
                  isExpanded: true,
                  initialValue: _options['traditionId'] ?? traditions.first.id,
                  decoration: const InputDecoration(labelText: 'Tradition'),
                  items: [
                    for (final tradition in traditions)
                      DropdownMenuItem(
                        value: tradition.id,
                        child: Text(tradition.name),
                      ),
                  ],
                  onChanged: widget.lockTradition
                      ? null
                      : (value) =>
                            setState(() => _options['traditionId'] = value!),
                ),
              if (!_raise && widget.lockSource)
                const Text('Erwerbsgrund: Neu erlernen'),
              if (!_raise && !widget.lockSource)
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: decision['source'],
                  decoration: const InputDecoration(labelText: 'Erwerbsgrund'),
                  items: const [
                    DropdownMenuItem(
                      value: 'acquisition',
                      child: Text('Neu erlernen'),
                    ),
                    DropdownMenuItem(
                      value: 'creation',
                      child: Text('Bei Erschaffung enthalten'),
                    ),
                    DropdownMenuItem(
                      value: 'existing',
                      child: Text('Bereits vorhanden'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _options['source'] = value!),
                ),
              if (!_raise &&
                  detectMagicStatus(
                        widget.session.preview,
                        widget.session.catalog,
                      ) ==
                      null)
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _options['magicStatus'],
                  decoration: const InputDecoration(
                    labelText: 'Zaubererstatus klären',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'full',
                      child: Text('Vollzauberer'),
                    ),
                    DropdownMenuItem(
                      value: 'half',
                      child: Text('Halbzauberer'),
                    ),
                    DropdownMenuItem(
                      value: 'quarter',
                      child: Text('Viertelzauberer'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _options['magicStatus'] = value!),
                ),
              if (_raise)
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _options['learningMethod'] ?? 'regular',
                  decoration: const InputDecoration(labelText: 'Lernweg'),
                  items: const [
                    DropdownMenuItem(
                      value: 'regular',
                      child: Text('Normales Lernen'),
                    ),
                    DropdownMenuItem(
                      value: 'teacher',
                      child: Text('Mit Lehrmeister'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _options['learningMethod'] = value!),
                ),
              if (!_representation)
                TextField(
                  key: const ValueKey('magic-knowledge-target'),
                  controller: _target,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _raise ? 'Ziel-RkW' : 'Start-RkW',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              if (decision['source'] == 'acquisition' || _raise) ...[
                _confirmation(
                  'teacherConfirmed',
                  _representation
                      ? 'Lehrmeister bestätigt'
                      : 'Lehrmeister vorhanden',
                ),
                if (_representation)
                  _confirmation(
                    'trainingYearConfirmed',
                    'Mindestens ein Jahr intensive Ausbildung',
                  ),
                if (!_representation && _raise)
                  _confirmation('bookConfirmed', 'Geeignetes Buch vorhanden'),
                if (!_representation && !_raise)
                  _confirmation(
                    'permissionConfirmed',
                    'Meistererlaubnis für die fremde Ritualkenntnis',
                  ),
              ],
              for (final check in resolved?.requirements ?? [])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('${check.sollText}: ${check.istText}'),
                ),
              if (resolved?.complexityHint != null)
                Text(resolved!.complexityHint!),
              Text(cost == null ? 'AP-Kosten noch offen' : 'Kosten: $cost AP'),
              Text('${widget.session.preview.apAvailable} AP verfügbar'),
              if (reason != null) Text(reason),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Abweichender Meisterentscheid'),
                value: _meister,
                onChanged: (value) => setState(() => _meister = value!),
              ),
              if (_meister) ...[
                TextField(
                  controller: _reason,
                  decoration: const InputDecoration(
                    labelText: 'Begründung des Meisterentscheids',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                TextField(
                  controller: _cost,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Abweichende AP-Kosten (optional)',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: invalid ? null : () => Navigator.pop(context, entry),
          child: const Text('Vormerken'),
        ),
      ],
    );
  }

  // Bestätigungen bleiben als einzelne Nachweise im Planungsbefehl erhalten.
  Widget _confirmation(String key, String label) => CheckboxListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    value: _options[key] == 'true',
    onChanged: (value) => setState(() => _options[key] = '$value'),
  );
}
