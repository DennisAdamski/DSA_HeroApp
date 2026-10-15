import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/domain/zustands_buchung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_rest_rules.dart';

HeroState _zustand({
  int lep = 10,
  int asp = 5,
  int ueber = 6,
  int ersch = 20,
  Map<WundZone, int> wunden = const <WundZone, int>{},
}) {
  return HeroState(
    currentLep: lep,
    currentAsp: asp,
    currentKap: 0,
    currentAu: 20,
    ueberanstrengung: ueber,
    erschoepfung: ersch,
  ).copyWith(wpiZustand: WundZustand(wundenProZone: wunden));
}

void main() {
  test('Wunden: je 6 volle Stunden eine', () {
    expect(ruheKoerperWunden(5), 0);
    expect(ruheKoerperWunden(6), 1);
    expect(ruheKoerperWunden(11), 1);
    expect(ruheKoerperWunden(12), 2);
    expect(ruheKoerperWunden(0), 0);
  });

  group('Prüfung', () {
    test('ZfP* und Stunden sind nötig, Stunden höchstens ZfP*', () {
      const ok = RuheKoerperEingabe(zfpStern: 8, stunden: 8);
      expect(pruefeRuheKoerper(_zustand(), ok, maxAsp: 20).gueltig, isTrue);
      expect(
        pruefeRuheKoerper(
          _zustand(),
          const RuheKoerperEingabe(zfpStern: 8, stunden: 9),
          maxAsp: 20,
        ).gueltig,
        isFalse,
      );
      expect(
        pruefeRuheKoerper(
          _zustand(),
          const RuheKoerperEingabe(zfpStern: 0, stunden: 1),
          maxAsp: 20,
        ).gueltig,
        isFalse,
      );
      expect(
        pruefeRuheKoerper(
          _zustand(),
          const RuheKoerperEingabe(zfpStern: 8, stunden: 0),
          maxAsp: 20,
        ).gueltig,
        isFalse,
      );
    });

    test('höchstens 1 AsP je Stunde', () {
      expect(
        pruefeRuheKoerper(
          _zustand(),
          const RuheKoerperEingabe(zfpStern: 8, stunden: 4, aspRegeneration: 4),
          maxAsp: 20,
        ).gueltig,
        isTrue,
      );
      expect(
        pruefeRuheKoerper(
          _zustand(),
          const RuheKoerperEingabe(zfpStern: 8, stunden: 4, aspRegeneration: 5),
          maxAsp: 20,
        ).gueltig,
        isFalse,
      );
    });

    test('Wunden nur soweit Stunden und Eintragungen reichen', () {
      final z = _zustand(wunden: {WundZone.brust: 1, WundZone.kopf: 1});
      expect(
        pruefeRuheKoerper(
          z,
          const RuheKoerperEingabe(
            zfpStern: 12,
            stunden: 12,
            geschlosseneWunden: {WundZone.brust: 1, WundZone.kopf: 1},
          ),
          maxAsp: 20,
        ).gueltig,
        isTrue,
      );
      // 6 Stunden heilen nur eine Wunde.
      expect(
        pruefeRuheKoerper(
          z,
          const RuheKoerperEingabe(
            zfpStern: 12,
            stunden: 6,
            geschlosseneWunden: {WundZone.brust: 1, WundZone.kopf: 1},
          ),
          maxAsp: 20,
        ).gueltig,
        isFalse,
      );
      // Mehr als in der Zone eingetragen.
      expect(
        pruefeRuheKoerper(
          z,
          const RuheKoerperEingabe(
            zfpStern: 12,
            stunden: 12,
            geschlosseneWunden: {WundZone.brust: 2},
          ),
          maxAsp: 20,
        ).gueltig,
        isFalse,
      );
    });

    test('Hinweise nennen Ersatz der Regeneration und Kostenträger', () {
      final p = pruefeRuheKoerper(
        _zustand(),
        const RuheKoerperEingabe(zfpStern: 8, stunden: 8),
        maxAsp: 20,
      );
      expect(p.hinweise.any((h) => h.contains('ersetzt die normale')), isTrue);
      expect(p.hinweise.any((h) => h.contains('Zaubernde trägt')), isTrue);
    });
  });

  group('Anwendung', () {
    test('2 LeP, 4 Überanstrengung, 8 Erschöpfung je Stunde', () {
      final a = wendeRuheKoerperAn(
        _zustand(lep: 5, ueber: 20, ersch: 40),
        const RuheKoerperEingabe(zfpStern: 8, stunden: 3),
        maxLep: 30,
        maxAsp: 20,
      );

      expect(a.lep, 6);
      expect(a.zustand.currentLep, 11);
      expect(a.ueberanstrengung, 12);
      expect(a.zustand.ueberanstrengung, 8);
      expect(a.erschoepfung, 24);
      expect(a.zustand.erschoepfung, 16);
    });

    test('nichts sinkt unter 0, LeP und AsP bleiben unter dem Maximum', () {
      final a = wendeRuheKoerperAn(
        _zustand(lep: 28, asp: 19, ueber: 2, ersch: 3),
        const RuheKoerperEingabe(zfpStern: 8, stunden: 8, aspRegeneration: 5),
        maxLep: 30,
        maxAsp: 20,
      );

      expect(a.zustand.currentLep, 30);
      expect(a.lep, 2);
      expect(a.zustand.currentAsp, 20);
      expect(a.asp, 1);
      expect(a.zustand.ueberanstrengung, 0);
      expect(a.ueberanstrengung, 2);
      expect(a.zustand.erschoepfung, 0);
      expect(a.erschoepfung, 3);
    });

    test('Wunden werden zonenweise geheilt, übrige Felder bleiben', () {
      final z = _zustand(wunden: {WundZone.brust: 2, WundZone.kopf: 1});
      final a = wendeRuheKoerperAn(
        z,
        const RuheKoerperEingabe(
          zfpStern: 12,
          stunden: 12,
          geschlosseneWunden: {WundZone.brust: 1, WundZone.kopf: 1},
        ),
        maxLep: 40,
        maxAsp: 20,
      );

      expect(a.zustand.wpiZustand.wundenInZone(WundZone.brust), 1);
      expect(a.zustand.wpiZustand.wundenInZone(WundZone.kopf), 0);
      expect(a.wundenGesamt, 2);
      expect(a.zustand.currentKap, z.currentKap);
      expect(a.zustand.currentAu, z.currentAu);
    });

    test('die Buchung nennt die Zone nur bei genau einer Zone', () {
      final einzel = wendeRuheKoerperAn(
        _zustand(wunden: {WundZone.brust: 1}),
        const RuheKoerperEingabe(
          zfpStern: 6,
          stunden: 6,
          geschlosseneWunden: {WundZone.brust: 1},
        ),
        maxLep: 40,
        maxAsp: 20,
      );
      final mehrere = wendeRuheKoerperAn(
        _zustand(wunden: {WundZone.brust: 1, WundZone.kopf: 1}),
        const RuheKoerperEingabe(
          zfpStern: 12,
          stunden: 12,
          geschlosseneWunden: {WundZone.brust: 1, WundZone.kopf: 1},
        ),
        maxLep: 40,
        maxAsp: 20,
      );
      final zeit = DateTime.utc(2026, 10, 15);

      final b1 = ruheKoerperBuchungAus(
        anwendung: einzel,
        id: 'a',
        zeitpunkt: zeit,
      );
      final b2 = ruheKoerperBuchungAus(
        anwendung: mehrere,
        id: 'b',
        zeitpunkt: zeit,
      );

      expect(b1.art, ZustandsBuchungsArt.heilung);
      expect(b1.zone, WundZone.brust);
      expect(b1.wundenDelta, -1);
      expect(b2.zone, isNull);
      expect(b2.wundenDelta, -2);
      expect(b2.lepDelta, 24);
    });
  });
}
