import 'package:dsa_heldenverwaltung/catalog/catalog_json_helpers.dart';

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
      id: readCatalogString(json, 'id', fallback: ''),
      name: readCatalogString(json, 'name', fallback: ''),
      gruppe: readCatalogString(json, 'gruppe', fallback: ''),
      typ: readCatalogString(json, 'typ', fallback: ''),
      erschwernis: readCatalogString(json, 'erschwernis', fallback: ''),
      seite: readCatalogString(json, 'seite', fallback: ''),
      erklarung: readCatalogString(json, 'erklarung', fallback: ''),
      erklarungLang: readCatalogString(json, 'erklarung_lang', fallback: ''),
      voraussetzungen: readCatalogString(
        json,
        'voraussetzungen',
        fallback: '',
      ),
      verbreitung: readCatalogString(json, 'verbreitung', fallback: ''),
      kosten: readCatalogString(json, 'kosten', fallback: ''),
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
