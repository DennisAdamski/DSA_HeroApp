import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_crypto.dart';
import 'package:dsa_heldenverwaltung/catalog/kurzregel_def.dart';
import 'package:dsa_heldenverwaltung/catalog/kurzregel_loader.dart';

import 'catalog_reference_names.dart';

/// Erfundene Testdaten: keine Regelbuchinhalte.
void main() {
  const passwort = 'testpasswort';
  final salt = Uint8List.fromList(List<int>.generate(32, (i) => i));
  final schluessel = deriveCatalogKey(password: passwort, salt: salt);

  Map<String, dynamic> eintrag({
    String id = 'test_eins',
    String titel = 'Testregel',
    List<String> quellen = const ['Testbuch, S. 12'],
    String kurztext = 'Erfundener Kurztext',
    List<String> hinweise = const ['Erster Hinweis'],
    String hausregelText = '',
    String hausregelQuelle = '',
    bool verschluesseln = true,
  }) {
    String text(String wert) => verschluesseln
        ? encryptCatalogValueV3(plaintext: wert, derivedKey: schluessel)
        : wert;
    return {
      'id': id,
      'titel': titel,
      'thema': 'kampf',
      'schlagworte': ['probe'],
      'quellen': quellen,
      'kurztext': text(kurztext),
      'hinweise': verschluesseln
          ? encryptCatalogListV3(values: hinweise, derivedKey: schluessel)
          : hinweise,
      if (hausregelText.isNotEmpty) 'hausregel_text': text(hausregelText),
      if (hausregelQuelle.isNotEmpty) 'hausregel_quelle': hausregelQuelle,
    };
  }

  group('parseKurzregeln', () {
    test('entschluesselt Texte und Listen mit richtigem Passwort', () {
      final katalog = parseKurzregeln(
        [
          eintrag(
            hausregelText: 'Erfundene Abweichung',
            hausregelQuelle: 'testpaket_v1',
          ),
        ],
        passwort: passwort,
        salt: salt,
      );

      final regel = katalog.eintraege.single;
      expect(regel.kurztext, 'Erfundener Kurztext');
      expect(regel.hinweise, ['Erster Hinweis']);
      expect(regel.hausregelText, 'Erfundene Abweichung');
      expect(regel.hatHausregel, isTrue);
      expect(regel.gesperrt, isFalse);
      expect(katalog.gesperrt, isFalse);
    });

    test('ohne Passwort bleiben Titel und Beleg, Texte sind gesperrt', () {
      final katalog = parseKurzregeln([eintrag()]);

      final regel = katalog.eintraege.single;
      expect(regel.titel, 'Testregel');
      expect(regel.quellen, ['Testbuch, S. 12']);
      expect(regel.kurztext, isEmpty);
      expect(regel.hinweise, isEmpty);
      expect(regel.gesperrt, isTrue);
      expect(katalog.gesperrt, isTrue);
    });

    test('falsches Passwort zeigt keinen Chiffretext', () {
      final katalog = parseKurzregeln(
        [eintrag()],
        passwort: 'falsch',
        salt: salt,
      );

      final regel = katalog.eintraege.single;
      expect(regel.kurztext, isEmpty);
      expect(regel.gesperrt, isTrue);
    });

    test('Klartext-Eintraege (z. B. Entwurf) sind nie gesperrt', () {
      final katalog = parseKurzregeln([eintrag(verschluesseln: false)]);

      expect(katalog.eintraege.single.kurztext, 'Erfundener Kurztext');
      expect(katalog.gesperrt, isFalse);
    });

    test('verwirft Eintraege ohne Quelle oder ohne Seitenangabe', () {
      final katalog = parseKurzregeln([
        eintrag(id: 'ohne', quellen: const []),
        eintrag(id: 'ohne_seite', quellen: const ['Testbuch']),
        eintrag(id: 'gut'),
      ]);

      expect(katalog.eintraege.map((e) => e.id), ['gut']);
      expect(katalog.verworfen.keys, containsAll(['ohne', 'ohne_seite']));
      expect(katalog.verworfen['ohne'], contains('quellen fehlen'));
    });

    test('Hausregeltext verlangt eine Hausregel-Quelle', () {
      final katalog = parseKurzregeln(
        [eintrag(id: 'x', hausregelText: 'Abweichung')],
        passwort: passwort,
        salt: salt,
      );

      expect(katalog.eintraege, isEmpty);
      expect(katalog.verworfen['x'], contains('hausregel_quelle fehlt'));
    });

    test(
      'Seitenbereiche und knappe Schreibweisen werden als Beleg akzeptiert',
      () {
        final katalog = parseKurzregeln([
          eintrag(quellen: const ['Testbuch, S. 12-13', 'Zweites Buch S.7']),
        ]);

        expect(katalog.eintraege, hasLength(1));
      },
    );

    test('ignoriert Nicht-Objekte in der Liste', () {
      final katalog = parseKurzregeln(['text', 3, null, eintrag()]);

      expect(katalog.eintraege, hasLength(1));
    });
  });

  group('kurzregelThemaLabel', () {
    test('kennt Themen und reicht unbekannte durch', () {
      expect(kurzregelThemaLabel('zustaende'), 'Zustände');
      expect(kurzregelThemaLabel('neu_thema'), 'neu_thema');
    });
  });

  group('Redaktionswerkzeug', () {
    test('tool/check_kurzregeln.py kennt dieselben Themen wie die App', () {
      final skript = File('tool/check_kurzregeln.py').readAsStringSync();
      final block = RegExp(
        r'THEMEN = \{(.*?)\}',
        dotAll: true,
      ).firstMatch(skript)!.group(1)!;
      final imSkript = RegExp(r"'([a-z_]+)'")
          .allMatches(block)
          .map((m) => m.group(1)!)
          .toSet();

      expect(imSkript, kurzregelThemen.map((t) => t.schluessel).toSet());
    });
  });

  group('ladeKurzregeln', () {
    test('fehlendes Asset ergibt ein leeres Kompendium', () async {
      final katalog = await ladeKurzregeln(
        lader: (pfad) async => throw FlutterError('Asset fehlt'),
      );

      expect(katalog.eintraege, isEmpty);
    });

    test('liest Liste und Salt aus den Assets', () async {
      final manifest = jsonEncode({'catalog_salt_v3': base64Encode(salt)});
      final katalog = await ladeKurzregeln(
        passwort: passwort,
        lader: (pfad) async =>
            pfad == kurzregelnAssetPfad ? jsonEncode([eintrag()]) : manifest,
      );

      expect(katalog.eintraege.single.kurztext, 'Erfundener Kurztext');
    });

    test(
      'Nicht-Liste und kaputtes JSON ergeben ein leeres Kompendium',
      () async {
        final keinArray = await ladeKurzregeln(lader: (_) async => '{}');
        final kaputt = await ladeKurzregeln(lader: (_) async => 'kein json');

        expect(keinArray.eintraege, isEmpty);
        expect(kaputt.eintraege, isEmpty);
      },
    );
  });

  group('eingechecktes Asset', () {
    test('ist eine Liste und jeder Eintrag ist belegt und verschluesselt', () {
      final roh = ladeKatalogDatei('kurzregeln.json');
      final katalog = parseKurzregeln(roh);

      expect(katalog.verworfen, isEmpty, reason: '${katalog.verworfen}');
      expect(katalog.eintraege, hasLength(roh.length));
      final ids = katalog.eintraege.map((e) => e.id).toList();
      expect(ids.toSet(), hasLength(ids.length), reason: 'doppelte id');
      for (final eintrag in katalog.eintraege) {
        expect(eintrag.thema, isNotEmpty, reason: eintrag.id);
      }
    });

    test('Themen und Buchnamen der Belege sind bekannt', () {
      // Bewusst enge Liste: ein Tippfehler im Buchnamen soll auffallen, statt
      // einen Beleg zu erzeugen, den niemand nachschlagen kann.
      const buecher = <String>[
        'Basisregelwerk',
        'Wege des Schwerts',
        'Wege der Zauberei',
        'Errata WdS',
      ];
      final themen = kurzregelThemen.map((t) => t.schluessel).toSet();
      for (final eintrag in parseKurzregeln(
        ladeKatalogDatei('kurzregeln.json'),
      ).eintraege) {
        expect(themen, contains(eintrag.thema), reason: eintrag.id);
        for (final beleg in eintrag.quellen) {
          expect(
            buecher.any(beleg.startsWith),
            isTrue,
            reason: '${eintrag.id}: $beleg',
          );
        }
      }
    });

    test('jede Hausregel nennt ihren Beleg im Klartext', () {
      final roh = ladeKatalogDatei('kurzregeln.json');
      final mitHausregel = roh.where((e) => e.containsKey('hausregel_text'));

      expect(mitHausregel, isNotEmpty);
      for (final eintrag in mitHausregel) {
        expect(
          '${eintrag['hausregel_quelle'] ?? ''}'.trim(),
          isNotEmpty,
          reason: '${eintrag['id']}',
        );
      }
    });

    test(
      'ohne Passwort bleibt jeder Text gesperrt, kein Klartext sichtbar',
      () {
        final katalog = parseKurzregeln(ladeKatalogDatei('kurzregeln.json'));

        expect(katalog.gesperrt, isTrue);
        for (final eintrag in katalog.eintraege) {
          expect(eintrag.kurztext, isEmpty, reason: eintrag.id);
          expect(eintrag.hinweise, isEmpty, reason: eintrag.id);
          expect(eintrag.hausregelText, isEmpty, reason: eintrag.id);
          expect(eintrag.gesperrt, isTrue, reason: eintrag.id);
        }
      },
    );
  });
}
