import 'package:dsa_heldenverwaltung/domain/combat_config/ranged_distance_band.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/ranged_projectile.dart';

/// Haelt alle zur Laufzeit geladenen DSA-Spielregeldaten.
///
/// Wird einmalig beim App-Start durch [CatalogLoader] aus den Split-JSON-
/// Assets befuellt und dann als unveraenderliches Objekt weitergegeben.
/// Der Katalog ist die zentrale Quelle fuer Talent-, Waffen-, Zauber- und
/// Manoeuverdefinitionen.
class RulesCatalog {
  const RulesCatalog({
    required this.version,
    required this.source,
    required this.talents,
    required this.spells,
    required this.weapons,
    this.maneuvers = const [],
    this.combatSpecialAbilities = const [],
    this.sprachen = const [],
    this.schriften = const [],
    this.metadata = const {},
  });

  final String version; // Katalogversion (z. B. 'house_rules_v1')
  final String source; // Quell-ID (z. B. Dateiname des Manifests)
  final List<TalentDef> talents; // Alle Talente (regulaer + Kampftalente)
  final List<SpellDef> spells; // Alle Zaubersprueche
  final List<WeaponDef> weapons; // Alle Waffendefinitionen
  final List<ManeuverDef> maneuvers; // Kampfmanöver (optional, kann leer sein)
  final List<CombatSpecialAbilityDef>
  combatSpecialAbilities; // Kampf-Sonderfertigkeiten
  final List<SpracheDef> sprachen; // Sprachdefinitionen
  final List<SchriftDef> schriften; // Schriftdefinitionen
  final Map<String, dynamic> metadata; // Sonstige Metadaten aus dem Manifest

  /// Sucht ein Manöver anhand des Namens (Groß-/Kleinschreibung wird ignoriert).
  ManeuverDef? maneuverByName(String name) {
    final needle = name.trim().toLowerCase();
    for (final m in maneuvers) {
      if (m.name.trim().toLowerCase() == needle) return m;
    }
    return null;
  }

  factory RulesCatalog.fromJson(Map<String, dynamic> json) {
    final talentsRaw = (json['talents'] as List?) ?? const [];
    final spellsRaw = (json['spells'] as List?) ?? const [];
    final weaponsRaw = (json['weapons'] as List?) ?? const [];
    final maneuversRaw = (json['maneuvers'] as List?) ?? const [];
    final combatSpecialAbilitiesRaw =
        (json['combatSpecialAbilities'] as List?) ?? const [];
    final sprachenRaw = (json['sprachen'] as List?) ?? const [];
    final schriftenRaw = (json['schriften'] as List?) ?? const [];

    return RulesCatalog(
      version: _readString(json, 'version', fallback: 'unknown'),
      source: _readString(json, 'source', fallback: 'unknown'),
      talents: talentsRaw
          .whereType<Map>()
          .map((entry) => TalentDef.fromJson(entry.cast<String, dynamic>()))
          .toList(growable: false),
      spells: spellsRaw
          .whereType<Map>()
          .map((entry) => SpellDef.fromJson(entry.cast<String, dynamic>()))
          .toList(growable: false),
      weapons: weaponsRaw
          .whereType<Map>()
          .map((entry) => WeaponDef.fromJson(entry.cast<String, dynamic>()))
          .toList(growable: false),
      maneuvers: maneuversRaw
          .whereType<Map>()
          .map((entry) => ManeuverDef.fromJson(entry.cast<String, dynamic>()))
          .toList(growable: false),
      combatSpecialAbilities: combatSpecialAbilitiesRaw
          .whereType<Map>()
          .map(
            (entry) =>
                CombatSpecialAbilityDef.fromJson(entry.cast<String, dynamic>()),
          )
          .toList(growable: false),
      sprachen: sprachenRaw
          .whereType<Map>()
          .map((entry) => SpracheDef.fromJson(entry.cast<String, dynamic>()))
          .toList(growable: false),
      schriften: schriftenRaw
          .whereType<Map>()
          .map((entry) => SchriftDef.fromJson(entry.cast<String, dynamic>()))
          .toList(growable: false),
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'source': source,
      'metadata': metadata,
      'talents': talents.map((entry) => entry.toJson()).toList(growable: false),
      'spells': spells.map((entry) => entry.toJson()).toList(growable: false),
      'weapons': weapons.map((entry) => entry.toJson()).toList(growable: false),
      'maneuvers': maneuvers
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'combatSpecialAbilities': combatSpecialAbilities
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'sprachen': sprachen
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'schriften': schriften
          .map((entry) => entry.toJson())
          .toList(growable: false),
    };
  }
}

