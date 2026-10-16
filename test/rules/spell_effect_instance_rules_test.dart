import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/spell_duration.dart';
import 'package:dsa_heldenverwaltung/domain/spell_effect_instance.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_state_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_instance_rules.dart';

import '../test_support/real_catalog.dart';

HeroState _zustand() => const HeroState(
  currentLep: 20,
  currentAsp: 15,
  currentKap: 4,
  currentAu: 18,
);

SpellEffectInstance _attributo(String id, AttributeModifiers boni) {
  return SpellEffectInstance(
    id: id,
    effectId: activeSpellEffectAttributo,
    vorgangsId: 'v-$id',
    attributeMods: boni,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('zwei Quellen für dieselbe Eigenschaft: nur die bessere zählt', () {
    var zustand = const HeroState(
      currentLep: 20,
      currentAsp: 15,
      currentKap: 4,
      currentAu: 18,
    );
    zustand = aktiviereEffektInstanz(
      zustand,
      _attributo('a', const AttributeModifiers(mu: 2)),
    );
    zustand = aktiviereEffektInstanz(
      zustand,
      _attributo('b', const AttributeModifiers(mu: 1, kk: 3)),
    );

    final summe = effektiveTempAttributeMods(zustand);

    expect(zustand.activeSpellEffects.instanzen, hasLength(2));
    // MU: 2 und 1 → nur 2. KK wird nur von der zweiten Quelle verbessert.
    expect(summe.mu, 2);
    expect(summe.kk, 3);
  });

  test('verschiedene Eigenschaften behalten alle Boni', () {
    var zustand = _zustand();
    zustand = aktiviereEffektInstanz(
      zustand,
      _attributo('a', const AttributeModifiers(mu: 2)),
    );
    zustand = aktiviereEffektInstanz(
      zustand,
      _attributo('b', const AttributeModifiers(kl: 3)),
    );

    final summe = effektiveTempAttributeMods(zustand);

    expect(summe.mu, 2);
    expect(summe.kl, 3);
  });

  test('bei Gleichstand zählt die Eigenschaft nur einmal', () {
    var zustand = _zustand();
    zustand = aktiviereEffektInstanz(
      zustand,
      _attributo('a', const AttributeModifiers(mu: 2)),
    );
    zustand = aktiviereEffektInstanz(
      zustand,
      _attributo('b', const AttributeModifiers(mu: 2)),
    );

    expect(effektiveTempAttributeMods(zustand).mu, 2);
    expect(ueberlagerteEigenschaften(zustand, 'a'), isEmpty);
    expect(ueberlagerteEigenschaften(zustand, 'b'), <String>['MU']);
  });

  test('die überlagerte Quelle wird benannt; Ende der besseren gibt frei', () {
    var zustand = _zustand();
    zustand = aktiviereEffektInstanz(
      zustand,
      _attributo('a', const AttributeModifiers(mu: 1, kl: 2)),
    );
    zustand = aktiviereEffektInstanz(
      zustand,
      _attributo('b', const AttributeModifiers(mu: 3)),
    );

    expect(ueberlagerteEigenschaften(zustand, 'a'), <String>['MU']);
    expect(ueberlagerteEigenschaften(zustand, 'b'), isEmpty);
    expect(ueberlagerteEigenschaften(zustand, 'unbekannt'), isEmpty);

    final ohneB = beendeEffektInstanz(zustand, 'b');
    expect(effektiveTempAttributeMods(ohneB).mu, 1);
    expect(ueberlagerteEigenschaften(ohneB, 'a'), isEmpty);
  });

  test('unterdrückte Quelle nimmt nicht am Vergleich teil', () {
    var zustand = _zustand();
    zustand = aktiviereEffektInstanz(
      zustand,
      _attributo('a', const AttributeModifiers(mu: 1)),
    );
    zustand = aktiviereEffektInstanz(
      zustand,
      _attributo('b', const AttributeModifiers(mu: 3)),
    );

    final ohneB = unterdrueckeEffektInstanz(zustand, 'b', unterdrueckt: true);

    expect(effektiveTempAttributeMods(ohneB).mu, 1);
  });

  test('Ende von Quelle A entfernt nur A, manuelle Boni bleiben', () {
    var zustand = const HeroState(
      currentLep: 20,
      currentAsp: 15,
      currentKap: 4,
      currentAu: 18,
      tempAttributeMods: AttributeModifiers(ge: 4),
    );
    zustand = aktiviereEffektInstanz(
      zustand,
      _attributo('a', const AttributeModifiers(mu: 2)),
    );
    zustand = aktiviereEffektInstanz(
      zustand,
      _attributo('b', const AttributeModifiers(mu: 1)),
    );

    final nachher = beendeEffektInstanz(zustand, 'a');

    expect(nachher.activeSpellEffects.instanzen.single.id, 'b');
    final summe = effektiveTempAttributeMods(nachher);
    expect(summe.mu, 1);
    expect(summe.ge, 4);
    expect(nachher.tempAttributeMods.ge, 4);
  });

  test('Retry mit gleicher Vorgangs-ID legt keine zweite Instanz an', () {
    final erste = _attributo('a', const AttributeModifiers(mu: 2));
    final retry = erste.copyWith();
    final andereId = SpellEffectInstance(
      id: 'neu',
      effectId: activeSpellEffectAttributo,
      vorgangsId: 'v-a',
      attributeMods: const AttributeModifiers(mu: 2),
    );

    final einmal = aktiviereEffektInstanz(
      const HeroState(
        currentLep: 20,
        currentAsp: 15,
        currentKap: 4,
        currentAu: 18,
      ),
      erste,
    );
    final zweimal = aktiviereEffektInstanz(einmal, retry);
    final dritt = aktiviereEffektInstanz(zweimal, andereId);

    expect(identical(zweimal, einmal), isTrue);
    expect(identical(dritt, einmal), isTrue);
    expect(effektiveTempAttributeMods(dritt).mu, 2);
  });

  test('unterdrückte Instanz bleibt gespeichert, wirkt aber nicht', () {
    final zustand = aktiviereEffektInstanz(
      const HeroState(
        currentLep: 20,
        currentAsp: 15,
        currentKap: 4,
        currentAu: 18,
      ),
      _attributo('a', const AttributeModifiers(mu: 2)),
    );

    final unterdrueckt = unterdrueckeEffektInstanz(
      zustand,
      'a',
      unterdrueckt: true,
    );
    final wieder = unterdrueckeEffektInstanz(
      unterdrueckt,
      'a',
      unterdrueckt: false,
    );

    expect(unterdrueckt.activeSpellEffects.instanzen, hasLength(1));
    expect(effektiveTempAttributeMods(unterdrueckt).mu, 0);
    expect(effektiveTempAttributeMods(wieder).mu, 2);
  });

  test('Bearbeiten und Beenden unbekannter IDs ändern nichts', () {
    final zustand = aktiviereEffektInstanz(
      const HeroState(
        currentLep: 20,
        currentAsp: 15,
        currentKap: 4,
        currentAu: 18,
      ),
      _attributo('a', const AttributeModifiers(mu: 2)),
    );

    expect(identical(beendeEffektInstanz(zustand, 'x'), zustand), isTrue);
    expect(
      identical(
        bearbeiteEffektInstanz(zustand, 'x', (i) => i.copyWith(amount: 9)),
        zustand,
      ),
      isTrue,
    );
  });

  test('ohne Instanzen kommt tempAttributeMods unverändert zurück', () {
    const zustand = HeroState(
      currentLep: 20,
      currentAsp: 15,
      currentKap: 4,
      currentAu: 18,
      tempAttributeMods: AttributeModifiers(kl: 1),
    );

    expect(
      identical(effektiveTempAttributeMods(zustand), zustand.tempAttributeMods),
      isTrue,
    );
  });

  test('Legacy-IDs erscheinen als synthetische Instanzen ohne Boni', () {
    var zustand = aktiviereAttributo(
      const HeroState(
        currentLep: 20,
        currentAsp: 15,
        currentKap: 4,
        currentAu: 18,
      ),
      const AttributeModifiers(mu: 2),
    );
    zustand = aktiviereEffektInstanz(
      zustand,
      _attributo('a', const AttributeModifiers(mu: 1)),
    );

    final alle = aktiveEffektInstanzen(zustand);

    expect(alle.map((i) => i.id), <String>[
      '${legacyInstanzPraefix}effect_spell_attributo',
      'a',
    ]);
    expect(istLegacyInstanz(alle.first.id), isTrue);
    expect(alle.first.attributeMods.mu, 0);
    // Legacy-Attributo (MU+2) und Instanz (MU+1) konkurrieren: es zählt MU+2,
    // der Legacy-Bonus liegt dabei nur einmal in tempAttributeMods.
    expect(effektiveTempAttributeMods(zustand).mu, 2);
    expect(ueberlagerteEigenschaften(zustand, 'a'), <String>['MU']);
  });

  test('Attributo aus kann die Boni behalten', () {
    final an = aktiviereAttributo(
      const HeroState(
        currentLep: 20,
        currentAsp: 15,
        currentKap: 4,
        currentAu: 18,
      ),
      const AttributeModifiers(mu: 2),
    );

    final aus = schalteZaubereffekt(
      an,
      activeSpellEffectAttributo,
      aktiv: false,
      attributoBoniBehalten: true,
    );

    expect(
      aus.activeSpellEffects.isActive(activeSpellEffectAttributo),
      isFalse,
    );
    expect(aus.tempAttributeMods.mu, 2);
  });

  test('Legacy-Attributo lässt sich bewusst als Instanz übernehmen', () {
    final dauer = SpellDuration(amount: 3, unit: SpellDurationUnit.kampfrunden);
    final an = aktiviereAttributo(
      const HeroState(
        currentLep: 20,
        currentAsp: 15,
        currentKap: 4,
        currentAu: 18,
      ),
      const AttributeModifiers(kk: 2),
    );
    final mitDauer = setzeZaubereffektDauer(
      an,
      activeSpellEffectAttributo,
      dauer,
    );

    final nachher = uebernimmLegacyAttributoAlsInstanz(mitDauer, 'neu');
    final nochmal = uebernimmLegacyAttributoAlsInstanz(nachher, 'neu2');

    final instanz = nachher.activeSpellEffects.instanzFor('neu')!;
    expect(instanz.attributeMods.kk, 2);
    expect(instanz.duration?.amount, 3);
    expect(nachher.tempAttributeMods.kk, 0);
    expect(
      nachher.activeSpellEffects.isActive(activeSpellEffectAttributo),
      isFalse,
    );
    expect(effektiveTempAttributeMods(nachher).kk, 2);
    // Zweiter Aufruf: Das Legacy-Flag ist weg, nichts passiert.
    expect(identical(nochmal, nachher), isTrue);
  });

  test('Dauer einer Instanz zählt ab dem gespeicherten Wert', () {
    final dauer = SpellDuration(amount: 3, unit: SpellDurationUnit.kampfrunden);
    var zustand = aktiviereEffektInstanz(
      const HeroState(
        currentLep: 20,
        currentAsp: 15,
        currentKap: 4,
        currentAu: 18,
      ),
      _attributo(
        'a',
        const AttributeModifiers(mu: 1),
      ).copyWith(duration: dauer),
    );

    zustand = zaehleEffektInstanzDauer(zustand, 'a', zuruecksetzen: false);
    zustand = zaehleEffektInstanzDauer(zustand, 'a', zuruecksetzen: false);

    expect(zustand.activeSpellEffects.instanzFor('a')!.duration?.remaining, 1);
    final zurueck = zaehleEffektInstanzDauer(zustand, 'a', zuruecksetzen: true);
    expect(zurueck.activeSpellEffects.instanzFor('a')!.duration?.remaining, 3);
  });

  test('manuelle Boni ohne Legacy-Attributo kommen zusätzlich dazu', () {
    var zustand = const HeroState(
      currentLep: 20,
      currentAsp: 15,
      currentKap: 4,
      currentAu: 18,
      tempAttributeMods: AttributeModifiers(mu: 1),
    );
    zustand = aktiviereEffektInstanz(
      zustand,
      _attributo('a', const AttributeModifiers(mu: 2)),
    );

    // Manuell eingetragene Werte entscheidet der Tisch; die App rechnet sie
    // nicht gegen die Zauberquelle.
    expect(effektiveTempAttributeMods(zustand).mu, 3);
  });

  group('Aufrechterhaltung (Katalog „(A)“)', () {
    late RulesCatalog katalog;

    setUpAll(() async {
      katalog = (await ladeEchtenRegelkatalog()).catalog;
    });

    test('Armatrutz und Axxeleratus tragen (A), Attributo nicht', () {
      expect(
        effektVerlangtAufrechterhaltung(activeSpellEffectArmatrutz, katalog),
        isTrue,
      );
      expect(
        effektVerlangtAufrechterhaltung(activeSpellEffectAxxeleratus, katalog),
        isTrue,
      );
      expect(
        effektVerlangtAufrechterhaltung(activeSpellEffectAttributo, katalog),
        isFalse,
      );
    });

    test('ohne Katalog oder unbekannte ID wird nichts geraten', () {
      expect(
        effektVerlangtAufrechterhaltung(activeSpellEffectArmatrutz, null),
        isFalse,
      );
      expect(
        effektVerlangtAufrechterhaltung('gibt_es_nicht', katalog),
        isFalse,
      );
    });

    test('jede Quelle zählt einzeln, unterdrückte und Attributo nicht', () {
      var zustand = aktiviereArmatrutz(
        _zustand(),
        const ActiveSpellEffectDetail(amount: 3),
      );
      zustand = aktiviereAttributo(zustand, const AttributeModifiers(mu: 1));
      zustand = aktiviereEffektInstanz(
        zustand,
        SpellEffectInstance(
          id: 'r2',
          effectId: activeSpellEffectArmatrutz,
          vorgangsId: 'v-r2',
          amount: 2,
        ),
      );

      expect(aufrechterhaltungsBefund(zustand, katalog).anzahl, 2);

      final ohneZweiten = unterdrueckeEffektInstanz(
        zustand,
        'r2',
        unterdrueckt: true,
      );
      expect(aufrechterhaltungsBefund(ohneZweiten, katalog).anzahl, 1);
      expect(aufrechterhaltungsBefund(zustand, null).anzahl, 0);
    });
  });
}
