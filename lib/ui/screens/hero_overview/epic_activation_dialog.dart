import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/rules/derived/epic_main_attribute_rules.dart';

/// Ergebnis der epischen Aktivierung: die vom Spieler gewählten Punkte,
/// die beiden Haupteigenschaften (je 1 für die gewählte geistige und
/// körperliche Eigenschaft, sonst 0) und die Aktivierungs-Policy.
class EpicActivationResult {
  const EpicActivationResult({
    required this.maxBonus,
    required this.mainAttributes,
    this.policy,
  });

  final Attributes maxBonus;
  final Attributes mainAttributes;
  final String? policy;
}

/// Dialog zur Aktivierung — und nachträglichen Korrektur — des epischen Status.
///
/// Der Spieler verteilt 5 Punkte auf die acht Grundeigenschaften
/// (maximal +2 pro Eigenschaft), wählt je eine geistige und eine
/// körperliche Haupteigenschaft und optional eine Aktivierungs-Policy.
///
/// [currentValues] sind die aktuellen Eigenschaftswerte des Helden.
/// [effectiveStartAttributes] werden genutzt, um die neuen Maximalwerte
/// (ceil(start × 1,5) + Bonus) anzuzeigen.
///
/// Mit [isEdit] arbeitet der Dialog als Korrekturmaske für bereits epische
/// Helden: [initialMaxBonus], [initialMainAttributes] und [initialPolicy]
/// belegen die Auswahl vor. Das ist der Weg, um bei Helden ohne
/// Haupteigenschaften die fehlende Auswahl nachzutragen.
class EpicActivationDialog extends StatefulWidget {
  const EpicActivationDialog({
    super.key,
    required this.currentValues,
    required this.effectiveStartAttributes,
    this.isEdit = false,
    this.initialMaxBonus = const Attributes.zero(),
    this.initialMainAttributes = const Attributes.zero(),
    this.initialPolicy,
  });

  final Attributes currentValues;
  final Attributes effectiveStartAttributes;

  /// Schaltet Titel, Texte und Bestätigungsbutton auf Korrekturbetrieb um.
  final bool isEdit;

  /// Vorbelegung der Punkteverteilung auf die Eigenschafts-Obergrenzen.
  final Attributes initialMaxBonus;

  /// Vorbelegung der Haupteigenschaften (Werte > 0 gelten als gewählt).
  final Attributes initialMainAttributes;

  /// Vorbelegung der Aktivierungs-Policy.
  final String? initialPolicy;

  @override
  State<EpicActivationDialog> createState() => _EpicActivationDialogState();
}

class _EpicActivationDialogState extends State<EpicActivationDialog> {
  static const int _maxTotal = 5;
  static const int _maxPerAttr = 2;

  static const List<(String, String)> _mentalAttrs = [
    ('Mut', 'mu'),
    ('Klugheit', 'kl'),
    ('Intuition', 'inn'),
    ('Charisma', 'ch'),
  ];

  static const List<(String, String)> _physicalAttrs = [
    ('Fingerfertigkeit', 'ff'),
    ('Gewandtheit', 'ge'),
    ('Konstitution', 'ko'),
    ('Körperkraft', 'kk'),
  ];

  static const List<(String, String)> _attrs = [
    ..._mentalAttrs,
    ..._physicalAttrs,
  ];

  static const List<(String, String)> _policies = [
    ('Standard (Stufe 21-22, 21.000-23.100 AP)', 'standard'),
    ('Höheres Wesen (ab Stufe 18)', 'elevated_being'),
    ('Paktierer (ab Stufe 16)', 'paktierer'),
    ('Elfisch (jederzeit mit Elfischer Weltsicht)', 'elfisch'),
  ];

  final Map<String, int> _bonus = {
    'mu': 0, 'kl': 0, 'inn': 0, 'ch': 0,
    'ff': 0, 'ge': 0, 'ko': 0, 'kk': 0,
  };

  String? _selectedMental;
  String? _selectedPhysical;
  String _policy = 'standard';

  @override
  void initState() {
    super.initState();
    for (final key in _bonus.keys.toList(growable: false)) {
      final initial = _attributeValue(widget.initialMaxBonus, key);
      _bonus[key] = initial.clamp(0, _maxPerAttr);
    }
    _selectedMental = _firstSelected(_mentalAttrs, widget.initialMainAttributes);
    _selectedPhysical = _firstSelected(
      _physicalAttrs,
      widget.initialMainAttributes,
    );
    final initialPolicy = widget.initialPolicy;
    final isKnownPolicy = _policies.any((entry) => entry.$2 == initialPolicy);
    if (isKnownPolicy) {
      _policy = initialPolicy!;
    }
  }

  /// Liefert den ersten Eigenschafts-Schluessel aus [candidates], der in
  /// [mainAttributes] markiert ist, sonst `null`.
  String? _firstSelected(
    List<(String, String)> candidates,
    Attributes mainAttributes,
  ) {
    for (final entry in candidates) {
      if (_attributeValue(mainAttributes, entry.$2) > 0) {
        return entry.$2;
      }
    }
    return null;
  }

  /// Liest einen Eigenschaftswert ueber den Kleinbuchstaben-Schluessel.
  int _attributeValue(Attributes attributes, String key) => switch (key) {
    'mu' => attributes.mu,
    'kl' => attributes.kl,
    'inn' => attributes.inn,
    'ch' => attributes.ch,
    'ff' => attributes.ff,
    'ge' => attributes.ge,
    'ko' => attributes.ko,
    'kk' => attributes.kk,
    _ => 0,
  };

