part of '../hero_begleiter_tab.dart';

// ---------------------------------------------------------------------------
// Dialoge der Vertrautenbindung
// ---------------------------------------------------------------------------

/// Wählt Art und Generierung eines neuen Vertrauten (WdZ S. 123 f.).
///
/// Zeigt die Kosten laufend; gebunden wird erst nach Bestätigung, und nur,
/// wenn die Generierung passt und die Hexe genug freie AP hat.
class _VertrautenBindungsDialog extends StatefulWidget {
  const _VertrautenBindungsDialog({
    required this.freieAp,
    required this.machtvollVorbelegt,
  });

  /// Freie AP der Hexe.
  final int freieAp;

  /// Die Hexe hat den Vorteil Machtvoller Vertrauter.
  final bool machtvollVorbelegt;

  @override
  State<_VertrautenBindungsDialog> createState() =>
      _VertrautenBindungsDialogState();
}

class _VertrautenBindungsDialogState extends State<_VertrautenBindungsDialog> {
  String _artId = kVertrautenArten.first.id;
  late bool _machtvoll = widget.machtvollVorbelegt;
  final Map<String, int> _punkte = <String, int>{};
  int _asp = 0;
  int _lep = 0;
  int _aup = 0;

  VertrautenGenerierung get _generierung => VertrautenGenerierung(
    artId: _artId,
    machtvoll: _machtvoll,
    punkte: Map<String, int>.of(_punkte),
    zusatzAsp: _asp,
    zusatzLep: _lep,
    zusatzAup: _aup,
  );

  @override
  Widget build(BuildContext context) {
    final art = vertrautenArt(_artId)!;
    final kosten = vertrautenBindungskosten(_generierung);
    final fehler = [
      ...vertrautenGenerierungsFehler(_generierung),
      if (kosten.summe > widget.freieAp)
        'Die Hexe hat nur ${widget.freieAp} AP frei.',
    ];
    final theme = Theme.of(context);
    final ueber = kosten.ueberMaximum > 0 ? '+ ${kosten.ueberMaximum} ' : '';
    return AdaptiveInputDialog(
      title: 'Vertrauten binden',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            key: const ValueKey<String>('vertrauten-art'),
            initialValue: _artId,
            decoration: const InputDecoration(labelText: 'Tierart'),
            items: [
              for (final a in kVertrautenArten)
                DropdownMenuItem(
                  value: a.id,
                  child: Text('${a.name} (${a.bindungskosten} AP)'),
                ),
            ],
            onChanged: (id) => setState(() {
              _artId = id ?? _artId;
              _punkte.clear();
            }),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Machtvoller Vertrauter'),
            subtitle: const Text('120 AP, freie Werte (Meisterentscheid)'),
            value: _machtvoll,
            onChanged: (v) => setState(() => _machtvoll = v),
          ),
          Text(
            'Punkte verteilen (${_generierung.punkteSumme} / '
            '$kVertrautenGenerierungspunkte, je 2 AP)',
            style: theme.textTheme.labelMedium,
          ),
          for (final (label, key) in kCompanionEigenschaftKeys)
            _PunkteZeile(
              key: ValueKey<String>('vertrauten-punkte-$key'),
              label:
                  '$label ${art.eigenschaften[key]!.start}–'
                  '${art.eigenschaften[key]!.max}',
              wert: _punkte[key] ?? 0,
              ergebnis: art.eigenschaften[key]!.start + (_punkte[key] ?? 0),
              onChanged: (v) => setState(() => _punkte[key] = v),
            ),
          const SizedBox(height: 8),
          Text(
            'Zusätzliche Punkte (je höchstens +3)',
            style: theme.textTheme.labelMedium,
          ),
          _PunkteZeile(
            label: 'AsP ${art.asp} (je 5 AP)',
            wert: _asp,
            ergebnis: art.asp + _asp,
            onChanged: (v) => setState(() => _asp = v),
          ),
          _PunkteZeile(
            label: 'LeP ${art.lep} (je 5 AP)',
            wert: _lep,
            ergebnis: art.lep + _lep,
            onChanged: (v) => setState(() => _lep = v),
          ),
          _PunkteZeile(
            label: 'AuP ${art.aup} (je 2 AP)',
            wert: _aup,
            ergebnis: art.aup + _aup,
            onChanged: (v) => setState(() => _aup = v),
          ),
          const SizedBox(height: 8),
          Text(
            'Kosten: ${kosten.grundkosten} + ${kosten.punkte} $ueber'
            '+ ${kosten.zusatzpunkte} = ${kosten.summe} AP der Hexe '
            '(frei: ${widget.freieAp})',
          ),
          for (final f in fehler)
            Text(
              f,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
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
          key: const ValueKey<String>('vertrauten-bindung-bestaetigen'),
          onPressed: fehler.isEmpty
              ? () => Navigator.of(context).pop(_generierung)
              : null,
          child: Text('Binden (${kosten.summe} AP)'),
        ),
      ],
    );
  }
}

