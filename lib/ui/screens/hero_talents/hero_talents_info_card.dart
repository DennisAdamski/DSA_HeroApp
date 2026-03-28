part of 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';

extension _HeroTalentsInfoCard on _HeroTalentTableTabState {
  Widget _buildTopActionBar({
    required String heroId,
    required int combatBaseBe,
    required int activeTalentBe,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FilledButton.icon(
              key: const ValueKey<String>('talents-local-start-edit'),
              onPressed: _editController.isEditing
                  ? null
                  : () {
                      _startEdit();
                    },
              icon: const Icon(Icons.edit),
              label: const Text('Bearbeiten'),
            ),
            const SizedBox(width: 4),
            IconButton(
              key: const ValueKey<String>('talents-be-screen-open'),
              onPressed: () => _openTalentBeScreen(
                heroId: heroId,
                combatBaseBe: combatBaseBe,
              ),
              icon: const Icon(Icons.settings),
              tooltip: 'BE konfigurieren ($activeTalentBe)',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCombatActionBar({required List<TalentDef> allTalents}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: _editController.isEditing
            ? FilledButton.icon(
                key: const ValueKey<String>('combat-talents-catalog-open'),
                onPressed: () => _showTalentKatalog(context, allTalents),
                icon: const Icon(Icons.library_add),
                label: const Text('Kampftalente verwalten'),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Future<void> _openTalentBeScreen({
    required String heroId,
    required int combatBaseBe,
  }) async {
    await showAdaptiveDetailSheet<void>(
      context: context,
      builder: (context) =>
          TalentBeConfigDialog(heroId: heroId, combatBaseBe: combatBaseBe),
    );
  }

  Widget _buildSpecialAbilitiesTab() {
    final isEditing = _editController.isEditing;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        margin: EdgeInsets.zero,
        child: ExpansionTile(
          key: const ValueKey<String>('talents-special-abilities-global'),
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  'Sonderfertigkeiten',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${_draftTalentSpecialAbilities.length})',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 12),
              FilledButton(
                key: const ValueKey<String>('talents-special-abilities-add'),
                onPressed: () async {
                  await _ensureEditingSession();
                  if (!mounted) {
                    return;
                  }
                  _addTalentSpecialAbility();
                },
                child: const Text('+ Sonderfertigkeit'),
              ),
            ],
          ),
          children: [
            if (_draftTalentSpecialAbilities.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Keine Sonderfertigkeiten eingetragen.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ..._draftTalentSpecialAbilities.asMap().entries.map((entry) {
              final index = entry.key;
              final ability = entry.value;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(ability.name),
                subtitle: ability.note.trim().isEmpty
                    ? null
                    : Text(ability.note),
                trailing: isEditing
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: ValueKey<String>(
                              'talents-special-abilities-edit-$index',
                            ),
                            icon: const Icon(Icons.edit, size: 18),
                            tooltip: 'Bearbeiten',
                            onPressed: () => _editTalentSpecialAbility(
                              index,
                              existing: ability,
                            ),
                          ),
                          IconButton(
                            key: ValueKey<String>(
                              'talents-special-abilities-delete-$index',
                            ),
                            icon: const Icon(Icons.delete, size: 18),
                            tooltip: 'Entfernen',
                            onPressed: () => _removeTalentSpecialAbility(index),
                          ),
                        ],
                      )
                    : null,
              );
            }),
          ],
        ),
      ),
    );
  }

  void _addTalentSpecialAbility() {
    _showTalentSpecialAbilityDialog(
      onSave: (ability) {
        _draftTalentSpecialAbilities = [
          ..._draftTalentSpecialAbilities,
          ability,
        ];
        _markFieldChanged();
      },
    );
  }

  void _editTalentSpecialAbility(
    int index, {
    required TalentSpecialAbility existing,
  }) {
    _showTalentSpecialAbilityDialog(
      existing: existing,
      onSave: (ability) {
        final updated = List<TalentSpecialAbility>.from(
          _draftTalentSpecialAbilities,
        );
        updated[index] = ability;
        _draftTalentSpecialAbilities = updated;
        _markFieldChanged();
      },
    );
  }

  void _removeTalentSpecialAbility(int index) {
    final updated = List<TalentSpecialAbility>.from(
      _draftTalentSpecialAbilities,
    );
    updated.removeAt(index);
    _draftTalentSpecialAbilities = updated;
    _markFieldChanged();
  }

  void _showTalentSpecialAbilityDialog({
    TalentSpecialAbility? existing,
    required void Function(TalentSpecialAbility ability) onSave,
  }) {
    var draftName = existing?.name ?? '';
    var draftNote = existing?.note ?? '';

    showAdaptiveDetailSheet<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                existing == null
                    ? 'Sonderfertigkeit hinzufügen'
                    : 'Sonderfertigkeit bearbeiten',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      key: const ValueKey<String>(
                        'talents-special-ability-name',
                      ),
                      initialValue: draftName,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'z. B. Regeneration I',
                      ),
                      autofocus: true,
                      onChanged: (value) {
                        setDialogState(() {
                          draftName = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: const ValueKey<String>(
                        'talents-special-ability-note',
                      ),
                      initialValue: draftNote,
                      decoration: const InputDecoration(
                        labelText: 'Notiz (optional)',
                      ),
                      maxLines: 2,
                      onChanged: (value) {
                        setDialogState(() {
                          draftNote = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  key: const ValueKey<String>('talents-special-ability-save'),
                  onPressed: () {
                    final name = draftName.trim();
                    if (name.isEmpty) {
                      return;
                    }
                    onSave(
                      TalentSpecialAbility(name: name, note: draftNote.trim()),
                    );
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Speichern'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSearchHeader({
    required List<TalentDef> allTalents,
    required List<TalentDef> allCatalogTalents,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey<String>('talents-group-search'),
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Talente suchen\u2026',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _talentGroupFilter.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Suche löschen',
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            key: const ValueKey<String>('talents-catalog-open'),
            onPressed: () => _openTalentCatalogAction(allTalents),
            icon: const Icon(Icons.library_add),
            label: const Text('+ Talent'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            key: const ValueKey<String>('meta-talents-manage-open'),
            onPressed: () => _openMetaTalentManagerAction(allCatalogTalents),
            icon: const Icon(Icons.merge_type),
            label: const Text('+ Meta-Talent'),
          ),
        ],
      ),
    );
  }
}

class TalentBeConfigDialog extends ConsumerStatefulWidget {
  const TalentBeConfigDialog({
    super.key,
    required this.heroId,
    required this.combatBaseBe,
  });

  final String heroId;
  final int combatBaseBe;

  @override
  ConsumerState<TalentBeConfigDialog> createState() =>
      _TalentBeConfigDialogState();
}

class _TalentBeConfigDialogState extends ConsumerState<TalentBeConfigDialog> {
  late final TextEditingController _overrideController;

  @override
  void initState() {
    super.initState();
    final value = ref.read(talentBeOverrideProvider(widget.heroId));
    _overrideController = TextEditingController(
      text: value == null ? '' : value.toString(),
    );
  }

  @override
  void dispose() {
    _overrideController.dispose();
    super.dispose();
  }

  void _updateOverride(String raw) {
    final trimmed = raw.trim();
    final nextValue = trimmed.isEmpty ? null : int.tryParse(trimmed);
    ref.read(talentBeOverrideProvider(widget.heroId).notifier).state =
        nextValue;
    setState(() {});
  }

  void _clearOverride() {
    _overrideController.clear();
    ref.read(talentBeOverrideProvider(widget.heroId).notifier).state = null;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final overrideValue = ref.watch(talentBeOverrideProvider(widget.heroId));
    final activeTalentBe = overrideValue ?? widget.combatBaseBe;
    return AlertDialog(
      title: const Text('Talent-BE'),
      content: SizedBox(
        width: kDialogWidthMedium,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BE (Kampf): ${widget.combatBaseBe}',
              key: const ValueKey<String>('talents-be-combat-default'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey<String>('talents-be-override-field'),
              controller: _overrideController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'-?[0-9]*')),
              ],
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'BE Override',
              ),
              onChanged: _updateOverride,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey<String>('talents-be-override-clear'),
                  onPressed: _clearOverride,
                  icon: const Icon(Icons.clear),
                  label: const Text('Override löschen'),
                ),
                Text(
                  'Aktive BE: $activeTalentBe',
                  key: const ValueKey<String>('talents-be-active-value'),
                ),
              ],
            ),
          ],
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
}
