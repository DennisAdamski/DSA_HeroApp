import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/avatar_snapshot.dart';

void main() {
  group('AvatarSnapshot.attributes-Normalisierung', () {
    test('ohne attributes bleibt die Map leer statt null', () {
      final snapshot = AvatarSnapshot(erstelltAm: '2026-08-21T10:00:00Z');

      expect(snapshot.attributes, isEmpty);
    });

    test('explizites null wird zur leeren Map', () {
      // Der Regressionsfall: ein durchgereichtes `null` liess frueher erst
      // computeAvatarSnapshotDiff mit
      // "Null is not a subtype of Iterable<String>" platzen.
      final snapshot = AvatarSnapshot(attributes: null);

      expect(snapshot.attributes, isNotNull);
      expect(snapshot.attributes, isEmpty);
    });

    test('uebergebene Werte bleiben erhalten', () {
      final snapshot = AvatarSnapshot(attributes: {'MU': 14, 'KL': 12});

      expect(snapshot.attributes, {'MU': 14, 'KL': 12});
    });

    test('die gespeicherte Map ist unveraenderlich', () {
      final quelle = {'MU': 14};
      final snapshot = AvatarSnapshot(attributes: quelle);

      expect(() => snapshot.attributes['KL'] = 12, throwsUnsupportedError);

      // Aenderungen an der Quelle duerfen den Snapshot nicht mehr erreichen.
      quelle['MU'] = 99;
      expect(snapshot.attributes['MU'], 14);
    });

    test('toJson liefert eine veraenderbare Kopie', () {
      final snapshot = AvatarSnapshot(attributes: {'MU': 14});

      final json = snapshot.toJson();
      final attributes = json['attributes'] as Map<String, int>;
      attributes['KL'] = 12;

      expect(snapshot.attributes, {'MU': 14});
    });

    test('fromJson ohne attributes-Feld ergibt eine leere Map', () {
      final snapshot = AvatarSnapshot.fromJson(<String, dynamic>{
        'erstelltAm': '2026-08-21T10:00:00Z',
      });

      expect(snapshot.attributes, isEmpty);
    });

    test('fromJson ueberlebt ein null im attributes-Feld', () {
      final snapshot = AvatarSnapshot.fromJson(<String, dynamic>{
        'attributes': null,
      });

      expect(snapshot.attributes, isEmpty);
    });

    test('Roundtrip ueber toJson/fromJson erhaelt die Werte', () {
      final original = AvatarSnapshot(
        erstelltAm: '2026-08-21T10:00:00Z',
        attributes: {'MU': 14, 'KK': 13},
        rasse: 'Halbelf',
      );

      final restored = AvatarSnapshot.fromJson(original.toJson());

      expect(restored.attributes, {'MU': 14, 'KK': 13});
      expect(restored.rasse, 'Halbelf');
      expect(restored.erstelltAm, '2026-08-21T10:00:00Z');
    });
  });
}
