import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/sync/gebuendelte_laeufe.dart';

void main() {
  test('Anstöße während eines Laufs ergeben genau einen Folgelauf', () async {
    final laeufe = GebuendelteLaeufe();
    final freigabe = Completer<void>();
    var anzahl = 0;
    Future<void> lauf() async {
      anzahl++;
      if (anzahl == 1) {
        await freigabe.future;
      }
    }

    final erster = laeufe.stosseAn('a', lauf);
    await Future<void>.delayed(Duration.zero);
    final zweiter = laeufe.stosseAn('a', lauf);
    final dritter = laeufe.stosseAn('a', lauf);
    expect(laeufe.laeuft('a'), isTrue);
    freigabe.complete();
    await Future.wait([erster, zweiter, dritter]);

    expect(anzahl, 2);
    expect(laeufe.laeuft('a'), isFalse);
  });

  test('verschiedene Schlüssel laufen unabhängig', () async {
    final laeufe = GebuendelteLaeufe();
    final haengt = Completer<void>();
    var bFertig = false;

    unawaited(laeufe.stosseAn('a', () => haengt.future));
    await laeufe.stosseAn('b', () async => bFertig = true);

    expect(bFertig, isTrue);
    expect(laeufe.laeuft('a'), isTrue);
    haengt.complete();
    await laeufe.warteAufAlle();
    expect(laeufe.laeuft('a'), isFalse);
  });

  test(
    'ein Fehler beendet den Durchgang, danach geht es normal weiter',
    () async {
      final laeufe = GebuendelteLaeufe();

      await expectLater(
        laeufe.stosseAn('a', () async => throw StateError('weg')),
        throwsStateError,
      );
      var danach = false;
      await laeufe.stosseAn('a', () async => danach = true);

      expect(danach, isTrue);
    },
  );

  test('nachLauf läuft einmal nach dem letzten Durchgang', () async {
    final aufrufe = <String>[];
    final laeufe = GebuendelteLaeufe(
      nachLauf: (schluessel) async => aufrufe.add(schluessel),
    );
    final freigabe = Completer<void>();

    final erster = laeufe.stosseAn('a', () => freigabe.future);
    await Future<void>.delayed(Duration.zero);
    unawaited(laeufe.stosseAn('a', () async {}));
    expect(aufrufe, isEmpty);
    freigabe.complete();
    await erster;

    expect(aufrufe, ['a']);
  });
}
