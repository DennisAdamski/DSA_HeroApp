import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_gegner.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_gegner_rules.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';

void main() {
  const ork = Gefechtsgegner(id: 'a', name: 'Ork', lep: 20, rs: 3, ini: 12);
  const anderer = Gefechtsgegner(id: 'b', name: 'Ork', lep: 30, rs: 1, ini: 15);

  test('Zielwechsel trennt IDs und verwirft veraltete Angriffsdaten', () {
    const alt = Gefechtszustand(
      iniWurf: 6,
      kontext: Gefechtskontext(
        kontakt: 'Ork',
        gegnerId: 'a',
        finte: 4,
        entfernung: 12,
      ),
    );
    final neu = waehleGefechtsgegner(alt, anderer, startDk: 'N');
    expect(neu.kontext.gegnerId, 'b');
    expect(neu.kontext.zielkennung, isNot(alt.kontext.zielkennung));
    expect(neu.kontext.entfernung, isNull);
    expect(neu.kontext.finte, 0);
    expect(neu.kontext.ohneAngriff().gegnerId, 'b');
    expect(neu.kontext.copyWith(entfernung: 3).gegnerId, 'b');
  });

  test(
    'TP berücksichtigt RS, direkte SP umgehen ihn, LeP dürfen negativ sein',
    () {
      expect(gefechtsGegnerschaden(ork, 8).lep, 15);
      expect(gefechtsGegnerschaden(ork, 2).lep, 20);
      expect(gefechtsGegnerschaden(ork, 8, direkt: true).lep, 12);
      expect(gefechtsGegnerschaden(ork, 30).lep, -7);
      expect(() => gefechtsGegnerschaden(ork, -1), throwsArgumentError);
    },
  );

  test(
    'IDs trennen gleiche Namen, frischer RS und einmalige Buchung gelten',
    () {
      var s = Gefechtsbegegnung(gegner: {'a': ork, 'b': anderer});
      s = bucheGefechtsGegnerschaden(s, gegnerId: 'a', buchungId: 'h:1', tp: 8);
      expect(s.gegner['a']!.lep, 15);
      expect(s.gegner['b']!.lep, 30);
      expect(
        identical(
          bucheGefechtsGegnerschaden(s, gegnerId: 'a', buchungId: 'h:1', tp: 8),
          s,
        ),
        isTrue,
      );
      s = speichereGefechtsgegner(s, ork.copyWith(lep: 15, rs: 5));
      s = bucheGefechtsGegnerschaden(s, gegnerId: 'a', buchungId: 'h:2', tp: 8);
      expect(s.gegner['a']!.lep, 12);
    },
  );

  test('Ungültige Profile und verschwundene Ziele verändern nichts', () {
    const leer = Gefechtsbegegnung();
    expect(
      () => speichereGefechtsgegner(leer, ork.copyWith(rs: -1)),
      throwsArgumentError,
    );
    expect(
      () => bucheGefechtsGegnerschaden(
        leer,
        gegnerId: 'a',
        buchungId: 'h:1',
        tp: 8,
      ),
      throwsStateError,
    );
  });
}
