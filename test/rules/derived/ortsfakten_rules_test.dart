import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/avesmaps_ort.dart';
import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/domain/ortsfakten.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ortsfakten_rules.dart';

const OrtsfaktenKatalog _katalog = OrtsfaktenKatalog(
  siedlungen: <String, SiedlungsFakten>{
    'Punin': SiedlungsFakten(
      einwohner: 27500,
      einwohnerText: '27500 (davon 2500 Tulamiden, 1040 BF)',
      oberhaupt: 'Ratsmeister',
    ),
    'Havena (Siedlung)': SiedlungsFakten(einwohner: 9000),
  },
  bauwerke: <String, List<OrtsBauwerk>>{
    'Punin': <OrtsBauwerk>[
      OrtsBauwerk(name: 'Yaquirbühne', ort: 'Punin', art: 'Theater'),
      OrtsBauwerk(
        name: 'Phex-Tempel in Punin',
        ort: 'Punin',
        art: 'Tempel',
        zugehoerigkeit: 'Phex-Kirche',
      ),
      OrtsBauwerk(
        name: 'Akademie der Hohen Magie',
        ort: 'Punin',
        seite: 'Akademie der Hohen Magie (Punin)',
        art: 'Magierakademie',
      ),
      OrtsBauwerk(name: 'Boronanger', ort: 'Punin', art: 'Heiligtum'),
      OrtsBauwerk(name: 'Palacio Galandi', ort: 'Punin', art: 'Wohnhaus'),
      OrtsBauwerk(name: 'Dunkle Halle', ort: 'Punin', art: 'Unheiligtum'),
      OrtsBauwerk(name: 'Alte Mühle', ort: 'Punin', art: 'Mühle'),
    ],
  },
);

