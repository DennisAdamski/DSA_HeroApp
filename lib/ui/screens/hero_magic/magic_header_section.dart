part of '../hero_magic_tab.dart';

/// Kopfbereich des Magie-Tabs: Repräsentation und Merkmalskenntnisse.
class _MagicHeaderSection extends StatelessWidget {
  const _MagicHeaderSection({
    required this.representationen,
    required this.merkmalskenntnisse,
    required this.magicLeadAttribute,
    required this.isEditing,
    required this.onRepresentationenChanged,
    required this.onMerkmalskenntnisseChanged,
    required this.onMagicLeadAttributeChanged,
    this.verfuegbareAp = 0,
    this.episch = false,
    this.onApKostenBestaetigt,
  });

  final List<String> representationen;
  final List<String> merkmalskenntnisse;
  final String magicLeadAttribute;
  final bool isEditing;
  final void Function(List<String>) onRepresentationenChanged;
  final void Function(List<String>) onMerkmalskenntnisseChanged;
  final void Function(String value) onMagicLeadAttributeChanged;

  final int verfuegbareAp;
  final bool episch;

  /// Wird nach einem bestaetigten Erwerbsdialog aufgerufen; der Aufrufer
  /// erhoeht damit `hero.apSpent`.
  final ValueChanged<int>? onApKostenBestaetigt;

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

  /// Schaltet eine Repraesentation um. Beim Aktivieren wird der Erwerb ueber
  /// den Erwerbsdialog bestaetigt (WdH S. 290). Vorgeschlagen wird der
  /// Vollzauberer-Preis; der Halbzauberer-Preis steht im Kostenhinweis und
  /// kann im editierbaren AP-Feld uebernommen werden.
  Future<void> _toggleRepresentation(
    BuildContext context,
    String representation,
    bool value,
  ) async {
    final updated = List<String>.from(representationen);
    if (!value) {
      updated.remove(representation);
      onRepresentationenChanged(updated);
      return;
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
      bezeichnung: 'Repräsentation $representation',
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
    onRepresentationenChanged(updated);
    if (erwerb.apKosten > 0) {
      onApKostenBestaetigt?.call(erwerb.apKosten);
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                      label: Text(rep),
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
            DropdownButtonFormField<String>(
              key: const ValueKey<String>('magic-lead-attribute-field'),
              initialValue: magicLeadAttribute.isEmpty
                  ? null
                  : magicLeadAttribute,
              decoration: const InputDecoration(
                labelText: 'Leiteigenschaft',
                border: OutlineInputBorder(),
                helperText: 'Wird für Meisterliche Regeneration verwendet.',
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
                  label: const Text('Leiteigenschaft löschen'),
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
