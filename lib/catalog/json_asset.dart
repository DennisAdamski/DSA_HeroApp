import 'dart:convert';

import 'package:flutter/services.dart';

/// Entfernt eine führende Byte-Order-Mark (U+FEFF), die manche Editoren in
/// JSON-Dateien schreiben und die `jsonDecode` ablehnt.
String ohneBom(String text) {
  return text.startsWith('\uFEFF') ? text.substring(1) : text;
}

/// Liest ein JSON-Asset und dekodiert es, auch mit führender BOM.
///
/// [lader] ersetzt `rootBundle.loadString` (Tests). Fehler beim Laden
/// (`FlutterError`) und Dekodieren (`FormatException`) gibt die Funktion
/// unverändert weiter; die Aufrufer entscheiden, was ein fehlendes Asset
/// bedeutet.
Future<Object?> ladeJsonAsset(
  String pfad, {
  Future<String> Function(String pfad)? lader,
}) async {
  final laden = lader ?? rootBundle.loadString;
  return jsonDecode(ohneBom(await laden(pfad)));
}
