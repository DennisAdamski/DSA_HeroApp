import 'package:dsa_heldenverwaltung/catalog/catalog_json_helpers.dart';
import 'package:dsa_heldenverwaltung/catalog/rule_meta.dart';

import 'special_ability_entry.dart';
import 'special_ability_requirement.dart';

/// Definition eines Kampfmanoeuvers aus dem Regelkatalog.
///
/// Manoever koennen Waffen ([WeaponDef.possibleManeuvers]) zugeordnet sein.
/// [erschwernis] enthaelt den Erschwernis-Wert als Freitext (z. B. '-4' oder '+0').
/// Fernkampf-Manoever mit [mussSeparatErlerntWerden] werden pro aktivem FK-Talent
/// einzeln aktiviert; die gespeicherte ID lautet dann `<id>::<talentId>`.
class ManeuverDef implements SpecialAbilityEntry {
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
    this.nurFuerTalente = const <String>[],
    this.mussSeparatErlerntWerden = false,
    this.giltFuerTalentTyp = '',
    this.ruleMeta,
    this.quelle = '',
    this.hausregel = false,
    this.nurEpisch = false,
    this.voraussetzungenStruktur = const [],
  });

  @override
  final String id;
  @override
  final String name;
  final String gruppe;
  final String typ;
  final String erschwernis;
  final String seite;
  final String erklarung;
  final String erklarungLang;
  final String voraussetzungen;
  final String verbreitung;
  @override
  final String kosten;

  /// Schraenkt Sichtbarkeit auf bestimmte Talent-IDs ein.
  /// Leer = gilt fuer alle Talente des [giltFuerTalentTyp].
  final List<String> nurFuerTalente;

  /// Wenn true: muss fuer jedes FK-Talent separat aktiviert werden.
  /// Gespeicherte ID: `<id>::<talentId>`.
  final bool mussSeparatErlerntWerden;

  /// Talenttyp-Filter fuer [mussSeparatErlerntWerden] (z. B. 'fernkampf').
  final String giltFuerTalentTyp;
  final RuleMeta? ruleMeta; // Strukturierte Herkunfts- und Freischaltmetadaten
  final String
  quelle; // Freitext-Quellreferenz (z. B. 'Wege des Schwerts S. 112')
  final bool hausregel; // Eintrag stammt aus einer Hausregel
  @override
  final bool nurEpisch; // Nur fuer episch eingestufte Helden verfuegbar

  @override
  final List<SpecialAbilityRequirement> voraussetzungenStruktur;

  /// Manöver werden über ihre eigene Katalog-ID und ihren Namen aufgelöst.
  @override
  List<String> get alleNamen => [name];

  /// Manöverabhängigkeiten stehen ausdrücklich in ihren Voraussetzungen.
  @override
  SpecialAbilityChainRef? get kette => null;

  factory ManeuverDef.fromJson(Map<String, dynamic> json) {
    final ruleMetaJson = readCatalogObject(json, 'ruleMeta');
    return ManeuverDef(
      id: readCatalogString(json, 'id', fallback: ''),
      name: readCatalogString(json, 'name', fallback: ''),
      gruppe: readCatalogString(json, 'gruppe', fallback: ''),
      typ: readCatalogString(json, 'typ', fallback: ''),
      erschwernis: readCatalogString(json, 'erschwernis', fallback: ''),
      seite: readCatalogString(json, 'seite', fallback: ''),
      erklarung: readCatalogString(json, 'erklarung', fallback: ''),
      erklarungLang: readCatalogString(json, 'erklarung_lang', fallback: ''),
      voraussetzungen: readCatalogString(json, 'voraussetzungen', fallback: ''),
      verbreitung: readCatalogString(json, 'verbreitung', fallback: ''),
      kosten: readCatalogString(json, 'kosten', fallback: ''),
      nurFuerTalente: readCatalogStringList(json, 'nur_fuer_talente'),
      mussSeparatErlerntWerden: readCatalogBool(
        json,
        'muss_separat_erlernt_werden',
        fallback: false,
      ),
      giltFuerTalentTyp: readCatalogString(
        json,
        'gilt_fuer_talent_typ',
        fallback: '',
      ),
      ruleMeta: ruleMetaJson == null ? null : RuleMeta.fromJson(ruleMetaJson),
      quelle: readCatalogString(json, 'quelle', fallback: ''),
      hausregel: readCatalogBool(json, 'hausregel', fallback: false),
      nurEpisch: readCatalogBool(json, 'nurEpisch', fallback: false),
      voraussetzungenStruktur: readCatalogObjectList(
        json,
        'voraussetzungen_struktur',
      ).map(SpecialAbilityRequirement.fromJson).toList(growable: false),
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
      if (voraussetzungenStruktur.isNotEmpty)
        'voraussetzungen_struktur': voraussetzungenStruktur
            .map((requirement) => requirement.toJson())
            .toList(growable: false),
      if (nurFuerTalente.isNotEmpty) 'nur_fuer_talente': nurFuerTalente,
      if (mussSeparatErlerntWerden) 'muss_separat_erlernt_werden': true,
      if (giltFuerTalentTyp.isNotEmpty)
        'gilt_fuer_talent_typ': giltFuerTalentTyp,
      if (ruleMeta != null) 'ruleMeta': ruleMeta!.toJson(),
      if (quelle.isNotEmpty) 'quelle': quelle,
      if (hausregel) 'hausregel': true,
      if (nurEpisch) 'nurEpisch': true,
    };
  }
}
