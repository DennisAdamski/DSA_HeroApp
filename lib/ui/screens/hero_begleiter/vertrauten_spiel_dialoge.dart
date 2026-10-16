part of '../hero_begleiter_tab.dart';

// ---------------------------------------------------------------------------
// Dialoge der Vertrautenaktionen am Spieltisch (V2)
// ---------------------------------------------------------------------------

/// Vereinigung bei Vollmond: je 1W6 AsP für Hexe und Vertrauten.
///
/// Die Würfe sind vorbelegt und änderbar (echte Würfel am Tisch). Der Dialog
/// liefert beide Würfe; gebucht wird im Aufrufer.
class _VereinigungsDialog extends StatefulWidget {
  const _VereinigungsDialog({
    required this.name,
    required this.aspHexe,
    required this.aspVertrauter,
  });

  final String name;
  final int aspHexe;
  final int aspVertrauter;

  @override
  State<_VereinigungsDialog> createState() => _VereinigungsDialogState();
}

class _VereinigungsDialogState extends State<_VereinigungsDialog> {
  final math.Random _zufall = math.Random();
  late final TextEditingController _hexe = TextEditingController(
    text: '${_zufall.nextInt(6) + 1}',
  );
  late final TextEditingController _tier = TextEditingController(
    text: '${_zufall.nextInt(6) + 1}',
  );

  @override
  void dispose() {
    _hexe.dispose();
    _tier.dispose();
    super.dispose();
  }

  int? _wurf(TextEditingController c) {
    final w = int.tryParse(c.text.trim());
    return w != null && w >= 1 && w <= 6 ? w : null;
  }

  void _neuWuerfeln() => setState(() {
    _hexe.text = '${_zufall.nextInt(6) + 1}';
    _tier.text = '${_zufall.nextInt(6) + 1}';
  });

  @override
  Widget build(BuildContext context) {
    final hexe = _wurf(_hexe);
    final tier = _wurf(_tier);
    final theme = Theme.of(context);
    String vorschau(int? wurf, int vorrat, String wer) => wurf == null
        ? '$wer: Wurf zwischen 1 und 6 eintragen.'
        : '$wer: −${vertrautenVereinigungsVerlust(aktuell: vorrat, wurf: wurf)} '
              'AsP (hat $vorrat)';
    return AdaptiveInputDialog(
      title: 'Vereinigung bei Vollmond',
      maxWidth: kDialogWidthSmall,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hexe und Vertrauter verlieren in der Vollmondnacht je 1W6 AsP '
            '(WdZ S. 125).',
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey<String>('vertrauten-vereinigung-hexe'),
                  controller: _hexe,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '1W6 Hexe'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const ValueKey<String>('vertrauten-vereinigung-tier'),
                  controller: _tier,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: '1W6 ${widget.name}'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          TextButton.icon(
            onPressed: _neuWuerfeln,
            icon: const Icon(Icons.casino_outlined, size: 18),
            label: const Text('Neu würfeln'),
          ),
          Text(vorschau(hexe, widget.aspHexe, 'Hexe')),
          Text(vorschau(tier, widget.aspVertrauter, widget.name)),
          if (hexe != null &&
              tier != null &&
              (hexe > widget.aspHexe || tier > widget.aspVertrauter))
            Text(
              'Der Vorrat reicht nicht; es werden nur die vorhandenen AsP '
              'abgezogen.',
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
          key: const ValueKey<String>('vertrauten-vereinigung-bestaetigen'),
          onPressed: hexe != null && tier != null
              ? () => Navigator.of(context).pop<(int, int)>((hexe, tier))
              : null,
          child: const Text('Buchen'),
        ),
      ],
    );
  }
}

/// Versäumtes Vollmondtreffen: −1 LeP (Zustand) und −1 LO (Bogen).
///
/// Zwei getrennte Buchungen (Speichervertrag): bleibt eine hängen, wird sie
/// hier einzeln erneut gewählt.
class _TreffenVersaeumtDialog extends StatefulWidget {
  const _TreffenVersaeumtDialog({required this.loyalitaet});

  final int loyalitaet;

  @override
  State<_TreffenVersaeumtDialog> createState() =>
      _TreffenVersaeumtDialogState();
}

