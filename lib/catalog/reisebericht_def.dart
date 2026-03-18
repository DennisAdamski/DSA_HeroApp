import 'package:dsa_heldenverwaltung/catalog/catalog_json_helpers.dart';

/// Definition eines Reisebericht-Eintrags aus dem Regelkatalog.
///
/// Jeder Eintrag gehoert zu einer Kategorie (z. B. 'kampferfahrungen') und
/// einem Typ (z. B. 'checkpoint', 'multi_requirement'). Je nach Typ sind
/// unterschiedliche Felder befuellt.
class ReiseberichtDef {
  const ReiseberichtDef({
    required this.id,
    required this.name,
    required this.kategorie,
    required this.typ,
    this.beschreibung = '',
    this.ap = 0,
    this.se = const [],
    this.anforderungen = const [],
    this.apProEintrag = 0,
    this.apProEintragAlternativ,
    this.apAlternativBedingung = '',
    this.schwelle = 0,
    this.schwelleBelohnung,
    this.festeEintraege = const [],
    this.bonus,
    this.seIntervall = 0,
    this.klassifikationen = const [],
    this.gruppeId = '',
    this.stufe = 0,
    this.eigenschaftsBonus = const [],
  });

  /// Eindeutige ID (z. B. 'rb_anfuehrer').
  final String id;

  /// Anzeigename.
  final String name;

  /// Kategorie-Schluessel (z. B. 'kampferfahrungen').
  final String kategorie;

  /// Eintragstyp: 'checkpoint', 'multi_requirement', 'collection_fixed',
  /// 'collection_open', 'grouped_progression', 'grouped_progression_bonus',
  /// 'meta'.
  final String typ;

  /// Beschreibung / Erklaerungstext.
  final String beschreibung;

  /// AP-Belohnung fuer 'checkpoint' und 'grouped_progression'.
  final int ap;

  /// SE-Belohnungen.
  final List<ReiseberichtSeDef> se;

  /// Sub-Items fuer 'multi_requirement'.
  final List<ReiseberichtAnforderungDef> anforderungen;

  /// AP pro abgehaktem Eintrag fuer 'collection_fixed' / 'collection_open'.
  final int apProEintrag;

  /// Alternativer AP-Wert (z. B. fuer Zauberer bei Traditionskundig).
  final int? apProEintragAlternativ;

  /// Bedingungstext fuer den alternativen AP-Wert.
  final String apAlternativBedingung;

  /// Schwelle fuer den Haupterfolg (Anzahl abgehakter Eintraege).
  final int schwelle;

  /// Belohnung bei Schwellenerreichung.
  final ReiseberichtBonusDef? schwelleBelohnung;

  /// Feste Eintraege fuer 'collection_fixed'.
  final List<ReiseberichtFesteintragDef> festeEintraege;

  /// Zusaetzlicher Bonus (z. B. 'Stadtkenner extrem').
  final ReiseberichtBonusDef? bonus;

  /// SE-Vergabe-Intervall fuer 'collection_open' (SE alle N Eintraege).
  final int seIntervall;

  /// AP-Klassifikationen fuer 'collection_open' (z. B. Kulturtypen).
  final List<ReiseberichtKlassifikationDef> klassifikationen;

  /// Gruppen-ID fuer 'grouped_progression' / 'grouped_progression_bonus'.
  final String gruppeId;

  /// Stufe innerhalb einer Progressionsgruppe.
  final int stufe;

  /// Permanente Eigenschaftsboni fuer 'meta'-Eintraege.
  final List<ReiseberichtEigenschaftsBonusDef> eigenschaftsBonus;

