/// Dauerhaftes Journal offener Vorgänge mit mehreren Schreibzugriffen
/// (ARCH-06).
///
/// Ein Vorgang, der mehrere Objekte nacheinander schreibt (etwa Bilder,
/// Bogen und Zustand beim Import), vermerkt sich hier **vor** dem ersten
/// Schreibzugriff und nach jedem Schritt; erst wenn alles geschrieben ist,
/// wird der Eintrag erledigt. Bricht die App dazwischen ab, findet der
/// Wiederanlauf beim nächsten Start den Eintrag und führt den Vorgang zu Ende
/// oder gleicht ihn aus (`lib/ablaeufe/vorgaenge_wiederaufnehmen.dart`).
///
/// Die Einträge sind rohe JSON-Maps; ihre Bedeutung legt allein der Ablauf
/// fest, der sie schreibt. Die Schnittstelle ist bewusst frei von Hive, damit
/// Abläufe sie ohne Datenschicht verwenden können.
abstract interface class Vorgangsjournal {
  /// Legt den Eintrag [vorgangId] an oder ersetzt ihn vollständig.
  Future<void> merke(String vorgangId, Map<String, Object?> eintrag);

  /// Entfernt den Eintrag [vorgangId]; ein fehlender Eintrag ist kein Fehler.
  Future<void> erledige(String vorgangId);

  /// Alle offenen Einträge, nach Vorgangs-ID.
  Future<Map<String, Map<String, Object?>>> offene();
}

/// Journal im Arbeitsspeicher, für Tests und als Vorgabe ohne Heldenspeicher.
///
/// Überdauert keinen Neustart; der App-Start übersteuert es mit
/// `HiveVorgangsjournal`.
class SpeicherVorgangsjournal implements Vorgangsjournal {
  final Map<String, Map<String, Object?>> _eintraege =
      <String, Map<String, Object?>>{};

  @override
  Future<void> merke(String vorgangId, Map<String, Object?> eintrag) async {
    _eintraege[vorgangId] = Map<String, Object?>.unmodifiable(eintrag);
  }

  @override
  Future<void> erledige(String vorgangId) async {
    _eintraege.remove(vorgangId);
  }

  @override
  Future<Map<String, Map<String, Object?>>> offene() async {
    return Map<String, Map<String, Object?>>.of(_eintraege);
  }
}