class _TreffenVersaeumtDialogState extends State<_TreffenVersaeumtDialog> {
  bool _lep = true;
  bool _lo = true;

  @override
  Widget build(BuildContext context) {
    return AdaptiveInputDialog(
      title: 'Treffen versäumt',
      maxWidth: kDialogWidthSmall,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ein versäumtes Vollmondtreffen kostet den Vertrauten 1 LeP und '
            '1 LO (WdZ S. 125), wenn die Hexe es nicht durch tägliche '
            'Beschäftigung ausgleicht. Beide Abzüge sind getrennte Buchungen; '
            'ist eine schon erfolgt, hier abwählen.',
          ),
          CheckboxListTile(
            key: const ValueKey<String>('vertrauten-versaeumt-lep'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: _lep,
            title: const Text('−1 LeP'),
            onChanged: (v) => setState(() => _lep = v ?? false),
          ),
          CheckboxListTile(
            key: const ValueKey<String>('vertrauten-versaeumt-lo'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: _lo,
            title: Text(
              '−1 LO (${widget.loyalitaet} → '
              '${widget.loyalitaet > 0 ? widget.loyalitaet - 1 : 0})',
            ),
            onChanged: (v) => setState(() => _lo = v ?? false),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('vertrauten-versaeumt-bestaetigen'),
          onPressed: _lep || _lo
              ? () => Navigator.of(context).pop<(bool, bool)>((_lep, _lo))
              : null,
          child: const Text('Buchen'),
        ),
      ],
    );
  }
}

/// Wählt den Vertrautenzauber und ob die Hexe in Körperkontakt steht.
class _ZauberWahlDialog extends StatefulWidget {
  const _ZauberWahlDialog({required this.kategorie});

  final HeroRitualCategory kategorie;

  @override
  State<_ZauberWahlDialog> createState() => _ZauberWahlDialogState();
}

class _ZauberWahlDialogState extends State<_ZauberWahlDialog> {
  int? _index;
  bool _kontakt = true;

  @override
  Widget build(BuildContext context) {
    final rituale = widget.kategorie.rituals;
    return AdaptiveInputDialog(
      title: 'Vertrautenzauber würfeln',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            key: const ValueKey<String>('vertrauten-zauber-kontakt'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Hexe in Körperkontakt'),
            subtitle: Text(
              _kontakt
                  ? 'Eigenschaften der Hexe, RK des Vertrauten'
                  : 'Eigenschaften des Vertrauten, Probe um '
                        '$kVertrautenAlleinErleichterung erleichtert',
            ),
            value: _kontakt,
            onChanged: (v) => setState(() => _kontakt = v),
          ),
          if (rituale.isEmpty)
            const Text('Der Vertraute kennt noch keinen Zauber.')
          else
            Flexible(
              child: SingleChildScrollView(
                child: RadioGroup<int>(
                  groupValue: _index,
                  onChanged: (v) => setState(() => _index = v),
                  child: Column(
                    children: [
                      for (var i = 0; i < rituale.length; i++)
                        RadioListTile<int>(
                          key: ValueKey<String>('vertrauten-wurf-$i'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: i,
                          title: Text(rituale[i].name),
                          subtitle: Text(
                            [
                              _ritualProbeText(rituale[i]),
                              rituale[i].kosten,
                            ].where((t) => t.isNotEmpty).join(' · '),
                          ),
                        ),
                    ],
                  ),
                ),
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
          key: const ValueKey<String>('vertrauten-zauber-wuerfeln-los'),
          onPressed: _index == null
              ? null
              : () => Navigator.of(context)
                    .pop<(HeroRitualEntry, bool)>((rituale[_index!], _kontakt)),
          child: const Text('Würfeln'),
        ),
      ],
    );
  }
}

/// Fragt die AsP-Kosten eines gewürfelten Vertrautenzaubers ab.
///
/// Der Betrag wird aus dem Ritualtext vorbelegt, wo er sich eindeutig lesen
/// lässt; sonst bleibt er leer. Immer änderbar. Der Vertraute trägt die AsP.
class _ZauberKostenDialog extends StatefulWidget {
  const _ZauberKostenDialog({
    required this.ritual,
    required this.vorrat,
    required this.gelungen,
  });

