part of '../hero_magic_tab.dart';

/// Oeffnet den responsiven Zauberdetail-Dialog und gibt gespeicherte Overrides zurueck.
Future<_SpellDetailsDialogResult?> _showSpellDetailsDialog({
  required BuildContext context,
  required SpellDef def,
  required HeroSpellEntry entry,
  required bool isEditing,
  required Attributes effectiveAttributes,
  bool contentUnlocked = true,
  String? contentPassword,
}) {
  return showAdaptiveDetailSheet<_SpellDetailsDialogResult>(
    context: context,
    builder: (_) => _SpellDetailsDialog(
      def: def,
      entry: entry,
      isEditing: isEditing,
      effectiveAttributes: effectiveAttributes,
      contentUnlocked: contentUnlocked,
      contentPassword: contentPassword,
    ),
  );
}

/// Zusammengefuehrte Spell-Details aus Katalog und heldenspezifischen Overrides.
class _ResolvedSpellDetails {
  const _ResolvedSpellDetails({
    required this.aspCost,
    required this.targetObject,
    required this.range,
    required this.duration,
    required this.castingTime,
    required this.wirkung,
    required this.modifications,
    required this.variants,
    required this.source,
  });

  factory _ResolvedSpellDetails.fromSpell({
    required SpellDef def,
    required HeroSpellEntry entry,
    bool contentUnlocked = true,
    String? contentPassword,
  }) {
    final overrides = entry.textOverrides;

    // Wirkung: Override hat Vorrang; sonst ggf. entschluesseln.
    String resolvedWirkung;
    if (overrides?.wirkung != null) {
      resolvedWirkung = overrides!.wirkung!;
    } else {
      resolvedWirkung =
          resolveProtectedValue(
            raw: def.wirkung,
            unlocked: contentUnlocked,
            password: contentPassword,
          ) ??
          lockedContentHint;
    }

    // Varianten: Override hat Vorrang; sonst ggf. entschluesseln.
    List<String> resolvedVariants;
    if (overrides?.variants != null) {
      resolvedVariants = List<String>.from(overrides!.variants!);
    } else {
      // def.variants ist normalerweise List<String>, kann aber als
      // verschluesselter String im Rohfeld stehen.
      final dynamic rawVariants = def.rawVariantsEncrypted ?? def.variants;
      final decrypted = resolveProtectedList(
        raw: rawVariants,
        unlocked: contentUnlocked,
        password: contentPassword,
      );
      resolvedVariants = decrypted ?? <String>[lockedContentHint];
    }

    return _ResolvedSpellDetails(
      aspCost: overrides?.aspCost ?? def.aspCost,
      targetObject: overrides?.targetObject ?? def.targetObject,
      range: overrides?.range ?? def.range,
      duration: overrides?.duration ?? def.duration,
      castingTime: overrides?.castingTime ?? def.castingTime,
      wirkung: resolvedWirkung,
      modifications: overrides?.modifications ?? def.modifications,
      variants: resolvedVariants,
      source: def.source,
    );
  }

  final String aspCost;
  final String targetObject;
  final String range;
  final String duration;
  final String castingTime;
  final String wirkung;
  final String modifications;
  final List<String> variants;
  final String source;
}

/// Rueckgabewert des Dialogs mit den normalisierten Overrides.
class _SpellDetailsDialogResult {
  const _SpellDetailsDialogResult({required this.overrides});

  final HeroSpellTextOverrides? overrides;
}

/// Dialog zum Anzeigen und Bearbeiten aller importierten Zauberdetails.
class _SpellDetailsDialog extends StatefulWidget {
  const _SpellDetailsDialog({
    required this.def,
    required this.entry,
    required this.isEditing,
    required this.effectiveAttributes,
    this.contentUnlocked = true,
    this.contentPassword,
  });

  final SpellDef def;
  final HeroSpellEntry entry;
  final bool isEditing;
  final Attributes effectiveAttributes;
  final bool contentUnlocked;
  final String? contentPassword;

  @override
  State<_SpellDetailsDialog> createState() => _SpellDetailsDialogState();
}

class _SpellDetailsDialogState extends State<_SpellDetailsDialog> {
  final ScrollController _detailsScrollController = ScrollController();
  late final TextEditingController _aspCostController;
  late final TextEditingController _targetObjectController;
  late final TextEditingController _rangeController;
  late final TextEditingController _durationController;
  late final TextEditingController _castingTimeController;
  late final TextEditingController _wirkungController;
  late final TextEditingController _modificationsController;
  late List<TextEditingController> _variantControllers;

  @override
  void initState() {
    super.initState();
    _resetControllersToCatalogOrOverride();
  }

