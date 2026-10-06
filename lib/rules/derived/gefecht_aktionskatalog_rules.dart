import 'package:dsa_heldenverwaltung/domain/gefecht.dart';

import 'gefecht_ablauf_rules.dart';
import 'gefecht_rules.dart';

/// Benannte Handlungen aus WdS S. 55 (MCP 6970/6971), ohne eigene Kampfprobe.
enum GefechtsBenannteAktion {
  /// Warnruf, Befehl oder Fluch mit höchstens drei kurzen Worten.
  rufen,

  /// Ein Schritt in beliebige Richtung; ändert weder Position noch DK.
  schritt,

  /// Drehung um 45° (Kampf mit Bodenplänen).
  drehen,

  /// Waffe oder Gegenstand fallen lassen, nicht vorsichtig absetzen.
  fallenLassen,

  /// Schlüsselbewegung oder -wort eines getragenen Artefakts.
  artefakt,

  /// GE-Probe; bei Misslingen 1W6 AuP und 1W6 INI; danach liegend.
  zuBodenWerfen,

  /// GS Schritt mit Umsicht; Kampfaktionen dieser Runde +4.
  bewegen,

  /// Zwei Aktionen, dreifache GS; keine Angriffs- oder Abwehraktion.
  sprinten,
}

/// Wie eine benannte Handlung bezahlt wird.
enum GefechtsAktionskosten { frei, aktion, zweiAktionen }

/// Kosten einer benannten Handlung nach WdS S. 55.
GefechtsAktionskosten gefechtsAktionskosten(GefechtsBenannteAktion a) =>
    switch (a) {
      GefechtsBenannteAktion.bewegen => GefechtsAktionskosten.aktion,
      GefechtsBenannteAktion.sprinten => GefechtsAktionskosten.zweiAktionen,
      _ => GefechtsAktionskosten.frei,
    };

/// Sichtbarer Name.
String gefechtsAktionsname(GefechtsBenannteAktion a) => switch (a) {
  GefechtsBenannteAktion.rufen => 'Rufen',
  GefechtsBenannteAktion.schritt => 'Schritt',
  GefechtsBenannteAktion.drehen => 'Drehen',
  GefechtsBenannteAktion.fallenLassen => 'Waffe oder Gegenstand fallen lassen',
  GefechtsBenannteAktion.artefakt => 'Artefakt aktivieren',
  GefechtsBenannteAktion.zuBodenWerfen => 'Sich zu Boden werfen',
  GefechtsBenannteAktion.bewegen => 'Bewegen',
  GefechtsBenannteAktion.sprinten => 'Sprinten',
};

/// Kurzer Regeltext zur Anzeige im Auswahlblatt.
String gefechtsAktionsregel(GefechtsBenannteAktion a) => switch (a) {
  GefechtsBenannteAktion.rufen => 'Freie Aktion: höchstens drei kurze Worte.',
  GefechtsBenannteAktion.schritt =>
    'Freie Aktion: ein Schritt; verbessert weder Position noch DK.',
  GefechtsBenannteAktion.drehen => 'Freie Aktion: Drehung um 45°.',
  GefechtsBenannteAktion.fallenLassen =>
    'Freie Aktion: fällt ungeschützt; Ausrüstung danach anpassen.',
  GefechtsBenannteAktion.artefakt =>
    'Freie Aktion: getragenes oder gehaltenes Artefakt aktivieren.',
  GefechtsBenannteAktion.zuBodenWerfen =>
    'Freie Aktion mit GE-Probe; misslungen 1W6 AuP und 1W6 INI. '
        'Danach liegend; aufstehen mit Position.',
  GefechtsBenannteAktion.bewegen =>
    'Eine Aktion: GS Schritt mit Umsicht. AT, PA und gezieltes '
        'Ausweichen dieser Runde +4.',
  GefechtsBenannteAktion.sprinten =>
    'Zwei Aktionen: dreifache GS. In dieser Runde keine Angriffs- oder '
        'Abwehraktion.',
};

/// Prüft das Budget einer benannten Handlung mit denselben Grundsperren.
Gefechtspruefung pruefeGefechtsBenannteAktion(
  Gefechtszustand s,
  Gefechtswerte w,
  GefechtsBenannteAktion a,
) => switch (gefechtsAktionskosten(a)) {
  GefechtsAktionskosten.frei => pruefeGefechtsaktion(
    s,
    w,
    Gefechtsaktion.freieAktion,
  ),
  GefechtsAktionskosten.aktion => pruefeManuelleGefechtsaktion(s, w, kosten: 1),
  GefechtsAktionskosten.zweiAktionen => pruefeManuelleGefechtsaktion(
    s,
    w,
    kosten: 2,
  ),
};

/// Folge einer gebuchten Handlung für die laufende Runde.
///
/// „Sich zu Boden werfen“ endet immer liegend (WdS S. 55); der AuP- und
/// INI-Verlust bei misslungener GE-Probe wird über [iniVerlust] gebucht
/// bzw. am Tisch als AuP-Verlust in den Vitalwerten erfasst.
Gefechtszustand wendeGefechtsBenannteAktionAn(
  Gefechtszustand s,
  GefechtsBenannteAktion a, {
  int iniVerlust = 0,
}) => switch (a) {
  GefechtsBenannteAktion.bewegen => s.copyWith(bewegt: true),
  GefechtsBenannteAktion.sprinten => s.copyWith(gesprintet: true),
  GefechtsBenannteAktion.zuBodenWerfen => s.copyWith(
    haltung: Gefechtshaltung.liegend,
    iniVerlust: s.iniVerlust + iniVerlust,
  ),
  _ => s,
};

/// AuP nach einem misslungenen Sprung zu Boden; AuP sinken nicht unter 0.
int gefechtsAupNachSturz(int aup, int verlust) {
  final rest = aup - verlust;
  return rest < 0 ? 0 : rest;
}
