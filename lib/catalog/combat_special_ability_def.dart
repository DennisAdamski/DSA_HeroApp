import 'package:dsa_heldenverwaltung/catalog/catalog_json_helpers.dart';
import 'package:dsa_heldenverwaltung/catalog/rule_meta.dart';

/// Definition einer Kampf-Sonderfertigkeit aus dem Regelkatalog.
///
/// Diese Eintraege werden aktuell als strukturierter Nachschlage-Katalog
/// geladen und koennen spaeter enger mit UI und Regelberechnungen
/// verknuepft werden.
class CombatSpecialAbilityDef {
  const CombatSpecialAbilityDef({
    required this.id,
    required this.name,
    this.gruppe = 'kampf',
    this.typ = 'sonderfertigkeit',
    this.stilTyp = '',
    this.seite = '',
    this.beschreibung = '',
    this.erklarungLang = '',
    this.voraussetzungen = '',
    this.verbreitung = '',
    this.kosten = '',
    this.aktiviertManoeverIds = const [],
    this.kampfwertBoni = const [],
    this.ruleMeta,
    this.quelle = '',
    this.hausregel = false,
    this.nurEpisch = false,
  });

  final String id; // Eindeutige ID (z. B. 'ksf_aufmerksamkeit')
  final String name; // Anzeigename
  final String gruppe; // Obergruppe, aktuell meist 'kampf'
  final String typ; // Typisierung, aktuell 'sonderfertigkeit'
  final String stilTyp; // Optionaler Stiltyp, z. B. 'waffenloser_kampfstil'
  final String seite; // Seitenreferenz im Regelwerk
  final String beschreibung; // Kurze Beschreibung
  final String erklarungLang; // Ausfuehrliche Regelbeschreibung
  final String voraussetzungen; // Erwerbsvoraussetzungen
  final String verbreitung; // Verbreitungsangabe laut Regelwerk
  final String kosten; // AP-Kosten laut Regelwerk
  final List<String> aktiviertManoeverIds; // Freigeschaltete Manoever-IDs
  final List<CombatSpecialAbilityBonusDef> kampfwertBoni; // Direkte Boni
  final RuleMeta? ruleMeta; // Strukturierte Herkunfts- und Freischaltmetadaten
  final String quelle; // Freitext-Quellreferenz (z. B. 'Wege des Schwerts S. 112')
  final bool hausregel; // Eintrag stammt aus einer Hausregel
  final bool nurEpisch; // Nur fuer episch eingestufte Helden verfuegbar

  /// Gibt an, ob der Eintrag einen regelwirksamen waffenlosen Kampfstil darstellt.
  bool get isUnarmedCombatStyle => stilTyp.trim() == 'waffenloser_kampfstil';

  /// Deserialisiert die Sonderfertigkeit tolerant aus JSON.
  factory CombatSpecialAbilityDef.fromJson(Map<String, dynamic> json) {
    final kampfwertBoniRaw = (json['kampfwert_boni'] as List?) ?? const [];
    final ruleMetaJson = readCatalogObject(json, 'ruleMeta');
    return CombatSpecialAbilityDef(
      id: readCatalogString(json, 'id', fallback: ''),
      name: readCatalogString(json, 'name', fallback: ''),
      gruppe: readCatalogString(json, 'gruppe', fallback: 'kampf'),
      typ: readCatalogString(json, 'typ', fallback: 'sonderfertigkeit'),
      stilTyp: readCatalogString(json, 'stil_typ', fallback: ''),
      seite: readCatalogString(json, 'seite', fallback: ''),
      beschreibung: readCatalogString(json, 'beschreibung', fallback: ''),
      erklarungLang: readCatalogString(json, 'erklarung_lang', fallback: ''),
      voraussetzungen: readCatalogString(json, 'voraussetzungen', fallback: ''),
      verbreitung: readCatalogString(json, 'verbreitung', fallback: ''),
      kosten: readCatalogString(json, 'kosten', fallback: ''),
      aktiviertManoeverIds: readCatalogStringList(
        json,
        'aktiviert_manoever_ids',
      ),
      kampfwertBoni: kampfwertBoniRaw
          .whereType<Map>()
          .map(
            (entry) => CombatSpecialAbilityBonusDef.fromJson(
              entry.cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
      ruleMeta: ruleMetaJson == null ? null : RuleMeta.fromJson(ruleMetaJson),
      quelle: readCatalogString(json, 'quelle', fallback: ''),
      hausregel: readCatalogBool(json, 'hausregel', fallback: false),
      nurEpisch: readCatalogBool(json, 'nurEpisch', fallback: false),
    );
  }

  /// Serialisiert die Sonderfertigkeit in ein JSON-kompatibles Map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'gruppe': gruppe,
      'typ': typ,
      'stil_typ': stilTyp,
      'seite': seite,
      'beschreibung': beschreibung,
      'erklarung_lang': erklarungLang,
      'voraussetzungen': voraussetzungen,
      'verbreitung': verbreitung,
      'kosten': kosten,
      'aktiviert_manoever_ids': aktiviertManoeverIds,
      'kampfwert_boni': kampfwertBoni
          .map((entry) => entry.toJson())
          .toList(growable: false),
      if (ruleMeta != null) 'ruleMeta': ruleMeta!.toJson(),
      if (quelle.isNotEmpty) 'quelle': quelle,
      if (hausregel) 'hausregel': true,
      if (nurEpisch) 'nurEpisch': true,
    };
  }
}

/// Beschreibt einen einfachen, direkt verrechenbaren Kampfwert-Bonus.
class CombatSpecialAbilityBonusDef {
  const CombatSpecialAbilityBonusDef({
    this.giltFuerTalent = '',
    this.atBonus = 0,
    this.paBonus = 0,
    this.iniMod = 0,
  });

  final String giltFuerTalent; // 'raufen', 'ringen', 'beide' oder 'wahl'
  final int atBonus;
  final int paBonus;
  final int iniMod;

  /// Deserialisiert einen Kampfwert-Bonus tolerant aus JSON.
  factory CombatSpecialAbilityBonusDef.fromJson(Map<String, dynamic> json) {
    return CombatSpecialAbilityBonusDef(
      giltFuerTalent: readCatalogString(json, 'gilt_fuer_talent', fallback: ''),
      atBonus: (json['at_bonus'] as num?)?.toInt() ?? 0,
      paBonus: (json['pa_bonus'] as num?)?.toInt() ?? 0,
      iniMod: (json['ini_mod'] as num?)?.toInt() ?? 0,
    );
  }

  /// Serialisiert den Bonus in ein JSON-kompatibles Map.
  Map<String, dynamic> toJson() {
    return {
      'gilt_fuer_talent': giltFuerTalent,
      'at_bonus': atBonus,
      'pa_bonus': paBonus,
      'ini_mod': iniMod,
    };
  }
}
