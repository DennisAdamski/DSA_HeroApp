/// AP-Kosten einer Steigerung als Herleitung (ARCH-04).
///
/// Die Kette „Grundkosten der Spalte → Sondererfahrung → epischer Aufschlag
/// → Lehrmeister“ stand bisher im Steigerungsdialog selbst. Hier steht sie
/// als Regel: Die Schritte ergeben genau die tatsächlich gebuchten AP, die
/// Oberfläche liest sie nur ab.
library;

import 'package:dsa_heldenverwaltung/domain/learn/learn_complexity.dart';
import 'package:dsa_heldenverwaltung/domain/learn/learn_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/epic_ap_cost_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';

/// Bezeichnung der Grundkosten.
const String kSteigerungGrundkostenSchritt = 'Grundkosten';

/// Bezeichnung des Sondererfahrungs-Nachlasses.
const String kSteigerungSeSchritt = 'Sondererfahrung';

/// Bezeichnung des epischen Aufschlags.
const String kSteigerungEposSchritt = 'Epischer Aufschlag (+25 %)';

/// Bezeichnung des Lehrmeister-Nachlasses.
const String kSteigerungLehrmeisterSchritt = 'Lehrmeister (−20 %)';

/// Kosten einer Steigerung samt Herleitung.
class Steigerungskosten {
  /// Hält die [herleitung] und die verbrauchten Sondererfahrungen.
  const Steigerungskosten({
    required this.herleitung,
    required this.seVerbraucht,
    required this.kostenVorAufschlag,
    required this.kostenNachAufschlag,
  });

  /// Schritte bis zu den tatsächlichen AP.
  final Herleitung herleitung;

  /// Anzahl der Schritte, die eine Sondererfahrung verbilligt hat.
  final int seVerbraucht;

  /// Kosten nach Sondererfahrung, vor epischem Aufschlag und Lehrmeister.
  final int kostenVorAufschlag;

  /// Kosten nach epischem Aufschlag, vor einem Lehrmeister-Nachlass.
  final int kostenNachAufschlag;

  /// Tatsächlich gebuchte AP.
  int get apKosten => herleitung.wert;

  /// Betrag des epischen Aufschlags (0, wenn er nicht greift).
  int get aufschlag => kostenNachAufschlag - kostenVorAufschlag;
}

/// Kosten für die Steigerung von [vonWert] auf [aufWert] in Spalte
/// [komplexitaet].
///
/// `vonWert < 0` steht für die Aktivierung. [seAnzahl] Sondererfahrungen
/// verbilligen die ersten Schritte um eine Spalte. Der epische Aufschlag
/// gilt nur für [episch]e Helden und nicht für [istHaupteigenschaft]; ein
/// [mitLehrmeister] hebt ihn auf und senkt die Kosten um 20 %.
Steigerungskosten herleiteSteigerungskosten({
  required int vonWert,
  required int aufWert,
  required LearnCost komplexitaet,
  int seAnzahl = 0,
  bool episch = false,
  bool istHaupteigenschaft = false,
  bool mitLehrmeister = false,
  bool epicRuleActive = true,
}) {
  final ohneSe = berechneSteigerungskosten(
    vonWert: vonWert,
    aufWert: aufWert,
    effektiveKomplexitaet: komplexitaet,
  );
  final mitSe = berechneSteigerungskosten(
    vonWert: vonWert,
    aufWert: aufWert,
    effektiveKomplexitaet: komplexitaet,
    seAnzahl: seAnzahl,
  );
  final vorAufschlag = mitSe.apKosten;
  final nachAufschlag = applyEpicApSurcharge(
    vorAufschlag,
    ruleActive: epicRuleActive,
    isEpisch: episch,
    isMainAttribute: istHaupteigenschaft,
    lehrmeisterHebtAuf: mitLehrmeister,
  );
  final nachLehrmeister = mitLehrmeister
      ? apMitLehrmeister(nachAufschlag)
      : nachAufschlag;
  final spalte = komplexitaetLabel(komplexitaet);
  final von = vonWert < 0 ? 'Aktivierung' : '$vonWert';
  return Steigerungskosten(
    seVerbraucht: mitSe.seVerbraucht,
    kostenVorAufschlag: vorAufschlag,
    kostenNachAufschlag: nachAufschlag,
    herleitung: Herleitung(
      bezeichnung: 'AP-Kosten',
      schritte: <HerleitungsSchritt>[
        HerleitungsSchritt(
          bezeichnung: kSteigerungGrundkostenSchritt,
          betrag: ohneSe.apKosten,
          art: HerleitungsArt.grundwert,
          formel: 'Spalte $spalte, $von → $aufWert',
        ),
        HerleitungsSchritt(
          bezeichnung: kSteigerungSeSchritt,
          betrag: vorAufschlag - ohneSe.apKosten,
          art: HerleitungsArt.modifikator,
          formel: mitSe.seVerbraucht == 0
              ? null
              : '${mitSe.seVerbraucht} '
                    '${mitSe.seVerbraucht == 1 ? 'Schritt' : 'Schritte'} '
                    'in Spalte ${komplexitaetLabel(komplexitaet.previous())}',
          quelle: 'Sondererfahrung',
        ),
        HerleitungsSchritt(
          bezeichnung: kSteigerungEposSchritt,
          betrag: nachAufschlag - vorAufschlag,
          art: HerleitungsArt.modifikator,
          quelle: 'Epische Stufen',
          bedingung:
              'Held ist episch, keine Haupteigenschaft, kein Lehrmeister',
        ),
        HerleitungsSchritt(
          bezeichnung: kSteigerungLehrmeisterSchritt,
          betrag: nachLehrmeister - nachAufschlag,
          art: HerleitungsArt.modifikator,
          quelle: 'Lehrmeister',
          bedingung: 'Lehrmeister mit TaW ≥ 15',
        ),
      ],
    ),
  );
}