// Eine Zeile mit −/+ für verteilte Punkte und dem resultierenden Wert.
class _PunkteZeile extends StatelessWidget {
  const _PunkteZeile({
    super.key,
    required this.label,
    required this.wert,
    required this.ergebnis,
    required this.onChanged,
  });

  final String label;
  final int wert;
  final int ergebnis;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          tooltip: '$label senken',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove, size: 18),
          onPressed: wert > 0 ? () => onChanged(wert - 1) : null,
        ),
        SizedBox(width: 28, child: Text('+$wert', textAlign: TextAlign.center)),
        IconButton(
          tooltip: '$label erhöhen',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add, size: 18),
          onPressed: () => onChanged(wert + 1),
        ),
        SizedBox(
          width: 36,
          child: Text('= $ergebnis', textAlign: TextAlign.end),
        ),
      ],
    );
  }
}

/// Erfasst die Bindung eines Bestandsvertrauten ohne Buchung.
class _BindungErfassenDialog extends StatefulWidget {
  const _BindungErfassenDialog({required this.machtvollVorbelegt});

  final bool machtvollVorbelegt;

  @override
  State<_BindungErfassenDialog> createState() => _BindungErfassenDialogState();
}

class _BindungErfassenDialogState extends State<_BindungErfassenDialog> {
  String _artId = kVertrautenArten.first.id;
  late bool _machtvoll = widget.machtvollVorbelegt;

  @override
  Widget build(BuildContext context) {
    return AdaptiveInputDialog(
      title: 'Bindung ohne Buchung erfassen',
      maxWidth: kDialogWidthSmall,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Für einen schon gebundenen Vertrauten: Werte und AP bleiben '
            'unverändert.',
          ),
          DropdownButtonFormField<String>(
            initialValue: _artId,
            decoration: const InputDecoration(labelText: 'Tierart'),
            items: [
              for (final a in kVertrautenArten)
                DropdownMenuItem(value: a.id, child: Text(a.name)),
            ],
            onChanged: (id) => setState(() => _artId = id ?? _artId),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Machtvoller Vertrauter'),
            value: _machtvoll,
            onChanged: (v) => setState(() => _machtvoll = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('vertrauten-erfassen-bestaetigen'),
          onPressed: () => Navigator.of(context).pop((_artId, _machtvoll)),
          child: const Text('Erfassen'),
        ),
      ],
    );
  }
}

/// Fragt eine AP-Zahl ab (Übertragung, Nachtrag).
class _VertrautenApDialog extends StatefulWidget {
  const _VertrautenApDialog({
    required this.titel,
    required this.text,
    required this.vorschlag,
    this.max,
    this.erlaubeNull = false,
  });

  final String titel;
  final String text;
  final int vorschlag;
  final int? max;
  final bool erlaubeNull;

  @override
  State<_VertrautenApDialog> createState() => _VertrautenApDialogState();
}

