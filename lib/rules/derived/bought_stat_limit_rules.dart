import 'package:dsa_heldenverwaltung/domain/attributes.dart';

/// Liefert die fachliche Zukauf-Grenze fuer kaufbare Grundwerte.
///
/// `null` bedeutet, dass fuer den Wert aktuell keine harte Regelgrenze
/// modelliert ist und nur AP-Verfuegbarkeit begrenzt.
int? computeBoughtStatMaximum({
  required String statKey,
  required Attributes permanentAttributes,
}) {
  return switch (statKey) {
    // Halbierungen werden aufgerundet (Wege der Helden S. 6).
    'lep' => (permanentAttributes.ko + 1) ~/ 2,
    'au' => permanentAttributes.ko,
    'mr' => (permanentAttributes.mu + 1) ~/ 2,
    // Zugekaufte Astralpunkte hoechstens in Hoehe des CH-Werts
    // (Basisregelwerk S. 207). Karmaenergie hat keine Regelgrenze.
    'asp' => permanentAttributes.ch,
    _ => null,
  };
}

/// Kombiniert AP-erreichbaren Wert und fachliche Zukauf-Grenze.
int resolveBoughtStatDialogMaximum({
  required int apReachableMaximum,
  required int? ruleMaximum,
}) {
  if (ruleMaximum == null) {
    return apReachableMaximum;
  }
  if (ruleMaximum < apReachableMaximum) {
    return ruleMaximum;
  }
  return apReachableMaximum;
}
