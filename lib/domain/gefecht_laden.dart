import 'gefecht.dart';
import 'gefecht_auftrag.dart';

/// Flüchtiger Ladezustand einer physischen Waffe mit bestätigtem Geschossprofil.
class Gefechtsladestand {
  /// Die Waffen-ID ist der Sitzungsschlüssel; die Hand gehört nicht zur Ladung.
  const Gefechtsladestand({
    required this.waffenprofilKey,
    required this.geschossId,
    required this.geladen,
  });
  final String waffenprofilKey, geschossId;
  final bool geladen;
}

/// Bezahlte Vorbereitung, deren Aktionen nie einer anderen Waffe zufallen.
class Gefechtsvorbereitung {
  /// Hält beim Zielen zusätzlich den ursprünglichen Schussauftrag fest.
  const Gefechtsvorbereitung({
    required this.kampfmittel,
    required this.waffenprofilKey,
    required this.geschossId,
    required this.bezahlteAktionen,
    required this.anfangsdauer,
    this.schussauftrag,
  });
  final GefechtsKampfmittelwahl kampfmittel;
  final String waffenprofilKey, geschossId;
  final int bezahlteAktionen, anfangsdauer;
  final GefechtAuftrag? schussauftrag;

  /// Erhält alle Bindungen beim tatsächlichen Bezahlen einer weiteren Aktion.
  Gefechtsvorbereitung mitZahlung(int bezahlt) => Gefechtsvorbereitung(
    kampfmittel: kampfmittel,
    waffenprofilKey: waffenprofilKey,
    geschossId: geschossId,
    bezahlteAktionen: bezahlt,
    anfangsdauer: anfangsdauer,
    schussauftrag: schussauftrag,
  );
}
