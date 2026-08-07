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
        traits: traits,
      ),
    );
    return inputChip;
  }

  bool _isGraduatedTrait(HeroTraitDef trait) {
    return trait.valueKind.contains('level') || trait.valueKind.contains('points');
  }

  Future<void> _abbauGraduatedTrait({
    required String keyName,
    required List<String> fragments,
    required int fragmentIndex,
    required HeroTraitDef trait,
    required int currentLevel,
  }) async {
    final hero = _latestHero;
    if (hero == null) {
      return;
    }
    final minWert = trait.minValue ?? 0;
    final gpWertProPunkt = parseGpAmount(trait.costText);
    final istSpeziellerErfahrungFaehig = trait.markers.contains('SE');
    final ergebnis = await showNachteilAbbauDialog(
      context: context,
      bezeichnung: trait.name,
      aktuellerWert: currentLevel,
      minWert: minWert,
      gpWertProPunkt: gpWertProPunkt,
      istSpeziellerErfahrungFaehig: istSpeziellerErfahrungFaehig,
      verfuegbareAp: hero.apAvailable,
      episch: hero.isEpisch,
    );
    if (ergebnis == null) {
      return;
    }
    if (ergebnis.apKosten > 0) {
      _erhoeheApSpent(ergebnis.apKosten);
    }
    final nextFragments = fragments.toList();
    if (ergebnis.neuerWert < minWert) {
      nextFragments.removeAt(fragmentIndex);
    } else {
      nextFragments[fragmentIndex] = buildHeroTraitSelectionText(
        trait: trait,
        value: ergebnis.neuerWert,
      );
    }
    _writeTraitFragments(keyName, nextFragments);
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
    if (keyName == 'vorteile' && pick.trait != null) {
      final apKosten = await _confirmTraitApKosten(
        trait: pick.trait!,
        faktor: kVorteilErwerbFaktor,
        titel: 'Vorteil nachträglich erwerben',
        frage:
            'Soll "${pick.trait!.name}" nachträglich mit AP-Kosten '
            'verrechnet werden (50 × GP-Wert)?',
      );
      if (apKosten > 0) {
        _erhoeheApSpent(apKosten);
      }
    }
    final fragments = splitHeroTraitText(_field(keyName).text).toList();
    fragments.add(fragment);
    _writeTraitFragments(keyName, fragments);
  }

  /// Sucht den zu einem gespeicherten Textfragment passenden Katalogeintrag
  /// (best effort, gleiche Praefix-Heuristik wie `isKnownHeroTraitFragment`).
  HeroTraitDef? _findMatchingTrait(String fragment, List<HeroTraitDef> traits) {
    final normalized = fragment.trim().toLowerCase();
    for (final trait in traits) {
      if (normalized.startsWith(trait.name.trim().toLowerCase())) {
        return trait;
      }
    }
    return null;
  }

  void _erhoeheApSpent(int apKosten) {
    final hero = _latestHero;
    if (hero == null || apKosten <= 0) {
      return;
    }
    final updatedHero = hero.copyWith(apSpent: hero.apSpent + apKosten);
    _latestHero = updatedHero;
    _setFieldText('ap_spent', updatedHero.apSpent.toString());
  }

  /// Fragt optional (Checkbox-Ersatz: eigener Bestaetigungsdialog, Default
  /// "ohne AP-Kosten") nach AP-Kosten fuer nachtraeglichen Vorteil-Erwerb
  /// bzw. Nachteil-Abbau und liefert die bestaetigten AP-Kosten (0, wenn
  /// abgelehnt/abgebrochen).
  Future<int> _confirmTraitApKosten({
    required HeroTraitDef trait,
    required int faktor,
    required String titel,
    required String frage,
  }) async {
    final hero = _latestHero;
    if (hero == null) {
      return 0;
    }
    final entscheidung = await showAdaptiveConfirmDialog(
      context: context,
      title: titel,
      content: frage,
      cancelLabel: 'Ohne AP-Kosten',
      confirmLabel: 'Mit AP-Kosten',
    );
    if (entscheidung != AdaptiveConfirmResult.confirm) {
      return 0;
    }
    if (!mounted) {
      return 0;
    }
    final gpWert = parseGpAmount(trait.costText);
    final vorschlag = gpWert == null
        ? null
        : computeTraitApCost(gpWert, faktor);
    final erwerb = await showErwerbDialog(
      context: context,
      bezeichnung: trait.name,
      kostenHinweis: trait.costText.isEmpty ? null : trait.costText,
      vorgeschlageneApKosten: vorschlag,
      verfuegbareAp: hero.apAvailable,
      episch: hero.isEpisch,
    );
    return erwerb?.apKosten ?? 0;
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

  Future<void> _removeTraitFragment({
    required String keyName,
    required List<String> fragments,
    required int fragmentIndex,
    List<HeroTraitDef> traits = const <HeroTraitDef>[],
  }) async {
    if (keyName == 'nachteile') {
      final fragment = fragments[fragmentIndex];
      final trait = _findMatchingTrait(fragment, traits);
      if (trait != null && _isGraduatedTrait(trait)) {
        final currentLevel = parseTraitFragmentValue(fragment, trait);
        if (currentLevel != null) {
          await _abbauGraduatedTrait(
            keyName: keyName,
            fragments: fragments,
            fragmentIndex: fragmentIndex,
            trait: trait,
            currentLevel: currentLevel,
          );
          return;
        }
      }
      if (trait != null) {
        final apKosten = await _confirmTraitApKosten(
          trait: trait,
          faktor: kNachteilAbbauFaktor,
          titel: 'Nachteil abbauen',
          frage:
              'Soll "${trait.name}" nachträglich mit AP-Kosten '
              'verrechnet werden (100 × GP-Wert)?',
        );
        if (apKosten > 0) {
          _erhoeheApSpent(apKosten);
        }
      }
    }
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
