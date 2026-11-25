import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:dsa_heldenverwaltung/data/freesound/freesound_oauth.dart';

/// Ablage des Freesound-Zugangs; nur auf dem Gerät, ohne Konto-Sync.
abstract interface class FreesoundZugangAblage {
  /// Gespeicherter Zugang oder `null`.
  Future<FreesoundZugang?> lies();

  /// Speichert [zugang]; `null` entfernt ihn.
  Future<void> schreibe(FreesoundZugang? zugang);
}

/// Ablage im sicheren Gerätespeicher (Keychain, Keystore, Credential Manager).
///
/// Wirft der Speicher (manche Browser), bleibt der Zugang nur für die
/// laufende Sitzung im Speicher.
class SichereFreesoundZugangAblage implements FreesoundZugangAblage {
  static const _name = 'freesound_oauth_v1';
  static const _secure = FlutterSecureStorage();
  FreesoundZugang? _fluechtig;

  @override
  Future<FreesoundZugang?> lies() async {
    try {
      final roh = await _secure.read(key: _name);
      if (roh == null) return _fluechtig;
      return FreesoundZugang.ausJson(jsonDecode(roh));
    } on Object {
      return _fluechtig;
    }
  }

  @override
  Future<void> schreibe(FreesoundZugang? zugang) async {
    _fluechtig = zugang;
    try {
      if (zugang == null) {
        await _secure.delete(key: _name);
      } else {
        await _secure.write(key: _name, value: jsonEncode(zugang.toJson()));
      }
    } on Object {
      // shortcut: nur sitzungsweise gemerkt, wenn der Browser keinen sicheren Speicher bietet.
    }
  }
}

/// Ablage nur im Speicher (Tests).
class FluechtigeFreesoundZugangAblage implements FreesoundZugangAblage {
  /// Erstellt die Ablage mit [wert].
  FluechtigeFreesoundZugangAblage([this.wert]);

  /// Aktueller Zugang.
  FreesoundZugang? wert;

  @override
  Future<FreesoundZugang?> lies() async => wert;

  @override
  Future<void> schreibe(FreesoundZugang? zugang) async => wert = zugang;
}
