import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:dsa_heldenverwaltung/data/avatar_gesicht/avatar_gesichtserkennung.dart';
import 'package:dsa_heldenverwaltung/data/avatar_gesicht_cache.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_gesichtsbefund.dart';

/// Liefert den Gesichtsbefund eines Avatarbildes: aus dem Cache oder frisch
/// erkannt.
///
/// Neue Bilder tragen ihren Befund bereits am Galerieeintrag
/// ([erkenneNeu] beim Anlegen); dieser Service ist fuer alle anderen da.
/// Nachgetragen wird der Befund bewusst **nie** in den Helden: Das Feld geht
/// in `heroContentHash` ein, und ein Nachtragen fuer Bestandsbilder wuerde
/// Helden schreiben — genau das, was ein Avatar-Abgleich nie tun darf (neues
/// `lastModified`, Konfliktwelle beim Sync). Fuer Bestandsbilder erkennt jedes
/// Geraet deshalb einmal selbst und merkt sich das Ergebnis lokal.
///
/// Wirft nie: Jeder Fehler ergibt `null`, und die Darstellung faellt auf den
/// Standardausschnitt zurueck. Ein Erkennungsproblem darf nie wie ein
/// Bildfehler aussehen.
class AvatarGesichtService {
  AvatarGesichtService({
    required this.erkennung,
    required this.cacheFuer,
    this.zeitlimit = const Duration(seconds: 15),
  });

  /// Rechnet die Befunde, die noch nicht im Cache liegen.
  final AvatarGesichtserkennung erkennung;

  /// Liefert den Cache fuer einen Heldenspeicherpfad.
  final AvatarGesichtCache Function(String heroStoragePath) cacheFuer;

  /// Hoechstens so lange wartet ein Aufrufer auf eine frische Erkennung.
  ///
  /// Laeuft sie laenger, bekommt er `null`; die Erkennung rechnet aber weiter
  /// und legt ihr Ergebnis fuer den naechsten Aufruf im Cache ab.
  final Duration zeitlimit;

  final Map<String, AvatarGesichtCache> _caches = {};
  final Map<String, Future<AvatarGesichtsbefund?>> _laufend = {};

  /// Ende der Warteschlange: Erkennungen laufen nacheinander.
  ///
  /// Ein frisch geoeffnetes Album fragt fuer jede Kachel gleichzeitig an.
  /// Parallel waeren das nativ ebenso viele Isolates mit eigener Modellkopie
  /// und im Web ebenso viele Netze auf dem Haupt-Thread.
  Future<void> _warteschlange = Future<void>.value();

  /// Befund fuer das Bild [fileName] mit den Bytes [bytes].
  ///
  /// Gleichzeitige Anfragen fuer dieselbe Datei teilen sich eine Erkennung.
  Future<AvatarGesichtsbefund?> befund({
    required String heroStoragePath,
    required String fileName,
    required Uint8List bytes,
  }) {
    if (fileName.isEmpty || bytes.isEmpty) return Future.value(null);
    final schluessel = '$heroStoragePath|$fileName|${bytes.length}';
    final laufend = _laufend[schluessel];
    if (laufend != null) return laufend;
    final neu = _ermittle(
      cache: _caches.putIfAbsent(
        heroStoragePath,
        () => cacheFuer(heroStoragePath),
      ),
      fileName: fileName,
      bytes: bytes,
    );
    _laufend[schluessel] = neu;
    return neu.whenComplete(() => _laufend.remove(schluessel));
  }

  /// Erkennt ein gerade angelegtes Bild, das noch keinen Dateinamen hat.
  ///
  /// Fuer Hochladen und Generieren: Der Befund wandert dort an den neuen
  /// Galerieeintrag und damit in denselben `saveHero`, der ohnehin laeuft.
  /// Das kurze [zeitlimit] haelt das Anlegen fluessig; wer `null` bekommt,
  /// legt den Eintrag ohne Befund an, und die Anzeige erkennt spaeter lokal.
  /// Wirft nie.
  Future<AvatarGesichtsbefund?> erkenneNeu(
    Uint8List bytes, {
    Duration zeitlimit = const Duration(seconds: 5),
  }) async {
    if (bytes.isEmpty) return null;
    try {
      return await _nacheinander<AvatarGesichtsbefund?>(
        () => erkennung.erkenne(bytes),
      ).timeout(zeitlimit, onTimeout: () => null);
    } on Object catch (error) {
      debugPrint('Gesichtserkennung beim Anlegen fehlgeschlagen: $error');
      return null;
    }
  }

  Future<AvatarGesichtsbefund?> _ermittle({
    required AvatarGesichtCache cache,
    required String fileName,
    required Uint8List bytes,
  }) async {
    try {
      final eintrag = await cache.lese(fileName);
      if (eintrag != null &&
          eintrag.version == kAvatarGesichtDetektorVersion &&
          eintrag.byteLaenge == bytes.length) {
        return eintrag.befund;
      }
    } on Object catch (error) {
      debugPrint('Gesichts-Cache nicht lesbar ($fileName): $error');
    }

    final laufend = _erkenneUndMerke(
      cache: cache,
      fileName: fileName,
      bytes: bytes,
    );
    return laufend.timeout(zeitlimit, onTimeout: () => null);
  }

  Future<AvatarGesichtsbefund?> _erkenneUndMerke({
    required AvatarGesichtCache cache,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final AvatarGesichtsbefund befund;
    try {
      befund = await _nacheinander(() => erkennung.erkenne(bytes));
    } on Object catch (error) {
      debugPrint('Gesichtserkennung fehlgeschlagen ($fileName): $error');
      return null;
    }
    try {
      await cache.schreibe(
        fileName,
        AvatarGesichtCacheEintrag(
          version: kAvatarGesichtDetektorVersion,
          byteLaenge: bytes.length,
          befund: befund,
        ),
      );
    } on Object catch (error) {
      debugPrint('Gesichts-Cache nicht schreibbar ($fileName): $error');
    }
    return befund;
  }

  Future<T> _nacheinander<T>(Future<T> Function() aufgabe) {
    final ergebnis = _warteschlange.then((_) => aufgabe());
    _warteschlange = ergebnis.then<void>((_) {}, onError: (Object _) {});
    return ergebnis;
  }
}
