import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/aventurian_date.dart';
import 'package:dsa_heldenverwaltung/domain/aventurischer_feiertag.dart';
import 'package:dsa_heldenverwaltung/rules/derived/aventurian_holiday_data.dart';
import 'package:dsa_heldenverwaltung/rules/derived/aventurian_holiday_rules.dart';

AventurianDate _d(String tag, String monat) =>
    AventurianDate(day: tag, month: monat, year: '1043');

Map<String, int> _abstaende(AventurianDate datum) => {
  for (final t in feiertageInDerNaehe(datum)) t.feiertag.name: t.abstandTage,
};

void main() {
  group('Feiertagstabelle', () {
    test('liegt vollständig im Jahr und hat Namen', () {
      expect(aventurischeFeiertage, isNotEmpty);
      for (final f in aventurischeFeiertage) {
        expect(f.name.trim(), isNotEmpty);
        expect(f.vonTagImJahr, inInclusiveRange(1, 365), reason: f.name);
        expect(f.bisTagImJahr, inInclusiveRange(1, 365), reason: f.name);
      }
    });

    test('religiöse Feiertage nennen ihre Gottheit', () {
      for (final f in aventurischeFeiertage.where(
        (f) => f.art == FeiertagArt.religioes,
      )) {
        expect(f.gottheit, isNotNull, reason: f.name);
      }
    });

    test('Tag und Monat ergeben die laufende Nummer im Jahr', () {
      final schwur = aventurischeFeiertage.firstWhere(
        (f) => f.name == 'Tag des Schwures',
      );
      // Praios 30 Tage, dazu der 5. Rondra.
      expect(schwur.vonTagImJahr, 35);
      expect(schwur.istEintaegig, isTrue);
      expect(schwur.dauerTage, 1);
    });

    test('ein Zeitraum über den Monatswechsel hat die richtige Dauer', () {
      final erneuerung = aventurischeFeiertage.firstWhere(
        (f) => f.name == 'Tag der Erneuerung',
      );
      expect(erneuerung.dauerTage, 2);
    });

    test('ein unbekannter Monat oder Tag ist ein Fehler der Tabelle', () {
      expect(
        () => AventurischerFeiertag.am(
          name: 'x',
          tag: 1,
          monat: 'nirgendwo',
          art: FeiertagArt.weltlich,
        ),
        throwsArgumentError,
      );
      expect(
        () => AventurischerFeiertag.am(
          name: 'x',
          tag: 6,
          monat: 'namenlose_tage',
          art: FeiertagArt.weltlich,
        ),
        throwsArgumentError,
      );
    });
  });

  group('feiertageInDerNaehe', () {
    test('findet Vergangenes und Bevorstehendes mit Abstand', () {
      // 8. Rondra: Nationalfeiertag läuft (6.–9.), Schwur war vor 3 Tagen,
      // Bosparans Fall ist heute, das Schwertfest in 7 Tagen.
      final abstaende = _abstaende(_d('8', 'rondra'));
      expect(abstaende['Tag des Schwures'], -3);
      expect(abstaende['Nationalfeiertag im Mittelreich'], 0);
      expect(abstaende['Bosparans Fall'], 0);
      expect(abstaende['Schwertfest'], 7);
      expect(abstaende.containsKey('Maraskanisches Neujahrsfest'), isTrue);
    });

    test('sortiert Vergangenes zuerst und dann nach Name', () {
      final treffer = feiertageInDerNaehe(_d('8', 'rondra'));
      final abstaende = treffer.map((t) => t.abstandTage).toList();
      expect(abstaende, orderedEquals([...abstaende]..sort()));
      final heute = treffer.where((t) => t.abstandTage == 0).toList();
      expect(heute.map((t) => t.feiertag.name), [
        'Bosparans Fall',
        'Nationalfeiertag im Mittelreich',
      ]);
    });

    test('ein laufender Zeitraum hat Abstand 0 an jedem seiner Tage', () {
      for (final tag in ['6', '7', '8', '9']) {
        expect(
          _abstaende(_d(tag, 'rondra'))['Nationalfeiertag im Mittelreich'],
          0,
          reason: '$tag. Rondra',
        );
      }
      expect(
        _abstaende(_d('10', 'rondra'))['Nationalfeiertag im Mittelreich'],
        -1,
      );
      expect(
        _abstaende(_d('5', 'rondra'))['Nationalfeiertag im Mittelreich'],
        1,
      );
    });

    test('hält das Fenster ein', () {
      // Das Schwertfest (15. Rondra) liegt 14 Tage nach dem 1. Rondra.
      expect(_abstaende(_d('1', 'rondra')).containsKey('Schwertfest'), isTrue);
      // Am Vortag wären es 15 Tage.
      expect(
        _abstaende(_d('30', 'praios')).containsKey('Schwertfest'),
        isFalse,
      );
      // Der 5. Rondra liegt am 12. Rondra genau 7 Tage zurück, am 13. 8.
      expect(
        _abstaende(_d('12', 'rondra')).containsKey('Tag des Schwures'),
        isTrue,
      );
      expect(
        _abstaende(_d('13', 'rondra')).containsKey('Tag des Schwures'),
        isFalse,
      );
    });

    test('rechnet über den Jahreswechsel', () {
      // 28. Rahja: Namenlose Tage und Sommersonnenwende sind in Reichweite.
      final abstaende = _abstaende(_d('28', 'rahja'));
      expect(abstaende['Reinigungsfest'], 2);
      expect(abstaende['3. Rastullahellah'], 3);
      expect(abstaende['Sommersonnenwende'], 8);

      // 2. Namenloser Tag: 1. Praios in vier Tagen, Reinigungsfest vor 2.
      final spaet = _abstaende(_d('2', 'namenlose_tage'));
      expect(spaet['Sommersonnenwende'], 4);
      expect(spaet['Reinigungsfest'], -2);

      // 3. Praios: der Jahreswechsel liegt hinter dem Datum.
      expect(_abstaende(_d('3', 'praios'))['3. Rastullahellah'], -7);
    });

    test('ein Zeitraum über den Monatswechsel wird gefunden', () {
      final abstaende = _abstaende(_d('1', 'phex'));
      expect(abstaende['Tag der Erneuerung'], 0);
      expect(_abstaende(_d('29', 'tsa'))['Tag der Erneuerung'], 1);
    });

    test('Jahr und Wochentag spielen keine Rolle', () {
      expect(
        _abstaende(AventurianDate(day: '5', month: 'rondra')),
        _abstaende(_d('5', 'rondra')),
      );
    });

    test('nicht lesbare Daten ergeben nichts', () {
      expect(feiertageInDerNaehe(const AventurianDate()), isEmpty);
      expect(feiertageInDerNaehe(_d('', 'rondra')), isEmpty);
      expect(feiertageInDerNaehe(_d('5', '')), isEmpty);
      expect(feiertageInDerNaehe(_d('31', 'rondra')), isEmpty);
      expect(feiertageInDerNaehe(_d('6', 'namenlose_tage')), isEmpty);
    });

    test('Fenster und Filter lassen sich einschränken', () {
      final nurHeute = feiertageInDerNaehe(
        _d('8', 'rondra'),
        tageDavor: 0,
        tageDanach: 0,
      );
      expect(nurHeute.map((t) => t.abstandTage).toSet(), {0});

      final ohneNovadis = feiertageInDerNaehe(
        _d('9', 'efferd'),
        filter: (f) => f.verbreitung != 'Novadis',
      );
      expect(
        ohneNovadis.any((t) => t.feiertag.name == '4. Rastullahellah'),
        isFalse,
      );
      expect(
        feiertageInDerNaehe(_d('9', 'efferd'))
            .any((t) => t.feiertag.name == '4. Rastullahellah'),
        isTrue,
      );
    });
  });

  group('Texte', () {
    AventurischerFeiertag nach(String name) =>
        aventurischeFeiertage.firstWhere((f) => f.name == name);

    test('Datum', () {
      expect(feiertagDatumText(nach('Tag des Schwures')), '5. Rondra');
      expect(
        feiertagDatumText(nach('Nationalfeiertag im Mittelreich')),
        '6.–9. Rondra',
      );
      expect(
        feiertagDatumText(nach('Tag der Erneuerung')),
        '30. Tsa – 1. Phex',
      );
      expect(feiertagDatumText(nach('3. Rastullahellah')), '1. Namenlose Tage');
    });

    test('Abstand', () {
      expect(feiertagAbstandText(0), 'heute');
      expect(feiertagAbstandText(1), 'morgen');
      expect(feiertagAbstandText(-1), 'gestern');
      expect(feiertagAbstandText(3), 'in 3 Tagen');
      expect(feiertagAbstandText(-2), 'vor 2 Tagen');
    });

    test('Geltung', () {
      expect(
        feiertagGeltungText(nach('Tag des Schwures')),
        'Rondra · zwölfgöttergläubige Lande',
      );
      expect(feiertagGeltungText(nach('Bosparans Fall')), 'Liebliches Feld');
      expect(
        feiertagGeltungText(
          const AventurischerFeiertag(
            name: 'x',
            vonTagImJahr: 1,
            bisTagImJahr: 1,
            art: FeiertagArt.weltlich,
          ),
        ),
        '',
      );
    });
  });
}
