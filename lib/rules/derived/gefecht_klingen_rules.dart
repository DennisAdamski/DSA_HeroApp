import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_klingen.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_angriff.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import 'excel_rounding.dart';
import 'gefecht_held_rules.dart';
import 'gefecht_rules.dart';
import 'gefecht_kontext_rules.dart';
import 'gefecht_angriff_rules.dart';

import 'dart:convert';

import 'gefecht_initiative_rules.dart';
import 'gefecht_patzer_rules.dart';

import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';

/// WdS MCP 6997/7013/7030: halbiert oder verteilt den um vier verbesserten Pool.
List<int> gefechtsKlingenwerte(
  int basis, {
  bool kampfgespuer = false,
  bool klingentaenzer = false,
  List<int>? verteilung,
}) {
  if (!kampfgespuer && !klingentaenzer) {
    if (verteilung != null && verteilung.length != 2) {
      throw ArgumentError('Zwei Teilproben.');
    }
    return List.unmodifiable([
      excelRound(basis / 2) + 2,
      excelRound(basis / 2) + 2,
    ]);
  }
  final werte =
      verteilung ?? [((basis + 4) ~/ 2), basis + 4 - ((basis + 4) ~/ 2)];
  if (werte.length < 2 ||
      werte.length > (klingentaenzer ? 3 : 2) ||
      werte.any((w) => w < 6) ||
      werte.fold<int>(0, (a, b) => a + b) != basis + 4) {
    throw ArgumentError('Pool ${basis + 4}: mindestens 6 pro Gegner.');
  }
  return List.unmodifiable(werte);
}

/// Gemeinsame Freigabe für Liste und geteilten Ausführungsweg ohne Einzelprobe.
Gefechtspruefung pruefeGefechtsKlingenbeginn(
  Gefechtszustand s,
  HeroComputedSnapshot snapshot,
  RulesCatalog k,
  ManeuverDef m, {
  GefechtsKampfmittelwahl? kampfmittel,
}) {
  final wand = m.id == 'man_klingenwand';
  final w = gefechtswerteFuer(snapshot, katalog: k, kampfmittel: kampfmittel);
  final idealDk = [
    'H',
    'N',
    'S',
    'P',
  ].where((d) => gefechtsDkDifferenz(w.waffenDk, d) == 0).firstOrNull;
  final basis = s.copyWith(
    dk: idealDk,
    kontext: Gefechtskontext(
      kontakt: s.kontext.kontakt,
      gegnerId: s.kontext.gegnerId,
      angriffsart: Gefechtsangriffsart.nahkampf,
      finte: 0,
      situationsZuschlag: s.kontext.situationsZuschlag,
      schildWmWirksam: true,
    ),
  );
  final p = pruefeGefechtsmanoever(
    basis,
    snapshot,
    k,
    m,
    zuschlag: 0,
    kampfmittel: kampfmittel,
    geteilteProbe: true,
  );
  final sperren = <String>[
    ...p.sperrgruende,
    if (s.klingen != null) 'Geteilter Ablauf bereits offen.',
    if (s.reserveIni != null) 'Verzögerte Reserve zuerst abwickeln.',
    if (w.fernkampf) 'Klingenmanöver benötigen eine Nahkampfwaffe.',
    if (wand ? s.paradenVerbraucht > 0 : s.angriffeVerbraucht > 0)
      'Nur die erste reguläre AT/PA darf aufgeteilt werden.',
    if (wand &&
        !w.klingentaenzerAktiv &&
        (s.angriffeVerbraucht > 0 ||
            s.freieVerbraucht > 0 ||
            s.zusatzVerbraucht > 0))
      'Klingenwand zu Beginn der Runde ansagen.',
    if (!wand && w.be > 4) 'Klingensturm benötigt BE höchstens 4.',
  ];
  // Wie `ergaenzeGefechtsfreigabe`: Hinweise allein ergeben „Bereit“ und
  // bleiben sichtbar; „Klären“ entsteht nur mit benanntem Grund.
  final hinweise = p.hinweise.isNotEmpty
      ? p.hinweise
      : p.gruende
            .where(
              (g) =>
                  !sperren.contains(g) &&
                  !p.fehlendeAngaben.contains(g) &&
                  !p.entscheidungen.contains(g),
            )
            .toList();
  final status = sperren.isNotEmpty
      ? Gefechtsfreigabe.gesperrt
      : p.fehlendeAngaben.isNotEmpty || p.entscheidungen.isNotEmpty
      ? Gefechtsfreigabe.pruefen
      : Gefechtsfreigabe.bereit;
  return Gefechtspruefung(
    aktion: p.aktion,
    status: status,
    gruende: [
      ...sperren,
      ...p.fehlendeAngaben,
      ...p.entscheidungen,
      ...hinweise,
    ],
    sperrgruende: sperren,
    fehlendeAngaben: p.fehlendeAngaben,
    entscheidungen: p.entscheidungen,
    hinweise: hinweise,
    zielwert: p.zielwert,
    angriffe: p.angriffe,
    paraden: p.paraden,
    freie: p.freie,
    zusatz: p.zusatz,
    erschwernis: p.erschwernis,
    kampfmittel: p.kampfmittel,
    ausruestungspaar: p.ausruestungspaar,
  );
}

