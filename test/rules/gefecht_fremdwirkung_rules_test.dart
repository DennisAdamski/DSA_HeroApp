import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_fremdwirkung.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_gegner.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_fremdwirkung_rules.dart';

ProbeResult probe({bool erfolg = true}) => evaluateProbe(
  const ResolvedProbeRequest(
    type: ProbeType.spell,
    title: 'Fulminictus Donnerkeil',
    subtitle: '',
    ruleHint: '',
    diceSpec: DiceSpec(count: 3, sides: 20),
    targets: [
      ProbeTargetValue(label: 'IN', value: 14),
      ProbeTargetValue(label: 'GE', value: 14),
      ProbeTargetValue(label: 'KO', value: 14),
    ],
    basePool: 5,
  ),
  ProbeRollInput(
    mode: ProbeRollMode.manual,
    diceValues: erfolg ? [10, 10, 10] : [20, 20, 20],
    situationalModifier: 0,
    specializationApplied: false,
  ),
);

void main() {
  const ziel = GefechtsFremdwirkung(
    zauberId: 'spell_fulminictus_donnerkeil',
    gegnerId: 'a',
    verfuegbareAsp: 40,
  );
  test('Nur exakte Katalog-ID erhält ein Fremdzielprofil', () {
    expect(gefechtsFremdprofilUnterstuetzt(ziel.zauberId), isTrue);
    expect(gefechtsFremdprofilUnterstuetzt('spell_ignifaxius'), isFalse);
    expect(gefechtsFremdprofilUnterstuetzt('Fulminictus'), isFalse);
  });
  test('Eingefrorene Probe liefert direkte SP und gleiche variable Kosten', () {
    final original = probe();
    final wurf = gefechtsFulminictusWurf(
      ziel: ziel,
      probe: original,
      ersterW6: 3,
      zweiterW6: 4,
    );
    expect(wurf.probe, same(original));
    expect(gefechtsFremdschaden(wurf, verfuegbareAsp: 40), 12);
    expect(gefechtsFremdschaden(wurf, verfuegbareAsp: 7), 7);
    expect(gefechtsFremdschaden(wurf, verfuegbareAsp: 0), 0);
    expect(wurf.schaden, 12);
    expect(wurf.kosten, 12);
  });
  test(
    'Startenergie begrenzt dauerhaft und wird beim Wiederöffnen nicht erhöht',
    () {
      final wurf = gefechtsFulminictusWurf(
        ziel: const GefechtsFremdwirkung(
          zauberId: 'spell_fulminictus_donnerkeil',
          gegnerId: 'a',
          verfuegbareAsp: 7,
        ),
        probe: probe(),
        ersterW6: 6,
        zweiterW6: 6,
      );
      expect(wurf.schaden, 7);
      expect(wurf.kosten, 7);
    },
  );
  test(
    'Kein Wirkungsschaden bei Fehlschlag, fremden IDs oder falschen Würfeln',
    () {
      expect(
        () => gefechtsFulminictusWurf(
          ziel: ziel,
          probe: probe(erfolg: false),
          ersterW6: 3,
          zweiterW6: 4,
        ),
        throwsStateError,
      );
      expect(
        () => gefechtsFulminictusWurf(
          ziel: ziel,
          probe: probe(),
          ersterW6: 0,
          zweiterW6: 7,
        ),
        throwsArgumentError,
      );
      expect(
        () => gefechtsFulminictusWurf(
          ziel: const GefechtsFremdwirkung(
            zauberId: 'other',
            gegnerId: 'a',
            verfuegbareAsp: 40,
          ),
          probe: probe(),
          ersterW6: 3,
          zweiterW6: 4,
        ),
        throwsStateError,
      );
    },
  );
  test(
    'Originalziel, frische LeP, RS ignoriert und doppelte Buchung ohne Folge',
    () {
      final wurf = gefechtsFulminictusWurf(
        ziel: const GefechtsFremdwirkung(
          zauberId: 'spell_fulminictus_donnerkeil',
          gegnerId: 'a',
          verfuegbareAsp: 7,
        ),
        probe: probe(),
        ersterW6: 3,
        zweiterW6: 4,
      );
      const s = Gefechtsbegegnung(
        gegner: {
          'a': Gefechtsgegner(id: 'a', name: 'A', lep: 25, rs: 100, ini: 10),
          'b': Gefechtsgegner(id: 'b', name: 'B', lep: 30, rs: 0, ini: 10),
        },
      );
      final neu = bucheGefechtsFremdwirkung(
        s,
        wurf: wurf,
        buchungId: 'einmal',
        schaden: 7,
      );
      expect(neu.gegner['a']!.lep, 18);
      expect(neu.gegner['b']!.lep, 30);
      expect(
        bucheGefechtsFremdwirkung(
          neu,
          wurf: wurf,
          buchungId: 'einmal',
          schaden: 7,
        ),
        same(neu),
      );
      expect(
        () => bucheGefechtsFremdwirkung(
          const Gefechtsbegegnung(),
          wurf: wurf,
          buchungId: 'einmal',
          schaden: 7,
        ),
        throwsStateError,
      );
    },
  );
}
