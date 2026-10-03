import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_angriff.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import 'gefecht_ansage_rules.dart';
import 'gefecht_kampfmittel_rules.dart';

/// Ordnet bekannte Folgen über stabile IDs ein; Ungeklärtes erfindet keine TP.
GefechtsSchadensfolge gefechtsSchadensfolgeFuerAuftrag(GefechtAuftrag a) {
  if (a.distanzSchritte != 0) return GefechtsSchadensfolge.keinSchaden;
  if (a.manuell || a.probe != null) return GefechtsSchadensfolge.manuell;
  final id = a.manoever?.id;
  if (id == null) return GefechtsSchadensfolge.waffenschaden;
  const schadenslos = {'man_entwaffnen', 'man_umreissen'};
  if (schadenslos.contains(id)) return GefechtsSchadensfolge.keinSchaden;
  const unterstuetzt = {
    'man_finte',
    'man_wuchtschlag',
    'man_sturmangriff',
    'man_hammerschlag',
    'man_todesstos',
    'man_gezielter_stich',
    'man_niederwerfen',
  };
  return unterstuetzt.contains(id)
      ? GefechtsSchadensfolge.waffenschaden
      : GefechtsSchadensfolge.manuell;
}

// Ein Hinweis erklärt den bekannten Umfang, statt einen falschen Würfelweg zu retten.
String _schadenshinweis(GefechtsSchadensfolge folge, String? id) {
  if (folge == GefechtsSchadensfolge.keinSchaden) {
    return 'Kein Schaden. Gegnerische Abwehr und übrige Manöverfolgen '
        'am Tisch abwickeln.';
  }
  if (folge == GefechtsSchadensfolge.manuell) {
    return 'Schadensfolge manuell: Art, Höhe und weitere Folgen dieser '
        'Variante am Tisch festlegen. Kein gewöhnlicher Waffenschaden angenommen.';
  }
  if (id == 'man_hammerschlag') {
    return 'Hammerschlag: die gesamte gewürfelte TP-Summe einschließlich '
        'TP-Ansage am Tisch verdreifachen. Gegnerische Abwehr und Bruchtest beachten.';
  }
  return 'Gegnerische Abwehr, RS, Wunden und weitere Manöverfolgen am Tisch abwickeln.';
}

/// Hält offene Treffer unabhängig von späteren Treffern oder Fehlschlägen.
Gefechtszustand ergaenzeGefechtsAngriffsergebnis(
  Gefechtszustand s,
  Gefechtsangriffsergebnis? ergebnis,
) {
  if (ergebnis == null ||
      s.angriffsergebnisse.any((e) => e.auftragId == ergebnis.auftragId)) {
    return s;
  }
  return s.copyWith(
    angriffsergebnisse: List.unmodifiable([...s.angriffsergebnisse, ergebnis]),
  );
}

/// Entfernt ausschließlich den abgewickelten Treffer, auch bei Doppelcallback.
Gefechtszustand entferneGefechtsAngriffsergebnis(
  Gefechtszustand s,
  String id,
) => s.copyWith(
  angriffsergebnisse: List.unmodifiable(
    s.angriffsergebnisse.where((e) => e.auftragId != id),
  ),
);

/// Hält nur erfolgreich gebuchte Angriffsfolgen mit gebundenen Metadaten fest.
/// Ein Schadensprofil entsteht ausschließlich für unterstützten Waffenschaden.
Gefechtsangriffsergebnis? gefechtsAngriffsergebnisNachBuchung({
  required String auftragId,
  required bool buchungErfolgreich,
  required bool erfolg,
  required HeroComputedSnapshot snapshot,
  required RulesCatalog katalog,
  required GefechtAuftrag auftrag,
  required Gefechtspruefung pruefung,
}) {
  final angreifen =
      pruefung.aktion == Gefechtsaktion.angriff ||
      pruefung.aktion == Gefechtsaktion.zusatzaktion && !auftrag.zusatzParade;
  if (!buchungErfolgreich ||
      !erfolg ||
      !angreifen ||
      auftrag.distanzSchritte != 0) {
    return null;
  }
  final profil = gefechtsKampfmittelFuer(snapshot, pruefung.kampfmittel);
  if (profil == null || profil.waffe == null) return null;
  final neben = profil.wahl.art == GefechtsKampfmittelArt.nebenwaffe;
  final folge = gefechtsSchadensfolgeFuerAuftrag(auftrag);
  final dice = neben
      ? snapshot.combatPreviewStats.offhandPreview?.damageDiceSpec
      : snapshot.combatPreviewStats.damageDiceSpec;
  if (folge == GefechtsSchadensfolge.waffenschaden && dice == null) return null;
  final wirkung = gefechtsAnsagewirkung(snapshot, katalog, auftrag);
  return Gefechtsangriffsergebnis(
    auftragId: auftragId,
    kampfmittel: profil.wahl,
    waffenname: profil.name,
    schaden: folge == GefechtsSchadensfolge.waffenschaden
        ? DiceSpec(
            count: dice!.count,
            sides: dice.sides,
            modifier: dice.modifier + wirkung.tpBonus,
          )
        : null,
    abwehrmalus: wirkung.abwehrmalus,
    tpBonus: folge == GefechtsSchadensfolge.keinSchaden ? 0 : wirkung.tpBonus,
    schadensfolge: folge,
    manoevername: auftrag.manoever?.name ?? '',
    hinweis: _schadenshinweis(folge, auftrag.manoever?.id),
  );
}

/// Liefert nur für unterstützten Waffenschaden einen gebundenen Würfelauftrag.
/// Schadenslose und ungeklärte Folgen besitzen ausdrücklich keinen Request.
ResolvedProbeRequest? gefechtsSchadenFuerAngriff(Gefechtsangriffsergebnis e) {
  final dice = e.schaden;
  if (e.schadensfolge != GefechtsSchadensfolge.waffenschaden || dice == null) {
    return null;
  }
  return ResolvedProbeRequest(
    type: ProbeType.damage,
    title: 'Angriffsschaden',
    subtitle: '${e.waffenname} · ${dice.label}',
    ruleHint: e.hinweis,
    diceSpec: dice,
    targets: const [],
  );
}
