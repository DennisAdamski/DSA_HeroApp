import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import 'gefecht_hand_rules.dart';
import 'gefecht_herleitung_rules.dart';
import 'herleitung.dart';
import 'kampf_herleitung_rules.dart';
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
    this.atHerleitung,
    this.paHerleitung,
  });
  final GefechtsKampfmittelwahl wahl;
  final String name;
  final MainWeaponSlot? waffe;
  final int? at, pa;

  /// Herleitungen von [at] und [pa] aus der Kampfvorschau, ohne Sitzungs-INI;
  /// `at == atHerleitung.wert`, `pa == paHerleitung.wert`.
  final Herleitung? atHerleitung, paHerleitung;

  /// [anteile] erklärt die Grundwerte aus den Schritten der Herleitungen.
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
  final h = c.herleitungen;
  // Hauptwaffe: AT/FK und PA aus der Vorschau; die PA ohne den Anteil einer
  // Parierwaffe ist die der Hauptwaffe allein.
  final hauptAt =
      h?.at ?? herleitungAusWert(c.isRangedWeapon ? 'FK' : 'AT', c.at);
  final hauptPaVoll = c.isRangedWeapon
      ? null
      : h?.pa ?? herleitungAusWert('PA', c.pa);
  final hauptPa = hauptPaVoll == null
      ? null
      : h?.pa == null
      ? herleitungAusWert('PA', c.pa - c.offhandPaBonus)
      : ohneSchritte(hauptPaVoll, {
          kNebenhandPaSchritt,
          kParierwaffenSfSchritt,
        });
  final nebenVorschau = c.offhandPreview;
  final nebenH = nebenVorschau?.herleitungen;
  final nebenAt = nebenVorschau == null
      ? null
      : nebenH?.at ??
            herleitungAusWert(
              nebenVorschau.isRangedWeapon ? 'FK' : 'AT',
              nebenVorschau.at ?? 0,
            );
  final nebenPa = nebenVorschau == null || nebenVorschau.isRangedWeapon
      ? null
      : nebenH?.pa ?? herleitungAusWert('PA', nebenVorschau.pa ?? 0);
  final schildPa = c.offhandIsShield
      ? h?.schildPa ?? herleitungAusWert('Schild-PA', c.shieldPa)
      : null;
  return [
    if (haupt != null)
      GefechtsKampfmittelprofil(
        wahl: GefechtsKampfmittelwahl(
          GefechtsKampfmittelArt.hauptwaffe,
          haupt.id,
        ),
        name: haupt.name,
        waffe: haupt,
        at: hauptAt.wert,
        pa: hauptPa?.wert,
        atHerleitung: hauptAt,
        paHerleitung: hauptPa,
        sperren: konflikte,
        anteile: [
          herleitungsZeile(c.isRangedWeapon ? 'FK' : 'AT', hauptAt),
          if (hauptPa != null)
            herleitungsZeile('Hauptwaffen-PA ohne Parierwaffenanteil', hauptPa),
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
        at: nebenAt?.wert,
        pa: nebenPa?.wert,
        atHerleitung: nebenAt,
        paHerleitung: nebenPa,
        sperren: [
          ...konflikte,
          if (!gefechtsWaffeEinhaendig(config.weaponSlots[neben.weaponIndex]))
            'Nebenhandwaffe nicht einhändig.',
        ],
        anteile: [
          if (nebenAt != null)
            herleitungsZeile(
              nebenVorschau!.isRangedWeapon ? 'FK Nebenhand' : 'AT Nebenhand',
              nebenAt,
            ),
          if (nebenPa != null) herleitungsZeile('PA Nebenhand', nebenPa),
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
            ? schildPa?.wert
            : haupt == null || c.offhandRequiresLinkhand
            ? null
            : hauptPaVoll?.wert,
        paHerleitung: c.offhandIsShield
            ? schildPa
            : haupt == null || c.offhandRequiresLinkhand
            ? null
            : hauptPaVoll,
        sperren: [
          ...konflikte,
          if (c.offhandRequiresLinkhand) 'Parierwaffen erfordern Linkhand.',
          if (!c.offhandIsShield && haupt == null)
            'Parierwaffe benötigt eine Hauptwaffe.',
        ],
        anteile: c.offhandIsShield
            ? [if (schildPa != null) herleitungsZeile('Schild-PA', schildPa)]
            : [
                if (hauptPa != null)
                  herleitungsZeile(
                    'Hauptwaffen-PA ohne Parierwaffenanteil',
                    hauptPa,
                  ),
                if (hauptPaVoll != null)
                  herleitungsZeile(
                    'Parierwaffenanteil',
                    Herleitung(
                      bezeichnung: 'Parierwaffenanteil',
                      schritte: [
                        for (final s in hauptPaVoll.schritte)
                          if (s.bezeichnung == kNebenhandPaSchritt ||
                              s.bezeichnung == kParierwaffenSfSchritt)
                            s,
                      ],
                    ),
                  ),
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
        atHerleitung:
            w.vorschau.herleitungen?.at ??
            herleitungAusWert('AT', w.vorschau.at),
        paHerleitung:
            w.vorschau.herleitungen?.pa ??
            herleitungAusWert('PA', w.vorschau.pa),
        anteile: [
          if (w.vorschau.herleitungen case final wh?) ...[
            herleitungsZeile('AT', wh.at),
            if (wh.pa case final pa?) herleitungsZeile('PA', pa),
          ],
          ...waffenloseHinweise(w),
        ],
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
