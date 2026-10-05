import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_patzer.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';

import 'gefecht_rules.dart';

/// WdS MCP 7058; Hausregel 25819 erhält BF nach bestandenem kritischen Bruchtest.
GefechtsBruchergebnis werteGefechtsBruchtest(
  int bf,
  int wurf, {
  required bool kritisch,
}) {
  _pruefeSumme(wurf);
  final zerbrochen = wurf <= bf;
  final erhoehen = !zerbrochen && !kritisch && wurf != 12;
  return GefechtsBruchergebnis(erhoehen ? bf + 1 : bf, zerbrochen);
}

/// WdS MCP 7057: Nahkampf zu Fuß, keine Fernkampf-/Reittier-Tabelle.
GefechtsPatzerfolge gefechtsPatzerfolge(
  int wurf, {
  required int bf,
  bool natuerlich = false,
  bool unzerstoerbar = false,
  bool sturzAbgewendet = false,
}) {
  _pruefeSumme(wurf);
  if (wurf == 2 && natuerlich) wurf = 12;
  if ((wurf == 9 || wurf == 10) && natuerlich) wurf = 4;
  if (wurf == 2) {
    return GefechtsPatzerfolge(
      titel: bf <= 0 ? 'Waffe verloren' : 'Waffe zerstört',
      iniVerlust: 4,
      zerbrochen: bf > 0,
      waffeVerloren: bf <= 0,
      bfAenderung: bf <= 0 && !unzerstoerbar ? 2 : 0,
    );
  }
  if (wurf <= 5) {
    return GefechtsPatzerfolge(
      titel: sturzAbgewendet ? 'Stolpern' : 'Sturz',
      iniVerlust: 2,
      sturz: !sturzAbgewendet,
    );
  }
  if (wurf <= 8) {
    return const GefechtsPatzerfolge(titel: 'Stolpern', iniVerlust: 2);
  }
  if (wurf <= 10) {
    return const GefechtsPatzerfolge(
      titel: 'Waffe verloren',
      iniVerlust: 2,
      waffeVerloren: true,
    );
  }
  return GefechtsPatzerfolge(
    titel: wurf == 11 ? 'Eigentreffer' : 'Schwerer Eigentreffer',
    iniVerlust: wurf == 11 ? 3 : 4,
    schadensFaktor: wurf == 11 ? 1 : 2,
  );
}

// Nur echte 2W6-Ergebnisse dürfen eine Quellenfolge auslösen.
void _pruefeSumme(int wurf) {
  if (wurf < 2 || wurf > 12) throw ArgumentError.value(wurf, '2W6');
}

/// WdS 7056: alle restlichen Aktionen einschließlich SK-II und Reserve entfallen.
Gefechtszustand verbraucheGefechtsPatzer(
  Gefechtszustand s,
  Gefechtswerte w,
  GefechtsPatzerfolge folge,
) => s.copyWith(
  angriffeVerbraucht: 2,
  paradenVerbraucht: 2,
  schildparadenVerbraucht: 1,
  freieVerbraucht: 2 + gefechtsIniBonus(s, w),
  zusatzVerbraucht: w.zusatzaktionen,
  regulaereAttacke: true,
  regulaereParade: true,
  umgewandelteAktionOffen: false,
  ohneReserve: true,
  reserveBereit: false,
  ohneKlingen: true,
  iniVerlust: s.iniVerlust + folge.iniVerlust,
  desorientiert: true,
  haltung: folge.sturz ? Gefechtshaltung.liegend : s.haltung,
);

/// Identische Waffen-ID gilt in Haupt- und Nebenhand als derselbe Gegenstand.
String gefechtsMittelSchluessel(GefechtsKampfmittelwahl w) =>
    '${w.art == GefechtsKampfmittelArt.hauptwaffe || w.art == GefechtsKampfmittelArt.nebenwaffe ? "waffe" : "nebenhand"}:${w.id}';

/// Findet konkrete Waffen/Schild-ID und bestätigt alle Felder des Einzelprofils.
GefechtsBruchprofil? gefechtsBruchprofil(
  CombatConfig c,
  GefechtsKampfmittelwahl w,
) {
  if (w.id.isEmpty) return null;
  if (w.art == GefechtsKampfmittelArt.hauptwaffe ||
      w.art == GefechtsKampfmittelArt.nebenwaffe) {
    final liste = c.weaponSlots.where((e) => e.id == w.id).toList();
    if (liste.length != 1) return null;
    final e = liste.single;
    return GefechtsBruchprofil(
      w,
      e.name,
      e.breakFactor,
      stableContentHash(e.toJson()),
    );
  }
  final liste = c.offhandEquipment.where((e) => e.id == w.id).toList();
  if (liste.length != 1) return null;
  final e = liste.single;
  return GefechtsBruchprofil(
    w,
    e.name,
    e.breakFactor,
    stableContentHash(e.toJson()),
  );
}

/// Schreibt nur BF am frischen ID-Treffer; Änderungen benötigen neue Bestätigung.
CombatConfig schreibeGefechtsBruchfaktor(
  CombatConfig c,
  GefechtsBruchprofil p,
  int bf,
) {
  final frisch = gefechtsBruchprofil(c, p.wahl);
  if (frisch == null || frisch.nachweis != p.nachweis) {
    throw StateError(
      'BF oder Waffenprofil geändert. Aktuellen Stand erneut bestätigen.',
    );
  }
  if (p.wahl.art == GefechtsKampfmittelArt.hauptwaffe ||
      p.wahl.art == GefechtsKampfmittelArt.nebenwaffe) {
    return c.copyWith(
      weapons: [
        for (final e in c.weaponSlots)
          if (e.id == p.wahl.id) e.copyWith(breakFactor: bf) else e,
      ],
    );
  }
  return c.copyWith(
    offhandEquipment: [
      for (final e in c.offhandEquipment)
        if (e.id == p.wahl.id) e.copyWith(breakFactor: bf) else e,
    ],
  );
}

