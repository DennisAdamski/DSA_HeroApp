import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_snapshot.dart';
import 'package:dsa_heldenverwaltung/domain/hero_appearance.dart';
import 'package:dsa_heldenverwaltung/domain/hero_background.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/avatar_snapshot_diff.dart';

HeroSheet _hero({
  Attributes attributes = const Attributes(
    mu: 14,
    kl: 12,
    inn: 13,
    ch: 11,
    ff: 10,
    ge: 12,
    ko: 14,
    kk: 13,
  ),
  String vorteileText = '',
  String nachteileText = '',
  String rasse = 'Mensch',
  String alter = '25',
  String haarfarbe = 'braun',
  String augenfarbe = 'grün',
}) {
  return HeroSheet(
    id: 'demo',
    name: 'Rondra',
    level: 1,
    attributes: attributes,
    vorteileText: vorteileText,
    nachteileText: nachteileText,
    background: HeroBackground(rasse: rasse),
    appearance: HeroAppearance(
      alter: alter,
      haarfarbe: haarfarbe,
      augenfarbe: augenfarbe,
    ),
  );
}

void main() {
  group('computeAvatarSnapshotDiff', () {
    test('leerer Snapshot-Attributsatz wirft nicht und meldet 0 als alt', () {
      // Regression: der Spread von `snapshot.attributes.keys` war die Stelle,
      // an der ein fehlender Attributsatz die gesamte Uebersicht lahmlegte.
      final diff = computeAvatarSnapshotDiff(AvatarSnapshot(), _hero());

      expect(diff.attributeChanges.keys, containsAll(<String>['MU', 'KL']));
      expect(diff.attributeChanges['MU'], (alt: 0, neu: 14));
    });

    test('identische Werte ergeben keine Aenderung', () {
      final snapshot = AvatarSnapshot(
        attributes: {
          'MU': 14,
          'KL': 12,
          'IN': 13,
          'CH': 11,
          'FF': 10,
          'GE': 12,
          'KO': 14,
          'KK': 13,
        },
        alter: '25',
        rasse: 'Mensch',
        haarfarbe: 'braun',
        augenfarbe: 'grün',
      );

      final diff = computeAvatarSnapshotDiff(snapshot, _hero());

      expect(diff.attributeChanges, isEmpty);
      expect(diff.hatAenderungen, isFalse);
    });

    test('geaenderte Eigenschaft wird als alt/neu gemeldet', () {
      final snapshot = AvatarSnapshot(attributes: {'MU': 12, 'KL': 12});

      final diff = computeAvatarSnapshotDiff(snapshot, _hero());

      expect(diff.attributeChanges['MU'], (alt: 12, neu: 14));
      expect(diff.attributeChanges.containsKey('KL'), isFalse);
      expect(diff.hatAenderungen, isTrue);
    });

    test('Vor- und Nachteile werden als Zu- und Abgang erkannt', () {
      final snapshot = AvatarSnapshot(
        vorteileText: 'Gutaussehend, Adliges Erbe',
        nachteileText: 'Jähzorn',
      );

      final diff = computeAvatarSnapshotDiff(
        snapshot,
        _hero(
          vorteileText: 'Gutaussehend, Eisern',
          nachteileText: 'Jähzorn, Neugier',
        ),
      );

      expect(diff.neueVorteile, ['eisern']);
      expect(diff.entfernteVorteile, ['adliges erbe']);
      expect(diff.neueNachteile, ['neugier']);
      expect(diff.entfernteNachteile, isEmpty);
    });

    test('optische Aenderungen erscheinen als Pfeiltext', () {
      final snapshot = AvatarSnapshot(
        alter: '25',
        rasse: 'Mensch',
        haarfarbe: 'braun',
        augenfarbe: 'grün',
      );

      final diff = computeAvatarSnapshotDiff(
        snapshot,
        _hero(
          alter: '30',
          rasse: 'Halbelf',
          haarfarbe: 'schwarz',
          augenfarbe: 'blau',
        ),
      );

      expect(diff.alterChange, '25 \u2192 30');
      expect(diff.rasseChange, 'Mensch \u2192 Halbelf');
      expect(diff.haarfarbeChange, 'braun \u2192 schwarz');
      expect(diff.augenfarbeChange, 'grün \u2192 blau');
    });
  });
}
