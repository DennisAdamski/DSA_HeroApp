/// Regeln fuer mehrfach erwerbbare Sonderfertigkeiten mit Auswahlvariante.
///
/// Einige allgemeine Sonderfertigkeiten werden laut Regelwerk mehrfach mit
/// jeweils einer anderen Auswahl erworben — Kulturkunde je Kultur,
/// Gelaendekunde je Gelaendetyp, Ortskenntnis je Oertlichkeit,
/// Akklimatisierung je Klima, Berufsgeheimnis je Geheimwissen.
///
/// Gespeichert wird jede Instanz als eigener Eintrag im Format
/// `Basisname (Variante)` — genau so schreiben es auch die Regelwerke
/// ("Kulturkunde (Novadi)"). Dieses Modul kapselt Aufbau und Zerlegung dieser
/// Namen sowie den AP-Vorschlag fuer gestaffelte Erwerbskosten.
library;

import 'package:dsa_heldenverwaltung/catalog/special_ability_def.dart';
import 'package:dsa_heldenverwaltung/rules/derived/cost_text_parsing.dart';

/// Baut den speicherbaren Anzeigenamen aus Basisname und Variante.
///
/// Eine leere Variante liefert den unveraenderten Basisnamen, damit
/// Sonderfertigkeiten ohne Auswahl gleich behandelt werden koennen.
String buildVariantAbilityName(String basisName, String variante) {
  final base = basisName.trim();
  final selection = variante.trim();
  if (base.isEmpty || selection.isEmpty) {
    return base;
  }
  return '$base ($selection)';
}

/// Liefert den Basisnamen eines gespeicherten Sonderfertigkeitsnamens.
///
/// Schneidet eine abschliessende Klammergruppe ab; `Kulturkunde (Novadi)`
/// ergibt `Kulturkunde`. Namen ohne Klammer bleiben unveraendert.
String specialAbilityBaseName(String gespeicherterName) {
  final name = gespeicherterName.trim();
  if (!name.endsWith(')')) {
    return name;
  }
  final open = name.indexOf('(');
  if (open <= 0) {
    return name;
  }
  return name.substring(0, open).trim();
}

/// Liefert die Variante eines gespeicherten Namens — die Umkehrung von
/// [buildVariantAbilityName]. `null`, wenn keine Variante enthalten ist.
String? specialAbilityVariant(String gespeicherterName) {
  final name = gespeicherterName.trim();
  if (!name.endsWith(')')) {
    return null;
  }
  final open = name.indexOf('(');
  if (open <= 0) {
    return null;
  }
  final variant = name.substring(open + 1, name.length - 1).trim();
  return variant.isEmpty ? null : variant;
}

/// Normalisiert einen Sonderfertigkeitsnamen fuer Vergleiche.
///
/// Faltet Umlaute und Eszett, senkt die Schreibweise und ersetzt alle uebrigen
/// Sonderzeichen durch einzelne Leerzeichen — dieselbe Strategie wie beim
/// Vor-/Nachteil-Abgleich, damit `Gelaendekunde` und `Geländekunde` gleich
/// behandelt werden.
String normalizeSpecialAbilityName(String value) {
  var text = value.toLowerCase().trim();
  text = text
      .replaceAll(String.fromCharCode(228), 'ae') // ä
      .replaceAll(String.fromCharCode(246), 'oe') // ö
      .replaceAll(String.fromCharCode(252), 'ue') // ü
      .replaceAll(String.fromCharCode(223), 'ss'); // ß
  return text.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

/// Zaehlt, wie viele der bereits eingetragenen Namen zu [basisName] gehoeren.
///
/// Beruecksichtigt sowohl Eintraege mit Variante (`Kulturkunde (Novadi)`) als
/// auch Altbestand ohne Variante (`Kulturkunde`).
int countOwnedVariants(Iterable<String> ownedNames, String basisName) {
  final needle = normalizeSpecialAbilityName(basisName);
  if (needle.isEmpty) {
    return 0;
  }
  var count = 0;
  for (final owned in ownedNames) {
    if (normalizeSpecialAbilityName(specialAbilityBaseName(owned)) == needle) {
      count++;
    }
  }
  return count;
}

/// Liefert die bereits belegten Varianten zu [basisName].
Set<String> ownedVariantsFor(Iterable<String> ownedNames, String basisName) {
  final needle = normalizeSpecialAbilityName(basisName);
  final variants = <String>{};
  if (needle.isEmpty) {
    return variants;
  }
  for (final owned in ownedNames) {
    if (normalizeSpecialAbilityName(specialAbilityBaseName(owned)) != needle) {
      continue;
    }
    final variant = specialAbilityVariant(owned);
    if (variant != null) {
      variants.add(variant);
    }
  }
  return variants;
}

/// Schlaegt die AP-Kosten fuer einen Erwerb vor.
///
/// Der Wert ist bewusst nur ein Vorschlag fuer den Erwerbsdialog: Die
/// Kostentexte der Regelwerke kennen zusaetzliche Rabatte (Kulturkunde
/// verbilligt auf 75 bzw. 38 AP), die weiterhin als Kostenhinweis im Dialog
/// stehen und dort manuell uebernommen werden.
///
/// [bereitsErworben] ist die Anzahl der schon eingetragenen Instanzen.
/// [eigeneKultur] ermoeglicht den Regelfall "Kulturkunde der eigenen Kultur
/// ist kostenlos"; der Abgleich ist ein Best-effort-Textvergleich mit
/// `hero.background.kultur`.
int suggestVariantApCost({
  required SpecialAbilityDef def,
  required int bereitsErworben,
  String variante = '',
  String eigeneKultur = '',
}) {
  if (_matchesOwnCulture(variante, eigeneKultur)) {
    return 0;
  }
  final fallback = parseLeadingApAmount(def.kosten) ?? 0;
  if (bereitsErworben <= 0) {
    return def.apErstwerb ?? fallback;
  }
  return def.apFolgeerwerb ?? def.apErstwerb ?? fallback;
}

bool _matchesOwnCulture(String variante, String eigeneKultur) {
  final selection = normalizeSpecialAbilityName(variante);
  final own = normalizeSpecialAbilityName(eigeneKultur);
  if (selection.isEmpty || own.isEmpty) {
    return false;
  }
  return selection == own ||
      own.contains(selection) ||
      selection.contains(own);
}
