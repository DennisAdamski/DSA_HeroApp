part of '../hero_talents_tab.dart';

/// Durchsuchbare Katalog-Tabelle aller Talente mit Aktivierungs-Checkboxen.
/// Wird als Inhalt eines Modal Bottom Sheets verwendet (analog Zauber-Katalog).
class _TalentCatalogTable extends StatefulWidget {
  const _TalentCatalogTable({
    required this.allTalents,
    required this.activeTalentIds,
    required this.lockedTalentIds,
    required this.onToggleTalent,
  });

  final List<TalentDef> allTalents;
  final Set<String> activeTalentIds;
  final Set<String> lockedTalentIds;
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
              'Keine Talente gefunden.',
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
                    DataColumn(label: Text('Gruppe')),
                    DataColumn(label: Text('Eigenschaften')),
                    DataColumn(label: Text('Stg')),
                    DataColumn(label: Text('BE')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: filtered.map((talent) {
                    final isActive =
                        widget.activeTalentIds.contains(talent.id);
                    final isLocked =
                        isActive && widget.lockedTalentIds.contains(talent.id);
                    return DataRow(
                      cells: [
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: isActive,
                                onChanged: isLocked
                                    ? null
                                    : (value) => widget.onToggleTalent(
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
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: Text(talent.name,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Text(
                              talent.group,
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: Text(
                              talent.attributes.join(', '),
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(Text(
                          talent.steigerung,
                          style: theme.textTheme.bodySmall,
                        )),
                        DataCell(Text(
                          talent.be.isEmpty ? '-' : talent.be,
                          style: theme.textTheme.bodySmall,
                        )),
                        DataCell(
                          Text(
                            isLocked ? 'Meta-Referenz' : '-',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
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