void main() {
  test('Auskunft über den Wiki-Seitennamen, nur für Siedlungen', () {
    final punin = ortsAuskunft(
      OrtEintrag(name: 'Punin', art: OrtArt.siedlung),
      _katalog,
    );
    expect(punin.fakten!.oberhaupt, 'Ratsmeister');
    expect(punin.tempel, hasLength(2));
    expect(punin.wichtigeOrte, hasLength(5));

    final havena = ortsAuskunft(
      OrtEintrag(
        name: 'Havena',
        art: OrtArt.siedlung,
        seite: 'Havena (Siedlung)',
      ),
      _katalog,
    );
    expect(havena.fakten!.einwohner, 9000);

    expect(
      ortsAuskunft(
        OrtEintrag(name: 'Punin', art: OrtArt.region),
        _katalog,
      ).istLeer,
      isTrue,
    );
    expect(ortsAuskunft(null, _katalog).istLeer, isTrue);
  });

  test('Tempel getrennt, übrige Bauwerke nach Bedeutung', () {
    final auskunft = ortsAuskunft(
      OrtEintrag(name: 'Punin', art: OrtArt.siedlung),
      _katalog,
    );
    expect(auskunft.tempel.map((b) => b.name), <String>[
      'Boronanger',
      'Phex-Tempel in Punin',
    ]);
    // Akademie, Theater und Unheiligtum sind bedeutend (in dieser
    // Reihenfolge), die Mühle sonstig, das Wohnhaus nebensächlich; ein
    // Unheiligtum ist kein Tempel.
    expect(auskunft.wichtigeOrte.map((b) => b.name), <String>[
      'Akademie der Hohen Magie',
      'Yaquirbühne',
      'Dunkle Halle',
      'Alte Mühle',
      'Palacio Galandi',
    ]);
  });

  test('Einwohner mit Tausenderpunkten, Zusatz bleibt', () {
    expect(mitTausenderpunkten(170000), '170.000');
    expect(mitTausenderpunkten(950), '950');
    expect(mitTausenderpunkten(1234567), '1.234.567');
    expect(
      einwohnerAnzeige(_katalog.siedlungen['Punin']!),
      '27.500 (davon 2500 Tulamiden, 1040 BF)',
    );
    expect(einwohnerAnzeige(const SiedlungsFakten(einwohner: 9000)), '9.000');
    expect(
      einwohnerAnzeige(const SiedlungsFakten(einwohnerText: 'einige Hundert')),
      'einige Hundert',
    );
  });

  test('Bauwerkzeile und Wiki-Link über den vollen Seitennamen', () {
    final akademie = _katalog.bauwerke['Punin']![2];
    expect(bauwerkZeile(akademie), 'Magierakademie');
    expect(
      bauwerkZeile(_katalog.bauwerke['Punin']![1]),
      'Tempel · Phex-Kirche',
    );
    expect(
      '${bauwerkLink(akademie)}',
      'https://de.wiki-aventurica.de/wiki/Akademie_der_Hohen_Magie_(Punin)',
    );
  });

  test('der Avesmaps-Ort findet seinen Eintrag über Kennung oder Namen', () {
    final verzeichnis = <OrtEintrag>[
      OrtEintrag(name: 'Punin', art: OrtArt.region),
      OrtEintrag(
        name: 'Punin',
        art: OrtArt.siedlung,
      ).mitKartenposition(ortId: 'p1', kartenX: 1, kartenY: 2),
      OrtEintrag(name: 'Gareth', art: OrtArt.siedlung),
    ];
    const punin = AvesmapsOrt(id: 'p1', name: 'Punin', x: 1, y: 2);
    const gareth = AvesmapsOrt(id: 'g', name: 'Gareth', x: 0, y: 0);
    const weg = AvesmapsOrt(id: 'x', name: 'Nirgendwo', x: 0, y: 0);
    expect(ortsEintragZu(punin, verzeichnis)!.art, OrtArt.siedlung);
    expect(ortsEintragZu(gareth, verzeichnis)!.name, 'Gareth');
    expect(ortsEintragZu(weg, verzeichnis), isNull);
  });

  test('Vielfalt: reihum je Art statt fünf Botschaften am Stück', () {
    OrtsBauwerk b(String name, String art) =>
        OrtsBauwerk(name: name, ort: 'Gareth', art: art);
    final reihe = reiheNachVielfalt(<OrtsBauwerk>[
      b('Botschaft A', 'Botschaft'),
      b('Botschaft B', 'Botschaft'),
      b('Botschaft C', 'Botschaft'),
      b('Alte Residenz', 'Palast'),
      b('Neue Residenz', 'Palast'),
      b('Burg Gareth', 'Burg'),
      b('Haus Alrik', 'Wohnhaus'),
    ]).map((x) => x.name);
    expect(reihe, <String>[
      'Alte Residenz',
      'Burg Gareth',
      'Botschaft A',
      'Neue Residenz',
      'Botschaft B',
      'Botschaft C',
      'Haus Alrik',
    ]);
  });

  test('Tempel nach Gottheit, die meisten zuerst, Weitere zuletzt', () {
    OrtsBauwerk t(String name, String zugehoerigkeit) => OrtsBauwerk(
      name: name,
      ort: 'Punin',
      art: 'Tempel',
      zugehoerigkeit: zugehoerigkeit,
    );
    final gruppen = tempelNachGottheit(<OrtsBauwerk>[
      t('A', 'Boron-Kirche: Puniner Ritus'),
      t('B', "Boron-Kirche (Al'Anfaner Ritus)"),
      t('C', 'Rastullah-Glauben'),
      t('D', ''),
      t('E', 'Kult des Namenlosen'),
      t('F', 'Phex-Kirche'),
    ]);
    expect(gruppen.map((g) => (g.$1, g.$2.length)), <(String, int)>[
      ('Boron', 2),
      ('Kult des Namenlosen', 1),
      ('Phex', 1),
      ('Rastullah', 1),
      ('Weitere', 1),
    ]);
  });

  test('Einwohner in Zahl und Zusatz', () {
    expect(
      einwohnerTeile(
        const SiedlungsFakten(
          einwohner: 105000,
          einwohnerText: '105000 (davon 25000 Sklaven) (1040 BF)',
        ),
      ),
      ('105.000', 'davon 25000 Sklaven; 1040 BF'),
    );
    expect(
      einwohnerTeile(
        const SiedlungsFakten(einwohner: 950, einwohnerText: '950'),
      ),
      ('950', ''),
    );
    expect(
      einwohnerTeile(const SiedlungsFakten(einwohnerText: 'einige Hundert')),
      (null, 'einige Hundert'),
    );
  });
}
