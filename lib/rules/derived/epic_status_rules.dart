// Aktivieren und Korrigieren des epischen Status (Hausregel „Epische
// Stufen“, Kap. 2.1).
//
// Beide Funktionen arbeiten auf dem gespeicherten Helden (ARCH-05): Start-AP
// und noch nicht aktivierte Talente stammen aus dem Stand, der tatsächlich
// gespeichert wird, nicht aus einer beim Öffnen des Dialogs erfassten
// Anzeige.

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';

/// Setzt den epischen Status des Helden.
///
/// `epicStartAp` ist der aktuelle AP-Verbrauch, `epicUnactivatedTalentIds`
/// die Talente ohne Wert: sie dürfen danach nur noch bis zur niedrigsten
/// beteiligten Eigenschaft gesteigert werden. [obergrenzenBonus] und
/// [haupteigenschaften] werden per `uebernimmWerte` übernommen, damit
/// unbekannte Felder erhalten bleiben; `policy: null` entfernt die Policy.
///
/// Ist der Held bereits episch, wirft die Funktion einen [StateError]: eine
/// zweite Aktivierung verschöbe den Start-AP-Stand und damit das Epos-Level.
HeroSheet aktiviereEpischenStatus(
  HeroSheet held, {
  required Attributes obergrenzenBonus,
  required Attributes haupteigenschaften,
  required String? policy,
}) {
  if (held.isEpisch) {
    throw StateError('Der epische Status ist bereits aktiviert.');
  }
  final nichtAktivierteTalente = <String>{
    for (final eintrag in held.talents.entries)
      if (eintrag.value.talentValue == null) eintrag.key,
  };
  return held.copyWith(
    isEpisch: true,
    epicStartAp: held.apSpent,
    epicAttributeMaxBonus: held.epicAttributeMaxBonus.uebernimmWerte(
      obergrenzenBonus,
    ),
    epicMainAttributes: held.epicMainAttributes.uebernimmWerte(
      haupteigenschaften,
    ),
    epicActivationPolicy: policy,
    epicUnactivatedTalentIds: Set<String>.unmodifiable(nichtAktivierteTalente),
  );
}

/// Korrigiert Haupteigenschaften, Obergrenzen-Bonus und Policy eines bereits
/// epischen Helden.
///
/// `epicStartAp` und `epicUnactivatedTalentIds` bleiben unangetastet, damit
/// Epos-Level und Talentdeckelung stabil bleiben. Ist der Held nicht (mehr)
/// episch, wirft die Funktion einen [StateError].
HeroSheet korrigiereEpischenStatus(
  HeroSheet held, {
  required Attributes obergrenzenBonus,
  required Attributes haupteigenschaften,
  required String? policy,
}) {
  if (!held.isEpisch) {
    throw StateError('Der Held ist nicht episch.');
  }
  return held.copyWith(
    epicAttributeMaxBonus: held.epicAttributeMaxBonus.uebernimmWerte(
      obergrenzenBonus,
    ),
    epicMainAttributes: held.epicMainAttributes.uebernimmWerte(
      haupteigenschaften,
    ),
    epicActivationPolicy: policy,
  );
}
