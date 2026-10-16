import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_herleitung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_kampfprofil_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_wirkwert_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung_uebersicht_rules.dart';

const _ausbildung = ReittierAusbildung(
  ausgangsstufe: ReittierAusbildungsstufe.erprobt,
  ausgangsart: ReittierAusbildungsart.fundiert,
  varianteId: 'pvar_leichtes_streitross',
  schritte: <ReittierAusbildungsschritt>[
    ReittierAusbildungsschritt(
      nach: ReittierAusbildungsstufe.geschult,
      art: ReittierAusbildungsart.fundiert,
    ),
  ],
);

const _pferd = HeroCompanion(
  id: 'p1',
  name: 'Falbe',
  typ: BegleiterTyp.reittier,
  kk: 20,
  loyalitaet: 12,
  ini: 9,
  maxLep: 40,
  startLep: 38,
  steigerungen: <String, int>{'kk': 1, 'lep': 2},
  angriffe: <HeroCompanionAttack>[
    HeroCompanionAttack(id: 'b', name: 'Biss', at: 11, pa: 8, tp: '1W6+1'),
    HeroCompanionAttack(
      id: 't',
      name: 'Tritt',
      at: 11,
      tp: '1W6+2',
      steigerungAt: 1,
    ),
  ],
  reittierAusbildung: _ausbildung,
);

const _vertrauter = HeroCompanion(
  id: 'v',
  name: 'Mira',
  typ: BegleiterTyp.vertrauter,
  kl: 10,
  kk: 8,
  ko: 10,
  ge: 12,
  ini: 8,
  loyalitaet: 14,
  maxLep: 24,
  startLep: 24,
  maxAup: 30,
  startAup: 30,
  steigerungen: <String, int>{'ko': 1, 'lep': 3},
  angriffe: <HeroCompanionAttack>[
    HeroCompanionAttack(
      id: 'biss',
      name: 'Biss',
      at: 11,
      pa: 6,
      tp: '1W6+3',
      steigerungPa: 1,
    ),
  ],
  vertrautenBindung: VertrautenBindung(
    artId: 'vart_hund',
    ausbildungen: [VertrautenAusbildungsbuchung(katalogId: 'vausb_kampftier')],
  ),
);

/// Jede Herleitung gleicht dem Wert, den Kampfprofil und Tab verwenden.
void _pruefe(HeroCompanion c) {
  final h = begleiterHerleitungen(c);
  for (final (_, key) in kBegleiterWerte) {
    final erwartet = begleiterWirksamerWert(c, key);
    expect(h.werte[key]?.wert, erwartet, reason: '${c.name} $key');
  }
  for (final (_, key) in kBegleiterPools) {
    final erwartet = begleiterWirksamerPoolwert(c, key);
    expect(h.pools[key]?.wert, erwartet, reason: '${c.name} $key');
  }
  expect(h.angriffe, hasLength(c.angriffe.length));
  for (final (i, a) in c.angriffe.indexed) {
    expect(h.angriffe[i].at?.wert, begleiterWirksamerAngriffAt(c, a));
    expect(h.angriffe[i].pa?.wert, begleiterWirksamerAngriffPa(c, a));
  }
  final profil = begleiterKampfprofil(c);
  expect(h.werte['ini']?.wert, profil.ini);
  expect(h.pools['mr']?.wert, profil.mr);
  for (final (i, a) in profil.angriffe.indexed) {
    expect(h.angriffe[i].at?.wert, a.at);
    expect(h.angriffe[i].pa?.wert, a.pa);
  }
}

HerleitungsSchritt _schritt(Herleitung h, String name) =>
    h.schritte.singleWhere((s) => s.bezeichnung == name);

