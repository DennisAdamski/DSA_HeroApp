import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_kampfprofil_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_wirkwert_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/companion_steigerung_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wirkwerte von Begleitern: Grundwert + Steigerung + Ausbildung.
void main() {
  const ausbildung = ReittierAusbildung(
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
  const pferd = HeroCompanion(
    id: 'p1',
    name: 'Falbe',
    typ: BegleiterTyp.reittier,
    kk: 20,
    loyalitaet: 12,
    ini: 9,
    steigerungen: <String, int>{'kk': 1},
    geschwindigkeiten: <HeroCompanionSpeed>[
      HeroCompanionSpeed(art: 'Schritt', wert: 2),
      HeroCompanionSpeed(art: 'Trab', wert: 12),
      HeroCompanionSpeed(art: 'Galopp', wert: 15),
    ],
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
    reittierAusbildung: ausbildung,
  );

  test('KK und Loyalitaet enthalten Steigerung und Ausbildung', () {
    expect(begleiterWirksamerWert(pferd, 'kk'), 21);
    expect(begleiterWirksamerWert(pferd, 'loyalitaet'), 16);
    expect(begleiterWirksamerWert(pferd, 'ini'), 9);
    // Die Vertrauten-Steigerung baut weiter auf dem Wert ohne Ausbildung auf.
    expect(companionEffektivwert(pferd, 'loyalitaet'), 12);
  });

  test('AT gilt fuer alle Angriffe, der TP-Bonus nur fuer Tritte', () {
    final biss = pferd.angriffe.first;
    final tritt = pferd.angriffe.last;

    expect(begleiterWirksamerAngriffAt(pferd, biss), 12);
    expect(begleiterWirksamerAngriffAt(pferd, tritt), 13);
    expect(begleiterWirksamerAngriffTp(pferd, biss), '1W6+1');
    expect(begleiterWirksamerAngriffTp(pferd, tritt), '1W6+3');
  });

  test('Trab und Galopp folgen der Variante, Schritt bleibt', () {
    final bote = pferd.copyWith(
      reittierAusbildung: ausbildung.copyWith(varianteId: 'pvar_botenpferd'),
    );

    expect(begleiterWirksameGeschwindigkeiten(bote).map((s) => s.wert), <int>[
      2,
      14,
      16,
    ]);
  });

  test('ohne Reittier-Typ wirkt keine Ausbildung', () {
    final vertrauter = pferd.copyWith(typ: BegleiterTyp.vertrauter);

    expect(begleiterWirksamerWert(vertrauter, 'loyalitaet'), 12);
    expect(begleiterWirksamerAngriffAt(vertrauter, pferd.angriffe.first), 11);
    expect(begleiterKampfprofil(vertrauter).reittier, isNull);
  });

  test('gekaufte GS-Stufen stecken im wirksamen Wert', () {
    const vertrauter = HeroCompanion(
      id: 'v',
      typ: BegleiterTyp.vertrauter,
      geschwindigkeiten: [
        HeroCompanionSpeed(art: 'Boden', wert: 1),
        HeroCompanionSpeed(art: 'Fliegen', wert: 12, steigerung: 2),
      ],
    );

    expect(begleiterWirksameGeschwindigkeiten(vertrauter).map((s) => s.wert), [
      1,
      14,
    ]);
  });

  test('Trag- und Zugkraft bekommen den Ausbildungsfaktor', () {
    expect(begleiterWirksameKraft('x5', 1), '×6');
    expect(begleiterWirksameKraft('x5', 0), 'x5');
    expect(begleiterWirksameKraft('viel', 2), 'viel (+2×KK durch Ausbildung)');
  });

  test('das Kampfprofil zeigt Wirkwerte und den Ausbildungsstand', () {
    final profil = begleiterKampfprofil(pferd);

    expect(profil.angriffe.last.at, 13);
    expect(profil.angriffe.last.tp, '1W6+3');
    expect(profil.reittier!.stufe, 'geschult');
    expect(profil.reittier!.variante, 'Leichtes Streitross');
    expect(profil.reittier!.kampfpferd, isTrue);
    expect(profil.reittier!.reitenNormal, -2);
    expect(profil.reittier!.reitenImKampf, -3);
  });
}
