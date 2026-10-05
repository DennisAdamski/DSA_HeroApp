import 'probe_engine.dart';
import 'gefecht_fremdwirkung.dart';

/// Bestätigte Eingaben einer Zauber-, Mirakel- oder Liturgiehandlung.
class GefechtsWirkprofil {
  /// Enthält nur flüchtige Arbeitsdaten; kein JSON und keine Ressourcenbuchung.
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
    this.aufrechterhalteneZauber,
    this.fremdwirkung,
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

  /// Angegebene Zahl aufrechterhaltener Zauber; die Sitzung merkt sie sich.
  final int? aufrechterhalteneZauber;

  /// Vor der Probe ausgewähltes Ziel einer belegten fremden Grundwirkung.
  final GefechtsFremdwirkung? fremdwirkung;

  /// Ergänzt das bestätigte Ziel ohne vorhandene Probenmodifikatoren zu ändern.
  GefechtsWirkprofil mitFremdwirkung(GefechtsFremdwirkung ziel) =>
      GefechtsWirkprofil(
        probe: probe,
        dauer: dauer,
        kosten: kosten,
        karmal: karmal,
        zauberkontrolle: zauberkontrolle,
        misserfolgKosten: misserfolgKosten,
        endprobe: endprobe,
        identitaet: identitaet,
        neueSpielrunde: neueSpielrunde,
        permanentManuell: permanentManuell,
        repraesentation: repraesentation,
        aufrechterhalteneZauber: aufrechterhalteneZauber,
        fremdwirkung: ziel,
      );
}

/// Ein ausdrücklich bestätigter Mirakelbonus auf genau eine passende Probe.
class GefechtsProbenbonus {
  /// Die Zielkennung verhindert, dass ein Bonus auf andere Proben übergreift.
  const GefechtsProbenbonus(this.ziel, this.wert);
  final String ziel;
  final int wert;
}
