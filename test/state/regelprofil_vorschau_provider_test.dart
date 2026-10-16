import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/regelprofil_aufloesung.dart';
import 'package:dsa_heldenverwaltung/catalog/regelprofil_vergleich.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/data/custom_catalog_repository.dart';
import 'package:dsa_heldenverwaltung/data/house_rule_pack_repository.dart';
import 'package:dsa_heldenverwaltung/domain/hero_regelprofil.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/rules/derived/regelprofil_vorschau_rules.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/ablauf_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/regelprofil_vorschau_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

import '../test_support/hero_fixtures.dart';
import '../test_support/real_catalog.dart';

/// Updatevorschau und Parallelbetrieb von Regelprofilen (ARCH-04).
///
/// Abnahme: Zwei Helden mit verschiedenen Profilen laufen parallel, ohne
/// einander zu beeinflussen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const talentPaket = 'regelwerk_ueberarbeitung_v1.talents_learning';
  const epicVorteile = 'epic_rules_v1.advantages';

  late EchterKatalog katalog;
  late HeroSheet basisHeld;
  late HeroRegelProfil veraltetesProfil;
  late HeroRegelProfil ohneEpicVorteile;

  setUpAll(() async {
    katalog = await ladeEchtenRegelkatalog();
    basisHeld = ladeBestandsheld(Bestandsheld.kriegerNormal).hero;
    final global = regelProfilAusGlobalemStand(
      catalogVersion: katalog.runtimeData.baseData.version,
      paketKatalog: katalog.runtimeData.packCatalog,
      aktivePaketIds: katalog.runtimeData.activeHouseRulePackIds,
    );
    veraltetesProfil = global.copyWith(
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
    ohneEpicVorteile = global.copyWith(
      pakete: [
        for (final p in global.pakete)
          if (p.paketId != epicVorteile) p,
      ],
    );
  });

  ProviderContainer container(List<HeroSheet> helden) {
    final zustand = ladeBestandsheld(Bestandsheld.kriegerNormal).state;
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
        heroRepositoryProvider.overrideWithValue(
          FakeRepository(
            heroes: helden,
            states: {for (final h in helden) h.id: zustand},
          ),
        ),
        for (final h in helden) heroByIdProvider(h.id).overrideWithValue(h),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

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

  HeroSheet heldA() =>
      basisHeld.copyWith(id: 'held-a', regelProfil: veraltetesProfil);
  HeroSheet heldB() =>
      basisHeld.copyWith(id: 'held-b', regelProfil: ohneEpicVorteile);

  group('Zwei Helden mit verschiedenen Profilen in einem Container', () {
    test('Katalog und Epic-Schalter gehören je dem eigenen Profil', () async {
      final c = container([heldA(), heldB()]);
      final a = await warte<RulesCatalog>(
        c,
        heroRulesCatalogProvider('held-a'),
      );
      final b = await warte<RulesCatalog>(
        c,
        heroRulesCatalogProvider('held-b'),
      );
      expect(c.read(heroEpicAdvantagesActiveProvider('held-a')), isTrue);
      expect(c.read(heroEpicAdvantagesActiveProvider('held-b')), isFalse);
      expect(a.advantages.length, greaterThan(b.advantages.length));
      // Der Katalog des einen ändert sich nicht, weil der andere gelesen wird.
      final nochmalA = await warte<RulesCatalog>(
        c,
        heroRulesCatalogProvider('held-a'),
      );
      expect(identical(a, nochmalA), isTrue);
    });

    test('die Vorschauen sind unabhängig voneinander', () async {
      final c = container([heldA(), heldB()]);
      final a = await warte<RegelProfilVorschau?>(
        c,
        regelProfilVorschauProvider('held-a'),
      );
      final b = await warte<RegelProfilVorschau?>(
        c,
        regelProfilVorschauProvider('held-b'),
      );
      expect(a, isNotNull);
      expect(b, isNotNull);
      expect(a!.uebernehmbar, isTrue);
      expect(a.von, veraltetesProfil);
      expect(a.vergleich.hinweise.map((h) => (h.art, h.paketId)), [
        (PaketHinweisArt.aktualisiert, talentPaket),
      ]);
      expect(b!.von, ohneEpicVorteile);
      expect(b.uebernehmbar, isFalse);
      expect(b.vergleich.hinweise, isEmpty);
      expect(b.istLeer, isTrue);
    });
  });

  group('Je ein Held in zwei Containern', () {
    test('dieselbe Held-ID mit anderem Profil bleibt getrennt', () async {
      final eins = container([
        basisHeld.copyWith(regelProfil: veraltetesProfil),
      ]);
      final zwei = container([
        basisHeld.copyWith(regelProfil: ohneEpicVorteile),
      ]);
      final id = basisHeld.id;
      final vorschauEins = await warte<RegelProfilVorschau?>(
        eins,
        regelProfilVorschauProvider(id),
      );
      final vorschauZwei = await warte<RegelProfilVorschau?>(
        zwei,
        regelProfilVorschauProvider(id),
      );
      expect(vorschauEins!.uebernehmbar, isTrue);
      expect(vorschauZwei!.uebernehmbar, isFalse);
      expect(eins.read(heroEpicAdvantagesActiveProvider(id)), isTrue);
      expect(zwei.read(heroEpicAdvantagesActiveProvider(id)), isFalse);
    });
  });

  test('ein Update verändert den Helden erst nach der Übernahme', () async {
    final held = heldA();
    final zustand = ladeBestandsheld(Bestandsheld.kriegerNormal).state;
    final repo = FakeRepository(heroes: [held], states: {held.id: zustand});
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
      ],
    );
    addTearDown(c.dispose);
    // Der Held steht erst da, wenn der Index geladen ist.
    final geladen = Completer<void>();
    c.listen<HeroSheet?>(heroByIdProvider(held.id), (_, next) {
      if (next != null && !geladen.isCompleted) geladen.complete();
    }, fireImmediately: true);
    await geladen.future.timeout(const Duration(seconds: 30));

    final vorher = await warte<RegelProfilVorschau?>(
      c,
      regelProfilVorschauProvider(held.id),
    );
    final alterKatalog = await warte<RulesCatalog>(
      c,
      heroRulesCatalogProvider(held.id),
    );
    expect(vorher!.uebernehmbar, isTrue);
    // Die Vorschau hat nichts gespeichert.
    expect((await repo.loadHeroById(held.id))!.regelProfil, veraltetesProfil);

    await c
        .read(regelProfilUebernehmenProvider)
        .uebernehme(heroId: held.id, vorschau: vorher);

    final gespeichert = (await repo.loadHeroById(held.id))!;
    expect(gespeichert.regelProfil, vorher.auf);
    expect(gespeichert.regelProfil, isNot(veraltetesProfil));
    // Danach ist die Vorschau leer und der Held rechnet mit dem neuen Stand.
    final nachher = await _warteAufWert<RegelProfilVorschau?>(
      c,
      regelProfilVorschauProvider(held.id),
      (v) => v != null && !v.uebernehmbar,
    );
    expect(nachher!.vergleich.hinweise, isEmpty);
    final neuerKatalog = await _warteAufWert<RulesCatalog>(
      c,
      heroRulesCatalogProvider(held.id),
      (k) => !identical(k, alterKatalog),
    );
    expect(
      neuerKatalog.talents.map((t) => t.steigerung).join(),
      isNot(alterKatalog.talents.map((t) => t.steigerung).join()),
    );
  });

  group('Ohne Profil', () {
    test(
      'es gibt nichts vorzuschauen, der Held folgt den Einstellungen',
      () async {
        final c = container([basisHeld.copyWith(regelProfil: null)]);
        final vorschau = await warte<RegelProfilVorschau?>(
          c,
          regelProfilVorschauProvider(basisHeld.id),
        );
        expect(vorschau, isNull);
      },
    );

    test('ein nicht verstandenes Profil wird wie keines behandelt', () async {
      final c = container([
        basisHeld.copyWith(
          regelProfil: veraltetesProfil.copyWith(formatVersion: 99),
        ),
      ]);
      final vorschau = await warte<RegelProfilVorschau?>(
        c,
        regelProfilVorschauProvider(basisHeld.id),
      );
      expect(vorschau, isNull);
    });
  });

  test('Helden mit gleichem Profil teilen den Vergleich', () async {
    final c = container([
      basisHeld.copyWith(id: 'x', regelProfil: veraltetesProfil),
      basisHeld.copyWith(id: 'y', regelProfil: veraltetesProfil),
    ]);
    final x = await warte<RegelProfilVorschau?>(
      c,
      regelProfilVorschauProvider('x'),
    );
    final y = await warte<RegelProfilVorschau?>(
      c,
      regelProfilVorschauProvider('y'),
    );
    expect(identical(x!.vergleich, y!.vergleich), isTrue);
  });
}

// Wartet, bis der Provider einen Wert liefert, der [passt].
Future<T> _warteAufWert<T>(
  ProviderContainer c,
  ProviderListenable<AsyncValue<T>> provider,
  bool Function(T wert) passt,
) {
  final completer = Completer<T>();
  c.listen<AsyncValue<T>>(provider, (_, next) {
    if (completer.isCompleted) return;
    if (next.hasError) {
      completer.completeError(next.error!, next.stackTrace);
    } else if (next.hasValue && passt(next.requireValue)) {
      completer.complete(next.requireValue);
    }
  }, fireImmediately: true);
  return completer.future.timeout(const Duration(seconds: 60));
}
