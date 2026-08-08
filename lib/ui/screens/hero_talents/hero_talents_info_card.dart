part of 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';

extension _HeroTalentsInfoCard on _HeroTalentTableTabState {
  Widget _buildTopActionBar({
    required String heroId,
    required int combatBaseBe,
    required int activeTalentBe,
  }) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final VoidCallback? startEdit = _editController.isEditing
        ? null
        : _startEdit;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (compact)
              IconButton(
                key: const ValueKey<String>('talents-local-start-edit'),
                onPressed: startEdit,
                icon: const Icon(Icons.edit),
                tooltip: 'Bearbeiten',
              )
            else
              FilledButton.icon(
                key: const ValueKey<String>('talents-local-start-edit'),
                onPressed: startEdit,
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
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                key: const ValueKey<String>(
                  'talents-special-abilities-catalog',
                ),
                tooltip: 'Aus Katalog wählen',
                onSelected: (value) async {
                  await _ensureEditingSession();
                  if (!mounted) {
                    return;
                  }
                  _openTalentSpecialAbilityCatalog(karmal: value == 'karmal');
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'allgemein', child: Text('Allgemein')),
                  PopupMenuItem(value: 'karmal', child: Text('Karmal')),
                ],
                child: IgnorePointer(
                  child: OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.library_add),
                    label: const Text('Aus Katalog'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
      onSave: (ability, apKosten) {
        _draftTalentSpecialAbilities = [
          ..._draftTalentSpecialAbilities,
          ability,
        ];
        if (apKosten > 0) {
          _draftApSpentDelta += apKosten;
        }
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
      onSave: (ability, _) {
        final updated = List<TalentSpecialAbility>.from(
          _draftTalentSpecialAbilities,
        );
        updated[index] = ability;
        _draftTalentSpecialAbilities = updated;
        _markFieldChanged();
      },
    );
  }

