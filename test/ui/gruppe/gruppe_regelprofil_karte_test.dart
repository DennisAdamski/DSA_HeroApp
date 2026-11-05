import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/firebase_bootstrap.dart';
import 'package:dsa_heldenverwaltung/data/gruppen_sync_service.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_gruppen_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_regelprofil.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/externe_helden_providers.dart';
import 'package:dsa_heldenverwaltung/state/firebase_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_gruppe/gruppe_regelprofil_karte.dart';

/// Regelprofil-Karte einer Konto-Gruppe (ARCH-04).
void main() {
  final profil = HeroRegelProfil(
    catalogVersion: 'house_rules_v1',
    pakete: [
      HeroRegelProfilPaket(
        paketId: 'epic_rules_v1',
        pruefsumme: 'abc',
        manifest: const <String, Object?>{
          'id': 'epic_rules_v1',
          'title': 'Epische Regeln',
        },
      ),
    ],
  );

  HeroSheet held(List<HeroGruppenMitgliedschaft> gruppen) => HeroSheet(
    id: 'hero',
    name: 'Alrik',
    level: 1,
    attributes: const Attributes(
      mu: 12,
      kl: 12,
      inn: 12,
      ch: 12,
      ff: 12,
      ge: 12,
      ko: 12,
      kk: 12,
    ),
    gruppen: gruppen,
    regelProfil: profil,
  );

  Future<FakeRepository> zeige(
    WidgetTester tester,
    FakeFirebaseFirestore firestore, {
    required List<HeroGruppenMitgliedschaft> gruppen,
    String uid = 'ich',
  }) async {
    final repo = FakeRepository(heroes: [held(gruppen)]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          firebaseBootstrapProvider.overrideWithValue(
            const FirebaseBootstrapResult.available(),
          ),
          gruppenSyncServiceProvider.overrideWithValue(
            GruppenSyncService(firestore: firestore, uidProvider: () => uid),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GruppeRegelprofilKarte(heroId: 'hero', gruppenCode: 'g1'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  Future<FakeFirebaseFirestore> gruppe() async {
    final firestore = FakeFirebaseFirestore();
    await GruppenSyncService(
      firestore: firestore,
      uidProvider: () => 'besitzer',
      idGenerator: () => 'g1',
      joinCodeGenerator: () => 'CODE00000001',
    ).erstelleGruppe('Die Silberfüchse');
    await firestore.doc('groups_v2/g1/members/ich').set({'role': 'member'});
    return firestore;
  }

  testWidgets('Mitglied: Gruppe zur primären machen, keine Besitzeraktionen', (
    tester,
  ) async {
    final firestore = await gruppe();
    final repo = await zeige(
      tester,
      firestore,
      gruppen: const [
        HeroGruppenMitgliedschaft(gruppenCode: 'g1', kontoGruppe: true),
      ],
    );

    expect(
      find.byKey(const ValueKey('gruppe-regelprofil-leer')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('gruppe-regelprofil-setzen')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('gruppe-regelprofil-primaer-setzen')),
    );
    await tester.pumpAndSettle();

    final gespeichert = await repo.loadHeroById('hero');
    expect(gespeichert!.gruppen.single.primaer, isTrue);
    // Das Profil des Helden bleibt, wie es war.
    expect(gespeichert.regelProfil, profil);
  });

  testWidgets('Besitzer setzt und entfernt die Vorgabe', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await GruppenSyncService(
      firestore: firestore,
      uidProvider: () => 'ich',
      idGenerator: () => 'g1',
      joinCodeGenerator: () => 'CODE00000001',
    ).erstelleGruppe('Die Silberfüchse');
    await zeige(
      tester,
      firestore,
      gruppen: const [
        HeroGruppenMitgliedschaft(
          gruppenCode: 'g1',
          kontoGruppe: true,
          primaer: true,
        ),
      ],
    );

    expect(
      find.byKey(const ValueKey('gruppe-regelprofil-primaer')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('gruppe-regelprofil-setzen')));
    await tester.pumpAndSettle();
    expect(find.text('• Epische Regeln'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('gruppe-regelprofil-setzen-ok')),
    );
    await tester.pumpAndSettle();

    expect(
      (await firestore.doc('groups_v2/g1/shared_info/regelprofil').get())
          .exists,
      isTrue,
    );
    expect(
      find.byKey(const ValueKey('gruppe-regelprofil-pakete')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('gruppe-regelprofil-entfernen')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('gruppe-regelprofil-entfernen-ok')),
    );
    await tester.pumpAndSettle();

    expect(
      (await firestore.doc('groups_v2/g1/shared_info/regelprofil').get())
          .exists,
      isFalse,
    );
    expect(
      find.byKey(const ValueKey('gruppe-regelprofil-leer')),
      findsOneWidget,
    );
  });
}