/// Definition eines Kampfmanoeuvers aus dem Regelkatalog.
///
/// Manoever koennen Waffen ([WeaponDef.possibleManeuvers]) zugeordnet sein.
/// [erschwernis] enthaelt den Erschwernis-Wert als Freitext (z. B. '-4' oder '+0').
class ManeuverDef {
  const ManeuverDef({
    required this.id,
    required this.name,
    this.gruppe = '',
    this.typ = '',
    this.erschwernis = '',
    this.seite = '',
    this.erklarung = '',
    this.erklarungLang = '',
    this.voraussetzungen = '',
    this.verbreitung = '',
    this.kosten = '',
  });

  final String id; // Eindeutige ID (z. B. 'man_hammerschlag')
  final String name; // Anzeigename
  final String gruppe; // Kategorie (z. B. 'Angriff', 'Abwehr')
  final String
  typ; // Feinere Typisierung fuer die UI (z. B. 'Angriffsmanoever')
  final String erschwernis; // Erschwernis-Modifikator als Freitext
  final String seite; // Seitenreferenz im Regelwerk
  final String erklarung; // Regeltext / Beschreibung
  final String erklarungLang; // Ausfuehrliche Regelbeschreibung
  final String voraussetzungen; // Erwerbs- oder Einsatzvoraussetzungen
  final String verbreitung; // Verbreitungsangabe laut Regelwerk
  final String kosten; // AP-Kosten laut Regelwerk

  factory ManeuverDef.fromJson(Map<String, dynamic> json) {
    return ManeuverDef(
      id: _readString(json, 'id', fallback: ''),
      name: _readString(json, 'name', fallback: ''),
      gruppe: _readString(json, 'gruppe', fallback: ''),
      typ: _readString(json, 'typ', fallback: ''),
      erschwernis: _readString(json, 'erschwernis', fallback: ''),
      seite: _readString(json, 'seite', fallback: ''),
      erklarung: _readString(json, 'erklarung', fallback: ''),
      erklarungLang: _readString(json, 'erklarung_lang', fallback: ''),
      voraussetzungen: _readString(json, 'voraussetzungen', fallback: ''),
      verbreitung: _readString(json, 'verbreitung', fallback: ''),
      kosten: _readString(json, 'kosten', fallback: ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'gruppe': gruppe,
      'typ': typ,
      'erschwernis': erschwernis,
      'seite': seite,
      'erklarung': erklarung,
      'erklarung_lang': erklarungLang,
      'voraussetzungen': voraussetzungen,
      'verbreitung': verbreitung,
      'kosten': kosten,
    };
  }
}

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

  /// Gibt an, ob der Eintrag einen regelwirksamen waffenlosen Kampfstil darstellt.
  bool get isUnarmedCombatStyle => stilTyp.trim() == 'waffenloser_kampfstil';

