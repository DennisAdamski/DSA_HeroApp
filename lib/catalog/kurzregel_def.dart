import 'package:dsa_heldenverwaltung/catalog/catalog_crypto.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_json_helpers.dart';

/// Ein Themenbereich des Kurzregel-Kompendiums (Schluessel und Anzeigename).
class KurzregelThema {
  const KurzregelThema(this.schluessel, this.label);

  /// Stabiler Schluessel, wie er in `kurzregeln.json` unter `thema` steht.
  final String schluessel;

  /// Anzeigename fuer Filter-Chips und Detailansicht.
  final String label;
}

/// Bekannte Themenbereiche in Anzeigereihenfolge.
///
/// Unbekannte Schluessel aus dem Katalog bleiben lesbar: [kurzregelThemaLabel]
/// faellt dann auf den Rohwert zurueck, damit neue Themen ohne App-Update
/// angezeigt werden koennen.
const List<KurzregelThema> kurzregelThemen = <KurzregelThema>[
  KurzregelThema('kampf', 'Kampf'),
  KurzregelThema('zustaende', 'Zustände'),
  KurzregelThema('wunden', 'Wunden'),
  KurzregelThema('proben', 'Proben'),
  KurzregelThema('fernkampf', 'Fernkampf'),
  KurzregelThema('reiten', 'Reiten'),
  KurzregelThema('umgebung', 'Sicht & Umgebung'),
  KurzregelThema('heilung', 'Heilung'),
  KurzregelThema('magie', 'Magie'),
];

/// Anzeigename zu einem Themenschluessel; unbekannte Schluessel unveraendert.
String kurzregelThemaLabel(String schluessel) {
  for (final thema in kurzregelThemen) {
    if (thema.schluessel == schluessel) {
      return thema.label;
    }
  }
  return schluessel;
}

/// Beleg wie `Wege des Schwerts, S. 112` oder `Liber Cantiones S. 23-24`.
final RegExp _belegMitSeite = RegExp(r'\S.*\bS\.\s?\d+');

/// Kurze, eigenformulierte Regelzusammenfassung fuer den Spieltisch.
///
/// Eintraege sind reine Nachschlagetexte: die Regelberechnung der App liest
/// kein Feld dieser Klasse. Die Langtexte ([kurztext], [hinweise],
/// [hausregelText]) liegen im Asset v3-verschluesselt (siehe
/// `PROTECTED_FIELDS` in `tool/encrypt_catalog_fields.py`); Titel, Thema,
/// Schlagworte und Quellenbelege sind Klartext, damit Liste und Filter auch
/// ohne Passwort funktionieren.
///
/// Offizielle Regel ([kurztext], Beleg in [quellen], Bezug DSA 4.1) und
/// Hausregel ([hausregelText], Beleg in [hausregelQuelle]) sind getrennte
/// Felder, damit die Oberflaeche beides unterscheidbar zeigen kann.
class KurzregelDef {
  const KurzregelDef({
    required this.id,
    required this.titel,
    this.thema = '',
    this.schlagworte = const <String>[],
    this.quellen = const <String>[],
    this.kurztext = '',
    this.hinweise = const <String>[],
    this.hausregelText = '',
    this.hausregelQuelle = '',
    this.gesperrt = false,
  });

  /// Stabile Kennung, eindeutig im Kompendium.
  final String id;

  /// Anzeigetitel, z. B. der Name eines Manoevers oder Zustands.
  final String titel;

  /// Themenschluessel, siehe [kurzregelThemen].
  final String thema;

  /// Zusaetzliche Suchbegriffe (Klartext), z. B. Synonyme.
  final List<String> schlagworte;

  /// Quellenbelege der offiziellen Regel, je Eintrag `Buch, S. <Seite>`.
  final List<String> quellen;

  /// Eigene Kurzfassung der offiziellen Regel (DSA 4.1).
  final String kurztext;

  /// Zusaetzliche Stichpunkte (Sonderfaelle, Erschwernisse).
  final List<String> hinweise;

  /// Abweichung durch Hausregeln; leer, wenn die Hausregeln nichts aendern.
  final String hausregelText;

  /// Beleg der Hausregel, z. B. die Kennung des Hausregel-Pakets.
  final String hausregelQuelle;

  /// true, wenn Langtexte vorhanden, aber ohne Passwort nicht lesbar sind.
  final bool gesperrt;

  /// Ob der Eintrag eine Hausregel-Abweichung traegt.
  ///
  /// Zaehlt auch die Klartext-Quelle, damit die Kennzeichnung in der Liste
  /// bei gesperrten Texten sichtbar bleibt.
  bool get hatHausregel =>
      hausregelText.isNotEmpty || hausregelQuelle.trim().isNotEmpty;

  /// Liest einen Eintrag aus (bereits entschluesseltem) JSON.
  ///
  /// Noch verschluesselte Werte (`enc:`) ergeben leere Texte und setzen
  /// [gesperrt], statt Chiffretext anzuzeigen.
  factory KurzregelDef.fromJson(Map<String, dynamic> json) {
    var gesperrt = false;
    String text(String key) {
      final wert = readCatalogString(json, key, fallback: '');
      if (isEncryptedValue(wert)) {
        gesperrt = true;
        return '';
      }
      return wert;
    }

    List<String> liste(String key) {
      final roh = json[key];
      if (roh is String && isEncryptedValue(roh)) {
        gesperrt = true;
        return const <String>[];
      }
      return readCatalogStringList(json, key);
    }

    return KurzregelDef(
      id: readCatalogString(json, 'id', fallback: ''),
      titel: readCatalogString(json, 'titel', fallback: ''),
      thema: readCatalogString(json, 'thema', fallback: ''),
      schlagworte: readCatalogStringList(json, 'schlagworte'),
      quellen: readCatalogStringList(json, 'quellen'),
      kurztext: text('kurztext'),
      hinweise: liste('hinweise'),
      hausregelText: text('hausregel_text'),
      hausregelQuelle: readCatalogString(
        json,
        'hausregel_quelle',
        fallback: '',
      ),
      gesperrt: gesperrt,
    );
  }

  /// Probleme, die den Eintrag unbrauchbar machen (leer = gueltig).
  ///
  /// Kern der Quellenpflicht: ein Eintrag ohne Buch- und Seitenbeleg wird
  /// vom Lader verworfen und faellt im Katalogtest auf.
  List<String> get probleme {
    final befunde = <String>[];
    if (id.trim().isEmpty) {
      befunde.add('id fehlt');
    }
    if (titel.trim().isEmpty) {
      befunde.add('titel fehlt');
    }
    if (quellen.isEmpty) {
      befunde.add('quellen fehlen');
    }
    for (final beleg in quellen) {
      if (!_belegMitSeite.hasMatch(beleg)) {
        befunde.add('quelle ohne Seitenangabe: "$beleg"');
      }
    }
    if (hausregelText.isNotEmpty && hausregelQuelle.trim().isEmpty) {
      befunde.add('hausregel_quelle fehlt');
    }
    return befunde;
  }
}
