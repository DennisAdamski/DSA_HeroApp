import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_laden_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import '../ui2/shell/karto_test_support.dart';
import 'gefecht_laden_rules_test.dart' as fixture;

/// Echte Rüstung, SF und aktive Effekte erreichen beide zentralen Vorschauen.
HeroComputedSnapshot reviewLadeSnapshot({
  int be = 4,
  int training = 0,
  bool nebenhand = false,
  bool owned = true,
  bool axx = false,
  String art = 'Armbrust',
}) {
  final basis = fixture.ladeSnapshot(nebenhand: nebenhand);
  final waffen = basis.hero.combatConfig.weaponSlots
      .map((w) => w.isRanged ? w.copyWith(weaponType: art) : w)
      .toList();
  return buildHeroComputedSnapshot(
    hero: basis.hero.copyWith(
      combatConfig: basis.hero.combatConfig.copyWith(
        weapons: waffen,
        armor: ArmorConfig(
          globalArmorTrainingLevel: training,
          pieces: [
            ArmorPiece(
              id: 'ruestung',
              name: 'Rüstung',
              isActive: true,
              be: be,
              rg1Active: training == 1,
            ),
          ],
        ),
        specialRules: CombatSpecialRules(
          activeManeuvers: owned
              ? ['man_schnellladen_armbrust', 'man_schnellladen_bogen']
              : [],
        ),
      ),
    ),
    state: HeroState(
      currentLep: 30,
      currentAsp: 30,
      currentKap: 0,
      currentAu: 30,
      activeSpellEffects: ActiveSpellEffectsState(
        activeEffectIds: axx ? [activeSpellEffectAxxeleratus] : [],
      ),
    ),
    catalog: testCatalog,
    epicAdvantagesActive: false,
  );
}

void main() {
  test('I2 Zielzahlung mit PA-Marke erhält den aktuellen Schusskontext', () {
    final snap = fixture.ladeSnapshot();
    var s = beginneGefechtsZielen(
      const Gefechtszustand(iniWurf: 6),
      snap,
      testCatalog,
      fixture.zielauftrag,
    );
    s = bezahleGefechtsVorbereitung(s, snap);
    expect(s.paradenVerbraucht, 1);
    expect(s.kontext.situationsZuschlag, 0);
    s = bezahleGefechtsVorbereitung(naechsteGefechtsrunde(s), snap);
    s = naechsteGefechtsrunde(s).copyWith(
      dk: 'N',
      kontext: s.kontext.copyWith(situationsZuschlag: 2, getuemmel: true),
    );
    final p = pruefeGefechtsZielschuss(s, snap, testCatalog);
    expect(p.ausfuehrbar, true);
    expect(
      p.erschwernis,
      8,
      reason: 'Ansage5, Entfernung-2, neue Situation2, Getümmel3.',
    );
  });
  for (final art in ['Armbrust', 'Bogen']) {
    for (final nebenhand in [false, true]) {
      test('I1 $art Hand=$nebenhand BE4 aktiv und BE5 gesperrt', () {
        for (final be in [4, 5]) {
          final snap = reviewLadeSnapshot(
            be: be,
            nebenhand: nebenhand,
            art: art,
          );
          final c = snap.combatPreviewStats;
          expect(c.beKampf, be);
          expect(
            nebenhand ? c.offhandPreview!.reloadTime : c.reloadTime,
            be == 4 ? 3 : 4,
          );
          if (!nebenhand) {
            expect(
              art == 'Armbrust'
                  ? c.schnellladenArmbrustActive
                  : c.schnellladenBogenActive,
              be <= 4,
            );
          }
        }
      });
      test(
        'I1 $art Hand=$nebenhand RG und Axx-Kombination benutzen gültige BE',
        () {
          for (final training in [1, 2, 3]) {
            final snap = reviewLadeSnapshot(
              be: training == 3 ? 6 : 5,
              training: training,
              nebenhand: nebenhand,
              art: art,
            );
            expect(snap.combatPreviewStats.beKampf, 4);
            expect(
              nebenhand
                  ? snap.combatPreviewStats.offhandPreview!.reloadTime
                  : snap.combatPreviewStats.reloadTime,
              3,
            );
          }
          for (final owned in [false, true]) {
            for (final be in [4, 5]) {
              final snap = reviewLadeSnapshot(
                be: be,
                nebenhand: nebenhand,
                art: art,
                owned: owned,
                axx: true,
              );
              final erwartet = be == 5
                  ? 4
                  : owned
                  ? 2
                  : 3;
              expect(
                nebenhand
                    ? snap.combatPreviewStats.offhandPreview!.reloadTime
                    : snap.combatPreviewStats.reloadTime,
                erwartet,
              );
            }
          }
        },
      );
    }
  }
  test(
    'I1 laufendes bezahltes Laden erreicht BE-Grenze ohne Zahlungsverlust',
    () {
      final be4 = reviewLadeSnapshot();
      final be5 = reviewLadeSnapshot(be: 5);
      var s = beginneGefechtsLaden(
        const Gefechtszustand(iniWurf: 6),
        be4,
        fixture.mittel,
        anfangGeladen: false,
      );
      s = bezahleGefechtsVorbereitung(s, be4);
      final p = pruefeGefechtsVorbereitung(s, be5);
      expect(p.bezahlt, 2);
      expect(p.dauer, 4);
      expect(p.rest, 2);
      s = bezahleGefechtsVorbereitung(naechsteGefechtsrunde(s), be5);
      expect(s.handlung!.vorbereitung!.bezahlteAktionen, 3);
      expect(
        gefechtsLadezustand(s, be5.hero.combatConfig.selectedWeapon),
        false,
      );
      // RG stellt wirksame BE4 her; die bezahlten3Aktionen reichen ohne neue Marke.
      final rg = reviewLadeSnapshot(be: 5, training: 2);
      final fertig = bezahleGefechtsVorbereitung(s, rg);
      expect(fertig.handlung, isNull);
      expect(fertig.angriffeVerbraucht, s.angriffeVerbraucht);
      expect(fertig.paradenVerbraucht, s.paradenVerbraucht);
      expect(
        gefechtsLadezustand(fertig, rg.hero.combatConfig.selectedWeapon),
        true,
      );
    },
  );
}
