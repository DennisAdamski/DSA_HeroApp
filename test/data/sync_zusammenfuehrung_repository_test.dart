import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/hive_sync_basis_store.dart';
import 'package:dsa_heldenverwaltung/data/sync/sync_basis_store.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/domain/sync_zusammenfuehrung.dart';

import '../test_support/hero_fixtures.dart';
import '../test_support/sync_geraete.dart';

// Zusammenführung im Konto-Sync (ARCH-06): echte Konflikte sind nur Werte,
// die beide Geräte seit dem letzten Abgleich verschieden geändert haben.

const String _krieger = 'bestand-f01';
const _heldKey = SyncObjectKey(type: SyncObjectType.hero, id: _krieger);

Future<void> _aendere(
  SyncTestGeraet geraet,
  HeroSheet Function(HeroSheet held) aenderung,
) async {
  final held = (await geraet.lokal.loadHeroById(_krieger))!;
  await geraet.repo.saveHero(aenderung(held));
}

Future<void> _aendereZustand(
  SyncTestGeraet geraet,
  HeroState Function(HeroState zustand) aenderung,
) async {
  final zustand = (await geraet.lokal.loadHeroState(_krieger))!;
  await geraet.repo.saveHeroState(_krieger, aenderung(zustand));
  await geraet.repo.warteAufUebertragungen();
}

