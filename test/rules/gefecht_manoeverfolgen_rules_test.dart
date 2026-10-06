import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_gegner.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_manoeverfolgen_rules.dart';

void main() {
  const g = Gefechtsgegner(id: 'g', name: 'Ork', lep: 20, rs: 3, ini: 12);
  test('Entwaffnen ist schadenslos und KK 8/10 erschwert', () {
    expect(
      gefechtsGegenprobe(
        'man_entwaffnen',
        eigenschaft: 15,
      ).targets.single.value,
      15,
    );
    expect(
      gefechtsGegenprobe(
        'man_entwaffnen',
        eigenschaft: 15,
      ).initialSituationalModifier,
      -8,
    );
    expect(
      gefechtsGegenprobe(
        'man_entwaffnen',
        eigenschaft: 15,
        meisterlich: true,
      ).initialSituationalModifier,
      -10,
    );
    final neu = gefechtsManoeverfolge(
      g,
      'man_entwaffnen',
      gegenprobeErfolg: false,
    );
    expect(neu.lep, 20);
    expect(neu.entwaffnet, isTrue);
    expect(
      gefechtsManoeverfolge(g, 'man_entwaffnen', gegenprobeErfolg: true),
      same(g),
    );
  });
  test(
    'Umreißen nutzt TP nur zur GE-Erschwernis und 2W6 INI bei Misslingen',
    () {
      final p = gefechtsGegenprobe(
        'man_umreissen',
        eigenschaft: 14,
        tp: 8,
        standBonus: 4,
      );
      expect(p.initialSituationalModifier, -4);
      final neu = gefechtsManoeverfolge(
        g,
        'man_umreissen',
        gegenprobeErfolg: false,
        iniVerlust: 7,
      );
      expect(neu.liegend, isTrue);
      expect(neu.ini, 5);
      expect(neu.lep, 20);
    },
  );
}
