import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart';
import 'package:dsa_heldenverwaltung/rules/derived/magic_setup_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/magic_status_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/tradition_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_rules.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';

import 'magic_knowledge_advancement_dialog.dart';

/// Liefert einen vollständigen Entwurf; Abbruch speichert keinerlei Teilentscheidung.
Future<HeroSheet?> showMagicSetupDialog({
  required BuildContext context,
  required HeroSheet hero,
  required RulesCatalog catalog,
  String? initialRepresentation,
}) => showDialog<HeroSheet>(
  context: context,
  builder: (_) => _MagicSetupDialog(
    hero: hero,
    catalog: catalog,
    initialRepresentation: initialRepresentation,
  ),
);

class _MagicSetupDialog extends StatefulWidget {
  const _MagicSetupDialog({
    required this.hero,
    required this.catalog,
    this.initialRepresentation,
  });
  final HeroSheet hero;
  final RulesCatalog catalog;
  final String? initialRepresentation;
  @override
  State<_MagicSetupDialog> createState() => _MagicSetupDialogState();
}

class _MagicSetupDialogState extends State<_MagicSetupDialog> {
  String _traditionId = 'gildenmagier';
  String _source = 'creation';
  bool _representation = true;
  bool _ritual = true;
  String? _sourceCategory;
  final Set<String> _categories = {};
  final _start = TextEditingController(text: '3');
  String? _error;
  bool _busy = false;
  String? _magicStatus;

  @override
  void initState() {
    super.initState();
    _magicStatus = detectMagicStatus(widget.hero, widget.catalog);
    final initial = widget.initialRepresentation;
    if (initial != null) {
      final traditions = traditionenFuerRepraesentation(initial);
      if (traditions.isNotEmpty) _traditionId = traditions.first.id;
      _source = 'acquisition';
      _ritual = false;
    }
  }

  @override
  void dispose() {
    _start.dispose();
    super.dispose();
  }

