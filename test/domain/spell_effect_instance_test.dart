import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/spell_effect_instance.dart';

void main() {
  const instanz = SpellEffectInstance(
    id: 'i1',
    effectId: 'effect_spell_attributo',
    vorgangsId: 'v1',
    quelle: 'Alrik',
    zfw: 12,
    zfpStern: 6,
    attributeMods: AttributeModifiers(mu: 2),
  );

  test('Instanz übersteht JSON-Roundtrip samt unbekannter Felder', () {
    final json = instanz.toJson()..['zukunft'] = <String, Object?>{'a': 1};

    final geladen = SpellEffectInstance.fromJson(json)!;

    expect(geladen.unbekannteFelder, <String, Object?>{
      'zukunft': <String, Object?>{'a': 1},
    });
    expect(geladen.toJson(), json);
    expect(geladen.attributeMods.mu, 2);
    expect(geladen.copyWith(unterdrueckt: true).unbekannteFelder, isNotEmpty);
  });

  test('Instanz ohne id oder effectId wird nicht verstanden', () {
    expect(SpellEffectInstance.fromJson(<String, dynamic>{'id': 'x'}), isNull);
    expect(
      SpellEffectInstance.fromJson(<String, dynamic>{'effectId': 'x'}),
      isNull,
    );
  });

  test('Altdaten ohne instanzen: JSON bleibt gleich', () {
    final alt = <String, dynamic>{
      'activeEffectIds': <Object?>['effect_spell_attributo'],
      'effectDetails': <String, dynamic>{},
    };

    final neu = ActiveSpellEffectsState.fromJson(alt);

    expect(neu.instanzen, isEmpty);
    expect(neu.toJson(), alt);
    expect(
      const HeroState(
        currentLep: 20,
        currentAsp: 15,
        currentKap: 4,
        currentAu: 18,
      ).toJson()['activeSpellEffects'],
      <String, dynamic>{
        'activeEffectIds': <Object?>[],
        'effectDetails': <String, dynamic>{},
      },
    );
  });

  test('Zustand schreibt Instanzen und liest sie wieder', () {
    final zustand = const ActiveSpellEffectsState().copyWith(
      instanzen: const [instanz],
    );

    final json = zustand.toJson();
    final geladen = ActiveSpellEffectsState.fromJson(json);

    expect(json['instanzen'], hasLength(1));
    expect(geladen.instanzen.single, instanz);
    expect(geladen.instanzFor('i1'), instanz);
    expect(geladen.instanzFor('nope'), isNull);
  });

  test('Nicht verstandene Einträge bleiben roh erhalten', () {
    final roh = <String, dynamic>{
      'instanzen': <Object?>[
        instanz.toJson(),
        <String, Object?>{'effectId': 'ohne_id', 'x': 1},
        'komisch',
      ],
    };

    final zustand = ActiveSpellEffectsState.fromJson(roh);
    final geaendert = zustand.withToggled('e1', true);

    expect(zustand.instanzen, hasLength(1));
    expect(zustand.unverstandeneInstanzen, hasLength(2));
    expect(geaendert.toJson()['instanzen'], roh['instanzen']);
  });

  test('doppelte Instanz-IDs werden zusammengeführt', () {
    final zustand = const ActiveSpellEffectsState().copyWith(
      instanzen: [
        instanz,
        instanz.copyWith(quelle: 'Zweiter'),
      ],
    );

    expect(zustand.instanzen.single.quelle, 'Alrik');
  });

  test('Schutzvorrat: nur bei Belegung im JSON, übersteht den Roundtrip', () {
    const ohne = SpellEffectInstance(id: 's', effectId: 'e', amount: 12);
    expect(ohne.toJson().containsKey('schutzRest'), isFalse);

    final mit = ohne.copyWith(schutzRest: 0);
    expect(mit.toJson()['schutzRest'], 0);
    expect(SpellEffectInstance.fromJson(mit.toJson())!.schutzRest, 0);
    expect(SpellEffectInstance.fromJson(mit.toJson()), mit);
    expect(mit == ohne, isFalse);
  });
}
