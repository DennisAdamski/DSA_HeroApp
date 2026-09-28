import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/avatar_gesicht/avatar_gesichtserkennung.dart';
import 'package:dsa_heldenverwaltung/data/avatar_gesicht_cache.dart';
import 'package:dsa_heldenverwaltung/data/avatar_gesicht_service.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_gesichtsbefund.dart';

class _ZaehlendeErkennung implements AvatarGesichtserkennung {
  _ZaehlendeErkennung({this.antwort, this.fehler});

  final Completer<AvatarGesichtsbefund>? antwort;
  final Object? fehler;
  int aufrufe = 0;

  @override
  Future<AvatarGesichtsbefund> erkenne(Uint8List bildBytes) async {
    aufrufe++;
    if (fehler != null) throw fehler!;
    final ausstehend = antwort;
    if (ausstehend != null) return ausstehend.future;
    return _befund;
  }
}

class _ProtokollierendeErkennung implements AvatarGesichtserkennung {
  _ProtokollierendeErkennung(this.protokoll, this.antworten);

  final List<String> protokoll;
  final Map<int, Future<AvatarGesichtsbefund>> antworten;

  @override
  Future<AvatarGesichtsbefund> erkenne(Uint8List bildBytes) async {
    final laenge = bildBytes.length;
    protokoll.add('start $laenge');
    final befund = await (antworten[laenge] ?? Future.value(_befund));
    protokoll.add('ende $laenge');
    return befund;
  }
}

const _befund = AvatarGesichtsbefund(
  bildBreite: 400,
  bildHoehe: 600,
  gesicht: AvatarGesichtsrahmen(links: 0.3, oben: 0.2, breite: 0.4, hoehe: 0.3),
  konfidenz: 0.9,
);