void main() {
  late GeteilteCloud cloud;
  late SyncTestGeraet a;
  late SyncTestGeraet b;

  setUp(() async {
    cloud = GeteilteCloud();
    a = SyncTestGeraet(cloud);
    b = SyncTestGeraet(cloud);
    final bundle = ladeBestandsheld(Bestandsheld.kriegerNormal);
    await a.repo.saveHero(bundle.hero);
    await a.repo.saveHeroState(_krieger, bundle.state);
    await a.repo.warteAufUebertragungen();
    await a.repo.syncNow();
    await b.repo.syncNow();
  });

  // Beide Geräte ändern offline; A ist zuerst wieder online.
  Future<void> offlineAufBeiden({
    required Future<void> Function() beiA,
    required Future<void> Function() beiB,
  }) async {
    a.remote.offline = true;
    b.remote.offline = true;
    await beiA();
    await beiB();
    a.remote.offline = false;
    b.remote.offline = false;
    await a.repo.syncNow();
    await b.repo.syncNow();
  }

  test('verschiedene Felder ergeben keinen Konflikt, beide Geräte enden '
      'gleich', () async {
    await offlineAufBeiden(
      beiA: () => _aendere(a, (held) => held.copyWith(dukaten: '20')),
      beiB: () => _aendere(b, (held) => held.copyWith(name: 'Alrik der Große')),
    );
    await a.repo.syncNow();

    expect(a.konflikte, isEmpty);
    expect(b.konflikte, isEmpty);
    expect(await a.heldHash(_krieger), await b.heldHash(_krieger));
    final held = (await a.lokal.loadHeroById(_krieger))!;
    expect((held.dukaten, held.name), ('20', 'Alrik der Große'));

    final vorher = cloud.schreibvorgaenge;
    await a.repo.syncNow();
    await b.repo.syncNow();
    expect(cloud.schreibvorgaenge, vorher, reason: 'danach Ruhe');
  });

  test(
    'ohne gemeinsamen Ausgangsstand bleibt es beim bisherigen Konflikt',
    () async {
      await b.basis.vergiss(_heldKey);
      // Der Abgleich ergänzt die Basis nur, solange B nichts geändert hat.
      await offlineAufBeiden(
        beiA: () => _aendere(a, (held) => held.copyWith(dukaten: '20')),
        beiB: () =>
            _aendere(b, (held) => held.copyWith(name: 'Alrik der Große')),
      );

      final konflikt = b.konflikte.single;
      expect(await b.repo.konfliktVorschau(konflikt.id), isNull);
      await expectLater(
        b.repo.resolveConflictAutomatisch(konflikt.id, const {}),
        throwsA(isA<StateError>()),
      );
      expect(b.konflikte, hasLength(1));
    },
  );

  test(
    'ein Abgleich ohne lokale Änderung trägt die fehlende Basis nach',
    () async {
      await b.basis.vergiss(_heldKey);
      await b.repo.syncNow();
      expect(await b.basis.lade(_heldKey), isNotNull);

      await offlineAufBeiden(
        beiA: () => _aendere(a, (held) => held.copyWith(dukaten: '20')),
        beiB: () =>
            _aendere(b, (held) => held.copyWith(name: 'Alrik der Große')),
      );
      expect(b.konflikte, isEmpty);
    },
  );

  test('Automatisch entscheidet nur den Widerspruch, der Zustand läuft '
      'zusammengeführt mit', () async {
    final startLep = (await a.lokal.loadHeroState(_krieger))!.currentLep;
    await offlineAufBeiden(
      beiA: () async {
        await _aendere(a, (held) => held.copyWith(dukaten: '20'));
        await _aendereZustand(
          a,
          (zustand) => zustand.copyWith(currentLep: zustand.currentLep - 5),
        );
      },
      beiB: () async {
        await _aendere(
          b,
          (held) => held.copyWith(dukaten: '30', name: 'Alrik der Große'),
        );
        await _aendereZustand(
          b,
          (zustand) => zustand.copyWith(currentLep: zustand.currentLep - 7),
        );
      },
    );

    final konflikt = b.konflikte.single;
    expect(konflikt.includesHeroState, isTrue);
    final vorschau = (await b.repo.konfliktVorschau(konflikt.id))!;
    expect(vorschau.felder.map((f) => f.schluessel), ['held:dukaten']);
    expect(vorschau.felder.single.lokal, '30');
    expect(vorschau.felder.single.online, '20');

    await b.repo.resolveConflictAutomatisch(konflikt.id, {
      'held:dukaten': SyncSeite.online,
    });
    await a.repo.syncNow();
    await b.repo.syncNow();

    expect(a.konflikte, isEmpty);
    expect(b.konflikte, isEmpty);
    for (final geraet in <SyncTestGeraet>[a, b]) {
      final held = (await geraet.lokal.loadHeroById(_krieger))!;
      expect((held.dukaten, held.name), ('20', 'Alrik der Große'));
      final zustand = (await geraet.lokal.loadHeroState(_krieger))!;
      expect(zustand.currentLep, startLep - 12);
    }
  });

  test('ändert sich der Online-Stand während der Entscheidung, wird der '
      'Konflikt frisch gestellt', () async {
    await offlineAufBeiden(
      beiA: () => _aendere(a, (held) => held.copyWith(dukaten: '20')),
      beiB: () => _aendere(b, (held) => held.copyWith(dukaten: '30')),
    );
    final konflikt = b.konflikte.single;
    await _aendere(a, (held) => held.copyWith(dukaten: '25'));

    await b.repo.resolveConflictAutomatisch(konflikt.id, {
      'held:dukaten': SyncSeite.lokal,
    });

    final neu = b.konflikte.single;
    final vorschau = (await b.repo.konfliktVorschau(neu.id))!;
    expect(vorschau.felder.single.online, '25');
    await b.repo.resolveConflictAutomatisch(neu.id, {
      'held:dukaten': SyncSeite.lokal,
    });
    await a.repo.syncNow();
    expect((await a.lokal.loadHeroById(_krieger))!.dukaten, '30');
  });

  test('die Basis übersteht das Schließen der Hive-Box', () async {
    final pfad = await hiveTempVerzeichnis('arch06_basis_');
    final erste = await HiveSyncBasisStore.create(storagePath: pfad);
    await erste.merke(
      _heldKey,
      const SyncBasis(
        revision: 'r-1',
        inhalt: {
          'name': 'Alrik',
          'talents': {
            'klettern': {'taw': 3},
          },
        },
      ),
    );
    await erste.close();

    final zweite = await HiveSyncBasisStore.create(storagePath: pfad);
    addTearDown(zweite.close);
    final basis = (await zweite.lade(_heldKey))!;
    expect(basis.revision, 'r-1');
    expect(basis.inhalt['talents'], {
      'klettern': {'taw': 3},
    });
    await zweite.vergiss(_heldKey);
    expect(await zweite.lade(_heldKey), isNull);
  });
}