/// Jede Ziel-DK und jeder Pool werden vor dem ersten Wurf vollständig geprüft.
void pruefeGefechtsKlingenteile(
  List<GefechtsKlingenteil> teile,
  Gefechtswerte w, {
  required bool parade,
}) {
  if (teile.length < 2 ||
      teile.length > (w.klingentaenzerAktiv ? 3 : 2) ||
      teile.map((t) => t.gegnerId).toSet().length != teile.length) {
    throw ArgumentError(
      'Zwei verschiedene Gegner, bei Klingentänzer bis zu drei.',
    );
  }
  for (final t in teile) {
    if (t.gegnerId.isEmpty ||
        t.finte < 0 ||
        gefechtsDkDifferenz(w.waffenDk, t.dk) != 0) {
      throw ArgumentError(
        'Jeder Gegner muss in einer idealen Waffen-DK stehen.',
      );
    }
  }
}

/// Eine tatsächliche erste Teilprobe bezahlt genau eine reguläre Quellmarke.
Gefechtszustand bucheGefechtsKlingenteil(
  Gefechtszustand s,
  Gefechtswerte w,
  int index,
  ProbeResult result,
) {
  final stand = s.klingen;
  if (stand == null ||
      index < 0 ||
      index >= stand.teile.length ||
      stand.teile[index].ergebnis != null) {
    return s;
  }
  var neu = stand.bezahlt
      ? s.copyWith(ohneAuftrag: true)
      : verbraucheGefechtsaktion(
          s,
          w,
          stand.basisPruefung,
          erfolg: result.success,
        );
  final teile = List<GefechtsKlingenteil>.of(stand.teile);
  teile[index] = teile[index].mitErgebnis(result);
  neu = neu.copyWith(
    klingen: stand.copyWith(teile: List.unmodifiable(teile), bezahlt: true),
  );
  if (!stand.bezahlt) {
    neu = neu.copyWith(meisterparadeBonus: 0, ansageFolgemalus: 0);
  }
  if (!stand.parade && result.success) {
    neu = ergaenzeGefechtsAngriffsergebnis(
      neu,
      Gefechtsangriffsergebnis(
        auftragId: '${stand.id}:$index',
        kampfmittel: stand.kampfmittel,
        waffenname: 'Klingensturm',
        schaden: stand.schaden,
        abwehrmalus: 0,
        tpBonus: 0,
        gegnerId: teile[index].gegnerId,
        hinweis: 'Getrennte Teilattacke; gegnerische Abwehr klären.',
      ),
    );
  }
  return neu;
}

