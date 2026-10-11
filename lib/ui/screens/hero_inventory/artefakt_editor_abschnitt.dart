import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/matrix_ausloesen.dart';
import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/domain/aventurian_date.dart';
import 'package:dsa_heldenverwaltung/rules/derived/artefakt_intervall_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/artefakt_matrix_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/artefakt_spruchspeicher_rules.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory/artefakt_ladungen_editor.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory/artefakt_zauber_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory/artefakt_zauber_zeile.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/list_tile_material.dart';

/// Abschnitt „Artefakt“ im Inventareditor.
///
/// Erfasst die Daten eines Matrixgebers (Stabilität, Regelfassung, die
/// eingesprochenen Zauber mit den Werten ihres Sprechers) oder eines
/// ladungsbasierten Spruchspeichers (Ladungen aus Zaubergruppen, bei
/// aufladbaren auch Aufladezähler und Gesamt-AsP) sowie Ersteller und
/// Auslöser. Der Abschnitt hält keinen Entwurf des Eintrags, sondern meldet
/// jede Änderung über [onChanged]; `null` heißt „kein Artefakt“.
class ArtefaktEditorAbschnitt extends StatefulWidget {
  /// Erstellt den Abschnitt für [daten].
  const ArtefaktEditorAbschnitt({
    super.key,
    required this.daten,
    required this.onChanged,
  });

  /// Aktuelle Artefaktdaten des Entwurfs; `null` bei einem normalen Gegenstand.
  final ArtefaktDaten? daten;

  /// Meldet die neuen Artefaktdaten (oder `null`).
  final ValueChanged<ArtefaktDaten?> onChanged;

  @override
  State<ArtefaktEditorAbschnitt> createState() =>
      _ArtefaktEditorAbschnittState();
}

class _ArtefaktEditorAbschnittState extends State<ArtefaktEditorAbschnitt> {
  late final TextEditingController _ersteller = TextEditingController(
    text: widget.daten?.ersteller ?? '',
  );
  late final TextEditingController _ausloeser = TextEditingController(
    text: widget.daten?.ausloeser ?? '',
  );
  late final TextEditingController _aktionen = TextEditingController(
    text: '${widget.daten?.ausloeserAktionen ?? 1}',
  );
  late final TextEditingController _pAsP = TextEditingController(
    text: widget.daten?.pAsP?.toString() ?? '',
  );
  late final TextEditingController _gesamtAsp = TextEditingController(
    text: widget.daten?.gesamtAspErschaffung?.toString() ?? '',
  );
  late final TextEditingController _aufladungen = TextEditingController(
    text: '${widget.daten?.aufladungen ?? 0}',
  );
  late final TextEditingController _anwendungenProIntervall =
      TextEditingController(
        text: '${widget.daten?.anwendungenProIntervall ?? 1}',
      );

  @override
  void dispose() {
    _ersteller.dispose();
    _ausloeser.dispose();
    _aktionen.dispose();
    _pAsP.dispose();
    _gesamtAsp.dispose();
    _aufladungen.dispose();
    _anwendungenProIntervall.dispose();
    super.dispose();
  }

  void _schalte(bool an) {
    if (an) {
      widget.onChanged(widget.daten ?? const ArtefaktDaten());
    } else {
      widget.onChanged(null);
    }
  }

  void _aendere(ArtefaktDaten Function(ArtefaktDaten alt) f) {
    final alt = widget.daten;
    if (alt != null) {
      widget.onChanged(f(alt));
    }
  }

  Future<void> _fuegeZauberHinzu() async {
    final zauber = await zeigeArtefaktZauberDialog(context);
    if (zauber == null || !mounted) return;
    _aendere((d) => d.copyWith(zauber: [...d.zauber, zauber]));
  }

  Future<void> _aendereZauber(int index) async {
    final alt = widget.daten;
    if (alt == null) return;
    final zauber = await zeigeArtefaktZauberDialog(
      context,
      start: alt.zauber[index],
    );
    if (zauber == null || !mounted) return;
    _aendere((d) {
      final liste = [...d.zauber];
      if (index < liste.length) liste[index] = zauber;
      return d.copyWith(zauber: liste);
    });
  }

