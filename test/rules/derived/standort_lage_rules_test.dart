import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/avesmaps_ort.dart';
import 'package:dsa_heldenverwaltung/domain/avesmaps_ortsdetails.dart';
import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/rules/derived/standort_lage_rules.dart';

// Gareth und Umgebung mit den Werten der Entwickler-API v1 (13.11.2026),
// ergänzt um erfundene Punkte für Richtungen und Ränder.
const AvesmapsOrt _gareth = AvesmapsOrt(
  id: '80558060-4299-54aa-b520-814b10819885',
  name: 'Gareth',
  art: 'metropole',
  x: 551.625,
  y: 532.969,
);

AvesmapsOrt _ort(
  String id,
  String name,
  String art, {
  required double ost,
  required double nord,
}) => AvesmapsOrt(
  id: id,
  name: name,
  art: art,
  x: _gareth.x + ost,
  y: _gareth.y + nord,
);

final List<AvesmapsOrt> _umgebung = <AvesmapsOrt>[
  _gareth,
  _ort('fehring', 'Fehring', 'dorf', ost: 0, nord: 1.2),
  _ort('schloss', 'Schloss Schickelsfeld', 'gebaeude', ost: 0.5, nord: 0),
  _ort('viertel', 'Alt-Gareth', 'stadtviertel', ost: 0.1, nord: 0.1),
  _ort('possel', 'Possel', 'kleinstadt', ost: 2, nord: -1),
  _ort('kronling', 'Kronling', 'stadt', ost: -2, nord: 2),
  _ort('wehrheim', 'Wehrheim', 'stadt', ost: 6, nord: 6),
  _ort('fern', 'Fernhausen', 'dorf', ost: 0, nord: -30),
];

