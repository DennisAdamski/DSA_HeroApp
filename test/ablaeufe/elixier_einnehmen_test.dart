import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/elixier_einnehmen.dart';
import 'package:dsa_heldenverwaltung/catalog/alchimikum_def.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/alchimika_elixier_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_instance_rules.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

final _jetzt = DateTime.utc(2026, 10, 16, 9);

const _mut = AlchimikumDef(
  id: 'alch_mutelixier',
  name: 'Mutelixier',
  qualitaeten: <AlchimikumQualitaet>[
    AlchimikumQualitaet(stufe: 'B'),
    AlchimikumQualitaet(
      stufe: 'C',
      eigenschaften: <AlchimikumEigenschaft>[
        AlchimikumEigenschaft(
          eigenschaft: 'MU',
          wert: 3,
          dauer: 3,
          einheit: 'spielrunden',
        ),
      ],
    ),
  ],
);

const _start = HeroState(
  currentLep: 20,
  currentAsp: 0,
  currentKap: 0,
  currentAu: 20,
);

void main() {
  var zaehler = 0;
  ElixierEinnehmen ablauf(FakeRepository repo) => ElixierEinnehmen(
    repository: repo,
    uhr: () => _jetzt,
    neueId: () => 'id-${zaehler++}',
  );

  test('legt die Wirkung an und protokolliert in einem Dokument', () async {
    final repo = FakeRepository(states: {'demo': _start});
    final angelegt = await ablauf(repo)
        .uebernimm(heroId: 'demo', mittel: _mut, stufe: 'C', vorgangId: 'v1');

    expect(angelegt.single.wert, 3);
    final z = (await repo.loadHeroState('demo'))!;
    expect(z.activeSpellEffects.instanzen, hasLength(1));
    expect(effektiveTempAttributeMods(z).mu, 3);
    expect(z.diceLog, hasLength(1));
    expect(z.diceLog.single.title, elixierProtokollTitel);
    expect(z.diceLog.single.subtitle, contains('Mutelixier (Qualität C)'));
    expect(z.diceLog.single.subtitle, contains('MU +3'));
    expect(z.lastModified, _jetzt);
  });

  test('eine Wiederholung derselben Vorgangs-ID wirkt nicht doppelt', () async {
    final repo = FakeRepository(states: {'demo': _start});
    final a = ablauf(repo);
    await a.uebernimm(
      heroId: 'demo',
      mittel: _mut,
      stufe: 'C',
      vorgangId: 'v1',
    );
    final zweite = await a.uebernimm(
      heroId: 'demo',
      mittel: _mut,
      stufe: 'C',
      vorgangId: 'v1',
    );

    expect(zweite, isEmpty);
    final z = (await repo.loadHeroState('demo'))!;
    expect(z.activeSpellEffects.instanzen, hasLength(1));
    expect(z.diceLog, hasLength(1));
  });

  test('eine neue Vorgangs-ID nimmt ein zweites Elixier ein', () async {
    final repo = FakeRepository(states: {'demo': _start});
    final a = ablauf(repo);
    await a.uebernimm(
      heroId: 'demo',
      mittel: _mut,
      stufe: 'C',
      vorgangId: 'v1',
    );
    await a.uebernimm(
      heroId: 'demo',
      mittel: _mut,
      stufe: 'C',
      vorgangId: 'v2',
    );

    final z = (await repo.loadHeroState('demo'))!;
    expect(z.activeSpellEffects.instanzen, hasLength(2));
    expect(effektiveTempAttributeMods(z).mu, 6);
  });

  test(
    'Stufen ohne Eigenschaftswirkung und unbekannte Stufen werden abgewiesen',
    () async {
      final repo = FakeRepository(states: {'demo': _start});
      final a = ablauf(repo);
      for (final stufe in ['B', 'F']) {
        expect(
          () => a.uebernimm(
            heroId: 'demo',
            mittel: _mut,
            stufe: stufe,
            vorgangId: 'v',
          ),
          throwsStateError,
        );
      }
      final z = (await repo.loadHeroState('demo'))!;
      expect(z.activeSpellEffects.instanzen, isEmpty);
    },
  );
}
