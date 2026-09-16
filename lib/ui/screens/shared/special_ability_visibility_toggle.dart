import 'package:flutter/material.dart';

/// Speichert die Anzeigepräferenz mit Fehlerrückmeldung und Doppelklickschutz.
class SpecialAbilityVisibilityToggle extends StatefulWidget {
  /// Bindet den Schalter an die Präferenz des aktuell angezeigten Helden.
  const SpecialAbilityVisibilityToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// Ob unpassende Bereiche zusätzlich angezeigt werden.
  final bool value;

  /// Persistiert die Einstellung; `null` sperrt den Schalter beim Speichern.
  final Future<void> Function(bool)? onChanged;

  @override
  State<SpecialAbilityVisibilityToggle> createState() =>
      _SpecialAbilityVisibilityToggleState();
}

class _SpecialAbilityVisibilityToggleState
    extends State<SpecialAbilityVisibilityToggle> {
  bool _saving = false;

  // Fehler dürfen die angezeigte Einstellung nicht vom gespeicherten Wert lösen.
  Future<void> _change(bool value) async {
    setState(() => _saving = true);
    try {
      await widget.onChanged?.call(value);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Anzeige konnte nicht gespeichert werden: $error'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SwitchListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    title: const Text('Unpassende Sonderfertigkeiten anzeigen'),
    value: widget.value,
    onChanged: _saving || widget.onChanged == null ? null : _change,
  );
}
