part of '../hero_magic_tab.dart';

/// Tabelle der aktivierten Zauber mit editierbaren ZfW-Werten und Detailzugriff.
class _MagicActiveSpellsTable extends StatelessWidget {
  const _MagicActiveSpellsTable({
    required this.activeSpellIds,
    required this.spellEntries,
    required this.spellDefs,
    required this.effectiveAttributes,
    required this.merkmalskenntnisse,
    required this.heroRepresentationen,
    required this.isEditing,
    required this.onSpellValueChanged,
    required this.onModifierChanged,
    required this.onHauszauberChanged,
    required this.onGiftedChanged,
    required this.onLearnedRepresentationChanged,
    required this.onTextOverridesChanged,
    required this.onRemoveSpell,
    required this.controllerFor,
    required this.canRaiseValues,
    required this.protectedContentCache,
    this.contentUnlocked = true,
    this.contentPassword,
    this.onRaiseSpell,
    this.onAddSpell,
    this.onRollSpell,
  });

  final List<String> activeSpellIds;
  final Map<String, HeroSpellEntry> spellEntries;
  final Map<String, SpellDef> spellDefs;
  final Attributes effectiveAttributes;
  final List<String> merkmalskenntnisse;
  final List<String> heroRepresentationen;
  final bool isEditing;
  final void Function(String spellId, String raw) onSpellValueChanged;
  final void Function(String spellId, String raw) onModifierChanged;
  final void Function(String spellId, bool value) onHauszauberChanged;
  final void Function(String spellId, bool value) onGiftedChanged;
  final void Function(String spellId, SpellAvailabilityEntry entry)
  onLearnedRepresentationChanged;
  final void Function(String spellId, HeroSpellTextOverrides? value)
  onTextOverridesChanged;
  final void Function(String spellId) onRemoveSpell;
  final TextEditingController Function(String id, String field, String initial)
  controllerFor;
  final bool canRaiseValues;
  final ProtectedContentCache protectedContentCache;
  final bool contentUnlocked;
  final String? contentPassword;
  final Future<void> Function(String spellId, SpellDef spell)? onRaiseSpell;
  final VoidCallback? onAddSpell;
  final void Function(String spellId, SpellDef spell, HeroSpellEntry entry)?
  onRollSpell;

  Future<void> _openSpellDetails(
    BuildContext context,
    String spellId,
    SpellDef def,
    HeroSpellEntry entry,
  ) async {
    final result = await _showSpellDetailsDialog(
      context: context,
      def: def,
      entry: entry,
      isEditing: isEditing,
      effectiveAttributes: effectiveAttributes,
      contentUnlocked: contentUnlocked,
      contentPassword: contentPassword,
      protectedContentCache: protectedContentCache,
    );
    if (result == null) {
      return;
    }
    onTextOverridesChanged(spellId, result.overrides);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final addSpellAction = onAddSpell == null
        ? null
        : FilledButton(
            key: const ValueKey<String>('magic-spells-add'),
            onPressed: onAddSpell,
            child: const Text('+ Zauber'),
          );
    final columns = <AdaptiveDataColumnSpec>[
      const AdaptiveDataColumnSpec(
        label: Text('Name'),
        width: AdaptiveTableColumnSpec(minWidth: 120, maxWidth: 220, flex: 2),
      ),
      const AdaptiveDataColumnSpec(
        label: Text('Eigenschaften'),
        width: AdaptiveTableColumnSpec(minWidth: 140, maxWidth: 200, flex: 1),
      ),
      const AdaptiveDataColumnSpec(
        label: Text('ZfW'),
        width: AdaptiveTableColumnSpec(minWidth: 40, maxWidth: 80),
        numeric: true,
      ),
      const AdaptiveDataColumnSpec(
        label: Text('Mod'),
        width: AdaptiveTableColumnSpec(minWidth: 64, maxWidth: 100),
        numeric: true,
      ),
      const AdaptiveDataColumnSpec(
        label: Text('Repr.'),
        width: AdaptiveTableColumnSpec(minWidth: 80, maxWidth: 160, flex: 1),
      ),
      const AdaptiveDataColumnSpec(
        label: Text('Kompl.'),
        width: AdaptiveTableColumnSpec(minWidth: 76, maxWidth: 96),
      ),
      const AdaptiveDataColumnSpec(
        label: Text('HZ'),
        width: AdaptiveTableColumnSpec.fixed(64),
      ),
      if (isEditing)
        const AdaptiveDataColumnSpec(
          label: Text('Beg.'),
          width: AdaptiveTableColumnSpec.fixed(68),
        ),
      const AdaptiveDataColumnSpec(
        label: Text('Merkmale'),
        width: AdaptiveTableColumnSpec(minWidth: 120, maxWidth: 220, flex: 1),
      ),
      const AdaptiveDataColumnSpec(
        label: Text('Zauberdauer'),
        width: AdaptiveTableColumnSpec(minWidth: 150, maxWidth: 220, flex: 1),
      ),
      const AdaptiveDataColumnSpec(
        label: Text('Kosten'),
        width: AdaptiveTableColumnSpec(minWidth: 84, maxWidth: 120),
      ),
      const AdaptiveDataColumnSpec(
        label: Text('Reichweite'),
        width: AdaptiveTableColumnSpec(minWidth: 120, maxWidth: 180, flex: 1),
      ),
      const AdaptiveDataColumnSpec(
        label: Text('Dauer'),
        width: AdaptiveTableColumnSpec(minWidth: 90, maxWidth: 130),
      ),
      const AdaptiveDataColumnSpec(
        label: Text('Wirkung'),
        width: AdaptiveTableColumnSpec(minWidth: 130, maxWidth: 240, flex: 2),
      ),
      const AdaptiveDataColumnSpec(
        label: Text('Varianten'),
        width: AdaptiveTableColumnSpec(minWidth: 140, maxWidth: 320, flex: 2),
      ),
      if (isEditing)
        const AdaptiveDataColumnSpec(
          label: Text(''),
          width: AdaptiveTableColumnSpec.fixed(48),
        ),
    ];

    if (activeSpellIds.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: CodexSectionCard(
          title: 'Zauber',
          subtitle: 'Aktiviere hier Zauber für diesen Helden.',
          trailing: addSpellAction,
          child: Text(
            'Keine Zauber aktiviert.',
            style: theme.textTheme.bodySmall,
          ),
        ),
      );
    }

