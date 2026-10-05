import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_magie_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_talent_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/talent_probe_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import '../ui2/shell/karto_test_support.dart';

const klettern = TalentDef(
  id: 'tal_klettern',
  name: 'Klettern',
  group: 'Körperliche Talente',
  steigerung: 'D',
  attributes: ['Mut', 'Gewandtheit', 'Körperkraft'],
  be: 'x2',
);
const selbstbeherrschung = TalentDef(
  id: 'tal_selbstbeherrschung',
  name: 'Selbstbeherrschung',
  group: 'Körperliche Talente',
  steigerung: 'D',
  attributes: ['Mut', 'Konstitution', 'Körperkraft'],
  be: '-',
);

HeroComputedSnapshot _snapshot({bool ruestung = true, bool stiefel = true}) {
  return buildHeroComputedSnapshot(
    hero: testHero().copyWith(
      talents: const {
        'tal_klettern': HeroTalentEntry(
          talentValue: 8,
          modifier: 1,
          specializations: 'Fels',
        ),
        'tal_selbstbeherrschung': HeroTalentEntry(talentValue: 6),
      },
      combatConfig: CombatConfig(
        armor: ArmorConfig(
          pieces: [
            if (ruestung)
              const ArmorPiece(
                name: 'Kettenhemd',
                isActive: true,
                rs: 3,
                be: 2,
              ),
          ],
        ),
      ),
      inventoryEntries: [
        if (stiefel)
          const HeroInventoryEntry(
            gegenstand: 'Kletterschuhe',
            itemType: InventoryItemType.ausruestung,
            istAusgeruestet: true,
            modifiers: [
              InventoryItemModifier(
                kind: InventoryModifierKind.talent,
                targetId: 'tal_klettern',
                wert: 2,
              ),
            ],
          ),
      ],
    ),
    state: const HeroState.empty(),
    catalog: const RulesCatalog(
      version: 'test',
      source: 'test',
      talents: [klettern, selbstbeherrschung],
      spells: [],
      weapons: [],
    ),
    epicAdvantagesActive: false,
  );
}

ProbeResult _wurf(ResolvedProbeRequest r, List<int> wuerfel) => evaluateProbe(
  r,
  ProbeRollInput(
    mode: ProbeRollMode.manual,
    diceValues: wuerfel,
    situationalModifier: 0,
    specializationApplied: false,
  ),
);

void main() {
  test('TaW* rechnet Behinderung, Modifikator und Inventarbonus ein', () {
    final s = _snapshot();
    final be = s.combatPreviewStats.beKampf;
    expect(be, greaterThan(0));
    final wert = talentProbenwertFuer(
      snapshot: s,
      talent: klettern,
      epicAdvantagesActive: false,
    )!;
    // BE×2 als Abzug, TaW 8 + Mod 1 + Stiefel 2.
    expect(wert.ebe, -2 * be);
    expect(wert.taw, 8 + 1 + 2 - 2 * be);
    expect(wert.spezialisierung, isTrue);
    expect(wert.ziele.map((z) => z.label), ['MU', 'GE', 'KK']);
    final ohne = talentProbenwertFuer(
      snapshot: _snapshot(ruestung: false, stiefel: false),
      talent: klettern,
      epicAdvantagesActive: false,
    )!;
    expect(ohne.taw, 9);
    // Die vorübergehende Talentansicht kann die BE überschreiben.
    expect(
      talentProbenwertFuer(
        snapshot: s,
        talent: klettern,
        epicAdvantagesActive: false,
        talentBeOverride: 0,
      )!.taw,
      11,
    );
  });

  test('Gefecht und Suche verwenden dieselbe Talentprobe', () {
    final s = _snapshot();
    final gefecht = gefechtsTalentprobe(s, klettern)!;
    final suche = talentprobeFuer(
      snapshot: s,
      talent: klettern,
      epicAdvantagesActive: false,
    )!;
    expect(gefecht.basePool, suche.basePool);
    expect(gefecht.specializationBonus, 2);
    expect(gefecht.type, ProbeType.talent);
    // Selbstbeherrschung hat keine Behinderung; der Wert bleibt der TaW.
    expect(gefechtsTalentprobe(s, selbstbeherrschung)!.basePool, 6);
  });

  test('Zeitbedarf: Talente eine Aktion, Eigenschaften keine', () {
    expect(
      gefechtsZeitbedarfVorgabe(ProbeType.talent),
      GefechtsZeitbedarf.aktion,
    );
    expect(
      gefechtsZeitbedarfVorgabe(ProbeType.attribute),
      GefechtsZeitbedarf.ohneAktion,
    );
    const w = Gefechtswerte(iniBasis: 10, at: 14, pa: 12, ausweichen: 10);
    final s = beginneGefecht(6, dk: 'N');
    expect(pruefeGefechtsZeitbedarf(s, w, GefechtsZeitbedarf.ohneAktion), null);
    expect(
      pruefeGefechtsZeitbedarf(s, w, GefechtsZeitbedarf.freieAktion)!.freie,
      1,
    );
    final aktion = pruefeGefechtsZeitbedarf(s, w, GefechtsZeitbedarf.aktion)!;
    expect(aktion.angriffe + aktion.paraden, 1);
    // Ohne freie Aktionen ist die freie Probe gesperrt.
    final leer = s.copyWith(freieVerbraucht: 10);
    expect(
      pruefeGefechtsZeitbedarf(leer, w, GefechtsZeitbedarf.freieAktion)!.status,
      Gefechtsfreigabe.gesperrt,
    );
  });

  test('Talenteinsatz: TaP* verkürzen die geplante Dauer', () {
    final r = gefechtsTalentprobe(_snapshot(), selbstbeherrschung)!;
    final gelungen = _wurf(r, [1, 1, 1]);
    expect(gelungen.success, isTrue);
    expect(
      gefechtsTalenteinsatzDauer(10, gelungen),
      10 - gelungen.remainingPool,
    );
    expect(gefechtsTalenteinsatzDauer(2, gelungen), 1);
    final misslungen = _wurf(r, [20, 20, 19]);
    expect(misslungen.success, isFalse);
    expect(gefechtsTalenteinsatzDauer(5, misslungen), 5);
    expect(() => gefechtsTalenteinsatzDauer(0, gelungen), throwsArgumentError);
  });
}
