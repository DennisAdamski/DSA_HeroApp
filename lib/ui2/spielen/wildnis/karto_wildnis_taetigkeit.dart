import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/kraeuter_eintrag.dart';
import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/meta_talent_rules.dart';
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
    this.dynamischerStandard,
  });

  /// Stabiler Schlüssel innerhalb der Tätigkeit.
  final String schluessel;

  /// Beschriftung des Felds.
  final String bezeichnung;

  /// Mögliche Antworten: Schlüssel und Anzeigetext.
  final List<({String schluessel, String text})> werte;

  /// Schlüssel der vorbelegten Antwort. Passt er nicht zu den
  /// [dynamischeWerte]n, gilt [dynamischerStandard], sonst deren erste
  /// Antwort.
  final String standard;

  /// Ob die Wahl zur aktuellen Auswahl passt; ohne Angabe immer.
  final bool Function(Map<String, String> optionen)? sichtbar;

  /// Antworten, die vom Kontext abhängen (etwa die Kräuter der Landschaft
  /// oder die Waffen des Helden); ersetzt [werte], wenn gesetzt.
  final List<({String schluessel, String text})> Function(
    KartoWildnisKontext kontext,
  )?
  dynamischeWerte;

  /// Vorgabe, die vom Kontext abhängt (etwa die erste Waffe des Helden, sonst
  /// der Kurzbogen); gilt, wenn die gespeicherte Antwort nicht mehr passt.
  final String Function(KartoWildnisKontext kontext)? dynamischerStandard;
}

/// Eine wählbare Dauer der Tätigkeit in Minuten.
typedef KartoWildnisDauer = ({int minuten, String text});

/// Alle Eingaben einer Wildnisprobe, so wie die Kachel sie zusammenträgt.
class KartoWildnisKontext {
  /// Erstellt den Kontext.
  const KartoWildnisKontext({
    required this.held,
    required this.katalog,
    required this.landschaft,
    required this.jahreszeit,
    required this.monat,
    required this.taw,
    required this.dauerMinuten,
    required this.eigenschaften,
    required this.gelaendekunde,
    required this.ortskenntnis,
    required this.eingesetzteAsp,
    required this.situativeErschwernis,
    required this.optionen,
    required this.daten,
  });

  /// Der Held (Talente, Waffen, Sonderfertigkeiten); nur lesen.
  final HeroSheet held;

  /// Regelkatalog des Helden (für Sonderfertigkeiten und Manöver).
  final RulesCatalog? katalog;

  /// Durchsuchte Landschaft.
  final WildnisLandschaft landschaft;

  /// Jahreszeit der Probe; `null` nur bei Tätigkeiten ohne
  /// [KartoWildnisTaetigkeit.brauchtJahreszeit].
  final Jahreszeit? jahreszeit;

  /// Monatsschlüssel des aventurischen Datums; leer, wenn unbekannt.
  final String monat;

  /// TaW der Tätigkeit bei der Grunddauer
  /// ([KartoWildnisTaetigkeit.grundTaw]).
  final int taw;

  /// Gewählte Dauer in Minuten.
  final int dauerMinuten;

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

/// Eine Wildnistätigkeit der Wildnis-Kachel: Kräuter suchen, Nahrung
/// sammeln, Pirsch- und Ansitzjagd, Fallenstellen, Fischen …
///
/// Die Kachel kennt nur diese Schnittstelle. Gemeinsam sind Landschaft,
/// Datum, Geländekunde, Ortskenntnis, TaW aus Bestandteil-Talenten, AsP, die
/// Probe über das Würfelprotokoll und die Ergebnisanzeige; die Tätigkeit
/// liefert, was sich unterscheidet. Eine neue Tätigkeit ist eine Unterklasse
/// plus ein Eintrag in `kartoWildnisTaetigkeiten`, ohne Umbau der Kachel.
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
  /// das Doppelte des niedrigsten). Tätigkeiten mit wählbaren Bestandteilen
  /// (etwa der Waffe) überschreiben [grundTaw].
  List<String> get talentKomponenten;

  /// TaW bei der Grunddauer für [held] und die gewählten [optionen].
  ///
  /// [optionen] können noch ungeprüft sein; die Tätigkeit fällt bei einer
  /// unbekannten Antwort auf ihre Vorgabe zurück.
  int grundTaw(HeroSheet held, Map<String, String> optionen) =>
      computeMetaTalentBaseTaw(
        talentEntries: held.talents,
        componentTalentIds: talentKomponenten,
      );

  /// Die drei Probeneigenschaften.
  List<AttributeCode> get eigenschaften;

  /// Ob die Jahreszeit die Probe verändert; sonst blendet die Kachel die Wahl
  /// aus und verlangt sie nicht.
  bool get brauchtJahreszeit => true;

  /// Was eine Geländekunde bei dieser Tätigkeit wert ist.
  GelaendekundeStaffel get gelaendekundeStaffel =>
      GelaendekundeStaffel.standard;

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

  /// Warum die Probe unter [kontext] nicht möglich ist (etwa Fallenstellen in
  /// der Wüste); `null`, wenn gewürfelt werden kann.
  String? sperrgrund(KartoWildnisKontext kontext) => null;

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

  /// Überschrift der Vorschau mit [anzahl] Zeilen.
  String vorschauTitel(int anzahl) => 'Mögliche Funde ($anzahl)';

  /// Zeilen der Vorschau vor dem Wurf (etwa die möglichen Kräuter); leer, wenn
  /// die Tätigkeit keine kennt.
  List<WildnisErgebnisZeile> vorschau(KartoWildnisKontext kontext) =>
      const <WildnisErgebnisZeile>[];
}
