import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reise_station.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reiseroute_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_stroke.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

/// Die Reiseroute als Tabelle: wann der Held wo war und zu welchem Abenteuer.
///
/// Spalten sind Nummer, Datum, Ort, Abenteuer und Notiz, die Zeilen stehen in
/// der gegebenen (zeitlichen) Reihenfolge. Unter dem Datum steht der Abstand
/// zur vorigen Station. Unter [breiteMitNotizspalte] oder bei stark
/// vergrößerter Schrift entfällt die Notizspalte; die Notiz steht dann
/// gekürzt unter dem Ort.
class KartoReiseTabelle extends StatelessWidget {
  /// Tabelle der [etappen]; [abenteuer] liefert die Titel der Zuordnung.
  const KartoReiseTabelle({
    super.key,
    required this.etappen,
    required this.abenteuer,
    this.onStation,
  });

  /// Darzustellende Etappen, bereits zeitlich geordnet.
  final List<ReiseEtappe> etappen;

  /// Abenteuer des Helden für die Spalte „Abenteuer“.
  final List<HeroAdventureEntry> abenteuer;

  /// Öffnet die Bearbeitung; `null` zeigt nur an.
  final ValueChanged<HeroReiseStation>? onStation;

  /// Breite, ab der die Notiz eine eigene Spalte bekommt.
  static const double breiteMitNotizspalte = 520;

  /// Schriftgröße, bis zu der die Notizspalte gilt.
  static const double schriftMitNotizspalte = 1.3;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final breit =
            constraints.maxWidth >= breiteMitNotizspalte &&
            MediaQuery.textScalerOf(context).scale(1) <= schriftMitNotizspalte;
        final karto = context.karto;
        return Column(
          key: const ValueKey<String>('karto-reise-tabelle'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Zeile(
              breit: breit,
              kopf: true,
              nummer: '#',
              datum: 'Datum',
              ort: 'Ort',
              abenteuer: 'Abenteuer',
              notiz: 'Notiz',
            ),
            Container(height: Strich.grat, color: karto.grat),
            for (final etappe in etappen) ...[
              _Zeile(
                key: ValueKey<String>('karto-reise-zeile-${etappe.station.id}'),
                breit: breit,
                nummer: '${etappe.nummer}',
                datum: reiseStationDatumText(etappe.station) ?? '—',
                abstand: etappe.nummer == 1
                    ? null
                    : reiseEtappenAbstandText(etappe),
                ort: etappe.station.ort.trim(),
                abenteuer:
                    reiseStationAbenteuerTitel(etappe.station, abenteuer) ??
                    '—',
                notiz: etappe.station.notiz.trim(),
                onTap: onStation == null
                    ? null
                    : () => onStation!(etappe.station),
              ),
              Container(height: Strich.hoehenlinie, color: karto.hoehenlinie),
            ],
          ],
        );
      },
    );
  }
}

class _Zeile extends StatelessWidget {
  const _Zeile({
    super.key,
    required this.breit,
    required this.nummer,
    required this.datum,
    required this.ort,
    required this.abenteuer,
    required this.notiz,
    this.abstand,
    this.kopf = false,
    this.onTap,
  });

  final bool breit;
  final bool kopf;
  final String nummer;
  final String datum;
  final String? abstand;
  final String ort;
  final String abenteuer;
  final String notiz;
  final VoidCallback? onTap;

  static const double _nummerBreite = 28;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    final kopfStil = texte.etikett.copyWith(color: karto.schriftLeise);
    final leise = texte.fliess.copyWith(color: karto.schriftLeise);

    Widget zelle(int flex, Widget kind) => Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.only(right: Abstand.weit),
        child: kind,
      ),
    );

    final zeile = Padding(
      padding: const EdgeInsets.symmetric(vertical: Abstand.normal),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _nummerBreite,
            child: Text(
              nummer,
              style: kopf
                  ? kopfStil
                  : texte.marke.copyWith(color: karto.schriftStumm),
            ),
          ),
          zelle(
            3,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(datum, style: kopf ? kopfStil : texte.fliess),
                if (abstand != null)
                  Text(
                    abstand!,
                    style: texte.marke.copyWith(color: karto.schriftStumm),
                  ),
              ],
            ),
          ),
          zelle(
            breit ? 3 : 4,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (kopf)
                  Text(ort, style: kopfStil)
                else
                  Text(
                    ort.isEmpty ? 'Unbekannter Ort' : ort,
                    style: ort.isEmpty
                        ? leise
                        : texte.fliess.copyWith(fontWeight: FontWeight.w600),
                  ),
                if (!kopf && !breit && notiz.isNotEmpty)
                  Text(
                    notiz,
                    style: texte.legende.copyWith(color: karto.schriftLeise),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          zelle(3, Text(abenteuer, style: kopf ? kopfStil : texte.fliess)),
          if (breit)
            zelle(5, Text(notiz, style: kopf ? kopfStil : texte.fliess)),
        ],
      ),
    );
    if (kopf) return zeile;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kKartoRadiusKlein),
        child: zeile,
      ),
    );
  }
}