    final sortedIds = List<String>.from(activeSpellIds)
      ..sort((a, b) {
        final defA = spellDefs[a];
        final defB = spellDefs[b];
        if (defA == null || defB == null) {
          return 0;
        }
        return defA.name.toLowerCase().compareTo(defB.name.toLowerCase());
      });

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: CodexSectionCard(
        title: 'Aktivierte Zauber',
        subtitle:
            '${sortedIds.length} Einträge mit Repräsentation, Wirkung und Varianten.',
        trailing: addSpellAction,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const columnSpacing = 2.0;
            const horizontalMargin = 0.0;
            final layout = resolveAdaptiveDataTableLayout(
              columns,
              availableWidth: constraints.maxWidth,
              columnSpacing: columnSpacing,
              horizontalMargin: horizontalMargin,
            );

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: columnSpacing,
                horizontalMargin: horizontalMargin,
                headingRowHeight: 36,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 52,
                columns: layout.columns,
                rows: sortedIds
                    .map((spellId) {
                      final def = spellDefs[spellId];
                      final entry =
                          spellEntries[spellId] ?? const HeroSpellEntry();
                      if (def == null) {
                        return DataRow(
                          cells: [
                            DataCell(Text(spellId)),
                            const DataCell(Text('?')),
                            const DataCell(Text('0')),
                            const DataCell(Text('0')),
                            const DataCell(Text('?')),
                            const DataCell(Text('-')),
                            const DataCell(Text('-')),
                            if (isEditing) const DataCell(Text('-')),
                            const DataCell(Text('-')),
                            const DataCell(Text('-')),
                            const DataCell(Text('-')),
                            const DataCell(Text('-')),
                            const DataCell(Text('-')),
                            const DataCell(Text('-')),
                            const DataCell(Text('-')),
                            if (isEditing)
                              DataCell(
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    size: 18,
                                  ),
                                  onPressed: () => onRemoveSpell(spellId),
                                ),
                              ),
                          ],
                        );
                      }

                      final currentAvailabilityEntry =
                          entry.learnedRepresentation == null
                          ? null
                          : findSpellAvailabilityEntry(
                              availability: def.availability,
                              learnedRepresentation:
                                  entry.learnedRepresentation!,
                              originTradition: entry.learnedTradition,
                            );
                      final isLearnedAsForeign =
                          currentAvailabilityEntry?.isForeignRepresentation ==
                              true ||
                          isForeignLearnedRepresentation(
                            learnedRepresentation: entry.learnedRepresentation,
                            learnedTradition: entry.learnedTradition,
                          );
                      final fremdReprPenaltySteps = isLearnedAsForeign ? 2 : 0;
                      final probeLabel = _probeWithValuesLabel(
                        effectiveAttributes,
                        def.attributes,
                      );
                      final merkmale = parseSpellTraits(def.traits);
                      final effSteigerung = effectiveSteigerung(
                        basisSteigerung: def.steigerung,
                        istHauszauber: entry.hauszauber,
                        zauberMerkmale: merkmale,
                        heldMerkmalskenntnisse: merkmalskenntnisse,
                        istBegabt: entry.gifted,
                        fremdReprPenaltySteps: fremdReprPenaltySteps,
                      );
                      final representationLabel =
                          currentAvailabilityEntry == null
                          ? (entry.learnedRepresentation == null
                                ? 'Auswahl fehlt'
                                : isLearnedAsForeign
                                ? '${entry.learnedRepresentation!} '
                                      '(fremd: ${entry.learnedTradition})'
                                : entry.learnedRepresentation!)
                          : _compactRepresentationLabel(
                              currentAvailabilityEntry,
                            );
                      final availableEntriesForHero =
                          availableSpellEntriesForRepresentations(
                            def.availability,
                            heroRepresentationen,
                          );
                      final dropdownEntries = <SpellAvailabilityEntry>[
                        ...availableEntriesForHero,
                      ];
                      if (currentAvailabilityEntry != null &&
                          !dropdownEntries.any(
                            (candidate) =>
                                candidate.storageKey ==
                                currentAvailabilityEntry.storageKey,
                          )) {
                        dropdownEntries.add(currentAvailabilityEntry);
                      }
                      if (isLearnedAsForeign &&
                          currentAvailabilityEntry == null &&
                          entry.learnedTradition != null) {
                        for (final repr in heroRepresentationen) {
                          final synthetic = SpellAvailabilityEntry(
                            tradition: entry.learnedTradition!,
                            learnedRepresentation: repr,
                            verbreitung: 0,
                          );
                          if (!dropdownEntries.any(
                            (candidate) =>
                                candidate.storageKey == synthetic.storageKey,
                          )) {
                            dropdownEntries.add(synthetic);
                          }
                        }
                      }
                      final preview = _SpellTablePreview.fromSpell(
                        def: def,
                        entry: entry,
                      );

                      void openDetails() {
                        _openSpellDetails(context, spellId, def, entry);
                      }

                      return DataRow(
                        cells: [
                          DataCell(
                            SizedBox(
                              width: layout.contentWidthFor(0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: openDetails,
                                      child: Text(
                                        def.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  if (onRollSpell != null)
                                    IconButton(
                                      key: ValueKey<String>(
                                        'magic-spells-roll-$spellId',
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      iconSize: 18,
                                      tooltip: '${def.name} würfeln',
                                      onPressed: () =>
                                          onRollSpell!(spellId, def, entry),
                                      icon: const Icon(Icons.casino_outlined),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(
                            Text(probeLabel, style: theme.textTheme.bodySmall),
                          ),
                          isEditing
                              ? DataCell(
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          key: ValueKey<String>(
                                            'magic-spells-field-$spellId-spellValue',
                                          ),
                                          controller: controllerFor(
                                            spellId,
                                            'spellValue',
                                            entry.spellValue.toString(),
                                          ),
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(
                                              RegExp(r'-?\d*'),
                                            ),
                                          ],
                                          onChanged: (raw) =>
                                              onSpellValueChanged(spellId, raw),
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.bodySmall,
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                  vertical: 6,
                                                ),
                                          ),
                                        ),
                                      ),
                                      if (canRaiseValues &&
                                          onRaiseSpell != null)
                                        IconButton(
                                          key: ValueKey<String>(
                                            'magic-spells-raise-$spellId',
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          iconSize: 18,
                                          tooltip: 'Zauber steigern',
                                          onPressed: () =>
                                              onRaiseSpell!(spellId, def),
                                          icon: const Icon(Icons.trending_up),
                                        ),
                                    ],
                                  ),
                                )
                              : DataCell(Text(entry.spellValue.toString())),
                          isEditing
                              ? DataCell(
                                  TextField(
                                    key: ValueKey<String>(
                                      'magic-spells-field-$spellId-modifier',
                                    ),
                                    controller: controllerFor(
                                      spellId,
                                      'modifier',
                                      entry.modifier.toString(),
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'-?\d*'),
                                      ),
                                    ],
                                    onChanged: (raw) =>
                                        onModifierChanged(spellId, raw),
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 6,
                                      ),
                                    ),
                                  ),
                                )
                              : DataCell(Text(entry.modifier.toString())),
                          DataCell(
                            SizedBox(
                              width: layout.contentWidthFor(4),
                              child: isEditing
                                  ? DropdownButtonFormField<String>(
                                      key: ValueKey<String>(
                                        'magic-spells-repr-$spellId-${currentAvailabilityEntry?.storageKey ?? 'none'}',
                                      ),
                                      initialValue:
                                          currentAvailabilityEntry?.storageKey,
                                      isExpanded: true,
                                      isDense: true,
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 6,
                                        ),
                                      ),
                                      items: dropdownEntries
                                          .map((candidate) {
                                            return DropdownMenuItem<String>(
                                              value: candidate.storageKey,
                                              child: Text(
                                                candidate.displayLabel,
                                              ),
                                            );
                                          })
                                          .toList(growable: false),
                                      selectedItemBuilder: (context) {
                                        return dropdownEntries
                                            .map((candidate) {
                                              return Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  _compactRepresentationLabel(
                                                    candidate,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              );
                                            })
                                            .toList(growable: false);
                                      },
                                      onChanged: dropdownEntries.isEmpty
                                          ? null
                                          : (value) {
                                              if (value == null) {
                                                return;
                                              }
                                              final selected = dropdownEntries
                                                  .firstWhere(
                                                    (candidate) =>
                                                        candidate.storageKey ==
                                                        value,
                                                  );
                                              onLearnedRepresentationChanged(
                                                spellId,
                                                selected,
                                              );
                                            },
                                    )
                                  : Text(
                                      representationLabel,
                                      style: currentAvailabilityEntry == null
                                          ? theme.textTheme.bodySmall?.copyWith(
                                              color: theme.colorScheme.error,
                                            )
                                          : theme.textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                            ),
                          ),
                          DataCell(
                            Text(
                              effSteigerung,
                              style:
                                  effSteigerung != def.steigerung ||
                                      currentAvailabilityEntry == null
                                  ? theme.textTheme.bodySmall?.copyWith(
                                      color: currentAvailabilityEntry == null
                                          ? theme.colorScheme.error
                                          : theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    )
                                  : theme.textTheme.bodySmall,
                            ),
                          ),
                          DataCell(
                            isEditing
                                ? Checkbox(
                                    key: ValueKey<String>(
                                      'magic-spells-hauszauber-$spellId',
                                    ),
                                    value: entry.hauszauber,
                                    onChanged: (value) => onHauszauberChanged(
                                      spellId,
                                      value ?? false,
                                    ),
                                  )
                                : Icon(
                                    entry.hauszauber
                                        ? Icons.star
                                        : Icons.star_border,
                                    size: 18,
                                    color: entry.hauszauber
                                        ? theme.colorScheme.primary
                                        : theme.disabledColor,
                                  ),
                          ),
                          if (isEditing)
                            DataCell(
                              Checkbox(
                                key: ValueKey<String>(
                                  'magic-spells-gifted-$spellId',
                                ),
                                value: entry.gifted,
                                onChanged: (value) =>
                                    onGiftedChanged(spellId, value ?? false),
                              ),
                            ),
                          DataCell(
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: layout.contentWidthFor(
                                  isEditing ? 8 : 7,
                                ),
                              ),
                              child: Text(
                                def.traits.isNotEmpty ? def.traits : '-',
                                style: theme.textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          _buildDetailCell(
                            width: layout.contentWidthFor(isEditing ? 9 : 8),
                            context: context,
                            text: preview.castingTime,
                            onTap: openDetails,
                          ),
                          _buildDetailCell(
                            width: layout.contentWidthFor(isEditing ? 10 : 9),
                            context: context,
                            text: preview.aspCost,
                            onTap: openDetails,
                          ),
                          _buildDetailCell(
                            width: layout.contentWidthFor(isEditing ? 11 : 10),
                            context: context,
                            text: preview.range,
                            onTap: openDetails,
                          ),
                          _buildDetailCell(
                            width: layout.contentWidthFor(isEditing ? 12 : 11),
                            context: context,
                            text: preview.duration,
                            onTap: openDetails,
                          ),
                          _buildDetailCell(
                            width: layout.contentWidthFor(isEditing ? 13 : 12),
                            context: context,
                            text: preview.wirkung,
                            maxLines: 2,
                            underline: true,
                            onTap: openDetails,
                          ),
                          _buildVariantsCell(
                            width: layout.contentWidthFor(isEditing ? 14 : 13),
                            context: context,
                            variants: preview.variants,
                            protectedPreview: preview.variantsProtected,
                            onTap: openDetails,
                          ),
                          if (isEditing)
                            DataCell(
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  size: 18,
                                ),
                                onPressed: () => onRemoveSpell(spellId),
                                tooltip: 'Deaktivieren',
                              ),
                            ),
                        ],
                      );
                    })
                    .toList(growable: false),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Schlanke Tabellenvorschau ohne Entschluesselung geschuetzter Langtexte.
