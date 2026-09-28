import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/app_storage_paths.dart';
import 'package:dsa_heldenverwaltung/data/hive_hero_repository.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_zuordnung_rules.dart';
import 'package:dsa_heldenverwaltung/state/avatar_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/in_memory_avatar_file_storage.dart';

import '../test_support/hero_fixtures.dart';
import '../test_support/real_catalog.dart';

/// Migration der Vor-/Nachteil-Texte in strukturierte Eintraege (ARCH-02)
/// mit echtem Hive: einmal beim Speichern, danach ein Fixpunkt, gleiche
/// Regelwerte, erhalten ueber Neustart sowie Export und Import.
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

  // Werte, die ein Nutzer sieht und die von Vor-/Nachteilen abhaengen.
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
      'gs': basis.gs,
      'eigenschaften': snapshot.effectiveAttributes.toJson(),
      'startwerte': snapshot.effectiveStartAttributes.toJson(),
      'wundschwellen': snapshot.wundschwellenStufen.ko,
      'ausweichen': snapshot.combatPreviewStats.ausweichen,
      'magie': snapshot.resourceActivation.magic.isEnabled,
    };
  }

  Map<String, dynamic> ohneStempel(HeroSheet held) {
    return held.toJson()..remove('lastModified');
  }

  const faelle = <Bestandsheld>[
    Bestandsheld.kriegerNormal,
    Bestandsheld.geodeMagisch,
    Bestandsheld.geweihterKarmal,
    Bestandsheld.freitextMerkmale,
    Bestandsheld.legacySchema1,
  ];

  for (final fall in faelle) {
    test('${fall.datei}: einmal migriert, danach unverändert', () async {
      final pfad = await hiveTempVerzeichnis('arch02_');
      var speicher = await oeffnen(pfad);
      final bundle = ladeBestandsheld(fall);
      final id = bundle.hero.id;
      await speicher.repo.saveHero(bundle.hero);
      await speicher.repo.saveHeroState(id, bundle.state);
      final vorher = werte(bundle.hero, bundle.state);

      final actions = speicher.container.read(heroActionsProvider);
      await actions.saveHero(
        (await speicher.repo.loadHeroById(id))!,
        validationCatalog: katalog.catalog,
      );
      await speicher.repo.close();
      speicher = await oeffnen(pfad);

      final held = (await speicher.repo.loadHeroById(id))!;
      expect(held.vorteilEintraege, isNotEmpty);
      expect(held.nachteilEintraege, isNotEmpty);
      expect(held.vorteileText, projiziereMerkmalText(held.vorteilEintraege));
      expect(held.nachteileText, projiziereMerkmalText(held.nachteilEintraege));
      // Nur die Merkmale vergleichen: `saveHero` normalisiert Altstände
      // (f07) auch an Stufe und Startwerten.
      final ohneListe = held.copyWith(
        vorteilEintraege: const [],
        nachteilEintraege: const [],
        vorteileText: bundle.hero.vorteileText,
        nachteileText: bundle.hero.nachteileText,
      );
      expect(werte(held, bundle.state), werte(ohneListe, bundle.state));
      if (fall.istAktuellesFormat) {
        expect(werte(held, bundle.state), vorher, reason: 'gleiche Regelwerte');
      }
      expect(ohneStempel(HeroSheet.fromJson(held.toJson())), ohneStempel(held));
      expect(
        ohneStempel(
          merkmaleZumSpeichern(
            held,
            katalog: MerkmalKatalog.von(katalog.catalog),
          ),
        ),
        ohneStempel(held),
        reason: 'ein zweites Speichern migriert nichts mehr',
      );

      // Export und Import als Kopie erhalten die Liste.
      final zweiteActions = speicher.container.read(heroActionsProvider);
      final export = await zweiteActions.buildExportJson(id);
      final kopieId = await zweiteActions.importHeroBundle(
        await zweiteActions.parseImportJson(export),
        resolution: ImportConflictResolution.createNewHero,
      );
      final kopie = (await speicher.repo.loadHeroById(kopieId))!;
      expect(kopie.vorteilEintraege, held.vorteilEintraege);
      expect(kopie.nachteilEintraege, held.nachteilEintraege);
      expect(kopie.vorteileText, held.vorteileText);
    });
  }
}