  void _entferneZauber(int index) => _aendere((d) {
    final liste = [...d.zauber]..removeAt(index);
    return d.copyWith(zauber: liste);
  });

  Widget _dropdown<T>({
    required String schluessel,
    required String label,
    required T wert,
    required Map<T, String> items,
    required ValueChanged<T> onChanged,
  }) => DropdownButtonFormField<T>(
    key: ValueKey<String>('inventory-editor-artefakt-$schluessel'),
    initialValue: wert,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
    ),
    items: [
      for (final e in items.entries)
        DropdownMenuItem<T>(value: e.key, child: Text(e.value)),
    ],
    onChanged: (v) {
      if (v != null) onChanged(v);
    },
  );

  Widget _text(
    String schluessel,
    String label,
    TextEditingController controller,
    ArtefaktDaten Function(ArtefaktDaten alt, String text) schreibe, {
    bool zahl = false,
    String? hilfe,
  }) => TextField(
    key: ValueKey<String>('inventory-editor-artefakt-$schluessel'),
    controller: controller,
    keyboardType: zahl ? TextInputType.number : null,
    onChanged: (t) => _aendere((d) => schreibe(d, t)),
    decoration: InputDecoration(
      labelText: label,
      helperText: hilfe,
      border: const OutlineInputBorder(),
      isDense: true,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final daten = widget.daten;
    final texte = Theme.of(context).textTheme;
    final speicher = daten != null && artefaktHatLadungen(daten.art);
    final semi =
        daten != null && daten.art == ArtefaktArt.spruchspeicherSemipermanent;
    final aufladbar =
        daten != null && daten.art == ArtefaktArt.spruchspeicherAufladbar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTileMaterial(
          child: SwitchListTile.adaptive(
            key: const ValueKey<String>('inventory-editor-artefakt'),
            value: daten != null,
            onChanged: _schalte,
            title: const Text('Artefakt'),
            subtitle: const Text(
              'Matrixgeber oder Spruchspeicher: Die Wirkung steht im '
              'Gegenstand, der Träger löst sie aus.',
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (daten != null) ...[
          const SizedBox(height: 12),
          _dropdown<ArtefaktArt>(
            schluessel: 'art',
            label: 'Art des Artefakts',
            wert: daten.art,
            items: {for (final a in ArtefaktArt.values) a: artefaktArtLabel(a)},
            onChanged: (v) => _aendere((d) => d.copyWith(art: v)),
          ),
          const SizedBox(height: 12),
          if (!speicher && !semi)
            Row(
              children: [
                Expanded(
                  child: _dropdown<MatrixStabilitaet>(
                    schluessel: 'stabilitaet',
                    label: 'Stabilität der Matrix',
                    wert: daten.stabilitaet,
                    items: {
                      for (final s in MatrixStabilitaet.values)
                        s: matrixStabilitaetLabel(s),
                    },
                    onChanged: (v) =>
                        _aendere((d) => d.copyWith(stabilitaet: v)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _fassungDropdown(daten)),
              ],
            )
          else if (aufladbar)
            _fassungDropdown(daten),
          if (semi) ...[
            Row(
              children: [
                Expanded(
                  child: _dropdown<ArtefaktIntervall>(
                    schluessel: 'intervall',
                    label: 'Intervall',
                    wert: daten.intervall,
                    items: {
                      for (final i in ArtefaktIntervall.values)
                        i: artefaktIntervallLabel(i),
                    },
                    onChanged: (v) => _aendere((d) => d.copyWith(intervall: v)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _text(
                    'anwendungen-je-intervall',
                    'Anwendungen je Intervall',
                    _anwendungenProIntervall,
                    (d, t) => d.copyWith(
                      anwendungenProIntervall: (int.tryParse(t.trim()) ?? 1) < 1
                          ? 1
                          : int.tryParse(t.trim()) ?? 1,
                    ),
                    zahl: true,
                    hilfe: 'Nach dem Intervall regenerieren die Matrizen',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    daten.anwendungen.isEmpty
                        ? 'Keine Anwendung vermerkt.'
                        : '${daten.anwendungen.length} Anwendung'
                              '${daten.anwendungen.length == 1 ? '' : 'en'} '
                              'vermerkt.',
                    key: const ValueKey<String>(
                      'inventory-editor-artefakt-anwendungen',
                    ),
                    style: texte.bodySmall,
                  ),
                ),
                if (daten.anwendungen.isNotEmpty)
                  TextButton(
                    key: const ValueKey<String>(
                      'inventory-editor-artefakt-anwendungen-reset',
                    ),
                    onPressed: () => _aendere(
                      (d) => d.copyWith(anwendungen: const <AventurianDate>[]),
                    ),
                    child: const Text('Matrizen regeneriert'),
                  ),
              ],
            ),
          ],
          if (aufladbar) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _text(
                    'aufladungen',
                    'Bisherige Aufladungen',
                    _aufladungen,
                    (d, t) => d.copyWith(aufladungen: int.tryParse(t) ?? 0),
                    zahl: true,
                    hilfe: 'WdA 2012: jede Aufladung erhöht das Schadensrisiko',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _text(
                    'gesamtasp',
                    'Gesamt-AsP der Erschaffung',
                    _gesamtAsp,
                    (d, t) => d.copyWith(
                      gesamtAspErschaffung: int.tryParse(t.trim()),
                    ),
                    zahl: true,
                    hilfe: 'Grenze für die Sprüche beim Aufladen',
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _text(
            'ersteller',
            'Ersteller',
            _ersteller,
            (d, t) => d.copyWith(ersteller: t.trim()),
          ),
          const SizedBox(height: 12),
          _text(
            'ausloeser',
            'Auslöser (Schlüsselwort, Geste …)',
            _ausloeser,
            (d, t) => d.copyWith(ausloeser: t.trim()),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _text(
                  'aktionen',
                  'Aktionen für den Auslöser',
                  _aktionen,
                  (d, t) => d.copyWith(ausloeserAktionen: int.tryParse(t) ?? 1),
                  zahl: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _text(
                  'pasp',
                  'Permanente AsP',
                  _pAsP,
                  (d, t) => d.copyWith(pAsP: int.tryParse(t.trim())),
                  zahl: true,
                  hilfe: artefaktPAspSumme(daten) == null
                      ? null
                      : 'Summe der Zauber: ${artefaktPAspSumme(daten)}',
                ),
              ),
            ],
          ),
          ListTileMaterial(
            child: SwitchListTile.adaptive(
              key: const ValueKey<String>('inventory-editor-artefakt-defekt'),
              value: daten.defekt,
              onChanged: (v) => _aendere((d) => d.copyWith(defekt: v)),
              title: const Text('Irreparabel beschädigt'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 8),
          if (speicher)
            ArtefaktLadungenEditor(
              ladungen: daten.ladungen,
              onChanged: (l) => _aendere((d) => d.copyWith(ladungen: l)),
            )
          else ...[
            Text('Gespeicherte Zauber', style: texte.titleSmall),
            const SizedBox(height: 4),
            if (daten.zauber.isEmpty)
              Text(
                'Noch kein Zauber hinterlegt.',
                style: texte.bodySmall,
                key: const ValueKey<String>('inventory-editor-artefakt-leer'),
              ),
            for (var i = 0; i < daten.zauber.length; i++)
              ArtefaktZauberZeile(
                key: ValueKey<String>('inventory-editor-artefakt-zauber-$i'),
                zauber: daten.zauber[i],
                onAendern: () => _aendereZauber(i),
                onEntfernen: () => _entferneZauber(i),
              ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const ValueKey<String>('inventory-editor-artefakt-add'),
                onPressed: _fuegeZauberHinzu,
                icon: const Icon(Icons.add),
                label: const Text('Zauber hinzufügen'),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _fassungDropdown(ArtefaktDaten daten) => _dropdown<MatrixRegelfassung>(
    schluessel: 'regelfassung',
    label: 'Regelfassung',
    wert: daten.regelfassung,
    items: {
      for (final f in MatrixRegelfassung.values) f: matrixRegelfassungLabel(f),
    },
    onChanged: (v) => _aendere((d) => d.copyWith(regelfassung: v)),
  );
}
