/// Statische Beschreibung einer Hausregel-Gruppe.
///
/// Hausregeln werden im Katalog ueber [RuleMeta.sourceKey] identifiziert.
/// Ein Descriptor liefert die Anzeigeinformationen fuer die Einstellungen
/// und verankert die Hierarchie ueber [parentSourceKey]. Der Zustand, ob
/// ein Hausregel-Paket aktiv ist, liegt in [AppSettings.disabledHouseRulePackIds]
/// und wird vom Provider-Layer ausgewertet.
class HouseRuleDescriptor {
  const HouseRuleDescriptor({
    required this.sourceKey,
    required this.title,
    required this.description,
    this.parentSourceKey,
    this.enabledByDefault = true,
  });

  /// Stabiler Schluessel, identisch mit [RuleMeta.sourceKey] im Katalog.
  final String sourceKey;

  /// Optionaler Parent-Schluessel. Ist der Parent deaktiviert, gilt auch
  /// dieser Descriptor als deaktiviert (Sub-Zustand bleibt dennoch erhalten).
  final String? parentSourceKey;

  /// Anzeigename in der Einstellungen-UI.
  final String title;

  /// Kurze Beschreibung fuer die Einstellungen-UI.
  final String description;

  /// Default-Zustand, wenn noch keine Benutzerentscheidung vorliegt.
  final bool enabledByDefault;

  bool get isRoot => parentSourceKey == null;
}
