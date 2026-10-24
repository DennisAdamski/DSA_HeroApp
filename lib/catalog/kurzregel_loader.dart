import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:dsa_heldenverwaltung/catalog/catalog_crypto.dart';
import 'package:dsa_heldenverwaltung/catalog/kurzregel_def.dart';

/// Asset des Kurzregel-Kompendiums (Top-Level-Liste, Texte v3-verschluesselt).
const String kurzregelnAssetPfad =
    'assets/catalogs/house_rules_v1/kurzregeln.json';

/// Manifest, dessen `catalog_salt_v3` auch die Kurzregeln verschluesselt.
const String kurzregelnManifestPfad =
    'assets/catalogs/house_rules_v1/manifest.json';

/// Felder, die das Encrypt-Tool als Text verschluesselt.
const List<String> _textFelder = <String>['kurztext', 'hausregel_text'];

/// Felder, die das Encrypt-Tool als JSON-Liste verschluesselt.
const List<String> _listenFelder = <String>['hinweise'];

/// Schwelle fuer die Auslagerung der Entschluesselung in einen Isolate.
///
/// Wie in `catalog_decrypt_runner.dart`: darunter ist der Spawn teurer als
/// die Entschluesselung selbst.
const int _isolateSchwelle = 64;

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
/// Mit [passwort] und [salt] werden `enc:3:`-Werte entschluesselt; ohne
/// bleiben die Texte leer und die Eintraege tragen [KurzregelDef.gesperrt].
/// Eintraege mit Problemen ([KurzregelDef.probleme]) landen in
/// [KurzregelKatalog.verworfen], statt unbelegt angezeigt zu werden.
KurzregelKatalog parseKurzregeln(
  List<dynamic> roh, {
  String? passwort,
  Uint8List? salt,
}) {
  final schluessel = (passwort == null || passwort.isEmpty || salt == null)
      ? null
      : deriveCatalogKey(password: passwort, salt: salt);
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

/// Zaehlt verschluesselte Felder, um die Isolate-Auslagerung zu entscheiden.
int _zaehleVerschluesselte(List<dynamic> roh) {
  var anzahl = 0;
  for (final element in roh) {
    if (element is! Map) {
      continue;
    }
    for (final wert in element.values) {
      if (wert is String && isEncryptedValue(wert)) {
        anzahl++;
      }
    }
  }
  return anzahl;
}

/// Argumentpaket fuer [compute]: nur sendbare Typen.
class _ParseAuftrag {
  const _ParseAuftrag(this.roh, this.passwort, this.salt);

  final List<dynamic> roh;
  final String? passwort;
  final Uint8List? salt;
}

KurzregelKatalog _parseImIsolate(_ParseAuftrag auftrag) {
  return parseKurzregeln(
    auftrag.roh,
    passwort: auftrag.passwort,
    salt: auftrag.salt,
  );
}

/// Signatur zum Laden eines Text-Assets (Testnaht fuer `rootBundle`).
typedef AssetBundleLader = Future<String> Function(String pfad);

/// Laedt das Kompendium aus den Assets.
///
/// Fehlt das Asset oder ist es kein JSON-Array, ist das Kompendium leer: die
/// Kurzregeln sind eine Zusatzfunktion und duerfen keinen Start verhindern.
Future<KurzregelKatalog> ladeKurzregeln({
  String? passwort,
  AssetBundleLader? lader,
}) async {
  final laden = lader ?? rootBundle.loadString;
  final List<dynamic> roh;
  try {
    final text = _ohneBom(await laden(kurzregelnAssetPfad));
    final decoded = jsonDecode(text);
    if (decoded is! List) {
      return const KurzregelKatalog();
    }
    roh = decoded;
  } on FlutterError {
    return const KurzregelKatalog();
  } on FormatException {
    return const KurzregelKatalog();
  }
  final salt = await _ladeSalt(laden);
  final auftrag = _ParseAuftrag(roh, passwort, salt);
  final entschluesseln =
      passwort != null && passwort.isNotEmpty && salt != null;
  if (entschluesseln && _zaehleVerschluesselte(roh) >= _isolateSchwelle) {
    return compute(_parseImIsolate, auftrag);
  }
  return _parseImIsolate(auftrag);
}

Future<Uint8List?> _ladeSalt(AssetBundleLader laden) async {
  try {
    final manifest = jsonDecode(
      _ohneBom(await laden(kurzregelnManifestPfad)),
    ) as Map<String, dynamic>;
    final salt = manifest['catalog_salt_v3'];
    return salt is String ? base64Decode(salt) : null;
  } on FlutterError {
    return null;
  } on FormatException {
    return null;
  }
}

String _ohneBom(String text) {
  return text.startsWith('﻿') ? text.substring(1) : text;
}
