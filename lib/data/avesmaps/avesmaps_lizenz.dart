import 'package:flutter/foundation.dart';

/// Quellenangabe für Orte und Kartenpositionen aus Avesmaps.
const String kAvesmapsLizenzText =
    'Karte & Ortsdaten: Avesmaps (https://avesmaps.de), ein DSA-Fanprojekt.\n\n'
    'Die App ruft das Ortsverzeichnis von Avesmaps (Namen, Ortsklassen und '
    'Kartenpositionen) mit Zustimmung des Betreibers über dessen '
    'Entwickler-API ab und speichert es lokal zwischen. Die Daten stehen '
    'nicht unter einer freien Lizenz: Die Rechte an den Namen und Inhalten '
    'Aventuriens liegen bei Ulisses Spiele bzw. den jeweiligen Urhebern.\n\n'
    'Kartenmaterial zeigt die App nicht; Orte öffnet sie als Link auf '
    'avesmaps.de.';

/// Meldet die Quellenangabe für Avesmaps bei der Flutter-Lizenzseite an
/// (`showLicensePage`).
void registriereAvesmapsLizenz() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(<String>[
      'Avesmaps (Ortsdaten)',
    ], kAvesmapsLizenzText);
  });
}
