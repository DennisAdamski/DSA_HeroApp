part of 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';

/// Dialog mit Detailansicht eines Talents (Katalog-Daten + Heldenwerte).
///
/// Im Read-Only-Modus (`isEditing == false`) reine Anzeige. Im Edit-Modus
/// bietet das Sheet Eingabefelder fuer TaW (und AT/PA bei Kampftalenten),
/// Modifikatoren, Spezialerfahrungen, Spezialisierungen sowie Begabung.
class _TalentDetailDialog extends StatefulWidget {
  const _TalentDetailDialog({
    required this.talent,
    required this.entry,
    required this.complexityResolution,
    required this.effectiveAttributes,
    required this.activeBaseBe,
    this.inventoryMod = 0,
    this.isEditing = false,
    this.state,
  });

  final TalentDef talent;
  final HeroTalentEntry entry;
  final TalentComplexityResolution complexityResolution;
  final Attributes effectiveAttributes;
  final int activeBaseBe;

  /// Summe aktiver Inventar-Modifikatoren fuer dieses Talent.
  final int inventoryMod;

  /// Aktiviert die Bearbeitungs-UI im Sheet.
  final bool isEditing;

  /// State-Referenz fuer Zugriff auf Edit-Helfer (Pflicht, wenn
  /// [isEditing] gesetzt ist).
  final _HeroTalentTableTabState? state;

  @override
  State<_TalentDetailDialog> createState() => _TalentDetailDialogState();
}

class _TalentDetailDialogState extends State<_TalentDetailDialog> {
  HeroTalentEntry get _liveEntry {
    if (widget.isEditing && widget.state != null) {
      return widget.state!._entryForTalent(widget.talent.id);
    }
    return widget.entry;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final talent = widget.talent;
    final entry = _liveEntry;
    final isCombat = talent.group.toLowerCase().contains('kampf');
    final isEditing = widget.isEditing && widget.state != null;
    final state = widget.state;
    final inventoryMod = widget.inventoryMod;
    final activeBaseBe = widget.activeBaseBe;
    final maxTaw = isCombat
        ? computeCombatTalentMaxValue(
            effectiveAttributes: widget.effectiveAttributes,
            talentType: talent.type,
            gifted: entry.gifted,
          )
        : computeTalentMaxValue(
            effectiveAttributes: widget.effectiveAttributes,
            attributeNames: talent.attributes,
            gifted: entry.gifted,
          );
    final specs = entry.combatSpecializations.isNotEmpty
        ? entry.combatSpecializations
        : entry.specializations
              .split(RegExp(r'[\n,;]+'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();

    return AlertDialog(
      title: Text(talent.name),
      content: SizedBox(
        width: kDialogWidthMedium,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(theme, 'Katalog-Daten'),
              _detailRow(theme, 'Gruppe', talent.group),
              if (talent.type.isNotEmpty) _detailRow(theme, 'Typ', talent.type),
              _detailRow(
                theme,
                'Steigerung',
                widget.complexityResolution.effectiveKomplexitaet,
              ),
              if (widget.complexityResolution.isOverridden)
                _detailRow(
                  theme,
                  'Basis',
                  widget.complexityResolution.baseKomplexitaet,
                ),
              if (widget.complexityResolution.isOverridden)
                _detailRow(
                  theme,
                  'Hausregel',
                  widget.complexityResolution.packTitle,
                ),
              _detailRow(theme, 'Eigenschaften', talent.attributes.join(', ')),
              if (talent.be.isNotEmpty)
                _detailRow(theme, 'BE-Regel', talent.be),
              if (talent.weaponCategory.isNotEmpty)
                _detailRow(theme, 'Waffengattung', talent.weaponCategory),
              if (talent.alternatives.isNotEmpty)
                _detailRow(theme, 'Ersatzweise', talent.alternatives),
              const Divider(height: 16),
              _sectionTitle(theme, 'Heldenwerte'),
              if (isEditing) ...[
                _editFieldRow(
                  theme,
                  'TaW',
                  _buildIntEditor(
                    state: state!,
                    field: 'talentValue',
                    value: entry.talentValue ?? 0,
                  ),
                ),
                if (isCombat) ...[
                  _editFieldRow(
                    theme,
                    'AT',
                    _buildIntEditor(
                      state: state,
                      field: 'atValue',
                      value: entry.atValue,
                    ),
                  ),
                  _editFieldRow(
                    theme,
                    'PA',
                    _buildIntEditor(
                      state: state,
                      field: 'paValue',
                      value: entry.paValue,
                    ),
                  ),
                ],
                _editFieldRow(
                  theme,
                  'SE',
                  _buildIntEditor(
                    state: state,
                    field: 'specialExperiences',
                    value: entry.specialExperiences,
                  ),
                ),
                _editFieldRow(
                  theme,
                  'Gesamt-Mod',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () async {
                            await state._openTalentModifiersDialog(
                              talent: talent,
                              entry: entry,
                            );
                            if (mounted) setState(() {});
                          },
                          icon: const Icon(Icons.tune, size: 16),
                          label: Text(
                            '${entry.modifier + inventoryMod}',
                          ),
                        ),
                      ),
                      ...entry.talentModifiers.map(
                        (modifier) => Padding(
                          padding: const EdgeInsets.only(left: 8, top: 2),
                          child: _detailRow(
                            theme,
                            modifier.description,
                            '${modifier.modifier}',
                          ),
                        ),
                      ),
                      if (inventoryMod != 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 8, top: 2),
                          child: _detailRow(
                            theme,
                            'Ausrüstung',
                            '$inventoryMod',
                          ),
                        ),
                    ],
                  ),
                ),
                _editFieldRow(
                  theme,
                  'Begabung',
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Checkbox(
                      value: entry.gifted,
                      onChanged: (next) {
                        state._updateGifted(talent.id, next ?? false);
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                ),
              ] else ...[
                _detailRow(
                  theme,
                  'TaW',
                  entry.talentValue != null ? '${entry.talentValue}' : '—',
                ),
                if (isCombat) ...[
                  _detailRow(theme, 'AT', '${entry.atValue}'),
                  _detailRow(theme, 'PA', '${entry.paValue}'),
                ],
                if (entry.talentModifiers.isNotEmpty || inventoryMod != 0) ...[
                  _detailRow(
                    theme,
                    'Gesamt-Mod',
                    '${entry.modifier + inventoryMod}',
                  ),
                  const SizedBox(height: 4),
                  _sectionTitle(theme, 'Modifikatoren'),
                  ...entry.talentModifiers.map(
                    (modifier) => _detailRow(
                      theme,
                      modifier.description,
                      '${modifier.modifier}',
                    ),
                  ),
                  if (inventoryMod != 0)
                    _detailRow(theme, 'Ausrüstung', '$inventoryMod'),
                ] else if (entry.modifier != 0)
                  _detailRow(theme, 'Modifikator', '${entry.modifier}'),
                if (entry.specialExperiences > 0)
                  _detailRow(theme, 'SE', '${entry.specialExperiences}'),
                if (entry.gifted) _detailRow(theme, 'Begabung', 'Ja'),
              ],
              _detailRow(theme, 'max TaW', '$maxTaw'),
              if (!isCombat) ...[
                _detailRow(
                  theme,
                  'eBE',
                  '${computeTalentEbe(baseBe: activeBaseBe, talentBeRule: talent.be)}',
                ),
                _detailRow(
                  theme,
                  'TaW*',
                  '${computeTalentComputedTaw(
                    talentValue: entry.talentValue,
                    modifier: entry.modifier,
                    ebe: computeTalentEbe(baseBe: activeBaseBe, talentBeRule: talent.be),
                    inventoryMod: inventoryMod,
                  )}',
                ),
              ],
              if (isEditing || specs.isNotEmpty) ...[
                const Divider(height: 16),
                _sectionTitle(theme, 'Spezialisierungen'),
                if (isEditing)
                  _buildSpecializationEditor(state: state!, talent: talent)
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: specs
                        .map(
                          (s) => Chip(
                            label: Text(s),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                adaptiveTapTargetSize(context),
                            padding: EdgeInsets.zero,
                            labelPadding: const EdgeInsets.symmetric(
                              horizontal: 6,
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
      ],
    );
  }

  Widget _buildIntEditor({
    required _HeroTalentTableTabState state,
    required String field,
    required int value,
  }) {
    final controller = state._controllerFor(
      widget.talent.id,
      field,
      value.toString(),
    );
    return SizedBox(
      width: 96,
      child: TextField(
        key: ValueKey<String>(
          'talent-detail-edit-${widget.talent.id}-$field',
        ),
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
        ),
        onChanged: (raw) {
          state._updateIntField(widget.talent.id, field, raw);
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Widget _buildSpecializationEditor({
    required _HeroTalentTableTabState state,
    required TalentDef talent,
  }) {
    final isCombat = talent.group.toLowerCase().contains('kampf');
    if (isCombat) {
      return state._combatSpecializationCell(
        talent: talent,
        entry: _liveEntry,
        isEditing: true,
      );
    }
    return state._specializationBadgesCell(
      talentId: talent.id,
      entry: _liveEntry,
      isEditing: true,
    );
  }

  Widget _sectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _detailRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }

  Widget _editFieldRow(ThemeData theme, String label, Widget editor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: editor),
        ],
      ),
    );
  }
}

