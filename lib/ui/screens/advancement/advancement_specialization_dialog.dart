import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_options.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_specialization_rules.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/erwerb_dialog.dart';

/// Erfasst eine Spezialisierung als Erwerbsbefehl ohne unmittelbare Speicherung.
Future<HeroAdvancementEntry?> showAdvancementSpecializationDialog({
  required BuildContext context,
  required AdvancementSession session,
  required String talentId,
}) async {
  final rules = AdvancementContext(
    hero: session.preview,
    catalog: session.catalog,
  );
  final choices = advancementSpecializationChoices(rules, talentId);
  final old = session.preview.talents[talentId]!;
  final owned = advancementTalentSpecializations(old);
  final available = choices.where((name) => !owned.contains(name)).toList();
  final name = await showAdaptiveInputDialog<String>(
    context: context,
    builder: (_) => _SpecializationNameDialog(
      choices: available,
      useSelection: choices.isNotEmpty,
    ),
  );
  if (name == null || !context.mounted) return null;
  final options = {'action': 'specialization', 'specialization': name.trim()};
  final option = resolveTalentSpecialization(rules, talentId, options)!;
  if (option.unavailableReason != null) {
    throw StateError(option.unavailableReason!);
  }
  final result = await showErwerbDialog(
    context: context,
    bezeichnung: option.label,
    vorgeschlageneApKosten: option.apCost,
    kostenHinweis: option.complexityHint,
    verfuegbareAp: session.preview.apAvailable,
    episch: session.preview.isEpisch,
    lehrmeisterUeblich: true,
    lehrmeisterVerdoppeltOhneIhn: true,
    confirmLabel: 'Vormerken',
  );
  if (result == null) return null;
  return HeroAdvancementEntry(
    id: const Uuid().v4(),
    sessionId: session.sessionId,
    createdAt: DateTime.now().toUtc(),
    kind: AdvancementKind.talent,
    targetId: talentId,
    label: option.label,
    apCost: result.apKosten,
    options: {
      ...option.options,
      if (result.lehrmeisterTaW != null)
        'lehrmeisterTaW': '${result.lehrmeisterTaW}',
      if (result.dukaten != null) 'dukaten': '${result.dukaten}',
    },
  );
}

// Die Route besitzt den Controller bis zum Ende ihrer Schließanimation.
class _SpecializationNameDialog extends StatefulWidget {
  const _SpecializationNameDialog({
    required this.choices,
    required this.useSelection,
  });
  final List<String> choices;
  final bool useSelection;

  @override
  State<_SpecializationNameDialog> createState() =>
      _SpecializationNameDialogState();
}

class _SpecializationNameDialogState extends State<_SpecializationNameDialog> {
  final _controller = TextEditingController();
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.choices.firstOrNull;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Spezialisierung lernen'),
    content: !widget.useSelection
        ? TextField(
            key: const ValueKey('advancement-specialization-name'),
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Spezialisierung'),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          )
        : DropdownButtonFormField<String>(
            initialValue: _selected,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Waffenkategorie'),
            items: [
              for (final value in widget.choices)
                DropdownMenuItem(value: value, child: Text(value)),
            ],
            onChanged: (value) => _selected = value,
          ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Abbrechen'),
      ),
      FilledButton(
        onPressed: widget.useSelection && widget.choices.isEmpty
            ? null
            : () {
                Navigator.of(context)
                    .pop(widget.useSelection ? _selected : _controller.text);
              },
        child: const Text('Weiter'),
      ),
    ],
  );
}
