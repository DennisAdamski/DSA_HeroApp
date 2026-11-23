import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/fallen_fischen_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_probe_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wildnis_region_rules.dart';

// Tierfallen (Wege des Entdeckers S. 111 f.): doppeltes Fallenstellen im
// Metatalent, höchstens der TaW Fallenstellen, Geländekunde −5/−3, in
// Hochgebirge, Ewigem Eis und Wüste nicht möglich. Angeln und Speerfischen
// (S. 110 f.): Region wie beim Angeln, in der Wüste nicht möglich; beim
// Speerfischen zählen Waffe und Scharfschütze.

const List<ProbeTargetValue> _eigenschaften = <ProbeTargetValue>[
  ProbeTargetValue(label: 'KL', value: 12),
  ProbeTargetValue(label: 'IN', value: 12),
  ProbeTargetValue(label: 'FF', value: 12),
];

RationenProbeEingabe _eingabe({
  Wildnisregion region = Wildnisregion.dichterWald,
  bool schmackhaft = false,
  Gelaendekunde gelaendekunde = Gelaendekunde.keine,
  bool ortskenntnis = false,
}) => RationenProbeEingabe(
  region: region,
  taw: 8,
  eigenschaften: _eigenschaften,
  nurSchmackhaft: schmackhaft,
  gelaendekunde: gelaendekunde,
  ortskenntnis: ortskenntnis,
);

Map<String, HeroTalentEntry> _talente(
  Map<String, int> werte,
) => <String, HeroTalentEntry>{
  for (final e in werte.entries) e.key: HeroTalentEntry(talentValue: e.value),
};

void main() {
  group('Tierfallen', () {
    test('Fallenstellen zählt doppelt', () {
      final taw = tierfallenTaw(
        _talente(<String, int>{
          'tal_fallenstellen': 10,
          'tal_tierkunde': 5,
          'tal_faehrtensuchen': 5,
          'tal_wildnisleben': 10,
        }),
      );
      // (2 × 10 + 5 + 5 + 10) / 5 = 8.
      expect(taw, 8);
    });

    test('höchstens der TaW Fallenstellen', () {
      final taw = tierfallenTaw(
        _talente(<String, int>{
          'tal_fallenstellen': 6,
          'tal_tierkunde': 14,
          'tal_faehrtensuchen': 14,
          'tal_wildnisleben': 14,
        }),
      );
      // Mittel (12 + 42) / 5 = 10,8 → 11, aber höchstens Fallenstellen 6.
      expect(taw, 6);
    });

    test('Region nach WdE S. 112, Gebirge nach eigenem Eintrag +4', () {
      expect(tierfallenRegionsErschwernis(Wildnisregion.lichterWald), -4);
      expect(tierfallenRegionsErschwernis(Wildnisregion.maraskanDschungel), -4);
      expect(tierfallenRegionsErschwernis(Wildnisregion.suempfeNord), 2);
      expect(tierfallenRegionsErschwernis(Wildnisregion.tundra), 2);
      expect(tierfallenRegionsErschwernis(Wildnisregion.gebirge), 4);
      expect(tierfallenRegionsErschwernis(Wildnisregion.graslandHeide), 0);
      expect(tierfallenRegionsErschwernis(Wildnisregion.hochgebirge), isNull);
      expect(tierfallenRegionsErschwernis(Wildnisregion.wueste), isNull);
      expect(tierfallenRegionsErschwernis(Wildnisregion.ewigesEis), isNull);
    });

    test('Geländekunde −5, ähnlich −3, schmackhaft +1', () {
      WildnisProbeEingabe e(Gelaendekunde g, {bool schmackhaft = false}) =>
          tierfallenProbeEingabe(
            _eingabe(gelaendekunde: g, schmackhaft: schmackhaft),
          )!;
      expect(wildnisProbenErschwernis(e(Gelaendekunde.passend)), -4 - 5);
      expect(wildnisProbenErschwernis(e(Gelaendekunde.aehnlich)), -4 - 3);
      expect(
        wildnisProbenErschwernis(e(Gelaendekunde.keine, schmackhaft: true)),
        -3,
      );
    });

    test('in der Wüste nicht möglich', () {
      expect(
        tierfallenProbeEingabe(_eingabe(region: Wildnisregion.wueste)),
        isNull,
      );
    });
  });

  group('Fischen', () {
    test('Region beim Angeln', () {
      expect(fischenRegionsErschwernis(Wildnisregion.suempfeSued), -4);
      expect(fischenRegionsErschwernis(Wildnisregion.suempfeNord), -2);
      expect(fischenRegionsErschwernis(Wildnisregion.gebirge), 2);
      expect(fischenRegionsErschwernis(Wildnisregion.ewigesEis), 8);
      expect(fischenRegionsErschwernis(Wildnisregion.dichterWald), 0);
      expect(fischenRegionsErschwernis(Wildnisregion.wueste), isNull);
    });

    test('Angeln mit Ortskenntnis und schmackhafter Beute', () {
      final e = angelnProbeEingabe(
        _eingabe(
          region: Wildnisregion.gebirge,
          schmackhaft: true,
          ortskenntnis: true,
        ),
      )!;
      expect(wildnisProbenErschwernis(e), 2 + 2 - 7);
      expect(
        angelnProbeEingabe(_eingabe(region: Wildnisregion.wueste)),
        isNull,
      );
    });

    test('Speerfischen nach Waffe und Scharfschütze', () {
      int erschwernis(Fischspeer speer, {bool scharf = false}) =>
          wildnisProbenErschwernis(
            speerfischenProbeEingabe(
              _eingabe(region: Wildnisregion.suempfeSued),
              speer: speer,
              scharfschuetze: scharf,
            )!,
          );
      expect(erschwernis(Fischspeer.fischspeer), -4 - 3);
      expect(erschwernis(Fischspeer.wurfspeer), -4);
      expect(erschwernis(Fischspeer.stock, scharf: true), -4 + 3 - 3);
    });

    test('Speerfischen mit Speeren oder Wurfspeeren', () {
      expect(speerfischenTalente('tal_wurfspeere'), <String>[
        'tal_wildnisleben',
        'tal_tierkunde',
        'tal_selbstbeherrschung',
        'tal_wurfspeere',
      ]);
    });

    test('Einzeltalent ohne Metatalent-Deckel', () {
      final talente = _talente(<String, int>{'tal_fischen_angeln': -2});
      expect(einzeltalentTaw(talente, kAngelnTalent), -2);
      expect(
        einzeltalentTaw(const <String, HeroTalentEntry>{}, kAngelnTalent),
        0,
      );
    });
  });
}
