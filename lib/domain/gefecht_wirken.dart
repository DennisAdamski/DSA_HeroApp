import 'probe_engine.dart';

/// Bestätigte Eingaben einer Zauber-, Mirakel- oder Liturgiehandlung.
class GefechtsWirkprofil {
  /// Enthält nur flüchtige Arbeitsdaten; kein JSON und kein Ressourcenstand.
  const GefechtsWirkprofil({
    required this.probe,
    required this.dauer,
    required this.kosten,
    required this.karmal,
    this.zauberkontrolle = false,
    this.misserfolgKosten,
    this.endprobe = false,
    this.identitaet = '',
    this.neueSpielrunde = false,
    this.permanentManuell = false,
    this.repraesentation = '',
  });
  final ResolvedProbeRequest probe;
  final int dauer, kosten;
  final int? misserfolgKosten;
  final bool karmal,
      zauberkontrolle,
      endprobe,
      neueSpielrunde,
      permanentManuell;
  final String identitaet;
  final String repraesentation;
}

/// Ein ausdrücklich bestätigter Mirakelbonus auf genau eine passende Probe.
class GefechtsProbenbonus {
  /// Die Zielkennung verhindert, dass ein Bonus auf andere Proben übergreift.
  const GefechtsProbenbonus(this.ziel, this.wert);
  final String ziel;
  final int wert;
}