class _SpellTablePreview {
  const _SpellTablePreview({
    required this.aspCost,
    required this.range,
    required this.duration,
    required this.castingTime,
    required this.wirkung,
    required this.variants,
    required this.variantsProtected,
  });

  factory _SpellTablePreview.fromSpell({
    required SpellDef def,
    required HeroSpellEntry entry,
  }) {
    final overrides = entry.textOverrides;
    final protectedWirkung =
        overrides?.wirkung == null && isProtectedCatalogValue(def.wirkung);
    final protectedVariants =
        overrides?.variants == null &&
        def.rawVariantsEncrypted != null &&
        isProtectedCatalogValue(def.rawVariantsEncrypted);

    return _SpellTablePreview(
      aspCost: overrides?.aspCost ?? def.aspCost,
      range: overrides?.range ?? def.range,
      duration: overrides?.duration ?? def.duration,
      castingTime: overrides?.castingTime ?? def.castingTime,
      wirkung: protectedWirkung
          ? protectedContentDetailHint
          : (overrides?.wirkung ?? def.wirkung),
      variants: overrides?.variants ?? def.variants,
      variantsProtected: protectedVariants,
    );
  }

  final String aspCost;
  final String range;
  final String duration;
  final String castingTime;
  final String wirkung;
  final List<String> variants;
  final bool variantsProtected;
}