  /// Oeffnet den Katalog-Browser fuer allgemeine oder karmale
  /// Sonderfertigkeiten (beide landen in derselben `talentSpecialAbilities`-
  /// Liste, vgl. Dokumentation bei [_showTalentSpecialAbilityDialog]).
  void _openTalentSpecialAbilityCatalog({required bool karmal}) {
    final hero = _latestHero;
    final catalog = ref.read(rulesCatalogProvider).valueOrNull;
    if (hero == null || catalog == null) {
      return;
    }
    final abilities =
        karmal ? catalog.karmalSpecialAbilities : catalog.generalSpecialAbilities;
    final owned = _draftTalentSpecialAbilities
        .map((a) => a.name.trim().toLowerCase())
        .toSet();
    showSpecialAbilityPicker(
      context: context,
      title: karmal
          ? 'Karmale Sonderfertigkeiten'
          : 'Allgemeine Sonderfertigkeiten',
      catalog: abilities,
      ownedNamesLower: owned,
      verfuegbareAp: hero.apAvailable,
      episch: hero.isEpisch,
      onAdd: (ability, apKosten) {
        _draftTalentSpecialAbilities = [
          ..._draftTalentSpecialAbilities,
          TalentSpecialAbility(name: ability.name),
        ];
        if (apKosten > 0) {
          _draftApSpentDelta += apKosten;
        }
        _markFieldChanged();
      },
      onRemove: (ability) {
        final normalized = ability.name.trim().toLowerCase();
        _draftTalentSpecialAbilities = _draftTalentSpecialAbilities
            .where((a) => a.name.trim().toLowerCase() != normalized)
            .toList();
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

  /// Zeigt den Sonderfertigkeiten-Dialog. Beim Neuanlegen wird der Name
  /// gegen die allgemeinen und karmalen Katalog-Sonderfertigkeiten
  /// abgeglichen und ein Erwerbs-Dialog mit den bekannten AP-Kosten
  /// angeboten (vgl. magische Sonderfertigkeiten im Magie-Tab).
  void _showTalentSpecialAbilityDialog({
    TalentSpecialAbility? existing,
    required void Function(TalentSpecialAbility ability, int apKosten) onSave,
  }) {
    var draftName = existing?.name ?? '';
    var draftNote = existing?.note ?? '';
    final isNew = existing == null;

    showAdaptiveDetailSheet<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                isNew
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
                  onPressed: () async {
                    final name = draftName.trim();
                    if (name.isEmpty) {
                      return;
                    }
                    var apKosten = 0;
                    if (isNew) {
                      final hero = _latestHero;
                      final catalog = ref
                          .read(rulesCatalogProvider)
                          .valueOrNull;
                      final combinedCatalog = <SpecialAbilityDef>[
                        ...?catalog?.generalSpecialAbilities,
                        ...?catalog?.karmalSpecialAbilities,
                      ];
                      final match = matchCatalogSpecialAbility(
                        combinedCatalog,
                        name,
                      );
                      final erwerb = await showErwerbDialog(
                        context: dialogContext,
                        bezeichnung: name,
                        kostenHinweis: match?.kosten,
                        vorgeschlageneApKosten: match == null
                            ? null
                            : parseLeadingApAmount(match.kosten),
                        verfuegbareAp: hero?.apAvailable ?? 0,
                        episch: hero?.isEpisch ?? false,
                        epischerInhalt: match?.nurEpisch ?? false,
                      );
                      if (erwerb == null) {
                        return;
                      }
                      apKosten = erwerb.apKosten;
                    }
                    onSave(
                      TalentSpecialAbility(
                        name: name,
                        note: draftNote.trim(),
                      ),
                      apKosten,
                    );
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
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

  Widget _buildGroupJumpBar(List<String> groups) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(
        children: groups.map((group) {
          final iconData = talentGroupIcons[group] ?? Icons.folder;
          void onPressed() {
            final key = _groupKeys[group];
            if (key?.currentContext != null) {
              Scrollable.ensureVisible(
                key!.currentContext!,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
                alignment: 0.0,
              );
            }
          }

          final chip = compact
              ? ActionChip(
                  label: Icon(iconData, size: 18),
                  tooltip: group,
                  onPressed: onPressed,
                )
              : ActionChip(
                  avatar: Icon(iconData, size: 18),
                  label: Text(group),
                  tooltip: group,
                  onPressed: onPressed,
                );
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: chip,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchHeader({
    required List<TalentDef> allTalents,
    required List<TalentDef> allCatalogTalents,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: LayoutBuilder(
        builder: (context, constraints) => Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              width: constraints.maxWidth < 560
                  ? constraints.maxWidth
                  : constraints.maxWidth - 336,
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
            FilledButton.icon(
              key: const ValueKey<String>('talents-catalog-open'),
              onPressed: () => _openTalentCatalogAction(allTalents),
              icon: const Icon(Icons.library_add),
              label: const Text('+ Talent'),
            ),
            FilledButton.icon(
              key: const ValueKey<String>('meta-talents-manage-open'),
              onPressed: () => _openMetaTalentManagerAction(allCatalogTalents),
              icon: const Icon(Icons.merge_type),
              label: const Text('+ Meta-Talent'),
            ),
            _buildTabellenAnsichtToggle(),
          ],
        ),
      ),
    );
  }

  /// Umschalter zwischen Breiten-Automatik, erzwungener Tabelle und Karten.
  ///
  /// Auf Tablet-Breiten weicht die Talent-Tabelle sonst zwingend auf Karten
  /// aus; wer die volle Tabelle braucht, kann sie hier horizontal scrollbar
  /// erzwingen. Die Auswahl gilt app-weit und wird persistiert.
  Widget _buildTabellenAnsichtToggle() {
    return SegmentedButton<TabellenAnsicht>(
      key: const ValueKey<String>('talents-view-mode-toggle'),
      showSelectedIcon: false,
      segments: const <ButtonSegment<TabellenAnsicht>>[
        ButtonSegment<TabellenAnsicht>(
          value: TabellenAnsicht.automatisch,
          icon: Icon(Icons.auto_mode),
          tooltip: 'Automatisch',
        ),
        ButtonSegment<TabellenAnsicht>(
          value: TabellenAnsicht.tabelle,
          icon: Icon(Icons.table_rows),
          tooltip: 'Immer Tabelle',
        ),
        ButtonSegment<TabellenAnsicht>(
          value: TabellenAnsicht.karten,
          icon: Icon(Icons.view_agenda_outlined),
          tooltip: 'Immer Karten',
        ),
      ],
      selected: <TabellenAnsicht>{_tabellenAnsicht},
      onSelectionChanged: (selection) {
        if (selection.isEmpty) return;
        ref.read(settingsActionsProvider).setTabellenAnsicht(selection.first);
      },
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

const Map<String, IconData> talentGroupIcons = {
  'Gabe': Icons.auto_awesome,
  'Körperliche Talente': Icons.directions_run,
  'Gesellschaftliche Talente': Icons.groups,
  'Natur Talente': Icons.park,
  'Wissenstalente': Icons.menu_book,
  'Handwerkliche Talente': Icons.handyman,
};
