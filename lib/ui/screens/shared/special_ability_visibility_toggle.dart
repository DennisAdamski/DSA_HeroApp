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
    extends State<SpecialAbilityVisibilityToggle>
    with _SpeichertAnzeige<SpecialAbilityVisibilityToggle> {
  @override
  Future<void> Function(bool)? get _onChanged => widget.onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    title: const Text('Unpassende Sonderfertigkeiten anzeigen'),
    value: widget.value,
    onChanged: _saving || widget.onChanged == null ? null : _change,
  );
}

/// Dieselbe Präferenz als Filterchip, neben anderen Filtern einer Liste.
///
/// Im Unterschied zu einem reinen Ansichtsfilter wird der Wert am Helden
/// gespeichert: Er blendet Magie und Karma ein, obwohl der Held sie nicht
/// aktiviert hat.
class SpecialAbilityVisibilityChip extends StatefulWidget {
  /// Bindet den Chip an die Präferenz des aktuell angezeigten Helden.
  const SpecialAbilityVisibilityChip({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// Ob unpassende Bereiche zusätzlich angezeigt werden.
  final bool value;

  /// Persistiert die Einstellung; `null` sperrt den Chip beim Speichern.
  final Future<void> Function(bool)? onChanged;

  @override
  State<SpecialAbilityVisibilityChip> createState() =>
      _SpecialAbilityVisibilityChipState();
}

class _SpecialAbilityVisibilityChipState
    extends State<SpecialAbilityVisibilityChip>
    with _SpeichertAnzeige<SpecialAbilityVisibilityChip> {
  @override
  Future<void> Function(bool)? get _onChanged => widget.onChanged;

  @override
  Widget build(BuildContext context) => Tooltip(
    message:
        'Zeigt auch Magie und Karma, die der Held nicht aktiviert hat. '
        'Die Einstellung wird am Helden gespeichert.',
    child: FilterChip(
      label: const Text('Unpassende einblenden'),
      selected: widget.value,
      onSelected: _saving || widget.onChanged == null ? null : _change,
    ),
  );
}

// Fehler dürfen die angezeigte Einstellung nicht vom gespeicherten Wert lösen.
mixin _SpeichertAnzeige<T extends StatefulWidget> on State<T> {
  bool _saving = false;

  /// Der Speicherweg des jeweiligen Widgets.
  Future<void> Function(bool)? get _onChanged;

  Future<void> _change(bool value) async {
    setState(() => _saving = true);
    try {
      await _onChanged?.call(value);
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
}