class _VertrautenApDialogState extends State<_VertrautenApDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.vorschlag}',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? get _wert {
    final wert = int.tryParse(_controller.text.trim());
    if (wert == null || wert < 0 || (wert == 0 && !widget.erlaubeNull)) {
      return null;
    }
    if (widget.max != null && wert > widget.max!) return null;
    return wert;
  }

  @override
  Widget build(BuildContext context) {
    final wert = _wert;
    return AdaptiveInputDialog(
      title: widget.titel,
      maxWidth: kDialogWidthSmall,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.text),
          TextField(
            key: const ValueKey<String>('vertrauten-ap-feld'),
            controller: _controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'AP',
              helperText: widget.max == null ? null : 'höchstens ${widget.max}',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('vertrauten-ap-bestaetigen'),
          onPressed: wert == null
              ? null
              : () => Navigator.of(context).pop(wert),
          child: const Text('Buchen'),
        ),
      ],
    );
  }
}

/// Ergebnis der Ausbildungswahl.
typedef _VertrautenAusbildungWahl = ({
  String katalogId,
  int apKosten,
  String bezeichnung,
  bool meisterentscheid,
});

/// Wählt eine Ausbildungsstufe oder Fertigkeit (ZBA S. 19–21).
class _VertrautenAusbildungDialog extends StatefulWidget {
  const _VertrautenAusbildungDialog({required this.companion});

  final HeroCompanion companion;

  @override
  State<_VertrautenAusbildungDialog> createState() =>
      _VertrautenAusbildungDialogState();
}

class _VertrautenAusbildungDialogState
    extends State<_VertrautenAusbildungDialog> {
  String? _id;
  int _ap = 10;
  bool _meisterentscheid = false;
  final TextEditingController _bezeichnung = TextEditingController();

  @override
  void dispose() {
    _bezeichnung.dispose();
    super.dispose();
  }

  void _waehle(String? id) {
    if (id == null) return;
    setState(() {
      _id = id;
      _meisterentscheid = false;
      _ap =
          vertrautenAusbildung(id)?.apKosten ??
          vertrautenFertigkeit(id)?.apVorschlag ??
          10;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.companion;
    final frei = companionApVerfuegbar(c);
    final geeignet = vertrautenArt(c.vertrautenBindung?.artId ?? '')
        ?.ausbildungIds;
    final id = _id;
    final sperre = id == null ? null : vertrautenAusbildungSperrgrund(c, id);
    final fertigkeit = id == null ? null : vertrautenFertigkeit(id);
    final darf =
        id != null && (sperre == null || _meisterentscheid) && _ap <= frei;
    final theme = Theme.of(context);
    return AdaptiveInputDialog(
      title: 'Ausbildung buchen',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Freie AP des Vertrauten: $frei'),
          RadioGroup<String>(
            groupValue: _id,
            onChanged: _waehle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  'Ausbildungsstufen (TaP* × 10 AP)',
                  style: theme.textTheme.labelMedium,
                ),
                for (final s in kVertrautenAusbildungen)
                  if (s.fuerVertraute)
                    RadioListTile<String>(
                      key: ValueKey<String>('vertrauten-ausbildung-${s.id}'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: s.id,
                      title: Text('${s.name} – ${s.apKosten} AP'),
                      subtitle: Text(
                        [
                          if (geeignet != null && !geeignet.contains(s.id))
                            'für diese Art nicht üblich',
                          if (s.hinweis.isNotEmpty) s.hinweis,
                        ].join(' · '),
                      ),
                    ),
                Text(
                  'Kampftier: für Vertraute nicht wählbar (WdZ S. 124).',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Fertigkeiten (10–50 AP)',
                  style: theme.textTheme.labelMedium,
                ),
                for (final f in kVertrautenFertigkeiten)
                  RadioListTile<String>(
                    key: ValueKey<String>('vertrauten-ausbildung-${f.id}'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: f.id,
                    title: Text('${f.name} – Vorschlag ${f.apVorschlag} AP'),
                    subtitle: f.hinweis.isEmpty ? null : Text(f.hinweis),
                  ),
              ],
            ),
          ),
          if (fertigkeit != null) ...[
            Row(
              children: [
                Expanded(child: Text('Kosten: $_ap AP')),
                IconButton(
                  tooltip: 'Kosten senken',
                  icon: const Icon(Icons.remove, size: 18),
                  onPressed: _ap > 10 ? () => setState(() => _ap -= 5) : null,
                ),
                IconButton(
                  tooltip: 'Kosten erhöhen',
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: _ap < 50 ? () => setState(() => _ap += 5) : null,
                ),
              ],
            ),
            if (fertigkeit.mehrfach)
              TextField(
                controller: _bezeichnung,
                decoration: const InputDecoration(labelText: 'Name des Tricks'),
              ),
          ],
          if (sperre != null) ...[
            Text(
              sperre,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _meisterentscheid,
              title: const Text('Trotzdem (Meisterentscheid)'),
              onChanged: (v) => setState(() => _meisterentscheid = v ?? false),
            ),
          ],
          if (_ap > frei)
            Text(
              'Der Vertraute hat nur $frei AP frei.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
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
          key: const ValueKey<String>('vertrauten-ausbildung-bestaetigen'),
          onPressed: darf
              ? () => Navigator.of(context).pop<_VertrautenAusbildungWahl>((
                  katalogId: id,
                  apKosten: _ap,
                  bezeichnung: _bezeichnung.text,
                  meisterentscheid: _meisterentscheid,
                ))
              : null,
          child: Text('Buchen ($_ap AP)'),
        ),
      ],
    );
  }
}

