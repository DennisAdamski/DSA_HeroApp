part of 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';

/// Durchsuchbare Katalog-Tabelle aller Waffen.
/// Wird als Inhalt eines Modal Bottom Sheets verwendet.
/// Waffen werden als Vorlage hinzugefuegt — gleiche Waffe kann mehrfach gewaehlt werden.
class _WeaponCatalogTable extends StatefulWidget {
  const _WeaponCatalogTable({
    required this.weapons,
    required this.meleeTalents,
    required this.onSelectWeapon,
  });

  final List<WeaponDef> weapons;
  final List<TalentDef> meleeTalents;
  final void Function(WeaponDef weapon) onSelectWeapon;

  @override
  State<_WeaponCatalogTable> createState() => _WeaponCatalogTableState();
}

class _WeaponCatalogTableState extends State<_WeaponCatalogTable> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<WeaponDef> _filteredWeapons() {
    var weapons = widget.weapons;
    if (_searchQuery.isNotEmpty) {
      final needle = _searchQuery.toLowerCase();
      weapons = weapons
          .where(
            (w) =>
                w.name.toLowerCase().contains(needle) ||
                w.combatSkill.toLowerCase().contains(needle) ||
                w.weaponCategory.toLowerCase().contains(needle),
          )
          .toList(growable: false);
    }
    return weapons;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filteredWeapons();
    final columns = <AdaptiveDataColumnSpec>[
      const AdaptiveDataColumnSpec(
        label: SizedBox(width: 36),
        width: AdaptiveTableColumnSpec.fixed(80),
      ),
      const AdaptiveDataColumnSpec(
        label: Text('Name'),
        width: AdaptiveTableColumnSpec(minWidth: 140, maxWidth: 220, flex: 2),
      ),
      const AdaptiveDataColumnSpec(
        label: Text('Talent'),
        width: AdaptiveTableColumnSpec(minWidth: 120, maxWidth: 180, flex: 1),
      ),
      const AdaptiveDataColumnSpec(
        label: Text('Typ'),
        width: AdaptiveTableColumnSpec(minWidth: 90, maxWidth: 140),
      ),
      const AdaptiveDataColumnSpec(
        label: Text('Kategorie'),
        width: AdaptiveTableColumnSpec(minWidth: 120, maxWidth: 240, flex: 2),
      ),
      const AdaptiveDataColumnSpec(
        label: Text('INI'),
        width: AdaptiveTableColumnSpec(minWidth: 64, maxWidth: 92),
        numeric: true,
      ),
      const AdaptiveDataColumnSpec(
        label: Text('WM AT'),
        width: AdaptiveTableColumnSpec(minWidth: 72, maxWidth: 96),
        numeric: true,
      ),
      const AdaptiveDataColumnSpec(
        label: Text('WM PA'),
        width: AdaptiveTableColumnSpec(minWidth: 72, maxWidth: 96),
        numeric: true,
      ),
      const AdaptiveDataColumnSpec(
        label: Text('DK'),
        width: AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 96),
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text('Waffen-Katalog', style: theme.textTheme.titleMedium),
              const SizedBox(width: 8),
              Text(
                '(${filtered.length}/${widget.weapons.length})',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            'Waffe aus Vorlage hinzufügen — Werte sind danach frei editierbar.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Waffe suchen...',
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
              'Keine Waffen gefunden.',
              style: theme.textTheme.bodySmall,
            ),
          )
        else
          Flexible(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const columnSpacing = 12.0;
                const horizontalMargin = 12.0;
                final layout = resolveAdaptiveDataTableLayout(
                  columns,
                  availableWidth: constraints.maxWidth,
                  columnSpacing: columnSpacing,
                  horizontalMargin: horizontalMargin,
                );

                return SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: columnSpacing,
                      horizontalMargin: horizontalMargin,
                      headingRowHeight: 36,
                      dataRowMinHeight: 32,
                      dataRowMaxHeight: 40,
                      columns: layout.columns,
                      rows: filtered
                          .map((weapon) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  IconButton(
                                    icon: const Icon(
                                      Icons.add_circle_outline,
                                      size: 20,
                                    ),
                                    tooltip: 'Als Vorlage hinzufügen',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints.tightFor(
                                      width: 24,
                                      height: 24,
                                    ),
                                    onPressed: () =>
                                        widget.onSelectWeapon(weapon),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: layout.contentWidthFor(1),
                                    child: Text(
                                      weapon.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: layout.contentWidthFor(2),
                                    child: Text(
                                      weapon.combatSkill.isEmpty
                                          ? '-'
                                          : weapon.combatSkill,
                                      style: theme.textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: layout.contentWidthFor(3),
                                    child: Text(
                                      weapon.type.isEmpty ? '-' : weapon.type,
                                      style: theme.textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: layout.contentWidthFor(4),
                                    child: Text(
                                      weapon.weaponCategory.isEmpty
                                          ? '-'
                                          : weapon.weaponCategory,
                                      style: theme.textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    weapon.iniMod.toString(),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    weapon.atMod.toString(),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    weapon.paMod.toString(),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    weapon.reach.isEmpty ? '-' : weapon.reach,
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
