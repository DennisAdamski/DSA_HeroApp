part of '../hero_magic_tab.dart';

/// Kopfbereich des Magie-Tabs: Repräsentation, Leiteigenschaft und
/// Merkmalskenntnisse.
///
/// Die Repräsentation entscheidet laut Wege der Zauberei S. 19 über die
/// Leiteigenschaft. Deshalb wird diese hier nicht mehr frei gewählt, sondern
/// aus den Traditionen abgeleitet; das Eingabefeld bleibt nur als bewusste
/// Abweichung erhalten. Bei mehrdeutigen Repräsentationen — aktuell nur die
/// geodische — fragt der Erwerb zuerst nach der Ausprägung.
class _MagicHeaderSection extends StatelessWidget {
  const _MagicHeaderSection({
    required this.representationen,
    required this.repraesentationsTraditionen,
    required this.merkmalskenntnisse,
    required this.magicLeadAttribute,
    required this.isEditing,
    required this.onRepresentationenChanged,
    required this.onRepraesentationsTraditionenChanged,
    required this.onMerkmalskenntnisseChanged,
    required this.onMagicLeadAttributeChanged,
    this.verfuegbareAp = 0,
    this.episch = false,
    this.onApKostenBestaetigt,
  });

  final List<String> representationen;
  final Map<String, String> repraesentationsTraditionen;
  final List<String> merkmalskenntnisse;
  final String magicLeadAttribute;
  final bool isEditing;
  final void Function(List<String>) onRepresentationenChanged;
  final void Function(Map<String, String>) onRepraesentationsTraditionenChanged;
  final void Function(List<String>) onMerkmalskenntnisseChanged;
  final void Function(String value) onMagicLeadAttributeChanged;

  final int verfuegbareAp;
  final bool episch;

  /// Wird nach einem bestaetigten Erwerbsdialog aufgerufen; der Aufrufer
  /// erhoeht damit `hero.apSpent`.
  final ValueChanged<int>? onApKostenBestaetigt;

  /// Die aufgeloesten Traditionen des Helden.
  List<TraditionDef> get _traditionen => resolveHeroTraditionen(
    repraesentationen: representationen,
    gewaehlteTraditionen: repraesentationsTraditionen,
  );

  /// Die abgeleiteten Leiteigenschaften.
  Set<String> get _abgeleiteteLeiteigenschaften =>
      leiteigenschaftenFuer(_traditionen);

  /// Schaltet eine Merkmalskenntnis um. Beim Aktivieren wird der Erwerb ueber
  /// den Erwerbsdialog bestaetigt (100/200/300 AP je Klassifikation, WdH
  /// S. 289); ein Abbruch laesst den Chip aus. Beim Deaktivieren werden — wie
  /// ueberall sonst in der App — keine AP zurueckerstattet.
  Future<void> _toggleMerkmalskenntnis(
    BuildContext context,
    String merkmal,
    bool value,
  ) async {
    final updated = List<String>.from(merkmalskenntnisse);
    if (!value) {
      updated.remove(merkmal);
      onMerkmalskenntnisseChanged(updated);
      return;
    }
    final stufe = merkmalsklassifikation(merkmal);
    final erwerb = await showErwerbDialog(
      context: context,
      bezeichnung: 'Merkmalskenntnis $merkmal',
      kostenHinweis:
          'Klassifikation $stufe: ${merkmalskenntnisApCost(merkmal)} AP; '
          'die erste Merkmalskenntnis ist bei vielen Professionen enthalten '
          '(dann 0 AP)',
      vorgeschlageneApKosten: merkmalskenntnisApCost(merkmal),
      verfuegbareAp: verfuegbareAp,
      episch: episch,
    );
    if (erwerb == null) {
      return;
    }
    updated.add(merkmal);
    onMerkmalskenntnisseChanged(updated);
    if (erwerb.apKosten > 0) {
      onApKostenBestaetigt?.call(erwerb.apKosten);
    }
  }