  @override
  void dispose() {
    _detailsScrollController.dispose();
    _aspCostController.dispose();
    _targetObjectController.dispose();
    _rangeController.dispose();
    _durationController.dispose();
    _castingTimeController.dispose();
    _wirkungController.dispose();
    _modificationsController.dispose();
    for (final controller in _variantControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _resetControllersToCatalogOrOverride() {
    final resolved = _ResolvedSpellDetails.fromSpell(
      def: widget.def,
      entry: widget.entry,
      contentUnlocked: widget.contentUnlocked,
      contentPassword: widget.contentPassword,
    );
    _aspCostController = TextEditingController(text: resolved.aspCost);
    _targetObjectController = TextEditingController(
      text: resolved.targetObject,
    );
    _rangeController = TextEditingController(text: resolved.range);
    _durationController = TextEditingController(text: resolved.duration);
    _castingTimeController = TextEditingController(text: resolved.castingTime);
    _wirkungController = TextEditingController(text: resolved.wirkung);
    _modificationsController = TextEditingController(
      text: resolved.modifications,
    );
    _variantControllers = resolved.variants
        .map((entry) => TextEditingController(text: entry))
        .toList(growable: true);
  }

  void _resetToCatalogValues() {
    _aspCostController.text = widget.def.aspCost;
    _targetObjectController.text = widget.def.targetObject;
    _rangeController.text = widget.def.range;
    _durationController.text = widget.def.duration;
    _castingTimeController.text = widget.def.castingTime;
    _wirkungController.text = widget.def.wirkung;
    _modificationsController.text = widget.def.modifications;
    for (final controller in _variantControllers) {
      controller.dispose();
    }
    _variantControllers = widget.def.variants
        .map((entry) => TextEditingController(text: entry))
        .toList(growable: true);
    setState(() {});
  }

  List<String> _normalizedVariants() {
    return _variantControllers
        .map((controller) => controller.text.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }

  String? _normalizeOverrideValue(String currentValue, String catalogValue) {
    final normalized = currentValue.trim();
    if (normalized == catalogValue) {
      return null;
    }
    return normalized;
  }

  HeroSpellTextOverrides? _buildOverrides() {
    final variants = _normalizedVariants();
    final overrides = HeroSpellTextOverrides(
      aspCost: _normalizeOverrideValue(
        _aspCostController.text,
        widget.def.aspCost,
      ),
      targetObject: _normalizeOverrideValue(
        _targetObjectController.text,
        widget.def.targetObject,
      ),
      range: _normalizeOverrideValue(_rangeController.text, widget.def.range),
      duration: _normalizeOverrideValue(
        _durationController.text,
        widget.def.duration,
      ),
      castingTime: _normalizeOverrideValue(
        _castingTimeController.text,
        widget.def.castingTime,
      ),
      wirkung: _normalizeOverrideValue(
        _wirkungController.text,
        widget.def.wirkung,
      ),
      modifications: _normalizeOverrideValue(
        _modificationsController.text,
        widget.def.modifications,
      ),
      variants: listEquals(variants, widget.def.variants) ? null : variants,
    );
    return overrides.isEmpty ? null : overrides;
  }

  void _saveAndClose() {
    Navigator.of(
      context,
    ).pop(_SpellDetailsDialogResult(overrides: _buildOverrides()));
  }

  void _addVariantField() {
    setState(() {
      _variantControllers = List<TextEditingController>.from(
        _variantControllers,
      )..add(TextEditingController());
    });
  }

  void _removeVariantField(int index) {
    final controller = _variantControllers[index];
    setState(() {
      _variantControllers = List<TextEditingController>.from(
        _variantControllers,
      )..removeAt(index);
    });
    controller.dispose();
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    String? keyName,
    int minLines = 1,
  }) {
    final displayValue = value.isNotEmpty ? value : '–';
    return Column(
      key: keyName == null
          ? null
          : ValueKey<String>('magic-spell-details-$keyName'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        SelectableText(
          displayValue,
          minLines: minLines,
          maxLines: minLines == 1 ? 4 : null,
        ),
      ],
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required String keyName,
    int minLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        TextField(
          key: ValueKey<String>('magic-spell-details-$keyName-field'),
          controller: controller,
          minLines: minLines,
          maxLines: minLines == 1 ? 2 : null,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildVariantsSection() {
    if (!widget.isEditing) {
      final resolved = _ResolvedSpellDetails.fromSpell(
        def: widget.def,
        contentUnlocked: widget.contentUnlocked,
        contentPassword: widget.contentPassword,
        entry: widget.entry,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Varianten', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          if (resolved.variants.isEmpty)
            const Text('Keine Varianten vorhanden.')
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: resolved.variants
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: SelectableText(entry),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      );
    }

    final variantFields = <Widget>[];
    for (var index = 0; index < _variantControllers.length; index++) {
      variantFields.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: ValueKey<String>(
                  'magic-spell-details-variant-field-$index',
                ),
                controller: _variantControllers[index],
                minLines: 2,
                maxLines: null,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  isDense: true,
                  labelText: 'Variante ${index + 1}',
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _removeVariantField(index),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Variante entfernen',
            ),
          ],
        ),
      );
      variantFields.add(const SizedBox(height: 8));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Varianten', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        if (variantFields.isEmpty)
          const Text('Keine Varianten vorhanden.')
        else
          ...variantFields,
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const ValueKey<String>('magic-spell-details-variants-add'),
            onPressed: _addVariantField,
            icon: const Icon(Icons.add),
            label: const Text('Variante hinzufügen'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final compactLayout = size.width < 720 || size.height < 720;
    final maxWidth = compactLayout ? size.width - 16 : kDialogWidthExtraLarge;
    final maxHeight = compactLayout ? size.height - 16 : size.height * 0.9;
    final resolved = _ResolvedSpellDetails.fromSpell(
      def: widget.def,
      entry: widget.entry,
      contentUnlocked: widget.contentUnlocked,
      contentPassword: widget.contentPassword,
    );
    final content = <Widget>[
      _buildReadOnlyField(
        label: 'Eigenschaften',
        value: _probeWithValuesLabel(
          widget.effectiveAttributes,
          widget.def.attributes,
        ),
      ),
      _buildReadOnlyField(
        label: 'Merkmale',
        value: widget.def.traits,
        keyName: 'traits',
      ),
      _buildReadOnlyField(
        label: 'Magieresistenz',
        value: describeSpellMagicResistanceProbe(
          targetObject: resolved.targetObject,
          modifier: widget.def.modifier,
          modifications: resolved.modifications,
        ),
        keyName: 'magic-resistance',
      ),
      if (widget.isEditing)
        _buildEditableField(
          label: 'Kosten',
          controller: _aspCostController,
          keyName: 'aspCost',
        )
      else
        _buildReadOnlyField(label: 'Kosten', value: resolved.aspCost),
      if (widget.isEditing)
        _buildEditableField(
          label: 'Zielobjekt',
          controller: _targetObjectController,
          keyName: 'targetObject',
        )
      else
        _buildReadOnlyField(label: 'Zielobjekt', value: resolved.targetObject),
      if (widget.isEditing)
        _buildEditableField(
          label: 'Reichweite',
          controller: _rangeController,
          keyName: 'range',
        )
      else
        _buildReadOnlyField(label: 'Reichweite', value: resolved.range),
      if (widget.isEditing)
        _buildEditableField(
          label: 'Wirkungsdauer',
          controller: _durationController,
          keyName: 'duration',
        )
      else
        _buildReadOnlyField(label: 'Wirkungsdauer', value: resolved.duration),
      if (widget.isEditing)
        _buildEditableField(
          label: 'Zauberdauer',
          controller: _castingTimeController,
          keyName: 'castingTime',
        )
      else
        _buildReadOnlyField(label: 'Zauberdauer', value: resolved.castingTime),
      if (widget.isEditing)
        _buildEditableField(
          label: 'Wirkung',
          controller: _wirkungController,
          keyName: 'wirkung',
          minLines: 6,
        )
      else
        _buildReadOnlyField(
          label: 'Wirkung',
          value: resolved.wirkung,
          minLines: 3,
        ),
      if (widget.isEditing)
        _buildEditableField(
          label: 'Modifikationen',
          controller: _modificationsController,
          keyName: 'modifications',
          minLines: 4,
        )
      else
        _buildReadOnlyField(
          label: 'Modifikationen',
          value: resolved.modifications,
          minLines: 2,
        ),
      _buildVariantsSection(),
      _buildReadOnlyField(label: 'Quelle', value: resolved.source),
    ];

    return Dialog(
      key: const ValueKey<String>('magic-spell-details-dialog'),
      insetPadding: EdgeInsets.all(compactLayout ? 8 : 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.def.name,
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.isEditing
                              ? 'Heldenspezifische Zauberdetails bearbeiten'
                              : 'Zauberdetails',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Schließen',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Scrollbar(
                controller: _detailsScrollController,
                child: SingleChildScrollView(
                  controller: _detailsScrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var index = 0; index < content.length; index++) ...[
                        content[index],
                        if (index < content.length - 1)
                          const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  if (widget.isEditing)
                    TextButton(
                      key: const ValueKey<String>('magic-spell-details-reset'),
                      onPressed: _resetToCatalogValues,
                      child: const Text('Katalogwerte'),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Abbrechen'),
                  ),
                  const SizedBox(width: 8),
                  if (widget.isEditing)
                    FilledButton(
                      key: const ValueKey<String>('magic-spell-details-save'),
                      onPressed: _saveAndClose,
                      child: const Text('Übernehmen'),
                    )
                  else
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Schließen'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