/// Dialog mit Detailansicht eines Meta-Talents inklusive Komponenten und Probe.
class _MetaTalentDetailDialog extends StatelessWidget {
  const _MetaTalentDetailDialog({
    required this.metaTalent,
    required this.effectiveAttributes,
    required this.activeBaseBe,
    required this.componentNames,
    required this.rawTaw,
    required this.computedTaw,
  });

  final HeroMetaTalent metaTalent;
  final Attributes effectiveAttributes;
  final int activeBaseBe;
  final List<String> componentNames;
  final int rawTaw;
  final int computedTaw;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxTaw = computeTalentMaxValue(
      effectiveAttributes: effectiveAttributes,
      attributeNames: metaTalent.attributes,
      gifted: false,
    );
    final ebe = computeMetaTalentEbe(
      baseBe: activeBaseBe,
      beRule: metaTalent.be,
    );

    return AlertDialog(
      title: Text(metaTalent.name),
      content: SizedBox(
        width: kDialogWidthMedium,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(theme, 'Meta-Talent'),
              _detailRow(theme, 'Typ', 'Heldenspezifisches Meta-Talent'),
              _detailRow(
                theme,
                'Eigenschaften',
                metaTalent.attributes.join(', '),
              ),
              if (metaTalent.be.isNotEmpty)
                _detailRow(theme, 'BE-Regel', metaTalent.be),
              const Divider(height: 16),
              _sectionTitle(theme, 'Heldenwerte'),
              _detailRow(theme, 'Roh-TaW', '$rawTaw'),
              _detailRow(theme, 'eBE', '$ebe'),
              _detailRow(theme, 'TaW*', '$computedTaw'),
              _detailRow(theme, 'max TaW', '$maxTaw'),
              const Divider(height: 16),
              _sectionTitle(theme, 'Bestandteile'),
              ...componentNames.map(
                (componentName) => _detailRow(theme, 'Talent', componentName),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
      ],
    );
  }

  Widget _sectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _detailRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
