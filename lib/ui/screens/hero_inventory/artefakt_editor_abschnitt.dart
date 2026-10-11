import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/matrix_ausloesen.dart';
import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory/artefakt_zauber_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/list_tile_material.dart';

/// Abschnitt „Artefakt“ im Inventareditor.
///
/// Erfasst die Daten eines Matrixgebers: Stabilität und Regelfassung, die
/// eingesprochenen Zauber mit den Werten ihres Sprechers sowie Ersteller und
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

  @override
  void dispose() {
    _ersteller.dispose();
    _ausloeser.dispose();
    _aktionen.dispose();
    _pAsP.dispose();
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
  }) => TextField(
    key: ValueKey<String>('inventory-editor-artefakt-$schluessel'),
    controller: controller,
    keyboardType: zahl ? TextInputType.number : null,
    onChanged: (t) => _aendere((d) => schreibe(d, t)),
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final daten = widget.daten;
    final texte = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTileMaterial(
          child: SwitchListTile.adaptive(
            key: const ValueKey<String>('inventory-editor-artefakt'),
            value: daten != null,
            onChanged: _schalte,
            title: const Text('Matrixgeber'),
            subtitle: const Text(
              'Ein zauberkundiger Träger löst die gespeicherten Zauber aus, '
              'ohne sie selbst zu beherrschen.',
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (daten != null) ...[
          const SizedBox(height: 12),
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
                  onChanged: (v) => _aendere((d) => d.copyWith(stabilitaet: v)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _dropdown<MatrixRegelfassung>(
                  schluessel: 'regelfassung',
                  label: 'Regelfassung',
                  wert: daten.regelfassung,
                  items: {
                    for (final f in MatrixRegelfassung.values)
                      f: matrixRegelfassungLabel(f),
                  },
                  onChanged: (v) =>
                      _aendere((d) => d.copyWith(regelfassung: v)),
                ),
              ),
            ],
          ),
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
          Text('Gespeicherte Zauber', style: texte.titleSmall),
          const SizedBox(height: 4),
          if (daten.zauber.isEmpty)
            Text(
              'Noch kein Zauber hinterlegt.',
              style: texte.bodySmall,
              key: const ValueKey<String>('inventory-editor-artefakt-leer'),
            ),
          for (var i = 0; i < daten.zauber.length; i++)
            _ZauberZeile(
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
    );
  }
}

class _ZauberZeile extends StatelessWidget {
  const _ZauberZeile({
    super.key,
    required this.zauber,
    required this.onAendern,
    required this.onEntfernen,
  });

  final ArtefaktZauber zauber;
  final VoidCallback onAendern;
  final VoidCallback onEntfernen;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (zauber.repraesentation.isNotEmpty) zauber.repraesentation,
      if (zauber.variante.isNotEmpty) 'Variante: ${zauber.variante}',
      if (zauber.zfw != null) 'ZfW ${zauber.zfw}',
      if (zauber.zfpStern != null) 'ZfP* ${zauber.zfpStern}',
      if (zauber.kostenAsp != null) '${zauber.kostenAsp} AsP',
    ].join(' · ');
    return ListTileMaterial(
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(zauber.name.isEmpty ? 'Unbenannt' : zauber.name),
        subtitle: details.isEmpty ? null : Text(details),
        onTap: onAendern,
        trailing: IconButton(
          tooltip: 'Zauber entfernen',
          icon: const Icon(Icons.delete_outline),
          onPressed: onEntfernen,
        ),
      ),
    );
  }
}
