import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/bought_stats.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/basiswert_herleitung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/kampfbasis_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_source_breakdown.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ressourcen_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import '../test_support/hero_fixtures.dart';
import '../test_support/real_catalog.dart';

const _attribute = Attributes(
  mu: 14,
  kl: 12,
  inn: 13,
  ch: 11,
  ff: 10,
  ge: 12,
  ko: 14,
  kk: 13,
);

const _zustand = HeroState(
  currentLep: 0,
  currentAsp: 0,
  currentKap: 0,
  currentAu: 0,
);

DerivedStats _rechne(
  HeroSheet held, {
  HeroState zustand = _zustand,
  StatModifiers wunden = const StatModifiers(),
  List<StatModifikatorQuelle>? textAufteilung,
  ModifierParseResult parsed = const ModifierParseResult(),
}) {
  return computeDerivedStatsFromInputs(
    sheet: held,
    state: zustand,
    parsedModifiers: parsed,
    effectiveAttributes: held.attributes,
    wundStatMods: wunden,
    textAufteilung: textAufteilung,
  );
}

HerleitungsSchritt _schritt(Herleitung h, String bezeichnung) =>
    h.schritte.singleWhere((s) => s.bezeichnung == bezeichnung);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Herleitung', () {
    test('der Wert ist die Summe aller Schritte', () {
      final h = Herleitung(
        bezeichnung: 'X',
        schritte: const <HerleitungsSchritt>[
          HerleitungsSchritt(
            bezeichnung: 'Grundwert',
            betrag: 10,
            art: HerleitungsArt.grundwert,
          ),
          HerleitungsSchritt(
            bezeichnung: 'Leer',
            betrag: 0,
            art: HerleitungsArt.modifikator,
          ),
          HerleitungsSchritt(
            bezeichnung: 'Malus',
            betrag: -3,
            art: HerleitungsArt.modifikator,
          ),
        ],
      );
      expect(h.wert, 7);
      expect(h.summeVon(HerleitungsArt.modifikator), -3);
      expect(h.sichtbareSchritte.map((s) => s.bezeichnung), <String>[
        'Grundwert',
        'Malus',
      ]);
    });

    test('mitUntergrenze gleicht genau die Differenz aus', () {
      final schritte = mitUntergrenze(
        const <HerleitungsSchritt>[
          HerleitungsSchritt(
            bezeichnung: 'a',
            betrag: -4,
            art: HerleitungsArt.modifikator,
          ),
        ],
        untergrenze: 0,
        bezeichnung: 'Untergrenze 0',
      );
      expect(summeDer(schritte), 0);
      expect(schritte.last.betrag, 4);
      expect(schritte.last.art, HerleitungsArt.begrenzung);
    });
  });

  group('Basiswerte', () {
    test('jeder Wert stammt aus seiner Herleitung, mit Formel und Quellen', () {
      final held = HeroSheet(
        id: 'h',
        name: 'Held',
        level: 30,
        attributes: _attribute,
        bought: const BoughtStats(lep: 1, au: 2),
        persistentMods: const StatModifiers(lep: 2),
        statModifiers: <String, List<HeroTalentModifier>>{
          'lep': <HeroTalentModifier>[
            HeroTalentModifier(modifier: 3, description: 'Segen'),
          ],
        },
      );
      final d = _rechne(held);
      final lep = d.herleitungen!.maxLep;

      expect(lep.wert, d.maxLep);
      // round((14+14+13)/2) = 21, Stufe höchstens 21, +1 zugekauft, +2, +3.
      expect(d.maxLep, 21 + 21 + 1 + 2 + 3);
      expect(_schritt(lep, 'Grundwert').formel, '(KO 14 + KO 14 + KK 13) / 2');
      expect(_schritt(lep, 'Stufe').betrag, 21);
      expect(_schritt(lep, 'Zugekauft').betrag, 1);
      expect(_schritt(lep, 'Schnellmodifikatoren').betrag, 2);
      final segen = _schritt(lep, 'Segen');
      expect(segen.betrag, 3);
      expect(segen.quelle, 'Eigener Modifikator');
      // Der eigene LeP-Modifikator wirkt auf keinen anderen Wert.
      expect(_schritt(d.herleitungen!.maxAu, 'Segen').betrag, 0);
    });

    test('alle Werte gleichen den Einzelformeln', () {
      final held = HeroSheet(
        id: 'h',
        name: 'Held',
        level: 7,
        attributes: _attribute,
        bought: const BoughtStats(lep: 2, au: 1, asp: 3, kap: 4, mr: 1),
        persistentMods: const StatModifiers(
          asp: 2,
          mr: -1,
          iniBase: 2,
          at: 1,
          pa: -1,
          fk: 2,
          gs: 1,
          ausweichen: 3,
        ),
        combatConfig: const CombatConfig(
          specialRules: CombatSpecialRules(
            kampfreflexe: true,
            kampfgespuer: true,
          ),
        ),
      );
      final d = _rechne(held);
      final mods = d.modifiers;
      final h = d.herleitungen!;
      expect(h.maxLep.wert, computeMaxLep(held, mods));
      expect(h.maxAu.wert, computeMaxAu(held, mods));
      expect(h.maxAsp.wert, computeMaxAsp(held, mods));
      expect(h.maxKap.wert, computeMaxKap(held, mods));
      expect(h.mr.wert, computeMr(held, mods));
      expect(h.atBase.wert, computeAt(held, mods));
      expect(h.paBase.wert, computePa(held, mods));
      expect(h.fkBase.wert, computeFk(held, mods));
      expect(h.gs.wert, computeGs(held, mods));
      expect(h.ausweichen.wert, 3);
      // Kampfreflexe und Kampfgespür erscheinen als eigene Schritte.
      expect(_schritt(h.iniBase, 'Kampfreflexe').betrag, 4);
      expect(_schritt(h.iniBase, 'Kampfgespür').betrag, 2);
      expect(
        _schritt(h.iniBase, 'Kampfreflexe').art,
        HerleitungsArt.sonderfertigkeit,
      );
    });

    test('Untergrenze 0 ist ein sichtbarer Ausgleich', () {
      const held = HeroSheet(
        id: 'h',
        name: 'Held',
        level: 1,
        attributes: _attribute,
        persistentMods: StatModifiers(kap: -3),
      );
      final kap = _rechne(held).herleitungen!.maxKap;
      expect(kap.wert, 0);
      expect(_schritt(kap, 'Untergrenze 0').betrag, 3);
    });

    test('GS: Axxeleratus verdoppelt, Wunden senken nicht unter 1', () {
      const held = HeroSheet(
        id: 'h',
        name: 'Held',
        level: 1,
        attributes: _attribute,
        combatConfig: CombatConfig(
          specialRules: CombatSpecialRules(axxeleratusActive: true),
        ),
      );
      final ohneWunden = _rechne(held).herleitungen!.gs;
      expect(ohneWunden.wert, 16);
      expect(_schritt(ohneWunden, 'Axxeleratus').betrag, 8);

      final gs = _rechne(
        held,
        wunden: const StatModifiers(gs: -10),
      ).herleitungen!.gs;
      // (8 − 10) × 2 = −4, die Wundgrenze hebt auf 1.
      expect(_schritt(gs, 'Wunden').betrag, -10);
      expect(_schritt(gs, 'Axxeleratus').betrag, -2);
      expect(_schritt(gs, 'Wunden senken die GS nicht unter 1').betrag, 5);
      expect(gs.wert, 1);
    });

    test('eine unpassende Textaufteilung fällt auf einen Schritt zurück', () {
      const held = HeroSheet(
        id: 'h',
        name: 'Held',
        level: 1,
        attributes: _attribute,
      );
      const parsed = ModifierParseResult(statMods: StatModifiers(lep: 2));
      final passend = _rechne(
        held,
        parsed: parsed,
        textAufteilung: const <StatModifikatorQuelle>[
          StatModifikatorQuelle(
            bezeichnung: 'Rasse',
            mods: StatModifiers(lep: 2),
          ),
        ],
      ).herleitungen!.maxLep;
      expect(_schritt(passend, 'Rasse').betrag, 2);

      final unpassend = _rechne(
        held,
        parsed: parsed,
        textAufteilung: const <StatModifikatorQuelle>[
          StatModifikatorQuelle(
            bezeichnung: 'Rasse',
            mods: StatModifiers(lep: 5),
          ),
        ],
      ).herleitungen!.maxLep;
      expect(
        unpassend.schritte.where((s) => s.bezeichnung == 'Rasse'),
        isEmpty,
      );
      expect(_schritt(unpassend, 'Herkunft, Vor- und Nachteile').betrag, 2);
      expect(unpassend.wert, passend.wert);
    });
  });

  group('Bestandshelden', () {
    late EchterKatalog katalog;

    setUpAll(() async {
      katalog = await ladeEchtenRegelkatalog();
    });

    for (final bestand in Bestandsheld.values) {
      test('${bestand.datei}: Herleitung nach Herkunft, Summe stimmt', () {
        final bundle = ladeBestandsheld(bestand);
        final zustand = bundle.state.copyWith(
          wpiZustand: const WundZustand(
            wundenProZone: <WundZone, int>{WundZone.bauch: 1},
          ),
        );
        final snapshot = buildHeroComputedSnapshot(
          hero: bundle.hero,
          state: zustand,
          catalog: katalog.catalog,
          epicAdvantagesActive: true,
        );
        final d = snapshot.derivedStats;
        final h = d.herleitungen!;
        for (final key in kStatModifikatorSchluessel) {
          final herleitung = h.fuer(key);
          if (herleitung == null) {
            continue;
          }
          // Die Modifikatorschritte zerlegen genau die Modifikatorsumme.
          final quellenSchritte = herleitung.schritte.where(
            (s) =>
                s.art == HerleitungsArt.modifikator &&
                s.quelle != 'Rüstung' &&
                s.quelle != 'Vorteil' &&
                s.quelle != 'Nachteil',
          );
          expect(
            summeDer(quellenSchritte),
            statModValue(d.modifiers, key),
            reason: '${bestand.datei} $key',
          );
          // Mit Katalog zerlegt die Herleitung den Text nach Herkunft.
          expect(
            herleitung.schritte.any(
              (s) => s.bezeichnung == 'Herkunft, Vor- und Nachteile',
            ),
            isFalse,
            reason: '${bestand.datei} $key',
          );
        }
        expect(h.maxLep.wert, d.maxLep);
        expect(h.gs.wert, d.gs);
        expect(h.iniBase.wert, d.iniBase);
      });
    }
  });
}
