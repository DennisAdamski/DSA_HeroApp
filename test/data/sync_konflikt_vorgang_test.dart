import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/sync/sync_konflikt_vorgang.dart';

SyncKonfliktVorgang _vorgang() {
  return SyncKonfliktVorgang(
    kontoId: 'konto-1',
    begonnen: DateTime.utc(2026, 10, 12, 8),
    originalId: 'held-1',
    kopieId: 'kopie-1',
    aktion: SyncKonfliktAktion.beideBehalten,
    dokumente: <SyncKonfliktDokument>[
      SyncKonfliktDokument.plane(
        art: SyncKonfliktDokumentArt.held,
        id: 'kopie-1',
        ziel: <String, dynamic>{
          'id': 'kopie-1',
          'liste': <Object?>[1, 2],
        },
        zielHash: 'h1',
        ausgangHash: null,
        lokalSchreiben: true,
        remoteSchreiben: true,
        istKopie: true,
      ),
      SyncKonfliktDokument.plane(
        art: SyncKonfliktDokumentArt.zustand,
        id: 'held-1',
        ziel: <String, dynamic>{'currentLep': 23},
        zielHash: 'h2',
        ausgangHash: 'alt',
        lokalSchreiben: true,
        remoteSchreiben: false,
        onlineRevision: 's-4',
        onlineHash: 'h2',
      ),
    ],
  );
}

SyncKonfliktVorgang _gelesen(Map<String, Object?> json) {
  final ergebnis = SyncKonfliktVorgang.lies(
    'syncKonflikt-held-1',
    json,
    kontoId: 'konto-1',
  );
  return (ergebnis! as SyncKonfliktGueltig).vorgang;
}

void main() {
  test('JSON-Roundtrip erhält Ziele, IDs und Fortschritt', () {
    final original = _vorgang();
    final gelesen = _gelesen(original.toJson());

    expect(gelesen.id, 'syncKonflikt-held-1');
    expect(gelesen.kopieId, 'kopie-1');
    expect(gelesen.aktion, SyncKonfliktAktion.beideBehalten);
    expect(gelesen.betroffeneIds, {'held-1', 'kopie-1'});
    expect(gelesen.dokumente.first.ziel, original.dokumente.first.ziel);
    expect(gelesen.dokumente.first.ausgangHash, isNull);
    expect(gelesen.dokumente.last.ausgangHash, 'alt');
    // Nicht nötige Schritte gelten von Anfang an als erledigt.
    expect(gelesen.dokumente.last.remoteErledigt, isTrue);
    expect(gelesen.dokumente.last.metaErledigt, isFalse);
    expect(gelesen.dokumente.first.lokalErledigt, isFalse);
  });

  test('unbekannte Felder bleiben beim Zurückschreiben erhalten', () {
    final json = _vorgang().toJson()..['zukunft'] = <String, Object?>{'x': 1};
    (json['dokumente']! as List<Object?>)
            .cast<Map<String, Object?>>()
            .first['dokumentZukunft'] =
        'y';

    final zurueck = _gelesen(json).toJson();

    expect(zurueck['zukunft'], {'x': 1});
    expect(
      (zurueck['dokumente']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .first['dokumentZukunft'],
      'y',
    );
  });

  test(
    'höhere Version, fremdes Konto und Lücken sind unbekannt, nicht gültig',
    () {
      final hoch = _vorgang().toJson()..['version'] = 2;
      final fremd = _vorgang().toJson()..['kontoId'] = 'konto-2';
      final luecke = _vorgang().toJson()
        ..['dokumente'] = <Object?>[
          <String, Object?>{'art': 'held'},
        ];

      for (final json in [hoch, fremd, luecke]) {
        final ergebnis = SyncKonfliktVorgang.lies(
          'syncKonflikt-held-1',
          json,
          kontoId: 'konto-1',
        );
        expect(ergebnis, isA<SyncKonfliktUnbekannt>());
        expect((ergebnis! as SyncKonfliktUnbekannt).reservierteIds, {
          'held-1',
          'kopie-1',
        }, reason: 'lesbare IDs bleiben reserviert');
      }
    },
  );

  test('fremde Arten gehen den Konfliktvorgang nichts an', () {
    expect(
      SyncKonfliktVorgang.lies('v-1', <String, Object?>{
        'art': 'heldImportieren',
      }, kontoId: 'konto-1'),
      isNull,
    );
  });

  test('ein beschädigter Eintrag reserviert keine ID', () {
    final ergebnis = SyncKonfliktVorgang.lies('x', <String, Object?>{
      'art': '_beschaedigt',
      'roh': '{',
    }, kontoId: 'konto-1');
    expect(ergebnis, isA<SyncKonfliktUnbekannt>());
    expect((ergebnis! as SyncKonfliktUnbekannt).reservierteIds, isEmpty);
  });

  test('die Blockade überdauert das Zurückschreiben', () {
    final blockiert = _vorgang().kopiere(
      blockade: SyncKonfliktBlockade(
        grund: SyncKonfliktBlockade.onlineGeaendert,
        seit: DateTime.utc(2026, 10, 12, 9),
      ),
    );
    final gelesen = _gelesen(blockiert.toJson());
    expect(gelesen.blockade!.grund, SyncKonfliktBlockade.onlineGeaendert);
    expect(gelesen.blockade!.seit, DateTime.utc(2026, 10, 12, 9));
  });
}
