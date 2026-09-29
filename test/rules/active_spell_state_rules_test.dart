import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/domain/spell_duration.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_state_rules.dart';

final _wurf = DiceLogEntry(
  timestamp: DateTime.utc(2026, 9, 29),
  type: ProbeType.attribute,
  title: 'Eigenschaftsprobe: MU',
  subtitle: 'MU 12',
  success: true,
  diceValues: const <int>[3],
);

/// Zustand mit Feldern, die keine Zaubereffekt-Änderung anfassen darf.
HeroState _grundzustand() {
  return const HeroState(
    currentLep: 20,
    currentAsp: 15,
    currentKap: 4,
    currentAu: 18,
    wpiZustand: WundZustand(wundenProZone: <WundZone, int>{WundZone.bauch: 1}),
  ).withAppendedDiceLogEntries(<DiceLogEntry>[_wurf]);
}

/// Prüft, dass außer den Zaubereffekten und Attributo-Boni alles blieb.
void _expectUebrigesUnveraendert(HeroState vorher, HeroState nachher) {
  final ohneEffekte = nachher.copyWith(
    activeSpellEffects: vorher.activeSpellEffects,
    tempAttributeMods: vorher.tempAttributeMods,
  );
  expect(ohneEffekte.toJson(), vorher.toJson());
}

final _dauer = SpellDuration(amount: 4, unit: SpellDurationUnit.kampfrunden);

void main() {
  group('schalteZaubereffekt', () {
    test('schaltet einen Effekt ein und wieder aus', () {
      final vorher = _grundzustand();

      final an = schalteZaubereffekt(
        vorher,
        activeSpellEffectAxxeleratus,
        aktiv: true,
      );
      final aus = schalteZaubereffekt(
        an,
        activeSpellEffectAxxeleratus,
        aktiv: false,
      );

      expect(
        an.activeSpellEffects.isActive(activeSpellEffectAxxeleratus),
        isTrue,
      );
      expect(
        aus.activeSpellEffects.isActive(activeSpellEffectAxxeleratus),
        isFalse,
      );
      _expectUebrigesUnveraendert(vorher, an);
      _expectUebrigesUnveraendert(vorher, aus);
    });

    test('Attributo aus nimmt seine Boni zurück, andere Effekte nicht', () {
      final mitAttributo = aktiviereAttributo(
        _grundzustand(),
        const AttributeModifiers(mu: 2),
      );

      final aus = schalteZaubereffekt(
        mitAttributo,
        activeSpellEffectAttributo,
        aktiv: false,
      );
      final andererAus = schalteZaubereffekt(
        mitAttributo,
        activeSpellEffectAxxeleratus,
        aktiv: false,
      );

      expect(aus.tempAttributeMods.mu, 0);
      expect(
        aus.activeSpellEffects.isActive(activeSpellEffectAttributo),
        isFalse,
      );
      expect(andererAus.tempAttributeMods.mu, 2);
    });
  });

  test('aktiviereAttributo setzt Boni und Effekt', () {
    final vorher = _grundzustand();

    final nachher = aktiviereAttributo(vorher, const AttributeModifiers(kk: 3));

    expect(nachher.tempAttributeMods.kk, 3);
    expect(
      nachher.activeSpellEffects.isActive(activeSpellEffectAttributo),
      isTrue,
    );
    _expectUebrigesUnveraendert(vorher, nachher);
  });

  test('aktiviereArmatrutz setzt Effekt und Zusatzdaten gemeinsam', () {
    final vorher = _grundzustand();

    final nachher = aktiviereArmatrutz(
      vorher,
      ActiveSpellEffectDetail(amount: 3, duration: _dauer),
    );

    final detail = nachher.activeSpellEffects.detailFor(
      activeSpellEffectArmatrutz,
    );
    expect(
      nachher.activeSpellEffects.isActive(activeSpellEffectArmatrutz),
      isTrue,
    );
    expect(detail.amount, 3);
    expect(detail.duration?.remaining, 4);
    _expectUebrigesUnveraendert(vorher, nachher);
  });

  group('Wirkungsdauer', () {
    HeroState mitArmatrutz() => aktiviereArmatrutz(
      _grundzustand(),
      ActiveSpellEffectDetail(amount: 3, duration: _dauer),
    );

    test('setzen behält die übrigen Zusatzdaten des gespeicherten Stands', () {
      final neu = SpellDuration(amount: 2, unit: SpellDurationUnit.spielrunden);

      final nachher = setzeZaubereffektDauer(
        mitArmatrutz(),
        activeSpellEffectArmatrutz,
        neu,
      );

      final detail = nachher.activeSpellEffects.detailFor(
        activeSpellEffectArmatrutz,
      );
      expect(detail.amount, 3);
      expect(detail.duration?.unit, SpellDurationUnit.spielrunden);
    });

    test('null entfernt nur die Dauer', () {
      final nachher = setzeZaubereffektDauer(
        mitArmatrutz(),
        activeSpellEffectArmatrutz,
        null,
      );

      final detail = nachher.activeSpellEffects.detailFor(
        activeSpellEffectArmatrutz,
      );
      expect(detail.duration, isNull);
      expect(detail.amount, 3);
    });

    test('zählen geht vom übergebenen Stand aus und ist wiederholbar', () {
      final einmal = zaehleZaubereffektDauer(
        mitArmatrutz(),
        activeSpellEffectArmatrutz,
        zuruecksetzen: false,
      );
      final zweimal = zaehleZaubereffektDauer(
        einmal,
        activeSpellEffectArmatrutz,
        zuruecksetzen: false,
      );
      final zurueck = zaehleZaubereffektDauer(
        zweimal,
        activeSpellEffectArmatrutz,
        zuruecksetzen: true,
      );

      int? rest(HeroState zustand) => zustand.activeSpellEffects
          .detailFor(activeSpellEffectArmatrutz)
          .duration
          ?.remaining;
      expect(rest(einmal), 3);
      expect(rest(zweimal), 2);
      expect(rest(zurueck), 4);
      _expectUebrigesUnveraendert(mitArmatrutz(), zweimal);
    });

    test('ohne Wirkungsdauer bleibt der Zustand unverändert', () {
      final vorher = schalteZaubereffekt(
        _grundzustand(),
        activeSpellEffectAxxeleratus,
        aktiv: true,
      );

      final nachher = zaehleZaubereffektDauer(
        vorher,
        activeSpellEffectAxxeleratus,
        zuruecksetzen: false,
      );

      expect(identical(nachher, vorher), isTrue);
    });
  });
}
