import 'dart:async';
import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/regelprofil_aufloesung.dart';
import 'package:dsa_heldenverwaltung/data/custom_catalog_repository.dart';
import 'package:dsa_heldenverwaltung/data/firebase_bootstrap.dart';
import 'package:dsa_heldenverwaltung/data/gruppen_sync_service.dart';
import 'package:dsa_heldenverwaltung/data/house_rule_pack_repository.dart';
import 'package:dsa_heldenverwaltung/domain/hero_gruppen_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_regelprofil.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/externe_helden_providers.dart';
import 'package:dsa_heldenverwaltung/state/firebase_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/regelprofil_gruppe_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_overview/hero_regelprofil_section.dart';

import '../../test_support/bogen_test_repository.dart';
import '../../test_support/hero_fixtures.dart';
import '../../test_support/real_catalog.dart';

/// Gruppenvorgabe in der Regelprofil-Karte (ARCH-04): Die Karte bietet die
/// Vorgabe der primären Gruppe an; der Held ändert sich erst mit „Übernehmen“.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const talentPaket = 'regelwerk_ueberarbeitung_v1.talents_learning';

  late EchterKatalog katalog;
  late HeroSheet basisHeld;
  late HeroRegelProfil aktuell;
  late HeroRegelProfil veraltet;

  setUpAll(() async {
    katalog = await ladeEchtenRegelkatalog();
    basisHeld = ladeBestandsheld(Bestandsheld.kriegerNormal).hero;
    aktuell = regelProfilAusGlobalemStand(
      catalogVersion: katalog.runtimeData.baseData.version,
      paketKatalog: katalog.runtimeData.packCatalog,
      aktivePaketIds: katalog.runtimeData.activeHouseRulePackIds,
    );
    veraltet = aktuell.copyWith(
      pakete: [
        for (final p in aktuell.pakete)
          if (p.paketId == talentPaket)
            HeroRegelProfilPaket(
              paketId: p.paketId,
              pruefsumme: stableContentHash(<String, Object?>{
                ...p.manifest,
                'patches': <Object?>[],
              }),
              manifest: <String, Object?>{
                ...p.manifest,
                'patches': <Object?>[],
              },
            )
          else
            p,
      ],
    );
  });

  Future<T> warte<T>(
    ProviderContainer c,
    ProviderListenable<AsyncValue<T>> provider,
  ) {
    final completer = Completer<T>();
    c.listen<AsyncValue<T>>(provider, (_, next) {
      if (completer.isCompleted) return;
      if (next.hasError) {
        completer.completeError(next.error!, next.stackTrace);
      } else if (next.hasValue) {
        completer.complete(next.requireValue);
      }
    }, fireImmediately: true);
    return completer.future.timeout(const Duration(seconds: 60));
  }

  Future<ProviderContainer> aufbau(
    BogenTestRepository repo,
    HeroSheet held, {
    HeroRegelProfil? vorgabe,
  }) async {
    final firestore = FakeFirebaseFirestore();
    if (vorgabe != null) {
      await firestore.doc('groups_v2/g1/shared_info/regelprofil').set({
        'profilJson': jsonEncode(vorgabe.toJson()),
      });
    }
    final c = ProviderContainer(
      overrides: [
        customCatalogRepositoryProvider.overrideWithValue(
          const CustomCatalogRepository(heroStoragePath: ''),
        ),
        houseRulePackRepositoryProvider.overrideWithValue(
          const HouseRulePackRepository(heroStoragePath: ''),
        ),
        catalogDisabledHouseRulePackIdsProvider.overrideWithValue(
          const <String>{},
        ),
        catalogContentPasswordProvider.overrideWithValue(null),
        heroRepositoryProvider.overrideWithValue(repo),
        heroByIdProvider(held.id).overrideWithValue(held),
        firebaseBootstrapProvider.overrideWithValue(
          const FirebaseBootstrapResult.available(),
        ),
        gruppenSyncServiceProvider.overrideWithValue(
          GruppenSyncService(firestore: firestore, uidProvider: () => 'ich'),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> zeige(
    WidgetTester tester,
    ProviderContainer c,
    String id,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HeroRegelprofilSection(heroId: id),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  const primaer = [
    HeroGruppenMitgliedschaft(
      gruppenCode: 'g1',
      gruppenName: 'Die Silberfüchse',
      kontoGruppe: true,
      primaer: true,
    ),
  ];

  testWidgets('abweichende Vorgabe: ansehen und bewusst übernehmen', (
    tester,
  ) async {
    final held = basisHeld.copyWith(
      id: 'g',
      regelProfil: veraltet,
      gruppen: primaer,
    );
    final zustand = ladeBestandsheld(Bestandsheld.kriegerNormal).state;
    final repo = BogenTestRepository(heroes: [held], states: {'g': zustand});
    final c = await aufbau(repo, held, vorgabe: aktuell);
    await tester.runAsync(() async {
      await warte(c, gruppenVorgabeVorschauProvider('g'));
    });
    await zeige(tester, c, 'g');

    expect(
      find.byKey(const ValueKey('regelprofil-gruppe-hinweis')),
      findsOneWidget,
    );
    expect(find.textContaining('Die Silberfüchse'), findsOneWidget);
    // Angezeigt, nicht geschrieben.
    expect(repo.bogenSpeicherungen, 0);

    await tester.tap(find.byKey(const ValueKey('regelprofil-gruppe-ansehen')));
    await tester.pumpAndSettle();
    expect(find.text('Regelprofil der Gruppe'), findsOneWidget);
    expect(repo.bogenSpeicherungen, 0);

    await tester.tap(
      find.byKey(const ValueKey('regelprofil-gruppe-uebernehmen')),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();

    final gespeichert = await tester.runAsync(() => repo.gespeichert('g'));
    expect(gespeichert!.regelProfil, aktuell);
    expect(gespeichert.gruppen.single.primaer, isTrue);
    expect(find.text('Regelprofil der Gruppe'), findsNothing);
  });

  testWidgets('Schließen lässt den Helden unverändert', (tester) async {
    final held = basisHeld.copyWith(
      id: 'g',
      regelProfil: veraltet,
      gruppen: primaer,
    );
    final zustand = ladeBestandsheld(Bestandsheld.kriegerNormal).state;
    final repo = BogenTestRepository(heroes: [held], states: {'g': zustand});
    final c = await aufbau(repo, held, vorgabe: aktuell);
    await tester.runAsync(() async {
      await warte(c, gruppenVorgabeVorschauProvider('g'));
    });
    await zeige(tester, c, 'g');

    await tester.tap(find.byKey(const ValueKey('regelprofil-gruppe-ansehen')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('regelprofil-gruppe-schliessen')),
    );
    await tester.pumpAndSettle();

    expect(repo.bogenSpeicherungen, 0);
    expect(find.text('Regelprofil der Gruppe'), findsNothing);
  });

  testWidgets('ohne primäre Gruppe oder ohne Vorgabe bleibt die Karte ruhig', (
    tester,
  ) async {
    final ohneGruppe = basisHeld.copyWith(id: 'o', regelProfil: veraltet);
    final zustand = ladeBestandsheld(Bestandsheld.kriegerNormal).state;
    final repo = BogenTestRepository(
      heroes: [ohneGruppe],
      states: {'o': zustand},
    );
    final c = await aufbau(repo, ohneGruppe, vorgabe: aktuell);
    await tester.runAsync(() async {
      await warte(c, gruppenVorgabeVorschauProvider('o'));
    });
    await zeige(tester, c, 'o');
    expect(
      find.byKey(const ValueKey('regelprofil-gruppe-hinweis')),
      findsNothing,
    );
  });
}
