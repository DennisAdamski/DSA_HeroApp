import 'gefecht.dart';
import 'probe_engine.dart';

/// Eine getrennte AT/PA mit dauerhaftem Ziel innerhalb der flüchtigen Handlung.
class GefechtsKlingenteil {
  /// DK und gegnerische Finte werden für jede Teilprobe ausdrücklich erfasst.
  const GefechtsKlingenteil({
    required this.gegnerId,
    required this.dk,
    required this.zielwert,
    this.finte = 0,
    this.ergebnis,
  });
  final String gegnerId, dk;
  final int zielwert, finte;
  final ProbeResult? ergebnis;

  /// Einmalige Ergebnisse bleiben bei Navigation und erneutem Callback erhalten.
  GefechtsKlingenteil mitErgebnis(ProbeResult r) => GefechtsKlingenteil(
    gegnerId: gegnerId,
    dk: dk,
    zielwert: zielwert,
    finte: finte,
    ergebnis: r,
  );
}

/// Geteilter Angriff oder geteilte Abwehr mit genau einer regulären Quellmarke.
class GefechtsKlingenstand {
  /// Profil und Zielwerte sind für diesen bestätigten Ablauf eingefroren.
  const GefechtsKlingenstand({
    required this.id,
    required this.parade,
    required this.kampfmittel,
    required this.profilKey,
    required this.teile,
    required this.basisPruefung,
    required this.schaden,
    this.bezahlt = false,
  });
  final String id, profilKey;
  final bool parade, bezahlt;
  final GefechtsKampfmittelwahl kampfmittel;
  final List<GefechtsKlingenteil> teile;
  final Gefechtspruefung basisPruefung;
  final DiceSpec? schaden;

  /// Aktualisiert nur den Fortschritt, niemals die bezahlte Quellaktion.
  GefechtsKlingenstand copyWith({
    List<GefechtsKlingenteil>? teile,
    bool? bezahlt,
  }) => GefechtsKlingenstand(
    id: id,
    parade: parade,
    kampfmittel: kampfmittel,
    profilKey: profilKey,
    teile: teile ?? this.teile,
    basisPruefung: basisPruefung,
    schaden: schaden,
    bezahlt: bezahlt ?? this.bezahlt,
  );
}
