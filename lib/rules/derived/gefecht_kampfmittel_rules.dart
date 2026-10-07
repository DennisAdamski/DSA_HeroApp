import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import 'gefecht_hand_rules.dart';
import 'combat_special_ability_state.dart';
import 'waffenlos_rules.dart';

/// Automatisch berechenbares Kampfmittel; Gründe erklären bekannte Sperren.
class GefechtsKampfmittelprofil {
  /// Grundwerte enthalten Heldenmali, jedoch keinen Gefechts-INI-Bonus.
  const GefechtsKampfmittelprofil({
    required this.wahl,
    required this.name,
    this.waffe,
    this.at,
    this.pa,
    this.sperren = const [],
    this.anteile = const [],
    this.nebenWaffe = false,
  });
  final GefechtsKampfmittelwahl wahl;
  final String name;
  final MainWeaponSlot? waffe;
  final int? at, pa;
  final List<String> sperren, anteile;

  /// Waffenloses Mittel neben einer Waffe: nur Manöver der Kampftechnik.
  final bool nebenWaffe;
}

/// Trennt Hauptwaffenparade und Kombination, ohne persistierte Werte einzuführen.
List<GefechtsKampfmittelprofil> gefechtsKampfmittelprofile(
  HeroComputedSnapshot s,
) {
  final config = s.hero.combatConfig;
  final c = s.combatPreviewStats;
  final haupt = gefuehrteHauptwaffe(config);
  final neben = config.offhandAssignment;
  final konflikte = <String>[];
  if (haupt != null && !gefechtsWaffeEinhaendig(haupt) && !neben.isNone) {
    konflikte.add(
      'Zweihändige Hauptwaffe und belegte Nebenhand widersprechen sich.',
    );
  }
  return [
    if (haupt != null)
      GefechtsKampfmittelprofil(
        wahl: GefechtsKampfmittelwahl(
          GefechtsKampfmittelArt.hauptwaffe,
          haupt.id,
        ),
        name: haupt.name,
        waffe: haupt,
        at: c.at,
        pa: c.isRangedWeapon ? null : c.pa - c.offhandPaBonus,
        sperren: konflikte,
        anteile: [
          'Hauptwaffen-PA ohne Parierwaffenanteil: ${c.pa - c.offhandPaBonus}',
          ...raufenwaffenHinweise(haupt),
        ],
      ),
    if (neben.usesWeapon)
      GefechtsKampfmittelprofil(
        wahl: GefechtsKampfmittelwahl(
          GefechtsKampfmittelArt.nebenwaffe,
          config.weaponSlots[neben.weaponIndex].id,
        ),
        name: gefechtsNebenhandname(config),
        waffe: config.weaponSlots[neben.weaponIndex],
        at: c.offhandPreview?.at,
        pa: c.offhandPreview?.isRangedWeapon == true
            ? null
            : c.offhandPreview?.pa,
        sperren: [
          ...konflikte,
          if (!gefechtsWaffeEinhaendig(config.weaponSlots[neben.weaponIndex]))
            'Nebenhandwaffe nicht einhändig.',
        ],
        anteile: [
          'Falsche Hand: AT ${c.offhandPreview?.falseHandAtMod}, PA ${c.offhandPreview?.falseHandPaMod}; im Grundwert enthalten.',
          'Nebenhandwunden und BE im Grundwert enthalten.',
          ...raufenwaffenHinweise(config.weaponSlots[neben.weaponIndex]),
        ],
      ),
    if (neben.usesEquipment)
      GefechtsKampfmittelprofil(
        wahl: GefechtsKampfmittelwahl(
          c.offhandIsShield
              ? GefechtsKampfmittelArt.schild
              : GefechtsKampfmittelArt.parierwaffe,
          config.offhandEquipment[neben.equipmentIndex].id,
        ),
        name: gefechtsNebenhandname(config),
        waffe: haupt,
        pa: c.offhandIsShield
            ? c.shieldPa
            : haupt == null || c.offhandRequiresLinkhand
            ? null
            : c.pa,
        sperren: [
          ...konflikte,
          if (c.offhandRequiresLinkhand) 'Parierwaffen erfordern Linkhand.',
          if (!c.offhandIsShield && haupt == null)
            'Parierwaffe benötigt eine Hauptwaffe.',
        ],
        anteile: c.offhandIsShield
            ? [
                'PA-Basis ${c.paBase}, Schild-WM/SF ${c.shieldPaBonus}; BE und Armwunden im Grundwert enthalten.',
              ]
            : [
                'Hauptwaffen-PA ${c.pa - c.offhandPaBonus}, Parierwaffen-WM/SF ${c.offhandPaBonus}.',
              ],
      ),
    for (final w in s.waffenlos)
      GefechtsKampfmittelprofil(
        nebenWaffe: w.nebenWaffe,
        wahl: GefechtsKampfmittelwahl(
          GefechtsKampfmittelArt.waffenlos,
          w.talent.kampfmittelId,
        ),
        name: w.slot.name,
        waffe: w.slot,
        at: w.vorschau.at,
        pa: w.vorschau.pa,
        anteile: waffenloseHinweise(w),
      ),
  ];
}

/// Waffenlose Kampfwerte zu [w], sonst `null`.
WaffenloseKampfwerte? gefechtsWaffenlosFuer(
  HeroComputedSnapshot s,
  GefechtsKampfmittelwahl? w,
) => w?.art != GefechtsKampfmittelArt.waffenlos
    ? null
    : s.waffenlos.where((e) => e.talent.kampfmittelId == w!.id).firstOrNull;

