import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:dsa_heldenverwaltung/data/firebase_bootstrap.dart';
import 'package:dsa_heldenverwaltung/data/gruppen_sync_service.dart';
import 'package:dsa_heldenverwaltung/data/hive_externe_helden_repository.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/externer_held.dart';
import 'package:dsa_heldenverwaltung/domain/gruppen_beitrittscode.dart';
import 'package:dsa_heldenverwaltung/domain/held_visitenkarte.dart';
import 'package:dsa_heldenverwaltung/domain/hero_gruppen_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/externe_helden_providers.dart';
import 'package:dsa_heldenverwaltung/state/firebase_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

const _attribute = Attributes(
  mu: 12,
  kl: 12,
  inn: 12,
  ch: 12,
  ff: 12,
  ge: 12,
  ko: 12,
  kk: 12,
);

HeroSheet _held({List<HeroGruppenMitgliedschaft> gruppen = const []}) {
  return HeroSheet(
    id: 'hero',
    name: 'Alrik',
    level: 1,
    attributes: _attribute,
    gruppen: gruppen,
  );
}

HeldVisitenkarte _karte(
  String heroId,
  String name, {
  bool manuell = false,
  DateTime? stand,
}) {
  return HeldVisitenkarte(
    heroId: heroId,
    name: name,
    exportedAt: stand ?? DateTime.utc(2026, 1, 1),
    istManuell: manuell,
  );
}