  factory ReiseberichtDef.fromJson(Map<String, dynamic> json) {
    final seRaw = json['se'] as List? ?? const [];
    final anforderungenRaw = json['anforderungen'] as List? ?? const [];
    final festeEintraegeRaw = json['feste_eintraege'] as List? ?? const [];
    final klassifikationenRaw = json['klassifikationen'] as List? ?? const [];
    final eigenschaftsBonusRaw =
        json['eigenschafts_bonus'] as List? ?? const [];

    final schwelleBelohnungRaw = json['schwelle_belohnung'];
    final bonusRaw = json['bonus'];

    return ReiseberichtDef(
      id: readCatalogString(json, 'id', fallback: ''),
      name: readCatalogString(json, 'name', fallback: ''),
      kategorie: readCatalogString(json, 'kategorie', fallback: ''),
      typ: readCatalogString(json, 'typ', fallback: 'checkpoint'),
      beschreibung: readCatalogString(json, 'beschreibung', fallback: ''),
      ap: readCatalogInt(json, 'ap', fallback: 0),
      se: seRaw
          .whereType<Map>()
          .map(
            (entry) =>
                ReiseberichtSeDef.fromJson(entry.cast<String, dynamic>()),
          )
          .toList(growable: false),
      anforderungen: anforderungenRaw
          .whereType<Map>()
          .map(
            (entry) => ReiseberichtAnforderungDef.fromJson(
              entry.cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
      apProEintrag: readCatalogInt(json, 'ap_pro_eintrag', fallback: 0),
      apProEintragAlternativ: json['ap_pro_eintrag_alternativ'] is num
          ? (json['ap_pro_eintrag_alternativ'] as num).toInt()
          : null,
      apAlternativBedingung: readCatalogString(
        json,
        'ap_alternativ_bedingung',
        fallback: '',
      ),
      schwelle: readCatalogInt(json, 'schwelle', fallback: 0),
      schwelleBelohnung: schwelleBelohnungRaw is Map
          ? ReiseberichtBonusDef.fromJson(
              schwelleBelohnungRaw.cast<String, dynamic>(),
            )
          : null,
      festeEintraege: festeEintraegeRaw
          .whereType<Map>()
          .map(
            (entry) => ReiseberichtFesteintragDef.fromJson(
              entry.cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
      bonus: bonusRaw is Map
          ? ReiseberichtBonusDef.fromJson(bonusRaw.cast<String, dynamic>())
          : null,
      seIntervall: readCatalogInt(json, 'se_intervall', fallback: 0),
      klassifikationen: klassifikationenRaw
          .whereType<Map>()
          .map(
            (entry) => ReiseberichtKlassifikationDef.fromJson(
              entry.cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
      gruppeId: readCatalogString(json, 'gruppe_id', fallback: ''),
      stufe: readCatalogInt(json, 'stufe', fallback: 0),
      eigenschaftsBonus: eigenschaftsBonusRaw
          .whereType<Map>()
          .map(
            (entry) => ReiseberichtEigenschaftsBonusDef.fromJson(
              entry.cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{
      'id': id,
      'name': name,
      'kategorie': kategorie,
      'typ': typ,
      'beschreibung': beschreibung,
    };
    if (ap > 0) result['ap'] = ap;
    if (se.isNotEmpty) {
      result['se'] = se.map((entry) => entry.toJson()).toList(growable: false);
    }
    if (anforderungen.isNotEmpty) {
      result['anforderungen'] =
          anforderungen.map((entry) => entry.toJson()).toList(growable: false);
    }
    if (apProEintrag > 0) result['ap_pro_eintrag'] = apProEintrag;
    if (apProEintragAlternativ != null) {
      result['ap_pro_eintrag_alternativ'] = apProEintragAlternativ;
    }
    if (apAlternativBedingung.isNotEmpty) {
      result['ap_alternativ_bedingung'] = apAlternativBedingung;
    }
    if (schwelle > 0) result['schwelle'] = schwelle;
    if (schwelleBelohnung != null) {
      result['schwelle_belohnung'] = schwelleBelohnung!.toJson();
    }
    if (festeEintraege.isNotEmpty) {
      result['feste_eintraege'] =
          festeEintraege.map((entry) => entry.toJson()).toList(growable: false);
    }
    if (bonus != null) result['bonus'] = bonus!.toJson();
    if (seIntervall > 0) result['se_intervall'] = seIntervall;
    if (klassifikationen.isNotEmpty) {
      result['klassifikationen'] =
          klassifikationen.map((entry) => entry.toJson()).toList(
            growable: false,
          );
    }
    if (gruppeId.isNotEmpty) result['gruppe_id'] = gruppeId;
    if (stufe > 0) result['stufe'] = stufe;
    if (eigenschaftsBonus.isNotEmpty) {
      result['eigenschafts_bonus'] =
          eigenschaftsBonus.map((entry) => entry.toJson()).toList(
            growable: false,
          );
    }
    return result;
  }
}

/// SE-Zuordnung innerhalb eines Reisebericht-Eintrags.
class ReiseberichtSeDef {
  const ReiseberichtSeDef({
    required this.ziel,
    required this.name,
    this.optionen = const [],
  });

  /// Zieltyp: 'talent', 'grundwert', 'wahl'.
  final String ziel;

  /// Anzeigename des Ziels (z. B. 'Kriegskunst', 'Passende SE').
  final String name;

  /// Auswahl-Optionen fuer 'wahl'-Ziele (z. B. ['Reiten', 'Fliegen']).
  final List<String> optionen;

  factory ReiseberichtSeDef.fromJson(Map<String, dynamic> json) {
    return ReiseberichtSeDef(
      ziel: readCatalogString(json, 'ziel', fallback: 'talent'),
      name: readCatalogString(json, 'name', fallback: ''),
      optionen: readCatalogStringList(json, 'optionen'),
    );
  }

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{'ziel': ziel, 'name': name};
    if (optionen.isNotEmpty) result['optionen'] = optionen;
    return result;
  }
}

/// Sub-Item fuer 'multi_requirement'-Eintraege.
class ReiseberichtAnforderungDef {
  const ReiseberichtAnforderungDef({
    required this.id,
    required this.name,
    this.ap = 0,
    this.se = const [],
  });

  final String id;
  final String name;
  final int ap;
  final List<ReiseberichtSeDef> se;

  factory ReiseberichtAnforderungDef.fromJson(Map<String, dynamic> json) {
    final seRaw = json['se'] as List? ?? const [];
    return ReiseberichtAnforderungDef(
      id: readCatalogString(json, 'id', fallback: ''),
      name: readCatalogString(json, 'name', fallback: ''),
      ap: readCatalogInt(json, 'ap', fallback: 0),
      se: seRaw
          .whereType<Map>()
          .map(
            (entry) =>
                ReiseberichtSeDef.fromJson(entry.cast<String, dynamic>()),
          )
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{'id': id, 'name': name};
    if (ap > 0) result['ap'] = ap;
    if (se.isNotEmpty) {
      result['se'] = se.map((entry) => entry.toJson()).toList(growable: false);
    }
    return result;
  }
}

/// Fester Eintrag fuer 'collection_fixed'.
class ReiseberichtFesteintragDef {
  const ReiseberichtFesteintragDef({required this.id, required this.name});

  final String id;
  final String name;

  factory ReiseberichtFesteintragDef.fromJson(Map<String, dynamic> json) {
    return ReiseberichtFesteintragDef(
      id: readCatalogString(json, 'id', fallback: ''),
      name: readCatalogString(json, 'name', fallback: ''),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

/// Bonus-Definition fuer Schwellen und Zusatzbelohnungen.
class ReiseberichtBonusDef {
  const ReiseberichtBonusDef({
    this.id = '',
    this.name = '',
    this.beschreibung = '',
    this.schwelle = 0,
    this.ap = 0,
    this.se = const [],
    this.talentBoni = const [],
  });

  final String id;
  final String name;
  final String beschreibung;
  final int schwelle;
  final int ap;
  final List<ReiseberichtSeDef> se;
  final List<ReiseberichtTalentBonusDef> talentBoni;

  factory ReiseberichtBonusDef.fromJson(Map<String, dynamic> json) {
    final seRaw = json['se'] as List? ?? const [];
    final talentBoniRaw = json['talent_boni'] as List? ?? const [];
    return ReiseberichtBonusDef(
      id: readCatalogString(json, 'id', fallback: ''),
      name: readCatalogString(json, 'name', fallback: ''),
      beschreibung: readCatalogString(json, 'beschreibung', fallback: ''),
      schwelle: readCatalogInt(json, 'schwelle', fallback: 0),
      ap: readCatalogInt(json, 'ap', fallback: 0),
      se: seRaw
          .whereType<Map>()
          .map(
            (entry) =>
                ReiseberichtSeDef.fromJson(entry.cast<String, dynamic>()),
          )
          .toList(growable: false),
      talentBoni: talentBoniRaw
          .whereType<Map>()
          .map(
            (entry) => ReiseberichtTalentBonusDef.fromJson(
              entry.cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{};
    if (id.isNotEmpty) result['id'] = id;
    if (name.isNotEmpty) result['name'] = name;
    if (beschreibung.isNotEmpty) result['beschreibung'] = beschreibung;
    if (schwelle > 0) result['schwelle'] = schwelle;
    if (ap > 0) result['ap'] = ap;
    if (se.isNotEmpty) {
      result['se'] = se.map((entry) => entry.toJson()).toList(growable: false);
    }
    if (talentBoni.isNotEmpty) {
      result['talent_boni'] =
          talentBoni.map((entry) => entry.toJson()).toList(growable: false);
    }
    return result;
  }
}

/// Permanenter Talentbonus aus einer Reisebericht-Belohnung.
class ReiseberichtTalentBonusDef {
  const ReiseberichtTalentBonusDef({
    required this.talentName,
    required this.wert,
  });

  final String talentName;
  final int wert;

  factory ReiseberichtTalentBonusDef.fromJson(Map<String, dynamic> json) {
    return ReiseberichtTalentBonusDef(
      talentName: readCatalogString(json, 'talent_name', fallback: ''),
      wert: readCatalogInt(json, 'wert', fallback: 0),
    );
  }

  Map<String, dynamic> toJson() => {'talent_name': talentName, 'wert': wert};
}

/// Permanenter Eigenschaftsbonus aus Meta-Erfolgen.
class ReiseberichtEigenschaftsBonusDef {
  const ReiseberichtEigenschaftsBonusDef({
    required this.eigenschaft,
    required this.wert,
    this.optionen = const [],
  });

  /// Eigenschaftscode ('mu', 'kl', etc.) oder 'wahl' bei Auswahl.
  final String eigenschaft;

  /// Bonus-Wert (typisch 1).
  final int wert;

  /// Auswahl-Optionen fuer 'wahl' (z. B. ['KL', 'IN']).
  final List<String> optionen;

  factory ReiseberichtEigenschaftsBonusDef.fromJson(
    Map<String, dynamic> json,
  ) {
    return ReiseberichtEigenschaftsBonusDef(
      eigenschaft: readCatalogString(json, 'eigenschaft', fallback: ''),
      wert: readCatalogInt(json, 'wert', fallback: 0),
      optionen: readCatalogStringList(json, 'optionen'),
    );
  }

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{
      'eigenschaft': eigenschaft,
      'wert': wert,
    };
    if (optionen.isNotEmpty) result['optionen'] = optionen;
    return result;
  }
}

/// AP-Klassifikation fuer 'collection_open' mit variablen AP.
class ReiseberichtKlassifikationDef {
  const ReiseberichtKlassifikationDef({
    required this.id,
    required this.name,
    required this.ap,
  });

  final String id;
  final String name;
  final int ap;

  factory ReiseberichtKlassifikationDef.fromJson(Map<String, dynamic> json) {
    return ReiseberichtKlassifikationDef(
      id: readCatalogString(json, 'id', fallback: ''),
      name: readCatalogString(json, 'name', fallback: ''),
      ap: readCatalogInt(json, 'ap', fallback: 0),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'ap': ap};
}
