import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/firebase_bootstrap.dart';
import 'package:dsa_heldenverwaltung/data/gruppen_sync_service.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/externer_held.dart';
import 'package:dsa_heldenverwaltung/domain/hero_gruppen_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/externe_helden_providers.dart';
import 'package:dsa_heldenverwaltung/state/firebase_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_gruppe/gruppe_mitglieder_liste.dart';

import '../../test_support/fake_repository.dart';

// Mitglieder entfernen (Gruppen v2): Nur der Besitzer einer Konto-Gruppe sieht
// „Aus der Gruppe entfernen“, und zwar nur an Heldenkarten von Mitgliedern,
// nicht an gemeinsamen Einträgen. Die Aktion selbst ist in
// `hero_actions_gruppen_test.dart` abgedeckt; hier zählen Sichtbarkeit und
// der Bestätigungsdialog.

final _freund = ExternerHeld(
  id: 'hero-freund',
  name: 'Rondra',
  quelleHeroId: 'hero-freund',
  updatedAt: DateTime.utc(2026, 1, 1),
);

final _packesel = ExternerHeld(
  id: 'npc',
  name: 'Packesel',
  updatedAt: DateTime.utc(2026, 1, 1),
);

void main() {
  const heroId = 'hero';
  const gruppenCode = 'g';

  Future<FakeFirebaseFirestore> zeige(
    WidgetTester tester, {
    required String uid,
    bool kontoGruppe = true,
    bool syncAvailable = true,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final firestore = FakeFirebaseFirestore();
    await GruppenSyncService(
      firestore: firestore,
      uidProvider: () => 'besitzer',
      idGenerator: () => gruppenCode,
      joinCodeGenerator: () => 'CODE12345678',
    ).erstelleGruppe('Runde');
    await firestore.doc('groups_v2/g/members/freund').set({'role': 'member'});
    await firestore.doc('groups_v2/g/members/ich').set({'role': 'member'});
    final repo = FakeRepository(
      heroes: [
        HeroSheet(
          id: heroId,
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
          gruppen: [
            HeroGruppenMitgliedschaft(
              gruppenCode: gruppenCode,
              kontoGruppe: kontoGruppe,
            ),
          ],
        ),
      ],
    );
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
          gruppenMitgliederProvider((heroId: heroId, gruppenCode: gruppenCode))
              .overrideWithValue([_freund, _packesel]),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GruppeMitgliederListe(
                heroId: heroId,
                gruppenCode: gruppenCode,
                kontoGruppe: kontoGruppe,
                syncAvailable: syncAvailable,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return firestore;
  }

  final menueFreund = find.byKey(
    const ValueKey<String>('gruppe-mitglied-menue-hero-freund'),
  );
  final menueEsel = find.byKey(
    const ValueKey<String>('gruppe-mitglied-menue-npc'),
  );

  testWidgets('Besitzer sieht „Aus der Gruppe entfernen“ nur am Mitglied', (
    tester,
  ) async {
    await zeige(tester, uid: 'besitzer');

    expect(menueFreund, findsOneWidget);
    await tester.tap(menueFreund);
    await tester.pumpAndSettle();
    expect(find.text('Aus der Gruppe entfernen'), findsOneWidget);
    // Das Mitglied hat keinen lokalen „Entfernen“-Eintrag.
    expect(find.text('Entfernen'), findsNothing);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    // Der gemeinsame Eintrag kennt nur das Löschen für alle.
    await tester.tap(menueEsel);
    await tester.pumpAndSettle();
    expect(find.text('Entfernen'), findsOneWidget);
    expect(find.text('Aus der Gruppe entfernen'), findsNothing);
  });

  testWidgets('Mitglied ohne Besitzerrecht sieht die Aktion nicht', (
    tester,
  ) async {
    await zeige(tester, uid: 'ich');
    expect(menueFreund, findsNothing);
    expect(menueEsel, findsOneWidget);
  });

  testWidgets('Ohne Sync gibt es die Aktion nicht, auch nicht für Besitzer', (
    tester,
  ) async {
    await zeige(tester, uid: 'besitzer', syncAvailable: false);
    expect(menueFreund, findsNothing);
  });

  testWidgets('Abbrechen im Dialog lässt Gruppe und Code unverändert', (
    tester,
  ) async {
    final firestore = await zeige(tester, uid: 'besitzer');

    await tester.tap(menueFreund);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aus der Gruppe entfernen'));
    await tester.pumpAndSettle();
    expect(find.text('Rondra aus der Gruppe entfernen?'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('gruppe-mitglied-entfernen-abbrechen')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rondra aus der Gruppe entfernen?'), findsNothing);
    expect(
      (await firestore.doc('groups_v2/g/members/freund').get()).exists,
      isTrue,
    );
    expect(
      (await firestore.doc('groups_v2/g').get()).data()?['joinCode'],
      'CODE12345678',
    );
  });
}
