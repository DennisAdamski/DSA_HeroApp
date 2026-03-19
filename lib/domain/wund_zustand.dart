/// Koerperzone fuer das Wunden-Tracking.
enum WundZone {
  kopf,
  brust,
  bauch,
  ruecken,
  linkerArm,
  rechterArm,
  linkesBein,
  rechtesBein,
}

/// Deutschsprachige Anzeigenamen fuer jede Wundzone.
const Map<WundZone, String> wundZoneLabel = {
  WundZone.kopf: 'Kopf',
  WundZone.brust: 'Brust',
  WundZone.bauch: 'Bauch',
  WundZone.ruecken: 'Rücken',
  WundZone.linkerArm: 'Linker Arm',
  WundZone.rechterArm: 'Rechter Arm',
  WundZone.linkesBein: 'Linkes Bein',
  WundZone.rechtesBein: 'Rechtes Bein',
};

/// Maximale Wundenanzahl je Zone.
const int maxWundenProZone = 3;

/// Laufzeitzustand der Wunden eines Helden.
///
/// Speichert die Anzahl Wunden pro Koerperzone sowie den kumulierten
/// gewuerfelten INI-Malus fuer Kopfwunden (Summe aller 2W6-Wuerfe).
class WundZustand {
  const WundZustand({
    this.wundenProZone = const <WundZone, int>{},
    this.kopfIniMalus = 0,
  });

  /// Anzahl Wunden je Zone (0–3). Fehlende Zonen = 0 Wunden.
  final Map<WundZone, int> wundenProZone;

  /// Kumulierter gewuerfelter INI-Malus fuer Kopfwunden.
  ///
  /// Wird bei jeder neuen Kopfwunde um den gewuerfelten 2W6-Wert erhoeht.
  /// Beim Entfernen einer Kopfwunde wird der anteilige Durchschnitt
  /// (aufgerundet) abgezogen.
  final int kopfIniMalus;

  /// Gibt die Wundenanzahl in der angegebenen [zone] zurueck.
  int wundenInZone(WundZone zone) => wundenProZone[zone] ?? 0;

  /// Gesamtzahl aller Wunden ueber alle Zonen.
  int get gesamtWunden {
    var total = 0;
    for (final count in wundenProZone.values) {
      total += count;
    }
    return total;
  }

  /// Erstellt eine Kopie mit optional ersetzten Feldern.
  WundZustand copyWith({
    Map<WundZone, int>? wundenProZone,
    int? kopfIniMalus,
  }) {
    return WundZustand(
      wundenProZone: wundenProZone ?? this.wundenProZone,
      kopfIniMalus: kopfIniMalus ?? this.kopfIniMalus,
    );
  }

  /// Fuegt eine Wunde in [zone] hinzu (max [maxWundenProZone]).
  ///
  /// Fuer Kopfwunden muss [iniWuerfelWert] den gewuerfelten 2W6-Wert
  /// enthalten; fuer andere Zonen wird er ignoriert.
  WundZustand mitWundeHinzu(WundZone zone, {int iniWuerfelWert = 0}) {
    final aktuell = wundenInZone(zone);
    if (aktuell >= maxWundenProZone) return this;
    final naechste = Map<WundZone, int>.of(wundenProZone);
    naechste[zone] = aktuell + 1;
    final naechsterIniMalus = zone == WundZone.kopf
        ? kopfIniMalus + iniWuerfelWert
        : kopfIniMalus;
    return WundZustand(
      wundenProZone: naechste,
      kopfIniMalus: naechsterIniMalus,
    );
  }

  /// Entfernt eine Wunde aus [zone] (min 0).
  ///
  /// Bei Kopfwunden wird der anteilige INI-Malus (aufgerundet) abgezogen.
  WundZustand mitWundeEntfernt(WundZone zone) {
    final aktuell = wundenInZone(zone);
    if (aktuell <= 0) return this;
    final naechste = Map<WundZone, int>.of(wundenProZone);
    naechste[zone] = aktuell - 1;
    if (naechste[zone] == 0) naechste.remove(zone);
    var naechsterIniMalus = kopfIniMalus;
    if (zone == WundZone.kopf && kopfIniMalus > 0 && aktuell > 0) {
      final anteil = (kopfIniMalus / aktuell).ceil();
      naechsterIniMalus = (kopfIniMalus - anteil).clamp(0, kopfIniMalus);
    }
    return WundZustand(
      wundenProZone: naechste,
      kopfIniMalus: naechsterIniMalus,
    );
  }

  /// Serialisierung fuer Persistenz.
  Map<String, dynamic> toJson() {
    final zonenMap = <String, dynamic>{};
    for (final entry in wundenProZone.entries) {
      if (entry.value > 0) {
        zonenMap[entry.key.name] = entry.value;
      }
    }
    return {
      'wundenProZone': zonenMap,
      'kopfIniMalus': kopfIniMalus,
    };
  }

  /// Robust gegen fehlende oder unbekannte Schluessel.
  static WundZustand fromJson(Map<String, dynamic> json) {
    final rawZonen =
        (json['wundenProZone'] as Map?)?.cast<String, dynamic>() ?? const {};
    final zonenMap = <WundZone, int>{};
    for (final zone in WundZone.values) {
      final wert = (rawZonen[zone.name] as num?)?.toInt() ?? 0;
      if (wert > 0) {
        zonenMap[zone] = wert.clamp(0, maxWundenProZone);
      }
    }
    return WundZustand(
      wundenProZone: zonenMap,
      kopfIniMalus: (json['kopfIniMalus'] as num?)?.toInt() ?? 0,
    );
  }
}
