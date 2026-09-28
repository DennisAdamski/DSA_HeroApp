import 'package:dsa_heldenverwaltung/catalog/catalog_json_helpers.dart';
import 'package:dsa_heldenverwaltung/catalog/hero_trait_effect.dart';
import 'package:dsa_heldenverwaltung/catalog/rule_meta.dart';

/// Katalogisierte Definition eines Vorteils oder Nachteils.
///
/// Neben Auswahl- und Referenzdaten traegt der Eintrag seine Regelwirkungen
/// deklarativ in [wirkungen]. Gerechnet wird damit ausschliesslich in
/// `lib/rules/derived/hero_merkmal_rules.dart`; der Held speichert erworbene
/// Merkmale ueber die stabile [id] (`HeroSheet.vorteilEintraege`/
/// `nachteilEintraege`) und schreibt `vorteileText`/`nachteileText` nur noch
/// als Projektion fuer aeltere App-Versionen.
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
    this.choiceLabel = '',
    this.choices = const <String>[],
    this.choiceSource = '',
    this.choiceFreeText = true,
    this.markers = const <String>[],
    this.source = '',
    this.active = true,
    this.ruleMeta,
    this.wirkungen = const <HeroTraitEffect>[],
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

  /// Beschriftung des `{choice}`-Felds, z. B. `Sinn` oder `Geltungsbereich`.
  /// Leer bedeutet die generische Beschriftung `Spezialisierung`.
  final String choiceLabel;

  /// Feste Auswahlliste für `{choice}`. Leer heißt: keine Vorschläge.
  final List<String> choices;

  /// Katalogabgeleitete Auswahlliste, aufgelöst über `resolveTraitChoices`
  /// (`lib/catalog/hero_trait_choices.dart`). Leer heißt: keine.
  final String choiceSource;

  /// Ob neben der Liste weiterhin freie Eingabe erlaubt ist. Der Default `true`
  /// entspricht dem bisherigen Verhalten (reines Textfeld).
  final bool choiceFreeText;

  /// Marker aus der Übersicht, z. B. `M(ZH)`, `SE`, `Gabe` oder `*`.
  final List<String> markers;

  /// Kurze Quellenreferenz für Admin- und Auswahl-UI.
  final String source;

  /// Ob der Eintrag grundsätzlich auswählbar ist.
  final bool active;

  /// Strukturierte Herkunfts- und Freischaltmetadaten.
  final RuleMeta? ruleMeta;

  /// Deklarative Regelwirkungen; leer bei rein beschreibenden Merkmalen.
  final List<HeroTraitEffect> wirkungen;

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
      choiceLabel: readCatalogString(json, 'choiceLabel', fallback: ''),
      choices: readCatalogStringList(json, 'choices'),
      choiceSource: readCatalogString(json, 'choiceSource', fallback: ''),
      choiceFreeText: readCatalogBool(json, 'choiceFreeText', fallback: true),
      markers: readCatalogStringList(json, 'markers'),
      source: readCatalogString(json, 'source', fallback: ''),
      active: readCatalogBool(json, 'active', fallback: true),
      ruleMeta: ruleMetaJson == null ? null : RuleMeta.fromJson(ruleMetaJson),
      wirkungen: readCatalogObjectList(
        json,
        'wirkungen',
      ).map(HeroTraitEffect.fromJson).toList(growable: false),
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
      if (choiceLabel.isNotEmpty) 'choiceLabel': choiceLabel,
      if (choices.isNotEmpty) 'choices': choices,
      if (choiceSource.isNotEmpty) 'choiceSource': choiceSource,
      if (!choiceFreeText) 'choiceFreeText': choiceFreeText,
      if (markers.isNotEmpty) 'markers': markers,
      'source': source,
      'active': active,
      if (ruleMeta != null) 'ruleMeta': ruleMeta!.toJson(),
      if (wirkungen.isNotEmpty)
        'wirkungen': wirkungen.map((wirkung) => wirkung.toJson()).toList(),
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