void main() {
  final bytes = Uint8List.fromList(List<int>.filled(32, 7));

  AvatarGesichtService service(
    AvatarGesichtserkennung erkennung,
    InMemoryAvatarGesichtCache cache, {
    Duration zeitlimit = const Duration(seconds: 5),
  }) {
    return AvatarGesichtService(
      erkennung: erkennung,
      cacheFuer: (_) => cache,
      zeitlimit: zeitlimit,
    );
  }

  test('erkennt beim ersten Aufruf und legt den Befund im Cache ab', () async {
    final erkennung = _ZaehlendeErkennung();
    final cache = InMemoryAvatarGesichtCache();

    final befund = await service(
      erkennung,
      cache,
    ).befund(heroStoragePath: '/helden', fileName: 'a.png', bytes: bytes);

    expect(befund, _befund);
    expect(erkennung.aufrufe, 1);
    final eintrag = cache.eintraege['a.png']!;
    expect(eintrag.version, kAvatarGesichtDetektorVersion);
    expect(eintrag.byteLaenge, bytes.length);
  });

  test('ein Cache-Treffer erspart die Erkennung', () async {
    final erkennung = _ZaehlendeErkennung();
    final cache = InMemoryAvatarGesichtCache()
      ..eintraege['a.png'] = AvatarGesichtCacheEintrag(
        version: kAvatarGesichtDetektorVersion,
        byteLaenge: bytes.length,
        befund: _befund,
      );

    final befund = await service(
      erkennung,
      cache,
    ).befund(heroStoragePath: '/helden', fileName: 'a.png', bytes: bytes);

    expect(befund, _befund);
    expect(erkennung.aufrufe, 0);
  });

  test('andere Detektorversion oder Dateigroesse erkennt neu', () async {
    for (final veraltet in [
      AvatarGesichtCacheEintrag(
        version: kAvatarGesichtDetektorVersion - 1,
        byteLaenge: bytes.length,
        befund: _befund,
      ),
      AvatarGesichtCacheEintrag(
        version: kAvatarGesichtDetektorVersion,
        byteLaenge: bytes.length + 1,
        befund: _befund,
      ),
    ]) {
      final erkennung = _ZaehlendeErkennung();
      final cache = InMemoryAvatarGesichtCache()..eintraege['a.png'] = veraltet;

      await service(
        erkennung,
        cache,
      ).befund(heroStoragePath: '/helden', fileName: 'a.png', bytes: bytes);

      expect(erkennung.aufrufe, 1);
      expect(cache.eintraege['a.png']!.byteLaenge, bytes.length);
    }
  });

  test('ein Erkennungsfehler ergibt null und wird nicht gecacht', () async {
    final erkennung = _ZaehlendeErkennung(fehler: StateError('kaputt'));
    final cache = InMemoryAvatarGesichtCache();

    final befund = await service(
      erkennung,
      cache,
    ).befund(heroStoragePath: '/helden', fileName: 'a.png', bytes: bytes);

    expect(befund, isNull);
    expect(cache.schreibvorgaenge, 0);
  });

  test('nach dem Zeitlimit kommt null, das Ergebnis landet trotzdem im '
      'Cache', () async {
    final antwort = Completer<AvatarGesichtsbefund>();
    final erkennung = _ZaehlendeErkennung(antwort: antwort);
    final cache = InMemoryAvatarGesichtCache();

    final befund = await service(
      erkennung,
      cache,
      zeitlimit: const Duration(milliseconds: 10),
    ).befund(heroStoragePath: '/helden', fileName: 'a.png', bytes: bytes);

    expect(befund, isNull);
    antwort.complete(_befund);
    await Future<void>.delayed(Duration.zero);
    expect(cache.eintraege['a.png']!.befund, _befund);
  });

  test('gleichzeitige Anfragen teilen sich eine Erkennung', () async {
    final antwort = Completer<AvatarGesichtsbefund>();
    final erkennung = _ZaehlendeErkennung(antwort: antwort);
    final dienst = service(erkennung, InMemoryAvatarGesichtCache());

    final erste = dienst.befund(
      heroStoragePath: '/helden',
      fileName: 'a.png',
      bytes: bytes,
    );
    final zweite = dienst.befund(
      heroStoragePath: '/helden',
      fileName: 'a.png',
      bytes: bytes,
    );
    await Future<void>.delayed(Duration.zero);
    antwort.complete(_befund);

    expect(await erste, _befund);
    expect(await zweite, _befund);
    expect(erkennung.aufrufe, 1);
  });

  test('verschiedene Bilder werden nacheinander erkannt', () async {
    final erste = Completer<AvatarGesichtsbefund>();
    final reihenfolge = <String>[];
    final erkennung = _ProtokollierendeErkennung(reihenfolge, {
      1: erste.future,
    });
    final dienst = service(erkennung, InMemoryAvatarGesichtCache());

    final a = dienst.befund(
      heroStoragePath: '/helden',
      fileName: 'a.png',
      bytes: Uint8List.fromList([1]),
    );
    final b = dienst.befund(
      heroStoragePath: '/helden',
      fileName: 'b.png',
      bytes: Uint8List.fromList([2, 2]),
    );
    await Future<void>.delayed(Duration.zero);
    expect(reihenfolge, ['start 1']);

    erste.complete(_befund);
    await a;
    await b;
    expect(reihenfolge, ['start 1', 'ende 1', 'start 2', 'ende 2']);
  });

  test('ohne Dateiname oder Bytes wird nichts erkannt', () async {
    final erkennung = _ZaehlendeErkennung();
    final dienst = service(erkennung, InMemoryAvatarGesichtCache());

    expect(
      await dienst.befund(heroStoragePath: '/', fileName: '', bytes: bytes),
      isNull,
    );
    expect(
      await dienst.befund(
        heroStoragePath: '/',
        fileName: 'a.png',
        bytes: Uint8List(0),
      ),
      isNull,
    );
    expect(erkennung.aufrufe, 0);
  });

  test('Cache-Eintrag uebersteht die Serialisierung', () {
    final eintrag = AvatarGesichtCacheEintrag(
      version: 3,
      byteLaenge: 1234,
      befund: _befund,
    );

    final gelesen = AvatarGesichtCacheEintrag.fromJson(eintrag.toJson())!;

    expect(gelesen.version, 3);
    expect(gelesen.byteLaenge, 1234);
    expect(gelesen.befund, _befund);
    expect(
      AvatarGesichtCacheEintrag.fromJson(const {
        'v': 1,
        'n': 1,
        'b': {'w': 10, 'h': 10},
      })!.befund.gesicht,
      isNull,
    );
    expect(AvatarGesichtCacheEintrag.fromJson(const {'v': 1}), isNull);
  });
}
