import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';

/// Normalisiert einen Kampf-Token robust fuer Vergleiche.
String normalizeCombatToken(String raw) {
  var value = raw.trim().toLowerCase();
  value = value
      .replaceAll(String.fromCharCode(228), 'ae')
      .replaceAll(String.fromCharCode(246), 'oe')
      .replaceAll(String.fromCharCode(252), 'ue')
      .replaceAll(String.fromCharCode(223), 'ss');
  return value.replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

/// Leitet eine stabile Manoever-ID aus Name oder ID ab.
///
/// Bevorzugt vorhandene Katalog-IDs und faellt sonst auf ein Slug-Format zurueck.
String canonicalManeuverIdFromName(
  String raw, {
  Iterable<ManeuverDef> catalogManeuvers = const <ManeuverDef>[],
}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  if (trimmed.startsWith('man_')) {
    return trimmed;
  }
  final token = normalizeCombatToken(trimmed);
  if (token.isEmpty) {
    return '';
  }
  for (final maneuver in catalogManeuvers) {
    final maneuverToken = normalizeCombatToken(maneuver.name);
    if (maneuverToken == token) {
      return maneuver.id;
    }
  }
  return 'man_$token';
}

/// Liefert den Anzeigenamen eines Manoevers anhand seiner stabilen ID.
String displayNameForManeuverId(
  String maneuverId, {
  Iterable<ManeuverDef> catalogManeuvers = const <ManeuverDef>[],
}) {
  final trimmed = maneuverId.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  for (final maneuver in catalogManeuvers) {
    if (maneuver.id == trimmed) {
      return maneuver.name;
    }
  }
  if (!trimmed.startsWith('man_')) {
    return trimmed;
  }
  final rawName = trimmed.substring(4);
  if (rawName.isEmpty) {
    return trimmed;
  }
  final withSpaces = rawName.replaceAll('_', ' ');
  return withSpaces.substring(0, 1).toUpperCase() + withSpaces.substring(1);
}

/// Normalisiert eine Liste von Manoevertokens zu stabilen IDs.
List<String> normalizeManeuverIds(
  Iterable<String> values, {
  Iterable<ManeuverDef> catalogManeuvers = const <ManeuverDef>[],
}) {
  final seen = <String>{};
  final normalized = <String>[];
  for (final value in values) {
    final id = canonicalManeuverIdFromName(
      value,
      catalogManeuvers: catalogManeuvers,
    );
    if (id.isEmpty || seen.contains(id)) {
      continue;
    }
    seen.add(id);
    normalized.add(id);
  }
  return List<String>.unmodifiable(normalized);
}
