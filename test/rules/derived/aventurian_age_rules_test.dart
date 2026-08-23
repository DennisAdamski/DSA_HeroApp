import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/aventurian_date.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_appearance.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/aventurian_age_rules.dart';

HeroAdventureEntry _adventure({
  required String id,
  HeroAdventureStatus status = HeroAdventureStatus.current,
  HeroAdventureDateValue start = const HeroAdventureDateValue(),
  HeroAdventureDateValue current = const HeroAdventureDateValue(),
  HeroAdventureDateValue end = const HeroAdventureDateValue(),
}) {
  return HeroAdventureEntry(
    id: id,
    status: status,
    startAventurianDate: start,
    currentAventurianDate: current,
    endAventurianDate: end,
  );
}

HeroSheet _hero({
  AventurianDate geburtsdatum = const AventurianDate(),
  List<HeroAdventureEntry> adventures = const <HeroAdventureEntry>[],
}) {
  return HeroSheet(
    id: 'held-1',
    name: 'Testheld',
    level: 1,
    attributes: const Attributes(
      mu: 12,
      kl: 12,
      inn: 12,
      ch: 12,
      ff: 12,
      ge: 12,
      ko: 12,
      kk: 12,
    ),
    appearance: HeroAppearance(geburtsdatum: geburtsdatum),
    adventures: adventures,
  );
}

