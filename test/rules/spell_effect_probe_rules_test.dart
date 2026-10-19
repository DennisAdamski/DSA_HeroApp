import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/domain/spell_effect_instance.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_state_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_request_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_probe_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/talent_herleitung_rules.dart';

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

/// Talentprobe mit Pool-Herleitung: TaW [taw], eigener Modifikator +1, eBE −2.
ResolvedProbeRequest _talentMitTaw(String name, {required int taw}) {
  final herleitung = Herleitung(
    bezeichnung: 'TaW*',
    schritte: <HerleitungsSchritt>[
      HerleitungsSchritt(
        bezeichnung: kTalentTawSchritt,
        betrag: taw,
        art: HerleitungsArt.zukauf,
      ),
      const HerleitungsSchritt(
        bezeichnung: 'Eigener Modifikator',
        betrag: 1,
        art: HerleitungsArt.modifikator,
      ),
      const HerleitungsSchritt(
        bezeichnung: kTalentEbeSchritt,
        betrag: -2,
        art: HerleitungsArt.modifikator,
      ),
    ],
  );
  return buildTalentProbeRequest(
    title: name,
    targets: const [
      ProbeTargetValue(label: 'MU', value: 12),
      ProbeTargetValue(label: 'GE', value: 13),
      ProbeTargetValue(label: 'KK', value: 11),
    ],
    basePool: herleitung.wert,
    tawHerleitung: herleitung,
  );
}

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

  group('Axxeleratus: Athletik-TaW für Sprint/Sprung', () {
    SpellEffectBeitraege axx(HeroState zustand) => berechneSpellEffectBeitraege(
      zustand: zustand,
      katalog: katalog,
      axxeleratus: true,
    );

    test('Athletik bekommt einen bedingten Schritt, der Pool bleibt', () {
      final probe = probeMitSpellEffekten(
        _talentMitTaw('Athletik', taw: 7),
        axx(_mit(const [])),
      );

      expect(probe.basePool, 6);
      expect(probe.initialSituationalModifier, 0);
      final schritt = probe.bedingterPoolSchritt!;
      expect(schritt.betrag, 7);
      expect(schritt.bedingung, kAxxeleratusAthletikBedingung);
      expect(schritt.art, HerleitungsArt.zauber);
      expect(probe.ruleHint, contains('Athletik-TaW verdoppelt'));
    });

    test('angewendet: Pool und Herleitung steigen um den TaW', () {
      final probe = wendeBedingtenPoolSchrittAn(
        probeMitSpellEffekten(
          _talentMitTaw('Athletik', taw: 7),
          axx(_mit(const [])),
        ),
      );

      expect(probe.basePool, 13);
      expect(probe.poolHerleitung!.wert, probe.basePool);
      expect(probe.bedingterPoolSchritt, isNull);
      // Nur der gesteigerte TaW zählt doppelt, Modifikator und eBE einmal.
      expect(
        probe.poolHerleitung!.schritte
            .where((s) => s.bezeichnung == kTalentEbeSchritt)
            .single
            .betrag,
        -2,
      );
    });

    test('kein Schritt für andere Talente, Ersatzproben und TaW ≤ 0', () {
      final b = axx(_mit(const []));
      expect(
        probeMitSpellEffekten(
          _talentMitTaw('Klettern', taw: 7),
          b,
        ).bedingterPoolSchritt,
        isNull,
      );
      expect(
        probeMitSpellEffekten(
          _talentMitTaw('Athletik (über Akrobatik)', taw: 7),
          b,
        ).bedingterPoolSchritt,
        isNull,
      );
      expect(
        probeMitSpellEffekten(
          _talentMitTaw('Athletik', taw: 0),
          b,
        ).bedingterPoolSchritt,
        isNull,
      );
      // Ohne Pool-Herleitung ist der TaW unbekannt.
      expect(
        probeMitSpellEffekten(_talent('Athletik'), b).bedingterPoolSchritt,
        isNull,
      );
    });

    test('ohne Axxeleratus kein Schritt', () {
      expect(
        probeMitSpellEffekten(
          _talentMitTaw('Athletik', taw: 7),
          rechne(_mit(const [])),
        ).bedingterPoolSchritt,
        isNull,
      );
    });

    test('mit Blitz: Startwert und bedingter Schritt zusammen', () {
      final probe = probeMitSpellEffekten(
        _talentMitTaw('Athletik', taw: 7),
        axx(_mit([_blitz(4)])),
      );

      expect(probe.initialSituationalModifier, -4);
      expect(probe.bedingterPoolSchritt!.betrag, 7);
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
      // Fernkampf geht in den FK-Wert der Waffe, nicht in einen Hinweis.
      expect(b.fernkampfMalus, -5);
      expect(b.fernkampfQuelle, isNotNull);
      expect(b.hinweise.join(' '), isNot(contains('Fernkampfproben')));
    });

    test('Konzentrationsstärke halbiert nur die Zauberproben (aufgerundet)', () {
      final b = rechne(_mit([_blitz(5)]), konzentrationsstaerke: true);

      expect(
        probeMitSpellEffekten(_zauber(), b).initialSituationalModifier,
        -3,
      );
      expect(b.fernkampfMalus, -5);
      expect(
        probeMitSpellEffekten(
          _talent('Klettern'),
          b,
        ).initialSituationalModifier,
        -5,
      );
      expect(b.hinweise.join(' '), contains('Konzentrationsstärke'));
    });

    test('Blindkampf halbiert Talent- und Zauberproben (aufgerundet)', () {
      final b = rechne(_mit([_blitz(5)]), blindkampf: true);

      expect(
        probeMitSpellEffekten(
          _talent('Klettern'),
          b,
        ).initialSituationalModifier,
        -3,
      );
      expect(
        probeMitSpellEffekten(_zauber(), b).initialSituationalModifier,
        -3,
      );
    });

    test('Blindkampf und Konzentrationsstärke halbieren nur einmal', () {
      final b = rechne(
        _mit([_blitz(5)]),
        blindkampf: true,
        konzentrationsstaerke: true,
      );

      expect(
        probeMitSpellEffekten(_zauber(), b).initialSituationalModifier,
        -3,
      );
      expect(b.hinweise.join(' '), contains('nicht ein zweites Mal'));
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
