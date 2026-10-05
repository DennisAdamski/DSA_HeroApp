import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_auftrag_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_laden_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_zielen_rules.dart';

import 'gefecht_laden_rules_test.dart' as fixture;
import '../ui2/shell/karto_test_support.dart';

/// Ein bestätigter Fernkampfangriff ohne zusätzliche Zielautomatisierung.
GefechtAuftrag zielauftrag({int erleichterung = 2, int ansage = 0}) =>
    GefechtAuftrag(
      aktion: Gefechtsaktion.angriff,
      titel: 'Angreifen',
      zuschlag: 0,
      dk: null,
      dauer: 1,
      kosten: 1,
      kampfmittel: fixture.mittel,
      fernkampfansage: ansage,
      zielErleichterung: erleichterung,
      kontext: const Gefechtskontext(
        kontakt: 'Ork',
        geladen: true,
        entfernung: 20,
        situationsZuschlag: 0,
      ),
    );

// Zahlt echte reguläre Marken, setzt nur bei erschöpftem Budget die Runde fort.
Gefechtszustand _bezahlen(GefechtAuftrag a) {
  final snap = fixture.ladeSnapshot();
  var s = beginneGefechtsZielen(
    const Gefechtszustand(iniWurf: 6),
    snap,
    testCatalog,
    a,
  );
  while (s.handlung!.verbleibend > 0) {
    if (s.angriffeVerbraucht + s.paradenVerbraucht == 2) {
      s = naechsteGefechtsrunde(s);
    }
    s = bezahleGefechtsVorbereitung(s, snap);
  }
  return naechsteGefechtsrunde(s);
}

