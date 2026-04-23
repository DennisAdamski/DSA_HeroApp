part of '../hero_talents_tab.dart';

const double _talentCatalogTableColumnSpacing = 12.0;
const double _talentCatalogTableHorizontalMargin = 12.0;
const List<AdaptiveDataColumnSpec> _talentCatalogTableColumns =
    <AdaptiveDataColumnSpec>[
      AdaptiveDataColumnSpec(
        label: SizedBox(width: 36),
        width: AdaptiveTableColumnSpec.fixed(84),
      ),
      AdaptiveDataColumnSpec(
        label: Text('Name'),
        width: AdaptiveTableColumnSpec(minWidth: 140, maxWidth: 220, flex: 2),
      ),
      AdaptiveDataColumnSpec(
        label: Text('Gruppe'),
        width: AdaptiveTableColumnSpec(minWidth: 130, maxWidth: 200, flex: 1),
      ),
      AdaptiveDataColumnSpec(
        label: Text('Eigenschaften'),
        width: AdaptiveTableColumnSpec(minWidth: 180, maxWidth: 260, flex: 2),
      ),
      AdaptiveDataColumnSpec(
        label: Text('Stg'),
        width: AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 80),
      ),
      AdaptiveDataColumnSpec(
        label: Text('BE'),
        width: AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 80),
      ),
      AdaptiveDataColumnSpec(
        label: Text('Status'),
        width: AdaptiveTableColumnSpec(minWidth: 120, maxWidth: 160),
      ),
    ];

final double _talentCatalogSheetMinWidth = adaptiveDataTableMinWidth(
  _talentCatalogTableColumns,
  columnSpacing: _talentCatalogTableColumnSpacing,
  horizontalMargin: _talentCatalogTableHorizontalMargin,
);

/// Durchsuchbare Katalog-Tabelle aller Talente mit Aktivierungs-Checkboxen.
/// Wird als Inhalt eines Modal Bottom Sheets verwendet (analog Zauber-Katalog).
class _TalentCatalogTable extends StatefulWidget {
  const _TalentCatalogTable({
    required this.allTalents,
    required this.activeTalentIds,
    required this.lockedTalentIds,
    required this.ruleResolver,
    required this.onToggleTalent,
  });

  final List<TalentDef> allTalents;
  final Set<String> activeTalentIds;
  final Set<String> lockedTalentIds;
  final CatalogRuleResolver ruleResolver;
  final void Function(String talentId, bool activate) onToggleTalent;

  @override
  State<_TalentCatalogTable> createState() => _TalentCatalogTableState();
}

class _TalentCatalogTableState extends State<_TalentCatalogTable> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TalentDef> _filteredTalents() {
    var talents = widget.allTalents;
    if (_searchQuery.isNotEmpty) {
      final needle = _searchQuery.toLowerCase();
      talents = talents
          .where((t) => t.name.toLowerCase().contains(needle))
          .toList(growable: false);
    }
    return talents;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filteredTalents();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text('Talent-Katalog', style: theme.textTheme.titleMedium),
              const SizedBox(width: 8),
              Text(
                '(${filtered.length}/${widget.allTalents.length})',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Talent suchen...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.trim();
              });
            },
          ),
        ),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Keine Talente gefunden.',
              style: theme.textTheme.bodySmall,
            ),
          )
        else
          Flexible(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final layout = resolveAdaptiveDataTableLayout(
                  _talentCatalogTableColumns,
                  availableWidth: constraints.maxWidth,
                  columnSpacing: _talentCatalogTableColumnSpacing,
                  horizontalMargin: _talentCatalogTableHorizontalMargin,
                );

                return SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: _talentCatalogTableColumnSpacing,
                      horizontalMargin: _talentCatalogTableHorizontalMargin,
                      headingRowHeight: 36,
                      dataRowMinHeight: 32,
                      dataRowMaxHeight: 40,
                      columns: layout.columns,
                      rows: filtered
                          .map((talent) {
                            final isActive = widget.activeTalentIds.contains(
                              talent.id,
                            );
                            final isLocked =
                                isActive &&
                                widget.lockedTalentIds.contains(talent.id);
                            final complexityResolution = widget.ruleResolver
                                .resolveTalentComplexity(
                                  talent: talent,
                                  gifted: false,
                                );
                            return DataRow(
                              cells: [
                                DataCell(
                                  SizedBox(
                                    width: layout.contentWidthFor(0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Checkbox(
                                          value: isActive,
                                          onChanged: isLocked
                                              ? null
                                              : (value) =>
                                                    widget.onToggleTalent(
                                                      talent.id,
                                                      value ?? false,
                                                    ),
                                        ),
                                        if (isLocked)
                                          const Tooltip(
                                            message:
                                                'Wird von einem Meta-Talent verwendet',
                                            child: Icon(Icons.lock, size: 16),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: layout.contentWidthFor(1),
                                    child: Text(
                                      talent.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: layout.contentWidthFor(2),
                                    child: Text(
                                      talent.group,
                                      style: theme.textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: layout.contentWidthFor(3),
                                    child: Text(
                                      talent.attributes.join(', '),
                                      style: theme.textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        complexityResolution
                                            .effectiveKomplexitaet,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      if (complexityResolution.houseRuleHint !=
                                          null) ...[
                                        const SizedBox(width: 4),
                                        Tooltip(
                                          message: complexityResolution
                                              .houseRuleHint!,
                                          child: Icon(
                                            Icons.rule_outlined,
                                            size: 14,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    talent.be.isEmpty ? '-' : talent.be,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: layout.contentWidthFor(6),
                                    child: Text(
                                      isLocked ? 'Meta-Referenz' : '-',
                                      style: theme.textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          })
                          .toList(growable: false),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
