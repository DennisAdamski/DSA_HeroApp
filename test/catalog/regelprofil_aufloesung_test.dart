import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_runtime_data.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';
import 'package:dsa_heldenverwaltung/catalog/regelprofil_aufloesung.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/data/custom_catalog_repository.dart';
import 'package:dsa_heldenverwaltung/data/house_rule_pack_repository.dart';
import 'package:dsa_heldenverwaltung/domain/hero_regelprofil.dart';
import 'package:dsa_heldenverwaltung/rules/house_rules/house_rule_registry.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/house_rules_providers.dart';
import 'package:dsa_heldenverwaltung/state/regelprofil_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';

import '../test_support/hero_fixtures.dart';
import '../test_support/real_catalog.dart';

/// Das Regelprofil eines Helden gegen den echten Katalog (ARCH-04).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EchterKatalog katalog;

  setUpAll(() async {
    katalog = await ladeEchtenRegelkatalog();
  });

  String abbild(CatalogRuntimeData daten) => jsonEncode({
    for (final section in editableCatalogSections)
      section.name: daten.effectiveData.entriesFor(section),
  });

  HeroRegelProfil globalesProfil() => regelProfilAusGlobalemStand(
    catalogVersion: katalog.runtimeData.baseData.version,
    paketKatalog: katalog.runtimeData.packCatalog,
    aktivePaketIds: katalog.runtimeData.activeHouseRulePackIds,
  );

  RegelProfilAufloesung loese(HeroRegelProfil profil) => loeseRegelProfilAuf(
    basisDaten: katalog.runtimeData.baseData,
    profil: profil,
    eigeneEintraege: katalog.runtimeData.customSnapshot,
  );

  group('Profil aus dem globalen Stand', () {
    test('enthält alle aktiven Pakete mit Kopie und Prüfsumme', () {
      final profil = globalesProfil();
      expect(profil.paketIds, katalog.runtimeData.activeHouseRulePackIds);
      expect(profil.pakete, isNotEmpty);
      for (final paket in profil.pakete) {
        final original = katalog.runtimeData.packCatalog.packs.firstWhere(
          (p) => p.id == paket.paketId,
        );
        expect(paket.pruefsumme, pruefsummeDesPakets(original));
        expect(paket.manifest['id'], paket.paketId);
      }
    });

    test('die Auflösung ergibt genau die Katalogdaten des globalen Stands', () {
      final aufloesung = loese(globalesProfil());
      expect(abbild(aufloesung.runtimeData), abbild(katalog.runtimeData));
      expect(
        aufloesung.aktivePaketIds,
        katalog.runtimeData.activeHouseRulePackIds,
      );
      expect(aufloesung.hinweise, isEmpty);
      expect(aufloesung.katalog.talents.length, katalog.catalog.talents.length);
    });

    test('Round-trip durch JSON ändert das Ergebnis nicht', () {
      final profil = HeroRegelProfil.fromJson(
        jsonDecode(jsonEncode(globalesProfil().toJson()))
            as Map<String, dynamic>,
      );
      expect(abbild(loese(profil).runtimeData), abbild(katalog.runtimeData));
    });
  });

  group('Abweichendes Profil', () {
    test('ein Held ohne Hausregelpakete rechnet ohne ihre Wirkung', () {
      final leer = globalesProfil().copyWith(
        pakete: const <HeroRegelProfilPaket>[],
      );
      final aufloesung = loese(leer);
      expect(aufloesung.aktivePaketIds, isEmpty);
      expect(
        abbild(aufloesung.runtimeData),
        isNot(abbild(katalog.runtimeData)),
      );
      // Gate: Einträge mit ruleMeta.sourceKey verschwinden ohne ihr Paket.
      expect(
        aufloesung.katalog.combatSpecialAbilities.length,
        lessThan(katalog.catalog.combatSpecialAbilities.length),
      );
    });

    test('Pakete außerhalb des Profils sind für den Helden aus', () {
      final profil = globalesProfil();
      final ohneEpos = profil.copyWith(
        pakete: [
          for (final p in profil.pakete)
            if (!p.paketId.startsWith('epic_rules_v1')) p,
        ],
      );
      final aufloesung = loese(ohneEpos);
      expect(
        aufloesung.aktivePaketIds.any((id) => id.startsWith('epic_rules_v1')),
        isFalse,
      );
      expect(
        aufloesung.aktivePaketIds.contains(EpicRuleKeys.advantages),
        isFalse,
      );
    });

    test('die Paketkopie bestimmt die Wirkung, nicht der aktuelle Stand', () {
      final profil = globalesProfil();
      // Kopie des Pakets, das Talente überschreibt, ohne seine Patches.
      final veraendert = profil.copyWith(
        pakete: [
          for (final p in profil.pakete)
            if (p.paketId == 'regelwerk_ueberarbeitung_v1.talents_learning')
              p.copyWith(
                manifest: <String, Object?>{
                  ...p.manifest,
                  'patches': <Object?>[],
                },
              )
            else
              p,
        ],
      );
      expect(
        abbild(loese(veraendert).runtimeData),
        isNot(abbild(katalog.runtimeData)),
      );
    });

    test('eine unlesbare Paketkopie wird gemeldet und übersprungen', () {
      final profil = globalesProfil();
      final kaputt = profil.copyWith(
        pakete: [
          ...profil.pakete,
          HeroRegelProfilPaket(
            paketId: 'kaputt',
            pruefsumme: 'x',
            manifest: const <String, Object?>{'id': '', 'title': ''},
          ),
        ],
      );
      final aufloesung = loese(kaputt);
      expect(aufloesung.hinweise.map((h) => h.packId), contains('kaputt'));
      expect(abbild(aufloesung.runtimeData), abbild(katalog.runtimeData));
    });
  });

  group('Provider', () {
    ProviderContainer container({
      HeroRegelProfil? profil,
      Set<String> deaktiviert = const <String>{},
    }) {
      final held = ladeBestandsheld(Bestandsheld.kriegerNormal).hero
          .copyWith(regelProfil: profil);
      final c = ProviderContainer(
        overrides: [
          customCatalogRepositoryProvider.overrideWithValue(
            const CustomCatalogRepository(heroStoragePath: ''),
          ),
          houseRulePackRepositoryProvider.overrideWithValue(
            const HouseRulePackRepository(heroStoragePath: ''),
          ),
          catalogDisabledHouseRulePackIdsProvider.overrideWithValue(
            deaktiviert,
          ),
          catalogContentPasswordProvider.overrideWithValue(null),
          heroByIdProvider(held.id).overrideWithValue(held),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    Future<RulesCatalog> warteAufKatalog(ProviderContainer c, String id) {
      final completer = Completer<RulesCatalog>();
      c.listen(heroRulesCatalogProvider(id), (_, next) {
        if (completer.isCompleted) return;
        if (next.hasError) {
          completer.completeError(next.error!, next.stackTrace);
        }
        if (next.hasValue) completer.complete(next.requireValue);
      }, fireImmediately: true);
      return completer.future.timeout(const Duration(seconds: 60));
    }

    final heldId = ladeBestandsheld(Bestandsheld.kriegerNormal).hero.id;

    test(
      'ohne Profil gilt der globale Katalog und Einstellungsstand',
      () async {
        final c = container(deaktiviert: {'epic_rules_v1'});
        final global = await warteAufKatalog(c, heldId);
        expect(c.read(heroRegelProfilProvider(heldId)), isNull);
        expect(c.read(heroEpicAdvantagesActiveProvider(heldId)), isFalse);
        expect(
          global.combatSpecialAbilities.length,
          c
              .read(rulesCatalogProvider)
              .requireValue
              .combatSpecialAbilities
              .length,
        );
      },
    );

    test('mit Profil zählt das Profil, nicht die Einstellungen', () async {
      final c = container(
        profil: globalesProfil(),
        deaktiviert: {'epic_rules_v1', 'regelwerk_ueberarbeitung_v1'},
      );
      final katalogDesHelden = await warteAufKatalog(c, heldId);
      expect(c.read(heroEpicAdvantagesActiveProvider(heldId)), isTrue);
      expect(katalogDesHelden.talents.length, katalog.catalog.talents.length);
      expect(c.read(isHouseRuleActiveProvider('epic_rules_v1')), isFalse);
    });

    test('ein nicht verstandenes Profil wird wie keines behandelt', () async {
      final profil = globalesProfil().copyWith(formatVersion: 99);
      final c = container(profil: profil);
      await warteAufKatalog(c, heldId);
      expect(c.read(heroRegelProfilProvider(heldId)), isNull);
    });

    test('Helden mit gleichem Profil teilen die Auflösung', () async {
      final c = container(profil: globalesProfil());
      await warteAufKatalog(c, heldId);
      final a = c.read(regelProfilAufloesungProvider(globalesProfil()));
      final b = c.read(regelProfilAufloesungProvider(globalesProfil()));
      expect(identical(a.requireValue, b.requireValue), isTrue);
    });
  });
}
