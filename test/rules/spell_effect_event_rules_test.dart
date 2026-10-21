import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/domain/spell_duration.dart';
import 'package:dsa_heldenverwaltung/domain/spell_effect_instance.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_state_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_auftrag_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_laden_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_event_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import '../test_support/real_catalog.dart';
import '../ui2/shell/karto_test_support.dart';
import 'gefecht_laden_rules_test.dart' as fixture;

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

SpellEffectInstance _falke(
  String id, {
  String? ziel = 'Ork',
  int? zfp = 5,
  bool unterdrueckt = false,
}) => SpellEffectInstance(
  id: id,
  effectId: kFalkenaugeZauberId,
  zfpStern: zfp,
  zfw: 9,
  ziel: ziel,
  unterdrueckt: unterdrueckt,
);

const _kontextOrk = Gefechtskontext(
  kontakt: 'Ork',
  geladen: true,
  entfernung: 60,
  situationsZuschlag: 0,
);

HeroComputedSnapshot _fkSnapshot(HeroState zustand) {
  final basis = fixture.ladeSnapshot(nebenhand: false);
  final waffen = basis.hero.combatConfig.weaponSlots.map((w) {
    if (!w.isRanged) return w;
    return w.copyWith(
      talentId: 'tal_armbrust',
      tpFlat: 4,
      rangedProfile: w.rangedProfile.copyWith(
        projectiles: const [
          RangedProjectile(id: 'p1', name: 'Bolzen', count: 5, tpMod: 3),
        ],
        distanceBands: const [
          RangedDistanceBand(label: '5', tpMod: 7),
          RangedDistanceBand(label: '10', tpMod: 2),
          RangedDistanceBand(label: '20', tpMod: -1),
          RangedDistanceBand(label: '40', tpMod: -3),
          RangedDistanceBand(label: '80', tpMod: -5),
        ],
      ),
    );
  }).toList();
  return buildHeroComputedSnapshot(
    hero: basis.hero.copyWith(
      talents: {'tal_armbrust': const HeroTalentEntry(talentValue: 16)},
      combatConfig: basis.hero.combatConfig.copyWith(weapons: waffen),
    ),
    state: zustand,
    catalog: testCatalog,
    epicAdvantagesActive: false,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RulesCatalog katalog;

  setUpAll(() async {
    katalog = (await ladeEchtenRegelkatalog()).catalog;
  });

  test(
    'die gespiegelten Auswahl-IDs stimmen mit den Ereignisregeln überein',
    () {
      expect(kEinmaligeAuswahlZauberIds, kEinmaligeZauberIds);
    },
  );

  group('Ziel', () {
    test('passt über Namen (ohne Groß-/Kleinschreibung) oder Kennung', () {
      expect(
        zielPasstZumKontakt('ork', const Gefechtskontext(kontakt: 'Ork')),
        isTrue,
      );
      expect(
        zielPasstZumKontakt(
          'gegner:g7',
          const Gefechtskontext(kontakt: 'Ork', gegnerId: 'g7'),
        ),
        isTrue,
      );
      expect(zielPasstZumKontakt('Goblin', _kontextOrk), isFalse);
    });

    test('ohne Ziel oder ohne Kontakt passt nichts', () {
      expect(zielPasstZumKontakt(null, _kontextOrk), isFalse);
      expect(zielPasstZumKontakt('  ', _kontextOrk), isFalse);
      expect(zielPasstZumKontakt('Ork', const Gefechtskontext()), isFalse);
    });
  });

  group('Falkenauge', () {
    test('erleichtert den Schuss auf das festgelegte Ziel um ZfP*', () {
      final anteil = falkenaugeAnteil(
        _mit([_falke('f')]),
        _kontextOrk,
        katalog,
      );

      expect(anteil, isNotNull);
      expect(anteil!.wert, -5);
      expect(anteil.name, contains('Falkenauge'));
    });

    test('nicht auf ein anderes Ziel, nicht unterdrückt, nicht ohne ZfP*', () {
      const andere = Gefechtskontext(kontakt: 'Goblin');
      expect(falkenaugeAnteil(_mit([_falke('f')]), andere, katalog), isNull);
      expect(
        falkenaugeAnteil(
          _mit([_falke('f', unterdrueckt: true)]),
          _kontextOrk,
          katalog,
        ),
        isNull,
      );
      expect(
        falkenaugeAnteil(_mit([_falke('f', zfp: null)]), _kontextOrk, katalog),
        isNull,
      );
      expect(
        falkenaugeAnteil(_mit([_falke('f', ziel: null)]), _kontextOrk, katalog),
        isNull,
      );
      expect(falkenaugeAnteil(_mit([_falke('f')]), _kontextOrk, null), isNull);
    });

    test('mehrere Quellen auf dasselbe Ziel: nur die stärkste', () {
      final anteil = falkenaugeAnteil(
        _mit([_falke('a', zfp: 3), _falke('b', zfp: 7), _falke('c', zfp: 4)]),
        _kontextOrk,
        katalog,
      );

      expect(anteil!.wert, -7);
      expect(
        passendeFalkenauge(
          _mit([_falke('a', zfp: 3), _falke('b', zfp: 7)]),
          _kontextOrk,
          katalog,
        )!.id,
        'b',
      );
    });

    test('Verbrauch entfernt nur diese Quelle und ist wiederholbar', () {
      final zustand = _mit([_falke('a', zfp: 3), _falke('b', ziel: 'Goblin')]);

      final einmal = beendeEffektInstanz(zustand, 'a');
      final zweimal = beendeEffektInstanz(einmal, 'a');

      expect(einmal.activeSpellEffects.instanzen.map((i) => i.id), ['b']);
      expect(identical(zweimal, einmal), isTrue);
    });

    test('im Gefecht: Erschwernis sinkt um ZfP*, Anteil ist benannt', () {
      final auftrag = GefechtAuftrag(
        aktion: Gefechtsaktion.angriff,
        titel: 'FK',
        zuschlag: 0,
        dk: null,
        dauer: 1,
        kosten: 1,
        fernkampfansage: 4,
        kampfmittel: const GefechtsKampfmittelwahl(
          GefechtsKampfmittelArt.hauptwaffe,
          'a',
        ),
        kontext: _kontextOrk,
      );
      Gefechtspruefung pruefe(HeroState zustand) {
        final snap = _fkSnapshot(zustand);
        var s = beginneGefechtsZielen(
          const Gefechtszustand(iniWurf: 6),
          snap,
          katalog,
          auftrag,
        );
        s = bezahleGefechtsVorbereitung(s, snap);
        s = naechsteGefechtsrunde(s).copyWith(ohneHandlung: true);
        return pruefeGefechtAuftrag(s, snap, katalog, auftrag);
      }

      final ohne = pruefe(const HeroState.empty());
      final mit = pruefe(_mit([_falke('f')]));
      final anderes = pruefe(_mit([_falke('f', ziel: 'Goblin')]));

      expect(
        mit.erschwernis - ohne.erschwernis,
        -5,
        reason: mit.gruende.join('; '),
      );
      expect(
        mit.modifikatoren.where((m) => m.name.contains('Falkenauge')),
        hasLength(1),
      );
      expect(anderes.erschwernis, ohne.erschwernis);
    });
  });

  group('Ängste lindern', () {
    const aengste = SpellEffectInstance(
      id: 'a',
      effectId: kAengsteLindernZauberId,
      zfpStern: 6,
    );

    test('Mut-Probe wird um ZfP* erleichtert', () {
      final probe = aengsteLindernProbe(mu: 12, instanz: aengste);

      expect(probe.type, ProbeType.attribute);
      expect(probe.targets.single.value, 12);
      expect(probe.initialSituationalModifier, 6);
      expect(probe.ruleHint, contains('verbraucht'));
    });

    test('einsetzbar nur mit ZfP* und ohne Unterdrückung', () {
      final liste = einsetzbareAengsteLindern(
        _mit([
          aengste,
          aengste.copyWith(unterdrueckt: true),
          const SpellEffectInstance(id: 'x', effectId: kAengsteLindernZauberId),
        ]),
        katalog,
      );
      expect(liste, hasLength(1));
      expect(einsetzbareAengsteLindern(_mit([aengste]), null), isEmpty);
    });
  });

  group('Dauervorschlag', () {
    test('nur eindeutig belegte Dauern', () {
      expect(dauerVorschlag(kPlumbumbarumZauberId)!.amount, 5);
      expect(
        dauerVorschlag(kPlumbumbarumZauberId)!.unit,
        SpellDurationUnit.kampfrunden,
      );
      expect(
        dauerVorschlag(kAdlerAugeZauberId)!.unit,
        SpellDurationUnit.spielrunden,
      );
      expect(dauerVorschlag(kFalkenaugeZauberId, zfw: 9)!.amount, 9);
      expect(dauerVorschlag(kFalkenaugeZauberId), isNull);
      // ZfW/2 Aktionen (Blitz), nach Tischregel aufgerundet; ohne ZfW nichts.
      expect(dauerVorschlag(kBlitzZauberId, zfw: 7)!.amount, 4);
      expect(dauerVorschlag(kBlitzZauberId, zfw: 8)!.amount, 4);
      expect(
        dauerVorschlag(kBlitzZauberId, zfw: 7)!.unit,
        SpellDurationUnit.aktionen,
      );
      expect(dauerVorschlag(kBlitzZauberId), isNull);
      expect(dauerVorschlag(kBlitzZauberId, zfw: 0), isNull);
      // Psychostabilis: nach AsP – ohne Angabe kein Vorschlag.
      expect(dauerVorschlag(kPsychostabilisZauberId), isNull);
    });

    test('Psychostabilis: 1 Spielrunde je vorausbezahltem Zusatz-AsP', () {
      final dauer = dauerVorschlag(
        kPsychostabilisZauberId,
        zusaetzlicheAsp: 7,
      )!;
      expect(dauer.amount, 7);
      expect(dauer.unit, SpellDurationUnit.spielrunden);
      // Grenzfälle: 0 oder negativ ergeben keinen Vorschlag.
      expect(
        dauerVorschlag(kPsychostabilisZauberId, zusaetzlicheAsp: 0),
        isNull,
      );
      expect(
        dauerVorschlag(kPsychostabilisZauberId, zusaetzlicheAsp: -2),
        isNull,
      );
      // Andere Zauber ignorieren die Angabe.
      expect(dauerVorschlag(kBlitzZauberId, zusaetzlicheAsp: 7), isNull);
    });
  });

  test('Dauervorschläge für Karnifilo und Seidenzunge', () {
    final karnifilo = dauerVorschlag(kKarnifiloZauberId, zfpStern: 4)!;
    expect(karnifilo.amount, 20);
    expect(karnifilo.unit, SpellDurationUnit.kampfrunden);
    final seide = dauerVorschlag(kSeidenzungeZauberId, zfpStern: 6)!;
    expect(seide.amount, 6);
    expect(seide.unit, SpellDurationUnit.spielrunden);
    expect(dauerVorschlag(kKarnifiloZauberId), isNull);
    expect(dauerVorschlag(kSeidenzungeZauberId, zfpStern: 0), isNull);
  });
}