void main() {
  group('aventurianDayOfYear', () {
    test('rechnet Monatsindex mal 30 plus Tag', () {
      expect(
        aventurianDayOfYear(const AventurianDate(day: '1', month: 'praios')),
        1,
      );
      expect(
        aventurianDayOfYear(const AventurianDate(day: '30', month: 'praios')),
        30,
      );
      expect(
        aventurianDayOfYear(const AventurianDate(day: '1', month: 'rondra')),
        31,
      );
    });

    test('beruecksichtigt Phex als neunten Monat', () {
      expect(
        aventurianDayOfYear(const AventurianDate(day: '30', month: 'tsa')),
        240,
      );
      expect(
        aventurianDayOfYear(const AventurianDate(day: '1', month: 'phex')),
        241,
      );
      expect(
        aventurianDayOfYear(const AventurianDate(day: '1', month: 'peraine')),
        271,
      );
    });

    test('setzt die Namenlosen Tage ans Jahresende', () {
      expect(
        aventurianDayOfYear(const AventurianDate(day: '30', month: 'rahja')),
        360,
      );
      expect(
        aventurianDayOfYear(
          const AventurianDate(day: '5', month: 'namenlose_tage'),
        ),
        365,
      );
    });

    test('akzeptiert Anzeigenamen statt Schluessel', () {
      expect(
        aventurianDayOfYear(const AventurianDate(day: '2', month: 'Phex')),
        242,
      );
    });

    test('liefert null bei fehlenden oder unplausiblen Angaben', () {
      expect(aventurianDayOfYear(const AventurianDate(month: 'praios')), isNull);
      expect(aventurianDayOfYear(const AventurianDate(day: '5')), isNull);
      expect(
        aventurianDayOfYear(const AventurianDate(day: '31', month: 'praios')),
        isNull,
      );
      expect(
        aventurianDayOfYear(const AventurianDate(day: '0', month: 'praios')),
        isNull,
      );
      expect(
        aventurianDayOfYear(
          const AventurianDate(day: '6', month: 'namenlose_tage'),
        ),
        isNull,
      );
      expect(
        aventurianDayOfYear(const AventurianDate(day: '1', month: 'hesindion')),
        isNull,
      );
    });
  });

  group('parseAventurianYear', () {
    test('liest reine Zahlen und Angaben mit Aera', () {
      expect(parseAventurianYear('1027'), 1027);
      expect(parseAventurianYear('  1027  '), 1027);
      expect(parseAventurianYear('1027 BF'), 1027);
      expect(parseAventurianYear('-50'), -50);
    });

    test('liefert null ohne Zahl', () {
      expect(parseAventurianYear(''), isNull);
      expect(parseAventurianYear('irgendwann'), isNull);
    });
  });

  group('computeAventurianAge', () {
    const geburt = AventurianDate(day: '12', month: 'praios', year: '1000');

    test('zaehlt volle Jahre, wenn der Geburtstag schon war', () {
      final alter = computeAventurianAge(
        geburtsdatum: geburt,
        stichtag: const AventurianDate(
          day: '13',
          month: 'praios',
          year: '1027',
        ),
      );
      expect(alter, 27);
    });

    test('zaehlt am Geburtstag selbst bereits das volle Jahr', () {
      final alter = computeAventurianAge(
        geburtsdatum: geburt,
        stichtag: const AventurianDate(
          day: '12',
          month: 'praios',
          year: '1027',
        ),
      );
      expect(alter, 27);
    });

    test('zieht ein Jahr ab, wenn der Geburtstag noch aussteht', () {
      final alter = computeAventurianAge(
        geburtsdatum: geburt,
        stichtag: const AventurianDate(
          day: '11',
          month: 'praios',
          year: '1027',
        ),
      );
      expect(alter, 26);
    });

    test('nutzt die Jahresdifferenz, wenn Tag oder Monat fehlen', () {
      final alter = computeAventurianAge(
        geburtsdatum: const AventurianDate(year: '1000'),
        stichtag: const AventurianDate(
          day: '11',
          month: 'praios',
          year: '1027',
        ),
      );
      expect(alter, 27);
    });

    test('versteht Jahresangaben mit Aera-Suffix', () {
      final alter = computeAventurianAge(
        geburtsdatum: const AventurianDate(
          day: '12',
          month: 'praios',
          year: '1000 BF',
        ),
        stichtag: const AventurianDate(
          day: '12',
          month: 'rahja',
          year: '1027 BF',
        ),
      );
      expect(alter, 27);
    });

    test('liefert null ohne Jahresangabe', () {
      expect(
        computeAventurianAge(
          geburtsdatum: const AventurianDate(day: '12', month: 'praios'),
          stichtag: const AventurianDate(
            day: '12',
            month: 'praios',
            year: '1027',
          ),
        ),
        isNull,
      );
      expect(
        computeAventurianAge(
          geburtsdatum: geburt,
          stichtag: const AventurianDate(day: '12', month: 'praios'),
        ),
        isNull,
      );
    });

    test('liefert null bei negativem Alter', () {
      final alter = computeAventurianAge(
        geburtsdatum: const AventurianDate(year: '1030'),
        stichtag: const AventurianDate(year: '1027'),
      );
      expect(alter, isNull);
    });
  });

  group('resolveCurrentAdventureDate', () {
    test('bevorzugt das aktuelle Datum des laufenden Abenteuers', () {
      final hero = _hero(
        adventures: <HeroAdventureEntry>[
          _adventure(
            id: 'a1',
            start: const HeroAdventureDateValue(
              day: '1',
              month: 'praios',
              year: '1027',
            ),
            current: const HeroAdventureDateValue(
              day: '4',
              month: 'rondra',
              year: '1027',
            ),
          ),
        ],
      );

      final date = resolveCurrentAdventureDate(hero);
      expect(date, const AventurianDate(day: '4', month: 'rondra', year: '1027'));
    });

    test('faellt auf das Startdatum zurueck', () {
      final hero = _hero(
        adventures: <HeroAdventureEntry>[
          _adventure(
            id: 'a1',
            start: const HeroAdventureDateValue(
              day: '1',
              month: 'praios',
              year: '1027',
            ),
          ),
        ],
      );

      final date = resolveCurrentAdventureDate(hero);
      expect(date, const AventurianDate(day: '1', month: 'praios', year: '1027'));
    });

    test('ueberspringt laufende Abenteuer ohne verwertbares Datum', () {
      final hero = _hero(
        adventures: <HeroAdventureEntry>[
          _adventure(id: 'ohne-datum'),
          _adventure(
            id: 'mit-datum',
            current: const HeroAdventureDateValue(
              day: '7',
              month: 'phex',
              year: '1027',
            ),
          ),
        ],
      );

      final date = resolveCurrentAdventureDate(hero);
      expect(date, const AventurianDate(day: '7', month: 'phex', year: '1027'));
    });

    test('nutzt ohne laufendes Abenteuer das zuletzt abgeschlossene', () {
      final hero = _hero(
        adventures: <HeroAdventureEntry>[
          _adventure(
            id: 'alt',
            status: HeroAdventureStatus.completed,
            end: const HeroAdventureDateValue(
              day: '1',
              month: 'praios',
              year: '1020',
            ),
          ),
          _adventure(
            id: 'neu',
            status: HeroAdventureStatus.completed,
            end: const HeroAdventureDateValue(
              day: '2',
              month: 'boron',
              year: '1026',
            ),
          ),
        ],
      );

      final date = resolveCurrentAdventureDate(hero);
      expect(date, const AventurianDate(day: '2', month: 'boron', year: '1026'));
    });

    test('liefert null ohne jedes verwertbare Datum', () {
      expect(resolveCurrentAdventureDate(_hero()), isNull);
      expect(
        resolveCurrentAdventureDate(
          _hero(adventures: <HeroAdventureEntry>[_adventure(id: 'leer')]),
        ),
        isNull,
      );
    });
  });

  group('computeCurrentHeroAge', () {
    test('verbindet Geburtsdatum und Abenteuerdatum', () {
      final hero = _hero(
        geburtsdatum: const AventurianDate(
          day: '12',
          month: 'praios',
          year: '1000',
        ),
        adventures: <HeroAdventureEntry>[
          _adventure(
            id: 'a1',
            current: const HeroAdventureDateValue(
              day: '11',
              month: 'praios',
              year: '1027',
            ),
          ),
        ],
      );

      expect(computeCurrentHeroAge(hero), 26);
    });

    test('liefert null ohne Geburtsdatum', () {
      final hero = _hero(
        adventures: <HeroAdventureEntry>[
          _adventure(
            id: 'a1',
            current: const HeroAdventureDateValue(
              day: '11',
              month: 'praios',
              year: '1027',
            ),
          ),
        ],
      );

      expect(computeCurrentHeroAge(hero), isNull);
    });

    test('liefert null ohne Abenteuerdatum', () {
      final hero = _hero(
        geburtsdatum: const AventurianDate(
          day: '12',
          month: 'praios',
          year: '1000',
        ),
      );

      expect(computeCurrentHeroAge(hero), isNull);
    });
  });
}
