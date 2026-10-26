/// AP-Kosten eines Einmalerwerbs als Herleitung (ARCH-04).
///
/// Der Erwerbsdialog (Sonderfertigkeit, Manöver, nachträglicher Vor-/Nachteil)
/// und der Nachteilsabbau rechneten „Kosten → epischer Aufschlag →
/// Lehrmeister“ bisher selbst. Hier steht die Kette als Regel: Die Schritte
/// ergeben genau die gebuchten AP, die Oberfläche liest sie nur ab.
library;

import 'package:dsa_heldenverwaltung/domain/learn/learn_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/epic_ap_cost_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/steigerung_herleitung_rules.dart';

/// Bezeichnung der eingegebenen oder vorgeschlagenen Kosten.
const String kErwerbBasiskostenSchritt = 'Kosten laut Katalog/Eingabe';

/// Bezeichnung des Aufschlags für den Erwerb ohne Lehrmeister, wenn die
/// Regel (Talentspezialisierung, WdS S. 17) doppelte Kosten verlangt.
const String kErwerbOhneLehrmeisterSchritt = 'Ohne Lehrmeister (doppelt)';

/// Kosten eines Einmalerwerbs samt Herleitung.
class Erwerbskosten {
  /// Hält die [herleitung] und die Zwischenstände.
  const Erwerbskosten({
    required this.herleitung,
    required this.kostenNachAufschlag,
  });

  /// Schritte bis zu den tatsächlich gebuchten AP.
  final Herleitung herleitung;

  /// Kosten nach epischem Aufschlag, vor Lehrmeister-Regel.
  final int kostenNachAufschlag;

  /// Tatsächlich gebuchte AP.
  int get apKosten => herleitung.wert;

  /// Betrag des epischen Aufschlags (0, wenn er nicht greift).
  int get aufschlag => herleitung.schritte
      .where((s) => s.bezeichnung == kSteigerungEposSchritt)
      .fold<int>(0, (summe, s) => summe + s.betrag);
}

/// Leitet die Kosten eines Einmalerwerbs aus [basiskosten] her.
///
/// Der epische Aufschlag gilt nur für [episch]e Helden und entfällt für
/// [epischerInhalt], [keinAufschlag] (Begabung/Sondererfahrung) und mit
/// [mitLehrmeister]. Ein Lehrmeister senkt die Kosten um 20 %, hebt bei
/// epischen Helden aber nur den Aufschlag auf; gilt
/// [lehrmeisterVerdoppeltOhneIhn], zählen die Kosten als Preis *mit*
/// Lehrmeister und der Erwerb ohne ihn kostet das Doppelte.
Erwerbskosten herleiteErwerbskosten({
  required int basiskosten,
  bool episch = false,
  bool epischerInhalt = false,
  bool keinAufschlag = false,
  bool mitLehrmeister = false,
  bool lehrmeisterVerdoppeltOhneIhn = false,
}) {
  final nachAufschlag = applyEpicApSurcharge(
    basiskosten,
    ruleActive: true,
    isEpisch: episch,
    isEpicContent: epischerInhalt,
    isBegabung: keinAufschlag,
    lehrmeisterHebtAuf: mitLehrmeister,
  );
  final int nachLehrmeister;
  if (lehrmeisterVerdoppeltOhneIhn) {
    nachLehrmeister = mitLehrmeister ? nachAufschlag : nachAufschlag * 2;
  } else {
    // Ein Lehrmeister hebt den epischen Aufschlag auf, statt zusaetzlich zu
    // verbilligen (Hausregel „Epische Stufen", Kap. 2.2).
    final aufschlagAufgehoben =
        mitLehrmeister &&
        epicApSurchargeApplies(
          ruleActive: true,
          isEpisch: episch,
          isEpicContent: epischerInhalt,
          isBegabung: keinAufschlag,
        );
    nachLehrmeister = mitLehrmeister && !aufschlagAufgehoben
        ? apMitLehrmeister(nachAufschlag)
        : nachAufschlag;
  }
  return Erwerbskosten(
    kostenNachAufschlag: nachAufschlag,
    herleitung: Herleitung(
      bezeichnung: 'AP-Kosten',
      schritte: <HerleitungsSchritt>[
        HerleitungsSchritt(
          bezeichnung: kErwerbBasiskostenSchritt,
          betrag: basiskosten,
          art: HerleitungsArt.grundwert,
        ),
        HerleitungsSchritt(
          bezeichnung: kSteigerungEposSchritt,
          betrag: nachAufschlag - basiskosten,
          art: HerleitungsArt.modifikator,
          quelle: 'Epische Stufen',
          bedingung:
              'Held ist episch, kein epischer Inhalt, keine '
              'Begabung/Sondererfahrung, kein Lehrmeister',
        ),
        if (lehrmeisterVerdoppeltOhneIhn)
          HerleitungsSchritt(
            bezeichnung: kErwerbOhneLehrmeisterSchritt,
            betrag: nachLehrmeister - nachAufschlag,
            art: HerleitungsArt.modifikator,
            quelle: 'Wege des Schwerts S. 17',
            bedingung: 'Erwerb ohne Lehrmeister',
          )
        else
          HerleitungsSchritt(
            bezeichnung: kSteigerungLehrmeisterSchritt,
            betrag: nachLehrmeister - nachAufschlag,
            art: HerleitungsArt.modifikator,
            quelle: 'Lehrmeister',
            bedingung: 'Lehrmeister mit TaW ≥ 15, außer er hebt den epischen Aufschlag auf',
          ),
      ],
    ),
  );
}
