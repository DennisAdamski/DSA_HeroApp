part of '../hero_magic_tab.dart';

/// Sektion zur Verwaltung heldenspezifischer Ritualkategorien und Rituale.
class _MagicRitualsSection extends StatelessWidget {
  const _MagicRitualsSection({
    required this.ritualCategories,
    required this.catalogTalents,
    required this.heroTalents,
    required this.isEditing,
    required this.onChanged,
    this.onEnsureEditing,
  });

  final List<HeroRitualCategory> ritualCategories;
  final List<TalentDef> catalogTalents;
  final Map<String, HeroTalentEntry> heroTalents;
  final bool isEditing;
  final void Function(List<HeroRitualCategory>) onChanged;
  final Future<void> Function()? onEnsureEditing;

  Future<void> _addCategory(BuildContext context) async {
    await onEnsureEditing?.call();
    if (!context.mounted) {
      return;
    }
    final created = await _showRitualCategoryDialog(
      context: context,
      catalogTalents: catalogTalents,
    );
    if (created == null) {
      return;
    }
    onChanged(normalizeRitualCategories([...ritualCategories, created]));
  }

  Future<void> _editCategory(
    BuildContext context,
    int categoryIndex,
    HeroRitualCategory category,
  ) async {
    final updatedCategory = await _showRitualCategoryDialog(
      context: context,
      catalogTalents: catalogTalents,
      existing: category,
    );
    if (updatedCategory == null) {
      return;
    }
    final updated = List<HeroRitualCategory>.from(ritualCategories);
    updated[categoryIndex] = updatedCategory;
    onChanged(normalizeRitualCategories(updated));
  }

  void _removeCategory(int categoryIndex) {
    final updated = List<HeroRitualCategory>.from(ritualCategories);
    updated.removeAt(categoryIndex);
    onChanged(normalizeRitualCategories(updated));
  }

  Future<void> _openRitualDialog(
    BuildContext context,
    int categoryIndex,
    HeroRitualCategory category, {
    int? ritualIndex,
  }) async {
    final existing = ritualIndex == null ? null : category.rituals[ritualIndex];
    final updatedRitual = await _showRitualEntryDialog(
      context: context,
      category: category,
      existing: existing,
      isEditing: isEditing,
    );
    if (updatedRitual == null) {
      return;
    }
    final updatedCategory = _withUpdatedRitual(
      category,
      updatedRitual,
      ritualIndex: ritualIndex,
    );
    final updatedCategories = List<HeroRitualCategory>.from(ritualCategories);
    updatedCategories[categoryIndex] = updatedCategory;
    onChanged(normalizeRitualCategories(updatedCategories));
  }

  HeroRitualCategory _withUpdatedRitual(
    HeroRitualCategory category,
    HeroRitualEntry ritual, {
    int? ritualIndex,
  }) {
    final updatedRituals = List<HeroRitualEntry>.from(category.rituals);
    if (ritualIndex == null) {
      updatedRituals.add(ritual);
    } else {
      updatedRituals[ritualIndex] = ritual;
    }
    return normalizeRitualCategory(category.copyWith(rituals: updatedRituals));
  }

