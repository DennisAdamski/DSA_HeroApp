import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';
import 'package:dsa_heldenverwaltung/catalog/regelprofil_aufloesung.dart';
import 'package:dsa_heldenverwaltung/catalog/regelprofil_vergleich.dart';
import 'package:dsa_heldenverwaltung/domain/hero_regelprofil.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/domain/talent_special_ability.dart';
import 'package:dsa_heldenverwaltung/rules/derived/regelprofil_vorschau_rules.dart';

import '../test_support/hero_fixtures.dart';
import '../test_support/real_catalog.dart';

/// Auswirkung einer Regelprofil-Aktualisierung auf einen Helden (ARCH-04).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EchterKatalog katalog;
  late HeroSheet krieger;
  late HeroSheet kriegerMitSf;
  late String sfId;
  late String talentId;

  setUpAll(() async {
    katalog = await ladeEchtenRegelkatalog();
    krieger = ladeBestandsheld(Bestandsheld.kriegerNormal).hero;
    // Ein Eintrag des Basiskatalogs: Patches sehen nur, was vor ihnen da ist.
    final roh = katalog.runtimeData.baseData
        .entriesFor(CatalogSectionId.generalSpecialAbilities)
        .firstWhere(
          (e) =>
              e['kette'] == null &&
              e['mehrfachwaehlbar'] != true &&
              e['nur_information'] != true,
        );
    sfId = roh['id'] as String;
    kriegerMitSf = krieger.copyWith(
      talentSpecialAbilities: [
        ...krieger.talentSpecialAbilities,
        TalentSpecialAbility(name: roh['name'] as String),
      ],
    );
    talentId = krieger.talents.entries
        .firstWhere(
          (e) =>
              e.value.talentValue != null &&
              katalog.catalog.talents
                      .where((t) => t.id == e.key)
                      .firstOrNull
                      ?.be
                      .trim() ==
                  '-',
        )
        .key;
  });

  HeroRegelProfil globalesProfil() => regelProfilAusGlobalemStand(
    catalogVersion: katalog.runtimeData.baseData.version,
    paketKatalog: katalog.runtimeData.packCatalog,
    aktivePaketIds: katalog.runtimeData.activeHouseRulePackIds,
  );

  HeroRegelProfil mitPaket(
    HeroRegelProfil profil,
    String id,
    List<Map<String, Object?>> patches, {
    int priority = 0,
  }) {
    final manifest = <String, Object?>{
      'id': id,
      'title': 'Test $id',
      'priority': priority,
      'patches': patches,
    };
    return profil.copyWith(
      pakete: [
        ...profil.pakete,
        HeroRegelProfilPaket(
          paketId: id,
          pruefsumme: stableContentHash(manifest),
          manifest: manifest,
        ),
      ],
    );
  }

  Map<String, Object?> voraussetzungsPatch(String id) => <String, Object?>{
    'section': 'generalSpecialAbilities',
    'selector': <String, Object?>{'entryId': id},
    'setFields': <String, Object?>{
      'voraussetzungen_struktur': <Object?>[
        <String, Object?>{'art': 'eigenschaft', 'code': 'MU', 'min': 99},
      ],
    },
  };

  // Ohne eigene Hürden, damit nur die Testhürde offen sein kann.
  HeroRegelProfil ohneHuerden() => mitPaket(globalesProfil(), 'test_leer', [
    <String, Object?>{
      'section': 'generalSpecialAbilities',
      'selector': <String, Object?>{'entryId': sfId},
      'setFields': <String, Object?>{'voraussetzungen_struktur': <Object?>[]},
    },
  ], priority: 5);

  HeroRegelProfil streng(HeroRegelProfil basis) =>
      mitPaket(basis, 'test_streng', [voraussetzungsPatch(sfId)], priority: 10);

  RegelProfilVorschau vorschau(
    HeroSheet held,
    HeroRegelProfil von,
    HeroRegelProfil auf,
  ) {
    final vergleich = erstelleRegelProfilVergleich(
      profil: von,
      vorgeschlagen: auf,
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

  group('Erwerbsvoraussetzungen', () {
    test('eine neue Hürde trifft die erworbene Fähigkeit', () {
      final profil = ohneHuerden();
      final strenger = streng(profil);
      final ergebnis = vorschau(kriegerMitSf, profil, strenger);
      final eintrag = ergebnis.voraussetzungen.singleWhere((v) => v.id == sfId);
      expect(eintrag.erworben, isTrue);
      expect(eintrag.auswirkung, ErworbenAuswirkung.neuOffen);
      expect(eintrag.offeneVorher, isEmpty);
      expect(eintrag.offeneNachher.single, contains('MU'));
      expect(ergebnis.betroffeneErworbene.map((v) => v.id), [sfId]);
    });

    test('ohne den Besitz bleibt es eine Information', () {
      final profil = ohneHuerden();
      final strenger = streng(profil);
      final ergebnis = vorschau(krieger, profil, strenger);
      final eintrag = ergebnis.voraussetzungen.singleWhere((v) => v.id == sfId);
      expect(eintrag.erworben, isFalse);
      expect(eintrag.auswirkung, ErworbenAuswirkung.nichtErworben);
      expect(eintrag.offeneNachher, isEmpty);
      expect(ergebnis.betroffeneErworbene, isEmpty);
    });

    test('fällt die Hürde weg, sind weniger Punkte offen', () {
      final profil = ohneHuerden();
      final strenger = streng(profil);
      final ergebnis = vorschau(kriegerMitSf, strenger, profil);
      final eintrag = ergebnis.voraussetzungen.singleWhere((v) => v.id == sfId);
      expect(eintrag.auswirkung, ErworbenAuswirkung.nichtMehrOffen);
      expect(eintrag.offeneVorher.single, contains('MU'));
      expect(eintrag.offeneNachher, isEmpty);
    });

    test('ein entfallener Eintrag zählt nur für den Besitzer', () {
      final profil = globalesProfil();
      final entfernt = mitPaket(profil, 'test_weg', [
        <String, Object?>{
          'section': 'generalSpecialAbilities',
          'selector': <String, Object?>{'entryId': sfId},
          'deactivateEntries': true,
        },
      ]);
      final besitzer = vorschau(kriegerMitSf, profil, entfernt);
      expect(
        besitzer.voraussetzungen.singleWhere((v) => v.id == sfId).auswirkung,
        ErworbenAuswirkung.entfallen,
      );
      final fremd = vorschau(krieger, profil, entfernt);
      expect(fremd.voraussetzungen.where((v) => v.id == sfId), isEmpty);
      // Als Katalogeintrag erscheint er trotzdem im Vergleich.
      expect(
        fremd.vergleich.eintraege.any(
          (e) => e.id == sfId && e.art == EintragsAenderungsart.entfernt,
        ),
        isTrue,
      );
    });

    test('ohne Änderung an Voraussetzungen bleibt die Liste leer', () {
      final profil = globalesProfil();
      final ergebnis = vorschau(kriegerMitSf, profil, profil);
      expect(ergebnis.voraussetzungen, isEmpty);
      expect(ergebnis.werte, isEmpty);
      expect(ergebnis.istLeer, isTrue);
      expect(ergebnis.uebernehmbar, isFalse);
    });
  });

  group('Herleitung vorher/nachher', () {
    test('ein geänderter Katalogwert erscheint mit beiden Herleitungen', () {
      final profil = globalesProfil();
      final anders = mitPaket(profil, 'test_be', [
        <String, Object?>{
          'section': 'talents',
          'selector': <String, Object?>{'entryId': talentId},
          'setFields': <String, Object?>{'be': 'x2'},
        },
      ]);
      final ergebnis = vorschau(krieger, profil, anders);
      final wert = ergebnis.werte.singleWhere(
        (w) => w.id == 'talent-$talentId-ebe',
      );
      // Vorher war die eBE 0 und damit keine Herleitung wert.
      expect(wert.vorher, isNull);
      expect(wert.nachher, isNotNull);
      expect(wert.nachher!.ergebnisText, isNot('0'));
      // Anzeige und Wert stammen aus derselben Herleitung.
      expect(wert.nachher!.ergebnisText, '${wert.nachher!.herleitung.wert}');
      expect(ergebnis.werte.map((w) => w.id), contains('talent-$talentId'));
    });
  });

  group('uebernehmeRegelProfil', () {
    test('setzt das Profil auf dem frisch geladenen Helden', () {
      final alt = globalesProfil();
      final neu = mitPaket(alt, 'test_neu', const []);
      final held = krieger.copyWith(regelProfil: alt);
      final ergebnis = uebernehmeRegelProfil(held, von: alt, auf: neu);
      expect(ergebnis.regelProfil, neu);
      expect(ergebnis.id, held.id);
      expect(held.regelProfil, alt);
    });

    test('ein inzwischen geändertes Profil wird nie überschrieben', () {
      final alt = globalesProfil();
      final fremd = mitPaket(alt, 'test_fremd', const []);
      final neu = mitPaket(alt, 'test_neu', const []);
      expect(
        () => uebernehmeRegelProfil(
          krieger.copyWith(regelProfil: fremd),
          von: alt,
          auf: neu,
        ),
        throwsStateError,
      );
      expect(
        () => uebernehmeRegelProfil(krieger, von: alt, auf: neu),
        throwsStateError,
      );
    });

    test(
      'ein gleiches Profil liefert denselben Helden, nichts zu speichern',
      () {
        final alt = globalesProfil();
        final held = krieger.copyWith(regelProfil: alt);
        expect(
          identical(uebernehmeRegelProfil(held, von: alt, auf: alt), held),
          isTrue,
        );
      },
    );

    test('die Erstübernahme setzt das Profil eines Helden ohne Profil', () {
      final profil = globalesProfil();
      final ergebnis = uebernehmeRegelProfil(krieger, von: null, auf: profil);
      expect(ergebnis.regelProfil, profil);
    });
  });

  group('setzeRegelProfilZurueck', () {
    test('entfernt das Profil auf dem frisch geladenen Helden', () {
      final profil = globalesProfil();
      final held = krieger.copyWith(regelProfil: profil);
      final ergebnis = setzeRegelProfilZurueck(held, von: profil);
      expect(ergebnis.regelProfil, isNull);
      expect(ergebnis.id, held.id);
      expect(held.regelProfil, profil);
      // Das JSON trägt den Schlüssel danach nicht mehr (Hash-Pins).
      expect(ergebnis.toJson().containsKey('regelProfil'), isFalse);
    });

    test('ein inzwischen geändertes Profil wird nie überschrieben', () {
      final alt = globalesProfil();
      final fremd = mitPaket(alt, 'test_fremd', const []);
      expect(
        () => setzeRegelProfilZurueck(
          krieger.copyWith(regelProfil: fremd),
          von: alt,
        ),
        throwsStateError,
      );
    });

    test('ohne Profil gibt es nichts zu speichern', () {
      expect(
        identical(
          setzeRegelProfilZurueck(krieger, von: globalesProfil()),
          krieger,
        ),
        isTrue,
      );
    });
  });
}