/// Schadenswürfel genau des Mittels [w] aus seiner eigenen Vorschau.
DiceSpec? gefechtsSchadenswuerfel(
  HeroComputedSnapshot s,
  GefechtsKampfmittelwahl w,
) => switch (w.art) {
  GefechtsKampfmittelArt.nebenwaffe =>
    s.combatPreviewStats.offhandPreview?.damageDiceSpec,
  GefechtsKampfmittelArt.waffenlos => gefechtsWaffenlosFuer(
    s,
    w,
  )?.vorschau.damageDiceSpec,
  _ => s.combatPreviewStats.damageDiceSpec,
};

/// Name, TP-Ausdruck und Würfel des Standardangriffsmittels für die Anzeige.
///
/// Ohne Waffe in der Hand ist das Raufen; ohne jedes Angriffsmittel `null`.
({String name, String tp, DiceSpec wuerfel})? gefechtsAngriffsanzeige(
  HeroComputedSnapshot s,
) {
  if (gefuehrteHauptwaffe(s.hero.combatConfig) case final haupt?) {
    final c = s.combatPreviewStats;
    return (name: haupt.name, tp: c.tpExpression, wuerfel: c.damageDiceSpec);
  }
  final raufen = s.waffenlos
      .where((w) => w.talent == WaffenlosesTalent.raufen)
      .firstOrNull;
  if (raufen == null) return null;
  return (
    name: raufen.slot.name,
    tp: '${raufen.vorschau.tpExpression} (A)',
    wuerfel: raufen.vorschau.damageDiceSpec,
  );
}

/// Löst ausschließlich das aktuell tatsächlich geführte bestätigte Mittel auf.
GefechtsKampfmittelprofil? gefechtsKampfmittelFuer(
  HeroComputedSnapshot s,
  GefechtsKampfmittelwahl? w,
) => w == null
    ? null
    : gefechtsKampfmittelprofile(s)
          .where((p) => p.wahl.art == w.art && p.wahl.id == w.id)
          .firstOrNull;

/// Schild, zulässige Parierwaffe, dann Hauptwaffe; Angriffe beginnen rechts.
/// Waffenlos kampfbereit folgt Raufen vor Ringen; neben einer Waffe nie.
GefechtsKampfmittelwahl? gefechtsStandardKampfmittel(
  HeroComputedSnapshot s,
  Gefechtsaktion a,
) {
  final profile = gefechtsKampfmittelprofile(s);
  final reihenfolge = a == Gefechtsaktion.schildparade
      ? [GefechtsKampfmittelArt.schild]
      : a == Gefechtsaktion.parade
      ? [
          GefechtsKampfmittelArt.schild,
          GefechtsKampfmittelArt.parierwaffe,
          GefechtsKampfmittelArt.hauptwaffe,
          GefechtsKampfmittelArt.waffenlos,
        ]
      : [GefechtsKampfmittelArt.hauptwaffe, GefechtsKampfmittelArt.waffenlos];
  for (final art in reihenfolge) {
    final p = profile
        .where(
          (p) =>
              p.wahl.art == art &&
              p.sperren.isEmpty &&
              !p.nebenWaffe &&
              (a == Gefechtsaktion.angriff ? p.at != null : p.pa != null),
        )
        .firstOrNull;
    if (p != null) return p.wahl;
  }
  return null;
}

/// Budget und Pflichtkontext folgen dem gewählten Mittel, nicht dem Buttontitel.
Gefechtsaktion gefechtsAktionMitKampfmittel(
  Gefechtsaktion a,
  GefechtsKampfmittelwahl? w,
) =>
    w != null &&
        (a == Gefechtsaktion.parade || a == Gefechtsaktion.schildparade)
    ? w.art == GefechtsKampfmittelArt.schild
          ? Gefechtsaktion.schildparade
          : Gefechtsaktion.parade
    : a;

/// WdS 71: Schildführung beschränkt auch Manöver mit der Hauptwaffe.
({int zuschlag, List<String> sperren}) gefechtsSchildmanoever(
  HeroComputedSnapshot s,
  String manoever,
) {
  final c = s.hero.combatConfig;
  if (!s.combatPreviewStats.offhandIsShield) return (zuschlag: 0, sperren: []);
  final schild = c.offhandEquipment[c.offhandAssignment.equipmentIndex];
  final name = manoever.toLowerCase();
  final klein = schild.shieldSize == ShieldSize.small;
  final gesperrt = [
    'doppelangriff',
    'entwaffnen',
    'klingensturm',
    'tod von links',
    'umreißen',
    'umreissen',
    'waffe zerbrechen',
  ].any(name.contains);
  final sk2 = isCombatSpecialAbilityActive(c, 'ksf_schildkampf_ii');
  return (
    zuschlag: name.contains('ausfall') || (name.contains('finte') && !klein)
        ? 2
        : 0,
    sperren: [
      if (gesperrt) 'Schildführung verbietet dieses Manöver (WdS 71).',
      if (name.contains('meisterparade') && !sk2)
        'Meisterparade mit Schild benötigt Schildkampf II.',
      if (name.contains('windmühle') && !klein)
        'Windmühle nur mit kleinem Schild.',
    ],
  );
}
