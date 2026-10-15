import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/domain/zustands_buchung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_healing_rules.dart';

HeroState _zustand({
  int lep = 10,
  int asp = 20,
  Map<WundZone, int> wunden = const <WundZone, int>{},
}) {
  return HeroState(
    currentLep: lep,
    currentAsp: asp,
    currentKap: 0,
    currentAu: 20,
  ).copyWith(wpiZustand: WundZustand(wundenProZone: wunden));
}

HeilEingabe _balsam({
  int asp = 10,
  int zfw = 8,
  bool wundheilung = false,
  WundZone? zone,
  int wunden = 0,
  bool selbst = false,
}) => HeilEingabe(
  zauberId: kBalsamZauberId,
  asp: asp,
  zfw: zfw,
  wundheilungAngesagt: wundheilung,
  zone: zone,
  wunden: wunden,
  selbstGewirkt: selbst,
);

HeilEingabe _speichel({
  int asp = 8,
  int zfw = 10,
  HeilSchaden schaden = HeilSchaden.wunde,
  bool selbst = false,
}) => HeilEingabe(
  zauberId: kHexenspeichelZauberId,
  asp: asp,
  zfw: zfw,
  schaden: schaden,
  selbstGewirkt: selbst,
);

void main() {
  group('Balsam', () {
    test('1 LeP je AsP, Kosten gleich den AsP', () {
      final p = pruefeHeilung(_zustand(), _balsam(asp: 10), maxLep: 30);
      expect(p.gueltig, isTrue, reason: p.fehler.join('; '));
      expect(p.lep, 10);
      expect(p.kosten, 10);
    });

    test('mindestens 5 AsP, höchstens ZfW × 2', () {
      expect(
        pruefeHeilung(_zustand(), _balsam(asp: 4), maxLep: 30).gueltig,
        isFalse,
      );
      expect(
        pruefeHeilung(_zustand(), _balsam(asp: 5), maxLep: 30).gueltig,
        isTrue,
      );
      expect(
        pruefeHeilung(_zustand(), _balsam(asp: 16, zfw: 8), maxLep: 30).gueltig,
        isTrue,
      );
      expect(
        pruefeHeilung(_zustand(), _balsam(asp: 17, zfw: 8), maxLep: 30).gueltig,
        isFalse,
      );
    });

    test('ohne ZfW keine Heilung', () {
      expect(
        pruefeHeilung(_zustand(), _balsam(zfw: 0), maxLep: 30).gueltig,
        isFalse,
      );
    });

    test('Wunden nur bei angesagter Wundheilung: je 7 LeP eine', () {
      final z = _zustand(wunden: {WundZone.brust: 2});
      final ohne = pruefeHeilung(z, _balsam(asp: 15), maxLep: 40);
      final mit = pruefeHeilung(
        z,
        _balsam(asp: 15, wundheilung: true, zone: WundZone.brust, wunden: 2),
        maxLep: 40,
      );

      expect(ohne.wundenVorschlag, 0);
      expect(mit.wundenVorschlag, 2);
      expect(mit.gueltig, isTrue, reason: mit.fehler.join('; '));
      expect(mit.hinweise.any((h) => h.contains('doppelte Zahl')), isTrue);
    });

    test('mehr Wunden als in der Zone, oder ohne Zone, sperren', () {
      final z = _zustand(wunden: {WundZone.brust: 1});
      expect(
        pruefeHeilung(
          z,
          _balsam(wundheilung: true, zone: WundZone.brust, wunden: 2),
          maxLep: 40,
        ).gueltig,
        isFalse,
      );
      expect(
        pruefeHeilung(
          z,
          _balsam(wundheilung: true, wunden: 1),
          maxLep: 40,
        ).gueltig,
        isFalse,
      );
    });

    test('Anwendung: LeP nur bis zum Maximum, Wunden geschlossen', () {
      final z = _zustand(
        lep: 25,
        wunden: {WundZone.brust: 2, WundZone.kopf: 1},
      );
      final eingabe = _balsam(
        asp: 14,
        wundheilung: true,
        zone: WundZone.brust,
        wunden: 2,
      );

      final a = wendeHeilungAn(z, eingabe, maxLep: 30);

      expect(a.lep, 5);
      expect(a.zustand.currentLep, 30);
      expect(a.wunden, 2);
      expect(a.zustand.wpiZustand.wundenInZone(WundZone.brust), 0);
      expect(a.zustand.wpiZustand.wundenInZone(WundZone.kopf), 1);
      expect(a.asp, 0);
      expect(a.zustand.currentAsp, 20);
    });

    test('fremde Quelle zieht keine AsP ab, Selbstwirkung schon', () {
      final fremd = wendeHeilungAn(_zustand(), _balsam(asp: 10), maxLep: 40);
      final selbst = wendeHeilungAn(
        _zustand(),
        _balsam(asp: 10, selbst: true),
        maxLep: 40,
      );

      expect(fremd.zustand.currentAsp, 20);
      expect(selbst.zustand.currentAsp, 10);
      expect(selbst.asp, 10);
    });

    test('Selbstwirkung mit zu wenigen AsP sperrt, nichts wird negativ', () {
      final p = pruefeHeilung(
        _zustand(asp: 6),
        _balsam(asp: 10, selbst: true),
        maxLep: 40,
      );
      expect(p.gueltig, isFalse);
    });

    test(
      'bei 0 LeP oder weniger wird die Rettungsvariante nicht gerechnet',
      () {
        for (final lep in [0, -5]) {
          final p = pruefeHeilung(_zustand(lep: lep), _balsam(), maxLep: 40);
          expect(p.gueltig, isFalse);
          expect(p.fehler.first, contains('Schwelle des Todes'));
        }
      },
    );
  });

  group('Hexenspeichel', () {
    test('Wunden: 1 LeP je 2 AsP, ungerade AsP sind nicht belegt', () {
      final p = pruefeHeilung(_zustand(), _speichel(asp: 8), maxLep: 40);
      expect(p.lep, 4);
      expect(p.kosten, 8);
      final ungerade = pruefeHeilung(_zustand(), _speichel(asp: 7), maxLep: 40);
      expect(ungerade.gueltig, isFalse);
      expect(ungerade.fehler.first, contains('Rundung'));
    });

    test('Krankheit 1 LeP je AsP, Vergiftung 2 LeP je AsP', () {
      expect(
        pruefeHeilung(
          _zustand(),
          _speichel(asp: 7, schaden: HeilSchaden.krankheit),
          maxLep: 40,
        ).lep,
        7,
      );
      expect(
        pruefeHeilung(
          _zustand(),
          _speichel(asp: 7, schaden: HeilSchaden.vergiftung),
          maxLep: 40,
        ).lep,
        14,
      );
    });

    test('höchstens ZfW AsP auf einmal', () {
      expect(
        pruefeHeilung(
          _zustand(),
          _speichel(asp: 10, zfw: 10),
          maxLep: 40,
        ).gueltig,
        isTrue,
      );
      expect(
        pruefeHeilung(
          _zustand(),
          _speichel(asp: 12, zfw: 10),
          maxLep: 40,
        ).gueltig,
        isFalse,
      );
    });

    test(
      'schließt keine Wunden und heilt sich nicht stillschweigend selbst',
      () {
        final wundheilung = pruefeHeilung(
          _zustand(wunden: {WundZone.brust: 1}),
          const HeilEingabe(
            zauberId: kHexenspeichelZauberId,
            asp: 8,
            zfw: 10,
            wundheilungAngesagt: true,
          ),
          maxLep: 40,
        );
        expect(wundheilung.gueltig, isFalse);

        final selbst = pruefeHeilung(
          _zustand(),
          _speichel(selbst: true),
          maxLep: 40,
        );
        expect(selbst.gueltig, isTrue);
        expect(selbst.hinweise.any((h) => h.contains('nicht selbst')), isTrue);
      },
    );
  });

  test('unbekannter Zauber ist nicht gültig', () {
    final p = pruefeHeilung(
      _zustand(),
      const HeilEingabe(zauberId: 'spell_x', asp: 5, zfw: 5),
      maxLep: 30,
    );
    expect(p.gueltig, isFalse);
  });

  test('die Buchung hält die tatsächlichen Änderungen fest', () {
    final z = _zustand(lep: 25, wunden: {WundZone.brust: 1});
    final eingabe = _balsam(
      asp: 10,
      selbst: true,
      wundheilung: true,
      zone: WundZone.brust,
      wunden: 1,
    );
    final a = wendeHeilungAn(z, eingabe, maxLep: 30);

    final b = heilungsBuchungAus(
      eingabe: eingabe,
      anwendung: a,
      id: 'h1',
      zeitpunkt: DateTime.utc(2026, 10, 15),
    );

    expect(b.art, ZustandsBuchungsArt.heilung);
    expect(b.lepDelta, 5);
    expect(b.aspDelta, -10);
    expect(b.wundenDelta, -1);
    expect(b.zone, WundZone.brust);
  });
}
