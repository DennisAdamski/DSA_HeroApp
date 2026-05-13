import 'package:dsa_heldenverwaltung/catalog/catalog_json_helpers.dart';
import 'package:dsa_heldenverwaltung/catalog/rule_meta.dart';

/// Katalogisierte Definition eines Vorteils oder Nachteils.
///
/// Der Typ speichert bewusst nur Auswahl- und Referenzdaten. Regelwirkungen
/// bleiben in den bestehenden Parsern und Regelmodulen, damit die Helden-
/// Speicherung weiterhin kompatibel über `vorteileText` und `nachteileText`
/// funktioniert.
class HeroTraitDef {
  const HeroTraitDef({
    required this.id,
    required this.name,
    required this.traitType,
    this.costText = '',
    this.valueKind = 'binary',
    this.minValue,
    this.maxValue,
    this.unit = '',
    this.selectionTemplate = '',
    this.markers = const <String>[],
    this.source = '',
    this.active = true,
    this.ruleMeta,
  });

  /// Stabile Katalog-ID.
  final String id;

  /// Anzeigename aus der Vor-/Nachteil-Übersicht.
  final String name;

  /// `advantage` oder `disadvantage`.
  final String traitType;

  /// GP-Angabe oder Kostenhinweis als Quellenfakt.
  final String costText;

  /// Auswahlart: `binary`, `level`, `points`, `choice` oder Kombination.
  final String valueKind;

  /// Kleinster sinnvoller Zahlenwert für Auswahl-Dialoge.
  final int? minValue;

  /// Größter sinnvoller Zahlenwert für Auswahl-Dialoge.
  final int? maxValue;

  /// Kurze Einheit für Zahlenwerte, z. B. `LeP`, `AsP` oder `Stufe`.
  final String unit;

  /// Textvorlage für die kompatible Speicherung im Heldenmodell.
  final String selectionTemplate;

  /// Marker aus der Übersicht, z. B. `M(ZH)`, `SE`, `Gabe` oder `*`.
  final List<String> markers;

  /// Kurze Quellenreferenz für Admin- und Auswahl-UI.
  final String source;

  /// Ob der Eintrag grundsätzlich auswählbar ist.
  final bool active;

  /// Strukturierte Herkunfts- und Freischaltmetadaten.
  final RuleMeta? ruleMeta;

  /// Deserialisiert einen Vorteil/Nachteil tolerant aus JSON.
  factory HeroTraitDef.fromJson(Map<String, dynamic> json) {
    final ruleMetaJson = readCatalogObject(json, 'ruleMeta');
    return HeroTraitDef(
      id: readCatalogString(json, 'id', fallback: ''),
      name: readCatalogString(json, 'name', fallback: ''),
      traitType: readCatalogString(json, 'traitType', fallback: ''),
      costText: readCatalogString(json, 'costText', fallback: ''),
      valueKind: readCatalogString(json, 'valueKind', fallback: 'binary'),
      minValue: _readNullableInt(json, 'minValue'),
      maxValue: _readNullableInt(json, 'maxValue'),
      unit: readCatalogString(json, 'unit', fallback: ''),
      selectionTemplate: readCatalogString(
        json,
        'selectionTemplate',
        fallback: '',
      ),
      markers: readCatalogStringList(json, 'markers'),
      source: readCatalogString(json, 'source', fallback: ''),
      active: readCatalogBool(json, 'active', fallback: true),
      ruleMeta: ruleMetaJson == null ? null : RuleMeta.fromJson(ruleMetaJson),
    );
  }

  /// Serialisiert den Eintrag in ein JSON-kompatibles Map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'traitType': traitType,
      'costText': costText,
      'valueKind': valueKind,
      if (minValue != null) 'minValue': minValue,
      if (maxValue != null) 'maxValue': maxValue,
      if (unit.isNotEmpty) 'unit': unit,
      'selectionTemplate': selectionTemplate,
      if (markers.isNotEmpty) 'markers': markers,
      'source': source,
      'active': active,
      if (ruleMeta != null) 'ruleMeta': ruleMeta!.toJson(),
    };
  }
}

int? _readNullableInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}
