import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart' show ArmorPiece;
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';

void main() {
  group('HeroCompanionSpeed', () {
    test('Roundtrip mit allen Feldern', () {
      const speed = HeroCompanionSpeed(art: 'zu Fuß', wert: 12);
      final json = speed.toJson();
      final restored = HeroCompanionSpeed.fromJson(json);
      expect(restored, equals(speed));
    });

    test('Roundtrip mit Standardwerten', () {
      const speed = HeroCompanionSpeed();
      final json = speed.toJson();
      final restored = HeroCompanionSpeed.fromJson(json);
      expect(restored, equals(speed));
    });

    test('fromJson toleriert fehlende Felder', () {
      final speed = HeroCompanionSpeed.fromJson(const {});
      expect(speed.art, '');
      expect(speed.wert, 0);
    });

    test('copyWith ersetzt nur angegebene Felder', () {
      const speed = HeroCompanionSpeed(art: 'Fliegen', wert: 8);
      final updated = speed.copyWith(wert: 10);
      expect(updated.art, 'Fliegen');
      expect(updated.wert, 10);
    });
  });

  group('HeroCompanion', () {
    test('Roundtrip mit allen Feldern', () {
      final companion = HeroCompanion(
        id: 'test-uuid-123',
        name: 'Rabenkralle',
        familie: 'Rabe',
        aussehen: 'Schwarz wie die Nacht',
        gattung: 'Tier',
        gewicht: '~0,5 kg',
        groesse: '60 cm',
        alter: '3',
        mu: 12,
        kl: null,
        inn: 10,
        ch: null,
        ff: null,
        ge: 14,
        ko: 11,
        kk: null,
        ini: 8,
        magieresistenz: 2,
        loyalitaet: 9,
        apGesamt: 100,
        apAusgegeben: 50,
        geschwindigkeiten: const [
          HeroCompanionSpeed(art: 'zu Fuß', wert: 3),
          HeroCompanionSpeed(art: 'Fliegen', wert: 14),
        ],
        maxLep: 20,
        maxAup: 15,
        maxAsp: null,
        tragkraft: '5 kg',
        zugkraft: '',
        ausbildung: 'Botenvogel',
        futterbedarf: 'Getreide, Insekten',
        vorteile: 'Flink',
        nachteile: 'Scheu',
        gw: 5,
        au: 3,
      );

      final json = companion.toJson();
      final restored = HeroCompanion.fromJson(json);
      expect(restored, equals(companion));
    });

    test('Roundtrip mit Minimalstruktur (nur ID)', () {
      const companion = HeroCompanion(id: 'min-id');
      final json = companion.toJson();
      final restored = HeroCompanion.fromJson(json);
      expect(restored, equals(companion));
    });

    test('fromJson toleriert fehlende Felder', () {
      final companion = HeroCompanion.fromJson({'id': 'x'});
      expect(companion.id, 'x');
      expect(companion.name, '');
      expect(companion.mu, isNull);
      expect(companion.ko, isNull);
      expect(companion.geschwindigkeiten, isEmpty);
      expect(companion.maxLep, isNull);
      expect(companion.vorteile, '');
      expect(companion.nachteile, '');
      expect(companion.gw, isNull);
      expect(companion.au, isNull);
    });

    test('fromJson migriert altes eigenAp-Feld nach apGesamt', () {
      final c = HeroCompanion.fromJson({'id': 'x', 'eigenAp': 75});
      expect(c.apGesamt, 75);
      expect(c.apAusgegeben, isNull);
    });

    test('fromJson migriert altes vorNachteile-Feld', () {
      final companion = HeroCompanion.fromJson({
        'id': 'x',
        'vorNachteile': 'Flink',
      });
      expect(companion.vorteile, 'Flink');
      expect(companion.nachteile, '');
    });

    test('copyWith erhält nullable Felder korrekt (null bleibt null)', () {
      const companion = HeroCompanion(id: 'a', mu: null, ko: 12);
      final updated = companion.copyWith(name: 'Neu');
      expect(updated.mu, isNull);
      expect(updated.ko, 12);
      expect(updated.name, 'Neu');
    });

    test('copyWith kann nullable Felder auf null setzen', () {
      const companion = HeroCompanion(id: 'a', ko: 12);
      final updated = companion.copyWith(ko: null);
      expect(updated.ko, isNull);
    });

    test(
      'nullable Eigenschaften werden in toJson nur bei Wert serialisiert',
      () {
        const companion = HeroCompanion(id: 'b', ko: 10);
        final json = companion.toJson();
        expect(json.containsKey('ko'), isTrue);
        expect(json.containsKey('mu'), isFalse);
      },
    );
  });

  group('HeroCompanionAttack', () {
    test('Roundtrip mit allen Feldern', () {
      const attack = HeroCompanionAttack(
        id: 'atk-1',
        name: 'Beißen',
        dk: 'H',
        at: 14,
        pa: 7,
        tp: '1W6+4',
        beschreibung: 'Kraftvoller Biss',
      );
      final json = attack.toJson();
      final restored = HeroCompanionAttack.fromJson(json);
      expect(restored, equals(attack));
    });

    test('Roundtrip mit Minimalstruktur', () {
      const attack = HeroCompanionAttack(id: 'min');
      final json = attack.toJson();
      final restored = HeroCompanionAttack.fromJson(json);
      expect(restored, equals(attack));
    });

    test('fromJson toleriert fehlende Felder', () {
      final attack = HeroCompanionAttack.fromJson({'id': 'x'});
      expect(attack.name, '');
      expect(attack.dk, '');
      expect(attack.at, isNull);
      expect(attack.pa, isNull);
      expect(attack.tp, '');
      expect(attack.beschreibung, '');
    });

    test('nullable at/pa werden in toJson nur bei Wert serialisiert', () {
      const attack = HeroCompanionAttack(id: 'x', at: 12);
      final json = attack.toJson();
      expect(json.containsKey('at'), isTrue);
      expect(json.containsKey('pa'), isFalse);
    });
  });

  group('HeroCompanionSonderfertigkeit', () {
    test('Roundtrip mit allen Feldern', () {
      const sf = HeroCompanionSonderfertigkeit(
        name: 'Wuchtschlag',
        beschreibung: 'Erhöht Schaden um 2',
      );
      final json = sf.toJson();
      final restored = HeroCompanionSonderfertigkeit.fromJson(json);
      expect(restored, equals(sf));
    });

    test('fromJson toleriert fehlende Felder', () {
      final sf = HeroCompanionSonderfertigkeit.fromJson({});
      expect(sf.name, '');
      expect(sf.beschreibung, '');
    });
  });

  group('HeroCompanion – Rüstung', () {
    test('Roundtrip mit Ruestungsteilen und Ruestungsgewoehnung', () {
      final companion = HeroCompanion(
        id: 'armor-test',
        name: 'Streitross',
        ruestungsgewoehnung: 2,
        ruestungsTeile: const [
          ArmorPiece(name: 'Pferdedecke', rs: 3, be: 2, isActive: true),
          ArmorPiece(name: 'Halsschutz', rs: 1, be: 1, isActive: false),
        ],
      );

      final json = companion.toJson();
      final restored = HeroCompanion.fromJson(json);

      expect(restored, equals(companion));
      expect(restored.ruestungsgewoehnung, 2);
      expect(restored.ruestungsTeile.length, 2);
      expect(restored.ruestungsTeile[0].name, 'Pferdedecke');
      expect(restored.ruestungsTeile[0].rs, 3);
      expect(restored.ruestungsTeile[0].isActive, isTrue);
      expect(restored.ruestungsTeile[1].isActive, isFalse);
    });

    test('fromJson ohne ruestungsTeile ergibt leere Liste', () {
      final companion = HeroCompanion.fromJson({'id': 'x'});
      expect(companion.ruestungsTeile, isEmpty);
      expect(companion.ruestungsgewoehnung, 0);
    });

    test('copyWith aktualisiert ruestungsTeile', () {
      const companion = HeroCompanion(id: 'a');
      final updated = companion.copyWith(
        ruestungsTeile: const [ArmorPiece(name: 'Kettenhemd', rs: 4, be: 3)],
        ruestungsgewoehnung: 1,
      );
      expect(updated.ruestungsTeile.length, 1);
      expect(updated.ruestungsTeile.first.name, 'Kettenhemd');
      expect(updated.ruestungsgewoehnung, 1);
      // Original unveraendert
      expect(companion.ruestungsTeile, isEmpty);
    });

    test('ruestungsTeile in toJson nur bei Wert serialisiert', () {
      const companion = HeroCompanion(
        id: 'b',
        ruestungsTeile: [ArmorPiece(name: 'Test', rs: 2, be: 1)],
      );
      final json = companion.toJson();
      expect(json['ruestungsTeile'], isA<List>());
      expect((json['ruestungsTeile'] as List).length, 1);
    });
  });

  group('HeroCompanion – Ritualkategorien', () {
    const testKategorie = HeroRitualCategory(
      id: 'vertrautenmagie',
      name: 'Vertrautenmagie',
      knowledgeMode: HeroRitualKnowledgeMode.ownKnowledge,
      ownKnowledge: HeroRitualKnowledge(
        name: 'Vertrautenmagie',
        value: 5,
        learningComplexity: 'E',
      ),
      rituals: [
        HeroRitualEntry(
          name: 'Zwiegespräch',
          technik: 'Konzentration',
          zauberdauer: '1 Aktion',
          wirkung: 'Telepathische Unterhaltung',
          kosten: '2 AsP',
          zielobjekt: 'Hexe',
          reichweite: 'Sichtweite',
          wirkungsdauer: '5 Minuten',
          merkmale: 'Kommunikation',
        ),
      ],
    );

    test('Roundtrip mit ritualCategories', () {
      final companion = HeroCompanion(
        id: 'v-1',
        typ: BegleiterTyp.vertrauter,
        ritualCategories: const [testKategorie],
      );
      final json = companion.toJson();
      final restored = HeroCompanion.fromJson(json);
      expect(restored, equals(companion));
      expect(restored.ritualCategories.length, 1);
      expect(restored.ritualCategories.first.id, 'vertrautenmagie');
      expect(restored.ritualCategories.first.rituals.length, 1);
      expect(restored.ritualCategories.first.ownKnowledge?.value, 5);
    });

    test('fromJson ohne ritualCategories ergibt leere Liste', () {
      final companion = HeroCompanion.fromJson({'id': 'x'});
      expect(companion.ritualCategories, isEmpty);
    });

    test('toJson schreibt ritualCategories nur bei nicht-leerer Liste', () {
      const companion = HeroCompanion(id: 'a');
      final json = companion.toJson();
      expect(json.containsKey('ritualCategories'), isFalse);
    });

    test('toJson mit Kategorien serialisiert ritualCategories', () {
      final companion = HeroCompanion(
        id: 'b',
        ritualCategories: const [testKategorie],
      );
      final json = companion.toJson();
      expect(json.containsKey('ritualCategories'), isTrue);
      expect((json['ritualCategories'] as List).length, 1);
    });

    test('copyWith aktualisiert ritualCategories', () {
      const companion = HeroCompanion(id: 'c');
      final updated = companion.copyWith(
        ritualCategories: const [testKategorie],
      );
      expect(updated.ritualCategories.length, 1);
      expect(companion.ritualCategories, isEmpty);
    });

    test('altes JSON ohne ritualCategories-Key (Backward-Compat)', () {
      final companion = HeroCompanion(
        id: 'd',
        ritualCategories: const [testKategorie],
      );
      final json = companion.toJson()..remove('ritualCategories');
      final restored = HeroCompanion.fromJson(json);
      expect(restored.ritualCategories, isEmpty);
    });
  });

  group('HeroCompanion – Steigerungen', () {
    test('Roundtrip mit steigerungen und Startwerten', () {
      final companion = HeroCompanion(
        id: 'stg-1',
        typ: BegleiterTyp.vertrauter,
        mu: 12,
        maxLep: 20,
        maxAsp: 10,
        magieresistenz: 4,
        steigerungen: const {'mu': 2, 'lep': 5, 'asp': 3, 'mr': 1},
        startLep: 20,
        startAsp: 10,
        startMr: 4,
      );
      final json = companion.toJson();
      final restored = HeroCompanion.fromJson(json);
      expect(restored, equals(companion));
      expect(restored.steigerungen['mu'], 2);
      expect(restored.steigerungen['lep'], 5);
      expect(restored.startLep, 20);
      expect(restored.startAsp, 10);
      expect(restored.startMr, 4);
    });

    test('fromJson ohne steigerungen ergibt leere Map', () {
      final companion = HeroCompanion.fromJson({'id': 'x'});
      expect(companion.steigerungen, isEmpty);
      expect(companion.startLep, isNull);
      expect(companion.startAsp, isNull);
      expect(companion.startMr, isNull);
    });

    test('toJson schreibt steigerungen nur bei nicht-leerer Map', () {
      const companion = HeroCompanion(id: 'a');
      final json = companion.toJson();
      expect(json.containsKey('steigerungen'), isFalse);
      expect(json.containsKey('startLep'), isFalse);
    });

    test('toJson mit Startwerten serialisiert diese', () {
      const companion = HeroCompanion(id: 'b', startLep: 15, startMr: 3);
      final json = companion.toJson();
      expect(json['startLep'], 15);
      expect(json['startMr'], 3);
      expect(json.containsKey('startAsp'), isFalse);
    });

    test('copyWith aktualisiert steigerungen', () {
      const companion = HeroCompanion(id: 'c');
      final updated = companion.copyWith(
        steigerungen: const {'mu': 1},
        startLep: 20,
      );
      expect(updated.steigerungen['mu'], 1);
      expect(updated.startLep, 20);
      expect(companion.steigerungen, isEmpty);
    });
  });

  group('HeroCompanionAttack – Steigerungen', () {
    test('Roundtrip mit steigerungAt und steigerungPa', () {
      const attack = HeroCompanionAttack(
        id: 'atk-stg',
        name: 'Beißen',
        at: 14,
        pa: 7,
        tp: '1W6+4',
        steigerungAt: 3,
        steigerungPa: 1,
      );
      final json = attack.toJson();
      final restored = HeroCompanionAttack.fromJson(json);
      expect(restored, equals(attack));
      expect(restored.steigerungAt, 3);
      expect(restored.steigerungPa, 1);
    });

    test('fromJson ohne steigerung-Felder ergibt 0', () {
      final attack = HeroCompanionAttack.fromJson({'id': 'x'});
      expect(attack.steigerungAt, 0);
      expect(attack.steigerungPa, 0);
    });

    test('toJson schreibt steigerung nur bei != 0', () {
      const attack = HeroCompanionAttack(id: 'x', at: 10);
      final json = attack.toJson();
      expect(json.containsKey('steigerungAt'), isFalse);
      expect(json.containsKey('steigerungPa'), isFalse);
    });
  });

  group('HeroSheet mit companions', () {
    const testAttributes = Attributes(
      mu: 8,
      kl: 8,
      inn: 8,
      ch: 8,
      ff: 8,
      ge: 8,
      ko: 8,
      kk: 8,
    );

    HeroSheet buildSheet({List<HeroCompanion> companions = const []}) {
      return HeroSheet(
        id: 'hero-1',
        name: 'Testheldin',
        level: 1,
        attributes: testAttributes,
        companions: companions,
      );
    }

    test('schemaVersion ist 23', () {
      expect(buildSheet().schemaVersion, 23);
    });

    test('Roundtrip mit leerem companions', () {
      final sheet = buildSheet();
      final json = sheet.toJson();
      final restored = HeroSheet.fromJson(json);
      expect(restored.companions, isEmpty);
    });

    test('Roundtrip mit einem Begleiter', () {
      final companion = const HeroCompanion(
        id: 'comp-1',
        name: 'Max',
        ko: 10,
        kk: 8,
        geschwindigkeiten: [HeroCompanionSpeed(art: 'zu Fuß', wert: 9)],
      );
      final sheet = buildSheet(companions: [companion]);
      final json = sheet.toJson();
      final restored = HeroSheet.fromJson(json);
      expect(restored.companions.length, 1);
      expect(restored.companions.first, equals(companion));
    });

    test('Roundtrip mit Angriffen und Sonderfertigkeiten', () {
      final companion = const HeroCompanion(
        id: 'c1',
        angriffe: [
          HeroCompanionAttack(id: 'a1', name: 'Beißen', at: 14, tp: '1W6+4'),
        ],
        sonderfertigkeiten: [
          HeroCompanionSonderfertigkeit(name: 'Wuchtschlag'),
        ],
      );
      final json = companion.toJson();
      final restored = HeroCompanion.fromJson(json);
      expect(restored.angriffe.length, 1);
      expect(restored.angriffe.first.name, 'Beißen');
      expect(restored.sonderfertigkeiten.length, 1);
      expect(restored.sonderfertigkeiten.first.name, 'Wuchtschlag');
    });

    test('altes JSON ohne angriffe/sonderfertigkeiten ergibt leere Listen', () {
      final companion = const HeroCompanion(id: 'c2');
      final json = companion.toJson()
        ..remove('angriffe')
        ..remove('sonderfertigkeiten');
      final restored = HeroCompanion.fromJson(json);
      expect(restored.angriffe, isEmpty);
      expect(restored.sonderfertigkeiten, isEmpty);
    });

    test('altes JSON ohne companions-Key ergibt leere Liste', () {
      final sheet = buildSheet();
      final json = sheet.toJson()..remove('companions');
      final restored = HeroSheet.fromJson(json);
      expect(restored.companions, isEmpty);
    });

    test('copyWith aktualisiert companions', () {
      final sheet = buildSheet();
      final updated = sheet.copyWith(
        companions: [const HeroCompanion(id: 'x', name: 'Begleiter')],
      );
      expect(updated.companions.length, 1);
      expect(updated.companions.first.name, 'Begleiter');
    });
  });
}
