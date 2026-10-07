part of '../hero_begleiter_tab.dart';

// ---------------------------------------------------------------------------
// Dialoge der Reittier-Ausbildung
// ---------------------------------------------------------------------------

/// Erfasst oder ändert den Ausgangsstand (Stufe, Art, Variante).
///
/// Ein bestehender Stand wird per `copyWith` geändert, damit Schritte,
/// Unarten und unbekannte Felder erhalten bleiben.
class _AusgangsstandDialog extends StatefulWidget {
  const _AusgangsstandDialog({this.initial});

  final ReittierAusbildung? initial;

  @override
  State<_AusgangsstandDialog> createState() => _AusgangsstandDialogState();
}

class _AusgangsstandDialogState extends State<_AusgangsstandDialog> {
  late ReittierAusbildungsstufe _stufe;
  late ReittierAusbildungsart _art;
  late String _varianteId;

  @override
  void initState() {
    super.initState();
    _stufe = widget.initial?.ausgangsstufe ?? ReittierAusbildungsstufe.erprobt;
    _art = widget.initial?.ausgangsart ?? ReittierAusbildungsart.laendlich;
    _varianteId = widget.initial?.varianteId ?? '';
  }

  // Geschult erreicht nur eine fundierte Ausbildung (ZBA S. 35).
  bool get _laendlichMoeglich => _stufe != ReittierAusbildungsstufe.geschult;

  void _speichern() {
    final art = _laendlichMoeglich ? _art : ReittierAusbildungsart.fundiert;
    final ergebnis =
        widget.initial?.copyWith(
          ausgangsstufe: _stufe,
          ausgangsart: art,
          varianteId: _varianteId,
        ) ??
        ReittierAusbildung(
          ausgangsstufe: _stufe,
          ausgangsart: art,
          varianteId: _varianteId,
        );
    Navigator.of(context).pop(ergebnis);
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveInputDialog(
      title: widget.initial == null ? 'Ausbildung erfassen' : 'Ausgangsstand',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Die eingetragenen Werte des Tiers enthalten bereits alles bis zu '
            'dieser Stufe. Erst später gebuchte Schritte ändern sie.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: _fieldSpacing),
          DropdownButtonFormField<ReittierAusbildungsstufe>(
            key: const ValueKey<String>('ausgangsstand-stufe'),
            initialValue: _stufe,
            decoration: const InputDecoration(
              labelText: 'Stufe',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final stufe in ReittierAusbildungsstufe.values)
                DropdownMenuItem(value: stufe, child: Text(stufe.label)),
            ],
            onChanged: (stufe) {
              if (stufe != null) setState(() => _stufe = stufe);
            },
          ),
          const SizedBox(height: _fieldSpacing),
          DropdownButtonFormField<ReittierAusbildungsart>(
            key: ValueKey<String>('ausgangsstand-art-$_laendlichMoeglich'),
            initialValue: _laendlichMoeglich
                ? _art
                : ReittierAusbildungsart.fundiert,
            decoration: const InputDecoration(
              labelText: 'Ausbildungsart',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final art in ReittierAusbildungsart.values)
                if (_laendlichMoeglich ||
                    art == ReittierAusbildungsart.fundiert)
                  DropdownMenuItem(value: art, child: Text(art.label)),
            ],
            onChanged: (art) {
              if (art != null) setState(() => _art = art);
            },
          ),
          const SizedBox(height: _fieldSpacing),
          _VarianteAuswahl(
            varianteId: _varianteId,
            onChanged: (id) => setState(() => _varianteId = id),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(onPressed: _speichern, child: const Text('Übernehmen')),
      ],
    );
  }
}

/// Auswahl einer Ausbildungsvariante samt Kurzbeschreibung.
class _VarianteAuswahl extends StatelessWidget {
  const _VarianteAuswahl({required this.varianteId, required this.onChanged});

  final String varianteId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final variante = reittierVariante(varianteId);
    final bekannt = variante != null || varianteId.isEmpty;
    final muted = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: const ValueKey<String>('ausbildung-variante'),
          initialValue: bekannt ? varianteId : '',
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Ausbildungsvariante',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            const DropdownMenuItem(value: '', child: Text('keine')),
            for (final v in kReittierVarianten)
              DropdownMenuItem(
                value: v.id,
                child: Text(v.kampfpferd ? '${v.name} (Kampfpferd)' : v.name),
              ),
          ],
          onChanged: (id) => onChanged(id ?? ''),
        ),
        if (variante != null) ...[
          const SizedBox(height: 4),
          if (!variante.modifikationen.istLeer)
            Text(
              reittierModifikationenText(variante.modifikationen),
              style: muted,
            ),
          if (variante.sfIds.isNotEmpty)
            Text(
              'SF: ${variante.sfIds.map((id) => pferdeSf(id)?.name ?? id).join(', ')}',
              style: muted,
            ),
          if (variante.hinweis.isNotEmpty) Text(variante.hinweis, style: muted),
        ],
      ],
    );
  }
}

