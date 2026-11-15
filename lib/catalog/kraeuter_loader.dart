import 'package:dsa_heldenverwaltung/catalog/catalog_crypto.dart';
import 'package:dsa_heldenverwaltung/catalog/json_asset.dart';
import 'package:dsa_heldenverwaltung/domain/aventurian_date.dart';
import 'package:dsa_heldenverwaltung/domain/kraeuter_eintrag.dart';

/// Asset der Kräutertabellen (Wege des Entdeckers S. 114–118).
///
/// Erzeugt von `tool/import_kraeuter.py`. Kurzfakten (Name, Bestimmung,
/// Häufigkeit je Landschaft, einzeilige Wirkung, Fundstelle) stehen im
/// Klartext; die Kurzbeschreibung `beschreibung` ist v3-verschlüsselt (Harte
/// Regel 13, `tool/encrypt_catalog_fields.py`).
const String kraeuterAssetPfad = 'assets/catalogs/house_rules_v1/kraeuter.json';

/// Liest die Rohdaten des Assets: ein Objekt mit der Liste `kraeuter` und
/// optional `stand`.
///
/// Je Eintrag: `name`, `bestimmung` (ganze Zahl), `vorkommen` (nichtleere
/// Liste aus `landschaft` und `haeufigkeit`, optional `hinweis`), optional
/// `wirkung`, `gebiet`, `bestimmungHinweis`, `erntezeit`, `erntemonate`
/// (Monatsschlüssel; fehlt das Feld, ist das Kraut ganzjährig zu ernten),
/// `grundmenge`, `quelle`, `beschreibung`. Ein unvollständiger Eintrag
/// landet in [KraeuterKatalog.verworfen] statt halb gelesen zu werden.
///
/// Mit dem v3-Katalogschlüssel [schluessel] wird `beschreibung`
/// entschlüsselt; ohne Schlüssel oder bei falschem Passwort bleibt sie leer
/// und [KrautEintrag.beschreibungGesperrt] ist gesetzt.
KraeuterKatalog parseKraeuter(Object? roh, {CatalogKey? schluessel}) {
  if (roh is! Map || roh['kraeuter'] is! List) return const KraeuterKatalog();
  final liste = roh['kraeuter'] as List<dynamic>;
  final kraeuter = <KrautEintrag>[];
  final verworfen = <String>[];
  String text(Object? wert) => wert is String ? wert.trim() : '';
  for (var i = 0; i < liste.length; i++) {
    final eintrag = liste[i];
    if (eintrag is! Map) {
      verworfen.add('#$i: kein Objekt');
      continue;
    }
    final name = text(eintrag['name']);
    final bestimmung = eintrag['bestimmung'];
    if (name.isEmpty || bestimmung is! int) {
      verworfen.add('#$i: Name oder Bestimmung fehlt');
      continue;
    }
    final rohVorkommen = eintrag['vorkommen'];
    if (rohVorkommen is! List || rohVorkommen.isEmpty) {
      verworfen.add('#$i ($name): Vorkommen fehlt');
      continue;
    }
    final vorkommen = <KrautVorkommen>[];
    var vorkommenOk = true;
    for (final roh in rohVorkommen) {
      final landschaft = roh is Map
          ? Kraeuterlandschaft.ausSchluessel(roh['landschaft'])
          : null;
      final haeufigkeit = roh is Map
          ? Kraeuterhaeufigkeit.ausSchluessel(roh['haeufigkeit'])
          : null;
      if (roh is! Map || landschaft == null || haeufigkeit == null) {
        vorkommenOk = false;
        break;
      }
      vorkommen.add(
        KrautVorkommen(
          landschaft: landschaft,
          haeufigkeit: haeufigkeit,
          hinweis: text(roh['hinweis']),
        ),
      );
    }
    if (!vorkommenOk) {
      verworfen.add('#$i ($name): Vorkommen ungültig');
      continue;
    }
    final (beschreibung, gesperrt) = _beschreibung(
      eintrag['beschreibung'],
      schluessel,
    );
    kraeuter.add(
      KrautEintrag(
        name: name,
        bestimmung: bestimmung,
        vorkommen: List<KrautVorkommen>.unmodifiable(vorkommen),
        wirkung: text(eintrag['wirkung']),
        gebiet: text(eintrag['gebiet']),
        bestimmungHinweis: text(eintrag['bestimmungHinweis']),
        erntezeit: text(eintrag['erntezeit']),
        erntemonate: List<String>.unmodifiable(<String>[
          if (eintrag['erntemonate'] is List)
            for (final monat in eintrag['erntemonate'] as List<dynamic>)
              if (normalizeAventurianMonth(monat.toString()).isNotEmpty)
                normalizeAventurianMonth(monat.toString()),
        ]),
        grundmenge: text(eintrag['grundmenge']),
        beschreibung: beschreibung,
        beschreibungGesperrt: gesperrt,
        quelle: text(eintrag['quelle']),
      ),
    );
  }
  return KraeuterKatalog(
    kraeuter: List<KrautEintrag>.unmodifiable(kraeuter),
    stand: text(roh['stand']),
    verworfen: List<String>.unmodifiable(verworfen),
  );
}

// Klartext der Beschreibung und ob sie gesperrt blieb.
(String, bool) _beschreibung(Object? wert, CatalogKey? schluessel) {
  if (wert is! String) return ('', false);
  final roh = wert.trim();
  if (!isEncryptedValue(roh)) return (roh, false);
  if (schluessel == null) return ('', true);
  final klartext = decryptCatalogValueV3(
    encryptedValue: roh,
    derivedKey: schluessel,
  );
  return klartext == null ? ('', true) : (klartext.trim(), false);
}

/// Lädt die Kräutertabellen aus dem Asset; [lader] ersetzt in Tests
/// `rootBundle`, [schluessel] entschlüsselt die Beschreibungen.
///
/// Fehlt das Asset oder ist es ungültig, ist der Katalog leer: Die
/// Kräutersuche liefert dann keine Funde, statt zu werfen.
Future<KraeuterKatalog> ladeKraeuter({
  Future<String> Function(String pfad)? lader,
  CatalogKey? schluessel,
}) async {
  try {
    return parseKraeuter(
      await ladeJsonAsset(kraeuterAssetPfad, lader: lader),
      schluessel: schluessel,
    );
  } on Object {
    return const KraeuterKatalog();
  }
}