  /// Schaltet eine Repraesentation um. Beim Aktivieren wird — falls das
  /// Kuerzel mehrere Traditionen traegt — zuerst die Auspraegung erfragt und
  /// danach der Erwerb ueber den Erwerbsdialog bestaetigt (WdH S. 290).
  /// Vorgeschlagen wird der Vollzauberer-Preis; der Halbzauberer-Preis steht
  /// im Kostenhinweis und kann im editierbaren AP-Feld uebernommen werden.
  Future<void> _toggleRepresentation(
    BuildContext context,
    String representation,
    bool value,
  ) async {
    final updated = List<String>.from(representationen);
    final traditionen = Map<String, String>.from(repraesentationsTraditionen);
    if (!value) {
      updated.remove(representation);
      traditionen.remove(representation);
      onRepresentationenChanged(updated);
      onRepraesentationsTraditionenChanged(traditionen);
      return;
    }

    var gewaehlteTradition = '';
    if (repraesentationBrauchtTraditionswahl(representation)) {
      final auswahl = await showAdaptiveInputDialog<String>(
        context: context,
        builder: (_) => _TraditionSelectionDialog(
          repraesentation: representation,
          kandidaten: traditionenFuerRepraesentation(representation),
        ),
      );
      if (auswahl == null || auswahl.isEmpty || !context.mounted) {
        return;
      }
      gewaehlteTradition = auswahl;
    }

    final anzahl = representationen.length;
    final vollzauberer = repraesentationApCost(
      anzahlVorhanden: anzahl,
      istHalbzauberer: false,
    );
    final halbzauberer = repraesentationApCost(
      anzahlVorhanden: anzahl,
      istHalbzauberer: true,
    );
    final erwerb = await showErwerbDialog(
      context: context,
      bezeichnung: 'Repräsentation ${_anzeigeName(representation)}',
      kostenHinweis: _representationKostenHinweis(
        anzahl: anzahl,
        vollzauberer: vollzauberer,
        halbzauberer: halbzauberer,
      ),
      vorgeschlageneApKosten: vollzauberer ?? 0,
      verfuegbareAp: verfuegbareAp,
      episch: episch,
    );
    if (erwerb == null) {
      return;
    }
    updated.add(representation);
    if (gewaehlteTradition.isNotEmpty) {
      traditionen[representation] = gewaehlteTradition;
    }
    onRepresentationenChanged(updated);
    onRepraesentationsTraditionenChanged(traditionen);
    if (erwerb.apKosten > 0) {
      onApKostenBestaetigt?.call(erwerb.apKosten);
    }
  }

  /// `Gildenmagisch (Mag)` statt des blossen Kuerzels.
  String _anzeigeName(String kuerzel) {
    final kandidaten = traditionenFuerRepraesentation(kuerzel);
    if (kandidaten.isEmpty) {
      return kuerzel;
    }
    final gewaehlt = repraesentationsTraditionen[kuerzel];
    final tradition = gewaehlt == null || gewaehlt.isEmpty
        ? kandidaten.first
        : (traditionById(gewaehlt) ?? kandidaten.first);
    return kandidaten.length > 1 && (gewaehlt == null || gewaehlt.isEmpty)
        ? 'Geodisch ($kuerzel)'
        : '${tradition.name} ($kuerzel)';
  }

  String _representationKostenHinweis({
    required int anzahl,
    required int? vollzauberer,
    required int? halbzauberer,
  }) {
    if (anzahl <= 0) {
      return 'Die erste Repräsentation stammt aus Kultur bzw. Profession '
          'und kostet keine AP.';
    }
    final teile = <String>[
      if (vollzauberer != null) 'Vollzauberer $vollzauberer AP',
      if (halbzauberer != null)
        'Halbzauberer $halbzauberer AP'
      else
        'für Halbzauberer laut Regelwerk nicht vorgesehen',
    ];
    return '${anzahl + 1}. Repräsentation: ${teile.join('; ')} '
        '(Wege der Helden S. 290)';
  }

  /// Beschreibt, woher die Leiteigenschaft kommt.
  String _leiteigenschaftHinweis() {
    final override = magicLeadAttribute.trim();
    final abgeleitet = _abgeleiteteLeiteigenschaften;
    if (override.isNotEmpty) {
      if (abgeleitet.isEmpty) {
        return 'Manuell gesetzt.';
      }
      return abgeleitet.contains(override.toUpperCase())
          ? 'Passt zur Tradition ${_traditionsNamen()}.'
          : 'Weicht bewusst von der Tradition ab '
                '(${abgeleitet.join(' / ')} laut ${_traditionsNamen()}).';
    }
    if (abgeleitet.isEmpty) {
      return 'Ohne Repräsentation oder Ritualkenntnis nicht ableitbar.';
    }
    if (abgeleitet.length > 1) {
      return '${abgeleitet.join(' / ')} — mehrere Traditionen '
          '(${_traditionsNamen()}).';
    }
    return '${abgeleitet.single} aus ${_traditionsNamen()}.';
  }

