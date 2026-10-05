import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';

// Sinnvolle Vorgaben des Gefechts (Nutzerentscheidung vom 5. Oktober 2026):
// Häufige Angaben stehen sichtbar vorbelegt in der Sitzung und lassen sich
// jederzeit ändern. Die Regeln selbst behandeln `null` weiterhin als
// unbekannt; die Vorgaben werden deshalb ausschließlich hier gesetzt.

/// Belegt nur unbekannte, häufig gleiche Angaben mit ihrem Regelfall vor.
///
/// Angriffsart Nahkampf, gegnerische Finte 0, Zielsituation im Fernkampf 0,
/// Platz zum Ausweichen und wirksamer Schild-WM entsprechen dem gewöhnlichen
/// Kampf. Bereits erfasste Werte, auch ein ausdrückliches „Nein“, bleiben
/// unverändert. Ladezustand und Schussentfernung erhalten bewusst keine
/// Vorgabe: ein falscher Wert würde Schüsse ohne Laden oder mit falscher
/// Entfernung freigeben.
Gefechtskontext gefechtsKontextMitVorgaben(Gefechtskontext k) =>
    Gefechtskontext(
      kontakt: k.kontakt,
      gegnerId: k.gegnerId,
      gegnerzahl: k.gegnerzahl,
      gegnerDk: k.gegnerDk,
      angriffsart: k.angriffsart ?? Gefechtsangriffsart.nahkampf,
      finte: k.finte ?? 0,
      paradeVerboten: k.paradeVerboten,
      platzZumAusweichen: k.platzZumAusweichen ?? true,
      sehrGross: k.sehrGross,
      grosserSchild: k.grosserSchild,
      halbschwert: k.halbschwert,
      weitereRegelnGeprueft: k.weitereRegelnGeprueft,
      entfernung: k.entfernung,
      geladen: k.geladen,
      getuemmel: k.getuemmel,
      kontrollbereich: k.kontrollbereich,
      situationsZuschlag: k.situationsZuschlag ?? 0,
      schildWmWirksam: k.schildWmWirksam ?? true,
    );

/// Distanzklasse zu Beginn eines Gefechts oder Kontakts (App-Konvention).
///
/// Jede Distanzklasse der Waffe ist für sie ohne Abzug nutzbar
/// (`gefechtsDkDifferenz`). Die Wahl beeinflusst aber Ausweichen und
/// Distanzwechsel, deshalb gilt Nahkampf, wenn die Waffe ihn führt, keine
/// Nahkampfwaffe geführt wird oder ihre DK unbekannt ist. Sonst gilt die
/// erste geführte Klasse in der Reihenfolge Handgemenge, Nahkampf,
/// Stangenwaffen, Piken.
String gefechtsStartDk(String waffenDk, {bool fernkampf = false}) {
  final dk = waffenDk.toUpperCase();
  if (fernkampf || dk.trim().isEmpty || dk.contains('N')) return 'N';
  for (final klasse in const ['H', 'N', 'S', 'P']) {
    if (dk.contains(klasse)) return klasse;
  }
  return 'N';
}

/// Start-DK der aktuell geführten Hauptwaffe.
String gefechtsStartDkFuer(MainWeaponSlot? waffe) => gefechtsStartDk(
  waffe?.distanceClass ?? '',
  fernkampf: waffe?.isRanged ?? false,
);

/// Relevante Nahkampfgegner: Angabe des Angriffs vor der Rundenleiste.
int gefechtsGegnerzahl(Gefechtszustand s) => s.kontext.gegnerzahl ?? s.gegner;
