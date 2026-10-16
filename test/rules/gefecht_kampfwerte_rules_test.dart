import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_held_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_herleitung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_kampfwerte_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';

import 'gefecht_meisterparade_rules_test.dart' as mp;

const _katalog = RulesCatalog(
  version: 'test',
  source: 'test',
  talents: [],
  spells: [],
  weapons: [],
  maneuvers: [],
);

Gefechtszustand _zustand({int wurf = 8}) =>
    beginneGefecht(wurf, dk: 'N').copyWith(
      kontext: const Gefechtskontext(
        angriffsart: Gefechtsangriffsart.nahkampf,
        finte: 0,
        schildWmWirksam: true,
        situationsZuschlag: 0,
      ),
    );

GefechtsKampfwert _wert(List<GefechtsKampfwert> liste, String id) =>
    liste.firstWhere((w) => w.id == id);

void main() {
  test('Gefechts-INI: Herleitung ergibt die Sitzungs-INI samt Verlusten', () {
    final snapshot = mp.mpSnapshot();
    final s = _zustand(wurf: 9).copyWith(
      iniVerlust: 3,
      geschuetzterIniVerlust: 1,
      ungeklaerterIniVerlust: 2,
    );
    final w = gefechtswerteFuer(snapshot);
    final liste = gefechtsKampfwerte(s, snapshot, null);
    final ini = _wert(liste, 'ini');
    expect(ini.wert, gefechtsInitiative(s, w));
    expect(ini.herleitung, isNotNull);
    expect(ini.herleitung!.wert, ini.wert);
    final namen = ini.herleitung!.sichtbareSchritte.map((e) => e.bezeichnung);
    expect(namen, contains('INI-Wurf (Sitzung)'));
    expect(namen, contains('Kampfverluste'));
    expect(namen, contains('Geschützter INI-Verlust'));
    expect(namen, contains('Ungeklärter INI-Verlust'));
    // Der Vorschauwurf steht nicht daneben.
    expect(namen, isNot(contains('INI-Wurf')));
  });

  test('Jede Herleitung ergibt ihren angezeigten Wert', () {
    final snapshot = mp.mpSnapshot(schild: true);
    for (final katalog in [null, _katalog]) {
      final liste = gefechtsKampfwerte(_zustand(), snapshot, katalog);
      expect(
        liste.map((w) => w.id),
        containsAll(['ini', 'at', 'pa', 'schildpa', 'aw', 'tp', 'rs', 'be']),
      );
      for (final w in liste) {
        if (w.herleitung != null && w.wert != null) {
          expect(w.herleitung!.wert, w.wert, reason: w.id);
        }
      }
      for (final id in ['at', 'pa', 'schildpa', 'aw']) {
        final w = _wert(liste, id);
        expect(w.zielwert, w.wert! - w.erschwernis, reason: id);
      }
    }
  });

  test(
    'Hohe INI wirkt als Sitzungsbonus auf PA und Ausweichen, nicht auf AT',
    () {
      final snapshot = mp.mpSnapshot();
      final s = _zustand(wurf: 30);
      final liste = gefechtsKampfwerte(s, snapshot, _katalog);
      String? bonusIn(String id) => _wert(liste, id).herleitung!.schritte
          .where((e) => e.bezeichnung == kGefechtsIniBonusSchritt)
          .map((e) => '${e.betrag}')
          .firstOrNull;
      expect(bonusIn('pa'), isNotNull);
      expect(bonusIn('aw'), isNotNull);
      expect(bonusIn('at'), isNull);
      expect(_wert(liste, 'pa').hinweise.join(' '), contains('Hohe INI'));
    },
  );

  test('Ansagefolgemalus senkt den Zielwert und erscheint als Hinweis', () {
    final snapshot = mp.mpSnapshot();
    final s = _zustand().copyWith(ansageFolgemalus: 2);
    final at = _wert(gefechtsKampfwerte(s, snapshot, _katalog), 'at');
    expect(at.zielwert, at.wert! - at.erschwernis);
    expect(at.zielwert, lessThan(at.wert!));
    expect(at.weichtAb, isTrue);
    expect(at.hinweise.join(' '), contains('Ansagefolgemalus'));
  });

  test('Ohne Schild gibt es keine Schild-PA', () {
    final liste = gefechtsKampfwerte(_zustand(), mp.mpSnapshot(), _katalog);
    expect(liste.map((w) => w.id), isNot(contains('schildpa')));
  });
}
