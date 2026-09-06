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
    final inputChip = InputChip(
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
    return inputChip;
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
    final existing = splitHeroTraitText(_field(keyName).text).toList();
    final fragments = pick.trait == null
        ? (existing..add(fragment))
        : mergeHeroTraitFragment(
            fragments: existing,
            fragment: fragment,
            trait: pick.trait!,
          );
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
                              onTap: () =>
                                  Navigator.of(dialogContext)
                                      .pop(const _TraitCatalogPick.freeEntry()),
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
                            onTap: () =>
                                Navigator.of(dialogContext)
                                    .pop(_TraitCatalogPick.trait(trait)),
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

    final catalog = ref.read(rulesCatalogProvider).valueOrNull;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => _TraitValueDialog(
        trait: trait,
        needsChoice: needsChoice,
        needsValue: needsValue,
        choices: needsChoice
            ? resolveTraitChoices(trait, catalog)
            : const <String>[],
      ),
    );
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

  Future<void> _removeTraitFragment({
    required String keyName,
    required List<String> fragments,
    required int fragmentIndex,
  }) async {
    final nextFragments = fragments.toList()..removeAt(fragmentIndex);
    _writeTraitFragments(keyName, nextFragments);
  }

  void _writeTraitFragments(String keyName, List<String> fragments) {
    final serialized = serializeHeroTraitFragments(fragments);
    _setFieldText(keyName, serialized);
    _onFieldChanged(serialized);
  }
}

class _TraitCatalogPick {
  const _TraitCatalogPick.trait(this.trait) : isFreeEntry = false;

  const _TraitCatalogPick.freeEntry() : trait = null, isFreeEntry = true;

  final HeroTraitDef? trait;
  final bool isFreeEntry;
}

/// Sentinel des Auswahl-Dropdowns fuer den Eintrag „Eigene Eingabe…".
const String _kTraitFreeChoiceSentinel = '__freitext__';

/// Klemmt einen Dialogwert gegen `minValue`/`maxValue` des Katalogeintrags.
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

/// Erfasst Auswahl und Zahlenwert eines katalogisierten Vor-/Nachteils.
///
/// Eigener [StatefulWidget], damit die Controller erst mit der Dialog-Route
/// entsorgt werden. Ein `dispose()` direkt nach `await showDialog` waere zu
/// frueh: die Route baut waehrend ihrer Schliess-Animation noch einmal auf.
class _TraitValueDialog extends StatefulWidget {
  const _TraitValueDialog({
    required this.trait,
    required this.needsChoice,
    required this.needsValue,
    required this.choices,
  });

  final HeroTraitDef trait;
  final bool needsChoice;
  final bool needsValue;
  final List<String> choices;

  @override
  State<_TraitValueDialog> createState() => _TraitValueDialogState();
}

class _TraitValueDialogState extends State<_TraitValueDialog> {
  late final TextEditingController _choiceController;
  late final TextEditingController _valueController;
  late String _selectedChoice;

  /// Ohne Vorschlagsliste bleibt es beim reinen Textfeld wie bisher; ein
  /// Dropdown mit nur dem Freitext-Eintrag waere ein Klick ohne Nutzen.
  bool get _useDropdown => widget.choices.isNotEmpty;

  bool get _isFreeChoice => _selectedChoice == _kTraitFreeChoiceSentinel;

  String get _resolvedChoice => _isFreeChoice || !_useDropdown
      ? _choiceController.text.trim()
      : _selectedChoice.trim();

  String get _choiceLabel => widget.trait.choiceLabel.trim().isEmpty
      ? 'Spezialisierung'
      : widget.trait.choiceLabel.trim();

  @override
  void initState() {
    super.initState();
    _choiceController = TextEditingController();
    _valueController = TextEditingController(
      text: (widget.trait.minValue ?? 1).toString(),
    );
    // Ist Freitext gesperrt, steht die erste Option vor; sonst startet der
    // Dialog leer, damit keine Auswahl versehentlich uebernommen wird.
    _selectedChoice = _useDropdown && !widget.trait.choiceFreeText
        ? widget.choices.first
        : '';
  }

  @override
  void dispose() {
    _choiceController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Widget _buildChoiceTextField() {
    return TextField(
      key: const Key('trait-choice-freetext'),
      controller: _choiceController,
      decoration: InputDecoration(
        labelText: _choiceLabel,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      autofocus: true,
      onChanged: (_) => setState(() {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = !widget.needsChoice || _resolvedChoice.isNotEmpty;

    return AlertDialog(
      title: Text(widget.trait.name),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.needsChoice && _useDropdown)
              DropdownButtonFormField<String>(
                key: const Key('trait-choice-dropdown'),
                initialValue: _selectedChoice.isEmpty ? null : _selectedChoice,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: _choiceLabel,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final choice in widget.choices)
                    DropdownMenuItem<String>(
                      value: choice,
                      child: Text(choice, overflow: TextOverflow.ellipsis),
                    ),
                  if (widget.trait.choiceFreeText)
                    const DropdownMenuItem<String>(
                      value: _kTraitFreeChoiceSentinel,
                      child: Text('Eigene Eingabe…'),
                    ),
                ],
                onChanged: (value) {
                  setState(() => _selectedChoice = value ?? '');
                },
              ),
            if (widget.needsChoice && !_useDropdown) _buildChoiceTextField(),
            if (widget.needsChoice && _useDropdown && _isFreeChoice) ...[
              const SizedBox(height: 12),
              _buildChoiceTextField(),
            ],
            if (widget.needsChoice && widget.needsValue)
              const SizedBox(height: 12),
            if (widget.needsValue)
              TextField(
                controller: _valueController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: widget.trait.unit.isEmpty
                      ? 'Wert'
                      : widget.trait.unit,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                autofocus: !widget.needsChoice,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: canSubmit
              ? () {
                  final parsedValue = int.tryParse(
                    _valueController.text.trim(),
                  );
                  final value = widget.needsValue
                      ? _clampTraitValue(parsedValue, widget.trait)
                      : null;
                  final fragment = buildHeroTraitSelectionText(
                    trait: widget.trait,
                    choice: widget.needsChoice ? _resolvedChoice : '',
                    value: value,
                  );
                  Navigator.of(context).pop(fragment);
                }
              : null,
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}
