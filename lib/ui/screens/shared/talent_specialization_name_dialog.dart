import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/rules/derived/talent_specialization_hints.dart';

/// Fragt den Namen einer Talent-Spezialisierung ab und bietet dabei die
/// Regelwerks-Empfehlungen an. Gemeinsam genutzt von Steigerung und Talente-Tab.
// Die Route besitzt den Controller bis zum Ende ihrer Schließanimation.
class TalentSpecializationNameDialog extends StatefulWidget {
  const TalentSpecializationNameDialog({
    super.key,
    required this.choices,
    required this.useSelection,
    required this.owned,
    this.talentName,
    this.hint,
  });
  final List<String> choices;
  final bool useSelection;
  final String? talentName;

  /// Empfehlungen für Nicht-Kampftalente; `null` bei Kampftalenten.
  final TalentSpezialisierungsHinweis? hint;

  /// Bereits gelernte oder vorgemerkte Spezialisierungen des Talents.
  final List<String> owned;

  @override
  State<TalentSpecializationNameDialog> createState() =>
      _TalentSpecializationNameDialogState();
}

class _TalentSpecializationNameDialogState
    extends State<TalentSpecializationNameDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.choices.firstOrNull;
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Eine eingetippte Spezialisierung ersetzt eine angeklickte Empfehlung;
  // der Weiter-Knopf folgt dem Eingabestand.
  void _onTextChanged() {
    if (widget.useSelection) return;
    setState(() {
      if (_selected != null && _controller.text != _selected) _selected = null;
    });
  }

  bool _isOwned(String name) => widget.owned.any(
    (value) => value.toLowerCase() == name.trim().toLowerCase(),
  );

  void _pick(String name) {
    setState(() => _selected = name);
    _controller.value = TextEditingValue(
      text: name,
      selection: TextSelection.collapsed(offset: name.length),
    );
  }

  String get _result =>
      _controller.text.trim().isNotEmpty ? _controller.text : (_selected ?? '');

  void _submit() {
    if (_result.trim().isEmpty) return;
    Navigator.of(context).pop(_result);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.talentName == null
          ? 'Spezialisierung lernen'
          : 'Spezialisierung: ${widget.talentName}',
    ),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: widget.useSelection ? _combatContent() : _generalContent(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Abbrechen'),
      ),
      FilledButton(
        onPressed: widget.useSelection
            ? (widget.choices.isEmpty
                  ? null
                  : () => Navigator.of(context).pop(_selected))
            : (_result.trim().isEmpty ? null : _submit),
        child: const Text('Weiter'),
      ),
    ],
  );

  // Kampftalente wählen weiterhin aus ihren Waffenkategorien.
  Widget _combatContent() => DropdownButtonFormField<String>(
    initialValue: _selected,
    isExpanded: true,
    decoration: const InputDecoration(labelText: 'Waffenkategorie'),
    items: [
      for (final value in widget.choices)
        DropdownMenuItem(value: value, child: Text(value)),
    ],
    onChanged: (value) => _selected = value,
  );

  Widget _generalContent() {
    final theme = Theme.of(context);
    final hint = widget.hint;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hint != null && hint.hatVorschlaege) ...[
          Text('Empfehlungen', style: theme.textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(
            'Laut $kSpezialisierungsQuelle. Im Spezialgebiet gilt ein um '
            '2 Punkte höherer TaW.',
            style: muted,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final name in hint.vorschlaege)
                ChoiceChip(
                  key: ValueKey('advancement-specialization-option-$name'),
                  label: Text(name),
                  avatar: _isOwned(name)
                      ? const Icon(Icons.check, size: 16)
                      : null,
                  selected: _selected == name,
                  // Bereits gelernte Spezialisierungen bleiben sichtbar,
                  // lassen sich aber nicht noch einmal wählen.
                  onSelected: _isOwned(name) ? null : (_) => _pick(name),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (hint != null && hint.keine) ...[
          Text(
            'Für dieses Talent nennt $kSpezialisierungsQuelle keine '
            'Spezialisierungen. Wähle eine nur in Absprache mit dem Meister.',
            style: muted,
          ),
          const SizedBox(height: 12),
        ],
        if (hint == null) ...[
          Text(
            'Zu diesem Talent nennt das Regelwerk keine Empfehlungen. '
            'Trage die Spezialisierung frei ein.',
            style: muted,
          ),
          const SizedBox(height: 12),
        ],
        if (hint?.anmerkung != null) ...[
          Text(hint!.anmerkung!, style: muted),
          const SizedBox(height: 12),
        ],
        Text(
          hint != null && hint.hatVorschlaege
              ? 'Oder eigene Spezialisierung'
              : 'Spezialisierung',
          style: theme.textTheme.titleSmall,
        ),
        if (hint?.freieWahl != null) ...[
          const SizedBox(height: 2),
          Text('Frei wählbar: ${hint!.freieWahl}', style: muted),
        ],
        const SizedBox(height: 8),
        RawAutocomplete<String>(
          textEditingController: _controller,
          focusNode: _focusNode,
          optionsBuilder: (value) {
            final options = hint?.weitereOptionen ?? const <String>[];
            final query = value.text.trim().toLowerCase();
            if (query.isEmpty) return const Iterable<String>.empty();
            return options.where(
              (option) =>
                  option.toLowerCase().contains(query) && !_isOwned(option),
            );
          },
          onSelected: _pick,
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) =>
              TextField(
                key: const ValueKey('advancement-specialization-name'),
                controller: controller,
                focusNode: focusNode,
                autofocus: !(hint?.hatVorschlaege ?? false),
                decoration: InputDecoration(
                  labelText: 'Spezialisierung',
                  helperText: hint?.weitereOptionen.isNotEmpty == true
                      ? 'Tippen für Vorschläge'
                      : null,
                ),
                onSubmitted: (_) => _submit(),
              ),
          optionsViewBuilder: (context, onSelected, options) => Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 220,
                  maxWidth: 420,
                ),
                child: ListView(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  children: [
                    for (final option in options)
                      ListTile(
                        dense: true,
                        title: Text(option),
                        onTap: () => onSelected(option),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
