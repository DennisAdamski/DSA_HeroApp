import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart' show ArmorPiece;
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
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
        eigenAp: 50,
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
        vorNachteile: 'Flink',
        gw: '',
        au: '',
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

    test('nullable Eigenschaften werden in toJson nur bei Wert serialisiert', () {
      const companion = HeroCompanion(id: 'b', ko: 10);
      final json = companion.toJson();
      expect(json.containsKey('ko'), isTrue);
      expect(json.containsKey('mu'), isFalse);
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

    test('schemaVersion ist 19', () {
      expect(buildSheet().schemaVersion, 19);
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
