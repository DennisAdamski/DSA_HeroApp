import 'package:flutter/material.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';

/// Fragt aktuelle Schussdaten ab, ohne ein fehlendes Waffenprofil zu erfinden.
class GefechtFernkampffelder extends StatelessWidget {
  /// Werte leben nur im Gefecht und werden vor jedem Schuss erneut bestätigt.
  const GefechtFernkampffelder({
    super.key,
    required this.kontext,
    required this.onChanged,
  });
  final Gefechtskontext kontext;
  final ValueChanged<Gefechtskontext> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      TextFormField(
        initialValue: kontext.entfernung?.toString(),
        decoration: const InputDecoration(labelText: 'Entfernung in Schritt'),
        keyboardType: TextInputType.number,
        onChanged: (v) => onChanged(
          kontext.copyWith(
            entfernung: int.tryParse(v),
            ohneEntfernung: int.tryParse(v) == null,
          ),
        ),
      ),
      TextFormField(
        initialValue: kontext.situationsZuschlag?.toString(),
        decoration: const InputDecoration(
          labelText: 'Zielgröße, Bewegung, Sicht/Deckung: Zuschlag (0 möglich)',
        ),
        keyboardType: const TextInputType.numberWithOptions(signed: true),
        onChanged: (v) => onChanged(
          kontext.copyWith(
            situationsZuschlag: int.tryParse(v),
            ohneSituationsZuschlag: int.tryParse(v) == null,
          ),
        ),
      ),
      DropdownButtonFormField<bool>(
        initialValue: kontext.geladen,
        decoration: const InputDecoration(
          labelText: 'Waffe geladen / wurfbereit?',
        ),
        items: const [
          DropdownMenuItem(value: true, child: Text('Ja')),
          DropdownMenuItem(value: false, child: Text('Nein')),
        ],
        onChanged: (v) => onChanged(kontext.copyWith(geladen: v)),
      ),
      CheckboxListTile(
        value: kontext.getuemmel,
        title: const Text('Schuss ins Kampfgetümmel'),
        onChanged: (v) => onChanged(kontext.copyWith(getuemmel: v)),
      ),
      if (kontext.getuemmel)
        const Text(
          'Verbündetenrisiko bei 17–19 am Spieltisch prüfen; halbe IN kann Fehlschuss verhindern (Hausregel).',
        ),
      CheckboxListTile(
        value: kontext.kontrollbereich,
        title: const Text('Im Kontrollbereich eines Gegners'),
        onChanged: (v) => onChanged(kontext.copyWith(kontrollbereich: v)),
      ),
      if (kontext.kontrollbereich)
        const Text(
          'Passierschlag beachten; bei höherer Gegner-INI kann er regulär angreifen (Hausregel).',
        ),
    ],
  );
}
