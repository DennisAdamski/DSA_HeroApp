import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/spell_effect_instance.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_state_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/basiswert_herleitung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_combat_rules.dart';

import '../test_support/real_catalog.dart';

HeroState _zustand() => const HeroState(
  currentLep: 30,
  currentAsp: 20,
  currentKap: 0,
  currentAu: 30,
);

HeroState _mit(HeroState z, SpellEffectInstance i) =>
    aktiviereEffektInstanz(z, i);

SpellEffectInstance _blitz(
  String id, {
  int? zfp = 5,
  int? zfw = 12,
  bool unterdrueckt = false,
}) => SpellEffectInstance(
  id: id,
  effectId: kBlitzZauberId,
  zfpStern: zfp,
  zfw: zfw,
  unterdrueckt: unterdrueckt,
);

SpellEffectInstance _plumbum(String id, {int? zfp = 6}) =>
    SpellEffectInstance(id: id, effectId: kPlumbumbarumZauberId, zfpStern: zfp);

StatModifikatorQuelle _quelle(SpellEffectKampfBeitraege b, String name) =>
    b.statQuellen.singleWhere((q) => q.bezeichnung == name);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RulesCatalog katalog;

  setUpAll(() async {
    katalog = (await ladeEchtenRegelkatalog()).catalog;
  });

  SpellEffectKampfBeitraege rechne(HeroState z, {bool blindkampf = false}) =>
      berechneSpellEffectKampfBeitraege(
        zustand: z,
        katalog: katalog,
        blindkampf: blindkampf,
      );

  test('Blitz ZfP*=5 zieht 3 von der AT und 2 von der PA-Basis ab', () {
    final b = rechne(_mit(_zustand(), _blitz('b')));

    final mods = _quelle(b, 'Blitz dich find').mods;
    expect(mods.at, -3);
    expect(mods.pa, -2);
    expect(mods.iniBase, 0);
    expect(b.heldenIniMalus, -12);
    expect(b.heldenIniQuelle, 'Blitz dich find');
    expect(b.orientierenGesperrt, isTrue);
  });

  test('Blitz: gerades ZfP* teilt gleichmäßig, ZfP* 1 trifft nur die AT', () {
    final gerade = rechne(_mit(_zustand(), _blitz('b', zfp: 6)));
    final eins = rechne(_mit(_zustand(), _blitz('b', zfp: 1)));
    final null0 = rechne(_mit(_zustand(), _blitz('b', zfp: 0)));

    expect(_quelle(gerade, 'Blitz dich find').mods.at, -3);
    expect(_quelle(gerade, 'Blitz dich find').mods.pa, -3);
    expect(_quelle(eins, 'Blitz dich find').mods.at, -1);
    expect(_quelle(eins, 'Blitz dich find').mods.pa, 0);
    expect(_quelle(null0, 'Blitz dich find').mods.at, 0);
  });

  test('Blitz ohne ZfW rechnet AT/PA, meldet aber den fehlenden INI-Abzug', () {
    final b = rechne(_mit(_zustand(), _blitz('b', zfw: null)));

    expect(_quelle(b, 'Blitz dich find').mods.at, -3);
    expect(b.heldenIniMalus, 0);
    expect(b.hinweise.single, contains('ZfW fehlt'));
  });

  test('Blitz ohne ZfP* rechnet nichts und sagt es', () {
    final b = rechne(_mit(_zustand(), _blitz('b', zfp: null)));

    expect(b.statQuellen, isEmpty);
    expect(b.heldenIniMalus, 0);
    expect(b.hinweise.single, contains('ZfP* fehlt'));
  });

  test('Blindkampf halbiert laut Regelwerk – die App rechnet nicht selbst', () {
    final b = rechne(_mit(_zustand(), _blitz('b')), blindkampf: true);

    expect(b.statQuellen, isEmpty);
    expect(b.heldenIniMalus, 0);
    expect(b.orientierenGesperrt, isTrue);
    expect(b.hinweise.single, contains('Blindkampf'));
  });

  test('Plumbumbarum ZfP*=6: AT und INI-Basis −6, PA bleibt', () {
    final b = rechne(_mit(_zustand(), _plumbum('p')));

    final mods = _quelle(b, 'Plumbumbarum schwerer Arm').mods;
    expect(mods.at, -6);
    expect(mods.iniBase, -6);
    expect(mods.pa, 0);
    expect(b.heldenIniMalus, 0);
    expect(b.orientierenGesperrt, isFalse);
  });

  test('mehrere Quellen desselben Zaubers: nur die stärkste zählt', () {
    var z = _mit(_zustand(), _plumbum('p1', zfp: 3));
    z = _mit(z, _plumbum('p2', zfp: 6));
    z = _mit(z, _plumbum('p3', zfp: 4));

    final b = rechne(z);

    expect(_quelle(b, 'Plumbumbarum schwerer Arm').mods.at, -6);
    expect(b.statQuellen, hasLength(1));
  });

  test('verschiedene Zauber addieren sich, unterdrückte zählen nicht', () {
    var z = _mit(_zustand(), _plumbum('p', zfp: 2));
    z = _mit(z, _blitz('b', unterdrueckt: true));
    final nur = rechne(z);
    expect(nur.statQuellen, hasLength(1));
    expect(nur.heldenIniMalus, 0);

    z = unterdrueckeEffektInstanz(z, 'b', unterdrueckt: false);
    final beide = rechne(z);
    expect(beide.statQuellen, hasLength(2));
    final summe = summeDerQuellen(beide.statQuellen);
    expect(summe.at, -2 - 3);
  });

  test('ohne Katalog oder mit anderem Zauber entsteht nichts', () {
    final z = _mit(_zustand(), _blitz('b'));

    expect(
      berechneSpellEffectKampfBeitraege(zustand: z, katalog: null).istLeer,
      isTrue,
    );
    expect(
      rechne(
        _mit(
          _zustand(),
          const SpellEffectInstance(
            id: 'x',
            effectId: 'spell_attributo',
            zfpStern: 7,
          ),
        ),
      ).istLeer,
      isTrue,
    );
  });
}
