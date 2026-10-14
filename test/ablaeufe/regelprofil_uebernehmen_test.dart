import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/held_schreiben.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/regelprofil_uebernehmen.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_runtime_data.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';
import 'package:dsa_heldenverwaltung/catalog/regelprofil_aufloesung.dart';
import 'package:dsa_heldenverwaltung/catalog/regelprofil_vergleich.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_regelprofil.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/rules/derived/regelprofil_vorschau_rules.dart';

import '../test_support/bogen_test_repository.dart';
import '../test_support/hero_fixtures.dart';
import '../test_support/real_catalog.dart';

/// „Regelprofil übernehmen“: ein App-Update wirkt erst nach der Übernahme
/// (ARCH-04, ARCH-05).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const talentPaket = 'regelwerk_ueberarbeitung_v1.talents_learning';

  late EchterKatalog katalog;
  late HeroSheet krieger;
  late HeroRegelProfil veraltetesProfil;
  late BogenTestRepository repo;
  late List<RulesCatalog?> normalisiertMit;
  late RegelProfilUebernehmen ablauf;

  HeroRegelProfil globalesProfil() => regelProfilAusGlobalemStand(
    catalogVersion: katalog.runtimeData.baseData.version,
    paketKatalog: katalog.runtimeData.packCatalog,
    aktivePaketIds: katalog.runtimeData.activeHouseRulePackIds,
  );

  String abbild(CatalogRuntimeData daten) => jsonEncode({
    for (final section in editableCatalogSections)
      section.name: daten.effectiveData.entriesFor(section),
  });

  RegelProfilVorschau vorschauFuer(HeroSheet held) {
    final vergleich = erstelleRegelProfilVergleich(
      profil: held.regelProfil!,
      basisDaten: katalog.runtimeData.baseData,
      eigeneEintraege: katalog.runtimeData.customSnapshot,
      aktuellerPaketKatalog: katalog.runtimeData.packCatalog,
    );
    return erstelleRegelProfilVorschau(
      hero: held,
      state: ladeBestandsheld(Bestandsheld.kriegerNormal).state,
      vergleich: vergleich,
    );
  }

  setUpAll(() async {
    katalog = await ladeEchtenRegelkatalog();
    final profil = globalesProfil();
    // Eine ältere Fassung des Talentpakets, wie sie ein früheres Speichern
    // hinterlassen hätte.
    veraltetesProfil = profil.copyWith(
      pakete: [
        for (final p in profil.pakete)
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
    krieger = ladeBestandsheld(Bestandsheld.kriegerNormal).hero
        .copyWith(regelProfil: veraltetesProfil);
  });

  setUp(() {
    repo = BogenTestRepository(heroes: [krieger]);
    normalisiertMit = <RulesCatalog?>[];
    ablauf = RegelProfilUebernehmen(
      aendere: (heroId, aenderung, {validationCatalog}) =>
          aendereGespeichertenHelden(
            repository: repo,
            heroId: heroId,
            aenderung: aenderung,
            speichere: (geaendert) async {
              normalisiertMit.add(validationCatalog);
              await repo.saveHero(geaendert);
              return geaendert;
            },
          ),
    );
  });

  test('die Vorschau allein ändert und speichert nichts', () async {
    final vorschau = vorschauFuer(krieger);
    expect(vorschau.uebernehmbar, isTrue);
    expect(vorschau.von, veraltetesProfil);
    expect(vorschau.auf, globalesProfil());
    expect(repo.bogenSpeicherungen, 0);
    final gespeichert = await repo.gespeichert(krieger.id);
    expect(gespeichert.regelProfil, veraltetesProfil);
    expect(heroContentHash(gespeichert), heroContentHash(krieger));
  });

  test('bis zur Übernahme rechnet der Held mit seiner alten Kopie', () async {
    final vorschau = vorschauFuer(krieger);
    final gespeichert = await repo.gespeichert(krieger.id);
    // Der Katalog des gespeicherten Profils bleibt der alte, auch wenn der
    // aktuelle Paketstand ein anderer ist.
    final heute = loeseRegelProfilAuf(
      basisDaten: katalog.runtimeData.baseData,
      profil: gespeichert.regelProfil!,
      eigeneEintraege: katalog.runtimeData.customSnapshot,
    );
    expect(
      abbild(heute.runtimeData),
      abbild(vorschau.vergleich.alt.runtimeData),
    );
    expect(abbild(heute.runtimeData), isNot(abbild(katalog.runtimeData)));
  });

  test(
    'die Übernahme schreibt genau ein Dokument mit dem neuen Profil',
    () async {
      final vorschau = vorschauFuer(krieger);
      final ergebnis = await ablauf.uebernehme(
        heroId: krieger.id,
        vorschau: vorschau,
      );
      expect(repo.bogenSpeicherungen, 1);
      expect(ergebnis.regelProfil, vorschau.auf);
      final gespeichert = await repo.gespeichert(krieger.id);
      expect(gespeichert.regelProfil, globalesProfil());
      // Alles übrige am Helden bleibt, wie es war.
      expect(
        heroContentHash(gespeichert.copyWith(regelProfil: veraltetesProfil)),
        heroContentHash(krieger),
      );
      // Nach der Übernahme rechnet der Held wie der aktuelle Stand.
      final danach = loeseRegelProfilAuf(
        basisDaten: katalog.runtimeData.baseData,
        profil: gespeichert.regelProfil!,
        eigeneEintraege: katalog.runtimeData.customSnapshot,
      );
      expect(abbild(danach.runtimeData), abbild(katalog.runtimeData));
      // Die Normalisierung nutzt den Katalog des neuen Profils.
      expect(normalisiertMit.single, same(vorschau.vergleich.neu.katalog));
    },
  );

  test('ein inzwischen geändertes Profil wird nicht überschrieben', () async {
    final vorschau = vorschauFuer(krieger);
    final fremd = globalesProfil().copyWith(pakete: const []);
    repo.fremdeAenderung = (held) => held.copyWith(regelProfil: fremd);
    await expectLater(
      ablauf.uebernehme(heroId: krieger.id, vorschau: vorschau),
      throwsStateError,
    );
    expect(repo.bogenSpeicherungen, 0);
    expect((await repo.gespeichert(krieger.id)).regelProfil, veraltetesProfil);
  });

  test('ist das Profil schon aktuell, wird nichts geschrieben', () async {
    final aktuell = krieger.copyWith(regelProfil: globalesProfil());
    repo = BogenTestRepository(heroes: [aktuell]);
    final vorschau = vorschauFuer(aktuell);
    expect(vorschau.uebernehmbar, isFalse);
    await ablauf.uebernehme(heroId: aktuell.id, vorschau: vorschau);
    expect(repo.bogenSpeicherungen, 0);
    expect(normalisiertMit, isEmpty);
  });

  test('ein fehlender Held ist ein Fehler, kein stilles Anlegen', () async {
    final vorschau = vorschauFuer(krieger);
    await expectLater(
      ablauf.uebernehme(heroId: 'gibt-es-nicht', vorschau: vorschau),
      throwsStateError,
    );
    expect(repo.bogenSpeicherungen, 0);
  });

  test('die Erstübernahme setzt das Profil eines Helden ohne Profil', () async {
    final ohneProfil = krieger.copyWith(regelProfil: null);
    repo = BogenTestRepository(heroes: [ohneProfil]);
    await ablauf.setzeProfil(
      heroId: ohneProfil.id,
      von: null,
      auf: globalesProfil(),
    );
    expect(repo.bogenSpeicherungen, 1);
    expect(
      (await repo.gespeichert(ohneProfil.id)).regelProfil,
      globalesProfil(),
    );
  });
}
