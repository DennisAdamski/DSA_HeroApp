import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/alchimikum_bezug.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/spell_duration.dart';
import 'package:dsa_heldenverwaltung/domain/spell_effect_instance.dart';
import 'package:dsa_heldenverwaltung/rules/derived/alchimika_elixier_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/alchimika_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_state_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_instance_rules.dart';

import '../test_support/real_catalog.dart';

const _mut = AlchimikumDef(
  id: 'alch_mutelixier',
  name: 'Mutelixier',
  qualitaeten: <AlchimikumQualitaet>[
    AlchimikumQualitaet(
      stufe: 'A',
      wirkung: 'Unbedacht.',
      eigenschaften: <AlchimikumEigenschaft>[
        AlchimikumEigenschaft(
          eigenschaft: 'MU',
          wert: 1,
          dauer: 1,
          einheit: 'spielrunden',
        ),
        AlchimikumEigenschaft(
          eigenschaft: 'IN',
          wert: -1,
          dauer: 1,
          einheit: 'stunden',
        ),
      ],
    ),
    AlchimikumQualitaet(
      stufe: 'E',
      eigenschaften: <AlchimikumEigenschaft>[
        AlchimikumEigenschaft(
          eigenschaft: 'MU',
          wert: 3,
          dauer: 1,
          einheit: 'tage',
        ),
      ],
    ),
  ],
);

const _katalog = RulesCatalog(
  version: 'test_catalog',
  source: 'test',
  talents: <TalentDef>[],
  spells: <SpellDef>[],
  weapons: <WeaponDef>[],
  alchimika: <AlchimikumDef>[_mut],
);

const _leer = HeroState(
  currentLep: 20,
  currentAsp: 0,
  currentKap: 0,
  currentAu: 20,
);