/// Auswahl einer weiteren Unart.
class _UnartDialog extends StatelessWidget {
  const _UnartDialog({required this.vorhanden});

  final List<String> vorhanden;

  @override
  Widget build(BuildContext context) {
    return AdaptiveInputDialog(
      title: 'Unart hinzufügen',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final unart in kPferdeUnarten)
            if (!vorhanden.contains(unart.id))
              ListTile(
                dense: true,
                title: Text(
                  unart.lo == 0
                      ? unart.name
                      : '${unart.name} (LO ${mitVorzeichen(unart.lo)})',
                ),
                subtitle: Text(unart.kurzwirkung),
                onTap: () => Navigator.of(context).pop(unart.id),
              ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
      ],
    );
  }
}

/// Ergebnis des Schrittdialogs.
class _AusbildungsschrittWahl {
  const _AusbildungsschrittWahl({
    required this.schritt,
    required this.varianteId,
    required this.varianteSfUebernehmen,
  });

  final ReittierAusbildungsschritt schritt;

  /// Gewählte Variante; nur beim Schritt nach „geschult“ belegt.
  final String? varianteId;
  final bool varianteSfUebernehmen;
}

/// Wählt und beschreibt den nächsten Ausbildungsschritt.
///
/// Gesperrte Schritte lassen sich nur mit „Trotzdem (Meisterentscheid)“
/// buchen. Die geforderten Proben stehen als Liste; wer sie am Tisch würfelt
/// oder von einem Zureiter erledigen lässt, trägt nur die Fehlschläge ein.
class _AusbildungsschrittDialog extends StatefulWidget {
  const _AusbildungsschrittDialog({required this.ausbildung});

  final ReittierAusbildung ausbildung;

  @override
  State<_AusbildungsschrittDialog> createState() =>
      _AusbildungsschrittDialogState();
}

class _AusbildungsschrittDialogState extends State<_AusbildungsschrittDialog> {
  late final List<ReittierSchrittOption> _optionen;
  late int _gewaehlt;
  late String _varianteId;
  bool _meisterentscheid = false;
  bool _sfUebernehmen = true;
  int _fehlschlaege = 0;
  final TextEditingController _ausbilder = TextEditingController();
  final TextEditingController _notiz = TextEditingController();

  @override
  void initState() {
    super.initState();
    _optionen = naechsteAusbildungsschritte(widget.ausbildung);
    final frei = _optionen.indexWhere((o) => o.sperrgrund == null);
    _gewaehlt = frei < 0 ? 0 : frei;
    _varianteId = widget.ausbildung.varianteId;
  }

  @override
  void dispose() {
    _ausbilder.dispose();
    _notiz.dispose();
    super.dispose();
  }

  ReittierSchrittOption get _option => _optionen[_gewaehlt];

  bool get _bestaetigbar {
    if (_option.sperrgrund != null && !_meisterentscheid) return false;
    if (_option.brauchtVariante && _varianteId.isEmpty) return false;
    return true;
  }

