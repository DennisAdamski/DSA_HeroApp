/// Kampfwerte des laufenden Gefechts mit ihren Herleitungen.
///
/// INI, AT, PA, Schild-PA und Ausweichen schwanken im Gefecht am stärksten
/// (Sitzungswurf, INI-Verluste, hohe INI, Wunden, Distanzklasse, Folgemali).
/// Das Modul stellt sie mit dem Rechenweg des **aktuellen** Gefechtsstands
/// zusammen: Der Grundwert kommt aus der Kampfvorschau samt Sitzungsanteil,
/// der Zielwert aus derselben Prüfung wie der Aktionsknopf
/// (`pruefeGefechtAuftrag`). Es rechnet nichts Neues; die Oberfläche summiert
/// nicht, sondern zeigt die Schritte.
library;

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import 'gefecht_auftrag_rules.dart';
import 'gefecht_held_rules.dart';
import 'gefecht_herleitung_rules.dart';
import 'gefecht_kampfmittel_rules.dart';
import 'gefecht_rules.dart';
import 'gefecht_zielwert_herleitung_rules.dart';
import 'herleitung.dart';
import 'kampf_ini_herleitung_rules.dart';
import 'waffenlos_slot_rules.dart';

/// Ein Kampfwert der Gefechtsansicht.
class GefechtsKampfwert {
  /// Bündelt Anzeige, Rechenweg und aktuelle Erschwernis eines Werts.
  const GefechtsKampfwert({
    required this.id,
    required this.kuerzel,
    required this.titel,
    required this.anzeige,
    this.wert,
    this.herleitung,
    this.zielwert,
    this.erschwernis = 0,
    this.erschwernisHerleitung,
    this.hinweise = const [],
  });

  /// Stabile Kennung für Schlüssel und Tests (`ini`, `at`, `pa`, …).
  final String id;

  /// Kurzbezeichnung der Kachel.
  final String kuerzel;

  /// Ausgeschriebener Name für das Detailblatt.
  final String titel;

  /// Angezeigter Wert; bei TP der Würfelausdruck.
  final String anzeige;

  /// Zahlenwert, soweit es einen gibt (nicht bei TP).
  final int? wert;

  /// Rechenweg des Werts ohne situative Erschwernis; seine Summe ist [wert].
  final Herleitung? herleitung;

  /// Zielwert der Probe unter den aktuellen Gefechtsbedingungen.
  final int? zielwert;

  /// Gesamte aktuelle Erschwernis (0 = keine).
  final int erschwernis;

  /// Benannte Anteile der Erschwernis.
  final Herleitung? erschwernisHerleitung;

  /// Zusätzliche Hinweise zum Zustand (etwa hohe INI oder offene Folgemali).
  final List<String> hinweise;

  /// Die Probe ist unter den aktuellen Bedingungen leichter oder schwerer.
  bool get weichtAb => zielwert != null && wert != null && zielwert != wert;
}

