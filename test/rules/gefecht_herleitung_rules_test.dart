import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_held_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_herleitung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_kampfmittel_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/kampf_ini_herleitung_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import '../test_support/hero_fixtures.dart';
import '../test_support/real_catalog.dart';
import '../ui2/shell/karto_test_support.dart';

const _sitzungsWuerfe = <int>[0, 12, 25, 35];

Herleitung _vorschauAusweichen({
  int paBasis = 10,
  int iniBonus = 1,
  int be = 0,
}) => herleiteAusweichen(
  paBasis: paBasis,
  sfBonus: 0,
  akrobatik: 0,
  iniBonus: iniBonus,
  kampfInitiative: 25,
  beKampf: be,
);

/// Summe der Vorschau-Herleitung ohne INI-Bonus und ohne Untergrenze.
int _ungeklemmtOhneIni(Herleitung h) => summeDer(
  h.schritte.where(
    (s) =>
        s.art != HerleitungsArt.begrenzung &&
        s.bezeichnung != kAusweichenIniBonusSchritt,
  ),
);

/// Zielwert plus Erschwernis: der Wert vor allen Zuschlägen der Prüfung.
int _basisZiel(Gefechtspruefung p) => p.zielwert! + p.erschwernis;

HeroComputedSnapshot _bauen(
  Bestandsheld bestand,
  EchterKatalog katalog,
  HeroState zustand,
) => buildHeroComputedSnapshot(
  hero: ladeBestandsheld(bestand).hero,
  state: zustand,
  catalog: katalog.catalog,
  epicAdvantagesActive: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('herleiteGefechtsAusweichen', () {
    test('ersetzt den INI-Bonus der Vorschau durch den Sitzungsanteil', () {
      final vorschau = _vorschauAusweichen(iniBonus: 2);
      final h = herleiteGefechtsAusweichen(vorschau, iniBonus: 1);
      expect(
        h.schritte.where((s) => s.bezeichnung == kAusweichenIniBonusSchritt),
        isEmpty,
      );
      final sitzung = h.schritte.singleWhere(
        (s) => s.bezeichnung == kGefechtsIniBonusSchritt,
      );
      expect(sitzung.betrag, 1);
      expect(h.wert, vorschau.wert - 2 + 1);
      // Reihenfolge der übrigen Schritte bleibt erhalten.
      expect(
        h.schritte.map((s) => s.bezeichnung).toList(),
        vorschau.schritte
            .map(
              (s) => s.bezeichnung == kAusweichenIniBonusSchritt
                  ? kGefechtsIniBonusSchritt
                  : s.bezeichnung,
            )
            .toList(),
      );
    });

    test('Untergrenze wird auf die neue Summe angewendet', () {
      final vorschau = _vorschauAusweichen(paBasis: 4, iniBonus: 3, be: 6);
      // Vorschau: 4 + 3 − 6 = 1; ohne den Vorschau-INI-Bonus −2 → Klemme 0.
      expect(vorschau.wert, 1);
      final ohne = herleiteGefechtsAusweichen(vorschau, iniBonus: 0);
      expect(ohne.wert, 0);
      expect(
        ohne.schritte.where((s) => s.art == HerleitungsArt.begrenzung),
        hasLength(1),
      );
      // Der alte Ausgleich der Vorschau darf nicht mitwandern.
      final voll = herleiteGefechtsAusweichen(
        _vorschauAusweichen(paBasis: 4, iniBonus: 0, be: 6),
        iniBonus: 3,
      );
      expect(voll.wert, 1);
      expect(
        voll.schritte.where((s) => s.art == HerleitungsArt.begrenzung),
        isEmpty,
      );
      expect(summeDer(voll.schritte), voll.wert);
    });

    test('ohne Herleitung rechnet gefechtsAusweichenHerleitung mit BE', () {
      final h = gefechtsAusweichenHerleitung(
        herleitung: null,
        ausweichen: 9,
        be: 4,
        iniBonus: 2,
      );
      expect(h.wert, 9 + 2 - 4);
      expect(
        gefechtsAusweichenHerleitung(
          herleitung: null,
          ausweichen: 1,
          be: 6,
          iniBonus: 0,
        ).wert,
        0,
      );
    });

    test(
      'herleitungsZeile und ohneSchritte erzeugen Text aus den Schritten',
      () {
        final h = _vorschauAusweichen(paBasis: 8, iniBonus: 1, be: 2);
        final zeile = herleitungsZeile('Ausweichen', h);
        expect(zeile, startsWith('Ausweichen: ${h.wert} ('));
        expect(zeile, contains('PA-Basis 8'));
        expect(zeile, contains('BE Kampf −2'));
        final ohne = ohneSchritte(h, {kAusweichenIniBonusSchritt});
        expect(ohne.wert, h.wert - 1);
      },
    );
  });

  group('Bestandshelden: Gefechtswerte gleich Vorschau ± Sitzungsanteile', () {
    late EchterKatalog katalog;

    setUpAll(() async {
      katalog = await ladeEchtenRegelkatalog();
    });

    for (final bestand in Bestandsheld.values) {
      test('${bestand.datei}: Ausweichen, AT, PA, Schild-PA und Anteile', () {
        final bundle = ladeBestandsheld(bestand);
        for (final zustand in <HeroState>[
          bundle.state,
          bundle.state.copyWith(
            wpiZustand: const WundZustand(
              wundenProZone: <WundZone, int>{
                WundZone.rechterArm: 1,
                WundZone.linkerArm: 1,
              },
            ),
            activeSpellEffects: const ActiveSpellEffectsState(
              activeEffectIds: <String>[activeSpellEffectAxxeleratus],
            ),
          ),
        ]) {
          final snapshot = _bauen(bestand, katalog, zustand);
          final c = snapshot.combatPreviewStats;
          final w = gefechtswerteFuer(snapshot, katalog: katalog.catalog);

          // Ausweichen: die Herleitung der Vorschau, unverändert gespeichert.
          expect(w.ausweichenHerleitung!.wert, c.ausweichen);
          for (final wurf in _sitzungsWuerfe) {
            final s = beginneGefecht(wurf, dk: 'N');
            final bonus = gefechtsIniBonus(s, w);
            final erwartet =
                _ungeklemmtOhneIni(c.herleitungen!.ausweichen) + bonus;
            final erwartetGeklemmt = erwartet < 0 ? 0 : erwartet;
            final frei = pruefeGefechtsaktion(
              s,
              w,
              Gefechtsaktion.freiesAusweichen,
            );
            // Gegner- und Kontextzuschläge liegen in der Erschwernis; die BE
            // steckt vollständig im Grundwert.
            expect(
              frei.zielwert,
              erwartetGeklemmt - frei.erschwernis,
              reason: '${bestand.datei} freies Ausweichen INI $wurf',
            );
            expect(
              gefechtsAusweichen(s, w).wert,
              erwartetGeklemmt,
              reason: bestand.datei,
            );

            // PA trägt den Sitzungsanteil, AT keinen.
            final pa = pruefeGefechtsaktion(s, w, Gefechtsaktion.parade);
            expect(_basisZiel(pa), w.pa + bonus, reason: bestand.datei);
            final at = pruefeGefechtsaktion(s, w, Gefechtsaktion.angriff);
            expect(_basisZiel(at), w.at, reason: bestand.datei);
          }

          // Kampfmittelprofile gleichen der Vorschau.
          final profile = gefechtsKampfmittelprofile(snapshot);
          for (final p in profile) {
            if (p.at != null) {
              expect(p.atHerleitung!.wert, p.at, reason: bestand.datei);
            }
            if (p.pa != null) {
              expect(p.paHerleitung!.wert, p.pa, reason: bestand.datei);
            }
            expect(p.anteile, isNotEmpty, reason: bestand.datei);
          }
          for (final p in profile) {
            switch (p.wahl.art) {
              case GefechtsKampfmittelArt.hauptwaffe:
                expect(p.at, c.at);
                expect(p.pa, c.isRangedWeapon ? null : c.pa - c.offhandPaBonus);
                if (p.pa != null) {
                  expect(
                    p.anteile,
                    contains(
                      startsWith(
                        'Hauptwaffen-PA ohne Parierwaffenanteil: ${p.pa}',
                      ),
                    ),
                  );
                }
              case GefechtsKampfmittelArt.nebenwaffe:
                expect(p.at, c.offhandPreview!.at);
                expect(
                  p.pa,
                  c.offhandPreview!.isRangedWeapon
                      ? null
                      : c.offhandPreview!.pa,
                );
              case GefechtsKampfmittelArt.schild:
                expect(p.pa, c.shieldPa);
              case GefechtsKampfmittelArt.parierwaffe:
                if (p.pa != null) expect(p.pa, c.pa);
              case GefechtsKampfmittelArt.waffenlos:
                final wl = snapshot.waffenlos.firstWhere(
                  (e) => e.talent.kampfmittelId == p.wahl.id,
                );
                expect(p.at, wl.vorschau.at);
                expect(p.pa, wl.vorschau.pa);
            }
          }
        }
      });
    }
  });

  group('Kombination aus Waffe und Nebenhand', () {
    const main = MainWeaponSlot(
      id: 'main',
      name: 'Schwert',
      distanceClass: 'N',
    );
    const pw = OffhandEquipmentEntry(
      id: 'pw',
      name: 'Linkhanddolch',
      atMod: -2,
      paMod: 2,
    );

    HeroComputedSnapshot snapshot({
      bool schild = false,
      List<ArmorPiece> ruestung = const [],
    }) => buildHeroComputedSnapshot(
      hero: testHero().copyWith(
        combatConfig: CombatConfig(
          weapons: const [main],
          armor: ArmorConfig(pieces: ruestung),
          offhandEquipment: [
            schild ? pw.copyWith(type: OffhandEquipmentType.shield) : pw,
          ],
          offhandAssignment: const OffhandAssignment(equipmentIndex: 0),
          specialRules: const CombatSpecialRules(
            linkhandActive: true,
            parierwaffenII: true,
          ),
        ),
      ),
      state: const HeroState.empty(),
      catalog: testCatalog,
      epicAdvantagesActive: false,
    );

    test('Parierwaffe trennt Hauptwaffen- und Parierwaffenanteil im Text', () {
      final profile = gefechtsKampfmittelprofile(snapshot());
      final haupt = profile.firstWhere(
        (p) => p.wahl.art == GefechtsKampfmittelArt.hauptwaffe,
      );
      final parier = profile.firstWhere(
        (p) => p.wahl.art == GefechtsKampfmittelArt.parierwaffe,
      );
      expect(parier.pa, haupt.pa! + 4);
      expect(
        parier.anteile,
        contains(startsWith('Parierwaffenanteil: 4 (Nebenhand PA +2')),
      );
      expect(
        haupt.anteile,
        contains(
          startsWith('Hauptwaffen-PA ohne Parierwaffenanteil: ${haupt.pa}'),
        ),
      );
      // Die Hauptwaffe zeigt den Parierwaffenanteil nirgends als Schritt.
      expect(
        haupt.paHerleitung!.schritte.map((s) => s.bezeichnung),
        isNot(contains('Nebenhand PA')),
      );
    });

    test('Schild: Profil-PA gleich Schild-Herleitung der Vorschau', () {
      final s = snapshot(schild: true);
      final schild = gefechtsKampfmittelprofile(s)
          .firstWhere((p) => p.wahl.art == GefechtsKampfmittelArt.schild);
      expect(schild.pa, s.combatPreviewStats.shieldPa);
      expect(schild.paHerleitung!.wert, schild.pa);
      expect(schild.anteile.single, startsWith('Schild-PA: ${schild.pa} ('));
    });

    test('Nutzerentscheidung: INI-Bonus gilt auch für die Schild-Parade', () {
      final w = gefechtswerteFuer(snapshot(schild: true), katalog: testCatalog);
      const s = Gefechtszustand(iniWurf: 40, dk: 'N');
      final bonus = gefechtsIniBonus(s, w);
      expect(bonus, greaterThan(0));
      final schild = pruefeGefechtsaktion(s, w, Gefechtsaktion.schildparade);
      expect(_basisZiel(schild), w.schildPa! + bonus);
      final parade = pruefeGefechtsaktion(s, w, Gefechtsaktion.parade);
      expect(_basisZiel(parade), w.pa + bonus);
    });

    test(
      'BE wirkt einmal im Grundwert und nicht zusätzlich als Erschwernis',
      () {
        final ohne = snapshot();
        final mit = snapshot(
          ruestung: const [
            ArmorPiece(name: 'Kettenhemd', isActive: true, rs: 4, be: 3),
          ],
        );
        final wOhne = gefechtswerteFuer(ohne, katalog: testCatalog);
        final wMit = gefechtswerteFuer(mit, katalog: testCatalog);
        expect(mit.combatPreviewStats.beKampf, greaterThan(0));
        final be = mit.combatPreviewStats.beKampf;
        const s = Gefechtszustand(iniWurf: 6, dk: 'N');
        final pOhne = pruefeGefechtsaktion(
          s,
          wOhne,
          Gefechtsaktion.freiesAusweichen,
        );
        final pMit = pruefeGefechtsaktion(
          s,
          wMit,
          Gefechtsaktion.freiesAusweichen,
        );
        expect(pMit.erschwernis, pOhne.erschwernis);
        expect(pMit.zielwert, pOhne.zielwert! - be);
      },
    );

    test(
      'schwere Rüstung klemmt Ausweichen auf 0 vor den Gegnerzuschlägen',
      () {
        final schwer = snapshot(
          ruestung: const [
            ArmorPiece(name: 'Plattenrüstung', isActive: true, rs: 6, be: 20),
          ],
        );
        final w = gefechtswerteFuer(schwer, katalog: testCatalog);
        const s = Gefechtszustand(iniWurf: 6, dk: 'N');
        final p = pruefeGefechtsaktion(s, w, Gefechtsaktion.freiesAusweichen);
        expect(gefechtsAusweichen(s, w).wert, 0);
        expect(p.zielwert, 0 - p.erschwernis);
      },
    );
  });
}
