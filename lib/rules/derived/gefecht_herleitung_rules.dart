/// Gefechtswerte auf den Herleitungen der Kampfvorschau (ARCH-04, Paket B).
///
/// Das Gefecht rechnet AT, PA, Schild-PA und Ausweichen nicht mehr aus
/// Einzelwerten nach: Es nimmt die Herleitung der Vorschau, ersetzt deren
/// INI-Anteil durch den der Sitzung und erzeugt seine Erklärzeilen aus den
/// Schritten. Das Modul ist blattartig (nur `herleitung.dart`).
library;

import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/kampf_ini_herleitung_rules.dart';

/// Schrittname des Sitzungsanteils, der den INI-Bonus der Vorschau ersetzt.
const String kGefechtsIniBonusSchritt = 'INI-Bonus (Sitzung)';

/// Herleitung aus einer bereits fertigen Zahl, wenn keine Vorschau-Herleitung
/// vorliegt (handgebaute Werte in Tests).
Herleitung herleitungAusWert(String bezeichnung, int wert) => Herleitung(
  bezeichnung: bezeichnung,
  schritte: [
    HerleitungsSchritt(
      bezeichnung: bezeichnung,
      betrag: wert,
      art: HerleitungsArt.grundwert,
      quelle: 'Kampfvorschau',
    ),
  ],
);

/// Neue Herleitung ohne die Schritte namens [bezeichnungen].
Herleitung ohneSchritte(Herleitung h, Set<String> bezeichnungen) => Herleitung(
  bezeichnung: h.bezeichnung,
  schritte: [
    for (final s in h.schritte)
      if (!bezeichnungen.contains(s.bezeichnung)) s,
  ],
);

/// Schritt des Sitzungs-INI-Bonus mit dem Betrag [iniBonus].
HerleitungsSchritt gefechtsIniBonusSchritt(int iniBonus) => HerleitungsSchritt(
  bezeichnung: kGefechtsIniBonusSchritt,
  betrag: iniBonus,
  art: HerleitungsArt.modifikator,
  formel: 'über INI 20 +1, über 30 +2, über 40 +3',
  quelle: 'Gefechts-INI',
);

/// Ausweichen im Gefecht: die Vorschau-Herleitung [vorschau] mit dem
/// Sitzungsanteil [iniBonus] statt ihres INI-Bonus.
///
/// Die Untergrenze der Vorschau fällt weg und wird auf die neue Summe
/// angewendet, damit der Endwert die Summe aller Schritte bleibt.
Herleitung herleiteGefechtsAusweichen(
  Herleitung vorschau, {
  required int iniBonus,
}) {
  final schritte = <HerleitungsSchritt>[];
  var ersetzt = false;
  for (final s in vorschau.schritte) {
    if (s.art == HerleitungsArt.begrenzung) continue;
    if (s.bezeichnung == kAusweichenIniBonusSchritt) {
      schritte.add(gefechtsIniBonusSchritt(iniBonus));
      ersetzt = true;
    } else {
      schritte.add(s);
    }
  }
  if (!ersetzt) schritte.add(gefechtsIniBonusSchritt(iniBonus));
  return Herleitung(
    bezeichnung: 'Ausweichen',
    schritte: mitUntergrenze(
      schritte,
      untergrenze: 0,
      bezeichnung: 'Untergrenze 0',
    ),
  );
}

/// Ausweichen-Zielwert vor Erschwernissen.
///
/// Ohne [herleitung] (handgebaute Gefechtswerte) entsteht sie aus dem Wert
/// ohne INI-Bonus [ausweichen] und der Kampfbehinderung [be].
Herleitung gefechtsAusweichenHerleitung({
  required Herleitung? herleitung,
  required int ausweichen,
  required int be,
  required int iniBonus,
}) {
  if (herleitung != null) {
    return herleiteGefechtsAusweichen(herleitung, iniBonus: iniBonus);
  }
  return Herleitung(
    bezeichnung: 'Ausweichen',
    schritte: mitUntergrenze(
      [
        HerleitungsSchritt(
          bezeichnung: 'Ausweichen',
          betrag: ausweichen,
          art: HerleitungsArt.grundwert,
          quelle: 'Kampfvorschau',
        ),
        gefechtsIniBonusSchritt(iniBonus),
        HerleitungsSchritt(
          bezeichnung: 'BE Kampf',
          betrag: -be,
          art: HerleitungsArt.modifikator,
          quelle: 'Rüstung',
        ),
      ],
      untergrenze: 0,
      bezeichnung: 'Untergrenze 0',
    ),
  );
}

/// Ausweichen der Vorschau ohne jeden INI-Bonus (mit Untergrenze 0); ohne
/// Herleitung gilt [rueckfall].
int ausweichenOhneIniBonus(Herleitung? vorschau, {required int rueckfall}) =>
    vorschau == null
    ? rueckfall
    : herleiteGefechtsAusweichen(vorschau, iniBonus: 0).wert;

String _schrittText(HerleitungsSchritt s) {
  if (s.art == HerleitungsArt.grundwert) return '${s.bezeichnung} ${s.betrag}';
  return '${s.bezeichnung} ${s.betrag >= 0 ? '+' : '−'}${s.betrag.abs()}';
}

/// Erklärzeile „[titel]: Wert (Schritt, Schritt, …)“ aus den sichtbaren
/// Schritten von [h]; nichts außer der Herleitung wird formuliert.
String herleitungsZeile(String titel, Herleitung h) {
  final schritte = h.sichtbareSchritte.map(_schrittText).join(', ');
  return schritte.isEmpty
      ? '$titel: ${h.wert}'
      : '$titel: ${h.wert} ($schritte)';
}
