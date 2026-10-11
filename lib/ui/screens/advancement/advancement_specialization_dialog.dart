import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_options.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_specialization_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/talent_specialization_hints.dart';
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
  final talentName = session.catalog.talents
      .where((def) => def.id == talentId)
      .map((def) => def.name)
      .firstOrNull;
  final name = await showAdaptiveInputDialog<String>(
    context: context,
    builder: (_) => _SpecializationNameDialog(
      choices: available,
      useSelection: choices.isNotEmpty,
      talentName: talentName,
      hint: advancementSpecializationHint(rules, talentId),
      owned: owned,
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
  State<_SpecializationNameDialog> createState() =>
      _SpecializationNameDialogState();
}

class _SpecializationNameDialogState extends State<_SpecializationNameDialog> {
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
