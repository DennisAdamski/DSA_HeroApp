import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_gefecht_probe_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_kampfprofil_rules.dart';
import 'package:flutter_test/flutter_test.dart';

// Würfelhilfen für Begleiterangriffe im Gefecht (Vertraute V3a): Die Werte
// kommen unverändert aus dem Kampfprofil (mit Steigerung und Ausbildung).

HeroCompanion _kater({
  BegleiterTyp typ = BegleiterTyp.vertrauter,
  VertrautenBindung? bindung = const VertrautenBindung(artId: 'vart_katze'),
  List<HeroCompanionAttack>? angriffe,
}) => HeroCompanion(
  id: 'kater',
  name: 'Kater',
  typ: typ,
  vertrautenBindung: bindung,
  angriffe:
      angriffe ??
      const [
        HeroCompanionAttack(
          id: 'pranke',
          name: 'Prankenhieb',
          at: 10,
          pa: 5,
          tp: '1W6',
          dk: 'H',
          steigerungAt: 2,
        ),
      ],
);

void main() {
  BegleiterKampfprofil profil(HeroCompanion c) => begleiterKampfprofil(c);

  group('AT, PA und TP aus dem Kampfprofil', () {
    test('die AT-Probe würfelt 1W20 gegen die wirksame AT', () {
      final p = profil(_kater());
      final request = begleiterAngriffProbe(p, p.angriffe.single)!;
      expect(request.type, ProbeType.combatAttack);
      expect(request.diceSpec.count, 1);
      expect(request.diceSpec.sides, 20);
      // 10 + 2 gesteigert.
      expect(request.targets.single.value, 12);
      expect(request.title, contains('Kater'));
      expect(request.title, contains('Prankenhieb'));
      expect(request.ruleHint, contains('DK H'));
      expect(request.verweis, isNull);
    });

    test('die PA-Probe nutzt die wirksame PA', () {
      final p = profil(_kater());
      final request = begleiterParadeProbe(p, p.angriffe.single)!;
      expect(request.type, ProbeType.combatParry);
      expect(request.targets.single.value, 5);
    });

    test('der TP-Wurf liest den Würfelausdruck', () {
      final p = profil(
        _kater(
          angriffe: const [
            HeroCompanionAttack(id: 'biss', name: 'Biss', at: 9, tp: '1W6+3'),
          ],
        ),
      );
      final request = begleiterSchadenProbe(p, p.angriffe.single)!;
      expect(request.type, ProbeType.damage);
      expect(request.diceSpec.label, '1W6+3');
      expect(request.targets, isEmpty);
    });

    test('ohne AT, PA oder lesbare TP gibt es keine Probe', () {
      final p = profil(
        _kater(
          angriffe: const [
            HeroCompanionAttack(id: 'huf', name: 'Huf', tp: 'Huf +2'),
          ],
        ),
      );
      final a = p.angriffe.single;
      expect(begleiterAngriffProbe(p, a), isNull);
      expect(begleiterParadeProbe(p, a), isNull);
      expect(begleiterSchadenProbe(p, a), isNull);
    });
  });

  group('Angriffe gelten als magisch (WdZ S. 125)', () {
    test('nur bei einem gebundenen Vertrauten', () {
      expect(profil(_kater()).angriffeMagisch, isTrue);
      expect(profil(_kater(bindung: null)).angriffeMagisch, isFalse);
      expect(
        profil(_kater(typ: BegleiterTyp.reittier, bindung: null))
            .angriffeMagisch,
        isFalse,
      );
    });

    test('der Hinweis steht in allen drei Proben', () {
      final p = profil(_kater());
      final a = p.angriffe.single;
      for (final request in [
        begleiterAngriffProbe(p, a)!,
        begleiterParadeProbe(p, a)!,
        begleiterSchadenProbe(p, a)!,
      ]) {
        expect(request.ruleHint, contains(kBegleiterMagischHinweis));
      }
    });

    test('ohne Bindung fehlt der Hinweis', () {
      final p = profil(_kater(bindung: null));
      expect(
        begleiterAngriffProbe(p, p.angriffe.single)!.ruleHint,
        isNot(contains('magisch')),
      );
    });
  });
}
