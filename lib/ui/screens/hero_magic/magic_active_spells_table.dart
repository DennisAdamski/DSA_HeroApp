part of '../hero_magic_tab.dart';

/// Tabelle der aktivierten Zauber mit editierbaren ZfW-Werten und Detailzugriff.
class _MagicActiveSpellsTable extends StatelessWidget {
  const _MagicActiveSpellsTable({
    required this.activeSpellIds,
    required this.spellEntries,
    required this.spellDefs,
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
    this.onAddSpell,
  });

  final List<String> activeSpellIds;
  final Map<String, HeroSpellEntry> spellEntries;
  final Map<String, SpellDef> spellDefs;
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
  final VoidCallback? onAddSpell;

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
    );
    if (result == null) {
      return;
    }
    onTextOverridesChanged(spellId, result.overrides);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (activeSpellIds.isEmpty) {
      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Keine Zauber aktiviert.', style: theme.textTheme.bodySmall),
              if (isEditing && onAddSpell != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const ValueKey<String>('magic-spells-add'),
                  onPressed: onAddSpell,
                  icon: const Icon(Icons.add),
                  label: const Text('Zauber hinzufügen'),
                ),
              ],
            ],
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

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        childrenPadding: EdgeInsets.zero,
        title: Row(
          children: [
            Text('Aktivierte Zauber', style: theme.textTheme.titleSmall),
            const SizedBox(width: 8),
            Text('(${sortedIds.length})', style: theme.textTheme.bodySmall),
          ],
        ),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 12,
              horizontalMargin: 12,
              headingRowHeight: 36,
              dataRowMinHeight: 36,
              dataRowMaxHeight: 52,
              columns: [
                const DataColumn(label: Text('Name')),
                const DataColumn(label: Text('Probe')),
                const DataColumn(label: Text('ZfW'), numeric: true),
                const DataColumn(label: Text('Mod'), numeric: true),
                const DataColumn(label: Text('Repr.')),
                const DataColumn(label: Text('Kompl.')),
                const DataColumn(label: Text('HZ')),
                if (isEditing) const DataColumn(label: Text('Beg.')),
                const DataColumn(label: Text('Merkmale')),
                const DataColumn(label: Text('Zauberdauer')),
                const DataColumn(label: Text('Kosten')),
                const DataColumn(label: Text('Reichweite')),
                const DataColumn(label: Text('Dauer')),
                const DataColumn(label: Text('Wirkung')),
                const DataColumn(label: Text('Varianten')),
                if (isEditing) const DataColumn(label: Text('')),
              ],
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

                    final resolved = _ResolvedSpellDetails.fromSpell(
                      def: def,
                      entry: entry,
                    );
                    final currentAvailabilityEntry =
                        entry.learnedRepresentation == null
                        ? null
                        : findSpellAvailabilityEntry(
                            availability: def.availability,
                            learnedRepresentation:
                                entry.learnedRepresentation!,
                            originTradition: entry.learnedTradition,
                          );
                    final fremdReprPenaltySteps =
                        currentAvailabilityEntry?.isForeignRepresentation ==
                            true
                        ? 2
                        : 0;
                    final probeLabel = _shortProbeLabel(def.attributes);
                    final merkmale = parseSpellTraits(def.traits);
                    final effSteigerung = effectiveSteigerung(
                      basisSteigerung: def.steigerung,
                      istHauszauber: entry.hauszauber,
                      zauberMerkmale: merkmale,
                      heldMerkmalskenntnisse: merkmalskenntnisse,
                      istBegabt: entry.gifted,
                      fremdReprPenaltySteps: fremdReprPenaltySteps,
                    );
                    final representationLabel = currentAvailabilityEntry == null
                        ? (entry.learnedRepresentation == null
                              ? 'Auswahl fehlt'
                              : entry.learnedRepresentation!)
                        : _compactRepresentationLabel(currentAvailabilityEntry);
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

                    void openDetails() {
                      _openSpellDetails(context, spellId, def, entry);
                    }

                    return DataRow(
                      cells: [
                        DataCell(
                          GestureDetector(
                            onTap: openDetails,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 180),
                              child: Text(
                                def.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(probeLabel, style: theme.textTheme.bodySmall),
                        ),
                        isEditing
                            ? DataCell(
                                SizedBox(
                                  width: 48,
                                  child: TextField(
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
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 6,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : DataCell(Text(entry.spellValue.toString())),
                        isEditing
                            ? DataCell(
                                SizedBox(
                                  width: 48,
                                  child: TextField(
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
                                ),
                              )
                            : DataCell(Text(entry.modifier.toString())),
                        DataCell(
                          isEditing
                              ? SizedBox(
                                  width: 140,
                                  child: DropdownButtonFormField<String>(
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
                                    items: dropdownEntries.map((candidate) {
                                      return DropdownMenuItem<String>(
                                        value: candidate.storageKey,
                                        child: Text(candidate.displayLabel),
                                      );
                                    }).toList(growable: false),
                                    selectedItemBuilder: (context) {
                                      return dropdownEntries.map((candidate) {
                                        return Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            _compactRepresentationLabel(
                                              candidate,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(growable: false);
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
                                  ),
                                )
                              : Text(
                                  representationLabel,
                                  style: currentAvailabilityEntry == null
                                      ? theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.error,
                                        )
                                      : theme.textTheme.bodySmall,
                                ),
                        ),
                        DataCell(
                          Text(
                            effSteigerung,
                            style: effSteigerung != def.steigerung ||
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
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Text(
                              def.traits.isNotEmpty ? def.traits : '-',
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        _buildDetailCell(
                          context: context,
                          text: resolved.castingTime,
                          maxWidth: 120,
                          onTap: openDetails,
                        ),
                        _buildDetailCell(
                          context: context,
                          text: resolved.aspCost,
                          maxWidth: 120,
                          onTap: openDetails,
                        ),
                        _buildDetailCell(
                          context: context,
                          text: resolved.range,
                          maxWidth: 140,
                          onTap: openDetails,
                        ),
                        _buildDetailCell(
                          context: context,
                          text: resolved.duration,
                          maxWidth: 120,
                          onTap: openDetails,
                        ),
                        _buildDetailCell(
                          context: context,
                          text: resolved.wirkung,
                          maxWidth: 140,
                          maxLines: 2,
                          underline: true,
                          onTap: openDetails,
                        ),
                        _buildVariantsCell(
                          context: context,
                          variants: resolved.variants,
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
          ),
          if (isEditing && onAddSpell != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: OutlinedButton.icon(
                key: const ValueKey<String>('magic-spells-add'),
                onPressed: onAddSpell,
                icon: const Icon(Icons.add),
                label: const Text('Zauber hinzufügen'),
              ),
            ),
        ],
      ),
    );
  }
}

String _compactRepresentationLabel(SpellAvailabilityEntry entry) {
  if (!entry.isForeignRepresentation) {
    return entry.learnedRepresentation;
  }
  return '${entry.learnedRepresentation} via ${entry.tradition}';
}

DataCell _buildDetailCell({
  required BuildContext context,
  required String text,
  required double maxWidth,
  required VoidCallback onTap,
  int maxLines = 1,
  bool underline = false,
}) {
  final theme = Theme.of(context);
  final preview = text.isNotEmpty ? text : '-';
  return DataCell(
    GestureDetector(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
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
  required List<String> variants,
  required VoidCallback onTap,
}) {
  final theme = Theme.of(context);
  return DataCell(
    GestureDetector(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 140),
        child: variants.isEmpty
            ? Text('-', style: theme.textTheme.bodySmall)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${variants.length}× ',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      variants.first,
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    ),
  );
}

/// Baut ein kompaktes Probe-Label aus den drei Attributnamen.
///
/// Input: ['Mut', 'Klugheit', 'Charisma']
/// Output: 'MU/KL/CH'
String _shortProbeLabel(List<String> attributeNames) {
  final parts = <String>[];
  for (final name in attributeNames) {
    final code = parseAttributeCode(name);
    if (code == null) {
      parts.add('??');
      continue;
    }
    parts.add(_attributeCodeLabel(code));
  }
  return parts.join('/');
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