/// Herleitung der Gefechts-INI: Schritte der Vorschau-Kampf-INI mit dem Wurf
/// der Sitzung statt des Vorschauwurfs, dazu Kopfwunde und INI-Verluste.
///
/// [vorschau] ist `KampfHerleitungen.kampfIni`; [kopfIniMalus] der laufende
/// Kopfwunden-Anteil (`WundEffekte.aktuellerIniMalus`, positiv). `null`, wenn
/// die Summe nicht `gefechtsInitiative(s, w)` entspricht.
Herleitung? herleiteGefechtsIni({
  required Gefechtszustand s,
  required Gefechtswerte w,
  required Herleitung? vorschau,
  required int kopfIniMalus,
}) {
  final schritte = <HerleitungsSchritt>[];
  if (vorschau == null) {
    schritte.add(
      HerleitungsSchritt(
        bezeichnung: 'INI-Basis',
        betrag: w.iniBasis,
        art: HerleitungsArt.grundwert,
        quelle: 'Kampfvorschau',
      ),
    );
  } else {
    var untergrenze = 0;
    for (final schritt in vorschau.schritte) {
      if (schritt.bezeichnung == kIniWurfSchritt) continue;
      if (schritt.art == HerleitungsArt.begrenzung) {
        untergrenze += schritt.betrag;
        continue;
      }
      schritte.add(schritt);
    }
    if (untergrenze != 0) {
      schritte.add(
        HerleitungsSchritt(
          bezeichnung: 'Untergrenze der Vorschau',
          betrag: untergrenze,
          art: HerleitungsArt.begrenzung,
          formel:
              'Die Vorschau hob ihren Wert auf 0 an; der Sitzungswurf '
              'ersetzt ihren Wurf',
        ),
      );
    }
    schritte.add(
      HerleitungsSchritt(
        bezeichnung: 'Kopfwunde (laufender Kampf)',
        betrag: -kopfIniMalus,
        art: HerleitungsArt.modifikator,
        quelle: 'Wunden',
      ),
    );
  }
  schritte.addAll([
    HerleitungsSchritt(
      bezeichnung: 'INI-Wurf (Sitzung)',
      betrag: s.iniWurf,
      art: HerleitungsArt.modifikator,
      quelle: 'Gefecht',
    ),
    HerleitungsSchritt(
      bezeichnung: 'Überzahl und Taktik',
      betrag: s.lageIni,
      art: HerleitungsArt.modifikator,
      quelle: 'Begegnung',
      formel: 'INI +1 je Kopf Überzahl (höchstens +4) und Taktik (WdS S. 81)',
    ),
    HerleitungsSchritt(
      bezeichnung: 'Kampfverluste',
      betrag: -s.iniVerlust,
      art: HerleitungsArt.modifikator,
      quelle: 'Gefecht',
    ),
    HerleitungsSchritt(
      bezeichnung: 'Geschützter INI-Verlust',
      betrag: -s.geschuetzterIniVerlust,
      art: HerleitungsArt.modifikator,
      quelle: 'Gefecht',
    ),
    HerleitungsSchritt(
      bezeichnung: 'Ungeklärter INI-Verlust',
      betrag: -s.ungeklaerterIniVerlust,
      art: HerleitungsArt.modifikator,
      quelle: 'Gefecht',
    ),
  ]);
  final herleitung = Herleitung(bezeichnung: 'INI', schritte: schritte);
  return herleitung.wert == gefechtsInitiative(s, w) ? herleitung : null;
}

// Dieselbe Prüfung wie der Aktionsknopf, ohne Dialogvorbelegung; ohne Katalog
// die Grundprüfung (ohne Ansagen und Folgemali).
Gefechtspruefung _pruefung(
  Gefechtszustand s,
  HeroComputedSnapshot snapshot,
  RulesCatalog? katalog,
  Gefechtswerte w,
  Gefechtsaktion aktion,
) => katalog == null
    ? pruefeGefechtsaktion(s, w, aktion)
    : pruefeGefechtAuftrag(
        s,
        snapshot,
        katalog,
        GefechtAuftrag(
          aktion: aktion,
          titel: '',
          zuschlag: 0,
          dk: s.dk,
          dauer: 1,
          kosten: 1,
        ),
      );

GefechtsKampfwert? _probenwert({
  required String id,
  required String kuerzel,
  required String titel,
  required Gefechtspruefung p,
  Herleitung? ersatz,
  List<String> hinweise = const [],
}) {
  final grund = p.zielHerleitung ?? ersatz;
  if (grund == null) return null;
  return GefechtsKampfwert(
    id: id,
    kuerzel: kuerzel,
    titel: titel,
    anzeige: '${grund.wert}',
    wert: grund.wert,
    herleitung: grund,
    zielwert: p.zielwert,
    erschwernis: p.erschwernis,
    erschwernisHerleitung: herleiteGefechtsErschwernis(p),
    hinweise: hinweise,
  );
}