void main() {
  for (final sf in ['man_scharfschuetze', 'man_meisterschuetze']) {
    test('Talentgebundene $sf verkürzt den echten Zielauftrag', () {
      final basis = fixture.ladeSnapshot();
      final talent = basis.hero.combatConfig.selectedWeapon.talentId;
      final snap = buildHeroComputedSnapshot(
        hero: basis.hero.copyWith(
          combatConfig: basis.hero.combatConfig.copyWith(
            specialRules: CombatSpecialRules(activeManeuvers: ['$sf::$talent']),
          ),
        ),
        state: const HeroState.empty(),
        catalog: testCatalog,
        epicAdvantagesActive: false,
      );
      final a = zielauftrag(erleichterung: 4);
      expect(gefechtsZieldauer(snap, a), 4);
      expect(
        pruefeGefechtsZielbeginn(
          const Gefechtszustand(iniWurf: 6),
          snap,
          testCatalog,
          a,
        ).ausfuehrbar,
        true,
      );
    });
  }
  test('Zieldauer: zwei Aktionen je Punkt, passende SF eine, maximal vier', () {
    for (var n = 0; n <= 4; n++) {
      expect(gefechtsOptionaleZieldauer(n), n * 2);
      expect(gefechtsOptionaleZieldauer(n, scharfschuetze: true), n);
      expect(gefechtsOptionaleZieldauer(n, meisterschuetze: true), n);
    }
  });
  test(
    'Zielen ohne Ansage bezahlt reguläre Marken und sperrt frühen Schuss',
    () {
      final snap = fixture.ladeSnapshot();
      final a = zielauftrag();
      final s = beginneGefechtsZielen(
        const Gefechtszustand(iniWurf: 6),
        snap,
        testCatalog,
        a,
      );
      expect(s.angriffeVerbraucht, 1);
      expect(s.paradenVerbraucht, 0);
      expect(s.zusatzVerbraucht, 0);
      expect(s.handlung!.verbleibend, 3);
      expect(pruefeGefechtsZielschuss(s, snap, testCatalog).ausfuehrbar, false);
    },
  );
  test('Bezahltes Zielen erhöht genau einmal das reale Probenziel', () {
    final snap = fixture.ladeSnapshot();
    final a = zielauftrag();
    final fertig = _bezahlen(a);
    final p = pruefeGefechtsZielschuss(fertig, snap, testCatalog);
    final ohne = pruefeGefechtAuftrag(
      const Gefechtszustand(iniWurf: 6),
      snap,
      testCatalog,
      zielauftrag(erleichterung: 0),
    );
    expect(p.ausfuehrbar, true);
    expect(p.zielwert, ohne.zielwert! + 2);
    expect(
      p.modifikatoren.where((m) => m.name == 'Optionales Zielen'),
      hasLength(1),
    );
    expect(fertig.zielstand!.zielErleichterung, 2);
    expect(gefechtsAktuellerZielauftrag(fertig).zielErleichterung, 2);
  });
  test('Ansagezeit und optionale Zielzeit werden getrennt bezahlt', () {
    final snap = fixture.ladeSnapshot();
    final a = zielauftrag(erleichterung: 4, ansage: 5);
    expect(gefechtsZieldauer(snap, a), 11);
    final s = _bezahlen(a);
    final p = pruefeGefechtsZielschuss(s, snap, testCatalog);
    expect(p.ausfuehrbar, true);
    expect(
      p.erschwernis,
      5,
      reason: 'Entfernung +4 fällt weg, Ansage +5 bleibt.',
    );
    expect(
      p.modifikatoren.singleWhere((m) => m.name == 'Fernkampfansage').wert,
      5,
    );
  });
  test(
    'Optionales Zielen baut den Zuschlag des Gezielten Schusses nicht ab',
    () {
      final a = zielauftrag(erleichterung: 4);
      final s = _bezahlen(a);
      const basis = Gefechtspruefung(
        aktion: Gefechtsaktion.angriff,
        status: Gefechtsfreigabe.bereit,
        gruende: [],
        zielwert: 8,
        erschwernis: 12,
        kampfmittel: fixture.mittel,
        modifikatoren: [
          Gefechtsmodifikator('Entfernung', 4),
          Gefechtsmodifikator('Gezielter Schuss', 8),
        ],
      );
      final p = ergaenzeGefechtsZielen(basis, s, fixture.ladeSnapshot(), a);
      expect(p.zielwert, 12);
      expect(p.erschwernis, 8);
      expect(
        p.modifikatoren.singleWhere((m) => m.name == 'Gezielter Schuss').wert,
        8,
      );
    },
  );
  test(
    'Frische Zielsituation begrenzt Erleichterung auf vorhandenen Zuschlag',
    () {
      final snap = fixture.ladeSnapshot();
      final s = _bezahlen(zielauftrag(erleichterung: 4));
      final frisch = s.copyWith(kontext: s.kontext.copyWith(entfernung: 10));
      final p = pruefeGefechtsZielschuss(frisch, snap, testCatalog);
      expect(p.ausfuehrbar, true);
      expect(p.erschwernis, 0);
    },
  );
  test(
    'Unbezahlte, negative und zu große Zielerleichterung bleiben gesperrt',
    () {
      final snap = fixture.ladeSnapshot();
      for (final n in [-1, 2, 5]) {
        final p = pruefeGefechtAuftrag(
          const Gefechtszustand(iniWurf: 6),
          snap,
          testCatalog,
          zielauftrag(erleichterung: n),
        );
        expect(p.ausfuehrbar, false);
      }
    },
  );
  test('Zielwechsel überträgt die bezahlte optionale Erleichterung nicht', () {
    final snap = fixture.ladeSnapshot();
    final s = _bezahlen(zielauftrag());
    final fremd = s.copyWith(kontext: const Gefechtskontext(kontakt: 'Goblin'));
    expect(
      pruefeGefechtsZielschuss(fremd, snap, testCatalog).ausfuehrbar,
      false,
    );
    expect(
      pruefeGefechtsZielschuss(
        s,
        fixture.ladeSnapshot(geschoss: 1),
        testCatalog,
      ).ausfuehrbar,
      false,
    );
  });
}
