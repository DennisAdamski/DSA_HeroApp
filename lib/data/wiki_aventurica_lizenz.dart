import 'package:flutter/foundation.dart';

/// Quellenangabe und Lizenzhinweis für das Ortsverzeichnis.
const String kWikiAventuricaLizenzText =
    'Das Ortsverzeichnis der App (Namen, Arten und Regionen von Siedlungen, '
    'Regionen, Staaten, Flüssen und Straßen Aventuriens) stammt aus der Wiki '
    'Aventurica, https://de.wiki-aventurica.de, und steht unter der Lizenz '
    'Creative Commons Namensnennung – Weitergabe unter gleichen Bedingungen '
    '(CC BY-SA).\n\n'
    'Die Lizenzbestimmungen stehen unter '
    'https://de.wiki-aventurica.de/wiki/Wiki_Aventurica:Lizenzbestimmungen; '
    'die Autorinnen und Autoren der einzelnen Seiten nennt jeweils deren '
    'Versionsgeschichte im Wiki.\n\n'
    'Übernommen sind nur Kurzangaben (Name, Art, Region), keine '
    'Beschreibungstexte. Die Daten wurden maschinell ausgelesen und '
    'aufbereitet; Fehler gehen nicht zulasten der Wiki.';

/// Meldet die Quellenangabe des Ortsverzeichnisses bei der Flutter-
/// Lizenzseite an (`showLicensePage`).
///
/// Die Daten sind ein Asset und kein Pub-Paket, ihre Lizenz erscheint deshalb
/// nicht von selbst.
void registriereWikiAventuricaLizenz() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(<String>[
      'Wiki Aventurica (Ortsverzeichnis)',
    ], kWikiAventuricaLizenzText);
  });
}