/// Die Kampfwerte des Helden im aktuellen Gefechtsstand.
///
/// Reihenfolge: INI, AT, PA, Schild-PA, Ausweichen, TP, RS, BE. Werte, die
/// es nicht gibt (PA im Fernkampf, AT ohne Waffe, Schild-PA ohne Schild),
/// entfallen. [katalog] darf fehlen; dann gilt die Grundprüfung.
List<GefechtsKampfwert> gefechtsKampfwerte(
  Gefechtszustand s,
  HeroComputedSnapshot snapshot,
  RulesCatalog? katalog,
) {
  final w = gefechtswerteFuer(snapshot, katalog: katalog);
  final c = snapshot.combatPreviewStats;
  final h = c.herleitungen;
  final bonus = gefechtsIniBonus(s, w);
  final ini = gefechtsInitiative(s, w);
  final iniHerleitung = herleiteGefechtsIni(
    s: s,
    w: w,
    vorschau: h?.kampfIni,
    kopfIniMalus: snapshot.wundEffekte.aktuellerIniMalus,
  );
  final folgen = [
    if (s.ansageFolgemalus > 0)
      'Ansagefolgemalus +${s.ansageFolgemalus} auf Proben bis einschließlich '
          'der nächsten AT/PA.',
    if (s.meisterparadeBonus > 0)
      'Meisterparade: nächste Angriffs- oder Abwehraktion um '
          '${s.meisterparadeBonus} erleichtert.',
  ];
  final abwehrHinweise = [
    if (bonus > 0) 'Hohe INI $ini: PA und Ausweichen +$bonus.',
    ...folgen,
  ];
  final angriff = _pruefung(s, snapshot, katalog, w, Gefechtsaktion.angriff);
  final parade = _pruefung(s, snapshot, katalog, w, Gefechtsaktion.parade);
  final schild = w.schildPa == null
      ? null
      : _pruefung(s, snapshot, katalog, w, Gefechtsaktion.schildparade);
  final ausweichen = _pruefung(
    s,
    snapshot,
    katalog,
    w,
    Gefechtsaktion.freiesAusweichen,
  );
  final tp = gefechtsAngriffsanzeige(snapshot)?.tp;
  return [
    GefechtsKampfwert(
      id: 'ini',
      kuerzel: 'INI',
      titel: 'Initiative',
      anzeige: '$ini',
      wert: ini,
      herleitung: iniHerleitung,
      hinweise: [
        if (s.fixierterIniBonus != null)
          'INI-Bonus dieser Runde fixiert: +${s.fixierterIniBonus}.',
        if (bonus > 0 && s.fixierterIniBonus == null)
          'Über INI 20 +1, über 30 +2, über 40 +3 auf PA und Ausweichen.',
      ],
    ),
    if (w.waffeVorhanden)
      ?_probenwert(
        id: 'at',
        kuerzel: w.fernkampf ? 'FK' : 'AT',
        titel: w.fernkampf ? 'Fernkampf' : 'Attacke',
        p: angriff,
        ersatz: herleitungAusWert(w.fernkampf ? 'FK' : 'AT', w.at),
        hinweise: folgen,
      ),
    if (w.waffeVorhanden && !w.fernkampf)
      ?_probenwert(
        id: 'pa',
        kuerzel: 'PA',
        titel: 'Parade',
        p: parade,
        ersatz: gefechtsGrundwert(
          vorschau: w.paHerleitung,
          wert: w.pa,
          name: 'PA',
          iniBonus: bonus,
        ),
        hinweise: abwehrHinweise,
      ),
    if (schild != null)
      ?_probenwert(
        id: 'schildpa',
        kuerzel: 'Schild',
        titel: 'Schild-Parade',
        p: schild,
        hinweise: abwehrHinweise,
      ),
    ?_probenwert(
      id: 'aw',
      kuerzel: 'AW',
      titel: 'Ausweichen',
      p: ausweichen,
      ersatz: gefechtsAusweichen(s, w),
      hinweise: abwehrHinweise,
    ),
    if (tp != null)
      GefechtsKampfwert(
        id: 'tp',
        kuerzel: 'TP',
        titel: 'Trefferpunkte',
        anzeige: tp,
        herleitung: gefuehrteHauptwaffe(snapshot.hero.combatConfig) != null
            ? h?.tpZuschlag
            : null,
      ),
    GefechtsKampfwert(
      id: 'rs',
      kuerzel: 'RS',
      titel: 'Rüstungsschutz',
      anzeige: '${c.rsTotal}',
      wert: c.rsTotal,
      herleitung: h?.rs,
    ),
    GefechtsKampfwert(
      id: 'be',
      kuerzel: 'BE',
      titel: 'Behinderung im Kampf',
      anzeige: '${c.beKampf}',
      wert: c.beKampf,
      herleitung: h?.beKampf,
    ),
  ];
}
