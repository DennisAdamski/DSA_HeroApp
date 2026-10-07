import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_angriff.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import 'gefecht_ansage_rules.dart';
import 'gefecht_kampfmittel_rules.dart';
import 'gefecht_fernkampf_rules.dart';
import 'maneuver_rules.dart';
import 'waffenlos_rules.dart';

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

/// Friert den ersten Schadenswurf ein, bis der tatsächliche Treffer bestätigt ist.
Gefechtszustand friereGefechtsAngriffsschadenEin(
  Gefechtszustand s,
  String id,
  int tp,
) => s.copyWith(
  angriffsergebnisse: List.unmodifiable([
    for (final e in s.angriffsergebnisse)
      if (e.auftragId == id && e.gewuerfelteTp == null)
        e.mitSchaden(tp < 0 ? 0 : tp)
      else
        e,
  ]),
);

/// Entfernt ausschließlich den abgewickelten Treffer, auch bei Doppelcallback.
Gefechtszustand entferneGefechtsAngriffsergebnis(
  Gefechtszustand s,
  String id,
) => s.copyWith(
  angriffsergebnisse: List.unmodifiable(
    s.angriffsergebnisse.where((e) => e.auftragId != id),
  ),
);

// TP(A) laut Katalogeintrag der Waffe oder der Handgemengewaffenliste.
bool _richtetTpAusdauerAn(RulesCatalog katalog, MainWeaponSlot waffe) {
  if (raufenwaffeFuer(waffe)?.tpAusdauer ?? false) return true;
  final name = waffe.weaponType.trim().isEmpty ? waffe.name : waffe.weaponType;
  return katalog.weapons.any(
    (w) => w.name == name.trim() && w.tp.contains('(A)'),
  );
}

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
  var folge = gefechtsSchadensfolgeFuerAuftrag(auftrag);
  final dice = gefechtsSchadenswuerfel(snapshot, profil.wahl);
  if (folge == GefechtsSchadensfolge.waffenschaden && dice == null) return null;
  var distanzKorrektur = 0;
  var hinweis = _schadenshinweis(folge, auftrag.manoever?.id);
  final waffenlos = gefechtsWaffenlosFuer(snapshot, profil.wahl)?.talent;
  if (folge == GefechtsSchadensfolge.waffenschaden &&
      waffenlos == WaffenlosesTalent.ringen) {
    // WdS S. 89: Ringen-Angriffe schaden nur als Wurf, sonst verschaffen sie
    // eine bessere Position; beides entscheidet der Tisch.
    folge = GefechtsSchadensfolge.manuell;
    hinweis =
        'Schadensfolge manuell: Ein Ringen-Angriff richtet nur als Wurf '
        '1W6 TP(A) an, sonst bringt er den Gegner in eine ungünstige Position.';
  } else if (folge == GefechtsSchadensfolge.waffenschaden &&
      waffenlos == WaffenlosesTalent.raufen) {
    hinweis =
        'Waffenlos: Die Trefferpunkte sind TP(A) (Ausdauerschaden). '
        'Panzerhandschuh, beschlagene Stiefel oder Metallhelm +2 TP(A). '
        '$hinweis';
  } else if (folge == GefechtsSchadensfolge.waffenschaden &&
      _richtetTpAusdauerAn(katalog, profil.waffe!)) {
    // AA S. 69/150: z. B. Schlagring, Stoß mit Schild, Turnierwaffen.
    final raufen = raufenwaffeFuer(profil.waffe!)?.hinweis ?? '';
    hinweis =
        'Die Trefferpunkte dieser Waffe sind TP(A) (Ausdauerschaden). '
        '${raufen.isEmpty ? '' : '$raufen '}$hinweis';
  }
  if (folge == GefechtsSchadensfolge.waffenschaden && profil.waffe!.isRanged) {
    final ranged = profil.waffe!.rangedProfile;
    final entfernung = auftrag.kontext?.entfernung;
    final band = entfernung == null
        ? null
        : gefechtsEntfernungsband(ranged.distanceBands, entfernung);
    if (band == null || band < 0) {
      folge = GefechtsSchadensfolge.manuell;
      hinweis =
          'Schadensfolge manuell: TP-Modifikator der tatsächlichen '
          'Entfernung am Tisch bestimmen; die Vorschau-Distanz gilt nicht für diesen Schuss.';
    } else {
      // Vorschau enthält alle übrigen TP-Anteile bereits, auch Geschoss/Effekte.
      distanzKorrektur =
          ranged.distanceBands[band].tpMod - ranged.selectedDistanceBand.tpMod;
    }
  }
  final wirkung = gefechtsAnsagewirkung(snapshot, katalog, auftrag);
  return Gefechtsangriffsergebnis(
    auftragId: auftragId,
    gegnerId: auftrag.kontext?.gegnerId,
    kampfmittel: profil.wahl,
    waffenname: profil.name,
    schaden: folge == GefechtsSchadensfolge.waffenschaden
        ? DiceSpec(
            count: dice!.count,
            sides: dice.sides,
            modifier: dice.modifier + distanzKorrektur + wirkung.tpBonus,
          )
        : null,
    abwehrmalus: wirkung.abwehrmalus,
    tpBonus: folge == GefechtsSchadensfolge.keinSchaden ? 0 : wirkung.tpBonus,
    schadensfolge: folge,
    manoevername: auftrag.manoever?.name ?? '',
    manoeverId: auftrag.manoever?.id,
    folgewuerfel: auftrag.manoever?.id == 'man_umreissen' ? dice : null,
    meisterlichesEntwaffnen:
        learnedManeuverIds(snapshot.hero.combatConfig, katalog).any(
          (id) =>
              id == 'man_meisterliches_entwaffnen' ||
              id.startsWith('man_meisterliches_entwaffnen::'),
        ),
    hinweis: hinweis,
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
