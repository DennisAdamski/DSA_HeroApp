import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/sync_zusammenfuehrung.dart';

SyncZusammenfuehrung _fuehre(
  Map<String, dynamic> basis,
  Map<String, dynamic> lokal,
  Map<String, dynamic> online, {
  SyncZusammenfuehrungsRegeln regeln = heldZusammenfuehrungsRegeln,
  Map<String, SyncSeite> entscheidungen = const <String, SyncSeite>{},
}) {
  return fuehreSyncZusammen(
    basis: basis,
    lokal: lokal,
    online: online,
    regeln: regeln,
    entscheidungen: entscheidungen,
  );
}

void main() {
  group('ohne echten Konflikt', () {
    test('verschiedene Felder beider Seiten werden übernommen', () {
      final ergebnis = _fuehre(
        {'name': 'Alrik', 'dukaten': '10', 'talents': {}},
        {'name': 'Alrik der Große', 'dukaten': '10', 'talents': {}},
        {'name': 'Alrik', 'dukaten': '25', 'talents': {}},
      );

      expect(ergebnis.vollstaendig, isTrue);
      expect(ergebnis.ergebnis['name'], 'Alrik der Große');
      expect(ergebnis.ergebnis['dukaten'], '25');
      expect(ergebnis.vonLokal, 1);
      expect(ergebnis.vonOnline, 1);
    });

    test('Talente werden je Schlüssel und Feld zusammengeführt', () {
      final ergebnis = _fuehre(
        {
          'talents': {
            'klettern': {'taw': 3, 'gifted': false},
            'schwimmen': {'taw': 2},
          },
        },
        {
          'talents': {
            'klettern': {'taw': 5, 'gifted': false},
            'schwimmen': {'taw': 2},
          },
        },
        {
          'talents': {
            'klettern': {'taw': 3, 'gifted': true},
            'schwimmen': {'taw': 2},
            'reiten': {'taw': 1},
          },
        },
      );

      expect(ergebnis.vollstaendig, isTrue);
      expect(ergebnis.ergebnis['talents'], {
        'klettern': {'taw': 5, 'gifted': true},
        'schwimmen': {'taw': 2},
        'reiten': {'taw': 1},
      });
    });

    test('AP sind Zähler: beide Seiten tragen ihre Differenz bei', () {
      final ergebnis = _fuehre(
        {'apTotal': 1000, 'apSpent': 900, 'apAvailable': 100, 'level': 5},
        {'apTotal': 1100, 'apSpent': 950, 'apAvailable': 150, 'level': 5},
        {'apTotal': 1050, 'apSpent': 1000, 'apAvailable': 50, 'level': 6},
      );

      expect(ergebnis.vollstaendig, isTrue);
      expect(ergebnis.ergebnis['apTotal'], 1150);
      expect(ergebnis.ergebnis['apSpent'], 1050);
      expect(ergebnis.ergebnis['apAvailable'], 100);
      expect(ergebnis.ergebnis['level'], 6);
    });

    test('Inventar über die Instanz-ID: Hinzufügen, Ändern und Entfernen '
        'beider Seiten', () {
      Map<String, dynamic> eintrag(String id, String name, {int menge = 1}) => {
        'instanzId': id,
        'name': name,
        'menge': menge,
      };
      final ergebnis = _fuehre(
        {
          'inventoryEntries': [
            eintrag('a', 'Seil'),
            eintrag('b', 'Fackel', menge: 3),
            eintrag('c', 'Brot'),
          ],
        },
        {
          'inventoryEntries': [
            eintrag('a', 'Seil'),
            eintrag('b', 'Fackel', menge: 2),
            eintrag('c', 'Brot'),
            eintrag('d', 'Dolch'),
          ],
        },
        {
          'inventoryEntries': [
            eintrag('a', 'Seil (10 Schritt)'),
            eintrag('b', 'Fackel', menge: 3),
            eintrag('e', 'Heiltrank'),
          ],
        },
      );

      expect(ergebnis.vollstaendig, isTrue);
      expect(ergebnis.ergebnis['inventoryEntries'], [
        eintrag('a', 'Seil (10 Schritt)'),
        eintrag('b', 'Fackel', menge: 2),
        eintrag('d', 'Dolch'),
        eintrag('e', 'Heiltrank'),
      ]);
    });

    test('Steigerungsverlauf wird über die ID vereinigt, nichts geht '
        'verloren', () {
      final ergebnis = _fuehre(
        {
          'advancementHistory': [
            {'id': '1', 'label': 'MU'},
          ],
        },
        {
          'advancementHistory': [
            {'id': '1', 'label': 'MU'},
            {'id': '2', 'label': 'Klettern'},
          ],
        },
        {
          'advancementHistory': [
            {'id': '1', 'label': 'MU'},
            {'id': '3', 'label': 'Schwimmen'},
          ],
        },
      );

      expect(
        (ergebnis.ergebnis['advancementHistory'] as List).map(
          (e) => (e as Map)['id'],
        ),
        ['1', '2', '3'],
      );
    });

    test('ein nur bei Belegung geschriebenes Feld darf auf einer Seite '
        'entstehen', () {
      final ergebnis = _fuehre(
        {'name': 'A'},
        {
          'name': 'A',
          'geburtsdatum': {'day': '3'},
        },
        {'name': 'B'},
      );

      expect(ergebnis.vollstaendig, isTrue);
      expect(ergebnis.ergebnis, {
        'name': 'B',
        'geburtsdatum': {'day': '3'},
      });
    });
  });

  group('echte Konflikte', () {
    test('derselbe Talentwert verschieden geändert', () {
      final ergebnis = _fuehre(
        {
          'talents': {
            'klettern': {'taw': 3},
          },
        },
        {
          'talents': {
            'klettern': {'taw': 5},
          },
        },
        {
          'talents': {
            'klettern': {'taw': 4},
          },
        },
      );

      final konflikt = ergebnis.konflikte.single;
      expect(konflikt.schluessel, 'talents/klettern/taw');
      expect(konflikt.pfad, ['talents', 'klettern', 'taw']);
      expect(konflikt.lokal, 5);
      expect(konflikt.online, 4);
    });

    test('Entscheidungen lösen sie je Feld', () {
      Map<String, dynamic> stand(int taw, String name) => {
        'name': name,
        'talents': {
          'klettern': {'taw': taw},
        },
      };
      final basis = stand(3, 'A');
      final lokal = stand(5, 'B');
      final online = stand(4, 'C');

      final ergebnis = _fuehre(
        basis,
        lokal,
        online,
        entscheidungen: {
          'talents/klettern/taw': SyncSeite.online,
          'name': SyncSeite.lokal,
        },
      );

      expect(ergebnis.vollstaendig, isTrue);
      expect(ergebnis.ergebnis, stand(4, 'B'));
    });

    test('gelöscht auf der einen, geändert auf der anderen Seite', () {
      final ergebnis = _fuehre(
        {
          'inventoryEntries': [
            {'instanzId': 'a', 'name': 'Seil', 'menge': 1},
          ],
        },
        {'inventoryEntries': <Object?>[]},
        {
          'inventoryEntries': [
            {'instanzId': 'a', 'name': 'Seil', 'menge': 2},
          ],
        },
      );

      final konflikt = ergebnis.konflikte.single;
      expect(konflikt.pfad, ['inventoryEntries', 'Seil']);
      expect(konflikt.lokalFehlt, isTrue);
      expect(konflikt.onlineFehlt, isFalse);
    });

    test('Listen ohne IDs sind unteilbar', () {
      final ergebnis = _fuehre(
        {
          'notes': [
            {'text': 'a'},
          ],
        },
        {
          'notes': [
            {'text': 'a'},
            {'text': 'b'},
          ],
        },
        {
          'notes': [
            {'text': 'c'},
          ],
        },
      );

      expect(ergebnis.konflikte.single.schluessel, 'notes');
    });
  });

  group('Laufzeitzustand', () {
    test('Ressourcen zählen, Buchungen und Protokoll werden vereinigt', () {
      Map<String, dynamic> stand(
        int lep,
        List<String> buchungen,
        List<String> wuerfe,
      ) => {
        'currentLep': lep,
        'buchungen': [
          for (final id in buchungen) {'id': id, 'art': 'schaden'},
        ],
        'diceLog': [
          for (final zeit in wuerfe) {'timestamp': zeit, 'title': 'W'},
        ],
      };

      final ergebnis = _fuehre(
        stand(30, [], ['2026-10-07T10:00:00.000Z']),
        stand(
          25,
          ['a'],
          ['2026-10-07T10:00:00.000Z', '2026-10-07T12:00:00.000Z'],
        ),
        stand(
          27,
          ['b'],
          ['2026-10-07T10:00:00.000Z', '2026-10-07T11:00:00.000Z'],
        ),
        regeln: zustandZusammenfuehrungsRegeln,
      );

      expect(ergebnis.vollstaendig, isTrue);
      expect(ergebnis.ergebnis['currentLep'], 22);
      expect(
        (ergebnis.ergebnis['buchungen'] as List).map((e) => (e as Map)['id']),
        ['a', 'b'],
      );
      expect(
        (ergebnis.ergebnis['diceLog'] as List).map(
          (e) => (e as Map)['timestamp'],
        ),
        [
          '2026-10-07T10:00:00.000Z',
          '2026-10-07T11:00:00.000Z',
          '2026-10-07T12:00:00.000Z',
        ],
      );
    });

    test('das Protokoll bleibt auf 50 Einträge begrenzt', () {
      List<Map<String, dynamic>> wuerfe(int von, int bis) => [
        for (var i = von; i < bis; i++)
          {'timestamp': '2026-10-07T10:${i.toString().padLeft(2, '0')}'},
      ];

      final ergebnis = _fuehre(
        {'diceLog': wuerfe(0, 40)},
        {'diceLog': wuerfe(0, 50)},
        {'diceLog': wuerfe(0, 40) + wuerfe(50, 60)},
        regeln: zustandZusammenfuehrungsRegeln,
      );

      final log = ergebnis.ergebnis['diceLog'] as List;
      expect(log, hasLength(50));
      expect((log.last as Map)['timestamp'], '2026-10-07T10:59');
    });

    test('dieselbe Wundzone verschieden geändert ist ein Konflikt', () {
      Map<String, dynamic> stand(int brust) => {
        'wpiZustand': {
          'wundenProZone': {'brust': brust},
        },
      };

      final ergebnis = _fuehre(
        stand(0),
        stand(1),
        stand(2),
        regeln: zustandZusammenfuehrungsRegeln,
      );

      expect(
        ergebnis.konflikte.single.schluessel,
        'wpiZustand/wundenProZone/brust',
      );
    });
  });

  group('laufende Werte der Begleiter', () {
    Map<String, dynamic> stand(Map<String, Map<String, dynamic>> begleiter) => {
      'currentLep': 30,
      if (begleiter.isNotEmpty) 'begleiterZustaende': begleiter,
    };

    test('LeP beider Geräte zählen als Zähler', () {
      final ergebnis = _fuehre(
        stand({
          'mira': {'currentLep': 10},
        }),
        stand({
          'mira': {'currentLep': 7},
        }),
        stand({
          'mira': {'currentLep': 9},
        }),
        regeln: zustandZusammenfuehrungsRegeln,
      );

      expect(ergebnis.vollstaendig, isTrue);
      expect(ergebnis.ergebnis['begleiterZustaende'], {
        'mira': {'currentLep': 6},
      });
    });

    test(
      'verschiedene Felder und Begleiter führen sich ohne Konflikt zusammen',
      () {
        final ergebnis = _fuehre(
          stand({
            'mira': {'currentLep': 10},
          }),
          stand({
            'mira': {'currentLep': 10, 'currentAsp': 4},
          }),
          stand({
            'mira': {'currentLep': 10, 'currentAup': 20},
            'rondo': {'currentLep': 5},
          }),
          regeln: zustandZusammenfuehrungsRegeln,
        );

        expect(ergebnis.vollstaendig, isTrue);
        expect(ergebnis.ergebnis['begleiterZustaende'], {
          'mira': {'currentLep': 10, 'currentAsp': 4, 'currentAup': 20},
          'rondo': {'currentLep': 5},
        });
      },
    );

    test('fehlt ein Wert („voll“) auf einer Seite, gilt kein Zähler', () {
      Map<String, Map<String, dynamic>> mit(Map<String, dynamic>? mira) => {
        'rondo': {'currentLep': 3},
        'mira': ?mira,
      };
      final ergebnis = _fuehre(
        stand(mit({'currentLep': 10})),
        stand(mit(null)),
        stand(mit({'currentLep': 8})),
        regeln: zustandZusammenfuehrungsRegeln,
      );

      expect(ergebnis.konflikte.single.schluessel, 'begleiterZustaende/mira');
      expect(ergebnis.konflikte.single.lokalFehlt, isTrue);
    });
  });

  test('legen beide Seiten eine Liste neu an, zählt jedes Element', () {
    final ergebnis = _fuehre(
      {'name': 'A'},
      {
        'name': 'A',
        'buchungen': [
          {'id': 'a'},
        ],
      },
      {
        'name': 'A',
        'buchungen': [
          {'id': 'b'},
        ],
      },
      regeln: zustandZusammenfuehrungsRegeln,
    );

    expect(ergebnis.vollstaendig, isTrue);
    expect(ergebnis.ergebnis['buchungen'], [
      {'id': 'a'},
      {'id': 'b'},
    ]);
  });

  test('ein Präfix trennt Schlüssel von Held und Zustand', () {
    final ergebnis = fuehreSyncZusammen(
      basis: {'name': 'A'},
      lokal: {'name': 'B'},
      online: {'name': 'C'},
      praefix: 'held:',
    );

    expect(ergebnis.konflikte.single.schluessel, 'held:name');
  });
}
