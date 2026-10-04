import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';

import 'gefecht.dart';
import 'probe_engine.dart';
import 'gefecht_kontext.dart';

/// Geprüfter Auftrag; die Ausführung validiert ihn auf aktuellen Werten erneut.
class GefechtAuftrag {
  /// Hält ausschließlich explizit bestätigte Eingaben fest.
  const GefechtAuftrag({
    required this.aktion,
    required this.titel,
    required this.zuschlag,
    required this.dk,
    required this.dauer,
    required this.kosten,
    this.zielwert,
    this.manoever,
    this.probe,
    this.manuell = false,
    this.grosserGegner = false,
    this.grosserSchild = false,
    this.zusatzParade = false,
    this.kontext,
    this.distanzSchritte = 0,
    this.kampfmittel,
    this.eingabefehler = const [],
    this.bestaetigteEntscheidungen = const [],
    this.finte = 0,
    this.wuchtschlag = 0,
    this.fernkampfansage = 0,
    this.zielErleichterung = 0,
    this.meisterparadeAnsage = 0,
    this.schildAnsagegrenze,
    this.manuelleKampfaktion,
  });
  final Gefechtsaktion aktion;
  final String titel;
  final int zuschlag, dauer, kosten;
  final int? zielwert;
  final String? dk;
  final ManeuverDef? manoever;
  final ResolvedProbeRequest? probe;
  final bool manuell, grosserGegner, grosserSchild, zusatzParade;
  final Gefechtskontext? kontext;
  final int distanzSchritte;
  final GefechtsKampfmittelwahl? kampfmittel;

  /// Ungültige Formularzahlen bleiben auch bei erneuter Prüfung sichtbar.
  final List<String> eingabefehler;

  /// Einzelne nicht automatisierbare Entscheidungen, keine pauschale Freigabe.
  final List<String> bestaetigteEntscheidungen;

  /// Unabhängige Ansagen; weitere Erschwernisse erzeugen keine Trefferfolgen.
  final int finte, wuchtschlag, fernkampfansage;

  /// Gewünschter Abbau anderer FK-Zuschläge durch separat bezahltes Zielen.
  final int zielErleichterung;

  /// Eigene PA-Ansage; erzeugt ausschließlich den einmaligen Erfolgsbonus.
  final int meisterparadeAnsage;

  /// Am Tisch geklärte Schildgrenze, weil Schilde keinen eigenen TaW haben.
  final int? schildAnsagegrenze;

  /// Ausdrückliche Einordnung manueller Abschlüsse als Angriff oder Abwehr.
  final Gefechtsaktion? manuelleKampfaktion;
}
