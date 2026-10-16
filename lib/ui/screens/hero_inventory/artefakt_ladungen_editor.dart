import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory/artefakt_zauber_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory/artefakt_zauber_zeile.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/list_tile_material.dart';

/// Bearbeitet die Ladungen eines Spruchspeichers.
///
/// Jede Ladung ist eine unabhängig auslösbare Anwendung aus einem oder
/// mehreren Zaubern, die gemeinsam ausgelöst werden. Der Editor hält keinen
/// Entwurf, sondern meldet jede Änderung über [onChanged]. [keyPraefix]
/// bildet die Widget-Schlüssel (`<keyPraefix>-ladung-<i>` …).
class ArtefaktLadungenEditor extends StatelessWidget {
  /// Erstellt den Editor für [ladungen].
  const ArtefaktLadungenEditor({
    super.key,
    required this.ladungen,
    required this.onChanged,
    this.keyPraefix = 'inventory-editor-artefakt',
    this.zeigeVerbraucht = true,
  });

  /// Die aktuellen Ladungen des Entwurfs.
  final List<ArtefaktLadung> ladungen;

  /// Meldet die neue Ladungsliste.
  final ValueChanged<List<ArtefaktLadung>> onChanged;

  /// Präfix der Widget-Schlüssel.
  final String keyPraefix;

  /// Ob der Schalter „Verbraucht“ je Ladung erscheint (nicht beim Aufladen).
  final bool zeigeVerbraucht;

  void _ersetze(int index, ArtefaktLadung neu) {
    final liste = [...ladungen];
    liste[index] = neu;
    onChanged(liste);
  }

  Future<void> _fuegeZauberHinzu(BuildContext context, int index) async {
    final zauber = await zeigeArtefaktZauberDialog(context);
    if (zauber == null || !context.mounted) return;
    final ladung = ladungen[index];
    _ersetze(index, ladung.copyWith(zauber: [...ladung.zauber, zauber]));
  }

  Future<void> _aendereZauber(BuildContext context, int index, int z) async {
    final ladung = ladungen[index];
    final neu = await zeigeArtefaktZauberDialog(
      context,
      start: ladung.zauber[z],
    );
    if (neu == null || !context.mounted) return;
    final liste = [...ladung.zauber];
    liste[z] = neu;
    _ersetze(index, ladung.copyWith(zauber: liste));
  }

  void _entferneZauber(int index, int z) {
    final ladung = ladungen[index];
    _ersetze(index, ladung.copyWith(zauber: [...ladung.zauber]..removeAt(z)));
  }

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ladungen', style: texte.titleSmall),
        const SizedBox(height: 4),
        if (ladungen.isEmpty)
          Text(
            'Noch keine Ladung hinterlegt.',
            style: texte.bodySmall,
            key: ValueKey<String>('$keyPraefix-ladungen-leer'),
          ),
        for (var i = 0; i < ladungen.length; i++)
          Card(
            key: ValueKey<String>('$keyPraefix-ladung-$i'),
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Ladung ${i + 1}', style: texte.titleSmall),
                      ),
                      IconButton(
                        key: ValueKey<String>(
                          '$keyPraefix-ladung-$i-entfernen',
                        ),
                        tooltip: 'Ladung entfernen',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => onChanged([...ladungen]..removeAt(i)),
                      ),
                    ],
                  ),
                  if (zeigeVerbraucht)
                    ListTileMaterial(
                      child: SwitchListTile.adaptive(
                        key: ValueKey<String>(
                          '$keyPraefix-ladung-$i-verbraucht',
                        ),
                        value: ladungen[i].verbraucht,
                        onChanged: (v) =>
                            _ersetze(i, ladungen[i].copyWith(verbraucht: v)),
                        title: const Text('Verbraucht'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  if (ladungen[i].zauber.isEmpty)
                    Text('Noch kein Zauber.', style: texte.bodySmall),
                  for (var z = 0; z < ladungen[i].zauber.length; z++)
                    ArtefaktZauberZeile(
                      key: ValueKey<String>('$keyPraefix-ladung-$i-zauber-$z'),
                      zauber: ladungen[i].zauber[z],
                      onAendern: () => _aendereZauber(context, i, z),
                      onEntfernen: () => _entferneZauber(i, z),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: ValueKey<String>('$keyPraefix-ladung-$i-add'),
                      onPressed: () => _fuegeZauberHinzu(context, i),
                      icon: const Icon(Icons.add),
                      label: const Text('Zauber hinzufügen'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: ValueKey<String>('$keyPraefix-ladung-add'),
            onPressed: () =>
                onChanged([...ladungen, ArtefaktLadung(id: const Uuid().v4())]),
            icon: const Icon(Icons.add),
            label: const Text('Ladung hinzufügen'),
          ),
        ),
      ],
    );
  }
}
