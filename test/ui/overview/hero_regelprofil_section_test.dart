import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/regelprofil_aufloesung.dart';
import 'package:dsa_heldenverwaltung/data/custom_catalog_repository.dart';
import 'package:dsa_heldenverwaltung/data/house_rule_pack_repository.dart';
import 'package:dsa_heldenverwaltung/domain/hero_regelprofil.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/regelprofil_providers.dart';
import 'package:dsa_heldenverwaltung/state/regelprofil_vorschau_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_overview/hero_regelprofil_section.dart';

import '../../test_support/bogen_test_repository.dart';
import '../../test_support/hero_fixtures.dart';
import '../../test_support/real_catalog.dart';

/// Regelprofil-Karte der Übersicht (ARCH-04, Teilstand 14).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const talentPaket = 'regelwerk_ueberarbeitung_v1.talents_learning';

  late EchterKatalog katalog;
  late HeroSheet basisHeld;
  late HeroRegelProfil global;
  late HeroRegelProfil veraltet;

  setUpAll(() async {
    katalog = await ladeEchtenRegelkatalog();
    basisHeld = ladeBestandsheld(Bestandsheld.kriegerNormal).hero;
    global = regelProfilAusGlobalemStand(
      catalogVersion: katalog.runtimeData.baseData.version,
      paketKatalog: katalog.runtimeData.packCatalog,
      aktivePaketIds: katalog.runtimeData.activeHouseRulePackIds,
    );
    // Ein Paket ohne seine Patches: das heutige Paket wäre ein Update.
    veraltet = global.copyWith(
      pakete: [
        for (final p in global.pakete)
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

  ProviderContainer container(BogenTestRepository repo, HeroSheet held) {
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

  testWidgets('Held ohne Profil: festhalten schreibt den globalen Stand', (
    tester,
  ) async {
    final held = basisHeld.copyWith(id: 'ohne');
    final zustand = ladeBestandsheld(Bestandsheld.kriegerNormal).state;
    final repo = BogenTestRepository(heroes: [held], states: {'ohne': zustand});
    final c = container(repo, held);
    await tester.runAsync(() async {
      final profil = await warte(c, globalesRegelProfilProvider);
      await warte(c, regelProfilAufloesungProvider(profil));
    });
    await zeige(tester, c, 'ohne');
    await tester.pump();

    expect(find.text('Regelprofil'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('regelprofil-festhalten')));
    await tester.pumpAndSettle();
    expect(find.text('Regelstand festhalten?'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('regelprofil-festhalten-bestaetigen')),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();

    final gespeichert = await tester.runAsync(() => repo.gespeichert('ohne'));
    expect(gespeichert!.regelProfil, isNotNull);
    expect(gespeichert.regelProfil!.paketIds.toSet(), global.paketIds.toSet());
  });

  testWidgets('Abbrechen lässt den Helden unverändert', (tester) async {
    final held = basisHeld.copyWith(id: 'ohne');
    final zustand = ladeBestandsheld(Bestandsheld.kriegerNormal).state;
    final repo = BogenTestRepository(heroes: [held], states: {'ohne': zustand});
    final c = container(repo, held);
    await tester.runAsync(() async {
      final profil = await warte(c, globalesRegelProfilProvider);
      await warte(c, regelProfilAufloesungProvider(profil));
    });
    await zeige(tester, c, 'ohne');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('regelprofil-festhalten')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('regelprofil-abbrechen')));
    await tester.pumpAndSettle();
    expect(repo.bogenSpeicherungen, 0);
  });

  testWidgets('Profil mit Update: Vorschau zeigen und bewusst übernehmen', (
    tester,
  ) async {
    final held = basisHeld.copyWith(id: 'alt', regelProfil: veraltet);
    final zustand = ladeBestandsheld(Bestandsheld.kriegerNormal).state;
    final repo = BogenTestRepository(heroes: [held], states: {'alt': zustand});
    final c = container(repo, held);
    await tester.runAsync(() async {
      await warte(c, regelProfilVorschauProvider('alt'));
    });
    await zeige(tester, c, 'alt');
    expect(find.byKey(const ValueKey('regelprofil-update')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('regelprofil-vorschau')));
    await tester.pumpAndSettle();
    expect(find.text('Regelprofil aktualisieren'), findsOneWidget);
    // Ohne Übernahme bleibt der Held unverändert.
    expect(repo.bogenSpeicherungen, 0);

    await tester.tap(find.byKey(const ValueKey('regelprofil-uebernehmen')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();

    final gespeichert = await tester.runAsync(() => repo.gespeichert('alt'));
    expect(gespeichert!.regelProfil, isNot(veraltet));
    expect(gespeichert.regelProfil!.paketIds.toSet(), global.paketIds.toSet());
    expect(find.text('Regelprofil aktualisieren'), findsNothing);
  });

  testWidgets('Profil lösen: Abbrechen schreibt nichts, Lösen entfernt es', (
    tester,
  ) async {
    final held = basisHeld.copyWith(id: 'alt', regelProfil: global);
    final zustand = ladeBestandsheld(Bestandsheld.kriegerNormal).state;
    final repo = BogenTestRepository(heroes: [held], states: {'alt': zustand});
    final c = container(repo, held);
    await tester.runAsync(() async {
      await warte(c, regelProfilVorschauProvider('alt'));
    });
    await zeige(tester, c, 'alt');

    await tester.tap(find.byKey(const ValueKey('regelprofil-loesen')));
    await tester.pumpAndSettle();
    expect(find.text('Festgehaltenen Regelstand lösen?'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('regelprofil-loesen-abbrechen')),
    );
    await tester.pumpAndSettle();
    expect(repo.bogenSpeicherungen, 0);

    await tester.tap(find.byKey(const ValueKey('regelprofil-loesen')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('regelprofil-loesen-bestaetigen')),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();

    final gespeichert = await tester.runAsync(() => repo.gespeichert('alt'));
    expect(gespeichert!.regelProfil, isNull);
    expect(repo.bogenSpeicherungen, 1);
  });

  testWidgets('Speicherfehler erscheint im Dialog und lässt ihn offen', (
    tester,
  ) async {
    final held = basisHeld.copyWith(id: 'alt', regelProfil: veraltet);
    final zustand = ladeBestandsheld(Bestandsheld.kriegerNormal).state;
    final repo = BogenTestRepository(heroes: [held], states: {'alt': zustand})
      ..schreibFehler = true;
    final c = container(repo, held);
    await tester.runAsync(() async {
      await warte(c, regelProfilVorschauProvider('alt'));
    });
    await zeige(tester, c, 'alt');
    await tester.tap(find.byKey(const ValueKey('regelprofil-vorschau')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('regelprofil-uebernehmen')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Regelprofil nicht gespeichert'),
      findsOneWidget,
    );
    expect(find.text('Regelprofil aktualisieren'), findsOneWidget);
  });

  testWidgets('Nicht verstandenes Profil wird nicht verändert', (tester) async {
    final unbekannt = global.copyWith(formatVersion: 99);
    final held = basisHeld.copyWith(id: 'neu', regelProfil: unbekannt);
    final zustand = ladeBestandsheld(Bestandsheld.kriegerNormal).state;
    final repo = BogenTestRepository(heroes: [held], states: {'neu': zustand});
    final c = container(repo, held);
    await zeige(tester, c, 'neu');
    expect(
      find.byKey(const ValueKey('regelprofil-unverstanden')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('regelprofil-festhalten')), findsNothing);
  });
}
