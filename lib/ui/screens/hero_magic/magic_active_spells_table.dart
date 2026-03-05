part of '../hero_magic_tab.dart';

/// Tabelle der aktivierten Zauber mit editierbaren ZfW-Werten und vollstaendigen Infos.
class _MagicActiveSpellsTable extends StatelessWidget {
  const _MagicActiveSpellsTable({
    required this.activeSpellIds,
    required this.spellEntries,
    required this.spellDefs,
    required this.merkmalskenntnisse,
    required this.isEditing,
    required this.onSpellValueChanged,
    required this.onModifierChanged,
    required this.onHauszauberChanged,
    required this.onSpecializationsChanged,
    required this.onRemoveSpell,
    required this.controllerFor,
    this.onAddSpell,
  });

  final List<String> activeSpellIds;
  final Map<String, HeroSpellEntry> spellEntries;
  final Map<String, SpellDef> spellDefs;
  final List<String> merkmalskenntnisse;
  final bool isEditing;
  final void Function(String spellId, String raw) onSpellValueChanged;
  final void Function(String spellId, String raw) onModifierChanged;
  final void Function(String spellId, bool value) onHauszauberChanged;
  final void Function(String spellId, String raw) onSpecializationsChanged;
  final void Function(String spellId) onRemoveSpell;
  final TextEditingController Function(String id, String field, String initial)
      controllerFor;
  final VoidCallback? onAddSpell;

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
              Text(
                'Keine Zauber aktiviert.',
                style: theme.textTheme.bodySmall,
              ),
              if (isEditing && onAddSpell != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
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

    // Sortiere aktive Zauber alphabetisch nach Name.
    final sortedIds = List<String>.from(activeSpellIds)
      ..sort((a, b) {
        final defA = spellDefs[a];
        final defB = spellDefs[b];
        if (defA == null || defB == null) return 0;
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
                const DataColumn(label: Text('Stg')),
                const DataColumn(label: Text('HZ')),
                const DataColumn(label: Text('Merkmale')),
                const DataColumn(label: Text('Zauberdauer')),
                const DataColumn(label: Text('AsP')),
                const DataColumn(label: Text('Reichweite')),
                const DataColumn(label: Text('Wirkung')),
                const DataColumn(label: Text('Spezialisierungen')),
                if (isEditing) const DataColumn(label: Text('')),
              ],
              rows: sortedIds.map((spellId) {
                final def = spellDefs[spellId];
                final entry = spellEntries[spellId] ??
                    const HeroSpellEntry();
                if (def == null) {
                  return DataRow(cells: [
                    DataCell(Text(spellId)),
                    const DataCell(Text('?')),
                    const DataCell(Text('0')),
                    const DataCell(Text('0')),
                    const DataCell(Text('?')),
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
                          icon: const Icon(Icons.remove_circle_outline,
                              size: 18),
                          onPressed: () => onRemoveSpell(spellId),
                        ),
                      ),
                  ]);
                }

                final probeLabel = _shortProbeLabel(def.attributes);
                final merkmale = parseSpellTraits(def.traits);
                final effSteigerung = effectiveSteigerung(
                  basisSteigerung: def.steigerung,
                  istHauszauber: entry.hauszauber,
                  zauberMerkmale: merkmale,
                  heldMerkmalskenntnisse: merkmalskenntnisse,
                );

                return DataRow(
                  cells: [
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: Text(def.name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    DataCell(Text(probeLabel,
                        style: theme.textTheme.bodySmall)),
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
                                      RegExp(r'-?\d*')),
                                ],
                                onChanged: (raw) =>
                                    onSpellValueChanged(spellId, raw),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 6),
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
                                      RegExp(r'-?\d*')),
                                ],
                                onChanged: (raw) =>
                                    onModifierChanged(spellId, raw),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 6),
                                ),
                              ),
                            ),
                          )
                        : DataCell(Text(entry.modifier.toString())),
                    DataCell(Text(
                      effSteigerung,
                      style: effSteigerung != def.steigerung
                          ? theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            )
                          : theme.textTheme.bodySmall,
                    )),
                    DataCell(
                      isEditing
                          ? Checkbox(
                              value: entry.hauszauber,
                              onChanged: (value) => onHauszauberChanged(
                                  spellId, value ?? false),
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
                    DataCell(Text(
                      def.castingTime.isNotEmpty ? def.castingTime : '-',
                      style: theme.textTheme.bodySmall,
                    )),
                    DataCell(Text(
                      def.aspCost.isNotEmpty ? def.aspCost : '-',
                      style: theme.textTheme.bodySmall,
                    )),
                    DataCell(Text(
                      def.range.isNotEmpty ? def.range : '-',
                      style: theme.textTheme.bodySmall,
                    )),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Text(
                          def.duration.isNotEmpty ? def.duration : '-',
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    isEditing
                        ? DataCell(
                            SizedBox(
                              width: 120,
                              child: TextField(
                                controller: controllerFor(
                                  spellId,
                                  'specializations',
                                  entry.specializations,
                                ),
                                onChanged: (raw) =>
                                    onSpecializationsChanged(spellId, raw),
                                style: theme.textTheme.bodySmall,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  hintText: 'Spezialisierung…',
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 6),
                                ),
                              ),
                            ),
                          )
                        : DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 120),
                              child: Text(
                                entry.specializations.isNotEmpty
                                    ? entry.specializations
                                    : '-',
                                style: theme.textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                    if (isEditing)
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
                              size: 18),
                          onPressed: () => onRemoveSpell(spellId),
                          tooltip: 'Deaktivieren',
                        ),
                      ),
                  ],
                );
              }).toList(growable: false),
            ),
          ),
          if (isEditing && onAddSpell != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: OutlinedButton.icon(
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