String _compactRepresentationLabel(SpellAvailabilityEntry entry) {
  if (!entry.isForeignRepresentation) {
    return entry.learnedRepresentation;
  }
  return '${entry.learnedRepresentation} via ${entry.tradition}';
}

DataCell _buildDetailCell({
  required BuildContext context,
  required double width,
  required String text,
  required VoidCallback onTap,
  int maxLines = 1,
  bool underline = false,
}) {
  final theme = Theme.of(context);
  final preview = text.isNotEmpty ? text : '-';
  return DataCell(
    GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Text(
          preview,
          style: theme.textTheme.bodySmall?.copyWith(
            decoration: underline && text.isNotEmpty
                ? TextDecoration.underline
                : null,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: maxLines,
        ),
      ),
    ),
  );
}

DataCell _buildVariantsCell({
  required BuildContext context,
  required double width,
  required List<String> variants,
  bool protectedPreview = false,
  required VoidCallback onTap,
}) {
  final theme = Theme.of(context);
  final Widget content;
  if (protectedPreview) {
    content = Text(
      protectedContentDetailHint,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.primary,
        decoration: TextDecoration.underline,
      ),
      overflow: TextOverflow.ellipsis,
    );
  } else if (variants.isEmpty) {
    content = Text('-', style: theme.textTheme.bodySmall);
  } else {
    content = Text(
      '${variants.length}x ${variants.first}',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  return DataCell(
    GestureDetector(
      onTap: onTap,
      child: SizedBox(width: width, child: content),
    ),
  );
}

/// Baut ein Eigenschaften-Label mit Werten aus Attributnamen und Heldenwerten.
///
/// Input: ['Mut', 'Klugheit', 'Charisma'], attributes
/// Output: 'MU: 14 | KL: 12 | CH: 11'
String _probeWithValuesLabel(
  Attributes attributes,
  List<String> attributeNames,
) {
  final parts = <String>[];
  for (final name in attributeNames) {
    final code = parseAttributeCode(name);
    if (code == null) {
      parts.add('??');
      continue;
    }
    final value = readAttributeValue(attributes, code);
    parts.add('${_attributeCodeLabel(code)}: $value');
  }
  return parts.join(' | ');
}

String _attributeCodeLabel(AttributeCode code) {
  switch (code) {
    case AttributeCode.mu:
      return 'MU';
    case AttributeCode.kl:
      return 'KL';
    case AttributeCode.inn:
      return 'IN';
    case AttributeCode.ch:
      return 'CH';
    case AttributeCode.ff:
      return 'FF';
    case AttributeCode.ge:
      return 'GE';
    case AttributeCode.ko:
      return 'KO';
    case AttributeCode.kk:
      return 'KK';
  }
}