  final HeroRitualEntry ritual;
  final int vorrat;
  final bool? gelungen;

  @override
  State<_ZauberKostenDialog> createState() => _ZauberKostenDialogState();
}

class _ZauberKostenDialogState extends State<_ZauberKostenDialog> {
  late final VertrautenRitualKosten? _kosten = parseRitualKosten(
    widget.ritual.kosten,
  );
  // Mit einmaligen Kosten zunächst ohne Dauer; reine Dauerkosten starten bei
  // einer Spielrunde.
  late int _runden = (_kosten?.grund ?? 0) > 0 ? 0 : 1;
  late final TextEditingController _betrag = TextEditingController(
    text: _vorschlag(),
  );

  String _vorschlag() {
    final k = _kosten;
    if (k == null) return '';
    return '${k.gesamt(spielrunden: k.hatDauerkosten ? _runden : 0, vorrat: widget.vorrat)}';
  }

  @override
  void dispose() {
    _betrag.dispose();
    super.dispose();
  }

  int? get _asp {
    final w = int.tryParse(_betrag.text.trim());
    return w != null && w >= 0 ? w : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final k = _kosten;
    final asp = _asp;
    final kroete = widget.ritual.name == kKroetenschlagName;
    return AdaptiveInputDialog(
      title: '${widget.ritual.name}: AsP-Kosten',
      maxWidth: kDialogWidthSmall,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.gelungen == null
                ? 'Probe nicht ausgewertet.'
                : widget.gelungen!
                ? 'Die Probe ist gelungen.'
                : 'Die Probe ist misslungen.',
          ),
          Text('Ritualkosten laut Preset: ${widget.ritual.kosten}'),
          if (k == null)
            Text(
              'Die Kosten lassen sich nicht eindeutig lesen; bitte den Betrag '
              'eintragen.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          if (k != null && k.hatDauerkosten)
            Row(
              children: [
                Expanded(child: Text('Spielrunden Wirkung: $_runden')),
                IconButton(
                  tooltip: 'Eine Spielrunde weniger',
                  icon: const Icon(Icons.remove, size: 18),
                  onPressed: _runden > 0
                      ? () => setState(() {
                          _runden--;
                          _betrag.text = _vorschlag();
                        })
                      : null,
                ),
                IconButton(
                  tooltip: 'Eine Spielrunde mehr',
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: () => setState(() {
                    _runden++;
                    _betrag.text = _vorschlag();
                  }),
                ),
              ],
            ),
          TextField(
            key: const ValueKey<String>('vertrauten-zauber-asp'),
            controller: _betrag,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'AsP des Vertrauten abziehen',
            ),
            onChanged: (_) => setState(() {}),
          ),
          Text('Vorrat des Vertrauten: ${widget.vorrat} AsP'),
          if (asp != null && asp > widget.vorrat)
            Text(
              'Der Vorrat reicht nicht; abgezogen werden höchstens '
              '${widget.vorrat} AsP.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          if (kroete && asp != null)
            Text(
              'Krötenschlag: ${asp < widget.vorrat ? asp : widget.vorrat} SP '
              'in Höhe der eingesetzten AsP, bei mehreren Gegnern '
              'gleichmäßig verteilt (nur zur Anzeige).',
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Nicht abziehen'),
        ),
        FilledButton(
          key: const ValueKey<String>('vertrauten-zauber-asp-bestaetigen'),
          onPressed: asp == null
              ? null
              : () => Navigator.of(context).pop<int>(asp),
          child: const Text('AsP abziehen'),
        ),
      ],
    );
  }
}

/// Einfache Rückfrage mit Text und einer Bestätigungsaktion.
class _VertrautenBestaetigenDialog extends StatelessWidget {
  const _VertrautenBestaetigenDialog({
    required this.titel,
    required this.text,
    required this.aktion,
  });

  final String titel;
  final String text;
  final String aktion;

  @override
  Widget build(BuildContext context) {
    return AdaptiveInputDialog(
      title: titel,
      maxWidth: kDialogWidthSmall,
      content: Text(text),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('vertrauten-bestaetigen'),
          onPressed: () => Navigator.of(context).pop<bool>(true),
          child: Text(aktion),
        ),
      ],
    );
  }
}
