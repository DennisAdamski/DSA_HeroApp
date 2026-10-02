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
}
