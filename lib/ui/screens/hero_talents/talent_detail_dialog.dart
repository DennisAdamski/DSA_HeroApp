part of 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';

/// Dialog mit Detailansicht eines Talents (Katalog-Daten + Heldenwerte).
class _TalentDetailDialog extends StatelessWidget {
  const _TalentDetailDialog({
    required this.talent,
    required this.entry,
    required this.effectiveAttributes,
    required this.activeBaseBe,
    this.inventoryMod = 0,
  });

  final TalentDef talent;
  final HeroTalentEntry entry;
  final Attributes effectiveAttributes;
  final int activeBaseBe;

  /// Summe aktiver Inventar-Modifikatoren fuer dieses Talent.
  final int inventoryMod;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCombat = talent.group.toLowerCase().contains('kampf');
    final effectiveSteigerung = effectiveTalentLernkomplexitaet(
      basisKomplexitaet: talent.steigerung,
      gifted: entry.gifted,
    );
    final maxTaw = isCombat
        ? computeCombatTalentMaxValue(
            effectiveAttributes: effectiveAttributes,
            talentType: talent.type,
            gifted: entry.gifted,
          )
        : computeTalentMaxValue(
            effectiveAttributes: effectiveAttributes,
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
              _detailRow(theme, 'Steigerung', effectiveSteigerung),
              _detailRow(theme, 'Eigenschaften', talent.attributes.join(', ')),
              if (talent.be.isNotEmpty)
                _detailRow(theme, 'BE-Regel', talent.be),
              if (talent.weaponCategory.isNotEmpty)
                _detailRow(theme, 'Waffengattung', talent.weaponCategory),
              if (talent.alternatives.isNotEmpty)
                _detailRow(theme, 'Ersatzweise', talent.alternatives),
              const Divider(height: 16),
              _sectionTitle(theme, 'Heldenwerte'),
              _detailRow(theme, 'TaW', entry.talentValue != null ? '${entry.talentValue}' : '—'),
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
              _detailRow(theme, 'max TaW', '$maxTaw'),
              if (!isCombat) ...[
                _detailRow(
                  theme,
                  'eBE',
                  '${computeTalentEbe(baseBe: activeBaseBe, talentBeRule: talent.be)}',
                ),
                _detailRow(
                  theme,
                  'TaW berechnet',
                  '${computeTalentComputedTaw(
                    talentValue: entry.talentValue,
                    modifier: entry.modifier,
                    ebe: computeTalentEbe(baseBe: activeBaseBe, talentBeRule: talent.be),
                    inventoryMod: inventoryMod,
                  )}',
                ),
              ],
              if (specs.isNotEmpty) ...[
                const Divider(height: 16),
                _sectionTitle(theme, 'Spezialisierungen'),
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
          child: const Text('Schliessen'),
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
