part of 'package:dsa_heldenverwaltung/ui/screens/hero_overview_tab.dart';

extension _HeroOverviewTraitsSection on _HeroOverviewTabState {
  Widget _buildTraitSelectionSection() {
    final catalogAsync = ref.watch(rulesCatalogProvider);
    final catalog = catalogAsync.valueOrNull;
    final advantages = catalog?.advantages ?? const <HeroTraitDef>[];
    final disadvantages = catalog?.disadvantages ?? const <HeroTraitDef>[];

    return _ResponsiveFieldGrid(
      breakpoint: _standardTwoColumnBreakpoint,
      children: [
        _buildTraitPanel(
          title: 'Vorteile',
          singularLabel: 'Vorteil',
          keyName: 'vorteile',
          traits: advantages,
          isCatalogLoading: catalogAsync.isLoading,
        ),
        _buildTraitPanel(
          title: 'Nachteile',
          singularLabel: 'Nachteil',
          keyName: 'nachteile',
          traits: disadvantages,
          isCatalogLoading: catalogAsync.isLoading,
        ),
      ],
    );
  }

  Widget _buildTraitPanel({
    required String title,
    required String singularLabel,
    required String keyName,
    required List<HeroTraitDef> traits,
    required bool isCatalogLoading,
  }) {
    final fragments = splitHeroTraitText(_field(keyName).text);
    final isEditing = _editController.isEditing;
    final sortedTraits = traits.where((entry) => entry.active).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Column(
      key: ValueKey<String>('overview-traits-$keyName'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleSmall),
            ),
            if (isEditing)
              TextButton(
                key: ValueKey<String>('overview-add-trait-$keyName'),
                onPressed: isCatalogLoading
                    ? null
                    : () => _addTraitFragment(
                        keyName: keyName,
                        singularLabel: singularLabel,
                        traits: sortedTraits,
                      ),
                child: Text('+ $singularLabel'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (fragments.isEmpty)
          Text('Keine Einträge', style: Theme.of(context).textTheme.bodyMedium)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var index = 0; index < fragments.length; index++)
                _buildTraitChip(
                  keyName: keyName,
                  fragments: fragments,
                  fragmentIndex: index,
                  traits: sortedTraits,
                  isEditing: isEditing,
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildTraitChip({
    required String keyName,
    required List<String> fragments,
    required int fragmentIndex,
    required List<HeroTraitDef> traits,
    required bool isEditing,
  }) {
    final fragment = fragments[fragmentIndex];
    final isKnown = isKnownHeroTraitFragment(fragment, traits);
    final label = Text(fragment);
    if (!isEditing) {
      return Chip(label: label, visualDensity: VisualDensity.compact);
    }
    return InputChip(
      key: ValueKey<String>('overview-trait-chip-$keyName-$fragmentIndex'),
      label: label,
      avatar: isKnown ? const Icon(Icons.check, size: 16) : null,
      visualDensity: VisualDensity.compact,
      onPressed: () => _editTraitFragment(
        keyName: keyName,
        fragments: fragments,
        fragmentIndex: fragmentIndex,
      ),
      onDeleted: () => _removeTraitFragment(
        keyName: keyName,
        fragments: fragments,
        fragmentIndex: fragmentIndex,
      ),
    );
  }

  Future<void> _addTraitFragment({
    required String keyName,
    required String singularLabel,
    required List<HeroTraitDef> traits,
  }) async {
    final pick = await _showTraitCatalogDialog(
      singularLabel: singularLabel,
      traits: traits,
    );
    if (pick == null) {
      return;
    }

    final fragment = pick.isFreeEntry
        ? await _showFreeTraitDialog(singularLabel: singularLabel)
        : await _showTraitValueDialog(pick.trait!);
    if (fragment == null || fragment.trim().isEmpty) {
      return;
    }
    final fragments = splitHeroTraitText(_field(keyName).text).toList();
    fragments.add(fragment);
    _writeTraitFragments(keyName, fragments);
  }

  Future<_TraitCatalogPick?> _showTraitCatalogDialog({
    required String singularLabel,
    required List<HeroTraitDef> traits,
  }) {
    final searchController = TextEditingController();
    return showDialog<_TraitCatalogPick>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final query = searchController.text.trim().toLowerCase();
            final filtered = traits
                .where((trait) {
                  if (query.isEmpty) {
                    return true;
                  }
                  final haystack = [
                    trait.name,
                    trait.costText,
                    trait.source,
                    ...trait.markers,
                  ].join(' ').toLowerCase();
                  return haystack.contains(query);
                })
                .take(80)
                .toList(growable: false);

            return AlertDialog(
              title: Text('$singularLabel auswählen'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        labelText: 'Suche',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 260,
                      child: ListView.builder(
                        itemCount: filtered.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return ListTile(
                              leading: const Icon(Icons.edit_note),
                              title: const Text('Freier Eintrag'),
                              onTap: () => Navigator.of(
                                dialogContext,
                              ).pop(const _TraitCatalogPick.freeEntry()),
                            );
                          }
                          final trait = filtered[index - 1];
                          final subtitleParts = <String>[
                            if (trait.costText.isNotEmpty) trait.costText,
                            if (trait.markers.isNotEmpty)
                              trait.markers.join(', '),
                            if (trait.source.isNotEmpty) trait.source,
                          ];
                          return ListTile(
                            title: Text(trait.name),
                            subtitle: subtitleParts.isEmpty
                                ? null
                                : Text(subtitleParts.join(' · ')),
                            onTap: () => Navigator.of(
                              dialogContext,
                            ).pop(_TraitCatalogPick.trait(trait)),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Abbrechen'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String?> _showTraitValueDialog(HeroTraitDef trait) async {
    final needsChoice = trait.selectionTemplate.contains('{choice}');
    final needsValue =
        trait.selectionTemplate.contains('{value}') ||
        trait.valueKind == 'level' ||
        trait.valueKind == 'points';
    if (!needsChoice && !needsValue) {
      return buildHeroTraitSelectionText(trait: trait);
    }

    final choiceController = TextEditingController();
    final valueController = TextEditingController(
      text: (trait.minValue ?? 1).toString(),
    );
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(trait.name),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (needsChoice)
                  TextField(
                    controller: choiceController,
                    decoration: const InputDecoration(
                      labelText: 'Spezialisierung',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    autofocus: true,
                  ),
                if (needsChoice && needsValue) const SizedBox(height: 12),
                if (needsValue)
                  TextField(
                    controller: valueController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: trait.unit.isEmpty ? 'Wert' : trait.unit,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    autofocus: !needsChoice,
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
              onPressed: () {
                final parsedValue = int.tryParse(valueController.text.trim());
                final value = needsValue
                    ? _clampTraitValue(parsedValue, trait)
                    : null;
                final fragment = buildHeroTraitSelectionText(
                  trait: trait,
                  choice: choiceController.text,
                  value: value,
                );
                Navigator.of(dialogContext).pop(fragment);
              },
              child: const Text('Übernehmen'),
            ),
          ],
        );
      },
    );
    return result;
  }

  Future<String?> _showFreeTraitDialog({required String singularLabel}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('$singularLabel erfassen'),
          content: SizedBox(
            width: 420,
            child: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Eintrag',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Übernehmen'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editTraitFragment({
    required String keyName,
    required List<String> fragments,
    required int fragmentIndex,
  }) async {
    final controller = TextEditingController(text: fragments[fragmentIndex]);
    final updated = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eintrag bearbeiten'),
          content: SizedBox(
            width: 420,
            child: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Eintrag',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Übernehmen'),
            ),
          ],
        );
      },
    );
    if (updated == null) {
      return;
    }
    final nextFragments = fragments.toList();
    nextFragments[fragmentIndex] = updated;
    _writeTraitFragments(keyName, nextFragments);
  }

  void _removeTraitFragment({
    required String keyName,
    required List<String> fragments,
    required int fragmentIndex,
  }) {
    final nextFragments = fragments.toList()..removeAt(fragmentIndex);
    _writeTraitFragments(keyName, nextFragments);
  }

  void _writeTraitFragments(String keyName, List<String> fragments) {
    final serialized = serializeHeroTraitFragments(fragments);
    _setFieldText(keyName, serialized);
    _onFieldChanged(serialized);
  }

  int _clampTraitValue(int? rawValue, HeroTraitDef trait) {
    final min = trait.minValue ?? 1;
    final max = trait.maxValue;
    var value = rawValue ?? min;
    if (value < min) {
      value = min;
    }
    if (max != null && value > max) {
      value = max;
    }
    return value;
  }
}

class _TraitCatalogPick {
  const _TraitCatalogPick.trait(this.trait) : isFreeEntry = false;

  const _TraitCatalogPick.freeEntry() : trait = null, isFreeEntry = true;

  final HeroTraitDef? trait;
  final bool isFreeEntry;
}
