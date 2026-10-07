import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_angriff.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_angriff_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_auftrag_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_held_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_kampfmittel_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_patzer_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/waffenlos_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import '../test_support/real_catalog.dart';
import '../ui2/shell/karto_test_support.dart';

// WdS S. 89–91, AA S. 150: Raufen und Ringen ohne Waffe, Kampfstile als
// waffenlose „Waffenspezialisierung“.
const _raufen = GefechtsKampfmittelwahl(
  GefechtsKampfmittelArt.waffenlos,
  'waffenlos:raufen',
);
const _ringen = GefechtsKampfmittelwahl(
  GefechtsKampfmittelArt.waffenlos,
  'waffenlos:ringen',
);

HeroComputedSnapshot _snapshot(
  RulesCatalog katalog, {
  CombatConfig config = const CombatConfig(),
  List<String> stile = const [],
}) {
  final held = testHero();
  return buildHeroComputedSnapshot(
    hero: held.copyWith(
      talents: {
        ...held.talents,
        'tal_raufen': const HeroTalentEntry(
          talentValue: 8,
          atValue: 4,
          paValue: 4,
        ),
        'tal_ringen': const HeroTalentEntry(
          talentValue: 10,
          atValue: 6,
          paValue: 4,
        ),
      },
      combatConfig: config.copyWith(
        specialRules: config.specialRules.copyWith(
          activeCombatSpecialAbilityIds: stile,
        ),
      ),
    ),
    state: const HeroState.empty(),
    catalog: katalog,
    epicAdvantagesActive: false,
  );
}

const _saebel = CombatConfig(
  weapons: [
    MainWeaponSlot(
      id: 'w',
      name: 'Säbel',
      talentId: 'tal_saebel',
      distanceClass: 'N',
    ),
  ],
);

GefechtsKampfmittelprofil _profil(HeroComputedSnapshot s, String id) =>
    gefechtsKampfmittelprofile(s).singleWhere((p) => p.wahl.id == id);

GefechtAuftrag _angriff(GefechtsKampfmittelwahl mittel, {ManeuverDef? m}) =>
    GefechtAuftrag(
      aktion: Gefechtsaktion.angriff,
      titel: 'AT',
      zuschlag: 0,
      dk: 'H',
      dauer: 1,
      kosten: 1,
      manoever: m,
      kampfmittel: mittel,
    );