  // Die gesamte Auswahl wird erst nach dem letzten Dialog an den Aufrufer gegeben.
  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final tradition = traditionById(_traditionId)!;
      if (_representation && !isValidMagicStatus(_magicStatus)) {
        throw StateError('Bitte den Zaubererstatus ausdrücklich klären.');
      }
      final value = int.tryParse(_start.text);
      if (_ritual && value == null) {
        throw StateError('Bitte einen Startwert angeben.');
      }
      final choice = MagicSetupChoice(
        traditionId: _traditionId,
        includeRepresentation: _representation,
        includeRitualKnowledge: _ritual,
        startValue: value ?? 3,
        sourceCategoryId: _sourceCategory,
        categoryIds: _categories.toList(),
      );
      var result = widget.hero;
      if (_source == 'acquisition') {
        final entries = <HeroAdvancementEntry>[];
        final id = const Uuid().v4();
        final targets = <(AdvancementKind, String)>[
          if (_representation &&
              tradition.repraesentation.isNotEmpty &&
              !result.representationen.contains(tradition.repraesentation))
            (AdvancementKind.representation, tradition.repraesentation),
          if (_ritual && !result.ritualKnowledge.containsKey(_traditionId))
            (AdvancementKind.ritualKnowledge, _traditionId),
        ];
        for (final target in targets) {
          final session = AdvancementSession(
            sessionId: id,
            base: widget.hero,
            catalog: widget.catalog,
            entries: entries,
            replay: replayAdvancements(
              base: widget.hero,
              entries: entries,
              catalog: widget.catalog,
            ),
          );
          final option = resolveAdvancementOption(
            hero: session.preview,
            catalog: widget.catalog,
            kind: target.$1,
            targetId: target.$2,
            options: {
              'source': 'acquisition',
              'traditionId': _traditionId,
              'magicStatus': ?_magicStatus,
            },
          );
          if (option == null) throw StateError('Erwerb nicht verfügbar.');
          if (!mounted) return;
          final entry = await showMagicKnowledgeAdvancementDialog(
            context: context,
            session: session,
            option: option,
            lockSource: true,
            lockTradition: true,
          );
          if (entry == null || !mounted) return;
          entries.add(entry);
        }
        result = commitAdvancements(
          base: widget.hero,
          entries: entries,
          catalog: widget.catalog,
        );
        // Nach bezahltem Erwerb nur ausdrücklich gewählte Gruppen anbinden.
        result = applyMagicSetup(
          result,
          MagicSetupChoice(
            traditionId: _traditionId,
            includeRepresentation: false,
            includeRitualKnowledge: _ritual,
            categoryIds: _categories.toList(),
          ),
        );
      } else {
        result = applyMagicSetup(result, choice);
      }
      if (mounted) Navigator.of(context).pop(result);
    } on StateError catch (error) {
      if (mounted) setState(() => _error = error.message.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tradition = traditionById(_traditionId)!;
    final known = widget.hero.ritualKnowledge[_traditionId];
    final legacy = widget.hero.ritualCategories
        .where(
          (category) =>
              category.knowledgeMode == HeroRitualKnowledgeMode.ownKnowledge &&
              category.ownKnowledge != null,
        )
        .toList();
    return AlertDialog(
      title: const Text('Magische Tradition einrichten'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _traditionId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tradition'),
                items: [
                  for (final def in kTraditionen)
                    DropdownMenuItem(value: def.id, child: Text(def.name)),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() {
                        _traditionId = value!;
                        final selected = traditionById(value)!;
                        _representation = selected.repraesentation.isNotEmpty;
                        _ritual = selected.ritualKnowledgeName.isNotEmpty;
                        _sourceCategory = null;
                        _categories.clear();
                      }),
              ),
              DropdownButtonFormField<String>(
                initialValue: _source,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Erfassungsgrund'),
                items: const [
                  DropdownMenuItem(
                    value: 'creation',
                    child: Text('Bei Erschaffung enthalten'),
                  ),
                  DropdownMenuItem(
                    value: 'existing',
                    child: Text('Bereits vorhanden'),
                  ),
                  DropdownMenuItem(
                    value: 'acquisition',
                    child: Text('Neu erlernen'),
                  ),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _source = value!),
              ),
              const SizedBox(height: 8),
              if (detectMagicStatus(widget.hero, widget.catalog) == null)
                DropdownButtonFormField<String>(
                  initialValue: _magicStatus,
                  isExpanded: true,
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
                  onChanged: (value) => setState(() => _magicStatus = value),
                ),
              Text(
                _source == 'acquisition'
                    ? 'Kosten und Voraussetzungen werden im Erwerbsdialog geprüft.'
                    : 'Enthaltene oder bereits vorhandene Kenntnisse kosten keine zusätzlichen AP.',
              ),
              if (tradition.repraesentation.isNotEmpty)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Repräsentation ${tradition.repraesentation}'),
                  subtitle:
                      widget.hero.representationen.contains(
                        tradition.repraesentation,
                      )
                      ? const Text('Bereits vorhanden')
                      : null,
                  value: _representation,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _representation = value!),
                ),
              if (tradition.ritualKnowledgeName.isNotEmpty) ...[
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Ritualkenntnis ${tradition.ritualKnowledgeName}',
                  ),
                  subtitle: known == null
                      ? null
                      : Text('Bereits vorhanden: RkW ${known.value}'),
                  value: _ritual,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _ritual = value!),
                ),
                if (_ritual && known == null && _source != 'acquisition') ...[
                  TextField(
                    controller: _start,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Professionsstartwert (normalerweise 3)',
                    ),
                  ),
                  if (legacy.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: _sourceCategory ?? '',
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Maßgebliche bestehende Kenntnis',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Neuen Startwert verwenden'),
                        ),
                        for (final category in legacy)
                          DropdownMenuItem(
                            value: category.id,
                            child: Text(
                              '${category.name}: ${category.ownKnowledge!.value} / '
                              '${category.ownKnowledge!.learningComplexity}',
                            ),
                          ),
                      ],
                      onChanged: (value) => setState(
                        () => _sourceCategory = value == '' ? null : value,
                      ),
                    ),
                ],
                if (_ritual && legacy.isNotEmpty) ...[
                  if (_source == 'acquisition')
                    const Text(
                      'Die neu erworbene Kenntnis startet bei 3. Angebundene Gruppen '
                      'verwenden anschließend diesen gemeinsamen Wert.',
                    ),
                  const Text(
                    'Ritualgruppen ausdrücklich an diese Kenntnis anbinden:',
                  ),
                  for (final category in legacy)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${category.name}: RkW ${category.ownKnowledge!.value}, '
                        'Spalte ${category.ownKnowledge!.learningComplexity}',
                      ),
                      value: _categories.contains(category.id),
                      onChanged: (value) => setState(() {
                        if (value == true) {
                          _categories.add(category.id);
                        } else {
                          _categories.remove(category.id);
                        }
                      }),
                    ),
                ],
              ] else
                const Text(
                  'Keine gemeinsame Ritualkenntnis dieser Tradition. '
                  'Talentbasierte und unabhängige Kenntnisse bleiben separat.',
                ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey('magic-setup-confirm'),
          onPressed: _busy ? null : _confirm,
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}
