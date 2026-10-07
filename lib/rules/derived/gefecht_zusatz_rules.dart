import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import 'combat_special_ability_state.dart';
import 'gefecht_kampfmittel_rules.dart';
import 'gefecht_hand_rules.dart';
import 'gefecht_held_rules.dart';
import 'gefecht_rules.dart';
import 'two_weapon_combat_rules.dart';

/// Konkrete Quelle einer einzelnen Zusatzmarke mit ihrem berechneten Kampfmittel.
class GefechtsZusatzoption {
  /// Mehrteilige Angriffe werden ausdrücklich nicht als Einzelprobe angeboten.
  const GefechtsZusatzoption(
    this.titel,
    this.kampfmittel, {
    required this.parade,
    required this.verfuegbar,
    this.grund = '',
  });
  final String titel, grund;
  final GefechtsKampfmittelwahl kampfmittel;
  final bool parade, verfuegbar;
}

/// Vorhandene Optionen werden einschließlich fehlender Voraussetzungen erklärt.
List<GefechtsZusatzoption> gefechtsZusatzoptionen(HeroComputedSnapshot s) {
  final c = s.combatPreviewStats;
  final profile = gefechtsKampfmittelprofile(s);
  final neben = profile
      .where(
        (p) =>
            p.wahl.art != GefechtsKampfmittelArt.hauptwaffe &&
            p.wahl.art != GefechtsKampfmittelArt.waffenlos,
      )
      .firstOrNull;
  if (neben == null) return [];
  final haupt = s.hero.combatConfig.selectedWeaponOrNull;
  if (neben.wahl.art == GefechtsKampfmittelArt.schild) {
    final sf = isCombatSpecialAbilityActive(
      s.hero.combatConfig,
      'ksf_schildkampf_ii',
    );
    final ok =
        sf &&
        haupt != null &&
        gefechtsWaffeEinhaendig(haupt) &&
        c.beKampf <= 4 &&
        !c.offhandName.toLowerCase().contains('turmschild') &&
        neben.sperren.isEmpty;
    return [
      GefechtsZusatzoption(
        'Zusätzliche Schildparade',
        neben.wahl,
        parade: true,
        verfuegbar: ok,
        grund: ok ? '' : 'Schildkampf II, passende Hauptwaffe, BE ≤4 und kein Turmschild erforderlich.',
      ),
    ];
  }
  return [
    for (final pa in [false, true])
      (() {
        final option = c.twoWeaponCombat?.optionFor(
          pa
              ? TwoWeaponActionType.extraOffhandParry
              : TwoWeaponActionType.extraOffhandAttack,
        );
        final wert = pa ? neben.pa : neben.at;
        final ok =
            option?.isAvailable == true &&
            wert != null &&
            haupt != null &&
            gefechtsWaffeEinhaendig(haupt) &&
            neben.sperren.isEmpty;
        return GefechtsZusatzoption(
          pa ? 'Zusätzliche Nebenhandparade' : 'Zusätzliche Nebenhandattacke',
          neben.wahl,
          parade: pa,
          verfuegbar: ok,
          grund: ok
              ? ''
              : option?.availabilityReason ??
                    'Kein vollständiges Nebenhandprofil.',
        );
      })(),
  ];
}

/// Bindet Zusatzaktionen an dieselbe Ausrüstung wie die vorherige reguläre Aktion.
String gefechtsAusruestungspaar(HeroComputedSnapshot s) {
  final c = s.hero.combatConfig;
  final n = gefechtsKampfmittelprofile(s)
      .where(
        (p) =>
            p.wahl.art != GefechtsKampfmittelArt.hauptwaffe &&
            p.wahl.art != GefechtsKampfmittelArt.waffenlos,
      )
      .firstOrNull;
  final haupt = c.selectedWeaponOrNull;
  final hId = haupt?.id.isNotEmpty == true
      ? haupt!.id
      : stableContentHash(haupt?.toJson() ?? {});
  final nId = n?.wahl.id.isNotEmpty == true
      ? n!.wahl.id
      : stableContentHash(
          c.offhandAssignment.usesWeapon
              ? c.weaponSlots[c.offhandAssignment.weaponIndex].toJson()
              : c.offhandAssignment.usesEquipment
              ? c.offhandEquipment[c.offhandAssignment.equipmentIndex].toJson()
              : {},
        );
  return '$hId|${n?.wahl.art.name}:$nId';
}

