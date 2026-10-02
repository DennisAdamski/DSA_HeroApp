import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_kampfmittel_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_auftrag_rules.dart';

import '../ui2/shell/karto_test_support.dart';

const _main = MainWeaponSlot(id: 'main', name: 'Schwert', distanceClass: 'N');
const _pw = OffhandEquipmentEntry(
  id: 'pw',
  name: 'Linkhanddolch',
  atMod: -2,
  paMod: 2,
);

HeroComputedSnapshot _snapshot({bool linkhand = true, bool schild = false}) =>
    buildHeroComputedSnapshot(
      hero: testHero().copyWith(
        combatConfig: CombatConfig(
          weapons: const [_main],
          offhandEquipment: [
            schild ? _pw.copyWith(type: OffhandEquipmentType.shield) : _pw,
          ],
          offhandAssignment: const OffhandAssignment(equipmentIndex: 0),
          specialRules: CombatSpecialRules(
            linkhandActive: linkhand,
            parierwaffenII: linkhand,
          ),
        ),
      ),
      state: const HeroState.empty(),
      catalog: testCatalog,
      epicAdvantagesActive: false,
    );

void main() {
  test('Parierwaffe verändert eigene Parade, nicht Hauptwaffenattacke', () {
    final s = _snapshot();
    final frei = buildHeroComputedSnapshot(
      hero: s.hero.copyWith(
        combatConfig: s.hero.combatConfig.copyWith(
          offhandAssignment: const OffhandAssignment(),
        ),
      ),
      state: s.state,
      catalog: testCatalog,
      epicAdvantagesActive: false,
    );
    expect(s.combatPreviewStats.at, frei.combatPreviewStats.at);
    final profile = gefechtsKampfmittelprofile(s);
    expect(
      profile
          .firstWhere((p) => p.wahl.art == GefechtsKampfmittelArt.hauptwaffe)
          .pa,
      frei.combatPreviewStats.pa,
    );
    expect(
      profile
          .firstWhere((p) => p.wahl.art == GefechtsKampfmittelArt.parierwaffe)
          .pa,
      frei.combatPreviewStats.pa + 4,
    );
  });
  test('Standardabwehr und fehlende Linkhand', () {
    expect(
      gefechtsStandardKampfmittel(_snapshot(), Gefechtsaktion.parade)!.art,
      GefechtsKampfmittelArt.parierwaffe,
    );
    expect(
      gefechtsStandardKampfmittel(
        _snapshot(linkhand: false),
        Gefechtsaktion.parade,
      )!.art,
      GefechtsKampfmittelArt.hauptwaffe,
    );
    expect(
      gefechtsStandardKampfmittel(
        _snapshot(schild: true),
        Gefechtsaktion.parade,
      )!.art,
      GefechtsKampfmittelArt.schild,
    );
  });
  test(
    'Gewählte Hauptwaffe und Parierwaffe: Finte und hoher INI-Bonus einmal',
    () {
      final snap = _snapshot();
      const s = Gefechtszustand(iniWurf: 40, dk: 'N', fixierterIniBonus: 2);
      for (final art in [
        GefechtsKampfmittelArt.hauptwaffe,
        GefechtsKampfmittelArt.parierwaffe,
      ]) {
        final profil = gefechtsKampfmittelprofile(snap)
            .firstWhere((p) => p.wahl.art == art);
        final p = pruefeGefechtAuftrag(
          s,
          snap,
          testCatalog,
          GefechtAuftrag(
            aktion: Gefechtsaktion.parade,
            titel: 'Parieren',
            zuschlag: 0,
            dk: 'N',
            dauer: 1,
            kosten: 1,
            kampfmittel: profil.wahl,
            kontext: const Gefechtskontext(
              angriffsart: Gefechtsangriffsart.nahkampf,
              finte: 3,
              paradeVerboten: false,
              weitereRegelnGeprueft: true,
            ),
          ),
        );
        expect(p.zielwert, profil.pa! + 2 - 3);
      }
    },
  );
}
