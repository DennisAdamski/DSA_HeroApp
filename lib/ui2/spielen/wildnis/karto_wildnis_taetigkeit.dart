import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/kraeuter_eintrag.dart';
import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_probe_rules.dart';

/// Eine Wahl, die eine Tätigkeit zusätzlich zu den gemeinsamen Feldern der
/// Wildnis-Kachel braucht (Suchziel, Erntezeit, Beutetier …).
///
/// Die Kachel zeigt jede Wahl als Auswahlfeld und merkt sich die Antwort unter
/// [schluessel]; die Tätigkeit liest sie über [KartoWildnisKontext.optionen].
class KartoWildnisOption {
  /// Erstellt eine Wahl mit festen [werte].
  const KartoWildnisOption({
    required this.schluessel,
    required this.bezeichnung,
    required this.werte,
    required this.standard,
    this.sichtbar,
    this.dynamischeWerte,
  });

  /// Stabiler Schlüssel innerhalb der Tätigkeit.
  final String schluessel;

  /// Beschriftung des Felds.
  final String bezeichnung;

  /// Mögliche Antworten: Schlüssel und Anzeigetext.
  final List<({String schluessel, String text})> werte;

  /// Schlüssel der vorbelegten Antwort.
  final String standard;

  /// Ob die Wahl zur aktuellen Auswahl passt; ohne Angabe immer.
  final bool Function(Map<String, String> optionen)? sichtbar;

  /// Antworten, die vom Kontext abhängen (etwa die Kräuter der Landschaft);
  /// ersetzt [werte], wenn gesetzt.
  final List<({String schluessel, String text})> Function(
    KartoWildnisKontext kontext,
  )?
  dynamischeWerte;
}

/// Eine wählbare Dauer der Tätigkeit.
typedef KartoWildnisDauer = ({int stunden, String text});

/// Alle Eingaben einer Wildnisprobe, so wie die Kachel sie zusammenträgt.
class KartoWildnisKontext {
  /// Erstellt den Kontext.
  const KartoWildnisKontext({
    required this.landschaft,
    required this.jahreszeit,
    required this.monat,
    required this.taw,
    required this.dauerStunden,
    required this.eigenschaften,
    required this.gelaendekunde,
    required this.ortskenntnis,
    required this.eingesetzteAsp,
    required this.situativeErschwernis,
    required this.optionen,
    required this.daten,
  });

  /// Durchsuchte Landschaft.
  final WildnisLandschaft landschaft;

  /// Jahreszeit der Probe.
  final Jahreszeit jahreszeit;

  /// Monatsschlüssel des aventurischen Datums; leer, wenn unbekannt.
  final String monat;

  /// TaW der Tätigkeit bei der Grunddauer (vor [dauerStunden]).
  final int taw;

  /// Gewählte Dauer in Stunden.
  final int dauerStunden;

  /// Die drei Probeneigenschaften samt Wert.
  final List<ProbeTargetValue> eigenschaften;

  /// Geländekunde für die Landschaft (erkannt oder von Hand gesetzt).
  final Gelaendekunde gelaendekunde;

  /// Ortskenntnis am Standort (erkannt oder von Hand gesetzt).
  final bool ortskenntnis;

  /// Eingesetzte AsP.
  final int eingesetzteAsp;

  /// Erschwernis (positiv) oder Erleichterung (negativ) des Meisters.
  final int situativeErschwernis;

  /// Antworten auf die Wahlen der Tätigkeit ([KartoWildnisOption]).
  final Map<String, String> optionen;

  /// Geladene Daten der Tätigkeit ([KartoWildnisTaetigkeit.beobachteDaten]).
  final Object? daten;
}

/// Eine Wildnistätigkeit der Wildnis-Kachel: Kräuter suchen, später Nahrung
/// sammeln, Pirschjagd, Fallenstellen …
///
/// Die Kachel kennt nur diese Schnittstelle. Gemeinsam sind Landschaft,
/// Datum, Geländekunde, Ortskenntnis, TaW aus Bestandteil-Talenten, AsP, die
/// Probe über das Würfelprotokoll und die Ergebnisanzeige; die Tätigkeit
/// liefert, was sich unterscheidet. Eine neue Tätigkeit ist eine Unterklasse
/// plus ein Eintrag in [kartoWildnisTaetigkeiten], ohne Umbau der Kachel.
///
/// Keine Rechenlogik hier: Erschwernis, Probe und Auswertung stammen aus
/// `lib/rules/derived/` (CLAUDE.md, Regel „Regelrechnung nie im Widget“).
abstract class KartoWildnisTaetigkeit {
  /// Erlaubt konstante Unterklassen.
  const KartoWildnisTaetigkeit();

  /// Stabile Kennung für Schlüssel und Tests.
  String get id;

  /// Name der Tätigkeit im Umschalter und in der Kopfzeile.
  String get titel;

  /// Symbol der Tätigkeit.
  IconData get symbol;

  /// Kurzer Regelverweis für die Anzeige (Quelle und Seite).
  String get regelHinweis;

  /// IDs der Talente, aus denen sich der TaW zusammensetzt (Mittel, höchstens
  /// das Doppelte des niedrigsten).
  List<String> get talentKomponenten;

  /// Die drei Probeneigenschaften.
  List<AttributeCode> get eigenschaften;

  /// Alle wählbaren Landschaften.
  List<WildnisLandschaft> get landschaften;

  /// Wählbare Dauern; die erste gilt als Grunddauer.
  List<KartoWildnisDauer> get dauern;

  /// Zusätzliche Wahlen der Tätigkeit.
  List<KartoWildnisOption> get optionen => const <KartoWildnisOption>[];

  /// Landschaften, die zu [ort] passen; leer, wenn der Ort nichts sagt.
  List<WildnisLandschaft> landschaftenFuerOrt(OrtEintrag ort);

  /// Beobachtet die Daten, die die Tätigkeit braucht (etwa einen Katalog).
  ///
  /// Wartet nie mit `.future` (Fehler enden nie); die Kachel zeigt Laden und
  /// Fehler selbst.
  AsyncValue<Object?> beobachteDaten(WidgetRef ref);

  /// Gesamterschwernis für [kontext] (positiv = schwerer).
  int erschwernis(KartoWildnisKontext kontext);

  /// Erklärt einen Anteil der Erschwernis, der aus der Wahl stammt (etwa die
  /// Suchschwierigkeit des gesuchten Krauts); `null` ohne solchen Anteil.
  String? erschwernisHinweis(KartoWildnisKontext kontext) => null;

  /// Angaben zum gewählten Ziel (etwa dem gesuchten Kraut) zum Aufklappen
  /// unter der Zusammenfassung; `null` ohne Ziel.
  WildnisErgebnisZeile? zielAngaben(KartoWildnisKontext kontext) => null;

  /// TaW der Probe nach gewählter Dauer.
  int tawBeiDauer(KartoWildnisKontext kontext);

  /// Baut die Probe für [kontext].
  ResolvedProbeRequest baueProbe(KartoWildnisKontext kontext);

  /// Setzt die ausgewürfelte [probe] in die Ausbeute um.
  WildnisErgebnis auswerten(
    KartoWildnisKontext kontext,
    ProbeResult probe, {
    required DiceRoller roller,
  });

  /// Zeilen der Vorschau vor dem Wurf (etwa die möglichen Kräuter); leer, wenn
  /// die Tätigkeit keine kennt.
  List<WildnisErgebnisZeile> vorschau(KartoWildnisKontext kontext) =>
      const <WildnisErgebnisZeile>[];
}
