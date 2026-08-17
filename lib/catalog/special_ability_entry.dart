/// Gemeinsamer Nenner aller Sonderfertigkeits-Katalogeintraege.
///
/// Die Regelwerke fuehren Kampf-Sonderfertigkeiten getrennt von den
/// allgemeinen, magischen und karmalen, und die App folgt dem: Kampf-Eintraege
/// sind `CombatSpecialAbilityDef` (mit Manoever-Freischaltungen und
/// Kampfwert-Boni), alles Uebrige ist `SpecialAbilityDef` (mit Varianten und
/// gestaffelten AP-Kosten). Fuer Erwerbsvoraussetzungen und Stufenketten ist
/// dieser Unterschied aber bedeutungslos — beide brauchen dieselbe Pruefung
/// und dieselbe Stufen-Darstellung.
///
/// Diese Schnittstelle haelt genau das fest, was Ketten-Logik und
/// Voraussetzungs-UI von einem Eintrag brauchen. Sie bleibt bewusst schmal:
/// Alles, was nur eine der beiden Seiten kennt (Varianten, Kategorie,
/// `nur_information`, Manoever-IDs), liest die UI weiterhin direkt am
/// konkreten Typ.
library;

import 'package:dsa_heldenverwaltung/catalog/special_ability_requirement.dart';

/// Ein Katalogeintrag, der Voraussetzungen und Stufenketten tragen kann.
abstract interface class SpecialAbilityEntry {
  /// Eindeutige Katalog-ID.
  String get id;

  /// Anzeigename.
  String get name;

  /// AP-Kosten laut Regelwerk, als Freitext.
  String get kosten;

  /// Anzeigename plus alle frueheren Schreibweisen — die vollstaendige Menge
  /// an Namen, unter denen dieser Eintrag bei einem Helden stehen kann.
  List<String> get alleNamen;

  /// Maschinenlesbare Erwerbsvoraussetzungen; leer heisst „nichts pruefbar“.
  List<SpecialAbilityRequirement> get voraussetzungenStruktur;

  /// Zugehoerigkeit zu einer Stufenkette; `null` bei Einzeleintraegen.
  SpecialAbilityChainRef? get kette;

  /// Nur fuer episch eingestufte Helden verfuegbar.
  bool get nurEpisch;
}
