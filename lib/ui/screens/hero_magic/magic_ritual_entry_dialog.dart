part of '../hero_magic_tab.dart';

const List<String> _ritualAttributeOptions = <String>[
  'MU',
  'KL',
  'IN',
  'CH',
  'FF',
  'GE',
  'KO',
  'KK',
];

Future<HeroRitualEntry?> _showRitualEntryDialog({
  required BuildContext context,
  required HeroRitualCategory category,
  HeroRitualEntry? existing,
  required bool isEditing,
}) {
  return showDialog<HeroRitualEntry>(
    context: context,
    builder: (dialogContext) {
      return _RitualEntryDialog(
        category: category,
        existing: existing,
        isEditing: isEditing,
      );
    },
  );
}

class _RitualEntryDialog extends StatefulWidget {
  const _RitualEntryDialog({
    required this.category,
    required this.isEditing,
    this.existing,
  });

  final HeroRitualCategory category;
  final HeroRitualEntry? existing;
  final bool isEditing;

  @override
  State<_RitualEntryDialog> createState() => _RitualEntryDialogState();
}

class _RitualEntryDialogState extends State<_RitualEntryDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _wirkungController;
  late final TextEditingController _kostenController;
  late final TextEditingController _wirkungsdauerController;
  late final TextEditingController _merkmaleController;
  late final TextEditingController _zauberdauerController;
  late final TextEditingController _zielobjektController;
  late final TextEditingController _reichweiteController;
  late final TextEditingController _technikController;
  late final List<_EditableRitualFieldValueDraft> _fieldDrafts;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final additionalValuesById = <String, HeroRitualFieldValue>{};
    for (final value
        in existing?.additionalFieldValues ?? const <HeroRitualFieldValue>[]) {
      additionalValuesById[value.fieldDefId] = value;
    }
    _nameController = TextEditingController(text: existing?.name ?? '');
    _wirkungController = TextEditingController(text: existing?.wirkung ?? '');
    _kostenController = TextEditingController(text: existing?.kosten ?? '');
    _wirkungsdauerController = TextEditingController(
      text: existing?.wirkungsdauer ?? '',
    );
    _merkmaleController = TextEditingController(text: existing?.merkmale ?? '');
    _zauberdauerController = TextEditingController(
      text: existing?.zauberdauer ?? '',
    );
    _zielobjektController = TextEditingController(
      text: existing?.zielobjekt ?? '',
    );
    _reichweiteController = TextEditingController(
      text: existing?.reichweite ?? '',
    );
    _technikController = TextEditingController(text: existing?.technik ?? '');
    _fieldDrafts = widget.category.additionalFieldDefs
        .map((fieldDef) {
          return _EditableRitualFieldValueDraft(
            fieldDef: fieldDef,
            existing: additionalValuesById[fieldDef.id],
          );
        })
        .toList(growable: false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _wirkungController.dispose();
    _kostenController.dispose();
    _wirkungsdauerController.dispose();
    _merkmaleController.dispose();
    _zauberdauerController.dispose();
    _zielobjektController.dispose();
    _reichweiteController.dispose();
    _technikController.dispose();
    for (final draft in _fieldDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final wirkung = _wirkungController.text.trim();
    final kosten = _kostenController.text.trim();
    final wirkungsdauer = _wirkungsdauerController.text.trim();
    final merkmale = _merkmaleController.text.trim();
    if (name.isEmpty ||
        wirkung.isEmpty ||
        kosten.isEmpty ||
        wirkungsdauer.isEmpty ||
        merkmale.isEmpty) {
      setState(() {
        _errorText =
            'Bitte Name, Wirkung, Kosten, Wirkungsdauer und Merkmale ausfuellen.';
      });
      return;
    }

    final additionalFieldValues = <HeroRitualFieldValue>[];
    for (final draft in _fieldDrafts) {
      final fieldDef = draft.fieldDef;
      switch (fieldDef.type) {
        case HeroRitualFieldType.text:
          final value = draft.textController.text.trim();
          if (value.isNotEmpty) {
            additionalFieldValues.add(
              HeroRitualFieldValue(fieldDefId: fieldDef.id, textValue: value),
            );
          }
        case HeroRitualFieldType.threeAttributes:
          final normalizedCodes = normalizeRitualAttributeCodes(
            draft.attributeCodes,
          );
          final anySelection = draft.attributeCodes.any(
            (code) => code.isNotEmpty,
          );
          if (anySelection && normalizedCodes.isEmpty) {
            setState(() {
              _errorText =
                  'Felder vom Typ 3 Eigenschaften brauchen genau drei Werte.';
            });
            return;
          }
          if (normalizedCodes.isNotEmpty) {
            additionalFieldValues.add(
              HeroRitualFieldValue(
                fieldDefId: fieldDef.id,
                attributeCodes: normalizedCodes,
              ),
            );
          }
      }
    }

    final builtEntry = HeroRitualEntry(
      name: name,
      wirkung: wirkung,
      kosten: kosten,
      wirkungsdauer: wirkungsdauer,
      merkmale: merkmale,
      zauberdauer: _zauberdauerController.text.trim(),
      zielobjekt: _zielobjektController.text.trim(),
      reichweite: _reichweiteController.text.trim(),
      technik: _technikController.text.trim(),
      additionalFieldValues: additionalFieldValues,
    );
    Navigator.of(context).pop(
      normalizeRitualEntry(
        builtEntry,
        fieldDefs: widget.category.additionalFieldDefs,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.existing == null
        ? 'Ritual anlegen'
        : widget.isEditing
        ? 'Ritual bearbeiten'
        : widget.existing!.name;
    return AlertDialog(
      key: const ValueKey<String>('magic-ritual-entry-dialog'),
      title: Text(title),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: widget.isEditing
              ? _buildEditingContent(context)
              : _buildReadOnlyContent(context),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.isEditing ? 'Abbrechen' : 'Schliessen'),
        ),
        if (widget.isEditing)
          FilledButton(
            key: const ValueKey<String>('magic-ritual-entry-save'),
            onPressed: _save,
            child: const Text('Speichern'),
          ),
      ],
    );
  }

  Widget _buildEditingContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey<String>('magic-ritual-entry-name-field'),
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Name'),
          autofocus: true,
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey<String>('magic-ritual-entry-wirkung-field'),
          controller: _wirkungController,
          decoration: const InputDecoration(labelText: 'Wirkung'),
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey<String>('magic-ritual-entry-kosten-field'),
                controller: _kostenController,
                decoration: const InputDecoration(labelText: 'Kosten'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                key: const ValueKey<String>(
                  'magic-ritual-entry-wirkungsdauer-field',
                ),
                controller: _wirkungsdauerController,
                decoration: const InputDecoration(labelText: 'Wirkungsdauer'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey<String>('magic-ritual-entry-merkmale-field'),
          controller: _merkmaleController,
          decoration: const InputDecoration(labelText: 'Merkmale'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey<String>(
                  'magic-ritual-entry-zauberdauer-field',
                ),
                controller: _zauberdauerController,
                decoration: const InputDecoration(labelText: 'Zauberdauer'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                key: const ValueKey<String>(
                  'magic-ritual-entry-zielobjekt-field',
                ),
                controller: _zielobjektController,
                decoration: const InputDecoration(labelText: 'Zielobjekt'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey<String>(
                  'magic-ritual-entry-reichweite-field',
                ),
                controller: _reichweiteController,
                decoration: const InputDecoration(labelText: 'Reichweite'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                key: const ValueKey<String>('magic-ritual-entry-technik-field'),
                controller: _technikController,
                decoration: const InputDecoration(labelText: 'Technik'),
              ),
            ),
          ],
        ),
        if (_fieldDrafts.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Zusatzfelder', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ..._fieldDrafts.asMap().entries.map((entry) {
            final index = entry.key;
            final draft = entry.value;
            switch (draft.fieldDef.type) {
              case HeroRitualFieldType.text:
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    key: ValueKey<String>(
                      'magic-ritual-entry-extra-text-$index',
                    ),
                    controller: draft.textController,
                    decoration: InputDecoration(
                      labelText: draft.fieldDef.label,
                    ),
                  ),
                );
              case HeroRitualFieldType.threeAttributes:
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        draft.fieldDef.label,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: List<Widget>.generate(3, (attrIndex) {
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: attrIndex == 2 ? 0 : 8,
                              ),
                              child: DropdownButtonFormField<String>(
                                key: ValueKey<String>(
                                  'magic-ritual-entry-extra-attr-$index-$attrIndex',
                                ),
                                initialValue:
                                    draft.attributeCodes[attrIndex].isEmpty
                                    ? null
                                    : draft.attributeCodes[attrIndex],
                                decoration: InputDecoration(
                                  labelText: 'Eigenschaft ${attrIndex + 1}',
                                ),
                                items: _ritualAttributeOptions
                                    .map((code) {
                                      return DropdownMenuItem<String>(
                                        value: code,
                                        child: Text(code),
                                      );
                                    })
                                    .toList(growable: false),
                                onChanged: (value) {
                                  setState(() {
                                    draft.attributeCodes[attrIndex] =
                                        value ?? '';
                                  });
                                },
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                );
            }
          }),
        ],
        if (_errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            _errorText!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _buildReadOnlyContent(BuildContext context) {
    final entry = widget.existing!;
    final additionalValuesById = <String, HeroRitualFieldValue>{};
    for (final value in entry.additionalFieldValues) {
      additionalValuesById[value.fieldDefId] = value;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReadOnlyRow('Name', entry.name),
        _buildReadOnlyRow('Wirkung', entry.wirkung),
        _buildReadOnlyRow('Kosten', entry.kosten),
        _buildReadOnlyRow('Wirkungsdauer', entry.wirkungsdauer),
        _buildReadOnlyRow('Merkmale', entry.merkmale),
        _buildReadOnlyRow('Zauberdauer', entry.zauberdauer),
        _buildReadOnlyRow('Zielobjekt', entry.zielobjekt),
        _buildReadOnlyRow('Reichweite', entry.reichweite),
        _buildReadOnlyRow('Technik', entry.technik),
        ...widget.category.additionalFieldDefs.map((fieldDef) {
          final value = additionalValuesById[fieldDef.id];
          final displayValue = switch (fieldDef.type) {
            HeroRitualFieldType.text => value?.textValue ?? '',
            HeroRitualFieldType.threeAttributes =>
              (value?.attributeCodes ?? []).join('/'),
          };
          return _buildReadOnlyRow(fieldDef.label, displayValue);
        }),
      ],
    );
  }

  Widget _buildReadOnlyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '-' : value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _EditableRitualFieldValueDraft {
  _EditableRitualFieldValueDraft({
    required this.fieldDef,
    HeroRitualFieldValue? existing,
  }) : textController = TextEditingController(text: existing?.textValue ?? ''),
       attributeCodes = List<String>.filled(3, '', growable: false) {
    final existingCodes = existing?.attributeCodes ?? const <String>[];
    for (var index = 0; index < existingCodes.length && index < 3; index++) {
      attributeCodes[index] = existingCodes[index];
    }
  }

  final HeroRitualFieldDef fieldDef;
  final TextEditingController textController;
  final List<String> attributeCodes;

  void dispose() {
    textController.dispose();
  }
}