int _zaehler = 0;
String _id() => 'i${_zaehler++}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('elixierInstanzen', () {
    test('legt je Eigenschaftsänderung eine Quelle mit eigener Dauer an', () {
      final instanzen = elixierInstanzen(
        mittel: _mut,
        stufe: 'A',
        vorgangsId: 'v1',
        neueId: _id,
      );
      expect(instanzen, hasLength(2));
      expect(instanzen[0].effectId, 'alch_mutelixier');
      expect(instanzen[0].attributeMods.mu, 1);
      expect(instanzen[0].duration?.amount, 1);
      expect(instanzen[0].duration?.unit, SpellDurationUnit.spielrunden);
      expect(instanzen[0].quelle, 'Qualität A');
      expect(instanzen[1].attributeMods.inn, -1);
      expect(instanzen[1].duration?.unit, SpellDurationUnit.stunden);
      expect(instanzen[0].vorgangsId, 'v1#0');
      expect(instanzen[1].vorgangsId, 'v1#1');
      expect(instanzen[0].id, isNot(instanzen[1].id));
    });

    test('unbekannte Stufe liefert nichts', () {
      expect(
        elixierInstanzen(
          mittel: _mut,
          stufe: 'D',
          vorgangsId: 'v',
          neueId: _id,
        ),
        isEmpty,
      );
    });

    test('unbekanntes Kürzel und unbekannte Einheit raten nichts', () {
      const komisch = AlchimikumDef(
        id: 'alch_x',
        name: 'X',
        qualitaeten: <AlchimikumQualitaet>[
          AlchimikumQualitaet(
            stufe: 'A',
            eigenschaften: <AlchimikumEigenschaft>[
              AlchimikumEigenschaft(
                eigenschaft: 'XX',
                wert: 1,
                dauer: 1,
                einheit: 'tage',
              ),
              AlchimikumEigenschaft(
                eigenschaft: 'KK',
                wert: 2,
                dauer: 3,
                einheit: 'jahre',
              ),
            ],
          ),
        ],
      );
      final instanzen = elixierInstanzen(
        mittel: komisch,
        stufe: 'A',
        vorgangsId: 'v',
        neueId: _id,
      );
      expect(instanzen, hasLength(1));
      expect(instanzen.single.attributeMods.kk, 2);
      expect(instanzen.single.duration, isNull);
    });
  });

  group('Wirkung auf die Eigenschaften', () {
    HeroState eingenommen(String stufe, {String vorgang = 'v'}) =>
        nimmElixierEin(
          _leer,
          elixierInstanzen(
            mittel: _mut,
            stufe: stufe,
            vorgangsId: vorgang,
            neueId: _id,
          ),
        );

    test(
      'wirkt über effektiveTempAttributeMods, nicht über tempAttributeMods',
      () {
        final zustand = eingenommen('A');
        expect(zustand.tempAttributeMods.mu, 0);
        final boni = effektiveTempAttributeMods(zustand);
        expect(boni.mu, 1);
        expect(boni.inn, -1);
      },
    );

    test('Elixiere addieren sich, auch mit Attributo und manuellen Boni', () {
      var zustand = eingenommen('E', vorgang: 'a');
      zustand = nimmElixierEin(
        zustand,
        elixierInstanzen(
          mittel: _mut,
          stufe: 'E',
          vorgangsId: 'b',
          neueId: _id,
        ),
      );
      expect(effektiveTempAttributeMods(zustand).mu, 6);
      zustand = zustand.copyWith(
        tempAttributeMods: const AttributeModifiers(mu: 2),
      );
      expect(effektiveTempAttributeMods(zustand).mu, 8);
    });

    test('Unterdrückte und beendete Quellen zählen nicht', () {
      var zustand = eingenommen('A');
      final erste = zustand.activeSpellEffects.instanzen.first;
      zustand = unterdrueckeEffektInstanz(
        zustand,
        erste.id,
        unterdrueckt: true,
      );
      expect(effektiveTempAttributeMods(zustand).mu, 0);
      expect(effektiveTempAttributeMods(zustand).inn, -1);
      zustand = beendeEffektInstanz(
        zustand,
        zustand.activeSpellEffects.instanzen.last.id,
      );
      expect(effektiveTempAttributeMods(zustand).inn, 0);
    });

    test('dieselbe Vorgangs-ID legt nichts doppelt an', () {
      final einmal = eingenommen('A');
      final zweimal = nimmElixierEin(
        einmal,
        elixierInstanzen(
          mittel: _mut,
          stufe: 'A',
          vorgangsId: 'v',
          neueId: _id,
        ),
      );
      expect(zweimal.activeSpellEffects.instanzen, hasLength(2));
      expect(elixierBereitsEingenommen(einmal, 'v'), isTrue);
      expect(elixierBereitsEingenommen(einmal, 'w'), isFalse);
    });

    test('der Name der Quelle stammt aus dem Katalog', () {
      expect(effektName('alch_mutelixier', _katalog), 'Mutelixier');
      expect(
        beschreibeEffektInstanz(
          const SpellEffectInstance(
            id: 'x',
            effectId: 'alch_mutelixier',
            attributeMods: AttributeModifiers(mu: 3),
          ),
        ),
        contains('MU'),
      );
    });
  });

  group('Katalogverweis am Eintrag', () {
    test('mitAlchimikum merkt Mittel und Stufe', () {
      final eintrag = mitAlchimikum(const HeroInventoryEntry(), _mut, 'E');
      expect(eintrag.alchimikum?.id, 'alch_mutelixier');
      expect(eintrag.alchimikum?.stufe, 'E');
      expect(hatElixierWirkung(_katalog, eintrag), isTrue);
      expect(elixierEigenschaften(_katalog, eintrag).single.wert, 3);
    });

    test('ohne Katalog, Verweis oder Wirkung gibt es kein Einnehmen', () {
      final eintrag = mitAlchimikum(const HeroInventoryEntry(), _mut, 'E');
      expect(hatElixierWirkung(null, eintrag), isFalse);
      expect(hatElixierWirkung(_katalog, const HeroInventoryEntry()), isFalse);
      expect(
        hatElixierWirkung(
          _katalog,
          eintrag.copyWith(alchimikum: const AlchimikumBezug(id: 'alch_x')),
        ),
        isFalse,
      );
      expect(
        hatElixierWirkung(
          _katalog,
          eintrag.copyWith(
            alchimikum: const AlchimikumBezug(
              id: 'alch_mutelixier',
              stufe: 'B',
            ),
          ),
        ),
        isFalse,
      );
    });
  });

  group('Echter Katalog', () {
    test(
      'Mutelixier D wirkt wie im Regelwerk: MU +7 für 7 Spielrunden',
      () async {
        final echt = await ladeEchtenRegelkatalog();
        final mut = echt.catalog.alchimika.firstWhere(
          (m) => m.id == 'alch_mutelixier',
        );
        final instanzen = elixierInstanzen(
          mittel: mut,
          stufe: 'D',
          vorgangsId: 'v',
          neueId: _id,
        );
        expect(instanzen.single.attributeMods.mu, 7);
        expect(instanzen.single.duration?.amount, 7);
        expect(instanzen.single.duration?.unit, SpellDurationUnit.spielrunden);
      },
    );

    test(
      'Fingerfertigkeitselixier E trägt Bonus und Malus mit eigener Dauer',
      () async {
        final echt = await ladeEchtenRegelkatalog();
        final ff = echt.catalog.alchimika.firstWhere(
          (m) => m.id == 'alch_fingerfertigkeitselixier',
        );
        final instanzen = elixierInstanzen(
          mittel: ff,
          stufe: 'E',
          vorgangsId: 'v',
          neueId: _id,
        );
        expect(instanzen, hasLength(2));
        expect(instanzen[0].attributeMods.ff, 15);
        expect(instanzen[0].duration?.amount, 1);
        expect(instanzen[1].attributeMods.kk, -7);
        expect(instanzen[1].duration?.amount, 3);
      },
    );
  });
}