void main() {
  late Directory verzeichnis;
  late HiveExterneHeldenRepository externe;
  late FakeFirebaseFirestore firestore;
  late FakeRepository heldenSpeicher;
  late GruppenSyncService dienst;
  late ProviderContainer container;

  Future<void> aufbau(List<HeroGruppenMitgliedschaft> gruppen) async {
    heldenSpeicher = FakeRepository(heroes: [_held(gruppen: gruppen)]);
    container = ProviderContainer(
      overrides: [
        firebaseBootstrapProvider.overrideWithValue(
          const FirebaseBootstrapResult.available(),
        ),
        heroRepositoryProvider.overrideWithValue(heldenSpeicher),
        externeHeldenRepositoryProvider.overrideWithValue(externe),
        gruppenSyncServiceProvider.overrideWithValue(dienst),
      ],
    );
    addTearDown(container.dispose);
  }

  Future<HeroGruppenMitgliedschaft> gruppeVon(String code) async {
    final held = await heldenSpeicher.loadHeroById('hero');
    return held!.gruppen.firstWhere((g) => g.gruppenCode == code);
  }

  setUp(() async {
    verzeichnis = await Directory.systemTemp.createTemp('dsa_gruppen_');
    externe = await HiveExterneHeldenRepository.create(
      storagePath: verzeichnis.path,
    );
    firestore = FakeFirebaseFirestore();
    dienst = GruppenSyncService(
      firestore: firestore,
      uidProvider: () => 'ich',
      idGenerator: () => 'gruppe-1',
      joinCodeGenerator: () => 'CODE12345678',
    );
  });

  tearDown(() async {
    await externe.close();
    await Hive.close();
    if (await verzeichnis.exists()) {
      await verzeichnis.delete(recursive: true);
    }
  });

  test('erstellt eine Konto-Gruppe und merkt sie am Helden', () async {
    await aufbau(const []);

    final id = await container
        .read(heroActionsProvider)
        .erstelleGruppe(heroId: 'hero', gruppenName: 'Die Thorwaler');

    expect(id, 'gruppe-1');
    final gruppe = await gruppeVon('gruppe-1');
    expect(gruppe.kontoGruppe, isTrue);
    expect(gruppe.gruppenName, 'Die Thorwaler');
    expect(
      await container.read(heroActionsProvider).ladeBeitrittscode('gruppe-1'),
      'gruppe-1.CODE12345678',
    );
  });

  test(
    'Beitritt nimmt den Beitrittscode und lehnt Unvollständiges ab',
    () async {
      await GruppenSyncService(
        firestore: firestore,
        uidProvider: () => 'besitzer',
        idGenerator: () => 'g',
        joinCodeGenerator: () => 'GEHEIM123456',
      ).erstelleGruppe('Runde');
      await aufbau(const []);
      final actions = container.read(heroActionsProvider);

      await expectLater(
        actions.trittGruppeBei(heroId: 'hero', beitrittscode: 'nur-eine-id'),
        throwsA(isA<GruppenException>()),
      );
      final id = await actions.trittGruppeBei(
        heroId: 'hero',
        beitrittscode: const GruppenBeitrittscode(
          groupId: 'g',
          joinCode: 'GEHEIM123456',
        ).text,
      );

      expect(id, 'g');
      expect((await gruppeVon('g')).kontoGruppe, isTrue);
      expect((await gruppeVon('g')).gruppenName, 'Runde');
    },
  );

  test(
    'Sync holt Mitglieder und gemeinsame Einträge und räumt Verschwundenes ab',
    () async {
      await GruppenSyncService(
        firestore: firestore,
        uidProvider: () => 'ich',
        idGenerator: () => 'g',
        joinCodeGenerator: () => 'GEHEIM123456',
      ).erstelleGruppe('Neuer Name');
      final freund = GruppenSyncService(
        firestore: firestore,
        uidProvider: () => 'freund',
      );
      await freund.tritteBei(
        const GruppenBeitrittscode(groupId: 'g', joinCode: 'GEHEIM123456'),
      );
      await freund.pushVisitenkarte('g', _karte('hero-freund', 'Rondra'));
      await freund.pushGeteilterHeld(
        'g',
        _karte('npc', 'Packesel', manuell: true),
      );
      // Reste einer früheren Synchronisierung, die es online nicht mehr gibt.
      await externe.save(
        ExternerHeld.fromVisitenkarte(_karte('hero-weg', 'Ausgetreten')),
      );
      await aufbau(const [
        HeroGruppenMitgliedschaft(
          gruppenCode: 'g',
          gruppenName: 'Alter Name',
          kontoGruppe: true,
          externeHeldIds: ['hero-weg'],
        ),
      ]);

      await container.read(heroActionsProvider).syncGruppen('hero');

      final gruppe = await gruppeVon('g');
      expect(gruppe.gruppenName, 'Neuer Name');
      expect(gruppe.externeHeldIds, unorderedEquals(['hero-freund', 'npc']));
      expect(externe.loadById('hero-freund')?.name, 'Rondra');
      expect(externe.loadById('hero-freund')?.istVerknuepft, isTrue);
      expect(externe.loadById('npc')?.istManuell, isTrue);
    },
  );

  test('Sync lässt Altgruppen unberührt', () async {
    await aufbau(const [
      HeroGruppenMitgliedschaft(gruppenCode: 'alt', externeHeldIds: ['x']),
    ]);

    await container.read(heroActionsProvider).syncGruppen('hero');

    expect((await gruppeVon('alt')).externeHeldIds, ['x']);
    expect((await firestore.collection('groups_v2').get()).docs, isEmpty);
  });

  test(
    'neuerer lokaler Stand eines gemeinsamen Eintrags geht in die Gruppe',
    () async {
      await GruppenSyncService(
        firestore: firestore,
        uidProvider: () => 'ich',
        idGenerator: () => 'g',
        joinCodeGenerator: () => 'GEHEIM123456',
      ).erstelleGruppe('Runde');
      await dienst.pushGeteilterHeld(
        'g',
        _karte('npc', 'Alt', manuell: true, stand: DateTime.utc(2026, 1, 1)),
      );
      await externe.save(
        ExternerHeld(
          id: 'npc',
          name: 'Neu',
          updatedAt: DateTime.utc(2026, 2, 1),
        ),
      );
      await aufbau(const [
        HeroGruppenMitgliedschaft(
          gruppenCode: 'g',
          kontoGruppe: true,
          externeHeldIds: ['npc'],
        ),
      ]);

      await container.read(heroActionsProvider).syncGruppen('hero');

      final remote = await firestore.doc('groups_v2/g/shared_heroes/npc').get();
      expect(remote.data(), containsPair('name', 'Neu'));
      expect((await gruppeVon('g')).externeHeldIds, ['npc']);
    },
  );

  test(
    'gemeinsamer Eintrag wird erst nach dem Upload lokal gespeichert',
    () async {
      await GruppenSyncService(
        firestore: firestore,
        uidProvider: () => 'ich',
        idGenerator: () => 'g',
        joinCodeGenerator: () => 'GEHEIM123456',
      ).erstelleGruppe('Runde');
      await aufbau(const [
        HeroGruppenMitgliedschaft(gruppenCode: 'g', kontoGruppe: true),
      ]);
      final actions = container.read(heroActionsProvider);
      final npc = ExternerHeld(
        id: 'npc-1',
        name: 'Begleiter',
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      await actions.addManuellerHeld(
        heroId: 'hero',
        gruppenCode: 'g',
        held: npc,
      );

      expect(externe.loadById('npc-1')?.name, 'Begleiter');
      expect((await gruppeVon('g')).externeHeldIds, ['npc-1']);
      expect(
        (await firestore.doc('groups_v2/g/shared_heroes/npc-1').get()).exists,
        isTrue,
      );

      await actions.removeExternerHeld(
        heroId: 'hero',
        gruppenCode: 'g',
        externerHeldId: 'npc-1',
      );

      expect((await gruppeVon('g')).externeHeldIds, isEmpty);
      expect(
        (await firestore.doc('groups_v2/g/shared_heroes/npc-1').get()).exists,
        isFalse,
      );
    },
  );

  test('Abgleich vor dem Gefecht holt die Gruppe und meldet nichts', () async {
    await GruppenSyncService(
      firestore: firestore,
      uidProvider: () => 'freund',
      idGenerator: () => 'g',
      joinCodeGenerator: () => 'GEHEIM123456',
    ).erstelleGruppe('Runde');
    await firestore.doc('groups_v2/g/members/ich').set({'role': 'member'});
    await firestore
        .doc('groups_v2/g/hero_snapshots/freund')
        .set(_karte('hero-freund', 'Rondra').toJson());
    await aufbau(const [
      HeroGruppenMitgliedschaft(gruppenCode: 'g', kontoGruppe: true),
    ]);

    final warnung = await container
        .read(heroActionsProvider)
        .syncGruppenVorGefecht('hero');

    expect(warnung, isNull);
    expect(externe.loadById('hero-freund')?.name, 'Rondra');
  });

  test(
    'Abgleich vor dem Gefecht überspringt Helden ohne Konto-Gruppe',
    () async {
      await aufbau(const [HeroGruppenMitgliedschaft(gruppenCode: 'alt')]);

      expect(
        await container.read(heroActionsProvider).syncGruppenVorGefecht('hero'),
        isNull,
      );
      expect((await firestore.collection('groups_v2').get()).docs, isEmpty);
    },
  );

  test('Abgleich vor dem Gefecht wirft nie, sondern warnt', () async {
    // Die Gruppe gibt es online nicht (mehr).
    await aufbau(const [
      HeroGruppenMitgliedschaft(
        gruppenCode: 'weg',
        gruppenName: 'Verschwunden',
        kontoGruppe: true,
      ),
    ]);

    final warnung = await container
        .read(heroActionsProvider)
        .syncGruppenVorGefecht('hero');

    expect(warnung, contains('Verschwunden'));
  });

  test('Altgruppen nehmen keine neuen gemeinsamen Einträge an', () async {
    await aufbau(const [HeroGruppenMitgliedschaft(gruppenCode: 'alt')]);

    await expectLater(
      container
          .read(heroActionsProvider)
          .addManuellerHeld(
            heroId: 'hero',
            gruppenCode: 'alt',
            held: ExternerHeld(
              id: 'npc',
              name: 'X',
              updatedAt: DateTime.utc(2026, 1, 1),
            ),
          ),
      throwsA(isA<GruppenException>()),
    );
    expect(externe.loadById('npc'), isNull);
  });

  test('Verlassen einer Altgruppe entfernt sie nur lokal', () async {
    await aufbau(const [HeroGruppenMitgliedschaft(gruppenCode: 'alt')]);

    await container
        .read(heroActionsProvider)
        .verlasseGruppe(heroId: 'hero', gruppenCode: 'alt');

    expect((await heldenSpeicher.loadHeroById('hero'))!.gruppen, isEmpty);
  });

  test(
    'Verlassen und Löschen einer Konto-Gruppe gehen über Firestore',
    () async {
      await GruppenSyncService(
        firestore: firestore,
        uidProvider: () => 'besitzer',
        idGenerator: () => 'g',
        joinCodeGenerator: () => 'GEHEIM123456',
      ).erstelleGruppe('Runde');
      await aufbau(const []);
      final actions = container.read(heroActionsProvider);
      await actions.trittGruppeBei(
        heroId: 'hero',
        beitrittscode: 'g.GEHEIM123456',
      );
      expect(
        (await firestore.doc('groups_v2/g/members/ich').get()).exists,
        isTrue,
      );

      await actions.verlasseGruppe(heroId: 'hero', gruppenCode: 'g');

      expect(
        (await firestore.doc('groups_v2/g/members/ich').get()).exists,
        isFalse,
      );
      expect((await heldenSpeicher.loadHeroById('hero'))!.gruppen, isEmpty);
    },
  );
}
