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
({int apKosten, int seVerbraucht}) berechneSteigerungskosten({
  required int vonWert,
  required int aufWert,
  required LearnCost effektiveKomplexitaet,
  int seAnzahl = 0,
}) {
  if (aufWert <= vonWert) {
    return (apKosten: 0, seVerbraucht: 0);
  }

  var kosten = 0;
  var seVerbraucht = 0;
  final verfuegbareSe = math.max(0, seAnzahl);
  for (var level = vonWert; level < aufWert; level++) {
    final nutztSe = seVerbraucht < verfuegbareSe;
    final schrittKomplexitaet = nutztSe
        ? effektiveKomplexitaet.previous()
        : effektiveKomplexitaet;
    kosten += schrittKomplexitaet.costForStep(level);
    if (nutztSe) {
      seVerbraucht++;
    }
  }
  return (apKosten: kosten, seVerbraucht: seVerbraucht);
}

/// Reduziert Basiskosten fuer einen Lehrmeister um 20 Prozent.
int apMitLehrmeister(int basiskosten) {
  if (basiskosten <= 0) {
    return 0;
  }
  return (basiskosten * 0.8).floor();
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
