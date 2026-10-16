import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/vitalwirkung_anwenden.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/vitalwirkung.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/domain/zustands_buchung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/vitalwirkung_rules.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

final _jetzt = DateTime.utc(2026, 10, 15, 20);

const _grenzen = VitalGrenzen(maxLep: 30, maxAsp: 20, maxAu: 25);

final _start =
    const HeroState(
      currentLep: 12,
      currentAsp: 18,
      currentKap: 0,
      currentAu: 10,
    ).copyWith(
      wpiZustand: const WundZustand(
        wundenProZone: {WundZone.brust: 2, WundZone.kopf: 1},
      ),
    );

VitalwirkungAnwenden _ablauf(FakeRepository repo) =>
    VitalwirkungAnwenden(repository: repo, uhr: () => _jetzt);

void main() {
  group('Regeln', () {
    test('verlangt mindestens eine Wirkung', () {
      final p = pruefeVitalwirkung(
        _start,
        const VitalEingabe(),
        grenzen: _grenzen,
      );
      expect(p.gueltig, isFalse);
    });

    test('lehnt mehr Wunden ab, als in der Zone stehen', () {
      final p = pruefeVitalwirkung(
        _start,
        const VitalEingabe(wundenJeZone: {WundZone.brust: 3}),
        grenzen: _grenzen,
      );
      expect(p.gueltig, isFalse);
    });

    test('begrenzt auf das Maximum und meldet es als Hinweis', () {
      const eingabe = VitalEingabe(lep: 25, asp: 5, aup: 3);
      final p = pruefeVitalwirkung(_start, eingabe, grenzen: _grenzen);
      expect(p.gueltig, isTrue);
      expect(p.hinweise, hasLength(2));

      final a = wendeVitalwirkungAn(_start, eingabe, grenzen: _grenzen);
      expect(a.zustand.currentLep, 30);
      expect(a.zustand.currentAsp, 20);
      expect(a.zustand.currentAu, 13);
      expect(a.lep, 18);
      expect(a.asp, 2);
      expect(a.aup, 3);
    });

    test('heilt aus negativen LeP und schließt Wunden je Zone', () {
      final tief = _start.copyWith(currentLep: -3);
      final a = wendeVitalwirkungAn(
        tief,
        const VitalEingabe(
          lep: 8,
          wundenJeZone: {WundZone.brust: 1, WundZone.kopf: 1},
        ),
        grenzen: _grenzen,
      );
      expect(a.zustand.currentLep, 5);
      expect(a.zustand.wpiZustand.wundenInZone(WundZone.brust), 1);
      expect(a.zustand.wpiZustand.wundenInZone(WundZone.kopf), 0);
      expect(a.wunden, 2);
    });

    test('Vorschlag verteilt die Wunden der Vorgabe auf vorhandene Zonen', () {
      final v = vitalVorschlag(const Vitalwirkung(lep: 6, wunden: 5), _start);
      expect(v.lep, 6);
      expect(v.wundenGesamt, 3);
    });
  });

  group('Ablauf', () {
    test('bucht alles in einem Dokument und protokolliert', () async {
      final repo = FakeRepository(states: {'held': _start});
      final a = await _ablauf(repo).uebernimm(
        heroId: 'held',
        eingabe: const VitalEingabe(
          lep: 9,
          aup: 4,
          wundenJeZone: {WundZone.brust: 1},
        ),
        gegenstand: 'Heiltrank',
        grenzen: _grenzen,
        vorgangId: 'v1',
      );

      final z = (await repo.loadHeroState('held'))!;
      expect(z.currentLep, 21);
      expect(z.currentAu, 14);
      expect(z.wpiZustand.wundenInZone(WundZone.brust), 1);
      expect(a.istWiederholung, isFalse);
      final buchung = z.buchungen.single;
      expect(buchung.art, ZustandsBuchungsArt.heilung);
      expect(buchung.lepDelta, 9);
      expect(buchung.auDelta, 4);
      expect(buchung.wundenDelta, -1);
      expect(buchung.zone, WundZone.brust);
      expect(z.diceLog.last.subtitle, contains('Heiltrank'));
      expect(z.diceLog.last.subtitle, contains('+9 LeP'));
    });

    test('dieselbe Vorgangs-ID bucht nie zweimal', () async {
      final repo = FakeRepository(states: {'held': _start});
      Future<VitalAnwendung> buche() => _ablauf(repo).uebernimm(
        heroId: 'held',
        eingabe: const VitalEingabe(lep: 5),
        gegenstand: 'Heiltrank',
        grenzen: _grenzen,
        vorgangId: 'v1',
      );
      await buche();
      final zweite = await buche();

      expect(zweite.istWiederholung, isTrue);
      expect((await repo.loadHeroState('held'))!.currentLep, 17);
    });

    test('ungültige Eingabe schreibt nichts', () async {
      final repo = FakeRepository(states: {'held': _start});
      await expectLater(
        _ablauf(repo).uebernimm(
          heroId: 'held',
          eingabe: const VitalEingabe(),
          gegenstand: 'Heiltrank',
          grenzen: _grenzen,
          vorgangId: 'v1',
        ),
        throwsStateError,
      );
      expect((await repo.loadHeroState('held'))!.buchungen, isEmpty);
    });
  });

  group('Inventareintrag', () {
    test('Vitalwirkung bleibt über JSON und copyWith erhalten', () {
      const eintrag = HeroInventoryEntry(
        gegenstand: 'Heiltrank',
        vitalwirkung: Vitalwirkung(lep: 8, wunden: 1),
      );
      final neu = HeroInventoryEntry.fromJson(eintrag.toJson());
      expect(neu.vitalwirkung!.lep, 8);
      expect(neu.vitalwirkung!.wunden, 1);
      expect(neu.copyWith(gegenstand: 'Trank').vitalwirkung!.lep, 8);
      expect(neu.copyWith(vitalwirkung: null).vitalwirkung, isNull);
    });

    test('ohne Wirkung steht nichts im JSON', () {
      expect(
        const HeroInventoryEntry(gegenstand: 'Seil')
            .toJson()
            .containsKey('vitalwirkung'),
        isFalse,
      );
    });
  });
}
