import 'dart:async';
import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
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
import 'package:dsa_heldenverwaltung/state/regelprofil_vorschau_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

import '../test_support/hero_fixtures.dart';
import '../test_support/real_catalog.dart';

/// Gruppenvorgabe als Vorschau für den Helden (ARCH-04).
///
/// Die Vorgabe wird nur angeboten: Kein Provider und keine Vorschau ändert das
/// Profil des Helden.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const talentPaket = 'regelwerk_ueberarbeitung_v1.talents_learning';

  late EchterKatalog katalog;
  late HeroSheet basisHeld;
  late HeroRegelProfil aktuell;
  late HeroRegelProfil veraltet;
  late FakeFirebaseFirestore firestore;

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

  setUp(() => firestore = FakeFirebaseFirestore());

  Future<void> setzeVorgabe(HeroRegelProfil profil) => firestore
      .doc('groups_v2/g1/shared_info/regelprofil')
      .set(<String, dynamic>{'profilJson': jsonEncode(profil.toJson())});

  HeroSheet held({
    HeroRegelProfil? profil,
    List<HeroGruppenMitgliedschaft> gruppen = const [
      HeroGruppenMitgliedschaft(
        gruppenCode: 'g1',
        gruppenName: 'Die Silberfüchse',
        kontoGruppe: true,
        primaer: true,
      ),
    ],
  }) => basisHeld.copyWith(regelProfil: profil, gruppen: gruppen);

  ProviderContainer container(HeroSheet h, {bool firestoreDa = true}) {
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
          FakeRepository(heroes: [h], states: {h.id: zustand}),
        ),
        heroByIdProvider(h.id).overrideWithValue(h),
        firebaseBootstrapProvider.overrideWithValue(
          firestoreDa
              ? const FirebaseBootstrapResult.available()
              : const FirebaseBootstrapResult.unavailable(
                  userMessage: 'Firestore ist nicht verfügbar.',
                ),
        ),
        gruppenSyncServiceProvider.overrideWithValue(
          GruppenSyncService(firestore: firestore, uidProvider: () => 'ich'),
        ),
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

  test('eine abweichende Vorgabe wird als Vorschau angeboten', () async {
    await setzeVorgabe(aktuell);
    final c = container(held(profil: veraltet));

    final angebot = await warte<GruppenVorgabeVorschau?>(
      c,
      gruppenVorgabeVorschauProvider(basisHeld.id),
    );

    expect(angebot, isNotNull);
    expect(angebot!.gruppenCode, 'g1');
    expect(angebot.gruppenName, 'Die Silberfüchse');
    expect(angebot.vorschau.uebernehmbar, isTrue);
    expect(angebot.vorschau.von, veraltet);
    expect(angebot.vorschau.auf, aktuell);
    // Angeboten, nicht geschrieben.
    expect(c.read(heroRegelProfilProvider(basisHeld.id)), veraltet);
  });

  test('ein Held ohne Profil wird mit dem globalen Stand verglichen', () async {
    await setzeVorgabe(veraltet);
    final c = container(held());
    final global = await warte<HeroRegelProfil>(c, globalesRegelProfilProvider);
    // Gleicher Stand wie die Vorgabe wäre kein Angebot; der Test braucht einen
    // Unterschied.
    expect(global, isNot(veraltet));

    final angebot = await warte<GruppenVorgabeVorschau?>(
      c,
      gruppenVorgabeVorschauProvider(basisHeld.id),
    );

    expect(angebot, isNotNull);
    expect(angebot!.vorschau.von, global);
    expect(angebot.vorschau.auf, veraltet);
    expect(c.read(heroRegelProfilProvider(basisHeld.id)), isNull);
  });

  test(
    'rechnet der Held schon mit der Vorgabe, gibt es kein Angebot',
    () async {
      await setzeVorgabe(aktuell);
      final c = container(held(profil: aktuell));

      expect(
        await warte<GruppenVorgabeVorschau?>(
          c,
          gruppenVorgabeVorschauProvider(basisHeld.id),
        ),
        isNull,
      );
    },
  );

  test('ohne Vorgabe der Gruppe gibt es kein Angebot', () async {
    final c = container(held(profil: veraltet));

    expect(
      await warte<GruppenVorgabeVorschau?>(
        c,
        gruppenVorgabeVorschauProvider(basisHeld.id),
      ),
      isNull,
    );
  });

  test('nur eine primäre Konto-Gruppe gibt das Profil vor', () async {
    await setzeVorgabe(aktuell);
    final c = container(
      held(
        profil: veraltet,
        gruppen: const [
          HeroGruppenMitgliedschaft(gruppenCode: 'g1', kontoGruppe: true),
          HeroGruppenMitgliedschaft(gruppenCode: 'alt', primaer: true),
        ],
      ),
    );

    expect(c.read(heroPrimaereGruppeProvider(basisHeld.id)), isNull);
    expect(
      await warte<GruppenVorgabeVorschau?>(
        c,
        gruppenVorgabeVorschauProvider(basisHeld.id),
      ),
      isNull,
    );
  });

  test('ohne Firestore (Windows) gilt die eigene Auswahl', () async {
    await setzeVorgabe(aktuell);
    final c = container(held(profil: veraltet), firestoreDa: false);

    expect(
      await warte<GruppenVorgabeVorschau?>(
        c,
        gruppenVorgabeVorschauProvider(basisHeld.id),
      ),
      isNull,
    );
  });

  test(
    'ohne Verbindung bleibt es beim Fehler, der Held ändert sich nicht',
    () async {
      final c = ProviderContainer(
        overrides: [
          firebaseBootstrapProvider.overrideWithValue(
            const FirebaseBootstrapResult.available(),
          ),
          heroByIdProvider(basisHeld.id)
              .overrideWithValue(held(profil: veraltet)),
          gruppenSyncServiceProvider.overrideWithValue(
            _OfflineDienst(firestore),
          ),
        ],
      );
      addTearDown(c.dispose);

      await expectLater(
        warte<GruppenVorgabeVorschau?>(
          c,
          gruppenVorgabeVorschauProvider(basisHeld.id),
        ),
        throwsA(isA<GruppenException>()),
      );
      expect(c.read(heroRegelProfilProvider(basisHeld.id)), veraltet);
    },
  );

  test(
    'ein nicht verstandenes Profil des Helden bleibt unangetastet',
    () async {
      await setzeVorgabe(aktuell);
      final c = container(held(profil: veraltet.copyWith(formatVersion: 99)));

      expect(
        await warte<GruppenVorgabeVorschau?>(
          c,
          gruppenVorgabeVorschauProvider(basisHeld.id),
        ),
        isNull,
      );
    },
  );
}

class _OfflineDienst extends GruppenSyncService {
  _OfflineDienst(FakeFirebaseFirestore firestore)
    : super(firestore: firestore, uidProvider: () => 'ich');

  @override
  Future<HeroRegelProfil?> ladeRegelVorgabe(String groupId) =>
      Future<HeroRegelProfil?>.error(
        const GruppenException('Keine Verbindung.'),
      );
}
