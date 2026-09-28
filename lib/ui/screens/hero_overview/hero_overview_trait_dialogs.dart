part of 'package:dsa_heldenverwaltung/ui/screens/hero_overview_tab.dart';

/// Dialoge und Pruefhinweise der Vor-/Nachteil-Bearbeitung (ARCH-02).
extension _HeroOverviewTraitDialogs on _HeroOverviewTabState {
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

  Future<String?> _showEditTraitTextDialog(String initialText) {
    final controller = TextEditingController(text: initialText);
    return showDialog<String>(
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
  }

  /// Ordnet einen mehrdeutigen Alttext einem der Kandidaten zu oder laesst
  /// ihn bewusst frei; liefert `null` bei Abbruch.
  Future<HeroMerkmal?> _waehleMerkmalKandidat(
    HeroMerkmal eintrag,
    List<HeroTraitDef> traits,
  ) async {
    final kandidaten = <HeroTraitDef>[
      for (final id in eintrag.kandidatenIds)
        ...traits.where((trait) => trait.id == id),
    ];
    final gewaehlt = await showDialog<Object>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: Text('„${eintrag.text}“ zuordnen'),
          children: [
            for (final trait in kandidaten)
              SimpleDialogOption(
                key: ValueKey<String>('overview-trait-kandidat-${trait.id}'),
                onPressed: () => Navigator.of(dialogContext).pop(trait),
                child: Text(trait.name),
              ),
            SimpleDialogOption(
              key: const ValueKey<String>('overview-trait-kandidat-frei'),
              onPressed: () => Navigator.of(dialogContext).pop(_kFreiLassen),
              child: const Text('Als freien Eintrag behalten'),
            ),
          ],
        );
      },
    );
    if (!mounted || gewaehlt == null) {
      return null;
    }
    if (gewaehlt is! HeroTraitDef) {
      return eintrag.copyWith(
        kandidatenIds: const <String>[],
        zuordnung: HeroMerkmalZuordnung.frei,
      );
    }
    final zugeordnet = ordneMerkmalZu(eintrag.text, <HeroTraitDef>[gewaehlt]);
    return eintrag.copyWith(
      katalogId: gewaehlt.id,
      wert: zugeordnet.wert,
      auswahl: zugeordnet.auswahl,
      kandidatenIds: const <String>[],
      zuordnung: HeroMerkmalZuordnung.katalog,
    );
  }

  /// Hinweis, dass eine aeltere App-Version den Text geaendert hat.
  ///
  /// Die Liste fuehrt und bleibt wirksam; der Nutzer entscheidet, ob der
  /// geaenderte Text uebernommen oder die Liste behalten wird. Erst danach
  /// laesst sich die Liste bearbeiten.
  Widget _buildTraitDeviation({
    required String keyName,
    required MerkmalAbweichung abweichung,
    required List<HeroTraitDef> traits,
    required RulesCatalog? catalog,
    required bool isEditing,
  }) {
    final theme = Theme.of(context);
    final hero = _latestHero;
    final text = hero == null
        ? ''
        : (keyName == 'vorteile' ? hero.vorteileText : hero.nachteileText);
    final liste = hero == null
        ? const <HeroMerkmal>[]
        : (keyName == 'vorteile'
              ? hero.vorteilEintraege
              : hero.nachteilEintraege);
    return Container(
      key: ValueKey<String>('overview-traits-abweichung-$keyName'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(kartoRadiusOder(context, 8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Eine ältere App-Version hat diese Einträge geändert. '
            'Wirksam bleibt die Liste, bis du entscheidest.',
            style: theme.textTheme.bodyMedium,
          ),
          if (abweichung.hinzugefuegt.isNotEmpty)
            Text('Neu im Text: ${abweichung.hinzugefuegt.join(', ')}'),
          if (abweichung.entfernt.isNotEmpty)
            Text('Im Text entfernt: ${abweichung.entfernt.join(', ')}'),
          const SizedBox(height: 8),
          if (!isEditing)
            Text(
              'Zum Entscheiden in den Bearbeitungsmodus wechseln.',
              style: theme.textTheme.bodySmall,
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  key: ValueKey<String>(
                    'overview-traits-text-uebernehmen-$keyName',
                  ),
                  onPressed: () => _setzeMerkmale(
                    keyName,
                    uebernimmMerkmalText(text, liste, traits),
                  ),
                  child: const Text('Geänderten Text übernehmen'),
                ),
                OutlinedButton(
                  key: ValueKey<String>(
                    'overview-traits-liste-behalten-$keyName',
                  ),
                  onPressed: () => _setzeMerkmale(keyName, liste),
                  child: const Text('Liste behalten'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TraitCatalogPick {
  const _TraitCatalogPick.trait(this.trait) : isFreeEntry = false;

  const _TraitCatalogPick.freeEntry() : trait = null, isFreeEntry = true;

  final HeroTraitDef? trait;
  final bool isFreeEntry;
}

/// Antwort des Kandidatendialogs fuer „Als freien Eintrag behalten“;
/// `null` bleibt dem Abbruch vorbehalten.
const Object _kFreiLassen = Object();

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

/// Im Dialog gewaehlte Auswahl und gewaehlter Wert eines Merkmals.
typedef _TraitWahl = ({String auswahl, int? wert});

/// Erfasst Auswahl und Zahlenwert eines katalogisierten Vor-/Nachteils.
///
/// Mit [initialChoice]/[initialValue] bearbeitet er einen bestehenden
/// Eintrag; der Katalogbezug bleibt dabei erhalten (ARCH-02).
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
    this.initialChoice = '',
    this.initialValue,
  });

  final HeroTraitDef trait;
  final bool needsChoice;
  final bool needsValue;
  final List<String> choices;
  final String initialChoice;
  final int? initialValue;

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
    final initialChoice = widget.initialChoice.trim();
    _choiceController = TextEditingController(text: initialChoice);
    _valueController = TextEditingController(
      text: (widget.initialValue ?? widget.trait.minValue ?? 1).toString(),
    );
    // Ist Freitext gesperrt, steht die erste Option vor; sonst startet der
    // Dialog leer, damit keine Auswahl versehentlich uebernommen wird.
    _selectedChoice = _useDropdown && !widget.trait.choiceFreeText
        ? widget.choices.first
        : '';
    if (_useDropdown && initialChoice.isNotEmpty) {
      _selectedChoice = widget.choices.contains(initialChoice)
          ? initialChoice
          : (widget.trait.choiceFreeText
                ? _kTraitFreeChoiceSentinel
                : _selectedChoice);
    }
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
                  final _TraitWahl wahl = (
                    auswahl: widget.needsChoice ? _resolvedChoice : '',
                    wert: value,
                  );
                  Navigator.of(context).pop(wahl);
                }
              : null,
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}
