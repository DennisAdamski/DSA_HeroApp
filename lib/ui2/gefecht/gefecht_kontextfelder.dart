import 'package:flutter/material.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';

/// Zeigt nur Eingaben, die für den gewählten Angriffs-/Abwehrweg fehlen.
class GefechtKontextfelder extends StatelessWidget {
  /// Änderungen werden als vollständiger flüchtiger Kontext zurückgemeldet.
  const GefechtKontextfelder({
    super.key,
    required this.kontext,
    required this.aktion,
    required this.onChanged,
    this.gegnerVorgabe,
  });
  final Gefechtskontext kontext;
  final Gefechtsaktion aktion;
  final ValueChanged<Gefechtskontext> onChanged;

  /// Gegnerzahl der Rundenleiste, solange der Angriff keine eigene nennt.
  final int? gegnerVorgabe;
  @override
  Widget build(BuildContext context) {
    final k = kontext;
    final pa =
        aktion == Gefechtsaktion.parade ||
        aktion == Gefechtsaktion.schildparade;
    final aw =
        aktion == Gefechtsaktion.freiesAusweichen ||
        aktion == Gefechtsaktion.gezieltesAusweichen;
    // Kontaktdaten bleiben erhalten, Bestätigungen gelten nur bis zur Änderung.
    void aendern({
      int? gegner,
      int? finte,
      Gefechtsangriffsart? art,
      bool? platz,
    }) => onChanged(
      Gefechtskontext(
        kontakt: k.kontakt,
        gegnerId: k.gegnerId,
        gegnerDk: k.gegnerDk,
        gegnerzahl: gegner ?? k.gegnerzahl,
        finte: finte ?? k.finte,
        angriffsart: art ?? k.angriffsart,
        paradeVerboten: k.paradeVerboten,
        platzZumAusweichen: platz ?? k.platzZumAusweichen,
        sehrGross: k.sehrGross,
        grosserSchild: k.grosserSchild,
        halbschwert: k.halbschwert,
        entfernung: k.entfernung,
        geladen: k.geladen,
        getuemmel: k.getuemmel,
        kontrollbereich: k.kontrollbereich,
        situationsZuschlag: k.situationsZuschlag,
        schildWmWirksam: k.schildWmWirksam,
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (pa || aw) ...[
          DropdownButtonFormField<Gefechtsangriffsart>(
            initialValue: k.angriffsart,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Angriff gegen mich'),
            items: [
              for (final a in Gefechtsangriffsart.values)
                DropdownMenuItem(
                  value: a,
                  child: Text(switch (a) {
                    Gefechtsangriffsart.nahkampf => 'Nahkampf',
                    Gefechtsangriffsart.fernkampf =>
                      'Fernkampf (manuell prüfen)',
                    Gefechtsangriffsart.besonders =>
                      'Sonderangriff (manuell prüfen)',
                  }),
                ),
            ],
            onChanged: (a) => aendern(art: a),
          ),
          TextFormField(
            initialValue: k.finte?.toString(),
            decoration: const InputDecoration(
              labelText: 'Gegnerische Finte (0 erlaubt)',
            ),
            keyboardType: TextInputType.number,
            onChanged: (v) => onChanged(
              Gefechtskontext(
                kontakt: k.kontakt,
                gegnerId: k.gegnerId,
                gegnerzahl: k.gegnerzahl,
                gegnerDk: k.gegnerDk,
                finte: int.tryParse(v),
                angriffsart: k.angriffsart,
                paradeVerboten: k.paradeVerboten,
                platzZumAusweichen: k.platzZumAusweichen,
                halbschwert: k.halbschwert,
                sehrGross: k.sehrGross,
                grosserSchild: k.grosserSchild,
                entfernung: k.entfernung,
                geladen: k.geladen,
                getuemmel: k.getuemmel,
                kontrollbereich: k.kontrollbereich,
                situationsZuschlag: k.situationsZuschlag,
                schildWmWirksam: k.schildWmWirksam,
              ),
            ),
          ),
        ],
        if (aktion == Gefechtsaktion.schildparade)
          _wahl(
            'Schild-WM wirksam? (Nein bei Kettenwaffe/-stab oder Peitsche)',
            k.schildWmWirksam,
            (v) => onChanged(
              k.copyWith(schildWmWirksam: v, weitereRegelnGeprueft: false),
            ),
          ),
        if (aw) ...[
          DropdownButtonFormField<int>(
            initialValue: k.gegnerzahl ?? gegnerVorgabe?.clamp(1, 6),
            decoration: const InputDecoration(
              labelText: 'Relevante Nahkampfgegner',
            ),
            items: [
              for (final n in [1, 2, 3, 4, 5, 6])
                DropdownMenuItem(value: n, child: Text('$n')),
            ],
            onChanged: (v) => aendern(gegner: v),
          ),
          _wahl(
            'Platz zum Ausweichen?',
            k.platzZumAusweichen,
            (v) => aendern(platz: v),
          ),
        ],
      ],
    );
  }

  // Unbekannt ist eine echte dritte Auswahl, keine voreingestellte Zustimmung.
  Widget _wahl(String titel, bool? wert, ValueChanged<bool> aendern) =>
      DropdownButtonFormField<bool>(
        initialValue: wert,
        decoration: InputDecoration(labelText: titel),
        items: const [
          DropdownMenuItem(value: true, child: Text('Ja')),
          DropdownMenuItem(value: false, child: Text('Nein')),
        ],
        onChanged: (v) {
          if (v != null) aendern(v);
        },
      );
}
