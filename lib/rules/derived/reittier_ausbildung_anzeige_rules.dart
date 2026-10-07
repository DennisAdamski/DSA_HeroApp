/// Anzeigetexte zur Reittier-Ausbildung (ZBA S. 32–37).
///
/// Getrennt von `reittier_ausbildung_rules.dart`, damit die Rechenregeln
/// frei von Formatierung bleiben; Widgets setzen keine Werte selbst
/// zusammen.
library;

import 'package:dsa_heldenverwaltung/catalog/reittier_ausbildung_katalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion/reittier_ausbildungsstufe.dart';

import 'begleiter_kampfprofil_rules.dart';

/// Wert mit Vorzeichen und typografischem Minus („+3“, „−1“, „±0“).
String mitVorzeichen(int wert) => switch (wert) {
  > 0 => '+$wert',
  < 0 => '−${-wert}',
  _ => '±0',
};

/// Kurztext aller Änderungen, z. B. „LO +4 · AT +1 · TP (Tritt) +1“;
/// leer, wenn nichts geändert wird.
String reittierModifikationenText(ReittierModifikationen m) {
  final teile = <String>[
    if (m.lo != 0) 'LO ${mitVorzeichen(m.lo)}',
    if (m.kk != 0) 'KK ${mitVorzeichen(m.kk)}',
    if (m.at != 0) 'AT ${mitVorzeichen(m.at)}',
    if (m.tpTritt != 0) 'TP (Tritt) ${mitVorzeichen(m.tpTritt)}',
    if (m.gsTrab != 0 || m.gsGalopp != 0)
      'GS Trab ${mitVorzeichen(m.gsTrab)} / Galopp ${mitVorzeichen(m.gsGalopp)}',
    if (m.auTrab != 0 || m.auGalopp != 0)
      'AU Trab ${mitVorzeichen(m.auTrab)} / Galopp ${mitVorzeichen(m.auGalopp)}',
    if (m.tkFaktor != 0) 'TK ${mitVorzeichen(m.tkFaktor)}×KK',
    if (m.zkFaktor != 0) 'ZK ${mitVorzeichen(m.zkFaktor)}×KK',
  ];
  return teile.join(' · ');
}

/// Text einer geforderten Ausbilderprobe, z. B. „2× Reiten +3 (Zugtiere:
/// Fahrzeug Lenken)“.
String reittierProbeText(ReittierProbeDef probe) {
  final erschwernis = probe.erschwernis == 0
      ? ''
      : ' ${mitVorzeichen(probe.erschwernis)}';
  final alternative = probe.alternativeTalentName == null
      ? ''
      : ' (Zugtiere: ${probe.alternativeTalentName})';
  return '${probe.anzahl}× ${probe.talentName}$erschwernis$alternative';
}

/// Bezeichnung eines Schritts, z. B. „→ geschult (fundiert)“.
String reittierSchrittText(
  ReittierAusbildungsstufe nach,
  ReittierAusbildungsart art,
) => '→ ${nach.label} (${art.label})';

/// Zahl der Unarten, die [fehlschlaege] misslungene Ausbilderproben nach
/// sich ziehen (ZBA S. 34): ländlich jede, fundiert je drei.
int faelligeUnarten(ReittierAusbildungsart art, int fehlschlaege) =>
    art == ReittierAusbildungsart.laendlich ? fehlschlaege : fehlschlaege ~/ 3;

/// Zeile zum Ausbildungsstand im Gefecht, z. B. „Ausbildung: geschult
/// (fundiert), Leichtes Streitross, Kampfpferd · Reiten −2 / im Kampf −3“.
String reittierProfilText(ReittierProfil r) {
  final stand = <String>[
    '${r.stufe} (${r.art})',
    if (r.variante.isNotEmpty) r.variante,
    if (r.kampfpferd) 'Kampfpferd',
  ].join(', ');
  final reiter = r.reiterKampfErschwernis == 0
      ? ''
      : ' · Reiter-AT/PA ${mitVorzeichen(r.reiterKampfErschwernis)}';
  return 'Ausbildung: $stand · Reiten ${mitVorzeichen(r.reitenNormal)} / '
      'im Kampf ${mitVorzeichen(r.reitenImKampf)}$reiter';
}
