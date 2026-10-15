import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/spell_duration.dart';
import 'package:dsa_heldenverwaltung/domain/spell_effect_instance.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_state_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_event_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_protection_rules.dart';

import '../test_support/real_catalog.dart';

SpellEffectInstance _schild(
  String id, {
  int kapazitaet = 14,
  int? rest,
  bool unterdrueckt = false,
  String effectId = kGardianumZauberId,
}) => SpellEffectInstance(
  id: id,
  effectId: effectId,
  zfpStern: 4,
  amount: kapazitaet,
  schutzRest: rest,
  unterdrueckt: unterdrueckt,
);

HeroState _mit(List<SpellEffectInstance> instanzen) {
  var zustand = const HeroState(
    currentLep: 30,
    currentAsp: 20,
    currentKap: 0,
    currentAu: 30,
  );
  for (final instanz in instanzen) {
    zustand = aktiviereEffektInstanz(zustand, instanz);
  }
  return zustand;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RulesCatalog katalog;

  setUpAll(() async {
    katalog = (await ladeEchtenRegelkatalog()).catalog;
  });

  test('die gespiegelte Auswahlliste stimmt mit den Schutzregeln überein', () {
    expect(kSchutzAuswahlZauberIds, kSchutzZauberIds);
  });

  group('Kapazität', () {
    test('Kuppel: investierte AsP plus doppelte ZfP*', () {
      expect(
        gardianumKapazitaet(
          variante: Schutzvariante.kuppel,
          zfpStern: 5,
          investierteAsp: 6,
        ),
        16,
      );
    });

    test('Persönlicher Schild: investierte AsP plus dreifache ZfP*', () {
      expect(
        gardianumKapazitaet(
          variante: Schutzvariante.persoenlich,
          zfpStern: 5,
          investierteAsp: 6,
        ),
        21,
      );
    });

    test('unter 3 AsP oder mit negativen ZfP* gibt es keinen Vorrat', () {
      expect(
        gardianumKapazitaet(
          variante: Schutzvariante.kuppel,
          zfpStern: 5,
          investierteAsp: 2,
        ),
        isNull,
      );
      expect(
        gardianumKapazitaet(
          variante: Schutzvariante.kuppel,
          zfpStern: -1,
          investierteAsp: 5,
        ),
        isNull,
      );
      expect(
        gardianumKapazitaet(
          variante: Schutzvariante.kuppel,
          zfpStern: 0,
          investierteAsp: 3,
        ),
        3,
      );
    });

    test(
      'der persönliche Schild meldet einen zu niedrigen ZfW nur als Hinweis',
      () {
        expect(
          schutzvarianteHinweis(Schutzvariante.persoenlich, 10),
          isNotNull,
        );
        expect(schutzvarianteHinweis(Schutzvariante.persoenlich, 11), isNull);
        expect(schutzvarianteHinweis(Schutzvariante.persoenlich, null), isNull);
        expect(schutzvarianteHinweis(Schutzvariante.kuppel, 3), isNull);
      },
    );
  });

  group('Vorrat', () {
    test('ohne Auffangvorgang entspricht der Rest der Kapazität', () {
      expect(schutzRestVon(_schild('a')), 14);
      expect(schutzRestVon(_schild('a', rest: 5)), 5);
      expect(schutzRestVon(_schild('a', rest: 0)), 0);
    });

    test('wirksam sind nur Schilde mit Vorrat, ohne Unterdrückung', () {
      final zustand = _mit([
        _schild('a'),
        _schild('b', rest: 0),
        _schild('c', unterdrueckt: true),
        _schild('d', effectId: kFalkenaugeZauberId),
      ]);

      expect(wirksameSchutzschilde(zustand, katalog).map((i) => i.id), ['a']);
      expect(wirksameSchutzschilde(zustand, null), isEmpty);
    });
  });

  group('Auffangen', () {
    test('ein kleinerer Treffer wird ganz aufgenommen', () {
      final ergebnis = fangeMagischenSchadenAuf(
        _mit([_schild('a')]),
        instanzId: 'a',
        eingehend: 9,
        erwarteterRest: 14,
      );

      expect(ergebnis.status, SchutzAuffangStatus.aufgefangen);
      expect(ergebnis.aufgefangen, 9);
      expect(ergebnis.durchschlag, 0);
      expect(ergebnis.restNachher, 5);
      expect(
        schutzRestVon(ergebnis.zustand.activeSpellEffects.instanzen.single),
        5,
      );
      expect(ergebnis.aufgezehrt, isFalse);
    });

    test(
      'ein größerer Treffer zehrt den Schild auf, der Rest schlägt durch',
      () {
        final ergebnis = fangeMagischenSchadenAuf(
          _mit([_schild('a', rest: 5)]),
          instanzId: 'a',
          eingehend: 12,
          erwarteterRest: 5,
        );

        expect(ergebnis.aufgefangen, 5);
        expect(ergebnis.durchschlag, 7);
        expect(ergebnis.restNachher, 0);
        expect(ergebnis.aufgezehrt, isTrue);
        // Der aufgezehrte Schild bleibt gespeichert und wird am Tisch beendet.
        expect(ergebnis.zustand.activeSpellEffects.instanzen, hasLength(1));
      },
    );

    test('genau der Vorrat wird aufgenommen, nichts schlägt durch', () {
      final ergebnis = fangeMagischenSchadenAuf(
        _mit([_schild('a', kapazitaet: 8)]),
        instanzId: 'a',
        eingehend: 8,
        erwarteterRest: 8,
      );

      expect(ergebnis.aufgefangen, 8);
      expect(ergebnis.durchschlag, 0);
      expect(ergebnis.aufgezehrt, isTrue);
    });

    test('ein zweiter Vorgang mit demselben erwarteten Rest bucht nichts', () {
      final erster = fangeMagischenSchadenAuf(
        _mit([_schild('a')]),
        instanzId: 'a',
        eingehend: 9,
        erwarteterRest: 14,
      );
      final wiederholt = fangeMagischenSchadenAuf(
        erster.zustand,
        instanzId: 'a',
        eingehend: 9,
        erwarteterRest: 14,
      );

      expect(wiederholt.status, SchutzAuffangStatus.restAbweichend);
      expect(wiederholt.aufgefangen, 0);
      expect(wiederholt.durchschlag, 9);
      expect(wiederholt.restVorher, 5);
      expect(identical(wiederholt.zustand, erster.zustand), isTrue);
    });

    test('unterdrückte, fremde und fehlende Instanzen fangen nichts auf', () {
      final unterdrueckt = fangeMagischenSchadenAuf(
        _mit([_schild('a', unterdrueckt: true)]),
        instanzId: 'a',
        eingehend: 4,
        erwarteterRest: 14,
      );
      final fremd = fangeMagischenSchadenAuf(
        _mit([_schild('a', effectId: kFalkenaugeZauberId)]),
        instanzId: 'a',
        eingehend: 4,
        erwarteterRest: 14,
      );
      final fehlt = fangeMagischenSchadenAuf(
        _mit([_schild('a')]),
        instanzId: 'x',
        eingehend: 4,
        erwarteterRest: 14,
      );

      expect(unterdrueckt.status, SchutzAuffangStatus.unwirksam);
      expect(fremd.status, SchutzAuffangStatus.unwirksam);
      expect(fehlt.status, SchutzAuffangStatus.nichtGefunden);
      for (final e in [unterdrueckt, fremd, fehlt]) {
        expect(e.durchschlag, 4);
        expect(e.aufgefangen, 0);
      }
    });

    test('negative TP gelten als 0, andere Schilde bleiben unberührt', () {
      final ergebnis = fangeMagischenSchadenAuf(
        _mit([_schild('a'), _schild('b')]),
        instanzId: 'a',
        eingehend: -3,
        erwarteterRest: 14,
      );
      expect(ergebnis.eingehend, 0);
      expect(ergebnis.restNachher, 14);

      final zweiter = fangeMagischenSchadenAuf(
        _mit([_schild('a'), _schild('b')]),
        instanzId: 'a',
        eingehend: 6,
        erwarteterRest: 14,
      );
      final b = zweiter.zustand.activeSpellEffects.instanzen.last;
      expect(b.id, 'b');
      expect(b.schutzRest, isNull);
    });
  });

  group('Korrektur', () {
    test('der Vorrat wird auf 0 bis zur Kapazität begrenzt', () {
      final zustand = _mit([_schild('a')]);

      expect(
        schutzRestVon(
          setzeSchutzRest(zustand, 'a', 99).activeSpellEffects.instanzen.single,
        ),
        14,
      );
      expect(
        schutzRestVon(
          setzeSchutzRest(zustand, 'a', -4).activeSpellEffects.instanzen.single,
        ),
        0,
      );
      expect(
        schutzRestVon(
          setzeSchutzRest(zustand, 'a', 6).activeSpellEffects.instanzen.single,
        ),
        6,
      );
    });

    test('andere Zauber werden nicht verändert', () {
      final zustand = _mit([_schild('a', effectId: kFalkenaugeZauberId)]);
      expect(
        identical(
          setzeSchutzRest(
            zustand,
            'a',
            3,
          ).activeSpellEffects.instanzen.single.schutzRest,
          3,
        ),
        isFalse,
      );
      expect(
        setzeSchutzRest(
          zustand,
          'a',
          3,
        ).activeSpellEffects.instanzen.single.schutzRest,
        isNull,
      );
    });

    test('Anzeigetext nennt Rest und Kapazität', () {
      expect(beschreibeSchutzVorrat(_schild('a', rest: 5)), 'Schutz 5 / 14 TP');
      expect(
        beschreibeSchutzVorrat(_schild('a', rest: 0)),
        contains('aufgezehrt'),
      );
    });
  });

  test('das Profil ist belegt, automatisierbar und wählbar', () {
    final auswahl = spellEffectAuswahl(katalog);
    final eintrag = auswahl.firstWhere((e) => e.zauberId == kGardianumZauberId);

    expect(eintrag.name, 'Gardianum Zauberschild');
    expect(eintrag.benoetigtSchutzvorrat, isTrue);
    expect(eintrag.benoetigtZiel, isFalse);
    expect(eintrag.benoetigtZfw, isTrue);
  });

  test('die Dauer beträgt höchstens eine Spielrunde', () {
    final dauer = dauerVorschlag(kGardianumZauberId)!;
    expect(dauer.amount, 1);
    expect(dauer.unit, SpellDurationUnit.spielrunden);
  });
}
