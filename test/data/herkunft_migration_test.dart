import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/app_storage_paths.dart';
import 'package:dsa_heldenverwaltung/data/hive_hero_repository.dart';
import 'package:dsa_heldenverwaltung/domain/hero_herkunft.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_herkunft_migration_rules.dart';
import 'package:dsa_heldenverwaltung/state/avatar_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/in_memory_avatar_file_storage.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';

import '../test_support/hero_fixtures.dart';
import '../test_support/real_catalog.dart';

/// Migration der Herkunftstexte in strukturierte Modifikatoren (ARCH-02,
/// Herkunftsmerkmale) mit echtem Hive: einmal beim Speichern, danach ein
/// Fixpunkt, gleiche Regelwerte, erhalten über Neustart sowie Export und
/// Import.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EchterKatalog katalog;

  setUpAll(() async {
    katalog = await ladeEchtenRegelkatalog();
  });

  Future<({HiveHeroRepository repo, ProviderContainer container})> oeffnen(
    String pfad,
  ) async {
    final repo = await HiveHeroRepository.create(storagePath: pfad);
    final container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(repo),
        ...katalog.overrides,
        avatarFileStorageProvider.overrideWithValue(
          InMemoryAvatarFileStorage(),
        ),
        heroStorageLocationProvider.overrideWith(
          (ref) async => HeroStorageLocation(
            defaultPath: pfad,
            effectivePath: pfad,
            customPathSupported: false,
            usesCustomPath: false,
          ),
        ),
      ],
    );
    var geschlossen = false;
    Future<void> schliessen() async {
      if (geschlossen) return;
      geschlossen = true;
      container.dispose();
      await repo.close();
    }

    addTearDown(schliessen);
    return (repo: repo, container: container);
  }

  Map<String, Object?> werte(HeroSheet held, HeroState zustand) {
    final snapshot = buildHeroComputedSnapshot(
      hero: held,
      state: zustand,
      catalog: katalog.catalog,
      epicAdvantagesActive: katalog.epicAdvantagesActive,
    );
    final basis = snapshot.derivedStats;
    return <String, Object?>{
      'lep': basis.maxLep,
      'au': basis.maxAu,
      'asp': basis.maxAsp,
      'kap': basis.maxKap,
      'mr': basis.mr,
      'ini': basis.iniBase,
      'eigenschaften': snapshot.effectiveAttributes.toJson(),
      'startwerte': snapshot.effectiveStartAttributes.toJson(),
      'maxima': snapshot.attributeMaximums.toJson(),
      'magie': snapshot.resourceActivation.magic.isEnabled,
      'karma': snapshot.resourceActivation.divine.isEnabled,
    };
  }

  Map<String, dynamic> ohneStempel(HeroSheet held) {
    return held.toJson()..remove('lastModified');
  }

  const faelle = <Bestandsheld>[
    Bestandsheld.kriegerNormal,
    Bestandsheld.geodeMagisch,
    Bestandsheld.geweihterKarmal,
    Bestandsheld.episch,
    Bestandsheld.freitextMerkmale,
    Bestandsheld.gleichnamigeAusruestung,
    Bestandsheld.legacySchema1,
  ];

  for (final fall in faelle) {
    test('${fall.datei}: einmal migriert, danach unverändert', () async {
      final pfad = await hiveTempVerzeichnis('arch02_herkunft_');
      var speicher = await oeffnen(pfad);
      final bundle = ladeBestandsheld(fall);
      final id = bundle.hero.id;
      await speicher.repo.saveHero(bundle.hero);
      await speicher.repo.saveHeroState(id, bundle.state);
      expect(bundle.hero.background.herkunftsModifikatoren, isNull);
      final vorher = werte(bundle.hero, bundle.state);

      // Laden und Rohspeichern migrieren nichts.
      expect(
        (await speicher.repo.loadHeroById(id))!
            .toJson()
            .containsKey('herkunftsModifikatoren'),
        isFalse,
      );

      await speicher.container
          .read(heroActionsProvider)
          .saveHero(
            (await speicher.repo.loadHeroById(id))!,
            validationCatalog: katalog.catalog,
          );
      await speicher.repo.close();
      speicher = await oeffnen(pfad);

      final held = (await speicher.repo.loadHeroById(id))!;
      final container = held.background.herkunftsModifikatoren;
      expect(container, isNotNull);
      expect(container!.istBearbeitbar, isTrue);
      expect(container.brauchtPruefung, isFalse);
      // Die Texte bleiben beim Migrieren unverändert.
      expect(held.background.rasseModText, bundle.hero.background.rasseModText);
      expect(
        held.background.kulturModText,
        bundle.hero.background.kulturModText,
      );
      expect(
        held.background.professionModText,
        bundle.hero.background.professionModText,
      );
      expect(gleicheHerkunftAb(held.background).abweichungen, isEmpty);
      for (final herkunft in HeroHerkunft.values) {
        expect(
          container.eintraegeFuer(herkunft).map((e) => e.text),
          zerlegeHerkunftsText(
            herkunftsTextVon(bundle.hero.background, herkunft),
          ),
        );
      }
      if (fall.istAktuellesFormat) {
        expect(werte(held, bundle.state), vorher, reason: 'gleiche Regelwerte');
      }
      // Fixpunkt: laden und erneut speichern ändert die Herkunft nicht.
      expect(ohneStempel(HeroSheet.fromJson(held.toJson())), ohneStempel(held));
      expect(herkunftZumSpeichern(held.background), same(held.background));
      await speicher.container
          .read(heroActionsProvider)
          .saveHero(held, validationCatalog: katalog.catalog);
      final nochmal = (await speicher.repo.loadHeroById(id))!;
      expect(
        nochmal.background.herkunftsModifikatoren!.toJson(),
        container.toJson(),
        reason: 'IDs und Einträge bleiben beim zweiten Speichern gleich',
      );

      // Export und Import als Kopie erhalten Liste und Texte.
      final actions = speicher.container.read(heroActionsProvider);
      final export = await actions.buildExportJson(id);
      final kopieId = await actions.importHeroBundle(
        await actions.parseImportJson(export),
        resolution: ImportConflictResolution.createNewHero,
      );
      final kopie = (await speicher.repo.loadHeroById(kopieId))!;
      expect(
        kopie.background.herkunftsModifikatoren!.toJson(),
        container.toJson(),
      );
      expect(kopie.background.rasseModText, held.background.rasseModText);
    });
  }

  test('ein ausdrücklich leerer Container bleibt über Export und Import '
      'erhalten und tritt nicht aus dem Alttext wieder auf', () async {
    final pfad = await hiveTempVerzeichnis('arch02_herkunft_leer_');
    final speicher = await oeffnen(pfad);
    final bundle = ladeBestandsheld(Bestandsheld.kriegerNormal);
    final actions = speicher.container.read(heroActionsProvider);
    // Der Nutzer hat alle Herkunftseinträge gelöscht: leerer Container, leere
    // Texte.
    final leer = bundle.hero.copyWith(
      background: bundle.hero.background.copyWith(
        rasseModText: '',
        kulturModText: '',
        professionModText: '',
        herkunftsModifikatoren: const HeroHerkunftsModifikatoren(),
      ),
    );
    await speicher.repo.saveHero(leer);
    await speicher.repo.saveHeroState(leer.id, bundle.state);
    await actions.saveHero(
      (await speicher.repo.loadHeroById(leer.id))!,
      validationCatalog: katalog.catalog,
    );
    final gespeichert = (await speicher.repo.loadHeroById(leer.id))!;
    expect(gespeichert.background.herkunftsModifikatoren!.rasse, isEmpty);

    final export = await actions.buildExportJson(leer.id);
    final kopieId = await actions.importHeroBundle(
      await actions.parseImportJson(export),
      resolution: ImportConflictResolution.createNewHero,
    );
    final kopie = (await speicher.repo.loadHeroById(kopieId))!;
    expect(kopie.background.herkunftsModifikatoren, isNotNull);
    expect(kopie.background.herkunftsModifikatoren!.rasse, isEmpty);
    expect(kopie.background.rasseModText, isEmpty);
  });

  test('unbekannte Rohdaten überstehen Speichern, Neustart, Export und '
      'Import unverändert', () async {
    final pfad = await hiveTempVerzeichnis('arch02_herkunft_roh_');
    var speicher = await oeffnen(pfad);
    final bundle = ladeBestandsheld(Bestandsheld.kriegerNormal);
    final rohContainer = <String, Object?>{
      'formatVersion': 900,
      'zukunft': <String, Object?>{'wert': 42},
    };
    final json = bundle.hero.toJson()
      ..['herkunftsModifikatoren'] = rohContainer;
    final zukunft = HeroSheet.fromJson(json);
    await speicher.repo.saveHero(zukunft);
    await speicher.repo.saveHeroState(zukunft.id, bundle.state);
    await speicher.container
        .read(heroActionsProvider)
        .saveHero(
          (await speicher.repo.loadHeroById(zukunft.id))!,
          validationCatalog: katalog.catalog,
        );
    await speicher.repo.close();
    speicher = await oeffnen(pfad);

    final held = (await speicher.repo.loadHeroById(zukunft.id))!;
    expect(held.toJson()['herkunftsModifikatoren'], rohContainer);
    expect(held.background.herkunftsModifikatoren!.istBearbeitbar, isFalse);
    // Die drei Texte gelten weiter und wurden nicht migriert.
    expect(held.background.rasseModText, 'LEP+10, AU+10, MR-4');

    final actions = speicher.container.read(heroActionsProvider);
    final export = await actions.buildExportJson(zukunft.id);
    final kopieId = await actions.importHeroBundle(
      await actions.parseImportJson(export),
      resolution: ImportConflictResolution.createNewHero,
    );
    final kopie = (await speicher.repo.loadHeroById(kopieId))!;
    expect(kopie.toJson()['herkunftsModifikatoren'], rohContainer);
  });
}
