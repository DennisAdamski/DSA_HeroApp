import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';

/// Zeigt einen Mehrfachauswahl-Dialog fuer Kampf-Spezialisierungen.
///
/// Gibt die sortierte Liste der ausgewaehlten Optionen zurueck oder `null`
/// bei Abbruch.
Future<List<String>?> showCombatSpecializationDialog({
  required BuildContext context,
  required String title,
  required List<String> options,
  required List<String> initialSelected,
}) {
  return showAdaptiveDetailSheet<List<String>>(
    context: context,
    builder: (_) => _CombatSpecializationDialog(
      title: title,
      options: options,
      initialSelected: initialSelected,
    ),
  );
}

class _CombatSpecializationDialog extends StatefulWidget {
  const _CombatSpecializationDialog({
    required this.title,
    required this.options,
    required this.initialSelected,
  });

  final String title;
  final List<String> options;
  final List<String> initialSelected;

  @override
  State<_CombatSpecializationDialog> createState() =>
      _CombatSpecializationDialogState();
}

class _CombatSpecializationDialogState
    extends State<_CombatSpecializationDialog> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = <String>{...widget.initialSelected};
  }

  List<String> _normalized() {
    return _selected
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList()
      ..sort();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: kDialogWidthSmall,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: widget.options
                .map(
                  (entry) => CheckboxListTile(
                    value: _selected.contains(entry),
                    title: Text(entry),
                    dense: true,
                    onChanged: (enabled) {
                      setState(() {
                        if (enabled == true) {
                          _selected.add(entry);
                        } else {
                          _selected.remove(entry);
                        }
                      });
                    },
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_normalized()),
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}