/// Nur tatsächliche Nahkampf-AT/PA-Zwanzig öffnet den Folgewurf.
bool istGefechtsPatzerkandidat(ProbeResult r) =>
    (r.request.type == ProbeType.combatAttack ||
        r.request.type == ProbeType.combatParry) &&
    r.diceValues.length == 1 &&
    r.diceValues.single == 20 &&
    r.effectiveTargetValues.length == 1;

/// Kontrollwurf behält sämtliche ursprünglichen situativen/Ansage-Modifikatoren.
ResolvedProbeRequest gefechtsPatzerKontrollprobe(ProbeResult r) =>
    ResolvedProbeRequest(
      type: r.request.type,
      title: 'Patzer-Kontrollwurf',
      subtitle: r.request.title,
      ruleHint: 'WdS 7055/7056: Erfolg verhindert den Patzer, die ursprüngliche Probe bleibt misslungen.',
      diceSpec: const DiceSpec(count: 1, sides: 20),
      targets: [
        ProbeTargetValue(
          label: 'Kontrolle',
          value: r.effectiveTargetValues.single,
        ),
      ],
    );

/// Gefrorener Tabellen-/Bruchwurf hat ausschließlich zwei echte W6 ohne Zuschlag.
int gefechtsPatzerW6Summe(ProbeResult r) {
  if (r.diceValues.length != 2 || r.diceValues.any((v) => v < 1 || v > 6)) {
    throw StateError('Zwei gültige W6 erforderlich.');
  }
  return r.diceValues[0] + r.diceValues[1];
}

/// Defekte werden flüchtig gesperrt und niemals aus dem Inventar entfernt.
String? gefechtKampfmittelGesperrt(
  GefechtsPatzerstand s,
  GefechtsKampfmittelwahl w,
) => s.gesperrteMittel[gefechtsMittelSchluessel(w)];

/// Der Verlust gilt bis Rundenende, ungeklärte Folgewürfe bis ihrem Abschluss.
bool gefechtPatzerSperrt(GefechtsPatzerstand s, int runde) =>
    s.verloreneRunde == runde || gefechtFolgewuerfeOffen(s);

/// Offene gefrorene Folgen blockieren Rundenwechsel bis zum konkreten Abschluss.
bool gefechtFolgewuerfeOffen(GefechtsPatzerstand s) =>
    s.patzer != null && !s.patzer!.erledigt ||
    s.bruch != null && !s.bruch!.erledigt;

/// Berechnet den ausdrücklich in der Patzertabelle angeordneten neuen BF.
int gefechtsPatzerBruchfaktor(GefechtsBruchprofil p, GefechtsPatzerfolge f) =>
    p.bf + f.bfAenderung;

/// Nur tatsächlich wiederaufgenommene verlorene Mittel werden freigegeben.
/// Zerbrochene Mittel bleiben über diesen Pfad immer gesperrt.
GefechtsPatzerstand bestaetigeGefechtsWiederaufnahme(
  GefechtsPatzerstand s,
  String schluessel,
) {
  if (!s.verloreneMittel.contains(schluessel)) return s;
  final gesperrt = Map<String, String>.of(s.gesperrteMittel)
    ..remove(schluessel);
  final verloren = Set<String>.of(s.verloreneMittel)..remove(schluessel);
  return s.copyWith(gesperrteMittel: gesperrt, verloreneMittel: verloren);
}

/// Ergänzt transiente Patzersperren ohne Verlust bestehender Freigabemetadaten.
Gefechtspruefung ergaenzeGefechtsPatzerfreigabe(
  Gefechtspruefung p,
  Gefechtszustand s,
  GefechtsKampfmittelwahl? w,
) {
  final grund = w == null
      ? null
      : s.gesperrteKampfmittel[gefechtsMittelSchluessel(w)];
  final sperren = <String>[...p.sperrgruende, ?s.patzerSperre, ?grund];
  if (sperren.length == p.sperrgruende.length) return p;
  return Gefechtspruefung(
    aktion: p.aktion,
    status: Gefechtsfreigabe.gesperrt,
    gruende: [...p.gruende, ...sperren.skip(p.sperrgruende.length)],
    zielwert: p.zielwert,
    angriffe: p.angriffe,
    paraden: p.paraden,
    freie: p.freie,
    zusatz: p.zusatz,
    erschwernis: p.erschwernis,
    modifikatoren: p.modifikatoren,
    kampfmittel: p.kampfmittel,
    ausruestungspaar: p.ausruestungspaar,
    mitAnsage: p.mitAnsage,
    probenart: p.probenart,
    sperrgruende: sperren,
    fehlendeAngaben: p.fehlendeAngaben,
    entscheidungen: p.entscheidungen,
    hinweise: p.hinweise,
    meisterparadeAnsage: p.meisterparadeAnsage,
    verbrauchterMeisterparadeBonus: p.verbrauchterMeisterparadeBonus,
    ansageFehlmalus: p.ansageFehlmalus,
    beendetAnsageFolgemalus: p.beendetAnsageFolgemalus,
  );
}
