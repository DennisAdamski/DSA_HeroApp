import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';

/// Bewertet nur Kontextregeln; Aktionsmarken bleiben im gemeinsamen Budget.
class Gefechtskontextpruefung {
  /// Fehlende Angaben dürfen nicht durch angenommene Standardwerte verschwinden.
  const Gefechtskontextpruefung(this.modifikatoren, this.fehlend, this.sperren);
  final List<Gefechtsmodifikator> modifikatoren;
  final List<String> fehlend, sperren;

  /// Summe wird im Regelmodul berechnet, nicht im Widget.
  int get zuschlag => modifikatoren.fold(0, (summe, m) => summe + m.wert);
}

/// Ein neuer Kontakt übernimmt keine unbekannten Werte des vorherigen Gegners.
Gefechtszustand wechsleGefechtskontakt(Gefechtszustand s, String kontakt) =>
    s.copyWith(ohneDk: true, kontext: Gefechtskontext(kontakt: kontakt.trim()));

/// Bewegt nur innerhalb der vier tatsächlichen Distanzklassen.
String? naechsteGefechtsDk(String? dk, int schritte) {
  const klassen = ['H', 'N', 'S', 'P'];
  final index = klassen.indexOf(dk ?? '');
  final neu = index + schritte;
  return index < 0 || neu < 0 || neu >= klassen.length ? null : klassen[neu];
}

/// Fehlende Kerndaten können nicht durch eine pauschale Bestätigung ersetzt werden.
bool gefechtsPflichtkontextErfasst(
  Gefechtskontext k,
  Gefechtsaktion aktion, {
  bool fernkampf = false,
}) {
  final pa =
      aktion == Gefechtsaktion.parade || aktion == Gefechtsaktion.schildparade;
  final aw =
      aktion == Gefechtsaktion.freiesAusweichen ||
      aktion == Gefechtsaktion.gezieltesAusweichen;
  if (pa &&
      (k.angriffsart == null || k.finte == null || k.paradeVerboten == null)) {
    return false;
  }
  if (aw &&
      (k.angriffsart == null ||
          k.finte == null ||
          k.gegnerzahl == null ||
          k.platzZumAusweichen == null)) {
    return false;
  }
  if (fernkampf &&
      aktion == Gefechtsaktion.angriff &&
      (k.entfernung == null ||
          k.geladen == null ||
          k.situationsZuschlag == null)) {
    return false;
  }
  return true;
}

/// WdS 80: Mehrfach-DK verwenden die nächstgelegene erlaubte Distanz.
int? gefechtsDkDifferenz(
  String waffenDk,
  String? aktuelleDk, {
  bool halbschwert = false,
}) {
  const klassen = ['H', 'N', 'S', 'P'];
  final aktuell = klassen.indexOf(aktuelleDk ?? '');
  if (aktuell < 0) return null;
  int? beste;
  for (var i = 0; i < klassen.length; i++) {
    if (!waffenDk.contains(klassen[i])) continue;
    final index = halbschwert && i > 0 ? i - 1 : i;
    final differenz = index - aktuell;
    if (beste == null || differenz.abs() < beste.abs()) beste = differenz;
  }
  return beste;
}

/// DK und gegnerische Ansagen werden für AT, PA und AW einmal berücksichtigt.
Gefechtskontextpruefung pruefeGefechtskontext(
  Gefechtszustand s,
  Gefechtsaktion aktion,
  String waffenDk, {
  bool fernkampf = false,
  bool distanzAenderung = false,
}) {
  final k = s.kontext;
  final mods = <Gefechtsmodifikator>[];
  final fehlend = <String>[];
  final sperren = <String>[];
  final at = aktion == Gefechtsaktion.angriff;
  final pa =
      aktion == Gefechtsaktion.parade || aktion == Gefechtsaktion.schildparade;
  final aw =
      aktion == Gefechtsaktion.freiesAusweichen ||
      aktion == Gefechtsaktion.gezieltesAusweichen;
  if (!at && !pa && !aw) return const Gefechtskontextpruefung([], [], []);
  if (!k.weitereRegelnGeprueft) {
    fehlend.add('Sicht, Gelände und Sonderregeln prüfen.');
  }
  if (!fernkampf &&
      !distanzAenderung &&
      (at || aktion == Gefechtsaktion.parade)) {
    final d = gefechtsDkDifferenz(waffenDk, s.dk, halbschwert: k.halbschwert);
    if (d == null) {
      fehlend.add('Tatsächliche DK und Waffen-DK festlegen.');
    } else if (d >= 2 || at && d <= -2) {
      sperren.add('Waffe in dieser DK nicht verwendbar.');
    } else if (d == 1 || at && d == -1) {
      mods.add(const Gefechtsmodifikator('Distanzklasse', 6));
    }
  }
  if (pa || aw) {
    if (k.angriffsart == null) fehlend.add('Aktuelle Angriffsart festlegen.');
    if (k.angriffsart != null &&
        k.angriffsart != Gefechtsangriffsart.nahkampf) {
      fehlend.add(
        'Fernkampf-/Sonderangriff: Abwehrmöglichkeiten und Zuschlag manuell prüfen.',
      );
    }
    if (k.finte == null) {
      fehlend.add('Gegnerische Finte für diesen Angriff erfassen (0 möglich).');
    } else if (k.finte! < 0) {
      sperren.add('Finte darf nicht negativ sein.');
    } else {
      mods.add(Gefechtsmodifikator('Gegnerische Finte', k.finte!));
    }
    if (pa && k.paradeVerboten == null) fehlend.add('Paradeverbot klären.');
    if (pa && k.paradeVerboten == true) {
      sperren.add('Dieser Angriff kann nicht pariert werden.');
    }
  }
  if (aw) {
    if (k.gegnerzahl == null) {
      fehlend.add('Relevante Nahkampfgegner bestätigen.');
    }
    if (k.platzZumAusweichen == null) {
      fehlend.add('Platz zum Ausweichen klären.');
    }
    if (k.platzZumAusweichen == false) {
      sperren.add('Kein Platz zum Ausweichen.');
    }
    if (s.dk == null) fehlend.add('Tatsächliche DK für Ausweichen festlegen.');
    if (aktion == Gefechtsaktion.freiesAusweichen) {
      mods.add(
        Gefechtsmodifikator('Ausweich-DK', switch (s.dk) {
          'H' => 4,
          'N' => 2,
          'S' => 1,
          _ => 0,
        }),
      );
    }
  }
  return Gefechtskontextpruefung(mods, fehlend, sperren);
}
