part of '../hero_magic_tab.dart';

const double _magicSpellCatalogTableColumnSpacing = 12.0;
const double _magicSpellCatalogTableHorizontalMargin = 12.0;
const List<AdaptiveDataColumnSpec> _magicSpellCatalogTableColumns =
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
        label: Text('Verbreitungen'),
        width: AdaptiveTableColumnSpec(minWidth: 190, maxWidth: 340, flex: 2),
      ),
      AdaptiveDataColumnSpec(
        label: Text('Merkmale'),
        width: AdaptiveTableColumnSpec(minWidth: 110, maxWidth: 220, flex: 1),
      ),
      AdaptiveDataColumnSpec(
        label: Text('Stg'),
        width: AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 84),
      ),
    ];

final double _magicSpellCatalogSheetMinWidth = adaptiveDataTableMinWidth(
  _magicSpellCatalogTableColumns,
  columnSpacing: _magicSpellCatalogTableColumnSpacing,
  horizontalMargin: _magicSpellCatalogTableHorizontalMargin,
);

/// Durchsuchbare Katalog-Tabelle aller Zauber mit Aktivierungs-Checkboxen.
/// Wird als Inhalt eines Modal Bottom Sheets verwendet.
class _MagicSpellCatalogTable extends StatefulWidget {
  const _MagicSpellCatalogTable({
    required this.allSpells,
    required this.activeSpellIds,
    required this.heroRepresentationen,
    required this.onActivateSpell,
    required this.onDeactivateSpell,
  });

  final List<SpellDef> allSpells;
  final Set<String> activeSpellIds;
  final List<String> heroRepresentationen;
  final Future<bool> Function(SpellDef spell) onActivateSpell;
  final void Function(String spellId) onDeactivateSpell;

  @override
  State<_MagicSpellCatalogTable> createState() =>
      _MagicSpellCatalogTableState();
}

class _MagicSpellCatalogTableState extends State<_MagicSpellCatalogTable> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showAll = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SpellDef> _filteredSpells() {
    var spells = widget.allSpells;

    // Filter nach Repraesentation wenn nicht "alle" angezeigt werden.
    if (!_showAll && widget.heroRepresentationen.isNotEmpty) {
      spells = spells
          .where((spell) {
            return availableSpellEntriesForRepresentations(
              spell.availability,
              widget.heroRepresentationen,
            ).isNotEmpty;
          })
          .toList(growable: false);
    }

    // Namenssuche.
    if (_searchQuery.isNotEmpty) {
      final needle = _searchQuery.toLowerCase();
      spells = spells
          .where((spell) => spell.name.toLowerCase().contains(needle))
          .toList(growable: false);
    }

    return spells;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filteredSpells();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text('Zauber-Katalog', style: theme.textTheme.titleMedium),
              const SizedBox(width: 8),
              Text(
                '(${filtered.length}/${widget.allSpells.length})',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Zauber suchen...',
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
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Alle'),
                selected: _showAll,
                onSelected: (value) {
                  setState(() {
                    _showAll = value;
                  });
                },
              ),
            ],
          ),
        ),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Keine Zauber gefunden.',
              style: theme.textTheme.bodySmall,
            ),
          )
        else
          Flexible(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final layout = resolveAdaptiveDataTableLayout(
                  _magicSpellCatalogTableColumns,
                  availableWidth: constraints.maxWidth,
                  columnSpacing: _magicSpellCatalogTableColumnSpacing,
                  horizontalMargin: _magicSpellCatalogTableHorizontalMargin,
                );

                return SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: _magicSpellCatalogTableColumnSpacing,
                      horizontalMargin: _magicSpellCatalogTableHorizontalMargin,
                      headingRowHeight: 36,
                      dataRowMinHeight: 32,
                      dataRowMaxHeight: 40,
                      columns: layout.columns,
                      rows: filtered
                          .map((spell) {
                            final isActive = widget.activeSpellIds.contains(
                              spell.id,
                            );
                            final heroEntries =
                                availableSpellEntriesForRepresentations(
                                  spell.availability,
                                  widget.heroRepresentationen,
                                );
                            final canActivate = heroEntries.isNotEmpty;
                            final availabilityLabel = formatAvailabilityEntries(
                              spell.availability,
                            );

                            return DataRow(
                              cells: [
                                DataCell(
                                  Checkbox(
                                    key: ValueKey<String>(
                                      'magic-spell-catalog-toggle-${spell.id}',
                                    ),
                                    value: isActive,
                                    onChanged: isActive
                                        ? (_) =>
                                              widget.onDeactivateSpell(spell.id)
                                        : canActivate
                                        ? (_) async {
                                            await widget.onActivateSpell(spell);
                                          }
                                        : null,
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: layout.contentWidthFor(1),
                                    child: Text(
                                      spell.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: layout.contentWidthFor(2),
                                    child: Text(
                                      availabilityLabel,
                                      style: theme.textTheme.bodySmall,
                                      softWrap: true,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: layout.contentWidthFor(3),
                                    child: Text(
                                      spell.traits,
                                      style: theme.textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    spell.steigerung,
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
