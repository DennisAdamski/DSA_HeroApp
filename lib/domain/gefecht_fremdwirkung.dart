import 'probe_engine.dart';

/// Vor dem Zauber festgehaltenes fremdes Ziel und verfügbare Startenergie.
class GefechtsFremdwirkung {
  /// Nur lokale Begegnungs-IDs; keine persistierten fremden Heldenzustände.
  const GefechtsFremdwirkung({
    required this.zauberId,
    required this.gegnerId,
    required this.verfuegbareAsp,
  });
  final String zauberId, gegnerId;
  final int verfuegbareAsp;
}

/// Einmal bestätigter Schadenswurf zur unveränderten ursprünglichen Zauberprobe.
class GefechtsFremdwirkungswurf {
  /// Die festgelegten Kosten bleiben bei späterer Übernahme unverändert.
  const GefechtsFremdwirkungswurf({
    required this.ziel,
    required this.probe,
    required this.ersterW6,
    required this.zweiterW6,
    required this.schaden,
  });
  final GefechtsFremdwirkung ziel;
  final ProbeResult probe;
  final int ersterW6, zweiterW6, schaden;

  /// Beim Fulminictus ist jeder zugefügte SP zugleich ein AsP Kostenpunkt.
  int get kosten => schaden;
}