/// Prüft das eingefrorene Mittel vor jeder weiteren tatsächlichen Teilprobe.
void pruefeGefechtsKlingenfortsetzung(
  Gefechtszustand s,
  Gefechtswerte w,
  int index,
) {
  final stand = s.klingen;
  if (stand == null ||
      index < 0 ||
      index >= stand.teile.length ||
      stand.teile[index].ergebnis != null ||
      s.auftrag != null ||
      s.handlung != null) {
    throw StateError('Teilprobe nicht verfügbar.');
  }
  if (gefechtsKlingenprofilKey(w) != stand.profilKey) {
    throw StateError('Waffenprofil geändert; geteilten Ablauf beenden.');
  }
  if (s.patzerSperre != null ||
      s.gesperrteKampfmittel[gefechtsMittelSchluessel(stand.kampfmittel)] !=
          null) {
    throw StateError(s.patzerSperre ?? 'Kampfmittel nicht verfügbar.');
  }
  if (stand.teile.take(index).any((t) => t.ergebnis == null)) {
    throw StateError('Vorherige Teilprobe zuerst abwickeln.');
  }
  if (!stand.parade) {
    final sperre = gefechtsZeitsperre(
      s.copyWith(angriffeVerbraucht: stand.bezahlt ? 0 : s.angriffeVerbraucht),
      w,
      Gefechtsaktion.angriff,
    );
    if (sperre != null) throw StateError(sperre);
  }
}

/// Sichtbare Vorbelegung der Aufteilung (Vorgaben statt Pflichtfelder,
/// Nutzerentscheidung vom 5. Oktober 2026).
///
/// Je Teilprobe die aktuelle Sitzungs-DK und verschiedene Gegner der
/// Begegnung, das aktuelle Ziel zuerst. Fehlen Gegner oder DK, bleibt der
/// Eintrag `null` und `pruefeGefechtsKlingenteile` verlangt ihn weiter.
({List<String?> gegner, List<String?> dk}) gefechtsKlingenVorgaben(
  Gefechtszustand s,
  List<String> gegnerIds, {
  int teile = 3,
}) {
  final ziel = s.kontext.gegnerId;
  final reihenfolge = [
    if (ziel != null && gegnerIds.contains(ziel)) ziel,
    ...gegnerIds.where((id) => id != ziel),
  ];
  return (
    gegner: [
      for (var i = 0; i < teile; i++)
        i < reihenfolge.length ? reihenfolge[i] : null,
    ],
    dk: List<String?>.filled(teile, s.dk),
  );
}

/// Getrennte Würfe verwenden den bestätigten Pool und die jeweilige Finte einmal.
ResolvedProbeRequest gefechtsKlingenrequest(
  GefechtsKlingenstand stand,
  GefechtsKlingenteil teil,
  String gegnername, {
  int meisterparadeBonus = 0,
  int ansageFolgemalus = 0,
}) => ResolvedProbeRequest(
  type: stand.parade ? ProbeType.combatParry : ProbeType.combatAttack,
  title: stand.parade ? 'Klingenwand' : 'Klingensturm',
  subtitle: gegnername,
  ruleHint: 'Getrennte Teilprobe; keine eigene Ansage. Ein reguläres Budget.',
  diceSpec: const DiceSpec(count: 1, sides: 20),
  targets: [
    ProbeTargetValue(label: stand.parade ? 'PA' : 'AT', value: teil.zielwert),
  ],
  initialSituationalModifier:
      (stand.parade ? -teil.finte : 0) +
      meisterparadeBonus -
      ansageFolgemalus -
      teil.erschwernis,
);

/// Änderungen der Waffe oder ihrer aktuellen Werte verlangen neue Bestätigung.
String gefechtsKlingenprofilKey(Gefechtswerte w) => jsonEncode({
  'waffe': w.waffe?.toJson(),
  'at': w.at,
  'pa': w.pa,
  'be': w.be,
  'schild': w.schildPa,
  'kg': w.kampfgespuer,
  'kt': w.klingentaenzerAktiv,
});

/// Übernimmt genau die Vorschau des konkreten Angriffsmittels ohne neue TP-Rechnung.
DiceSpec? gefechtsKlingenschaden(
  HeroComputedSnapshot s,
  GefechtsKampfmittelwahl w,
) => w.art == GefechtsKampfmittelArt.nebenwaffe
    ? s.combatPreviewStats.offhandPreview?.damageDiceSpec
    : s.combatPreviewStats.damageDiceSpec;
