import 'package:flutter/foundation.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_crypto.dart';
import 'package:dsa_heldenverwaltung/catalog/json_asset.dart';
import 'package:dsa_heldenverwaltung/catalog/kurzregel_def.dart';

/// Asset des Kurzregel-Kompendiums (Top-Level-Liste, Texte v3-verschluesselt).
const String kurzregelnAssetPfad =
    'assets/catalogs/house_rules_v1/kurzregeln.json';

/// Felder, die das Encrypt-Tool als Text verschluesselt.
const List<String> _textFelder = <String>['kurztext', 'hausregel_text'];

/// Felder, die das Encrypt-Tool als JSON-Liste verschluesselt.
const List<String> _listenFelder = <String>['hinweise'];

/// Geladenes Kompendium samt Diagnose.
class KurzregelKatalog {
  const KurzregelKatalog({
    this.eintraege = const <KurzregelDef>[],
    this.verworfen = const <String, List<String>>{},
  });

  /// Gueltige Eintraege in Dateireihenfolge.
  final List<KurzregelDef> eintraege;

  /// Verworfene Eintraege (Kennung → Probleme), vor allem fehlende Belege.
  final Map<String, List<String>> verworfen;

  /// true, wenn mindestens ein Eintrag verschluesselte Texte traegt.
  bool get gesperrt => eintraege.any((eintrag) => eintrag.gesperrt);
}

/// Parst die Rohliste des Assets zu einem [KurzregelKatalog].
///
/// Mit dem v3-Katalogschluessel [schluessel] (`catalogKeyV3Provider`) werden
/// `enc:3:`-Werte entschluesselt; ohne bleiben die Texte leer und die
/// Eintraege tragen [KurzregelDef.gesperrt].
/// Eintraege mit Problemen ([KurzregelDef.probleme]) landen in
/// [KurzregelKatalog.verworfen], statt unbelegt angezeigt zu werden.
KurzregelKatalog parseKurzregeln(List<dynamic> roh, {CatalogKey? schluessel}) {
  final eintraege = <KurzregelDef>[];
  final verworfen = <String, List<String>>{};
  for (final element in roh) {
    if (element is! Map) {
      continue;
    }
    final json = _entschluesselt(element.cast<String, dynamic>(), schluessel);
    final eintrag = KurzregelDef.fromJson(json);
    final probleme = eintrag.probleme;
    if (probleme.isEmpty) {
      eintraege.add(eintrag);
    } else {
      verworfen[eintrag.id.isEmpty ? '(ohne id)' : eintrag.id] = probleme;
    }
  }
  return KurzregelKatalog(
    eintraege: List<KurzregelDef>.unmodifiable(eintraege),
    verworfen: Map<String, List<String>>.unmodifiable(verworfen),
  );
}

/// Kopie des Eintrags, in der geschuetzte Felder entschluesselt sind.
///
/// Misslingt die Entschluesselung (falsches Passwort), bleibt der
/// `enc:`-Wert stehen und [KurzregelDef.fromJson] markiert den Eintrag
/// als gesperrt.
Map<String, dynamic> _entschluesselt(
  Map<String, dynamic> json,
  CatalogKey? schluessel,
) {
  if (schluessel == null) {
    return json;
  }
  final kopie = Map<String, dynamic>.of(json);
  for (final feld in _textFelder) {
    final wert = kopie[feld];
    if (wert is String && isEncryptedValue(wert)) {
      final klartext = decryptCatalogValueV3(
        encryptedValue: wert,
        derivedKey: schluessel,
      );
      if (klartext != null) {
        kopie[feld] = klartext;
      }
    }
  }
  for (final feld in _listenFelder) {
    final wert = kopie[feld];
    if (wert is String && isEncryptedValue(wert)) {
      final liste = decryptCatalogListV3(
        encryptedValue: wert,
        derivedKey: schluessel,
      );
      if (liste != null) {
        kopie[feld] = liste;
      }
    }
  }
  return kopie;
}

/// Signatur zum Laden eines Text-Assets (Testnaht fuer `rootBundle`).
typedef AssetBundleLader = Future<String> Function(String pfad);

/// Laedt das Kompendium aus den Assets.
///
/// Fehlt das Asset oder ist es kein JSON-Array, ist das Kompendium leer: die
/// Kurzregeln sind eine Zusatzfunktion und duerfen keinen Start verhindern.
/// Entschluesselt wird mit dem schon abgeleiteten [schluessel]; die paar
/// AES-Werte brauchen keinen eigenen Isolate.
Future<KurzregelKatalog> ladeKurzregeln({
  CatalogKey? schluessel,
  AssetBundleLader? lader,
}) async {
  final List<dynamic> roh;
  try {
    final decoded = await ladeJsonAsset(kurzregelnAssetPfad, lader: lader);
    if (decoded is! List) {
      return const KurzregelKatalog();
    }
    roh = decoded;
  } on FlutterError {
    return const KurzregelKatalog();
  } on FormatException {
    return const KurzregelKatalog();
  }
  return parseKurzregeln(roh, schluessel: schluessel);
}