void main() {
  test('Reittier: Summen gleich den wirksamen Werten', () => _pruefe(_pferd));
  test('Vertrauter: Summen gleich den wirksamen Werten', () {
    _pruefe(_vertrauter);
  });
  test('ohne Ausbildung und Steigerung nur der Grundwert', () {
    const schlicht = HeroCompanion(id: 's', kk: 10, ini: 7, maxLep: 20);
    _pruefe(schlicht);
    final kk = begleiterHerleitungen(schlicht).werte['kk']!;
    expect(kk.wert, 10);
    expect(kk.sichtbareSchritte.map((s) => s.bezeichnung), ['Grundwert']);
  });

  test('Reittier-Ausbildung steht als eigener Schritt in Loyalität und AT', () {
    final h = begleiterHerleitungen(_pferd);
    final kk = h.werte['kk']!;
    expect(_schritt(kk, kBegleiterSteigerungSchritt).betrag, 1);
    expect(_schritt(kk, kBegleiterReittierSchritt).betrag, 0);
    expect(
      _schritt(h.werte['loyalitaet']!, kBegleiterReittierSchritt).betrag,
      greaterThan(0),
    );
    expect(
      _schritt(h.angriffe.first.at!, kBegleiterReittierSchritt).betrag,
      greaterThan(0),
    );
    expect(
      _schritt(h.angriffe.last.at!, kBegleiterSteigerungSchritt).betrag,
      1,
    );
    expect(_schritt(h.pools['lep']!, kBegleiterSteigerungSchritt).betrag, 2);
  });

  test('Tierausbildung des Vertrauten wirkt auf Werte, Pools und Angriffe', () {
    final h = begleiterHerleitungen(_vertrauter);
    expect(_schritt(h.werte['ko']!, kBegleiterSteigerungSchritt).betrag, 1);
    expect(_schritt(h.werte['ko']!, kBegleiterTierausbildungSchritt).betrag, 2);
    expect(
      _schritt(h.werte['ini']!, kBegleiterTierausbildungSchritt).betrag,
      1,
    );
    expect(
      _schritt(h.pools['lep']!, kBegleiterTierausbildungSchritt).betrag,
      7,
    );
    expect(
      _schritt(h.pools['aup']!, kBegleiterTierausbildungSchritt).betrag,
      10,
    );
    expect(
      _schritt(h.angriffe.single.at!, kBegleiterTierausbildungSchritt).betrag,
      3,
    );
    expect(
      _schritt(h.angriffe.single.pa!, kBegleiterTierausbildungSchritt).betrag,
      2,
    );
    expect(
      _schritt(h.angriffe.single.pa!, kBegleiterSteigerungSchritt).betrag,
      1,
    );
  });

  test('Angriff ohne Parade hat keine PA-Herleitung', () {
    final h = begleiterHerleitungen(_pferd);
    expect(h.angriffe.last.pa, isNull);
    expect(h.angriffe.first.pa, isNotNull);
  });

  group('Berechnungsschritte-Suche', () {
    test('Begleiter erscheinen als eigener Bereich mit ihren Werten', () {
      final eintraege = sammleHerleitungen(begleiter: [_pferd, _vertrauter]);
      expect(
        eintraege.every((e) => e.bereich == HerleitungsBereich.begleiter),
        isTrue,
      );
      final ids = eintraege.map((e) => e.id);
      expect(
        ids,
        containsAll([
          'begleiter-p1-kk',
          'begleiter-p1-lep',
          'begleiter-p1-angriff0-at',
          'begleiter-p1-angriff0-pa',
          'begleiter-p1-angriff1-at',
          'begleiter-v-ko',
          'begleiter-v-angriff0-pa',
        ]),
      );
      expect(ids, isNot(contains('begleiter-p1-angriff1-pa')));
      final kk = eintraege.firstWhere((e) => e.id == 'begleiter-p1-kk');
      expect(kk.titel, 'Falbe – KK');
      expect(kk.herleitung.wert, begleiterWirksamerWert(_pferd, 'kk'));
      expect(
        filtereHerleitungen(eintraege, 'Mira tierausbildung').map((e) => e.id),
        contains('begleiter-v-ko'),
      );
    });

    test('ohne Begleiter bleibt die Liste unverändert leer', () {
      expect(sammleHerleitungen(), isEmpty);
    });
  });
}
