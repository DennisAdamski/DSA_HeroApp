import 'package:dsa_heldenverwaltung/catalog/catalog_json_helpers.dart';
import 'package:dsa_heldenverwaltung/catalog/rule_meta.dart';

/// Definition einer Sonderfertigkeit (allgemein, magisch oder karmal)
/// aus dem Regelkatalog.
///
/// Bewusst ein einziger Typ fuer alle drei Sektionen, da die Regelwerke
/// strukturell identische Angaben liefern. Die konkrete Zugehoerigkeit
/// entscheidet die Katalogsektion ([CatalogSectionId]), nicht dieser Typ.
class SpecialAbilityDef {
  const SpecialAbilityDef({
    required this.id,
    required this.name,
    this.gruppe = '',
    this.typ = 'sonderfertigkeit',
    this.kategorie = '',
    this.seite = '',
    this.beschreibung = '',
    this.erklarungLang = '',
    this.voraussetzungen = '',
    this.verbreitung = '',
    this.kosten = '',
    this.quelle = '',
    this.hausregel = false,
    this.nurEpisch = false,
    this.mehrfachwaehlbar = false,
    this.variantenLabel = '',
    this.varianten = const <String>[],
    this.variantenFreitext = true,
    this.apErstwerb,
    this.apFolgeerwerb,
    this.ruleMeta,
  });

  final String id; // Eindeutige ID (z. B. 'asf_wachsamkeit')
  final String name; // Anzeigename
  final String gruppe; // Obergruppe laut Regelwerk
  final String typ; // Typisierung, meist 'sonderfertigkeit'
  final String kategorie; // Optionale Unterkategorie (z. B. Schule, Ritus)
  final String seite; // Seitenreferenz im Regelwerk
  final String beschreibung; // Kurze Beschreibung
  final String erklarungLang; // Ausfuehrliche Regelbeschreibung
  final String voraussetzungen; // Erwerbsvoraussetzungen
  final String verbreitung; // Verbreitungsangabe laut Regelwerk
  final String kosten; // AP-Kosten laut Regelwerk
  final String quelle; // Freitext-Quellreferenz (z. B. 'Wege der Zauberei S. 140')
  final bool hausregel; // Eintrag stammt aus einer Hausregel
  final bool nurEpisch; // Nur fuer episch eingestufte Helden verfuegbar

  /// Die Sonderfertigkeit darf mehrfach erworben werden — jeweils fuer eine
  /// andere Variante (z. B. Kulturkunde je Kultur, Gelaendekunde je Gelaende).
  final bool mehrfachwaehlbar;

  /// Beschriftung des Auswahlfelds im Erwerbsdialog, z. B. 'Kultur'.
  final String variantenLabel;

  /// Katalogisierte Auswahlvorschlaege fuer die Variante. Darf leer sein,
  /// wenn es keine feste Liste gibt (z. B. Ortskenntnis).
  final List<String> varianten;

  /// Ob zusaetzlich zur Liste eine freie Eingabe erlaubt ist.
  final bool variantenFreitext;

  /// AP-Vorschlag fuer den ersten Erwerb. `null` faellt auf den ersten
  /// AP-Betrag aus [kosten] zurueck.
  final int? apErstwerb;

  /// AP-Vorschlag fuer jeden weiteren Erwerb (gestaffelte Kosten).
  final int? apFolgeerwerb;

  final RuleMeta? ruleMeta; // Strukturierte Herkunfts- und Freischaltmetadaten

  /// Deserialisiert die Sonderfertigkeit tolerant aus JSON.
  factory SpecialAbilityDef.fromJson(Map<String, dynamic> json) {
    final ruleMetaJson = readCatalogObject(json, 'ruleMeta');
    return SpecialAbilityDef(
      id: readCatalogString(json, 'id', fallback: ''),
      name: readCatalogString(json, 'name', fallback: ''),
      gruppe: readCatalogString(json, 'gruppe', fallback: ''),
      typ: readCatalogString(json, 'typ', fallback: 'sonderfertigkeit'),
      kategorie: readCatalogString(json, 'kategorie', fallback: ''),
      seite: readCatalogString(json, 'seite', fallback: ''),
      beschreibung: readCatalogString(json, 'beschreibung', fallback: ''),
      erklarungLang: readCatalogString(json, 'erklarung_lang', fallback: ''),
      voraussetzungen: readCatalogString(json, 'voraussetzungen', fallback: ''),
      verbreitung: readCatalogString(json, 'verbreitung', fallback: ''),
      kosten: readCatalogString(json, 'kosten', fallback: ''),
      quelle: readCatalogString(json, 'quelle', fallback: ''),
      hausregel: readCatalogBool(json, 'hausregel', fallback: false),
      nurEpisch: readCatalogBool(json, 'nurEpisch', fallback: false),
      mehrfachwaehlbar: readCatalogBool(
        json,
        'mehrfachwaehlbar',
        fallback: false,
      ),
      variantenLabel: readCatalogString(
        json,
        'varianten_label',
        fallback: '',
      ),
      varianten: readCatalogStringList(json, 'varianten'),
      variantenFreitext: readCatalogBool(
        json,
        'varianten_freitext',
        fallback: true,
      ),
      apErstwerb: _readNullableInt(json, 'ap_erstwerb'),
      apFolgeerwerb: _readNullableInt(json, 'ap_folgeerwerb'),
      ruleMeta: ruleMetaJson == null ? null : RuleMeta.fromJson(ruleMetaJson),
    );
  }

  /// Serialisiert die Sonderfertigkeit in ein JSON-kompatibles Map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'gruppe': gruppe,
      'typ': typ,
      if (kategorie.isNotEmpty) 'kategorie': kategorie,
      'seite': seite,
      'beschreibung': beschreibung,
      'erklarung_lang': erklarungLang,
      'voraussetzungen': voraussetzungen,
      'verbreitung': verbreitung,
      'kosten': kosten,
      if (quelle.isNotEmpty) 'quelle': quelle,
      if (hausregel) 'hausregel': true,
      if (nurEpisch) 'nurEpisch': true,
      if (mehrfachwaehlbar) 'mehrfachwaehlbar': true,
      if (variantenLabel.isNotEmpty) 'varianten_label': variantenLabel,
      if (varianten.isNotEmpty) 'varianten': varianten,
      if (!variantenFreitext) 'varianten_freitext': false,
      if (apErstwerb != null) 'ap_erstwerb': apErstwerb,
      if (apFolgeerwerb != null) 'ap_folgeerwerb': apFolgeerwerb,
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
