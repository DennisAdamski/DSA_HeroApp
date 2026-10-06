import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_aktionskatalog_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_lage_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import '../ui2/shell/karto_test_support.dart';

void main() {
  const w = Gefechtswerte(
    iniBasis: 10,
    at: 14,
    pa: 12,
    ausweichen: 10,
    ausweichen1: true,
    waffenDk: 'N',
  );

  test('Kosten folgen WdS S. 55', () {
    final s = beginneGefecht(6, dk: 'N');
    final rufen = pruefeGefechtsBenannteAktion(
      s,
      w,
      GefechtsBenannteAktion.rufen,
    );
    expect(rufen.freie, 1);
    expect(rufen.angriffe + rufen.paraden, 0);
    final bewegen = pruefeGefechtsBenannteAktion(
      s,
      w,
      GefechtsBenannteAktion.bewegen,
    );
    expect(bewegen.angriffe + bewegen.paraden, 1);
    final sprinten = pruefeGefechtsBenannteAktion(
      s,
      w,
      GefechtsBenannteAktion.sprinten,
    );
    expect(sprinten.angriffe + sprinten.paraden, 2);
    expect(
      gefechtsAktionskosten(GefechtsBenannteAktion.zuBodenWerfen),
      GefechtsAktionskosten.frei,
    );
  });

  test('Bewegen erschwert Kampfaktionen dieser Runde genau einmal um 4', () {
    final s = beginneGefecht(6, dk: 'N');
    final vorher = pruefeGefechtsaktion(s, w, Gefechtsaktion.angriff);
    final bewegt = wendeGefechtsBenannteAktionAn(
      s,
      GefechtsBenannteAktion.bewegen,
    );
    final at = pruefeGefechtsaktion(bewegt, w, Gefechtsaktion.angriff);
    expect(at.zielwert, vorher.zielwert! - 4);
    expect(
      at.modifikatoren.where((m) => m.name == 'Nach Bewegen'),
      hasLength(1),
    );
    final pa = pruefeGefechtsaktion(bewegt, w, Gefechtsaktion.parade);
    expect(
      pa.zielwert,
      pruefeGefechtsaktion(s, w, Gefechtsaktion.parade).zielwert! - 4,
    );
    // Freies Ausweichen ist keine Kampfaktion im Sinne der +4.
    expect(
      pruefeGefechtsaktion(bewegt, w, Gefechtsaktion.freiesAusweichen).zielwert,
      pruefeGefechtsaktion(s, w, Gefechtsaktion.freiesAusweichen).zielwert,
    );
    expect(naechsteGefechtsrunde(bewegt).bewegt, isFalse);
  });

  test('Sprinten sperrt Angriff und Abwehr bis zur nächsten Runde', () {
    final s = wendeGefechtsBenannteAktionAn(
      beginneGefecht(6, dk: 'N'),
      GefechtsBenannteAktion.sprinten,
    );
    for (final a in [
      Gefechtsaktion.angriff,
      Gefechtsaktion.parade,
      Gefechtsaktion.freiesAusweichen,
      Gefechtsaktion.gezieltesAusweichen,
    ]) {
      expect(
        pruefeGefechtsaktion(s, w, a).status,
        Gefechtsfreigabe.gesperrt,
        reason: '$a',
      );
    }
    final neu = naechsteGefechtsrunde(s);
    expect(neu.gesprintet, isFalse);
    expect(
      pruefeGefechtsaktion(neu, w, Gefechtsaktion.angriff).status,
      isNot(Gefechtsfreigabe.gesperrt),
    );
  });

  test('Zu Boden werfen endet liegend und bucht INI-Verlust', () {
    final s = beginneGefecht(6, dk: 'N');
    final neu = wendeGefechtsBenannteAktionAn(
      s,
      GefechtsBenannteAktion.zuBodenWerfen,
      iniVerlust: 4,
    );
    expect(neu.haltung, Gefechtshaltung.liegend);
    expect(neu.iniVerlust, s.iniVerlust + 4);
    expect(gefechtsAupNachSturz(3, 5), 0);
    expect(gefechtsAupNachSturz(10, 4), 6);
  });

  test('Lage nach LeP und AuP (WdS S. 11)', () {
    HeroComputedSnapshot snap(int lep, int au) => buildHeroComputedSnapshot(
      hero: testHero(),
      state: HeroState(
        currentLep: lep,
        currentAsp: 0,
        currentKap: 0,
        currentAu: au,
      ),
      catalog: testCatalog,
      epicAdvantagesActive: false,
    );
    expect(gefechtsLage(snap(30, 20)), GefechtsLage.normal);
    expect(gefechtsLage(snap(6, 20)), GefechtsLage.normal);
    expect(gefechtsLage(snap(5, 20)), GefechtsLage.kampfunfaehig);
    expect(gefechtsLage(snap(0, 20)), GefechtsLage.lebensgefahr);
    expect(gefechtsLage(snap(-3, 20)), GefechtsLage.lebensgefahr);
    expect(gefechtsLage(snap(20, 0)), GefechtsLage.handlungsunfaehig);
    expect(gefechtsLagetext(GefechtsLage.normal), isNull);
    expect(gefechtsLagetext(GefechtsLage.kampfunfaehig), contains('WdS S. 11'));
  });
}
