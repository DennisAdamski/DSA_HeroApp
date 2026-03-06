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
            'Waffe als Vorlage hinzufuegen — Werte sind danach frei editierbar.',
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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                    DataColumn(label: Text('Talent')),
                    DataColumn(label: Text('Typ')),
                    DataColumn(label: Text('Kategorie')),
                    DataColumn(label: Text('INI')),
                    DataColumn(label: Text('WM AT')),
                    DataColumn(label: Text('WM PA')),
                    DataColumn(label: Text('DK')),
                  ],
                  rows: filtered.map((weapon) {
                    return DataRow(
                      cells: [
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 20),
                            tooltip: 'Als Vorlage hinzufuegen',
                            onPressed: () => widget.onSelectWeapon(weapon),
                          ),
                        ),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: Text(
                              weapon.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(Text(
                          weapon.combatSkill.isEmpty
                              ? '-'
                              : weapon.combatSkill,
                          style: theme.textTheme.bodySmall,
                        )),
                        DataCell(Text(
                          weapon.type.isEmpty ? '-' : weapon.type,
                          style: theme.textTheme.bodySmall,
                        )),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: Text(
                              weapon.weaponCategory.isEmpty
                                  ? '-'
                                  : weapon.weaponCategory,
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(Text(
                          weapon.iniMod.toString(),
                          style: theme.textTheme.bodySmall,
                        )),
                        DataCell(Text(
                          weapon.atMod.toString(),
                          style: theme.textTheme.bodySmall,
                        )),
                        DataCell(Text(
                          weapon.paMod.toString(),
                          style: theme.textTheme.bodySmall,
                        )),
                        DataCell(Text(
                          weapon.reach.isEmpty ? '-' : weapon.reach,
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
    );
  }
}