Gefechtsangriffsergebnis? _ergebnis(
  HeroComputedSnapshot s,
  RulesCatalog k,
  GefechtAuftrag a,
) {
  final p = pruefeGefechtAuftrag(
    const Gefechtszustand(iniWurf: 6, dk: 'H'),
    s,
    k,
    a,
  );
  return gefechtsAngriffsergebnisNachBuchung(
    auftragId: 'a',
    buchungErfolgreich: true,
    erfolg: true,
    snapshot: s,
    katalog: k,
    auftrag: a,
    pruefung: p,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RulesCatalog katalog;
  setUpAll(() async {
    katalog = (await ladeEchtenRegelkatalog()).catalog;
  });

  test('Ohne Waffe stehen Raufen und Ringen als Kampfmittel bereit', () {
    final s = _snapshot(katalog);
    final raufen = _profil(s, 'waffenlos:raufen');
    final ringen = _profil(s, 'waffenlos:ringen');
    final atBasis = s.derivedStats.atBase;
    final paBasis = s.combatPreviewStats.paBase;
    expect(raufen.at, atBasis + 4);
    expect(raufen.pa, paBasis + 4);
    expect(ringen.at, atBasis + 6);
    expect(ringen.pa, paBasis + 4);
    expect(
      gefechtsKampfmittelprofile(s)
          .where((p) => p.wahl.art == GefechtsKampfmittelArt.hauptwaffe),
      isEmpty,
      reason: 'Der leere Platzhalter ist keine Waffe.',
    );
    expect(
      gefechtsStandardKampfmittel(s, Gefechtsaktion.angriff)?.id,
      'waffenlos:raufen',
    );
    expect(
      gefechtsStandardKampfmittel(s, Gefechtsaktion.parade)?.id,
      'waffenlos:raufen',
    );
    expect(raufen.anteile.join(), contains('Position'));
    final anzeige = gefechtsAngriffsanzeige(s)!;
    expect(anzeige.name, 'Raufen (waffenlos)');
    expect(anzeige.tp, endsWith('(A)'));
    expect(anzeige.wuerfel.count, 1);
    expect(anzeige.wuerfel.sides, 6);
  });

  test('Auch nach Entfernen der letzten Waffe (Index −1) waffenlos', () {
    final s = _snapshot(
      katalog,
      config: const CombatConfig(selectedWeaponIndex: -1),
    );
    expect(s.waffenlos, hasLength(2));
    expect(gefechtswerteFuer(s, katalog: katalog).waffeVorhanden, isTrue);
  });

  test('Unauer Schule hebt nur Ringen-AT/PA um je 1 (WdS S. 91)', () {
    final ohne = _snapshot(katalog);
    final mit = _snapshot(katalog, stile: const ['ksf_unauer_schule']);
    expect(
      _profil(mit, 'waffenlos:ringen').at,
      _profil(ohne, 'waffenlos:ringen').at! + 1,
    );
    expect(
      _profil(mit, 'waffenlos:ringen').pa,
      _profil(ohne, 'waffenlos:ringen').pa! + 1,
    );
    expect(
      _profil(mit, 'waffenlos:raufen').at,
      _profil(ohne, 'waffenlos:raufen').at,
    );
    final hinweise = _profil(mit, 'waffenlos:ringen').anteile.join('\n');
    expect(hinweise, contains('Unauer Schule'));
    expect(hinweise, contains('Entwinden'));
    expect(hinweise, contains('ohne Position'));
  });

  test('Mehrere Kampfstile bringen je höchstens +2 (WdS S. 90)', () {
    final ohne = _snapshot(katalog);
    final mit = _snapshot(
      katalog,
      stile: const ['ksf_unauer_schule', 'ksf_bornlaendisch', 'ksf_mercenario'],
    );
    expect(
      _profil(mit, 'waffenlos:ringen').at,
      _profil(ohne, 'waffenlos:ringen').at! + 2,
    );
  });

  test('Waffe oder Schild in der Hand: kein waffenloses Kampfmittel', () {
    final bewaffnet = _snapshot(katalog, config: _saebel);
    expect(bewaffnet.waffenlos, isEmpty);
    final schild = _snapshot(
      katalog,
      config: const CombatConfig(
        selectedWeaponIndex: -1,
        offhandEquipment: [
          OffhandEquipmentEntry(
            id: 's',
            name: 'Holzschild',
            type: OffhandEquipmentType.shield,
          ),
        ],
        offhandAssignment: OffhandAssignment(equipmentIndex: 0),
      ),
    );
    expect(schild.waffenlos, isEmpty);
  });

  test('Raufen-Treffer würfelt TP(A), Ringen-Angriff bleibt manuell', () {
    final s = _snapshot(katalog);
    final raufen = _ergebnis(s, katalog, _angriff(_raufen))!;
    expect(raufen.schadensfolge, GefechtsSchadensfolge.waffenschaden);
    expect(raufen.schaden?.count, 1);
    expect(raufen.hinweis, contains('TP(A)'));
    final ringen = _ergebnis(s, katalog, _angriff(_ringen))!;
    expect(ringen.schadensfolge, GefechtsSchadensfolge.manuell);
    expect(ringen.schaden, isNull);
    expect(ringen.hinweis, contains('Wurf'));
  });

  test('Ringen-Manöver verlangt das Kampfmittel Ringen', () {
    final s = _snapshot(katalog, stile: const ['ksf_unauer_schule']);
    final griff = katalog.maneuvers.singleWhere((m) => m.id == 'man_griff');
    expect(waffenloseManoevertalente(griff), {WaffenlosesTalent.ringen});
    const zustand = Gefechtszustand(iniWurf: 6, dk: 'H');
    final mitRaufen = pruefeGefechtsmanoever(
      zustand,
      s,
      katalog,
      griff,
      zuschlag: 0,
      kampfmittel: _raufen,
    );
    expect(mitRaufen.status, Gefechtsfreigabe.gesperrt);
    expect(mitRaufen.gruende.join(), contains('Kampfmittel Ringen'));
    final mitRingen = pruefeGefechtsmanoever(
      zustand,
      s,
      katalog,
      griff,
      zuschlag: 0,
      kampfmittel: _ringen,
    );
    expect(mitRingen.gruende.join(), isNot(contains('Kampfmittel Ringen')));
    expect(mitRingen.gruende.join(), isNot(contains('nicht erlernt')));
  });

  test('Waffenloser Kampf kennt keinen Bruchtest', () {
    final s = _snapshot(katalog);
    expect(gefechtsBruchprofil(s.hero.combatConfig, _raufen), isNull);
    expect(gefechtsMittelSchluessel(_raufen), 'waffenlos:waffenlos:raufen');
  });

  test('Ohne Waffe rechnet die Vorschau Raufen mit Fausthieb-INI −2', () {
    final s = _snapshot(katalog);
    final c = s.combatPreviewStats;
    expect(c.waffenlos, isTrue);
    expect(vorschauHauptwaffe(s.hero.combatConfig).name, 'Raufen (waffenlos)');
    expect(c.kombinierteHeldenWaffenIni, c.heldenInitiative - 2 + c.iniGe);
    expect(c.at, _profil(s, 'waffenlos:raufen').at);
    final bewaffnet = _snapshot(katalog, config: _saebel);
    expect(bewaffnet.combatPreviewStats.waffenlos, isFalse);
  });

  group('Waffenlos geführte Handgemengewaffen (AA S. 69 f.)', () {
    const schlagring = MainWeaponSlot(
      id: 'sr',
      name: 'Schlagring',
      weaponType: 'Schlagring',
      talentId: 'tal_raufen',
      distanceClass: 'H',
      tpFlat: 2,
      kkBase: 10,
      kkThreshold: 3,
    );
    const mitSchlagring = CombatConfig(weapons: [schlagring]);
    const hauptwaffe = GefechtsKampfmittelwahl(
      GefechtsKampfmittelArt.hauptwaffe,
      'sr',
    );
    ManeuverDef manoever(String id) =>
        katalog.maneuvers.singleWhere((m) => m.id == id);
    Gefechtspruefung pruefe(
      HeroComputedSnapshot s,
      String id,
      GefechtsKampfmittelwahl mittel,
    ) => pruefeGefechtsmanoever(
      const Gefechtszustand(iniWurf: 6, dk: 'H'),
      s,
      katalog,
      manoever(id),
      zuschlag: 0,
      kampfmittel: mittel,
    );

    test('Träger bleibt waffenlos kampfbereit', () {
      final s = _snapshot(katalog, config: mitSchlagring);
      expect(waffenlosKampfbereit(s.hero.combatConfig), isTrue);
      expect(s.waffenlos.map((w) => w.nebenWaffe), [false, false]);
      expect(
        _profil(s, 'sr').anteile.join(),
        allOf(contains('unbewaffnet'), contains('aufrunden')),
      );
      expect(gefechtsStandardKampfmittel(s, Gefechtsaktion.angriff)?.id, 'sr');
    });

    test('Nur die eigenen Manöver der Waffe, Ringen über Ringen', () {
      final s = _snapshot(
        katalog,
        config: mitSchlagring,
        stile: ['ksf_bornlaendisch'],
      );
      expect(
        pruefe(s, 'man_gerade', hauptwaffe).gruende.join(),
        isNot(contains('erlaubt dieses Manöver nicht')),
      );
      expect(
        pruefe(s, 'man_tritt', hauptwaffe).gruende.join(),
        contains('Schlagring erlaubt dieses Manöver nicht'),
      );
      expect(
        pruefe(s, 'man_tritt', _raufen).gruende.join(),
        isNot(contains('erlaubt dieses Manöver nicht')),
      );
      expect(
        pruefe(s, 'man_griff', hauptwaffe).gruende.join(),
        contains('Kampfmittel Ringen'),
      );
    });

    test('Schlagring-Treffer weist auf TP(A) hin', () {
      final s = _snapshot(katalog, config: mitSchlagring);
      final e = _ergebnis(s, katalog, _angriff(hauptwaffe))!;
      expect(e.schadensfolge, GefechtsSchadensfolge.waffenschaden);
      expect(e.hinweis, contains('TP(A)'));
    });
  });

  group('Waffenlose Manöver neben einer Waffe (WdS S. 90)', () {
    ManeuverDef manoever(String id) =>
        katalog.maneuvers.singleWhere((m) => m.id == id);

    test('Ohne Kampftechnik kein waffenloses Kampfmittel neben der Waffe', () {
      expect(_snapshot(katalog, config: _saebel).waffenlos, isEmpty);
    });

    test('Mit Kampftechnik nur deren Manöver, um 2 erschwert', () {
      final bewaffnet = _snapshot(
        katalog,
        config: _saebel,
        stile: ['ksf_unauer_schule'],
      );
      final frei = _snapshot(katalog, stile: ['ksf_unauer_schule']);
      expect(bewaffnet.waffenlos.every((w) => w.nebenWaffe), isTrue);
      expect(
        gefechtsKampfmittelprofile(bewaffnet)
            .singleWhere((p) => p.wahl.id == 'waffenlos:ringen')
            .name,
        'Ringen (waffenloses Manöver)',
      );
      expect(
        gefechtsStandardKampfmittel(bewaffnet, Gefechtsaktion.angriff)?.art,
        GefechtsKampfmittelArt.hauptwaffe,
      );
      const zustand = Gefechtszustand(iniWurf: 6, dk: 'H');
      Gefechtspruefung griff(HeroComputedSnapshot s) => pruefeGefechtsmanoever(
        zustand,
        s,
        katalog,
        manoever('man_griff'),
        zuschlag: 0,
        kampfmittel: _ringen,
      );
      expect(griff(bewaffnet).erschwernis, griff(frei).erschwernis + 2);
      expect(
        pruefeGefechtsmanoever(
          zustand,
          bewaffnet,
          katalog,
          manoever('man_tritt'),
          zuschlag: 0,
          kampfmittel: _raufen,
        ).gruende.join(),
        contains('nur Manöver der beherrschten'),
      );
      final plain = pruefeGefechtAuftrag(
        zustand,
        bewaffnet,
        katalog,
        _angriff(_raufen),
      );
      expect(plain.status, Gefechtsfreigabe.gesperrt);
      expect(plain.gruende.join(), contains('keine gewöhnliche AT/PA'));
    });

    test('Würgegriff braucht beide Hände', () {
      final s = _snapshot(
        katalog,
        config: _saebel,
        stile: ['ksf_bornlaendisch'],
      );
      final p = pruefeGefechtsmanoever(
        const Gefechtszustand(iniWurf: 6, dk: 'H'),
        s,
        katalog,
        manoever('man_wuergegriff'),
        zuschlag: 0,
        kampfmittel: _ringen,
      );
      expect(p.gruende.join(), contains('beide Hände'));
    });
  });
}
