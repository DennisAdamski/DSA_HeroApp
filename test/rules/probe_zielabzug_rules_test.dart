import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wund_rules.dart';

// Armwunden: KK und FF −2 gelten nur, „wenn er diesen Arm benutzt“
// (Wege des Schwerts S. 108 f.). Der Probendialog fragt danach.
void main() {
  WundEffekte wunden(Map<WundZone, int> proZone, {bool linkshaender = false}) =>
      computeWundEffekte(
        WundZustand(wundenProZone: proZone),
        linkshaender: linkshaender,
      );

  ResolvedProbeRequest probe(List<String> labels) => ResolvedProbeRequest(
    type: ProbeType.talent,
    title: 'Talentprobe: Test',
    subtitle: labels.join(' / '),
    ruleHint: '',
    diceSpec: const DiceSpec(count: 3, sides: 20),
    targets: <ProbeTargetValue>[
      for (final label in labels) ProbeTargetValue(label: label, value: 13),
    ],
    basePool: 5,
  );

  test('je verwundetem Arm ein Abzug mit Armrolle', () {
    final abzuege = armWundenZielAbzuege(
      wunden(const {WundZone.rechterArm: 1, WundZone.linkerArm: 2}),
    );
    expect(abzuege.map((a) => a.bezeichnung), [
      'Linker Arm (Schildarm)',
      'Rechter Arm (Schwertarm)',
    ]);
    expect(abzuege[0].abzuege, {'KK': -4, 'FF': -4});
    expect(abzuege[1].abzuege, {'KK': -2, 'FF': -2});
  });

  test('Linkshänder: der linke Arm trägt die Rolle Schwertarm', () {
    final abzuege = armWundenZielAbzuege(
      wunden(const {WundZone.linkerArm: 1}, linkshaender: true),
    );
    expect(abzuege.single.bezeichnung, 'Linker Arm (Schwertarm)');
  });

  test('unterdrückte Armwunden bieten keinen Abzug an', () {
    final unterdrueckt = computeWundEffekte(
      const WundZustand(
        wundenProZone: {WundZone.rechterArm: 1},
        unterdrueckteWundenProZone: {WundZone.rechterArm: 1},
      ),
    );
    expect(armWundenZielAbzuege(unterdrueckt), isEmpty);
  });

  test('nur Proben mit KK oder FF bekommen den Abzug', () {
    final effekte = wunden(const {WundZone.rechterArm: 1});
    final mitKk = probeMitArmwundenAbzug(probe(['MU', 'GE', 'KK']), effekte);
    expect(mitKk.bedingteZielAbzuege, hasLength(1));
    final ohne = probe(['MU', 'KL', 'IN']);
    expect(identical(probeMitArmwundenAbzug(ohne, effekte), ohne), isTrue);
    final ohneWunde = probe(['MU', 'GE', 'KK']);
    expect(
      identical(
        probeMitArmwundenAbzug(ohneWunde, const WundEffekte()),
        ohneWunde,
      ),
      isTrue,
    );
  });

  test('gewählte Abzüge senken nur die betroffenen Zielwerte', () {
    final effekte = wunden(const {WundZone.rechterArm: 1});
    final angebot = probeMitArmwundenAbzug(probe(['FF', 'GE', 'KK']), effekte);
    final gewertet = wendeZielAbzuegeAn(angebot, angebot.bedingteZielAbzuege);
    expect(gewertet.targets.map((t) => (t.label, t.value)), [
      ('FF', 11),
      ('GE', 13),
      ('KK', 11),
    ]);
    expect(gewertet.bedingteZielAbzuege, isEmpty);
    expect(identical(wendeZielAbzuegeAn(angebot, const []), angebot), isTrue);
  });

  test('beide Arme gewählt addieren sich', () {
    final effekte = wunden(const {
      WundZone.rechterArm: 1,
      WundZone.linkerArm: 1,
    });
    final angebot = probeMitArmwundenAbzug(probe(['KK']), effekte);
    final gewertet = wendeZielAbzuegeAn(angebot, angebot.bedingteZielAbzuege);
    expect(gewertet.targets.single.value, 9);
  });
}
