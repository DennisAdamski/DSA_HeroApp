part of '../hero_magic_tab.dart';

/// Durchsuchbare Katalog-Tabelle aller Zauber mit Aktivierungs-Checkboxen.
class _MagicSpellCatalogTable extends StatefulWidget {
  const _MagicSpellCatalogTable({
    required this.allSpells,
    required this.activeSpellIds,
    required this.heroRepresentationen,
    required this.isEditing,
    required this.onToggleSpell,
  });

  final List<SpellDef> allSpells;
  final Set<String> activeSpellIds;
  final List<String> heroRepresentationen;
  final bool isEditing;
  final void Function(String spellId, bool activate) onToggleSpell;

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
      spells = spells.where((spell) {
        return spellAvailabilityForRepresentations(
              spell.availability,
              widget.heroRepresentationen,
            ) !=
            null;
      }).toList(growable: false);
    }

    // Namenssuche.
    if (_searchQuery.isNotEmpty) {
      final needle = _searchQuery.toLowerCase();
      spells = spells
          .where(
              (spell) => spell.name.toLowerCase().contains(needle))
          .toList(growable: false);
    }

    return spells;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEditing) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final filtered = _filteredSpells();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        childrenPadding: EdgeInsets.zero,
        title: Row(
          children: [
            Text('Zauber-Katalog', style: theme.textTheme.titleSmall),
            const SizedBox(width: 8),
            Text('(${filtered.length}/${widget.allSpells.length})',
                style: theme.textTheme.bodySmall),
          ],
        ),
        children: [
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
                          horizontal: 8, vertical: 8),
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
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 12,
                    horizontalMargin: 12,
                    headingRowHeight: 36,
                    dataRowMinHeight: 32,
                    dataRowMaxHeight: 40,
                    columns: const [
                      DataColumn(label: SizedBox(width: 36)),
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Repr.')),
                      DataColumn(label: Text('Verbr.'), numeric: true),
                      DataColumn(label: Text('Merkmale')),
                      DataColumn(label: Text('Stg')),
                    ],
                    rows: filtered.map((spell) {
                      final isActive =
                          widget.activeSpellIds.contains(spell.id);
                      final verbreitung =
                          widget.heroRepresentationen.isNotEmpty
                              ? spellAvailabilityForRepresentations(
                                  spell.availability,
                                  widget.heroRepresentationen,
                                )
                              : null;
                      final traditions = extractTraditions(spell.availability);

                      return DataRow(
                        cells: [
                          DataCell(
                            Checkbox(
                              value: isActive,
                              onChanged: (value) =>
                                  widget.onToggleSpell(
                                      spell.id, value ?? false),
                            ),
                          ),
                          DataCell(
                            ConstrainedBox(
                              constraints:
                                  const BoxConstraints(maxWidth: 200),
                              child: Text(spell.name,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ),
                          DataCell(
                            ConstrainedBox(
                              constraints:
                                  const BoxConstraints(maxWidth: 120),
                              child: Text(
                                traditions.join(', '),
                                style: theme.textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(Text(
                            verbreitung?.toString() ?? '-',
                            style: theme.textTheme.bodySmall,
                          )),
                          DataCell(
                            ConstrainedBox(
                              constraints:
                                  const BoxConstraints(maxWidth: 180),
                              child: Text(
                                spell.traits,
                                style: theme.textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(Text(
                            spell.steigerung,
                            style: theme.textTheme.bodySmall,
                          )),
                        ],
                      );
                    }).toList(growable: false),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
