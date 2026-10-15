import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/domain/spell_effect_instance.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_state_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_request_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_probe_rules.dart';

import '../test_support/real_catalog.dart';

HeroState _mit(List<SpellEffectInstance> instanzen) {
  var zustand = const HeroState(
    currentLep: 30,
    currentAsp: 20,
    currentKap: 0,
    currentAu: 30,
  );
  for (final instanz in instanzen) {
    zustand = aktiviereEffektInstanz(zustand, instanz);
  }
  return zustand;
}

SpellEffectInstance _adler(int zfp) => SpellEffectInstance(
  id: 'a$zfp',
  effectId: kAdlerAugeZauberId,
  zfpStern: zfp,
);

SpellEffectInstance _blitz(int zfp) => SpellEffectInstance(
  id: 'b$zfp',
  effectId: kBlitzZauberId,
  zfpStern: zfp,
  zfw: 10,
);

ResolvedProbeRequest _talent(String name) => buildTalentProbeRequest(
  title: name,
  targets: const [
    ProbeTargetValue(label: 'KL', value: 12),
    ProbeTargetValue(label: 'IN', value: 13),
    ProbeTargetValue(label: 'FF', value: 11),
  ],
  basePool: 8,
);

ResolvedProbeRequest _zauber() => buildSpellProbeRequest(
  title: 'Ignifaxius',
  targets: const [
    ProbeTargetValue(label: 'KL', value: 12),
    ProbeTargetValue(label: 'IN', value: 13),
    ProbeTargetValue(label: 'CH', value: 11),
  ],
  basePool: 9,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RulesCatalog katalog;

  setUpAll(() async {
    katalog = (await ladeEchtenRegelkatalog()).catalog;
  });

  SpellEffectBeitraege rechne(
    HeroState zustand, {
    bool blindkampf = false,
    bool konzentrationsstaerke = false,
  }) => berechneSpellEffectBeitraege(
    zustand: zustand,
    katalog: katalog,
    blindkampf: blindkampf,
    konzentrationsstaerke: konzentrationsstaerke,
  );

  test('das Adlerauge-Talent heißt im Katalog genau so', () {
    expect(
      katalog.talents.any((t) => t.name == kSinnenschaerfeTalentName),
      isTrue,
    );
  });

  group('Adlerauge', () {
    test('erleichtert Sinnesschärfe um ZfP*, kein anderes Talent', () {
      final b = rechne(_mit([_adler(5)]));

      final sinne = probeMitSpellEffekten(_talent('Sinnesschärfe'), b);
      final klettern = probeMitSpellEffekten(_talent('Klettern'), b);

      expect(sinne.initialSituationalModifier, 5);
      expect(sinne.ruleHint, contains('Adlerauge Luchsenohr +5'));
      expect(klettern.initialSituationalModifier, 0);
      expect(probeMitSpellEffekten(_zauber(), b).initialSituationalModifier, 0);
    });

    test('zählt nicht für Ersatzproben über ein anderes Talent', () {
      final b = rechne(_mit([_adler(5)]));
      final ersatz = buildTalentProbeRequest(
        title: 'Sinnesschärfe (über Menschenkenntnis −3)',
        targets: const [ProbeTargetValue(label: 'KL', value: 12)],
        basePool: 4,
      );

      expect(talentNameAusProbe(ersatz), isNull);
      expect(probeMitSpellEffekten(ersatz, b).initialSituationalModifier, 0);
    });

    test('mehrere Adlerauge: nur das stärkste zählt', () {
      final b = rechne(_mit([_adler(3), _adler(6), _adler(4)]));

      expect(
        probeMitSpellEffekten(
          _talent('Sinnesschärfe'),
          b,
        ).initialSituationalModifier,
        6,
      );
    });
  });

  group('Blitz', () {
    test('erschwert Talent- und Zauberproben um ZfP*', () {
      final b = rechne(_mit([_blitz(5)]));

      expect(
        probeMitSpellEffekten(
          _talent('Klettern'),
          b,
        ).initialSituationalModifier,
        -5,
      );
      expect(
        probeMitSpellEffekten(_zauber(), b).initialSituationalModifier,
        -5,
      );
      expect(b.hinweise.join(' '), contains('Fernkampfproben'));
    });

    test('Konzentrationsstärke: Zauberproben nicht gerechnet, Hinweis', () {
      final b = rechne(_mit([_blitz(5)]), konzentrationsstaerke: true);

      expect(probeMitSpellEffekten(_zauber(), b).initialSituationalModifier, 0);
      expect(
        probeMitSpellEffekten(
          _talent('Klettern'),
          b,
        ).initialSituationalModifier,
        -5,
      );
      expect(b.hinweise.join(' '), contains('Konzentrationsstärke'));
    });

    test('Blindkampf: gar keine Probenzahl, Hinweis', () {
      final b = rechne(_mit([_blitz(5)]), blindkampf: true);

      expect(b.probenBeitraege, isEmpty);
    });

    test(
      'Adlerauge und Blitz heben sich auf Sinnesschärfe nicht gegenseitig',
      () {
        final b = rechne(_mit([_adler(5), _blitz(3)]));

        expect(
          probeMitSpellEffekten(
            _talent('Sinnesschärfe'),
            b,
          ).initialSituationalModifier,
          5 - 3,
        );
      },
    );
  });

  test('andere Probenarten und leere Beiträge bleiben unberührt', () {
    final b = rechne(_mit([_blitz(5)]));
    final attribut = buildAttributeProbeRequest(
      label: 'MU',
      effectiveValue: 12,
    );

    expect(identical(probeMitSpellEffekten(attribut, b), attribut), isTrue);
    final talent = _talent('Klettern');
    expect(
      identical(
        probeMitSpellEffekten(talent, const SpellEffectBeitraege()),
        talent,
      ),
      isTrue,
    );
  });

  test('Titel ohne Talentform liefern keinen Talentnamen', () {
    expect(talentNameAusProbe(_zauber()), isNull);
    expect(talentNameAusProbe(_talent('Klettern')), 'Klettern');
  });

  group('Seidenzunge', () {
    test('das Talent heißt im Katalog genau so', () {
      expect(
        katalog.talents.any((t) => t.name == kUeberredenTalentName),
        isTrue,
      );
    });

    test('erleichtert Überreden um ZfP* als Startwert, sonst nichts', () {
      final b = rechne(
        _mit([
          const SpellEffectInstance(
            id: 's',
            effectId: kSeidenzungeZauberId,
            zfpStern: 4,
          ),
        ]),
      );

      final ueberreden = probeMitSpellEffekten(_talent('Überreden'), b);
      expect(ueberreden.initialSituationalModifier, 4);
      expect(ueberreden.ruleHint, contains('Seidenzunge Elfenwort +4'));
      expect(
        probeMitSpellEffekten(
          _talent('Klettern'),
          b,
        ).initialSituationalModifier,
        0,
      );
      expect(b.hinweise.join(' '), contains('Meisterentscheid'));
    });
  });
}