  /// Deserialisiert die Sonderfertigkeit tolerant aus JSON.
  factory CombatSpecialAbilityDef.fromJson(Map<String, dynamic> json) {
    final kampfwertBoniRaw = (json['kampfwert_boni'] as List?) ?? const [];
    return CombatSpecialAbilityDef(
      id: _readString(json, 'id', fallback: ''),
      name: _readString(json, 'name', fallback: ''),
      gruppe: _readString(json, 'gruppe', fallback: 'kampf'),
      typ: _readString(json, 'typ', fallback: 'sonderfertigkeit'),
      stilTyp: _readString(json, 'stil_typ', fallback: ''),
      seite: _readString(json, 'seite', fallback: ''),
      beschreibung: _readString(json, 'beschreibung', fallback: ''),
      erklarungLang: _readString(json, 'erklarung_lang', fallback: ''),
      voraussetzungen: _readString(json, 'voraussetzungen', fallback: ''),
      verbreitung: _readString(json, 'verbreitung', fallback: ''),
      kosten: _readString(json, 'kosten', fallback: ''),
      aktiviertManoeverIds: _readStringList(json, 'aktiviert_manoever_ids'),
      kampfwertBoni: kampfwertBoniRaw
          .whereType<Map>()
          .map(
            (entry) => CombatSpecialAbilityBonusDef.fromJson(
              entry.cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
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
      giltFuerTalent: _readString(json, 'gilt_fuer_talent', fallback: ''),
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

/// Definition einer Sprache aus dem Regelkatalog.
///
/// [familie] bestimmt die dynamische Lernkomplexität:
/// – Sprache liegt in derselben Familie wie Muttersprache → A (außer [steigerung] ist 'B')
/// – Andere Familie oder keine Muttersprache → B
/// [steigerung] ist normalerweise 'A'; bei seltenen Sprachen (z. B. Asdharia)
/// ist es fest 'B'.
class SpracheDef {
  const SpracheDef({
    required this.id,
    required this.name,
    required this.familie,
    required this.maxWert,
    this.steigerung = 'A',
    this.schriftIds = const [],
    this.schriftlos = false,
    this.hinweise = '',
  });

  final String id; // Eindeutige ID (z. B. 'spr_garethi')
  final String name; // Anzeigename
  final String familie; // Sprachfamilie (z. B. 'Garethi-Familie')
  final int maxWert; // Maximaler Talentwert
  final String steigerung; // 'A' (Normalfall) oder 'B' (feste Komplexität)
  final List<String> schriftIds; // IDs zugehöriger Schriften
  final bool schriftlos; // true → keine Schrift vorhanden
  final String hinweise; // Freitext-Sonderregeln

  factory SpracheDef.fromJson(Map<String, dynamic> json) {
    return SpracheDef(
      id: _readString(json, 'id', fallback: ''),
      name: _readString(json, 'name', fallback: ''),
      familie: _readString(json, 'familie', fallback: ''),
      maxWert: _readInt(json, 'maxWert', fallback: 18),
      steigerung: _readString(json, 'steigerung', fallback: 'A'),
      schriftIds: _readStringList(json, 'schriftIds'),
      schriftlos: _readBool(json, 'schriftlos', fallback: false),
      hinweise: _readString(json, 'hinweise', fallback: ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'familie': familie,
      'maxWert': maxWert,
      'steigerung': steigerung,
      'schriftIds': schriftIds,
      'schriftlos': schriftlos,
      'hinweise': hinweise,
    };
  }
}

/// Definition einer Schrift aus dem Regelkatalog.
///
/// [steigerung] bestimmt die AP-Kosten pro Talentwert-Punkt ('A', 'B' oder 'C').
class SchriftDef {
  const SchriftDef({
    required this.id,
    required this.name,
    required this.maxWert,
    this.beschreibung = '',
    this.steigerung = 'A',
    this.hinweise = '',
  });

  final String id; // Eindeutige ID (z. B. 'sch_kusliker_zeichen')
  final String name; // Anzeigename
  final int maxWert; // Maximaler Talentwert
  final String beschreibung; // Kurzbeschreibung (z. B. '31 Lautzeichen')
  final String steigerung; // AP-Steigerungskategorie ('A', 'B' oder 'C')
  final String hinweise; // Freitext-Sonderregeln

  factory SchriftDef.fromJson(Map<String, dynamic> json) {
    return SchriftDef(
      id: _readString(json, 'id', fallback: ''),
      name: _readString(json, 'name', fallback: ''),
      maxWert: _readInt(json, 'maxWert', fallback: 10),
      beschreibung: _readString(json, 'beschreibung', fallback: ''),
      steigerung: _readString(json, 'steigerung', fallback: 'A'),
      hinweise: _readString(json, 'hinweise', fallback: ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'maxWert': maxWert,
      'beschreibung': beschreibung,
      'steigerung': steigerung,
      'hinweise': hinweise,
    };
  }
}

/// Definition eines Talents aus dem Regelkatalog.
///
/// Unterscheidung normale Talente vs. Kampftalente erfolgt ueber
/// [group] ('Kampftalent'), [weaponCategory] (nicht-leer) oder
/// [type] ('nahkampf' / 'fernkampf').
///
/// [steigerung] ist der Steigerungsfaktor der DSA-Steigungstabelle
/// (z. B. 'B', 'C', 'D', 'E', 'F') – bestimmt AP-Kosten pro TaW-Punkt.
/// [be] beschreibt den Behinderungseinfluss: '-' = keiner, '-2' = feste
/// Reduktion, 'xBE' = Vielfaches der Ruestungsbehinderung.
class TalentDef {
  const TalentDef({
    required this.id,
    required this.name,
    required this.group,
    required this.steigerung,
    required this.attributes,
    this.type = '',
    this.be = '',
    this.weaponCategory = '',
    this.alternatives = '',
    this.source = '',
    this.description = '',
    this.active = true,
  });

  final String id; // Eindeutige ID (z. B. 'tal_empathie')
  final String name; // Anzeigename
  final String group; // Gruppe ('Kampftalent', 'Gabe', 'Koerper', …)
  final String steigerung; // AP-Steigerungskategorie ('B'–'F')
  final List<String> attributes; // Drei Eigenschaftskuerzel fuer Proben
  final String type; // Talenttyp ('nahkampf', 'fernkampf', 'Gabe', …)
  final String be; // Behinderungsformel ('-', '-N', 'xN' oder '')
  final String weaponCategory; // Waffenkategorie fuer Spezialisierungsabgleich
  final String alternatives; // Alternative Kategorienamen (kommagetrennt)
  final String source; // Quellreferenz (Seitenzahl o. Ae.)
  final String description; // Regelbeschreibung als Freitext
  final bool active; // Im App verfuegbar und anzeigbar?

  factory TalentDef.fromJson(Map<String, dynamic> json) {
    return TalentDef(
      id: _readString(json, 'id', fallback: ''),
      name: _readString(json, 'name', fallback: ''),
      group: _readString(json, 'group', fallback: ''),
      steigerung: _readString(json, 'steigerung', fallback: 'B'),
      attributes: _readStringList(json, 'attributes'),
      type: _readString(json, 'type', fallback: ''),
      be: _readString(json, 'be', fallback: ''),
      weaponCategory: _readString(json, 'weaponCategory', fallback: ''),
      alternatives: _readString(json, 'alternatives', fallback: ''),
      source: _readString(json, 'source', fallback: ''),
      description: _readString(json, 'description', fallback: ''),
      active: _readBool(json, 'active', fallback: true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'group': group,
      'steigerung': steigerung,
      'attributes': attributes,
      'type': type,
      'be': be,
      'weaponCategory': weaponCategory,
      'alternatives': alternatives,
      'source': source,
      'description': description,
      'active': active,
    };
  }
}

/// Definition eines Zauberspruchs aus dem Regelkatalog.
///
/// [steigerung] entspricht dem AP-Steigerungsfaktor (analog zu [TalentDef]).
/// [aspCost] enthaelt die Kosten in Astralpunkten als Formel-String
/// (z. B. '4' oder '4W6').
/// [modifier] beschreibt moegliche Erschwernisse oder Erleichterungen.
class SpellDef {
  const SpellDef({
    required this.id,
    required this.name,
    required this.tradition,
    required this.steigerung,
    required this.attributes,
    this.availability = '',
    this.traits = '',
    this.modifier = '',
    this.castingTime = '',
    this.aspCost = '',
    this.targetObject = '',
    this.range = '',
    this.duration = '',
    this.modifications = '',
    this.wirkung = '',
    this.variants = const [],
    this.category = '',
    this.source = '',
    this.active = true,
  });

  final String id;
  final String name;
  final String tradition; // Magie-Tradition (z. B. 'Gildenmagie')
  final String steigerung; // AP-Steigerungskategorie ('A'–'F')
  final List<String> attributes; // Eigenschaftskuerzel fuer Zauberprobe
  final String availability; // Verfuegbarkeit (Verbreitung)
  final String traits; // Zaubereigenschaften (z. B. 'Beruehrung, Blitz')
  final String modifier; // Erschwernis/Erleichterung als Freitext
  final String castingTime; // Zauberdauer (z. B. '2 Aktionen')
  final String aspCost; // AsP-Kosten als Freitext-Formel (z. B. '4W6')
  final String targetObject; // Zielobjekt laut Regelwerk
  final String range; // Reichweite
  final String duration; // Wirkungsdauer
  final String modifications; // Modifikationsoptionen fuer den Zauber
  final String wirkung; // Wirkungsbeschreibung (Langtext aus dem Regelwerk)
  final List<String> variants; // Definierte Varianten des Zaubers
  final String category; // Zauberkategorie
  final String source; // Quellreferenz (z. B. 'Liber Cantiones S. 36')
  final bool active; // Im App verfuegbar und anzeigbar?

  factory SpellDef.fromJson(Map<String, dynamic> json) {
    return SpellDef(
      id: _readString(json, 'id', fallback: ''),
      name: _readString(json, 'name', fallback: ''),
      tradition: _readString(json, 'tradition', fallback: ''),
      steigerung: _readString(json, 'steigerung', fallback: 'C'),
      attributes: _readStringList(json, 'attributes'),
      availability: _readString(json, 'availability', fallback: ''),
      traits: _readString(json, 'traits', fallback: ''),
      modifier: _readString(json, 'modifier', fallback: ''),
      castingTime: _readString(json, 'castingTime', fallback: ''),
      aspCost: _readString(json, 'aspCost', fallback: ''),
      targetObject: _readString(json, 'targetObject', fallback: ''),
      range: _readString(json, 'range', fallback: ''),
      duration: _readString(json, 'duration', fallback: ''),
      modifications: _readString(json, 'modifications', fallback: ''),
      wirkung: _readString(json, 'wirkung', fallback: ''),
      variants: _readStringList(json, 'variants'),
      category: _readString(json, 'category', fallback: ''),
      source: _readString(json, 'source', fallback: ''),
      active: _readBool(json, 'active', fallback: true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'tradition': tradition,
      'steigerung': steigerung,
      'attributes': attributes,
      'availability': availability,
      'traits': traits,
      'modifier': modifier,
      'castingTime': castingTime,
      'aspCost': aspCost,
      'targetObject': targetObject,
      'range': range,
      'duration': duration,
      'modifications': modifications,
      'wirkung': wirkung,
      'variants': variants,
      'category': category,
      'source': source,
      'active': active,
    };
  }
}

/// Definition einer Waffe aus dem Regelkatalog.
///
/// [combatSkill] verweist auf den Namen des zugehoerigen Kampftalents.
/// [tp] enthaelt die Schadens-Formel als Freitext (z. B. '1W6+4').
/// [tpkk] beschreibt die KK-abhaengige TP-Skalierung im DSA-Format
/// (z. B. '12/6' bedeutet: ab KK 12, ein TP-Schritt pro 6 KK-Punkte).
/// [atMod] und [paMod] sind waffenspezifische Angriffs- und Parade-Boni.
class WeaponDef {
  const WeaponDef({
    required this.id,
    required this.name,
    required this.type,
    required this.combatSkill,
    required this.tp,
    this.complexity = '',
    this.weaponCategory = '',
    this.possibleManeuvers = const [],
    this.activeManeuvers = const [],
    this.tpkk = '',
    this.iniMod = 0,
    this.atMod = 0,
    this.paMod = 0,
    this.reloadTime = 0,
    this.rangedDistanceBands = const <RangedDistanceBand>[],
    this.rangedProjectiles = const <RangedProjectile>[],
    this.reach = '',
    this.source = '',
    this.active = true,
  });

  final String id;
  final String name;
  final String type; // 'Nahkampf' oder 'Fernkampf'
  final String combatSkill; // Verknuepftes Kampftalent (Name)
  final String tp; // Schadens-Formel (z. B. '1W6+4')
  final String complexity; // Waffenkomplexitaet
  final String weaponCategory; // Kategorie fuer Spezialisierungsabgleich
  final List<String> possibleManeuvers; // Alle verfuegbaren Manöver-IDs
  final List<String> activeManeuvers; // Standardmaessig aktive Manöver-IDs
  final String tpkk; // KK-Skalierung im Format 'Basis/Schritt'
  final int iniMod; // Waffenspezifischer Initiative-Modifier
  final int atMod; // Waffenspezifischer Angriff-Modifier
  final int paMod; // Waffenspezifischer Parade-Modifier
  final int reloadTime; // Feste Ladezeit fuer Fernkampfwaffen
  final List<RangedDistanceBand> rangedDistanceBands; // Distanzstufen
  final List<RangedProjectile> rangedProjectiles; // Geschossvorlagen
  final String reach; // Reichweite / Distanzklasse
  final String source; // Quellreferenz
  final bool active; // Im App verfuegbar und anzeigbar?

  factory WeaponDef.fromJson(Map<String, dynamic> json) {
    final type = _readString(json, 'type', fallback: '');
    final rawDistanceBands =
        (json['rangedDistanceBands'] as List?) ?? const <dynamic>[];
    final rawProjectiles =
        (json['rangedProjectiles'] as List?) ??
        (json['projectiles'] as List?) ??
        const <dynamic>[];
    final hasAtMod = json.containsKey('atMod') && json['atMod'] != null;
    return WeaponDef(
      id: _readString(json, 'id', fallback: ''),
      name: _readString(json, 'name', fallback: ''),
      type: type,
      combatSkill: _readString(json, 'combatSkill', fallback: ''),
      tp: _readString(json, 'tp', fallback: ''),
      complexity: _readString(json, 'complexity', fallback: ''),
      weaponCategory: _readString(json, 'weaponCategory', fallback: ''),
      possibleManeuvers: _readStringList(json, 'possibleManeuvers'),
      activeManeuvers: _readStringList(json, 'activeManeuvers'),
      tpkk: _readString(json, 'tpkk', fallback: ''),
      iniMod: _readInt(json, 'iniMod', fallback: 0),
      atMod: hasAtMod
          ? _readInt(json, 'atMod', fallback: 0)
          : _readInt(
              json,
              'fkMod',
              fallback: type.trim().toLowerCase() == 'fernkampf'
                  ? 0
                  : _readInt(json, 'atMod', fallback: 0),
            ),
      paMod: _readInt(json, 'paMod', fallback: 0),
      reloadTime: _readInt(json, 'reloadTime', fallback: 0),
      rangedDistanceBands: rawDistanceBands
          .whereType<Map>()
          .map(
            (entry) =>
                RangedDistanceBand.fromJson(entry.cast<String, dynamic>()),
          )
          .toList(growable: false),
      rangedProjectiles: rawProjectiles
          .whereType<Map>()
          .map(
            (entry) => RangedProjectile.fromJson(entry.cast<String, dynamic>()),
          )
          .toList(growable: false),
      reach: _readString(json, 'reach', fallback: ''),
      source: _readString(json, 'source', fallback: ''),
      active: _readBool(json, 'active', fallback: true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'combatSkill': combatSkill,
      'tp': tp,
      'complexity': complexity,
      'weaponCategory': weaponCategory,
      'possibleManeuvers': possibleManeuvers,
      'activeManeuvers': activeManeuvers,
      'tpkk': tpkk,
      'iniMod': iniMod,
      'atMod': atMod,
      'paMod': paMod,
      'reloadTime': reloadTime,
      'rangedDistanceBands': rangedDistanceBands
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'rangedProjectiles': rangedProjectiles
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'reach': reach,
      'source': source,
      'active': active,
    };
  }
}

// Liest einen String-Wert lenient: nicht-String-Werte werden via toString()
// konvertiert, null ergibt den Fallback. So bleiben alte Schemata lesbar.
String _readString(
  Map<String, dynamic> json,
  String key, {
  required String fallback,
}) {
  final value = json[key];
  if (value is String) {
    return value;
  }
  if (value == null) {
    return fallback;
  }
  return value.toString();
}

// Liest einen int-Wert lenient: num wird via toInt() konvertiert (kürzt
// Nachkommastellen). Nützlich, wenn JSON-Dateien Floats statt Ints enthalten.
int _readInt(Map<String, dynamic> json, String key, {required int fallback}) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return fallback;
}

// Liest einen bool-Wert; jeder Nicht-Bool-Wert ergibt den Fallback.
bool _readBool(
  Map<String, dynamic> json,
  String key, {
  required bool fallback,
}) {
  final value = json[key];
  if (value is bool) {
    return value;
  }
  return fallback;
}

// Liest eine JSON-Liste als String-Liste. Nicht-Listen ergeben eine leere
// konstante Liste. Jedes Element wird via toString() konvertiert, um
// typentolerante JSON-Quellen zu unterstuetzen.
List<String> _readStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    return const [];
  }
  return value.map((entry) => entry.toString()).toList(growable: false);
}

/// Die neun DSA-Repraesentationen (Kuerzel fuer Zaubertradition).
const List<String> kRepresentationen = [
  'Ach', // Achaz
  'Bor', // Borbaradianer
  'Dru', // Druide
  'Elf', // Elf
  'Geo', // Geode
  'Hex', // Hexe
  'Mag', // Gildenmagier
  'Sch', // Schelm
  'Srl', // Scharlatane
];

/// Alle 34 bekannten Zauber-Merkmale aus dem Katalog.
const List<String> kMerkmale = [
  'Antimagie',
  'Beschwörung',
  'Dämonisch (Amazeroth)',
  'Dämonisch (Asfaloth)',
  'Dämonisch (Blakharaz)',
  'Dämonisch (Lolgramoth)',
  'Dämonisch (Mishkara)',
  'Dämonisch (Thargunitoth)',
  'Dämonisch (allgemein)',
  'Eigenschaften',
  'Einfluss',
  'Elementar (Eis)',
  'Elementar (Erz)',
  'Elementar (Feuer)',
  'Elementar (Humus)',
  'Elementar (Luft)',
  'Elementar (Wasser)',
  'Elementar (allgemein)',
  'Form',
  'Geisterwesen',
  'Heilung',
  'Hellsicht',
  'Herbeirufung',
  'Herrschaft',
  'Illusion',
  'Kraft',
  'Limbus',
  'Metamagie',
  'Objekt',
  'Schaden',
  'Telekinese',
  'Temporal',
  'Umwelt',
  'Verständigung',
];
