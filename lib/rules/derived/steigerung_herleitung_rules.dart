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
import 'package:dsa_heldenverwaltung/rules/derived/lernkosten_faktor_rules.dart';

/// Bezeichnung der Grundkosten.
const String kSteigerungGrundkostenSchritt = 'Grundkosten';

/// Bezeichnung des Sondererfahrungs-Nachlasses.
const String kSteigerungSeSchritt = 'Sondererfahrung';

/// Bezeichnung der Hexalogie-Erleichterung.
const String kSteigerungHexalogieSchritt = 'Hexalogie';

/// Bezeichnung des epischen Aufschlags.
const String kSteigerungEposSchritt = 'Epischer Aufschlag (+25 %)';

/// Bezeichnung des Lehrmeister-Nachlasses.
const String kSteigerungLehrmeisterSchritt = 'Lehrmeister (−20 %)';

/// Regeln, die die Kosten eines Lernziels über die Spalte hinaus bestimmen.
class Lernregeln {
  /// Bündelt Hexalogie-Erleichterung, Kostenfaktoren und Erklärungen.
  const Lernregeln({
    this.erleichterungBisWert,
    this.faktoren = const <LernkostenFaktor>[],
    this.spaltenHerleitung,
    this.hinweise = const <String>[],
  });

  /// Ohne besondere Regeln.
  static const Lernregeln keine = Lernregeln();

  /// Bis zu diesem Zielwert ist jeder Schritt eine weitere Spalte billiger
  /// (Hexalogie).
  final int? erleichterungBisWert;

  /// Kostenfaktoren aus Vorteilen (Gutes/Eidetisches Gedächtnis).
  final List<LernkostenFaktor> faktoren;

  /// Herleitung der Lernspalte in Spalten, falls das Lernziel eine kennt.
  final Herleitung? spaltenHerleitung;

  /// Weitere Erklärungen für die Anzeige (etwa zur Hexalogie).
  final List<String> hinweise;
}

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
  Lernregeln regeln = Lernregeln.keine,
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
  final mitHexalogie = berechneSteigerungskosten(
    vonWert: vonWert,
    aufWert: aufWert,
    effektiveKomplexitaet: komplexitaet,
    seAnzahl: seAnzahl,
    erleichterungBisWert: regeln.erleichterungBisWert,
  );
  // Faktoren (Gedächtnis) wirken auf die Kosten nach allen Spaltenregeln.
  final faktorSchritte = <HerleitungsSchritt>[];
  var kosten = mitHexalogie.apKosten;
  for (final faktor in regeln.faktoren) {
    final danach = faktor.wende(kosten);
    faktorSchritte.add(
      HerleitungsSchritt(
        bezeichnung: faktor.bezeichnung,
        betrag: danach - kosten,
        art: HerleitungsArt.modifikator,
        quelle: faktor.quelle,
        formel: '${faktor.zaehler}/${faktor.nenner} von $kosten AP',
      ),
    );
    kosten = danach;
  }
  final vorAufschlag = kosten;
  final nachAufschlag = applyEpicApSurcharge(
    vorAufschlag,
    ruleActive: epicRuleActive,
    isEpisch: episch,
    isMainAttribute: istHaupteigenschaft,
    lehrmeisterHebtAuf: mitLehrmeister,
  );
  final aufschlagAufgehoben =
      mitLehrmeister &&
      applyEpicApSurcharge(
            vorAufschlag,
            ruleActive: epicRuleActive,
            isEpisch: episch,
            isMainAttribute: istHaupteigenschaft,
          ) >
          nachAufschlag;
  final nachLehrmeister = lehrmeisterNachlassNachAufschlag(
    nachAufschlag,
    mitLehrmeister: mitLehrmeister,
    aufschlagAufgehoben: aufschlagAufgehoben,
  );
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
          betrag: mitSe.apKosten - ohneSe.apKosten,
          art: HerleitungsArt.modifikator,
          formel: mitSe.seVerbraucht == 0
              ? null
              : '${mitSe.seVerbraucht} '
                    '${mitSe.seVerbraucht == 1 ? 'Schritt' : 'Schritte'} '
                    'in Spalte ${komplexitaetLabel(komplexitaet.previous())}',
          quelle: 'Sondererfahrung',
        ),
        HerleitungsSchritt(
          bezeichnung: kSteigerungHexalogieSchritt,
          betrag: mitHexalogie.apKosten - mitSe.apKosten,
          art: HerleitungsArt.modifikator,
          formel: regeln.erleichterungBisWert == null
              ? null
              : 'eine Spalte leichter bis ZfW ${regeln.erleichterungBisWert}',
          quelle: 'Hexalogie',
        ),
        ...faktorSchritte,
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
