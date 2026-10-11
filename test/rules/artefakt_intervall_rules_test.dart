import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/domain/aventurian_date.dart';
import 'package:dsa_heldenverwaltung/rules/derived/artefakt_intervall_rules.dart';

AventurianDate _d(String tag, String monat, [String jahr = '1027']) =>
    AventurianDate(day: tag, month: monat, year: jahr);

ArtefaktDaten _speicher({
  ArtefaktIntervall intervall = ArtefaktIntervall.woche,
  int proIntervall = 1,
  List<AventurianDate> anwendungen = const <AventurianDate>[],
}) => ArtefaktDaten(
  art: ArtefaktArt.spruchspeicherSemipermanent,
  intervall: intervall,
  anwendungenProIntervall: proIntervall,
  anwendungen: anwendungen,
);

void main() {
  group('Kalender', () {
    test('Intervalllängen: Tag 1, Woche 7, Monat 30, Jahr 365', () {
      expect(artefaktIntervallTage(ArtefaktIntervall.tag), 1);
      expect(artefaktIntervallTage(ArtefaktIntervall.woche), 7);
      expect(artefaktIntervallTage(ArtefaktIntervall.monat), 30);
      expect(artefaktIntervallTage(ArtefaktIntervall.jahr), 365);
    });

    test('Tagesnummer und Datum sind zueinander umkehrbar', () {
      for (final datum in [
        _d('1', 'praios'),
        _d('30', 'praios'),
        _d('1', 'rondra'),
        _d('30', 'rahja'),
        _d('1', 'namenlose_tage'),
        _d('5', 'namenlose_tage'),
        _d('17', 'phex', '999'),
      ]) {
        final tag = aventurischerTag(datum);
        expect(tag, isNotNull, reason: '$datum');
        expect(aventurischesDatum(tag!), datum, reason: '$datum');
      }
    });

    test('aufeinanderfolgende Tage über Monats- und Jahresgrenzen', () {
      int tag(AventurianDate d) => aventurischerTag(d)!;

      expect(tag(_d('1', 'rondra')) - tag(_d('30', 'praios')), 1);
      expect(tag(_d('1', 'namenlose_tage')) - tag(_d('30', 'rahja')), 1);
      expect(
        tag(_d('1', 'praios', '1028')) - tag(_d('5', 'namenlose_tage')),
        1,
      );
    });

    test('unvollständige oder unlesbare Daten haben keine Tagesnummer', () {
      expect(aventurischerTag(const AventurianDate()), isNull);
      expect(aventurischerTag(_d('1', 'praios', '')), isNull);
      expect(aventurischerTag(_d('', 'praios')), isNull);
      expect(aventurischerTag(_d('1', '', '1027')), isNull);
      expect(aventurischerTag(_d('31', 'praios')), isNull);
      expect(aventurischerTag(_d('6', 'namenlose_tage')), isNull);
    });
  });

  group('Stand der Anwendungen', () {
    test('ohne vermerkte Anwendung ist alles frei', () {
      final status = intervallStatus(_speicher(), _d('1', 'praios'));

      expect(status.verbraucht, 0);
      expect(status.frei, 1);
      expect(status.istFrei, isTrue);
      expect(status.fruehestensWieder, isNull);
    });

    test('einmal je Woche: sieben volle Tage dazwischen', () {
      final daten = _speicher(anwendungen: [_d('10', 'praios')]);

      final sechs = intervallStatus(daten, _d('16', 'praios'));
      final sieben = intervallStatus(daten, _d('17', 'praios'));

      expect(sechs.istFrei, isFalse);
      expect(sechs.fruehestensWieder, _d('17', 'praios'));
      expect(sieben.istFrei, isTrue);
      expect(sieben.verbraucht, 0);
    });

    test('dreimal je Woche: gleitendes Fenster der letzten sieben Tage', () {
      final daten = _speicher(
        proIntervall: 3,
        anwendungen: [_d('1', 'praios'), _d('3', 'praios'), _d('5', 'praios')],
      );

      final voll = intervallStatus(daten, _d('6', 'praios'));
      final eine = intervallStatus(daten, _d('8', 'praios'));
      final zwei = intervallStatus(daten, _d('10', 'praios'));

      expect(voll.verbraucht, 3);
      expect(voll.frei, 0);
      expect(voll.fruehestensWieder, _d('8', 'praios'));
      expect(eine.verbraucht, 2);
      expect(eine.frei, 1);
      expect(zwei.verbraucht, 1);
      expect(zwei.frei, 2);
    });

    test(
      'mehr Anwendungen als erlaubt: die älteste zuerst, nie unter 0 frei',
      () {
        final daten = _speicher(
          anwendungen: [_d('1', 'praios'), _d('2', 'praios')],
        );

        final status = intervallStatus(daten, _d('3', 'praios'));

        expect(status.frei, 0);
        // Beide zählen, bis die jüngere verfällt: erst dann sind weniger als
        // erlaubt übrig.
        expect(status.fruehestensWieder, _d('9', 'praios'));
      },
    );

    test('Tag, Monat und Jahr', () {
      final tag = _speicher(
        intervall: ArtefaktIntervall.tag,
        anwendungen: [_d('4', 'rondra')],
      );
      expect(intervallStatus(tag, _d('4', 'rondra')).istFrei, isFalse);
      expect(intervallStatus(tag, _d('5', 'rondra')).istFrei, isTrue);

      final monat = _speicher(
        intervall: ArtefaktIntervall.monat,
        anwendungen: [_d('20', 'rahja')],
      );
      // Rahja 20 → Namenlose Tage 1: 11 Tage.
      expect(
        intervallStatus(monat, _d('1', 'namenlose_tage')).istFrei,
        isFalse,
      );
      // Rahja 20 → Praios 20 des Folgejahres: 35 Tage.
      expect(
        intervallStatus(monat, _d('20', 'praios', '1028')).istFrei,
        isTrue,
      );
      expect(
        intervallStatus(monat, _d('20', 'rahja')).fruehestensWieder,
        _d('15', 'praios', '1028'),
        reason: 'Rahja 20 plus 30 Tage, über die Namenlosen Tage ins neue Jahr',
      );

      final jahr = _speicher(
        intervall: ArtefaktIntervall.jahr,
        anwendungen: [_d('1', 'praios')],
      );
      expect(intervallStatus(jahr, _d('30', 'rahja')).istFrei, isFalse);
      expect(intervallStatus(jahr, _d('1', 'praios', '1028')).istFrei, isTrue);
    });

    test('eine Anwendung ohne Datum zählt, bis der Nutzer regeneriert', () {
      final daten = _speicher(anwendungen: [const AventurianDate()]);

      final status = intervallStatus(daten, _d('1', 'praios', '2000'));

      expect(status.verbraucht, 1);
      expect(status.frei, 0);
      expect(status.fruehestensWieder, isNull);
    });

    test('ohne heutiges Datum verfällt nichts von selbst', () {
      final daten = _speicher(anwendungen: [_d('1', 'praios')]);

      final status = intervallStatus(daten, null);

      expect(status.datumUnbekannt, isTrue);
      expect(status.verbraucht, 1);
      expect(status.fruehestensWieder, isNull);
      // Auch ein unlesbares heutiges Datum gilt als unbekannt.
      expect(intervallStatus(daten, _d('', 'praios')).datumUnbekannt, isTrue);
    });

    test('Anwendungen je Intervall unter 1 gelten als 1', () {
      final daten = _speicher(proIntervall: 0);

      expect(intervallStatus(daten, _d('1', 'praios')).erlaubt, 1);
    });
  });

  group('Neue Anwendung', () {
    test('hängt das heutige Datum an und lässt Abgelaufenes fallen', () {
      final daten = _speicher(
        proIntervall: 3,
        anwendungen: [_d('1', 'praios'), _d('9', 'praios')],
      );

      final neu = anwendungenNachAusloesung(daten, _d('10', 'praios'));

      expect(neu, [_d('9', 'praios'), _d('10', 'praios')]);
    });

    test('behält nur so viele wie das Intervall erlaubt', () {
      final daten = _speicher(
        proIntervall: 2,
        anwendungen: [_d('4', 'praios'), _d('5', 'praios')],
      );

      final neu = anwendungenNachAusloesung(daten, _d('6', 'praios'));

      expect(neu, [_d('5', 'praios'), _d('6', 'praios')]);
    });

    test('ohne Datum wird eine Anwendung ohne Datum vermerkt', () {
      final daten = _speicher(
        proIntervall: 2,
        anwendungen: [_d('4', 'praios')],
      );

      final neu = anwendungenNachAusloesung(daten, null);

      expect(neu, [_d('4', 'praios'), const AventurianDate()]);
    });

    test('eine unlesbare Datumsangabe zählt wie ein unbekanntes Datum', () {
      final daten = _speicher();

      final neu = anwendungenNachAusloesung(daten, _d('', 'praios'));

      expect(neu, [const AventurianDate()]);
    });
  });

  group('Text', () {
    test('nennt freie Anwendungen und das Intervall', () {
      final daten = _speicher(
        proIntervall: 3,
        anwendungen: [_d('1', 'praios')],
      );

      expect(
        intervallStatusText(daten, intervallStatus(daten, _d('2', 'praios'))),
        '2 von 3 Anwendungen je Woche frei',
      );
    });

    test('nennt den frühesten freien Tag', () {
      final daten = _speicher(anwendungen: [_d('10', 'praios')]);

      expect(
        intervallStatusText(daten, intervallStatus(daten, _d('12', 'praios'))),
        '0 von 1 Anwendung je Woche frei · frühestens wieder am '
        '17. Praios 1027 BF',
      );
    });

    test('warnt bei unbekanntem Datum', () {
      final daten = _speicher(anwendungen: [const AventurianDate()]);

      expect(
        intervallStatusText(daten, intervallStatus(daten, null)),
        contains('Datum unbekannt'),
      );
    });
  });
}
