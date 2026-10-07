/// Sofortbuchungen an der Ausbildung eines Reittiers.
///
/// Jede Funktion arbeitet auf dem frisch geladenen Begleiter und prüft den
/// Stand, den der Dialog gezeigt hat. Weicht er ab, wurde inzwischen
/// anderswo gebucht; dann wirft sie einen [StateError], statt auf einem
/// veralteten Stand weiterzubuchen.
library;

import 'package:dsa_heldenverwaltung/catalog/reittier_ausbildung_katalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';

import 'begleiter_aenderung_rules.dart';
import 'reittier_ausbildung_rules.dart';

/// Begleiter-SF-Eintrag für eine Pferde-SF aus dem Katalog.
///
/// Name und Kurzwirkung stehen mit im Eintrag, damit ältere App-Versionen
/// die Sonderfertigkeit ohne Katalog anzeigen.
HeroCompanionSonderfertigkeit pferdeSfEintrag(PferdeSfDef sf) =>
    HeroCompanionSonderfertigkeit(
      name: sf.name,
      beschreibung: sf.kurzwirkung,
      katalogId: sf.id,
    );

/// Bucht den Ausbildungsschritt [schritt] auf den gespeicherten Begleiter.
///
/// [erwarteteSchrittanzahl] ist die Zahl der Schritte, die der Dialog
/// gesehen hat. [varianteId] setzt die Ausbildungsvariante (für den Schritt
/// nach „geschult“). Führt der Schritt nach „geschult“ und ist
/// [varianteSfUebernehmen] gesetzt, bekommt das Tier die noch fehlenden
/// Sonderfertigkeiten der Variante.
HeroCompanion schliesseAusbildungsschrittAb(
  HeroCompanion gespeichert, {
  required int erwarteteSchrittanzahl,
  required ReittierAusbildungsschritt schritt,
  String? varianteId,
  bool varianteSfUebernehmen = true,
}) {
  final ausbildung = _gepruefteAusbildung(gespeichert, erwarteteSchrittanzahl);
  final neu = ausbildung.copyWith(
    schritte: List<ReittierAusbildungsschritt>.unmodifiable(
      <ReittierAusbildungsschritt>[...ausbildung.schritte, schritt],
    ),
    varianteId: varianteId,
  );
  var begleiter = gespeichert.copyWith(reittierAusbildung: neu);
  final variante = gewaehlteVariante(neu);
  final geschult = schritt.nach == ReittierAusbildungsstufe.geschult;
  if (geschult && varianteSfUebernehmen && variante != null) {
    begleiter = _mitVariantenSf(begleiter, variante);
  }
  return begleiter;
}

/// Nimmt den zuletzt gebuchten Ausbildungsschritt zurück.
///
/// Mit der Variante übernommene Sonderfertigkeiten bleiben stehen; sie
/// lassen sich im Bearbeitungsmodus einzeln entfernen.
HeroCompanion nimmLetztenAusbildungsschrittZurueck(
  HeroCompanion gespeichert, {
  required int erwarteteSchrittanzahl,
}) {
  final ausbildung = _gepruefteAusbildung(gespeichert, erwarteteSchrittanzahl);
  if (ausbildung.schritte.isEmpty) {
    throw StateError('Es gibt keinen gebuchten Ausbildungsschritt.');
  }
  final verbleibend = ausbildung.schritte.sublist(
    0,
    ausbildung.schritte.length - 1,
  );
  return gespeichert.copyWith(
    reittierAusbildung: ausbildung.copyWith(
      schritte: List<ReittierAusbildungsschritt>.unmodifiable(verbleibend),
    ),
  );
}

/// Trägt die Pferde-SF [sfId] beim Begleiter ein.
///
/// Wirft einen [StateError] für unbekannte oder schon erlernte SF; die
/// Lernbarkeit selbst entscheidet der Dialog samt Meisterentscheid.
HeroCompanion erlernePferdeSf(HeroCompanion gespeichert, String sfId) {
  final sf = pferdeSf(sfId);
  if (sf == null) {
    throw StateError('Unbekannte Pferde-Sonderfertigkeit.');
  }
  if (begleiterBeherrschtPferdeSf(gespeichert, sfId)) {
    throw StateError('${sf.name} ist bereits erlernt.');
  }
  return gespeichert.copyWith(
    sonderfertigkeiten: List<HeroCompanionSonderfertigkeit>.unmodifiable(
      <HeroCompanionSonderfertigkeit>[
        ...gespeichert.sonderfertigkeiten,
        pferdeSfEintrag(sf),
      ],
    ),
  );
}

/// Bucht einen Ausbildungsschritt auf den Begleiter [begleiterId] des
/// gespeicherten Helden.
HeroSheet bucheAusbildungsschritt(
  HeroSheet held, {
  required String begleiterId,
  required int erwarteteSchrittanzahl,
  required ReittierAusbildungsschritt schritt,
  String? varianteId,
  bool varianteSfUebernehmen = true,
}) {
  return ersetzeBegleiter(
    held,
    begleiterId,
    (gespeichert) => schliesseAusbildungsschrittAb(
      gespeichert,
      erwarteteSchrittanzahl: erwarteteSchrittanzahl,
      schritt: schritt,
      varianteId: varianteId,
      varianteSfUebernehmen: varianteSfUebernehmen,
    ),
  );
}

/// Nimmt beim Begleiter [begleiterId] den letzten Ausbildungsschritt zurück.
HeroSheet bucheAusbildungsschrittZurueck(
  HeroSheet held, {
  required String begleiterId,
  required int erwarteteSchrittanzahl,
}) {
  return ersetzeBegleiter(
    held,
    begleiterId,
    (gespeichert) => nimmLetztenAusbildungsschrittZurueck(
      gespeichert,
      erwarteteSchrittanzahl: erwarteteSchrittanzahl,
    ),
  );
}

/// Trägt beim Begleiter [begleiterId] die Pferde-SF [sfId] ein.
HeroSheet buchePferdeSf(
  HeroSheet held, {
  required String begleiterId,
  required String sfId,
}) {
  return ersetzeBegleiter(
    held,
    begleiterId,
    (gespeichert) => erlernePferdeSf(gespeichert, sfId),
  );
}

// Ausbildung des Begleiters, sofern sie dem Stand des Dialogs entspricht.
ReittierAusbildung _gepruefteAusbildung(
  HeroCompanion gespeichert,
  int erwarteteSchrittanzahl,
) {
  final ausbildung = gespeichert.reittierAusbildung;
  if (ausbildung == null) {
    throw StateError('Für dieses Tier ist keine Ausbildung erfasst.');
  }
  if (ausbildung.schritte.length != erwarteteSchrittanzahl) {
    throw StateError(
      'Die Ausbildung wurde inzwischen geändert. Bitte erneut öffnen.',
    );
  }
  return ausbildung;
}

// Hängt die noch fehlenden Sonderfertigkeiten der Variante an.
HeroCompanion _mitVariantenSf(
  HeroCompanion begleiter,
  ReittierAusbildungsvarianteDef variante,
) {
  final neu = <HeroCompanionSonderfertigkeit>[
    for (final id in variante.sfIds)
      if (!begleiterBeherrschtPferdeSf(begleiter, id) && pferdeSf(id) != null)
        pferdeSfEintrag(pferdeSf(id)!),
  ];
  if (neu.isEmpty) {
    return begleiter;
  }
  return begleiter.copyWith(
    sonderfertigkeiten: List<HeroCompanionSonderfertigkeit>.unmodifiable(
      <HeroCompanionSonderfertigkeit>[...begleiter.sonderfertigkeiten, ...neu],
    ),
  );
}