  int get _totalUsed => _bonus.values.fold(0, (a, b) => a + b);
  int get _remaining => _maxTotal - _totalUsed;
  bool get _canConfirm =>
      _selectedMental != null && _selectedPhysical != null;

  void _adjust(String key, int delta) {
    final current = _bonus[key]!;
    final next = current + delta;
    if (next < 0 || next > _maxPerAttr) return;
    if (delta > 0 && _remaining <= 0) return;
    setState(() => _bonus[key] = next);
  }

  /// Berechnet den Basismax-Wert (vor epischem Bonus) aus dem Startwert.
  int _baseMax(String key) {
    return (_startValue(key) * 1.5).ceil();
  }

  int _startValue(String key) =>
      _attributeValue(widget.effectiveStartAttributes, key);

  int _currentValue(String key) => _attributeValue(widget.currentValues, key);

  Attributes _buildBonus() {
    return Attributes(
      mu: _bonus['mu']!,
      kl: _bonus['kl']!,
      inn: _bonus['inn']!,
      ch: _bonus['ch']!,
      ff: _bonus['ff']!,
      ge: _bonus['ge']!,
      ko: _bonus['ko']!,
      kk: _bonus['kk']!,
    );
  }

  Attributes _buildMainAttributes() {
    int valueFor(String code, String? selected) =>
        selected == code ? 1 : 0;
    return Attributes(
      mu: valueFor('mu', _selectedMental),
      kl: valueFor('kl', _selectedMental),
      inn: valueFor('inn', _selectedMental),
      ch: valueFor('ch', _selectedMental),
      ff: valueFor('ff', _selectedPhysical),
      ge: valueFor('ge', _selectedPhysical),
      ko: valueFor('ko', _selectedPhysical),
      kk: valueFor('kk', _selectedPhysical),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = _remaining;

    final hinweis = widget.isEdit
        ? 'Korrigiere die Punkteverteilung auf die Eigenschafts-Obergrenzen '
              '(noch $remaining von $_maxTotal Punkten frei, max. '
              '+$_maxPerAttr pro Eigenschaft) sowie die beiden '
              'Haupteigenschaften. Bereits gesteigerte Werte bleiben erhalten, '
              'auch wenn sie über einer neuen Obergrenze liegen.'
        : 'Verteile $remaining von $_maxTotal Punkten auf die '
              'Eigenschafts-Obergrenzen (max. +$_maxPerAttr pro Eigenschaft). '
              'Wähle zusätzlich je eine geistige und eine körperliche '
              'Haupteigenschaft.';

    return AlertDialog(
      title: Text(
        widget.isEdit
            ? 'Epischen Status bearbeiten'
            : 'Epischen Status aktivieren',
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(hinweis, style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              ..._attrs.map((entry) {
                final label = entry.$1;
                final key = entry.$2;
                final value = _bonus[key]!;
                final canIncrease = value < _maxPerAttr && remaining > 0;
                final canDecrease = value > 0;
                final baseMax = _baseMax(key);
                final newMax = baseMax + value;
                final cur = _currentValue(key);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 160,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(label, style: theme.textTheme.bodyMedium),
                            Text(
                              'Wert $cur  |  Max $baseMax → $newMax',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove),
                        iconSize: 18,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        onPressed: canDecrease ? () => _adjust(key, -1) : null,
                      ),
                      SizedBox(
                        width: 28,
                        child: Text(
                          '+$value',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: value > 0
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        iconSize: 18,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        onPressed: canIncrease ? () => _adjust(key, 1) : null,
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              Text(
                'Vergeben: $_totalUsed / $_maxTotal Punkte',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _remaining == 0
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Geistige Haupteigenschaft',
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _mentalAttrs.map((entry) {
                  final label = entry.$1;
                  final key = entry.$2;
                  final bonusText =
                      epicMainAttributeBonusDescriptions[key] ?? '';
                  return Tooltip(
                    message: bonusText,
                    preferBelow: true,
                    child: ChoiceChip(
                      key: ValueKey<String>('epic-dialog-mental-$key'),
                      label: Text(label),
                      selected: _selectedMental == key,
                      onSelected: (_) =>
                          setState(() => _selectedMental = key),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Text(
                'Körperliche Haupteigenschaft',
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _physicalAttrs.map((entry) {
                  final label = entry.$1;
                  final key = entry.$2;
                  final bonusText =
                      epicMainAttributeBonusDescriptions[key] ?? '';
                  return Tooltip(
                    message: bonusText,
                    preferBelow: true,
                    child: ChoiceChip(
                      key: ValueKey<String>('epic-dialog-physical-$key'),
                      label: Text(label),
                      selected: _selectedPhysical == key,
                      onSelected: (_) =>
                          setState(() => _selectedPhysical = key),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text(
                'Aktivierungs-Policy',
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: _policy,
                isExpanded: true,
                items: _policies
                    .map(
                      (entry) => DropdownMenuItem<String>(
                        value: entry.$2,
                        child: Text(entry.$1),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _policy = value);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('epic-dialog-confirm'),
          onPressed: _canConfirm
              ? () => Navigator.of(context).pop(
                    EpicActivationResult(
                      maxBonus: _buildBonus(),
                      mainAttributes: _buildMainAttributes(),
                      policy: _policy,
                    ),
                  )
              : null,
          child: Text(widget.isEdit ? 'Speichern' : 'Aktivieren'),
        ),
      ],
    );
  }
}
