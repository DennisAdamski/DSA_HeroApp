import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/catalog/special_ability_def.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';

/// Dialog zur Auswahl der Variante einer mehrfach waehlbaren Sonderfertigkeit
/// (Kultur, Gelaende, Ort, Klima, Geheimwissen, Merkmal, Einzelritual).
///
/// Zeigt die katalogisierten Vorschlaege als Dropdown und — sofern der Katalog
/// es erlaubt — zusaetzlich ein Freitextfeld. Bereits belegte Varianten werden
/// ausgeblendet.
class SpecialAbilityVariantDialog extends StatefulWidget {
  /// Erzeugt den Auswahldialog.
  const SpecialAbilityVariantDialog({
    super.key,
    required this.ability,
    required this.bereitsBelegt,
  });

  /// Die mehrfach waehlbare Sonderfertigkeit.
  final SpecialAbilityDef ability;

  /// Varianten, die der Held schon erworben hat.
  final Set<String> bereitsBelegt;

  @override
  State<SpecialAbilityVariantDialog> createState() =>
      _SpecialAbilityVariantDialogState();
}

/// Eine waehlbare Variante samt ihrem Gruppenpreis (falls vorhanden).
class _VariantOption {
  const _VariantOption({required this.name, this.ap, this.gruppe = ''});

  final String name;
  final int? ap;
  final String gruppe;
}

class _SpecialAbilityVariantDialogState
    extends State<SpecialAbilityVariantDialog> {
  static const _freeTextValue = '__freitext__';

  late final List<_VariantOption> _options;
  late final TextEditingController _freeTextController;
  String? _selected;

  @override
  void initState() {
    super.initState();
    final belegt = widget.bereitsBelegt
        .map((entry) => entry.trim().toLowerCase())
        .toSet();
    final ability = widget.ability;
    final options = <_VariantOption>[];
    for (final name in ability.varianten) {
      options.add(_VariantOption(name: name));
    }
    for (final gruppe in ability.variantenGruppen) {
      for (final name in gruppe.varianten) {
        options.add(
          _VariantOption(name: name, ap: gruppe.ap, gruppe: gruppe.label),
        );
      }
    }
    final seen = <String>{};
    _options = options.where((option) {
      final key = option.name.trim().toLowerCase();
      return !belegt.contains(key) && seen.add(key);
    }).toList(growable: false);
    _freeTextController = TextEditingController();
    _selected = _options.isEmpty && ability.variantenFreitext
        ? _freeTextValue
        : null;
  }

  /// Alle Katalogoptionen sind belegt und Freitext ist nicht erlaubt —
  /// es gibt nichts mehr zu erwerben.
  bool get _isExhausted =>
      _options.isEmpty && !widget.ability.variantenFreitext;

  @override
  void dispose() {
    _freeTextController.dispose();
    super.dispose();
  }

  bool get _isFreeText => _selected == _freeTextValue;

  String get _resolvedVariant =>
      _isFreeText ? _freeTextController.text.trim() : (_selected ?? '').trim();

  String get _label => widget.ability.variantenLabel.trim().isEmpty
      ? 'Auswahl'
      : widget.ability.variantenLabel.trim();

  @override
  Widget build(BuildContext context) {
    final allowsFreeText = widget.ability.variantenFreitext;
    return AdaptiveInputDialog(
      title: '${widget.ability.name}: $_label wählen',
      maxWidth: kDialogWidthSmall,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isExhausted)
            Text(
              'Alle Auswahlmöglichkeiten sind bereits erworben.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          if (_options.isNotEmpty)
            DropdownButtonFormField<String>(
              key: const ValueKey<String>('sf-variant-dropdown'),
              initialValue: _selected,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: _label,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final option in _options)
                  DropdownMenuItem<String>(
                    value: option.name,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            option.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (option.ap != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${option.ap} AP',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Theme.of(context).hintColor),
                          ),
                        ],
                      ],
                    ),
                  ),
                if (allowsFreeText)
                  const DropdownMenuItem<String>(
                    value: _freeTextValue,
                    child: Text('Eigene Eingabe…'),
                  ),
              ],
              onChanged: (value) => setState(() => _selected = value),
            ),
          if (_options.isNotEmpty && _isFreeText) const SizedBox(height: 12),
          if (_isFreeText)
            TextField(
              key: const ValueKey<String>('sf-variant-freetext'),
              controller: _freeTextController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: _label,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _resolvedVariant.isEmpty
              ? null
              : () => Navigator.of(context).pop(_resolvedVariant),
          child: const Text('Weiter'),
        ),
      ],
    );
  }
}