/// Ergänzt Buchungsmetadaten, ohne Budget oder Zielwert noch einmal zu berechnen.
Gefechtspruefung gefechtsPruefungMitKampfmittel(
  Gefechtspruefung p,
  HeroComputedSnapshot s,
  GefechtAuftrag a,
  GefechtsKampfmittelwahl? w,
) => Gefechtspruefung(
  aktion: p.aktion,
  status: p.status,
  gruende: p.gruende,
  sperrgruende: p.sperrgruende,
  fehlendeAngaben: p.fehlendeAngaben,
  entscheidungen: p.entscheidungen,
  hinweise: p.hinweise,
  zielwert: p.zielwert,
  angriffe: p.angriffe,
  paraden: p.paraden,
  freie: p.freie,
  zusatz: p.zusatz,
  erschwernis: p.erschwernis,
  modifikatoren: p.modifikatoren,
  kampfmittel: w,
  ausruestungspaar: gefechtsAusruestungspaar(s),
  mitAnsage: a.manoever != null || a.zuschlag != 0,
);

/// Prüft Kontext mit echter Probenart und bezahlt nur die eine Zusatzmarke.
Gefechtspruefung pruefeGefechtsZusatzauftrag(
  Gefechtszustand s,
  HeroComputedSnapshot snap,
  RulesCatalog k,
  GefechtAuftrag a,
  GefechtsKampfmittelwahl? w, {
  bool eigenerAuftrag = false,
}) {
  final profil = gefechtsKampfmittelFuer(snap, w);
  final option = gefechtsZusatzoptionen(snap)
      .where(
        (o) =>
            o.parade == a.zusatzParade &&
            o.kampfmittel.art == w?.art &&
            o.kampfmittel.id == w?.id,
      )
      .firstOrNull;
  final pa = a.zusatzParade;
  final art = pa
      ? w?.art == GefechtsKampfmittelArt.schild
            ? Gefechtsaktion.schildparade
            : Gefechtsaktion.parade
      : Gefechtsaktion.angriff;
  final werte = gefechtswerteFuer(snap, katalog: k, kampfmittel: w);
  final basis = pruefeGefechtsaktion(
    s.copyWith(
      angriffeVerbraucht: 0,
      paradenVerbraucht: 0,
      umwandlung: Gefechtsumwandlung.normal,
    ),
    werte,
    art,
    zuschlag: a.zuschlag,
    eigenerAuftrag: eigenerAuftrag,
  );
  final vorher = pa ? s.regulaeresParadepaar : s.regulaeresAngriffspaar;
  final sperren = <String>[
    if (snap.wundEffekte.kampfunfaehig) 'Durch Wunden kampfunfähig.',
    ...basis.sperrgruende,
    if (profil == null) 'Kampfmittel nicht mehr geführt.',
    if (profil != null) ...profil.sperren,
    if (option?.verfuegbar != true)
      option?.grund ?? 'Diese Zusatzaktion hat kein bestätigtes Profil.',
    if (vorher == null || vorher != gefechtsAusruestungspaar(snap))
      'Zuerst passende reguläre Aktion mit derselben Ausrüstung ausführen.',
    if (s.zusatzVerbraucht > 0)
      'Zusatzaktionen sind nicht kumulativ; Zusatzmarke bereits verbraucht.',
    if (pa &&
        w?.art == GefechtsKampfmittelArt.schild &&
        s.regulaeresParademittel?.art != GefechtsKampfmittelArt.schild)
      'Zuerst regulär mit dem Schild parieren.',
    if (pa &&
        w?.art == GefechtsKampfmittelArt.schild &&
        s.umwandlung != Gefechtsumwandlung.normal)
      'Umwandlung schließt die zusätzliche SK-II-Parade aus.',
    if (pa &&
        w?.art == GefechtsKampfmittelArt.parierwaffe &&
        (s.regulaeresParademittel?.art != GefechtsKampfmittelArt.parierwaffe ||
            s.paradeMitAnsage ||
            a.zuschlag != 0 ||
            a.manoever != null ||
            s.umwandlung != Gefechtsumwandlung.normal))
      'Zwei Parierwaffenparaden benötigen gewöhnliche Paraden ohne Ansage oder Umwandlung.',
    if (s.umwandlung != Gefechtsumwandlung.normal && werte.umwandlungVerboten)
      'Aktuelle Waffe verbietet die angesagte Umwandlung.',
  ];
  return Gefechtspruefung(
    aktion: Gefechtsaktion.zusatzaktion,
    status: sperren.isNotEmpty ? Gefechtsfreigabe.gesperrt : basis.status,
    gruende: [
      ...sperren,
      if (basis.status != Gefechtsfreigabe.gesperrt) ...basis.gruende,
    ],
    sperrgruende: sperren,
    fehlendeAngaben: basis.fehlendeAngaben,
    entscheidungen: basis.entscheidungen,
    hinweise: basis.hinweise,
    zielwert: basis.zielwert,
    zusatz: 1,
    erschwernis: basis.erschwernis,
    modifikatoren: basis.modifikatoren,
    kampfmittel: w,
    probenart: art,
  );
}
