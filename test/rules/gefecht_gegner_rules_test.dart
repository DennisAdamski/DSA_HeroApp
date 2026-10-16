import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_gegner.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_gegner_rules.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';

void main() {
  const ork = Gefechtsgegner(id: 'a', name: 'Ork', lep: 20, rs: 3, ini: 12);
  const anderer = Gefechtsgegner(id: 'b', name: 'Ork', lep: 30, rs: 1, ini: 15);

  // Kurzform für einen bestätigten Treffer.
  Gefechtsgegner treffer(
    Gefechtsgegner g,
    int tp, {
    bool direkt = false,
    WundZone? zone,
    int? wunden,
  }) => gefechtsGegnerschaden(
    g,
    Gefechtsgegnertreffer(
      buchungId: 't${g.treffer.length}',
      tp: tp,
      direkt: direkt,
      zone: zone,
      wunden: wunden,
    ),
  );

  test('Zielwechsel trennt IDs und verwirft veraltete Angriffsdaten', () {
    const alt = Gefechtszustand(
      iniWurf: 6,
      kontext: Gefechtskontext(
        kontakt: 'Ork',
        gegnerId: 'a',
        finte: 4,
        entfernung: 12,
      ),
    );
    final neu = waehleGefechtsgegner(alt, anderer, startDk: 'N');
    expect(neu.kontext.gegnerId, 'b');
    expect(neu.kontext.zielkennung, isNot(alt.kontext.zielkennung));
    expect(neu.kontext.entfernung, isNull);
    expect(neu.kontext.finte, 0);
    expect(neu.kontext.ohneAngriff().gegnerId, 'b');
    expect(neu.kontext.copyWith(entfernung: 3).gegnerId, 'b');
  });

  test(
    'TP berücksichtigt RS, direkte SP umgehen ihn, LeP dürfen negativ sein',
    () {
      expect(gefechtsGegnerstand(treffer(ork, 8)).lep, 15);
      expect(gefechtsGegnerstand(treffer(ork, 2)).lep, 20);
      expect(gefechtsGegnerstand(treffer(ork, 8, direkt: true)).lep, 12);
      expect(gefechtsGegnerstand(treffer(ork, 30)).lep, -7);
      expect(gefechtsGegnerstand(treffer(treffer(ork, 8), 6)).sp, 8);
      expect(() => treffer(ork, -1), throwsArgumentError);
      expect(() => treffer(ork, 5, wunden: 4), throwsArgumentError);
    },
  );

  test('Unbekannter RS hält TP offen und verrechnet sie nachträglich', () {
    final g = treffer(treffer(ork.copyWith(rs: null), 9), 4, direkt: true);
    final offen = gefechtsGegnerstand(g);
    expect(offen.tpOhneRs, 9);
    expect(offen.sp, 4);
    expect(offen.lep, isNull);
    final bekannt = gefechtsGegnerstand(g.copyWith(rs: 2));
    expect(bekannt.tpOhneRs, 0);
    expect(bekannt.sp, 11);
    expect(bekannt.lep, 9);
    expect(gefechtsGegnerstand(g.copyWith(lep: null, rs: 2)).lep, isNull);
  });

  test('Wunden nach Schwellen, höchstens drei je Zone, sonst von Hand', () {
    // KO 12: Schwellen 6 / 12 / 18 (WdS S. 57).
    final g = ork.copyWith(ko: 12);
    expect(gefechtsGegnerstand(g).wundschwellen, [6, 12, 18]);
    final zwei = gefechtsGegnerstand(treffer(g, 16, zone: WundZone.brust));
    expect(zwei.wunden, 2);
    expect(zwei.wundenNachZone, {WundZone.brust: 2});
    final gedeckelt = gefechtsGegnerstand(
      treffer(treffer(g, 16, zone: WundZone.brust), 25, zone: WundZone.brust),
    );
    expect(gedeckelt.wirkungen.last.wunden, 3);
    expect(gedeckelt.wundenNachZone[WundZone.brust], 3);
    expect(gedeckelt.wunden, 3);
    final ohneZone = gefechtsGegnerstand(treffer(g, 10));
    expect(ohneZone.wundenOhneZone, 1);
    // Ohne KO zählen nur bestätigte Wunden; mit KO wird neu gerechnet.
    final hand = treffer(ork, 10, wunden: 2, zone: WundZone.kopf);
    expect(gefechtsGegnerstand(hand).wunden, 2);
    expect(gefechtsGegnerstand(hand).wirkungen.single.wundenBerechnet, isFalse);
    expect(gefechtsGegnerstand(hand.copyWith(ko: 12)).wunden, 1);
  });

  test(
    'IDs trennen gleiche Namen, frischer RS und einmalige Buchung gelten',
    () {
      var s = Gefechtsbegegnung(gegner: {'a': ork, 'b': anderer});
      s = bucheGefechtsGegnerschaden(s, gegnerId: 'a', buchungId: 'h:1', tp: 8);
      expect(gefechtsGegnerstand(s.gegner['a']!).lep, 15);
      expect(gefechtsGegnerstand(s.gegner['b']!).lep, 30);
      expect(
        identical(
          bucheGefechtsGegnerschaden(s, gegnerId: 'a', buchungId: 'h:1', tp: 8),
          s,
        ),
        isTrue,
      );
      // Profiländerung wirkt auf den frischen Gegner und alle Treffer.
      s = speichereGefechtsgegnerprofil(s, ork.copyWith(name: 'Ork 1', rs: 5));
      expect(s.gegner['a']!.treffer, hasLength(1));
      expect(s.gegner['a']!.name, 'Ork 1');
      s = bucheGefechtsGegnerschaden(s, gegnerId: 'a', buchungId: 'h:2', tp: 8);
      expect(gefechtsGegnerstand(s.gegner['a']!).lep, 14);
    },
  );

  test('Profil erhält Folgen und Bindung, die nach dem Öffnen entstanden', () {
    var s = Gefechtsbegegnung(gegner: {'a': ork});
    s = speichereGefechtsgegner(
      s,
      ork.copyWith(liegend: true, bindet: 'held', ini: 4),
    );
    s = speichereGefechtsgegnerprofil(
      s,
      ork.copyWith(groesse: GefechtsGroesse.gross),
    );
    final g = s.gegner['a']!;
    expect(g.liegend, isTrue);
    expect(g.bindet, 'held');
    expect(g.groesse, GefechtsGroesse.gross);
    expect(g.ini, 12);
  });

  test('Rücknahme entfernt den Treffer, die Buchung bleibt verbraucht', () {
    var s = Gefechtsbegegnung(gegner: {'a': ork});
    s = bucheGefechtsGegnerschaden(s, gegnerId: 'a', buchungId: 'h:1', tp: 8);
    s = nimmGefechtsGegnertrefferZurueck(s, gegnerId: 'a', buchungId: 'h:1');
    expect(s.gegner['a']!.treffer, isEmpty);
    expect(gefechtsGegnerstand(s.gegner['a']!).lep, 20);
    final erneut = bucheGefechtsGegnerschaden(
      s,
      gegnerId: 'a',
      buchungId: 'h:1',
      tp: 8,
    );
    expect(identical(erneut, s), isTrue);
    expect(
      identical(
        nimmGefechtsGegnertrefferZurueck(s, gegnerId: 'x', buchungId: 'h:1'),
        s,
      ),
      isTrue,
    );
  });

  test('Ungültige Profile und verschwundene Ziele verändern nichts', () {
    const leer = Gefechtsbegegnung();
    expect(
      () => speichereGefechtsgegner(leer, ork.copyWith(rs: -1)),
      throwsArgumentError,
    );
    expect(
      () => speichereGefechtsgegner(leer, ork.copyWith(lep: 0)),
      throwsArgumentError,
    );
    expect(
      () => speichereGefechtsgegner(leer, ork.copyWith(ko: 0)),
      throwsArgumentError,
    );
    expect(
      speichereGefechtsgegner(
        leer,
        ork.copyWith(lep: null, rs: null),
      ).gegner['a']!.rs,
      isNull,
    );
    expect(
      () => bucheGefechtsGegnerschaden(
        leer,
        gegnerId: 'a',
        buchungId: 'h:1',
        tp: 8,
      ),
      throwsStateError,
    );
  });
  test('Nur Kämpfende handeln; Tote und Geflohene sind kein Ziel', () {
    final s = Gefechtsbegegnung(
      gegner: {
        'a': ork.copyWith(status: GefechtsgegnerStatus.kampfunfaehig),
        'b': anderer,
        'c': ork.copyWith(status: GefechtsgegnerStatus.tot),
        'd': ork.copyWith(status: GefechtsgegnerStatus.geflohen),
      }.map((k, g) => MapEntry(k, _mitId(g, k))),
    );
    expect(s.gegner.values.where(gefechtsGegnerHandelt).map((g) => g.id), [
      'b',
    ]);
    expect(gefechtsAngreifbareGegner(s).map((g) => g.id), ['b', 'a']);
    expect(
      () => waehleGefechtsgegner(
        const Gefechtszustand(iniWurf: 6),
        s.gegner['c']!,
        startDk: 'N',
      ),
      throwsStateError,
    );
    expect(
      waehleGefechtsgegner(
        const Gefechtszustand(iniWurf: 6),
        s.gegner['a']!,
        startDk: 'N',
      ).kontext.gegnerId,
      'a',
    );
  });

  test('Statusvorschläge nach LeP, KO und Körperbau, nie ohne LeP', () {
    GefechtsgegnerStatus? vorschlag(Gefechtsgegner g) =>
        gefechtsGegnerStatusvorschlag(g)?.status;
    // Ork: 20 LeP, RS 3.
    expect(vorschlag(treffer(ork, 10)), isNull);
    expect(vorschlag(treffer(ork, 18)), GefechtsgegnerStatus.kampfunfaehig);
    expect(vorschlag(treffer(ork, 23)), GefechtsgegnerStatus.kampfunfaehig);
    final tot = treffer(ork.copyWith(ko: 10), 34);
    expect(gefechtsGegnerstand(tot).lep, -11);
    expect(vorschlag(tot), GefechtsgegnerStatus.tot);
    expect(
      vorschlag(tot.copyWith(status: GefechtsgegnerStatus.kampfunfaehig)),
      GefechtsgegnerStatus.tot,
    );
    expect(vorschlag(tot.copyWith(status: GefechtsgegnerStatus.tot)), isNull);
    expect(vorschlag(treffer(ork.copyWith(lep: null), 18)), isNull);
    expect(vorschlag(treffer(ork.copyWith(rs: null), 18)), isNull);
    // Wolf: 24 LeP, RS 0 – Flucht ab einem Drittel, nicht schon bei 9.
    const wolf = Gefechtsgegner(
      id: 'w',
      name: 'Wolf',
      lep: 24,
      rs: 0,
      ini: 12,
      koerperbau: GefechtsKoerperbau.tier,
    );
    expect(vorschlag(treffer(wolf, 15)), isNull);
    expect(vorschlag(treffer(wolf, 16)), GefechtsgegnerStatus.geflohen);
    expect(vorschlag(treffer(wolf, 24)), GefechtsgegnerStatus.kampfunfaehig);
    expect(
      vorschlag(
        treffer(wolf, 16).copyWith(status: GefechtsgegnerStatus.kampfunfaehig),
      ),
      isNull,
    );
  });

  test('Status wird nur ausdrücklich und auf dem frischen Gegner gesetzt', () {
    var s = Gefechtsbegegnung(gegner: {'a': ork});
    s = bucheGefechtsGegnerschaden(s, gegnerId: 'a', buchungId: 'h:1', tp: 8);
    expect(s.gegner['a']!.status, GefechtsgegnerStatus.kaempft);
    final neu = setzeGefechtsgegnerStatus(
      s,
      gegnerId: 'a',
      status: GefechtsgegnerStatus.geflohen,
    );
    expect(neu.gegner['a']!.status, GefechtsgegnerStatus.geflohen);
    expect(neu.gegner['a']!.treffer, hasLength(1));
    expect(
      identical(
        setzeGefechtsgegnerStatus(
          neu,
          gegnerId: 'a',
          status: GefechtsgegnerStatus.geflohen,
        ),
        neu,
      ),
      isTrue,
    );
    expect(
      () => setzeGefechtsgegnerStatus(
        s,
        gegnerId: 'x',
        status: GefechtsgegnerStatus.tot,
      ),
      throwsStateError,
    );
  });
  test('Zielwahl belegt Größe, Getümmel und die DK der Paarung vor', () {
    expect(
      [for (final g in GefechtsGroesse.values) gefechtsZielgroesseZuschlag(g)],
      [8, 6, 4, 2, 0, -2],
    );
    final riese = _mitId(
      ork,
      'r',
    ).copyWith(groesse: GefechtsGroesse.sehrGross, bindet: 'bosper');
    final wolf = _mitId(
      ork,
      'w',
    ).copyWith(groesse: GefechtsGroesse.klein, bindet: 'held');
    var s = waehleGefechtsgegner(
      const Gefechtszustand(iniWurf: 6),
      riese,
      startDk: 'N',
      heldId: 'held',
    );
    expect(s.kontext.situationsZuschlag, -2);
    expect(s.kontext.sehrGross, isTrue);
    expect(s.kontext.getuemmel, isTrue);
    s = s.copyWith(dk: 'S');
    s = waehleGefechtsgegner(s, wolf, startDk: 'N', heldId: 'held');
    expect(s.kontext.situationsZuschlag, 4);
    expect(s.kontext.sehrGross, isFalse);
    // Bindet er den Schützen selbst, ist es kein Schuss ins Getümmel.
    expect(s.kontext.getuemmel, isFalse);
    expect(s.dk, 'N');
    s = s.copyWith(dk: 'H');
    s = waehleGefechtsgegner(s, riese, startDk: 'N', heldId: 'held');
    expect(s.dk, 'S');
    expect(s.dkJeGegner, {'r': 'S', 'w': 'H'});
  });
}

// Kopie mit anderer ID für Begegnungen aus einer Vorlage.
Gefechtsgegner _mitId(Gefechtsgegner g, String id) => Gefechtsgegner(
  id: id,
  name: g.name,
  lep: g.lep,
  rs: g.rs,
  ko: g.ko,
  ini: g.ini,
  status: g.status,
  groesse: g.groesse,
  bindet: g.bindet,
);
