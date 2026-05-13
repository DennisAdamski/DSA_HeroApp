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
    'lep' => permanentAttributes.ko ~/ 2,
    'au' => permanentAttributes.ko,
    'mr' => permanentAttributes.mu ~/ 2,
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
