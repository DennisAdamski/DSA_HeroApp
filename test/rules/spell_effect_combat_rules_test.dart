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

StatModifikatorQuelle _quelle(SpellEffectBeitraege b, String name) =>
    b.statQuellen.singleWhere((q) => q.bezeichnung == name);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RulesCatalog katalog;

  setUpAll(() async {
    katalog = (await ladeEchtenRegelkatalog()).catalog;
  });

  SpellEffectBeitraege rechne(HeroState z, {bool blindkampf = false}) =>
      berechneSpellEffectBeitraege(
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
    expect(b.hinweise.any((h) => h.contains('ZfW fehlt')), isTrue);
  });

  test('Blitz ohne ZfP* rechnet nichts und sagt es', () {
    final b = rechne(_mit(_zustand(), _blitz('b', zfp: null)));

    expect(b.statQuellen, isEmpty);
    expect(b.heldenIniMalus, 0);
    expect(b.hinweise.single, contains('ZfP* fehlt'));
  });

  test('Blindkampf halbiert alle Abzüge, der Betrag wird aufgerundet', () {
    // ZfP* 5 → 3 (aufgerundet), davon AT 2 und PA 1; ZfW 7 → INI −4.
    final b = rechne(
      _mit(_zustand(), _blitz('b', zfw: 7)),
      blindkampf: true,
    );

    final mods = _quelle(b, 'Blitz dich find').mods;
    expect(mods.at, -2);
    expect(mods.pa, -1);
    expect(b.heldenIniMalus, -4);
    expect(b.fernkampfMalus, -3);
    expect(b.orientierenGesperrt, isTrue);
    expect(b.hinweise.single, contains('Blindkampf'));
  });

  test('Blindkampf mit geradem ZfP*: genau die Hälfte', () {
    final b = rechne(
      _mit(_zustand(), _blitz('b', zfp: 6, zfw: 12)),
      blindkampf: true,
    );

    final mods = _quelle(b, 'Blitz dich find').mods;
    expect(mods.at, -2);
    expect(mods.pa, -1);
    expect(b.heldenIniMalus, -6);
    expect(b.fernkampfMalus, -3);
  });

  test('halbiertAufgerundet', () {
    expect(halbiertAufgerundet(5), 3);
    expect(halbiertAufgerundet(4), 2);
    expect(halbiertAufgerundet(1), 1);
    expect(halbiertAufgerundet(0), 0);
    expect(halbiertAufgerundet(-3), 0);
  });

  test('Blitz erschwert den Fernkampf um ZfP*', () {
    final b = rechne(_mit(_zustand(), _blitz('b')));

    expect(b.fernkampfMalus, isNegative);
    expect(b.fernkampfQuelle, 'Blitz dich find');
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
      berechneSpellEffectBeitraege(zustand: z, katalog: null).istLeer,
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

  test('Karnifilo ist in den rechenbaren Zaubern und meldet seine Grenzen', () {
    final b = rechne(
      _mit(
        _zustand(),
        const SpellEffectInstance(
          id: 'k',
          effectId: kKarnifiloZauberId,
          zfpStern: 4,
        ),
      ),
    );

    final mods = _quelle(b, 'Karnifilo Raserei').mods;
    expect(mods.at, 5);
    expect(mods.pa, -5);
    expect(mods.iniBase, 0);
    expect(b.heldenIniMalus, 0);
    expect(b.orientierenGesperrt, isFalse);
    expect(b.hinweise.any((h) => h.contains('MU +5')), isTrue);
    expect(b.hinweise.any((h) => h.contains('Sturmangriff')), isTrue);
    // Eigenschaften laufen getrennt, nie über die Stat-Quellen.
    final eigenschaften = b.eigenschaftsQuellen.single;
    expect(eigenschaften.bezeichnung, 'Karnifilo Raserei');
    expect(eigenschaften.mods.mu, 5);
    expect(eigenschaften.mods.kk, 5);
    expect(eigenschaften.mods.kl, -5);
    expect(eigenschaften.mods.ch, -5);
    expect(eigenschaften.mods.ge, 0);
    expect(zauberEigenschaftsName(b), 'Karnifilo Raserei');
  });

  test('Axxeleratus meldet die Athletik-Verdopplung auch ohne Katalog', () {
    expect(
      berechneSpellEffectBeitraege(
        zustand: _zustand(),
        katalog: null,
        axxeleratus: true,
      ).athletikVerdopplungQuelle,
      kAxxeleratusAthletikQuelle,
    );
    expect(rechne(_zustand()).athletikVerdopplungQuelle, isNull);
  });

  test('Karnifilo ohne ZfP* rechnet nichts und sagt es', () {
    final b = rechne(
      _mit(
        _zustand(),
        const SpellEffectInstance(id: 'k', effectId: kKarnifiloZauberId),
      ),
    );

    expect(b.statQuellen, isEmpty);
    expect(b.hinweise.single, contains('ZfP* fehlt'));
  });
}
