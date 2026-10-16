import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_background.dart';
import 'package:dsa_heldenverwaltung/domain/hero_herkunft.dart';
import 'package:dsa_heldenverwaltung/domain/hero_herkunfts_modifikator.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/editor_entwurf_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_herkunft_bearbeitung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_herkunft_migration_rules.dart';

HeroHerkunftsModifikator _eintrag(String id, String text) {
  return HeroHerkunftsModifikator(id: id, text: text);
}

void main() {
  test('Änderung einer anderen Herkunft bleibt erhalten', () {
    final basis = herkunftZumSpeichern(
      const HeroBackground(rasseModText: 'MU+1', kulturModText: 'KL+1'),
    );
    final aktuell = basis.copyWith(kultur: 'Neuer Name');
    final neu = ersetzeHerkunftsEintraege(
      basis: basis,
      aktuell: aktuell,
      herkunft: HeroHerkunft.rasse,
      eintraege: const [],
    );
    expect(neu.kultur, 'Neuer Name');
    expect(neu.rasseModText, isEmpty);
    expect(neu.herkunftsModifikatoren!.rasse, isEmpty);
    expect(neu.kulturModText, 'KL+1');
    expect(
      neu.herkunftsModifikatoren!.kultur,
      basis.herkunftsModifikatoren!.kultur,
    );
  });

  test('Liste und Textprojektion der Gruppe ändern sich gemeinsam', () {
    final basis = herkunftZumSpeichern(
      const HeroBackground(professionModText: 'MR+1'),
    );
    final neu = ersetzeHerkunftsEintraege(
      basis: basis,
      aktuell: basis,
      herkunft: HeroHerkunft.profession,
      eintraege: [_eintrag('a', 'MR+1'), _eintrag('b', 'Hausnotiz')],
    );
    expect(neu.professionModText, 'MR+1, Hausnotiz');
    expect(neu.herkunftsModifikatoren!.profession.map((e) => e.id), ['a', 'b']);
    expect(gleicheHerkunftAb(neu).abweichungen, isEmpty);
  });

  test('ohne gespeicherten Container wird er mit angelegt', () {
    const basis = HeroBackground(rasseModText: 'MU+1', kulturModText: 'KL+1');
    final neu = ersetzeHerkunftsEintraege(
      basis: basis,
      aktuell: basis,
      herkunft: HeroHerkunft.kultur,
      eintraege: const [],
    );
    final container = neu.herkunftsModifikatoren!;
    expect(container.kultur, isEmpty);
    expect(container.rasse.single.text, 'MU+1');
    expect(neu.rasseModText, 'MU+1');
    expect(neu.kulturModText, isEmpty);
  });

  test('dieselbe Gruppe anderweitig geändert wirft', () {
    final basis = herkunftZumSpeichern(
      const HeroBackground(rasseModText: 'MU+1'),
    );
    final fremd = ersetzeHerkunftsEintraege(
      basis: basis,
      aktuell: basis,
      herkunft: HeroHerkunft.rasse,
      eintraege: [_eintrag('x', 'KL+2')],
    );
    expect(
      () => ersetzeHerkunftsEintraege(
        basis: basis,
        aktuell: fremd,
        herkunft: HeroHerkunft.rasse,
        eintraege: const [],
      ),
      throwsStateError,
    );
  });

  test('nur der Text einer Gruppe geändert (ältere App) wirft', () {
    final basis = herkunftZumSpeichern(
      const HeroBackground(rasseModText: 'MU+1'),
    );
    final fremd = basis.copyWith(rasseModText: 'MU+3');
    expect(
      () => ersetzeHerkunftsEintraege(
        basis: basis,
        aktuell: fremd,
        herkunft: HeroHerkunft.rasse,
        eintraege: const [],
      ),
      throwsStateError,
    );
    // Eine andere Gruppe bleibt trotz fremder Abweichung bearbeitbar.
    final kultur = ersetzeHerkunftsEintraege(
      basis: basis,
      aktuell: fremd,
      herkunft: HeroHerkunft.kultur,
      eintraege: [_eintrag('k', 'Flink')],
    );
    expect(kultur.rasseModText, 'MU+3');
    expect(kultur.kulturModText, 'Flink');
  });

  test('unbekannte Version und gesperrte Gruppen werfen', () {
    final unbekannt = HeroBackground(
      herkunftsModifikatoren: HeroHerkunftsModifikatoren.fromJson(
        <String, Object?>{'formatVersion': 900},
      ),
    );
    expect(
      () => ersetzeHerkunftsEintraege(
        basis: unbekannt,
        aktuell: unbekannt,
        herkunft: HeroHerkunft.rasse,
        eintraege: const [],
      ),
      throwsStateError,
    );
    final doppelt = HeroBackground(
      herkunftsModifikatoren: HeroHerkunftsModifikatoren(
        rasse: [_eintrag('a', 'x'), _eintrag('a', 'y')],
      ),
      rasseModText: 'x, y',
    );
    expect(
      () => ersetzeHerkunftsEintraege(
        basis: doppelt,
        aktuell: doppelt,
        herkunft: HeroHerkunft.rasse,
        eintraege: const [],
      ),
      throwsStateError,
    );
  });

  test('unbekannte Containerfelder und Eintragsfelder bleiben erhalten', () {
    final container = HeroHerkunftsModifikatoren.fromJson(<String, Object?>{
      'formatVersion': 1,
      'rasse': <Object?>[
        <String, Object?>{'id': 'a', 'art': 'frei', 'text': 'x', 'neu': 1},
      ],
      'kultur': <Object?>[],
      'profession': <Object?>[],
      'zusatz': true,
    });
    final basis = HeroBackground(
      rasseModText: 'x',
      herkunftsModifikatoren: container,
    );
    final neu = ersetzeHerkunftsEintraege(
      basis: basis,
      aktuell: basis,
      herkunft: HeroHerkunft.kultur,
      eintraege: [_eintrag('k', 'Flink')],
    );
    final json = neu.herkunftsModifikatoren!.toJson()! as Map;
    expect(json['zusatz'], true);
    expect(((json['rasse'] as List).single as Map)['neu'], 1);
  });

  group('Editorentwurf gegen frisch Gespeichertes', () {
    HeroSheet held(HeroBackground background, {String dukaten = ''}) {
      return HeroSheet(
        id: 'h',
        name: 'Held',
        level: 1,
        attributes: const Attributes.zero(),
        background: background,
        dukaten: dukaten,
      );
    }

    final start = herkunftZumSpeichern(
      const HeroBackground(rasseModText: 'MU+1', kulturModText: 'KL+1'),
    );

    HeroBackground mitRasse(HeroBackground basis, String id, String text) {
      return ersetzeHerkunftsEintraege(
        basis: basis,
        aktuell: basis,
        herkunft: HeroHerkunft.rasse,
        eintraege: [_eintrag(id, text)],
      );
    }

    HeroSheet uebernimm(HeroSheet basis, HeroSheet entwurf, HeroSheet aktuell) {
      return uebernimmEditorEntwurf(
        basis: basis,
        entwurf: entwurf,
        aktuell: aktuell,
        neueId: () => 'neu',
      );
    }

    test('fremdes Speichern anderer Felder bleibt bei geändertem Entwurf', () {
      final basis = held(start);
      final entwurf = held(mitRasse(start, 'e', 'KK+2'));
      final aktuell = held(start, dukaten: '12');
      final ergebnis = uebernimm(basis, entwurf, aktuell);
      expect(ergebnis.dukaten, '12');
      expect(ergebnis.background.herkunftsModifikatoren!.rasse.single.id, 'e');
      expect(ergebnis.background.rasseModText, 'KK+2');
    });

    test('zwischenzeitlich geänderte Herkunft bleibt, wenn der Entwurf sie '
        'nicht anfasst', () {
      final basis = held(start);
      final entwurf = held(start, dukaten: '7');
      final aktuell = held(mitRasse(start, 'f', 'KL+2'));
      final ergebnis = uebernimm(basis, entwurf, aktuell);
      expect(ergebnis.dukaten, '7');
      expect(ergebnis.background.herkunftsModifikatoren!.rasse.single.id, 'f');
    });

    test('beidseitig geänderte Herkunft ist ein ausdrücklicher Konflikt, '
        'kein stilles Ersetzen', () {
      final basis = held(start);
      final entwurf = held(mitRasse(start, 'e', 'KK+2'));
      final aktuell = held(mitRasse(start, 'f', 'KL+2'));
      expect(
        () => uebernimm(basis, entwurf, aktuell),
        throwsA(
          isA<EditorEntwurfKonflikt>().having(
            (k) => k.schluessel,
            'schluessel',
            contains('herkunftsModifikatoren'),
          ),
        ),
      );
    });

    test('unbekannte Rohdaten des gespeicherten Standes bleiben erhalten', () {
      final json = held(start).toJson();
      (json['herkunftsModifikatoren'] as Map<String, dynamic>)['zusatz'] = 1;
      final aktuell = HeroSheet.fromJson(json).copyWith(dukaten: '5');
      final basis = HeroSheet.fromJson(json);
      final ergebnis = uebernimm(basis, basis.copyWith(name: 'Neu'), aktuell);
      expect((ergebnis.toJson()['herkunftsModifikatoren'] as Map)['zusatz'], 1);
    });
  });
}
