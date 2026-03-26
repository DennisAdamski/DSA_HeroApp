part of '../hero_combat_tab.dart';

const double _combatTalentCatalogTableColumnSpacing = 12.0;
const double _combatTalentCatalogTableHorizontalMargin = 12.0;
const List<AdaptiveDataColumnSpec> _combatTalentCatalogTableColumns =
    <AdaptiveDataColumnSpec>[
      AdaptiveDataColumnSpec(
        label: SizedBox(width: 36),
        width: AdaptiveTableColumnSpec.fixed(72),
      ),
      AdaptiveDataColumnSpec(
        label: Text('Name'),
        width: AdaptiveTableColumnSpec(minWidth: 140, maxWidth: 220, flex: 2),
      ),
      AdaptiveDataColumnSpec(
        label: Text('Typ'),
        width: AdaptiveTableColumnSpec(minWidth: 90, maxWidth: 160, flex: 1),
      ),
      AdaptiveDataColumnSpec(
        label: Text('Waffengattung'),
        width: AdaptiveTableColumnSpec(minWidth: 180, maxWidth: 300, flex: 2),
      ),
      AdaptiveDataColumnSpec(
        label: Text('Stg'),
        width: AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 80),
      ),
    ];

final double _combatTalentCatalogSheetMinWidth = adaptiveDataTableMinWidth(
  _combatTalentCatalogTableColumns,
  columnSpacing: _combatTalentCatalogTableColumnSpacing,
  horizontalMargin: _combatTalentCatalogTableHorizontalMargin,
);

/// Durchsuchbare Katalog-Tabelle aller Kampftalente mit Aktivierungs-Checkboxen.
/// Wird als Inhalt eines Modal Bottom Sheets verwendet.
class _CombatTalentCatalogTable extends StatefulWidget {
  const _CombatTalentCatalogTable({
    required this.allTalents,
    required this.activeTalentIds,
    required this.onToggleTalent,
  });

  final List<TalentDef> allTalents;
  final Set<String> activeTalentIds;
  final void Function(String talentId, bool activate) onToggleTalent;

  @override
  State<_CombatTalentCatalogTable> createState() =>
      _CombatTalentCatalogTableState();
}

class _CombatTalentCatalogTableState extends State<_CombatTalentCatalogTable> {
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
              Text('Kampftalent-Katalog', style: theme.textTheme.titleMedium),
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
              hintText: 'Kampftalent suchen...',
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
              'Keine Kampftalente gefunden.',
              style: theme.textTheme.bodySmall,
            ),
          )
        else
          Flexible(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final layout = resolveAdaptiveDataTableLayout(
                  _combatTalentCatalogTableColumns,
                  availableWidth: constraints.maxWidth,
                  columnSpacing: _combatTalentCatalogTableColumnSpacing,
                  horizontalMargin: _combatTalentCatalogTableHorizontalMargin,
                );

                return SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: _combatTalentCatalogTableColumnSpacing,
                      horizontalMargin:
                          _combatTalentCatalogTableHorizontalMargin,
                      headingRowHeight: 36,
                      dataRowMinHeight: 32,
                      dataRowMaxHeight: 40,
                      columns: layout.columns,
                      rows: filtered
                          .map((talent) {
                            final isActive = widget.activeTalentIds.contains(
                              talent.id,
                            );
                            return DataRow(
                              cells: [
                                DataCell(
                                  Checkbox(
                                    value: isActive,
                                    onChanged: (value) => widget.onToggleTalent(
                                      talent.id,
                                      value ?? false,
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
                                      talent.type.isEmpty ? '-' : talent.type,
                                      style: theme.textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: layout.contentWidthFor(3),
                                    child: Text(
                                      talent.weaponCategory.isEmpty
                                          ? '-'
                                          : talent.weaponCategory,
                                      style: theme.textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    talent.steigerung,
                                    style: theme.textTheme.bodySmall,
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