/// Wählt einen Vertrautenzauber zum Lernen (WdZ S. 126–128).
class _VertrautenZauberDialog extends StatefulWidget {
  const _VertrautenZauberDialog({required this.companion});

  final HeroCompanion companion;

  @override
  State<_VertrautenZauberDialog> createState() =>
      _VertrautenZauberDialogState();
}

class _VertrautenZauberDialogState extends State<_VertrautenZauberDialog> {
  String? _id;
  bool _meisterentscheid = false;
  bool _ohneAp = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.companion;
    final frei = companionApVerfuegbar(c);
    final zugaenge = vertrautenZauberZugaenge(c);
    final wahl = zugaenge.where((z) => z.zauber.id == _id).firstOrNull;
    final kosten = wahl == null || _ohneAp ? 0 : wahl.lernkosten;
    final darf =
        wahl != null &&
        (wahl.sperrgrund == null || _meisterentscheid) &&
        kosten <= frei;
    return AdaptiveInputDialog(
      title: 'Vertrautenzauber lernen',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Freie AP des Vertrauten: $frei'),
          RadioGroup<String>(
            groupValue: _id,
            onChanged: (id) => setState(() {
              _id = id;
              _meisterentscheid = false;
            }),
            child: Column(
              children: [
                for (final zugang in zugaenge)
                  if (!zugang.bekannt)
                    RadioListTile<String>(
                      key: ValueKey<String>('vertrauten-${zugang.zauber.id}'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: zugang.zauber.id,
                      title: Text(
                        '${zugang.zauber.name} – ${zugang.lernkosten} AP',
                      ),
                      subtitle: Text(zugang.sperrgrund ?? 'lernbar'),
                    ),
              ],
            ),
          ),
          if (wahl?.sperrgrund != null)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _meisterentscheid,
              onChanged: (v) => setState(() => _meisterentscheid = v ?? false),
              title: const Text('Trotzdem (Meisterentscheid)'),
            ),
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: _ohneAp,
            onChanged: (v) => setState(() => _ohneAp = v ?? false),
            title: const Text('Ohne AP erfassen (schon früher gelernt)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('vertrauten-zauber-bestaetigen'),
          onPressed: darf
              ? () =>
                    Navigator.of(context)
                        .pop<(String, int)>((wahl.zauber.name, kosten))
              : null,
          child: Text('Lernen ($kosten AP)'),
        ),
      ],
    );
  }
}
