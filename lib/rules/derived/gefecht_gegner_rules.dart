import 'package:dsa_heldenverwaltung/domain/gefecht_gegner.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';

import 'gefecht_vorgaben_rules.dart';

/// Ein neuer Gegnerkontakt verwirft Angriffsdaten und bezahltes altes Zielen.
Gefechtszustand waehleGefechtsgegner(
  Gefechtszustand s,
  Gefechtsgegner g, {
  required String startDk,
}) {
  if (s.auftrag != null || s.handlung != null) {
    throw StateError('Laufende Handlung zuerst abschließen oder abbrechen.');
  }
  if (s.kontext.gegnerId == g.id) return s;
  return s.copyWith(
    dk: startDk,
    ohneZielstand: true,
    kontext: gefechtsKontextMitVorgaben(
      Gefechtskontext(kontakt: g.name, gegnerId: g.id),
    ),
  );
}

/// WdS 56 (MCP 6975): RS mindert TP, direkte SP umgehen den Rüstungsschutz.
Gefechtsgegner gefechtsGegnerschaden(
  Gefechtsgegner g,
  int tp, {
  bool direkt = false,
}) {
  if (tp < 0) throw ArgumentError('Schaden darf nicht negativ sein.');
  final rest = direkt ? tp : tp - g.rs;
  final sp = rest < 0 ? 0 : rest;
  return g.copyWith(lep: g.lep - sp);
}

/// Erfasst oder korrigiert einen Gegner, ohne gleichnamige Gegner zu ersetzen.
Gefechtsbegegnung speichereGefechtsgegner(
  Gefechtsbegegnung s,
  Gefechtsgegner g,
) {
  if (g.id.isEmpty || g.name.trim().isEmpty || g.rs < 0) {
    throw ArgumentError('Name und ID sind erforderlich; RS mindestens 0.');
  }
  return s.copyWith(gegner: Map.unmodifiable({...s.gegner, g.id: g}));
}

/// Verbraucht eine konkrete bestätigte Schadensübernahme höchstens einmal.
Gefechtsbegegnung bucheGefechtsGegnerschaden(
  Gefechtsbegegnung s, {
  required String gegnerId,
  required String buchungId,
  required int tp,
  bool direkt = false,
}) {
  if (s.buchungen.contains(buchungId)) return s;
  if (buchungId.isEmpty) throw ArgumentError('Buchungs-ID fehlt.');
  final g = s.gegner[gegnerId];
  if (g == null) throw StateError('Der ursprüngliche Gegner fehlt.');
  final neu = gefechtsGegnerschaden(g, tp, direkt: direkt);
  return s.copyWith(
    gegner: Map.unmodifiable({...s.gegner, gegnerId: neu}),
    buchungen: Set.unmodifiable({...s.buchungen, buchungId}),
  );
}