  String _traditionsNamen() =>
      _traditionen.map((tradition) => tradition.name).join(', ');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final abgeleitet = _abgeleiteteLeiteigenschaften;
    final effektiv = magicLeadAttribute.trim().isNotEmpty
        ? magicLeadAttribute.trim().toUpperCase()
        : (abgeleitet.length == 1 ? abgeleitet.single : '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CodexSectionCard(
        title: 'Repräsentationen & Fokus',
        subtitle:
            'Repräsentationen, Merkmalskenntnisse und arkane Leiteigenschaft.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Repräsentation', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: kRepresentationen
                  .map((rep) {
                    final selected = representationen.contains(rep);
                    return FilterChip(
                      key: ValueKey<String>('magic-representation-$rep'),
                      label: Text(_anzeigeName(rep)),
                      selected: selected,
                      onSelected: isEditing
                          ? (value) =>
                                _toggleRepresentation(context, rep, value)
                          : null,
                    );
                  })
                  .toList(growable: false),
            ),
            const SizedBox(height: 16),
            Text('Leiteigenschaft', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              key: const ValueKey<String>('magic-lead-attribute-derived'),
              effektiv.isEmpty
                  ? 'Nicht bestimmt — ${_leiteigenschaftHinweis()}'
                  : '$effektiv — ${_leiteigenschaftHinweis()}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: const ValueKey<String>('magic-lead-attribute-field'),
              initialValue: magicLeadAttribute.isEmpty
                  ? null
                  : magicLeadAttribute,
              decoration: const InputDecoration(
                labelText: 'Abweichende Leiteigenschaft',
                border: OutlineInputBorder(),
                helperText: 'Nur setzen, wenn sie von der Tradition abweicht.',
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(value: 'MU', child: Text('MU')),
                DropdownMenuItem<String>(value: 'KL', child: Text('KL')),
                DropdownMenuItem<String>(value: 'IN', child: Text('IN')),
                DropdownMenuItem<String>(value: 'CH', child: Text('CH')),
                DropdownMenuItem<String>(value: 'FF', child: Text('FF')),
                DropdownMenuItem<String>(value: 'GE', child: Text('GE')),
                DropdownMenuItem<String>(value: 'KO', child: Text('KO')),
                DropdownMenuItem<String>(value: 'KK', child: Text('KK')),
              ],
              onChanged: isEditing
                  ? (value) => onMagicLeadAttributeChanged(value ?? '')
                  : null,
            ),
            if (isEditing && magicLeadAttribute.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey<String>('magic-lead-attribute-clear'),
                  onPressed: () => onMagicLeadAttributeChanged(''),
                  icon: const Icon(Icons.clear),
                  label: const Text('Abweichung entfernen'),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text('Merkmalskenntnisse', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: kMerkmale
                  .map((merkmal) {
                    final selected = merkmalskenntnisse.contains(merkmal);
                    return FilterChip(
                      label: Text(merkmal),
                      selected: selected,
                      onSelected: isEditing
                          ? (value) =>
                                _toggleMerkmalskenntnis(context, merkmal, value)
                          : null,
                    );
                  })
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fragt die Auspraegung einer mehrdeutigen Repraesentation ab.
///
/// Betrifft aktuell nur die geodische: Herren der Erde fuehren die Klugheit,
/// Diener Sumus die Intuition als Leiteigenschaft (WdZ S. 19). Ohne diese
/// Wahl bliebe unentschieden, welche der beiden gilt.
class _TraditionSelectionDialog extends StatefulWidget {
  const _TraditionSelectionDialog({
    required this.repraesentation,
    required this.kandidaten,
  });

  final String repraesentation;
  final List<TraditionDef> kandidaten;

  @override
  State<_TraditionSelectionDialog> createState() =>
      _TraditionSelectionDialogState();
}

class _TraditionSelectionDialogState extends State<_TraditionSelectionDialog> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.kandidaten.isEmpty ? null : widget.kandidaten.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AdaptiveInputDialog(
      title: 'Tradition wählen',
      maxWidth: kDialogWidthSmall,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Die Repräsentation ${widget.repraesentation} wird von mehreren '
            'Traditionen genutzt. Die Wahl bestimmt die Leiteigenschaft.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          // Bewusst ListTile mit Radio-Icon statt RadioListTile: dasselbe
          // Muster wie im Zauber-Repraesentationsdialog, und ohne die
          // seit Flutter 3.32 deprecateten Radio-Gruppenparameter.
          for (final tradition in widget.kandidaten)
            ListTile(
              key: ValueKey<String>('magic-tradition-${tradition.id}'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                _selected == tradition.id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              title: Text(tradition.name),
              subtitle: Text('Leiteigenschaft ${tradition.leiteigenschaft}'),
              onTap: () => setState(() => _selected = tradition.id),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('magic-tradition-confirm'),
          onPressed: _selected == null
              ? null
              : () => Navigator.of(context).pop(_selected),
          child: const Text('Weiter'),
        ),
      ],
    );
  }
}