  void _removeRitual(int categoryIndex, int ritualIndex) {
    final updatedCategory = ritualCategories[categoryIndex];
    final updatedRituals = List<HeroRitualEntry>.from(updatedCategory.rituals);
    updatedRituals.removeAt(ritualIndex);
    final updatedCategories = List<HeroRitualCategory>.from(ritualCategories);
    updatedCategories[categoryIndex] = normalizeRitualCategory(
      updatedCategory.copyWith(rituals: updatedRituals),
    );
    onChanged(normalizeRitualCategories(updatedCategories));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Ritualkategorien', style: theme.textTheme.titleSmall),
                const SizedBox(width: 8),
                Text(
                  '(${ritualCategories.length})',
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                FilledButton(
                  key: const ValueKey<String>('magic-rituals-add-category'),
                  onPressed: () => _addCategory(context),
                  child: const Text('+ Ritualkategorie'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (ritualCategories.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Noch keine Ritualkategorien. Lege eine neue Kategorie an.',
                  key: const ValueKey<String>('magic-rituals-empty'),
                  style: theme.textTheme.bodySmall,
                ),
              )
            else
              ...ritualCategories.asMap().entries.map((entry) {
                final categoryIndex = entry.key;
                final category = entry.value;
                final resolvedTalents = resolveDerivedRitualTalents(
                  category: category,
                  catalogTalents: catalogTalents,
                  heroTalents: heroTalents,
                );
                return ExpansionTile(
                  key: ValueKey<String>('magic-ritual-category-$categoryIndex'),
                  initiallyExpanded: true,
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  title: Text(category.name),
                  subtitle: Text(
                    _buildCategorySummary(category, resolvedTalents),
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: isEditing
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              key: ValueKey<String>(
                                'magic-ritual-category-edit-$categoryIndex',
                              ),
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () {
                                _editCategory(context, categoryIndex, category);
                              },
                              tooltip: 'Kategorie bearbeiten',
                            ),
                            IconButton(
                              key: ValueKey<String>(
                                'magic-ritual-category-remove-$categoryIndex',
                              ),
                              icon: const Icon(Icons.delete, size: 18),
                              onPressed: () => _removeCategory(categoryIndex),
                              tooltip: 'Kategorie entfernen',
                            ),
                          ],
                        )
                      : null,
                  children: [
                    _buildKnowledgeSummary(
                      context,
                      category: category,
                      resolvedTalents: resolvedTalents,
                    ),
                    if (category.additionalFieldDefs.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Zusatzfelder', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: category.additionalFieldDefs
                            .map((fieldDef) {
                              return Chip(
                                label: Text(
                                  '${fieldDef.label} (${_ritualFieldTypeLabel(fieldDef.type)})',
                                ),
                              );
                            })
                            .toList(growable: false),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text('Rituale', style: theme.textTheme.titleSmall),
                        const SizedBox(width: 8),
                        Text(
                          '(${category.rituals.length})',
                          style: theme.textTheme.bodySmall,
                        ),
                        const Spacer(),
                        if (isEditing)
                          OutlinedButton.icon(
                            key: ValueKey<String>(
                              'magic-ritual-add-ritual-$categoryIndex',
                            ),
                            onPressed: () {
                              _openRitualDialog(
                                context,
                                categoryIndex,
                                category,
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Ritual'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (category.rituals.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Keine Rituale in dieser Kategorie.',
                          style: theme.textTheme.bodySmall,
                        ),
                      )
                    else
                      ...category.rituals.asMap().entries.map((ritualEntry) {
                        final ritualIndex = ritualEntry.key;
                        final ritual = ritualEntry.value;
                        return ListTile(
                          key: ValueKey<String>(
                            'magic-ritual-tile-$categoryIndex-$ritualIndex',
                          ),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(ritual.name),
                          subtitle: Text(
                            _buildRitualSummary(ritual),
                            style: theme.textTheme.bodySmall,
                          ),
                          onTap: () {
                            _openRitualDialog(
                              context,
                              categoryIndex,
                              category,
                              ritualIndex: ritualIndex,
                            );
                          },
                          trailing: isEditing
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      key: ValueKey<String>(
                                        'magic-ritual-edit-$categoryIndex-$ritualIndex',
                                      ),
                                      icon: const Icon(Icons.edit, size: 18),
                                      onPressed: () {
                                        _openRitualDialog(
                                          context,
                                          categoryIndex,
                                          category,
                                          ritualIndex: ritualIndex,
                                        );
                                      },
                                      tooltip: 'Ritual bearbeiten',
                                    ),
                                    IconButton(
                                      key: ValueKey<String>(
                                        'magic-ritual-remove-$categoryIndex-$ritualIndex',
                                      ),
                                      icon: const Icon(Icons.delete, size: 18),
                                      onPressed: () {
                                        _removeRitual(
                                          categoryIndex,
                                          ritualIndex,
                                        );
                                      },
                                      tooltip: 'Ritual entfernen',
                                    ),
                                  ],
                                )
                              : const Icon(Icons.chevron_right),
                        );
                      }),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }
}

Widget _buildKnowledgeSummary(
  BuildContext context, {
  required HeroRitualCategory category,
  required List<ResolvedRitualTalent> resolvedTalents,
}) {
  final theme = Theme.of(context);
  if (category.knowledgeMode == HeroRitualKnowledgeMode.ownKnowledge) {
    final ownKnowledge =
        category.ownKnowledge ?? buildDefaultRitualKnowledge(category.name);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: const Text('Ritualkenntnis'),
      subtitle: Text(
        'TaW ${ownKnowledge.value}  |  Komplexitaet ${ownKnowledge.learningComplexity}',
        style: theme.textTheme.bodySmall,
      ),
    );
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Abgeleitete Talente', style: theme.textTheme.titleSmall),
      const SizedBox(height: 6),
      if (resolvedTalents.isEmpty)
        Text('Keine Talente verknuepft.', style: theme.textTheme.bodySmall)
      else
        ...resolvedTalents.map((talent) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '${talent.talentName}: TaW ${talent.talentValue}',
              style: theme.textTheme.bodySmall,
            ),
          );
        }),
    ],
  );
}

String _buildCategorySummary(
  HeroRitualCategory category,
  List<ResolvedRitualTalent> resolvedTalents,
) {
  if (category.knowledgeMode == HeroRitualKnowledgeMode.ownKnowledge) {
    final knowledge =
        category.ownKnowledge ?? buildDefaultRitualKnowledge(category.name);
    return 'Ritualkenntnis, TaW ${knowledge.value}, Kompl. ${knowledge.learningComplexity}';
  }
  if (resolvedTalents.isEmpty) {
    return 'Talentbasiert, keine Talente verknuepft';
  }
  return resolvedTalents
      .map((talent) => '${talent.talentName} (${talent.talentValue})')
      .join(', ');
}

String _buildRitualSummary(HeroRitualEntry ritual) {
  final parts = <String>[];
  if (ritual.kosten.isNotEmpty) {
    parts.add('Kosten: ${ritual.kosten}');
  }
  if (ritual.wirkungsdauer.isNotEmpty) {
    parts.add('Dauer: ${ritual.wirkungsdauer}');
  }
  if (ritual.merkmale.isNotEmpty) {
    parts.add('Merkmale: ${ritual.merkmale}');
  }
  if (parts.isEmpty) {
    return 'Keine Details eingetragen';
  }
  return parts.join(' | ');
}

String _ritualFieldTypeLabel(HeroRitualFieldType type) {
  switch (type) {
    case HeroRitualFieldType.text:
      return 'Text';
    case HeroRitualFieldType.threeAttributes:
      return '3 Eigenschaften';
  }
}
