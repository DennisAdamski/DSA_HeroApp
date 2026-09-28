part of 'package:dsa_heldenverwaltung/ui/screens/hero_overview_tab.dart';

/// Vor- und Nachteile der Uebersicht (ARCH-02).
///
/// Bearbeitet wird die strukturierte Liste (`HeroMerkmal` mit Katalog-ID,
/// Wert und Auswahl); `vorteileText`/`nachteileText` entstehen beim Speichern
/// als Projektion. Solange nichts geaendert wurde, bleibt der Entwurf `null`
/// und der Held unberuehrt — die Migration uebernimmt dann `saveHero`.
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
          catalog: catalog,
          isCatalogLoading: catalogAsync.isLoading,
        ),
        _buildTraitPanel(
          title: 'Nachteile',
          singularLabel: 'Nachteil',
          keyName: 'nachteile',
          traits: disadvantages,
          catalog: catalog,
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
    required RulesCatalog? catalog,
    required bool isCatalogLoading,
  }) {
    final eintraege = _merkmale(keyName, catalog);
    final abweichung = _merkmalAbweichung(keyName);
    final isEditing = _editController.isEditing;
    final sortedTraits = traits.where((entry) => entry.active).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    // Erst entscheiden, dann bearbeiten: sonst ueberschriebe ein Speichern
    // die Aenderung der aelteren App-Version stillschweigend.
    final gesperrt = abweichung != null;

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
                onPressed: isCatalogLoading || gesperrt
                    ? null
                    : () => _addTraitEntry(
                        keyName: keyName,
                        singularLabel: singularLabel,
                        traits: sortedTraits,
                        catalog: catalog,
                      ),
                child: Text('+ $singularLabel'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (abweichung != null) ...[
          _buildTraitDeviation(
            keyName: keyName,
            abweichung: abweichung,
            traits: sortedTraits,
            catalog: catalog,
            isEditing: isEditing,
          ),
          const SizedBox(height: 8),
        ],
        if (eintraege.isEmpty)
          Text('Keine Einträge', style: Theme.of(context).textTheme.bodyMedium)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var index = 0; index < eintraege.length; index++)
                _buildTraitChip(
                  keyName: keyName,
                  eintraege: eintraege,
                  index: index,
                  traits: sortedTraits,
                  catalog: catalog,
                  isEditing: isEditing && !gesperrt,
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildTraitChip({
    required String keyName,
    required List<HeroMerkmal> eintraege,
    required int index,
    required List<HeroTraitDef> traits,
    required RulesCatalog? catalog,
    required bool isEditing,
  }) {
    final eintrag = eintraege[index];
    final label = Text(eintrag.text);
    final Widget? avatar = eintrag.istKatalogisiert
        ? const Icon(Icons.check, size: 16)
        : eintrag.brauchtPruefung
        ? const Tooltip(
            message: 'Mehrdeutig – bitte Katalogeintrag wählen',
            child: Icon(Icons.help_outline, size: 16),
          )
        : null;
    if (!isEditing) {
      return Chip(
        label: label,
        avatar: eintrag.brauchtPruefung ? avatar : null,
        visualDensity: VisualDensity.compact,
      );
    }
    return InputChip(
      key: ValueKey<String>('overview-trait-chip-$keyName-$index'),
      label: label,
      avatar: avatar,
      visualDensity: VisualDensity.compact,
      onPressed: () => _editTraitEntry(
        keyName: keyName,
        eintraege: eintraege,
        index: index,
        traits: traits,
        catalog: catalog,
      ),
      onDeleted: () => _setzeMerkmale(
        keyName,
        List<HeroMerkmal>.of(eintraege)..removeAt(index),
      ),
    );
  }

  /// Wirksame Liste: Entwurf, sonst Abgleich des gespeicherten Helden.
  List<HeroMerkmal> _merkmale(String keyName, RulesCatalog? catalog) {
    final entwurf = keyName == 'vorteile' ? _draftVorteile : _draftNachteile;
    if (entwurf != null) {
      return entwurf;
    }
    final hero = _latestHero;
    if (hero == null) {
      return const <HeroMerkmal>[];
    }
    final abgleich = werteMerkmaleAus(hero, catalog: catalog).abgleich;
    return keyName == 'vorteile' ? abgleich.vorteile : abgleich.nachteile;
  }

  /// Abweichung durch eine aeltere App-Version; ein Entwurf loest sie auf.
  MerkmalAbweichung? _merkmalAbweichung(String keyName) {
    final hero = _latestHero;
    final entwurf = keyName == 'vorteile' ? _draftVorteile : _draftNachteile;
    if (hero == null || entwurf != null) {
      return null;
    }
    final abgleich = gleicheMerkmaleAb(hero);
    return keyName == 'vorteile'
        ? abgleich.vorteilAbweichung
        : abgleich.nachteilAbweichung;
  }

  void _setzeMerkmale(String keyName, List<HeroMerkmal> eintraege) {
    final liste = List<HeroMerkmal>.unmodifiable(eintraege);
    if (keyName == 'vorteile') {
      _draftVorteile = liste;
    } else {
      _draftNachteile = liste;
    }
    _onFieldChanged('');
  }

  /// Uebernimmt einen Merkmalsentwurf in [hero]: Liste plus Projektion.
  HeroSheet _mitMerkmalEntwurf(HeroSheet hero) {
    var ergebnis = hero;
    final vorteile = _draftVorteile;
    if (vorteile != null) {
      ergebnis = ergebnis.copyWith(
        vorteilEintraege: vorteile,
        vorteileText: projiziereMerkmalText(vorteile),
      );
    }
    final nachteile = _draftNachteile;
    if (nachteile != null) {
      ergebnis = ergebnis.copyWith(
        nachteilEintraege: nachteile,
        nachteileText: projiziereMerkmalText(nachteile),
      );
    }
    return ergebnis;
  }

  Future<void> _addTraitEntry({
    required String keyName,
    required String singularLabel,
    required List<HeroTraitDef> traits,
    required RulesCatalog? catalog,
  }) async {
    final pick = await _showTraitCatalogDialog(
      singularLabel: singularLabel,
      traits: traits,
    );
    if (pick == null) {
      return;
    }
    final HeroMerkmal neu;
    final def = pick.trait;
    if (def == null) {
      final text = await _showFreeTraitDialog(singularLabel: singularLabel);
      if (text == null || text.trim().isEmpty) {
        return;
      }
      neu = HeroMerkmal(
        text: text.trim(),
        zuordnung: HeroMerkmalZuordnung.frei,
      );
    } else {
      final wahl = await _showTraitValueDialog(def);
      if (wahl == null) {
        return;
      }
      neu = HeroMerkmal(
        katalogId: def.id,
        text: merkmalTextFuer(def, auswahl: wahl.auswahl, wert: wahl.wert),
        wert: wahl.wert,
        auswahl: wahl.auswahl,
      );
    }
    _setzeMerkmale(
      keyName,
      fuegeMerkmalHinzu(_merkmale(keyName, catalog), neu, def: def),
    );
  }

  Future<void> _editTraitEntry({
    required String keyName,
    required List<HeroMerkmal> eintraege,
    required int index,
    required List<HeroTraitDef> traits,
    required RulesCatalog? catalog,
  }) async {
    final eintrag = eintraege[index];
    final def = eintrag.istKatalogisiert
        ? catalog == null
              ? null
              : MerkmalKatalog.von(catalog)
                    .eintrag(eintrag.katalogId, vorteil: keyName == 'vorteile')
        : null;
    HeroMerkmal? ersetzt;
    if (def != null && _brauchtTraitWahl(def)) {
      final wahl = await _showTraitValueDialog(
        def,
        initialChoice: eintrag.auswahl,
        initialValue: eintrag.wert,
      );
      if (wahl == null) {
        return;
      }
      ersetzt = eintrag.copyWith(
        text: merkmalTextFuer(def, auswahl: wahl.auswahl, wert: wahl.wert),
        wert: wahl.wert,
        auswahl: wahl.auswahl,
        zuordnung: HeroMerkmalZuordnung.katalog,
      );
    } else if (eintrag.brauchtPruefung) {
      ersetzt = await _waehleMerkmalKandidat(eintrag, traits);
    } else {
      final text = await _showEditTraitTextDialog(eintrag.text);
      if (text == null || text.trim().isEmpty) {
        return;
      }
      // Ein getippter Katalogname wird zugeordnet, alles andere bleibt frei.
      final zugeordnet = ordneMerkmalZu(text, traits);
      ersetzt = eintrag.copyWith(
        katalogId: zugeordnet.katalogId,
        text: zugeordnet.text,
        wert: zugeordnet.wert,
        auswahl: zugeordnet.auswahl,
        kandidatenIds: zugeordnet.kandidatenIds,
        zuordnung: zugeordnet.istKatalogisiert
            ? HeroMerkmalZuordnung.katalog
            : zugeordnet.zuordnung,
      );
    }
    if (ersetzt == null) {
      return;
    }
    _setzeMerkmale(keyName, List<HeroMerkmal>.of(eintraege)..[index] = ersetzt);
  }

  bool _brauchtTraitWahl(HeroTraitDef trait) {
    return trait.selectionTemplate.contains('{choice}') ||
        trait.selectionTemplate.contains('{value}') ||
        trait.valueKind == 'level' ||
        trait.valueKind == 'points';
  }

  Future<_TraitWahl?> _showTraitValueDialog(
    HeroTraitDef trait, {
    String initialChoice = '',
    int? initialValue,
  }) async {
    final needsChoice = trait.selectionTemplate.contains('{choice}');
    if (!_brauchtTraitWahl(trait)) {
      return (auswahl: '', wert: null);
    }
    final catalog = ref.read(rulesCatalogProvider).valueOrNull;
    return showDialog<_TraitWahl>(
      context: context,
      builder: (dialogContext) => _TraitValueDialog(
        trait: trait,
        needsChoice: needsChoice,
        needsValue:
            trait.selectionTemplate.contains('{value}') ||
            trait.valueKind == 'level' ||
            trait.valueKind == 'points',
        choices: needsChoice
            ? resolveTraitChoices(trait, catalog)
            : const <String>[],
        initialChoice: initialChoice,
        initialValue: initialValue,
      ),
    );
  }
}
