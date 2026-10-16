/// Zielwert und Erschwernis einer Gefechtsprüfung als [Herleitung]en
/// (ARCH-04, Paket C).
///
/// `pruefeGefechtsaktion` und die Ergänzungen der Ansagen, Zielen,
/// Meisterparade und Ansagefolge halten jede Erschwernis benannt in
/// `Gefechtspruefung.modifikatoren` und den Zielwert vor Erschwernis in
/// `zielHerleitung`. Dieses Modul macht daraus die angezeigten Herleitungen;
/// beide rechnen nichts neu, ihre Summen sind die Werte der Prüfung.
library;

import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_herleitung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';

/// Namen der Erschwernisse, die `pruefeGefechtsaktion` selbst setzt.
const String kGefechtsNachBewegen = 'Nach Bewegen';
const String kGefechtsDistanzwechsel = 'Distanzklassenwechsel';
const String kGefechtsZweiteAttacke = 'Zweite Attacke (Umwandlung)';
const String kGefechtsZweiteParade = 'Zweite Parade (Umwandlung)';
const String kGefechtsGezieltesAusweichen = 'Gezieltes Ausweichen (DK)';
const String kGefechtsWeitereGegner = 'Weitere Gegner';
const String kGefechtsUeberzahl = 'Überzahl';

// Rechenweg der bekannten Erschwernisse; unbekannte Namen zeigen keinen.
const Map<String, String> _formeln = {
  kGefechtsNachBewegen:
      'Bewegen erschwert Kampfaktionen derselben Runde (WdS S. 55)',
  kGefechtsDistanzwechsel: '1 DK entfernen +4, 2 DK +8, 2 DK annähern +8',
  kGefechtsZweiteAttacke: 'Zweite AT durch Umwandlung +4, mit Stabumwandlung 0',
  kGefechtsZweiteParade:
      'Zweite PA durch Umwandlung +4, mit Schild, Stabumwandlung oder '
      'Defensivem Kampfstil 0',
  kGefechtsGezieltesAusweichen: 'H +8, N +4, S +2',
  kGefechtsWeitereGegner:
      'PA-Basis +1 je weiterem Gegner, Ausweichen zusätzlich +1; höchstens '
      'drei Gegner im Blick (WdS S. 81)',
  kGefechtsUeberzahl:
      '1 leichter, wenn mindestens zwei von euch dasselbe Ziel angreifen '
      '(WdS S. 81)',
  'Ausweich-DK': 'H +4, N +2, S +1',
  'Distanzklasse': 'Waffe in der falschen DK +6',
  'Schild-WM entfällt': 'Schild-WM gegen Kettenwaffe oder Peitsche entfällt',
};

/// Grundwert eines Zielwerts: [vorschau] (Herleitung der Kampfvorschau), wenn
/// sie [wert] ergibt, sonst eine Zahl [wert] unter [name]; ein [manuell]
/// bestätigter Wert ersetzt beides. [iniBonus] wird als Sitzungsanteil
/// angehängt.
Herleitung gefechtsGrundwert({
  int? manuell,
  Herleitung? vorschau,
  required int wert,
  required String name,
  int iniBonus = 0,
}) {
  final Herleitung basis;
  if (manuell != null) {
    basis = Herleitung(
      bezeichnung: name,
      schritte: [
        HerleitungsSchritt(
          bezeichnung: 'Manuell bestätigter Grundzielwert',
          betrag: manuell,
          art: HerleitungsArt.grundwert,
        ),
      ],
    );
  } else if (vorschau != null && vorschau.wert == wert) {
    basis = vorschau;
  } else {
    basis = herleitungAusWert(name, wert);
  }
  if (iniBonus == 0) return basis;
  return Herleitung(
    bezeichnung: basis.bezeichnung,
    schritte: [...basis.schritte, gefechtsIniBonusSchritt(iniBonus)],
  );
}

/// Zielwert der Prüfung [p]: Grundwert mit INI-Bonus der Sitzung, dann die
/// gesamte Erschwernis. `null` ohne Zielwert oder ohne Herleitung des
/// Grundwerts (manuelle und sonstige Handlungen).
Herleitung? herleiteGefechtsZielwert(Gefechtspruefung p) {
  final grund = p.zielHerleitung;
  final ziel = p.zielwert;
  if (grund == null || ziel == null) return null;
  final herleitung = Herleitung(
    bezeichnung: 'Zielwert',
    schritte: [
      ...grund.schritte,
      HerleitungsSchritt(
        bezeichnung: 'Erschwernis',
        betrag: -p.erschwernis,
        art: HerleitungsArt.modifikator,
        formel: 'Summe der Erschwernisse',
      ),
    ],
  );
  return herleitung.wert == ziel ? herleitung : null;
}

/// Erschwernis der Prüfung [p] aus ihren benannten Anteilen; `null`, wenn sie
/// keine hat oder ihre Summe von [Gefechtspruefung.erschwernis] abweicht.
Herleitung? herleiteGefechtsErschwernis(Gefechtspruefung p) {
  if (p.modifikatoren.isEmpty) return null;
  final herleitung = Herleitung(
    bezeichnung: 'Erschwernis',
    schritte: [
      for (final m in p.modifikatoren)
        HerleitungsSchritt(
          bezeichnung: m.name,
          betrag: m.wert,
          art: HerleitungsArt.modifikator,
          formel: _formeln[m.name],
        ),
    ],
  );
  return herleitung.wert == p.erschwernis ? herleitung : null;
}