void main() {
  group('Himmelsrichtung', () {
    test('y wächst nach Norden, x nach Osten', () {
      Himmelsrichtung r(double ost, double nord) =>
          Himmelsrichtung.zwischen(0, 0, ost, nord);
      expect(r(0, 1), Himmelsrichtung.n);
      expect(r(1, 1), Himmelsrichtung.no);
      expect(r(1, 0), Himmelsrichtung.o);
      expect(r(1, -1), Himmelsrichtung.so);
      expect(r(0, -1), Himmelsrichtung.s);
      expect(r(-1, -1), Himmelsrichtung.sw);
      expect(r(-1, 0), Himmelsrichtung.w);
      expect(r(-1, 1), Himmelsrichtung.nw);
      // Knapp an der Grenze zwischen N und NO (22,5°).
      expect(r(0.4, 1), Himmelsrichtung.n);
      expect(r(0.42, 1), Himmelsrichtung.no);
    });
  });

  group('ortZumStandort', () {
    test('folgt der Kennung des verbundenen Verzeichnisses', () {
      final verzeichnis = <OrtEintrag>[
        OrtEintrag(
          name: 'Gareth',
          art: OrtArt.siedlung,
          ortId: _gareth.id,
          kartenX: _gareth.x,
          kartenY: _gareth.y,
        ),
      ];
      expect(ortZumStandort(' gareth ', verzeichnis, _umgebung), same(_gareth));
    });

    test('ohne Verzeichnis nur ein eindeutig gleicher Name', () {
      expect(ortZumStandort('Kronling', const [], _umgebung)?.id, 'kronling');
      final doppelt = <AvesmapsOrt>[
        ..._umgebung,
        _ort('kronling2', 'Kronling', 'dorf', ost: 50, nord: 50),
      ];
      expect(ortZumStandort('Kronling', const [], doppelt), isNull);
      expect(
        ortZumStandort('Auf der Reichsstraße', const [], _umgebung),
        isNull,
      );
      expect(ortZumStandort('', const [], _umgebung), isNull);
      expect(ortZumStandort('Gareth', const [], const []), isNull);
    });
  });

  group('orteInDerNaehe', () {
    test('nur Siedlungen, nächste zuerst, ohne den Ort selbst', () {
      final nahe = orteInDerNaehe(_gareth, _umgebung, limit: 10);
      expect(nahe.map((n) => n.ort.id), <String>[
        'fehring',
        'possel',
        'kronling',
        'wehrheim',
        'fern',
      ]);
      expect(nahe.first.meilen, closeTo(3.6, 0.001));
      expect(nahe.first.richtung, Himmelsrichtung.n);
      expect(nahe.first.abstandText, '3,6 Meilen N');
      expect(nahe[3].richtung, Himmelsrichtung.no);
      expect(nahe.last.abstandText, '90 Meilen S');
    });

    test('begrenzt die Zahl der Einträge', () {
      expect(orteInDerNaehe(_gareth, _umgebung, limit: 2), hasLength(2));
      expect(orteInDerNaehe(_gareth, _umgebung, limit: 0), isEmpty);
    });
  });

  test('formatiereMeilen', () {
    expect(formatiereMeilen(3.64), '3,6 Meilen');
    expect(formatiereMeilen(1.0), '1 Meile');
    expect(formatiereMeilen(7.98), '8 Meilen');
    expect(formatiereMeilen(24.4), '24 Meilen');
  });

  group('Ortsdetails', () {
    final details = AvesmapsOrtsdetails.ausJson(<String, Object?>{
      'vertrag': 1,
      'id': _gareth.id,
      'name': 'Gareth',
      'art': 'metropole',
      'x': 551.625,
      'y': 532.969,
      'wiki': <String, Object?>{
        'url': 'https://de.wiki-aventurica.de/wiki/Gareth',
        'titel': 'Gareth',
      },
      'gebiete': <Object?>[
        <Object?>[
          <String, Object?>{
            'id': 'a',
            'name': 'Heiliges Neues Kaiserreich vom Greifenthron zu Gareth',
            'art': 'Kaiserreich',
          },
          <String, Object?>{
            'id': 'b',
            'name': 'Königreich Garetien',
            'art': 'Königreich',
          },
          <String, Object?>{'id': 'c', 'name': 'Kaisermark Gareth'},
          <String, Object?>{'id': 'd', 'name': 'Alt-Gareth', 'neu': 1},
          // Unlesbar: fällt weg.
          <String, Object?>{'name': 'ohne Kennung'},
        ],
        'keine Liste',
      ],
      'unbekanntesFeld': true,
    });

    test('lesen tolerant', () {
      expect(details, isNotNull);
      expect(details!.ort.name, 'Gareth');
      expect(details.wikiUrl, 'https://de.wiki-aventurica.de/wiki/Gareth');
      expect(details.gebiete, hasLength(1));
      expect(details.gebiete.single, hasLength(4));
      expect(details.gebiete.single[2].art, '');
      expect(AvesmapsOrtsdetails.ausJson(<String, Object?>{'id': 'x'}), isNull);
    });

    test('Gebietszeile innen nach außen, Reich getrennt', () {
      expect(
        gebietsZeile(details),
        'Alt-Gareth · Kaisermark Gareth · Königreich Garetien',
      );
      expect(
        reichDesOrts(details),
        'Heiliges Neues Kaiserreich vom Greifenthron zu Gareth',
      );
      expect(gebietsZeile(null), '');
      expect(reichDesOrts(null), '');
    });

    test('kurze Ketten bleiben ganz', () {
      final kurz = AvesmapsOrtsdetails(
        ort: _gareth,
        gebiete: const <List<AvesmapsGebiet>>[
          <AvesmapsGebiet>[
            AvesmapsGebiet(id: 'a', name: 'Thorwal'),
            AvesmapsGebiet(id: 'b', name: 'Hjaldingard'),
          ],
        ],
      );
      expect(gebietsZeile(kurz), 'Hjaldingard · Thorwal');
    });
  });

  group('avesmapsOrtLink folgt der Regel der Seite', () {
    test('mit Wiki-Artikel über den Seitennamen', () {
      expect(
        '${avesmapsOrtLink(wikiUrl: 'https://de.wiki-aventurica.de/wiki/Gareth', id: _gareth.id, name: 'Gareth')}',
        'https://avesmaps.de/?siedlung=Gareth',
      );
      expect(
        '${avesmapsOrtLink(wikiUrl: 'https://de.wiki-aventurica.de/wiki/Havena_(Siedlung)#Lage')}',
        'https://avesmaps.de/?siedlung=Havena_(Siedlung)',
      );
    });

    test('ohne Artikel über die Kennung, sonst über den Namen', () {
      expect(
        '${avesmapsOrtLink(id: 'fehring', name: 'Fehring')}',
        'https://avesmaps.de/?place=fehring',
      );
      expect(
        '${avesmapsOrtLink(name: 'Gareth')}',
        'https://avesmaps.de/?siedlung=Gareth',
      );
      expect(avesmapsOrtLink(), isNull);
    });
  });

  test('kartenpositionText', () {
    expect(kartenpositionText(_gareth), 'x 551,6 · y 533,0');
  });

  group('lageskizze', () {
    test('wählt den kleinsten Halbmesser mit genug Siedlungen', () {
      final dicht = <AvesmapsOrt>[
        _gareth,
        for (var i = 0; i < kSkizzeMindestOrte; i++)
          _ort('d$i', 'Dorf $i', 'dorf', ost: 1 + i * 0.3, nord: 0),
      ];
      expect(lageskizze(_gareth, dicht).radiusMeilen, kSkizzenRadien.first);
      // Zu wenige Orte: der größte Halbmesser.
      expect(lageskizze(_gareth, _umgebung).radiusMeilen, kSkizzenRadien.last);
    });

    test('normiert die Versätze und lässt Gebäude und Ränder weg', () {
      final skizze = lageskizze(_gareth, _umgebung);
      final einheiten = skizze.radiusMeilen / 3;
      final fehring = skizze.punkte.singleWhere((p) => p.ort.id == 'fehring');
      expect(fehring.dx, 0);
      expect(fehring.dy, closeTo(1.2 / einheiten, 1e-9));
      final ids = skizze.punkte.map((p) => p.ort.id).toSet();
      expect(ids, isNot(contains('schloss')));
      expect(ids, isNot(contains('viertel')));
      expect(ids, isNot(contains(_gareth.id)));
      // Fernhausen liegt 90 Meilen südlich, innerhalb von 120.
      expect(ids, contains('fern'));
    });

    test('beschriftet bedeutende Orte, zeichnet sie zuletzt', () {
      final skizze = lageskizze(_gareth, _umgebung);
      final beschriftet = {
        for (final p in skizze.punkte)
          if (p.beschriftet) p.ort.id,
      };
      expect(beschriftet, <String>{'possel', 'kronling', 'wehrheim'});
      expect(skizze.punkte.last.rang, 3);
      expect(skizze.punkte.first.rang, 1);
    });

    test('höchstens kSkizzeMaxNamen Namen', () {
      final viele = <AvesmapsOrt>[
        _gareth,
        for (var i = 0; i < 10; i++)
          _ort('s$i', 'Stadt $i', 'stadt', ost: i * 0.5, nord: 1),
      ];
      final skizze = lageskizze(_gareth, viele);
      expect(skizze.punkte.where((p) => p.beschriftet), hasLength(6));
    });
  });
}
