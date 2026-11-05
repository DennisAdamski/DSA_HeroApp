import 'dart:math' as math;

import 'package:dsa_heldenverwaltung/domain/learn/learn_complexity.dart';
import 'package:dsa_heldenverwaltung/rules/derived/learning_rules.dart';

/// Ordnet eine DSA-Lernkomplexitaet (`A*` bis `H`) einer [LearnCost]-Stufe zu.
///
/// Unbekannte oder leere Werte liefern `null`, damit Aufrufer fehlende
/// Katalogdaten gezielt behandeln koennen.
LearnCost? learnCostFromKomplexitaet(String komplexitaet) {
  final normalized = komplexitaet.trim().toUpperCase();
  return switch (normalized) {
    'A*' => LearnCost.z,
    'A' => LearnCost.a,
    'B' => LearnCost.b,
    'C' => LearnCost.c,
    'D' => LearnCost.d,
    'E' => LearnCost.e,
    'F' => LearnCost.f,
    'G' => LearnCost.g,
    'H' => LearnCost.h,
    _ => null,
  };
}

/// Feste Lernkomplexitaet fuer Eigenschaften.
const LearnCost kEigenschaftKomplexitaet = LearnCost.h;

/// Feste Lernkomplexitaeten fuer kaufbare Grundwerte.
const Map<String, LearnCost> kGrundwertKomplexitaeten = <String, LearnCost>{
  'lep': LearnCost.h,
  'au': LearnCost.e,
  'asp': LearnCost.g,
  'kap': LearnCost.h,
  'mr': LearnCost.h,
};

/// Berechnet die AP-Kosten fuer eine Steigerung eines Werts.
///
/// `vonWert` darf `-1` sein, um die Aktivierung eines zuvor inaktiven Talents
/// abzubilden. In diesem Fall repraesentiert der erste Schritt die
/// Aktivierungskosten. Sondererfahrungen reduzieren fuer die ersten
/// `seAnzahl` Schritte die Komplexitaet jeweils um genau eine Stufe.
///
/// [erleichterungBisWert] verbilligt jeden Schritt, dessen Zielwert hoechstens
/// so hoch ist, um eine weitere Spalte (Hexalogie: ein Zauber derselben
/// Hexalogie mit diesem ZfW ist schon gelernt). Die Aktivierung (Ziel 0) gehoert
/// dazu, sobald der Wert mindestens 0 ist. Beide Erleichterungen zaehlen
/// gemeinsam.
({int apKosten, int seVerbraucht}) berechneSteigerungskosten({
  required int vonWert,
  required int aufWert,
  required LearnCost effektiveKomplexitaet,
  int seAnzahl = 0,
  int? erleichterungBisWert,
}) {
  if (aufWert <= vonWert) {
    return (apKosten: 0, seVerbraucht: 0);
  }

  var kosten = 0;
  var seVerbraucht = 0;
  final verfuegbareSe = math.max(0, seAnzahl);
  for (var level = vonWert; level < aufWert; level++) {
    final nutztSe = seVerbraucht < verfuegbareSe;
    final erleichtert =
        erleichterungBisWert != null && level + 1 <= erleichterungBisWert;
    final schrittKomplexitaet = effektiveKomplexitaet.plusSteps(
      -((nutztSe ? 1 : 0) + (erleichtert ? 1 : 0)),
    );
    kosten += schrittKomplexitaet.costForStep(level);
    if (nutztSe) {
      seVerbraucht++;
    }
  }
  return (apKosten: kosten, seVerbraucht: seVerbraucht);
}

/// Reduziert Basiskosten fuer einen Lehrmeister um 20 Prozent.
///
/// Es wird echt gerundet (Wege der Helden S. 6, Tischentscheid 27.10.2026):
/// 4/5 der Basiskosten hat nur Nachkommastellen in Fuenfteln, ein exaktes
/// ,5 kommt nie vor. `(4 x + 2) ~/ 5` rechnet ohne Gleitkomma.
int apMitLehrmeister(int basiskosten) {
  if (basiskosten <= 0) {
    return 0;
  }
  return (basiskosten * 4 + 2) ~/ 5;
}

/// Berechnet die Dukatenkosten fuer eine Steigerung mit Lehrmeister.
double dukatenFuerLehrmeister(int apMitLehrmeister, int lehrmeisterTaW) {
  if (apMitLehrmeister <= 0 || lehrmeisterTaW <= 0) {
    return 0;
  }
  return apMitLehrmeister * lehrmeisterTaW * 2 / 100;
}

/// Liefert das zu einer [LearnCost]-Stufe passende DSA-Komplexitaetslabel.
String komplexitaetLabel(LearnCost learnCost) {
  return kLernkomplexitaeten[learnCost.index];
}
