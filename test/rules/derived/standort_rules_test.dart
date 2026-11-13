import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/avesmaps_ort.dart';
import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/rules/derived/standort_rules.dart';

void main() {
  group('bereinigeStandort', () {
    test('entfernt Leerraum außen und faltet ihn innen', () {
      expect(bereinigeStandort('  Bad \n  Garetz  '), 'Bad Garetz');
    });

    test('leere Eingabe bleibt leer', () {
      expect(bereinigeStandort('   \n '), '');
    });

    test('kürzt auf die Höchstlänge', () {
      final lang = 'a' * (kStandortMaxLaenge + 30);
      expect(bereinigeStandort(lang).length, kStandortMaxLaenge);
    });
  });

  group('avesmapsLink', () {
    test('baut den Siedlungslink', () {
      expect(
        avesmapsLink('Gareth').toString(),
        'https://avesmaps.de/?siedlung=Gareth',
      );
    });

    test('kodiert Leerzeichen und Umlaute', () {
      final link = avesmapsLink('Bad Garetz Süd')!;
      expect(link.host, 'avesmaps.de');
      expect(link.queryParameters['siedlung'], 'Bad Garetz Süd');
      expect(link.toString(), isNot(contains(' ')));
    });

    test('ohne Standort gibt es keinen Link', () {
      expect(avesmapsLink(''), isNull);
      expect(avesmapsLink('   '), isNull);
    });
  });

  group('sucheOrte', () {
    final orte = <OrtEintrag>[
      OrtEintrag(name: 'Gareth', art: OrtArt.siedlung, region: 'Garetien'),
      OrtEintrag(name: 'Garetien', art: OrtArt.region),
      OrtEintrag(name: 'Neu-Gareth', art: OrtArt.siedlung),
      OrtEintrag(name: 'Alt Gareth', art: OrtArt.siedlung),
      OrtEintrag(name: 'Havena', art: OrtArt.siedlung, region: 'Albernia'),
      OrtEintrag(name: 'Albernia', art: OrtArt.staat),
      OrtEintrag(name: 'Kühlwasser', art: OrtArt.siedlung),
      OrtEintrag(name: 'Reichsstraße', art: OrtArt.strasse),
      OrtEintrag(name: 'Reichsstraße', art: OrtArt.region),
    ];

    List<String> namen(String eingabe, {int? limit}) => [
      for (final ort
          in limit == null
              ? sucheOrte(eingabe, orte)
              : sucheOrte(eingabe, orte, limit: limit))
        ort.name,
    ];

    test('leere Eingabe liefert nichts', () {
      expect(sucheOrte('', orte), isEmpty);
      expect(sucheOrte('   ', orte), isEmpty);
    });

    test('gleicher Name geht vor Namensanfang, Wortanfang und Teilstring', () {
      expect(namen('gareth'), <String>['Gareth', 'Alt Gareth', 'Neu-Gareth']);
      expect(namen('areth'), <String>['Gareth', 'Alt Gareth', 'Neu-Gareth']);
    });

    test('Namensanfang geht vor Wortanfang', () {
      final treffer = namen('gar');
      expect(treffer.first, 'Gareth');
      expect(
        treffer.indexOf('Garetien'),
        lessThan(treffer.indexOf('Alt Gareth')),
      );
    });

    test('Umlaute und Umschreibungen finden sich gegenseitig', () {
      expect(namen('kuehlwasser'), <String>['Kühlwasser']);
      expect(namen('KÜHL'), <String>['Kühlwasser']);
      expect(namen('reichsstrasse'), contains('Reichsstraße'));
    });

    test('Treffer in der Region listet die Orte der Region', () {
      expect(namen('albernia'), <String>['Albernia', 'Havena']);
    });

    test('bei gleichem Rang gehen Regionen vor Straßen', () {
      final arten = [
        for (final ort in sucheOrte('Reichsstraße', orte)) ort.art,
      ];
      expect(arten, <OrtArt>[OrtArt.region, OrtArt.strasse]);
    });

    test('begrenzt auf limit', () {
      expect(namen('a', limit: 2), hasLength(2));
      expect(namen('a', limit: 0), isEmpty);
    });

    test('Freitext ohne Treffer liefert nichts', () {
      expect(namen('Auf der Reichsstraße nach Gareth'), isEmpty);
    });
  });

  group('kartenlinkSinnvoll', () {
    final orte = <OrtEintrag>[
      OrtEintrag(name: 'Gareth', art: OrtArt.siedlung),
      OrtEintrag(name: 'Albernia', art: OrtArt.staat),
      OrtEintrag(name: 'Havena', art: OrtArt.staat),
      OrtEintrag(name: 'Havena', art: OrtArt.siedlung),
    ];

    test('Siedlung: ja', () {
      expect(kartenlinkSinnvoll('Gareth', orte), isTrue);
      expect(kartenlinkSinnvoll(' gareth ', orte), isTrue);
    });

    test('nur als Region oder Staat bekannt: nein', () {
      expect(kartenlinkSinnvoll('Albernia', orte), isFalse);
    });

    test('auch Siedlung gleichen Namens: ja', () {
      expect(kartenlinkSinnvoll('Havena', orte), isTrue);
    });

    test('unbekannter Freitext behält den Link, leerer nicht', () {
      expect(kartenlinkSinnvoll('Bad Garetz Süd', orte), isTrue);
      expect(kartenlinkSinnvoll('   ', orte), isFalse);
      expect(kartenlinkSinnvoll('Gareth', const <OrtEintrag>[]), isTrue);
    });
  });

  group('wikiAventuricaLink', () {
    final orte = <OrtEintrag>[
      OrtEintrag(name: 'Gareth', art: OrtArt.siedlung),
      OrtEintrag(
        name: 'Havena',
        art: OrtArt.siedlung,
        seite: 'Havena (Siedlung)',
      ),
      OrtEintrag(name: 'Thorwal', art: OrtArt.staat, seite: 'Thorwal (Staat)'),
      OrtEintrag(name: 'Thorwal', art: OrtArt.siedlung),
      OrtEintrag(name: 'Kühlwasser', art: OrtArt.siedlung),
      OrtEintrag(name: 'Alter Hafen', art: OrtArt.region),
    ];

    test('führt auf die Wiki-Seite des Orts', () {
      expect(
        wikiAventuricaLink('Gareth', orte).toString(),
        'https://de.wiki-aventurica.de/wiki/Gareth',
      );
    });

    test('nimmt den vollen Seitennamen, wenn er vom Namen abweicht', () {
      expect(
        wikiAventuricaLink('Havena', orte)!.path,
        '/wiki/Havena_(Siedlung)',
      );
    });

    test('Siedlung geht vor Staat bei gleichem Namen', () {
      expect(wikiAventuricaLink('Thorwal', orte)!.path, '/wiki/Thorwal');
    });

    test('ignoriert Schreibweise, kodiert Umlaute und Leerzeichen', () {
      expect(
        wikiAventuricaLink(' kuehlwasser ', orte)!.toString(),
        'https://de.wiki-aventurica.de/wiki/K%C3%BChlwasser',
      );
      expect(
        wikiAventuricaLink('alter hafen', orte)!.path,
        '/wiki/Alter_Hafen',
      );
    });

    test('Freitext und leerer Standort haben keinen Link', () {
      expect(wikiAventuricaLink('Auf der Reichsstraße', orte), isNull);
      expect(wikiAventuricaLink('   ', orte), isNull);
      expect(wikiAventuricaLink('Gareth', const <OrtEintrag>[]), isNull);
    });
  });

  group('verbindeOrtsverzeichnisse', () {
    final wiki = <OrtEintrag>[
      OrtEintrag(name: 'Gareth', art: OrtArt.siedlung, region: 'Garetien'),
      OrtEintrag(name: 'Garetien', art: OrtArt.region),
      OrtEintrag(
        name: 'Auweiler',
        art: OrtArt.siedlung,
        region: 'Darpatien',
        seite: 'Auweiler (Darpatien)',
      ),
      OrtEintrag(name: 'Thorwal', art: OrtArt.staat),
      OrtEintrag(name: 'Nostria', art: OrtArt.siedlung),
    ];
    const avesmaps = <AvesmapsOrt>[
      AvesmapsOrt(id: 'g', name: 'Gareth', art: 'metropole', x: 551.6, y: 533),
      AvesmapsOrt(id: 'a1', name: 'Auweiler (Darpatien)', x: 1, y: 2),
      AvesmapsOrt(id: 'a2', name: 'Auweiler (Yantibair)', x: 3, y: 4),
      AvesmapsOrt(id: 't', name: 'Thorwal', art: 'grossstadt', x: 5, y: 6),
      AvesmapsOrt(id: 'n1', name: 'Nostria', x: 7, y: 8),
      AvesmapsOrt(id: 'n2', name: 'Nostria', x: 9, y: 10),
    ];

    test('ohne Avesmaps-Orte bleibt das Wiki-Verzeichnis unverändert', () {
      expect(
        verbindeOrtsverzeichnisse(wiki, const <AvesmapsOrt>[]),
        same(wiki),
      );
    });

    test('eine Siedlung bekommt Kennung und Position, behält ihre Region', () {
      final gareth = verbindeOrtsverzeichnisse(wiki, avesmaps).first;
      expect(gareth.name, 'Gareth');
      expect(gareth.region, 'Garetien');
      expect(gareth.ortId, 'g');
      expect(gareth.kartenX, 551.6);
      expect(gareth.kartenY, 533);
      expect(gareth.hatKartenposition, isTrue);
    });

    test('der volle Wiki-Seitenname entscheidet bei Klammerzusätzen', () {
      final orte = verbindeOrtsverzeichnisse(wiki, avesmaps);
      final darpatien = orte.firstWhere((o) => o.region == 'Darpatien');
      expect(darpatien.name, 'Auweiler');
      expect(darpatien.ortId, 'a1');
      // Der zweite Auweiler kommt als eigener Eintrag mit vollem Namen dazu.
      final yantibair = orte.firstWhere((o) => o.ortId == 'a2');
      expect(yantibair.name, 'Auweiler (Yantibair)');
      expect(yantibair.art, OrtArt.siedlung);
    });

    test('Regionen und Staaten bleiben ohne Position; der gleichnamige '
        'Avesmaps-Ort kommt als Siedlung dazu', () {
      final orte = verbindeOrtsverzeichnisse(wiki, avesmaps);
      expect(
        orte.firstWhere((o) => o.art == OrtArt.staat).hatKartenposition,
        isFalse,
      );
      final stadt = orte.firstWhere((o) => o.ortId == 't');
      expect(stadt.art, OrtArt.siedlung);
      expect(stadt.unterart, 'Großstadt');
      expect(stadt.untertitel, 'Großstadt');
    });

    test('mehrdeutige Namen verknüpfen nichts, beide Orte bleiben wählbar', () {
      final orte = verbindeOrtsverzeichnisse(wiki, avesmaps);
      final nostria = orte.where((o) => o.name == 'Nostria').toList();
      expect(nostria, hasLength(3));
      expect(nostria.first.hatKartenposition, isFalse);
      expect(nostria.skip(1).map((o) => o.ortId), <String>['n1', 'n2']);
    });

    test('jeder Avesmaps-Ort erscheint genau einmal', () {
      final orte = verbindeOrtsverzeichnisse(wiki, avesmaps);
      expect(
        orte.where((o) => o.ortId.isNotEmpty).map((o) => o.ortId).toList()
          ..sort(),
        <String>['a1', 'a2', 'g', 'n1', 'n2', 't'],
      );
      expect(orte, hasLength(wiki.length + 4));
    });
  });

  group('ortsVerweisFuer', () {
    final orte = verbindeOrtsverzeichnisse(
      <OrtEintrag>[
        OrtEintrag(name: 'Gareth', art: OrtArt.siedlung),
        OrtEintrag(name: 'Garetien', art: OrtArt.region),
      ],
      const <AvesmapsOrt>[
        AvesmapsOrt(id: 'g', name: 'Gareth', x: 551.6, y: 533),
        AvesmapsOrt(id: 'n1', name: 'Nostria', x: 7, y: 8),
        AvesmapsOrt(id: 'n2', name: 'Nostria', x: 9, y: 10),
      ],
    );

    test('ein eindeutig gleicher Name verweist auf den Ort', () {
      expect(ortsVerweisFuer('  gareth ', orte)?.ortId, 'g');
    });

    test('Freitext, Regionen und leere Eingaben verweisen auf nichts', () {
      expect(ortsVerweisFuer('Auf der Reichsstraße', orte), isNull);
      expect(ortsVerweisFuer('Garetien', orte), isNull);
      expect(ortsVerweisFuer('   ', orte), isNull);
      expect(ortsVerweisFuer('Gareth', const <OrtEintrag>[]), isNull);
    });

    test('eine Umlaut-Umschreibung reicht für den Verweis nicht', () {
      final mitUmlaut = verbindeOrtsverzeichnisse(
        const <OrtEintrag>[],
        const <AvesmapsOrt>[AvesmapsOrt(id: 'l', name: 'Lauen', x: 1, y: 2)],
      );
      expect(ortsVerweisFuer('Lauen', mitUmlaut)?.ortId, 'l');
      // `suchFaltung` ließe „Laun“ und „Lauen“ zusammenfallen.
      expect(ortsVerweisFuer('Laun', mitUmlaut), isNull);
    });

    test('gleichnamige Orte verknüpft nur die ausdrückliche Auswahl', () {
      expect(ortsVerweisFuer('Nostria', orte), isNull);
      final gewaehlt = orte.firstWhere((o) => o.ortId == 'n2');
      expect(ortsVerweisFuer('Nostria', orte, gewaehlt: gewaehlt)?.ortId, 'n2');
    });

    test('die Auswahl gilt nur, solange ihr Name im Feld steht', () {
      final gewaehlt = orte.firstWhere((o) => o.ortId == 'n2');
      expect(ortsVerweisFuer('Gareth', orte, gewaehlt: gewaehlt)?.ortId, 'g');
      expect(
        ortsVerweisFuer('Nostria am Meer', orte, gewaehlt: gewaehlt),
        isNull,
      );
    });

    test('ein gewählter Online-Treffer gilt auch ohne Verzeichnis', () {
      final treffer = OrtEintrag(
        name: 'Havena',
        art: OrtArt.siedlung,
        ortId: 'h',
        kartenX: 1,
        kartenY: 2,
      );
      expect(
        ortsVerweisFuer(
          'Havena',
          const <OrtEintrag>[],
          gewaehlt: treffer,
        )?.ortId,
        'h',
      );
    });
  });
}