  void _buchen() {
    final schritt = _option.schritt;
    Navigator.of(context).pop(
      _AusbildungsschrittWahl(
        schritt: ReittierAusbildungsschritt(
          nach: schritt.nach,
          art: schritt.art,
          fehlschlaege: _fehlschlaege,
          ausbilder: _ausbilder.text.trim(),
          notiz: _notiz.text.trim(),
        ),
        varianteId: _option.brauchtVariante ? _varianteId : null,
        varianteSfUebernehmen: _sfUebernehmen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final schritt = _option.schritt;
    final unarten = faelligeUnarten(schritt.art, _fehlschlaege);
    return AdaptiveInputDialog(
      title: 'Ausbildungsschritt',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RadioGroup<int>(
            groupValue: _gewaehlt,
            onChanged: (i) => setState(() {
              _gewaehlt = i ?? _gewaehlt;
              _meisterentscheid = false;
            }),
            child: Column(
              children: [
                for (var i = 0; i < _optionen.length; i++)
                  RadioListTile<int>(
                    key: ValueKey<String>('ausbildungsschritt-option-$i'),
                    value: i,
                    dense: true,
                    title: Text(
                      reittierSchrittText(
                        _optionen[i].schritt.nach,
                        _optionen[i].schritt.art,
                      ),
                    ),
                    subtitle: _optionen[i].sperrgrund == null
                        ? null
                        : Text(_optionen[i].sperrgrund!),
                  ),
              ],
            ),
          ),
          if (_option.sperrgrund != null)
            CheckboxListTile(
              dense: true,
              value: _meisterentscheid,
              title: const Text('Trotzdem (Meisterentscheid)'),
              onChanged: (v) => setState(() => _meisterentscheid = v ?? false),
            ),
          Text(schritt.hinweis, style: muted),
          for (final hinweis in _option.hinweise) Text(hinweis, style: muted),
          if (!schritt.modifikationen.istLeer)
            Text(
              'Modifikationen: '
              '${reittierModifikationenText(schritt.modifikationen)}',
            ),
          if (_option.brauchtVariante) ...[
            const SizedBox(height: _fieldSpacing),
            _VarianteAuswahl(
              varianteId: _varianteId,
              onChanged: (id) => setState(() => _varianteId = id),
            ),
            CheckboxListTile(
              dense: true,
              value: _sfUebernehmen,
              title: const Text('Sonderfertigkeiten der Variante übernehmen'),
              onChanged: (v) => setState(() => _sfUebernehmen = v ?? true),
            ),
          ],
          if (schritt.proben.isNotEmpty) ...[
            const SizedBox(height: _fieldSpacing),
            Text('Proben des Ausbilders', style: theme.textTheme.labelMedium),
            for (final probe in schritt.proben) Text(reittierProbeText(probe)),
          ],
          const SizedBox(height: _fieldSpacing),
          Row(
            children: [
              const Expanded(child: Text('Misslungene Proben')),
              IconButton(
                icon: const Icon(Icons.remove),
                tooltip: 'Weniger',
                onPressed: _fehlschlaege == 0
                    ? null
                    : () => setState(() => _fehlschlaege--),
              ),
              Text('$_fehlschlaege'),
              IconButton(
                key: const ValueKey<String>('ausbildungsschritt-fehlschlag'),
                icon: const Icon(Icons.add),
                tooltip: 'Mehr',
                onPressed: () => setState(() => _fehlschlaege++),
              ),
            ],
          ),
          if (unarten > 0)
            Text(
              unarten == 1
                  ? 'Eine Unart nach Meisterwahl ist fällig; trage sie unter '
                        'Unarten ein.'
                  : '$unarten Unarten nach Meisterwahl sind fällig; trage sie '
                        'unter Unarten ein.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          const SizedBox(height: _fieldSpacing),
          TextField(
            controller: _ausbilder,
            decoration: const InputDecoration(
              labelText: 'Ausbilder',
              hintText: 'Held oder Zureiter',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: _fieldSpacing),
          TextField(
            controller: _notiz,
            decoration: const InputDecoration(
              labelText: 'Notiz',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('ausbildungsschritt-buchen'),
          onPressed: _bestaetigbar ? _buchen : null,
          child: const Text('Buchen'),
        ),
      ],
    );
  }
}

/// Wählt eine Pferde-SF zum Erlernen und zeigt ihre Lernbarkeit.
class _PferdeSfDialog extends StatefulWidget {
  const _PferdeSfDialog({required this.companion});

  final HeroCompanion companion;

  @override
  State<_PferdeSfDialog> createState() => _PferdeSfDialogState();
}

class _PferdeSfDialogState extends State<_PferdeSfDialog> {
  String? _gewaehlt;
  bool _meisterentscheid = false;

  PferdeSfLernbarkeit? get _lernbarkeit => _gewaehlt == null
      ? null
      : pferdeSfLernbarkeit(widget.companion, _gewaehlt!);

  bool get _bestaetigbar {
    final lernbarkeit = _lernbarkeit;
    if (lernbarkeit == null) return false;
    return lernbarkeit.sperrgrund == null || _meisterentscheid;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final sortiert = <PferdeSfDef>[
      for (final typ in PferdeSfTyp.values)
        ...kPferdeSonderfertigkeiten.where((sf) => sf.typ == typ),
    ];
    final lernbarkeit = _lernbarkeit;
    return AdaptiveInputDialog(
      title: 'Pferde-Sonderfertigkeit',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RadioGroup<String>(
            groupValue: _gewaehlt,
            onChanged: (id) => setState(() {
              _gewaehlt = id;
              _meisterentscheid = false;
            }),
            child: Column(
              children: [
                for (final sf in sortiert)
                  if (!begleiterBeherrschtPferdeSf(widget.companion, sf.id))
                    RadioListTile<String>(
                      key: ValueKey<String>('pferde-sf-${sf.id}'),
                      value: sf.id,
                      dense: true,
                      title: Text(
                        '${sf.name} (${sf.typ.label}'
                        '${sf.kampf ? ', Kampf' : ''})',
                      ),
                      subtitle: Text(sf.kurzwirkung),
                    ),
              ],
            ),
          ),
          if (lernbarkeit != null) ...[
            const Divider(),
            if (lernbarkeit.erschwernis != null)
              Text(
                'Lernprobe: Abrichten '
                '${mitVorzeichen(lernbarkeit.erschwernis!)}',
              ),
            if (lernbarkeit.sperrgrund != null) ...[
              Text(
                lernbarkeit.sperrgrund!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              CheckboxListTile(
                dense: true,
                value: _meisterentscheid,
                title: const Text('Trotzdem (Meisterentscheid)'),
                onChanged: (v) =>
                    setState(() => _meisterentscheid = v ?? false),
              ),
            ],
            for (final hinweis in lernbarkeit.hinweise)
              Text(hinweis, style: muted),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('pferde-sf-erlernen'),
          onPressed: _bestaetigbar
              ? () => Navigator.of(context).pop(_gewaehlt)
              : null,
          child: const Text('Erlernen'),
        ),
      ],
    );
  }
}
