import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:dsa_heldenverwaltung/data/karte/karten_kachel_manifest.dart';

/// Quellenangabe für Orte und Kartenpositionen aus Avesmaps.
const String kAvesmapsLizenzText =
    'Karte & Ortsdaten: Avesmaps (https://avesmaps.de), ein DSA-Fanprojekt.\n\n'
    'Die App ruft das Ortsverzeichnis von Avesmaps (Namen, Ortsklassen und '
    'Kartenpositionen) mit Zustimmung des Betreibers über dessen '
    'Entwickler-API ab und speichert es lokal zwischen. Die Daten stehen '
    'nicht unter einer freien Lizenz: Die Rechte an den Namen und Inhalten '
    'Aventuriens liegen bei Ulisses Spiele bzw. den jeweiligen Urhebern.\n\n'
    'Die Karte der App zeichnet Orte, Namen und Route selbst aus diesen '
    'Ortsdaten, im Stil von Avesmaps. Ein Kartenbild von Avesmaps lädt sie '
    'nicht von avesmaps.de; Orte öffnet sie als Link auf avesmaps.de.';

/// Quellenangabe für das selbst gehostete Kartenbild.
const String kKartenmaterialLizenzText =
    'Kartenmaterial © Ulisses Spiele · Originalkarte: Ina Kramer · '
    'Bearbeitung: Avesmaps (DSA-Fanprojekt).\n\n'
    'Das Kartenbild stammt aus dem Kartenpaket, das Avesmaps über seine '
    'Karten-API ausgibt, und wird von dieser App in Kacheln geschnitten und '
    'selbst bereitgestellt. Grundlage ist die Lizenzvereinbarung zum '
    'Ulisses-Kartenpaket (nur nicht-kommerzielle Nutzung, Bearbeitungen als '
    'DSA-Fanprojekt gekennzeichnet): '
    'https://de.wiki-aventurica.de/wiki/Kartenpaket/Lizenz';

/// Meldet die Quellenangabe für Avesmaps bei der Flutter-Lizenzseite an
/// (`showLicensePage`).
void registriereAvesmapsLizenz() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(<String>[
      'Avesmaps (Ortsdaten)',
    ], kAvesmapsLizenzText);
    // Das Kartenmaterial nur, wenn dieser Build Kartenkacheln zeigt.
    if (kKartenKachelBasis.isNotEmpty) {
      yield const LicenseEntryWithLineBreaks(<String>[
        'Aventurienkarte (Ulisses-Kartenpaket, Bearbeitung Avesmaps)',
      ], kKartenmaterialLizenzText);
    }
    // Kartenschrift „Faculty Glyphic“ (SIL Open Font License 1.1).
    final ofl = await rootBundle.loadString(
      'assets/fonts/faculty_glyphic/OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(<String>['Faculty Glyphic'], ofl);
  });
}
