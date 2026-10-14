import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_runtime_data.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';
import 'package:dsa_heldenverwaltung/catalog/house_rule_catalog_resolver.dart';
import 'package:dsa_heldenverwaltung/catalog/house_rule_pack.dart';
import 'package:dsa_heldenverwaltung/catalog/regelprofil_aufloesung.dart';
import 'package:dsa_heldenverwaltung/catalog/regelprofil_vergleich.dart';
import 'package:dsa_heldenverwaltung/domain/hero_regelprofil.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';

import '../test_support/real_catalog.dart';

/// Updatevorschau eines Regelprofils gegen den echten Katalog (ARCH-04).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const talentPaket = 'regelwerk_ueberarbeitung_v1.talents_learning';
  const epicKampf = 'epic_rules_v1.combat_sf';

  late EchterKatalog katalog;

  setUpAll(() async {
    katalog = await ladeEchtenRegelkatalog();
  });

  HouseRulePackCatalog pakete() => katalog.runtimeData.packCatalog;

  HeroRegelProfil globalesProfil() => regelProfilAusGlobalemStand(
    catalogVersion: katalog.runtimeData.baseData.version,
    paketKatalog: pakete(),
    aktivePaketIds: katalog.runtimeData.activeHouseRulePackIds,
  );

  HeroRegelProfilPaket mitManifest(
    HeroRegelProfilPaket paket,
    Map<String, Object?> manifest,
  ) => HeroRegelProfilPaket(
    paketId: paket.paketId,
    pruefsumme: stableContentHash(manifest),
    manifest: manifest,
  );

  /// Profil, dessen Kopie von [paketId] ohne Patches gespeichert wurde, so
  /// wie sie eine ältere Paketfassung hinterlassen hätte (Prüfsumme passt).
  HeroRegelProfil veraltet(String paketId) {
    final profil = globalesProfil();
    return profil.copyWith(
      pakete: [
        for (final p in profil.pakete)
          if (p.paketId == paketId)
            mitManifest(p, <String, Object?>{
              ...p.manifest,
              'patches': <Object?>[],
            })
          else
            p,
      ],
    );
  }

  HeroRegelProfil ohnePaket(HeroRegelProfil profil, String paketId) =>
      profil.copyWith(
        pakete: [
          for (final p in profil.pakete)
            if (p.paketId != paketId) p,
        ],
      );

  RegelProfilVergleich vergleiche(
    HeroRegelProfil profil, {
    HeroRegelProfil? vorgeschlagen,
    Set<String> zusaetzlich = const <String>{},
    CatalogSourceData? vorherigeBasis,
  }) => erstelleRegelProfilVergleich(
    profil: profil,
    basisDaten: katalog.runtimeData.baseData,
    eigeneEintraege: katalog.runtimeData.customSnapshot,
    aktuellerPaketKatalog: pakete(),
    vorgeschlagen: vorgeschlagen,
    zusaetzlichePaketIds: zusaetzlich,
    vorherigeBasisDaten: vorherigeBasis,
  );

  String abbild(CatalogRuntimeData daten) => jsonEncode({
    for (final section in editableCatalogSections)
      section.name: daten.effectiveData.entriesFor(section),
  });

  String zusammenfassung(RegelProfilVergleich v) => jsonEncode({
    'profil': v.profilGeaendert,
    'eintraege': [
      for (final e in v.eintraege)
        [
          e.section.name,
          e.id,
          e.art.name,
          for (final f in e.felder) [f.pfad, f.vorher, f.nachher, f.paketId],
        ],
    ],
    'sperren': [
      for (final s in v.sperren)
        [
          s.section.name,
          s.id,
          s.quelleVorher,
          s.quelleNachher,
          s.vorherSichtbar,
          s.nachherSichtbar,
        ],
    ],
    'hinweise': [
      for (final h in v.hinweise) [h.art.name, h.paketId],
    ],
  });

  group('Unveränderter Stand', () {
    test('das Profil des globalen Stands ergibt einen leeren Vergleich', () {
      final vergleich = vergleiche(globalesProfil());
      expect(vergleich.eintraege, isEmpty);
      expect(vergleich.sperren, isEmpty);
      expect(vergleich.hinweise, isEmpty);
      expect(vergleich.profilGeaendert, isFalse);
      expect(vergleich.istLeer, isTrue);
    });

    test('der Vorschlag gleicht dem Profil', () {
      final profil = globalesProfil();
      final vorschlag = schlageProfilVor(
        profil: profil,
        aktuellerPaketKatalog: pakete(),
        catalogVersion: katalog.runtimeData.baseData.version,
      );
      expect(vorschlag, profil);
    });
  });

  group('Veraltete Paketkopie', () {
    test('der Vergleich zeigt Einträge, Felder und die Paketursache', () {
      final vergleich = vergleiche(veraltet(talentPaket));
      expect(vergleich.profilGeaendert, isTrue);
      expect(vergleich.eintraege, isNotEmpty);
      final geaendert = vergleich.eintraege.where(
        (e) => e.art == EintragsAenderungsart.geaendert,
      );
      expect(geaendert, isNotEmpty);
      for (final eintrag in geaendert) {
        expect(eintrag.felder, isNotEmpty);
        for (final feld in eintrag.felder) {
          expect(feld.vorher, isNot(equals(feld.nachher)));
        }
      }
      final ursachen = {
        for (final e in geaendert)
          for (final f in e.felder) f.paketId,
      };
      expect(ursachen, contains(talentPaket));
      expect(vergleich.hinweise.map((h) => (h.art, h.paketId)), [
        (PaketHinweisArt.aktualisiert, talentPaket),
      ]);
    });

    test('der Vorschlag rechnet wie der globale Stand', () {
      final vergleich = vergleiche(veraltet(talentPaket));
      expect(vergleich.neuesProfil, globalesProfil());
      expect(abbild(vergleich.neu.runtimeData), abbild(katalog.runtimeData));
      expect(
        abbild(vergleich.alt.runtimeData),
        isNot(abbild(katalog.runtimeData)),
      );
    });

    test('gleiche Eingaben liefern dasselbe Ergebnis', () {
      final a = zusammenfassung(vergleiche(veraltet(talentPaket)));
      final b = zusammenfassung(vergleiche(veraltet(talentPaket)));
      expect(a, b);
    });
  });

  group('schlageProfilVor', () {
    test('ein fehlendes Paket bleibt als Kopie erhalten', () {
      final profil = globalesProfil();
      final fremd = HeroRegelProfilPaket(
        paketId: 'altes_paket',
        pruefsumme: 'x',
        manifest: const <String, Object?>{
          'id': 'altes_paket',
          'title': 'Altes Paket',
          'patches': <Object?>[],
        },
      );
      final vorschlag = schlageProfilVor(
        profil: profil.copyWith(pakete: [...profil.pakete, fremd]),
        aktuellerPaketKatalog: pakete(),
        catalogVersion: profil.catalogVersion,
      );
      expect(vorschlag.pakete.last.paketId, 'altes_paket');
      expect(vorschlag.pakete.last.pruefsumme, 'x');
      expect(vorschlag.pakete.length, profil.pakete.length + 1);
    });

    test('neue Pakete kommen nur auf Wunsch hinzu', () {
      final profil = ohnePaket(globalesProfil(), epicKampf);
      final ohne = schlageProfilVor(
        profil: profil,
        aktuellerPaketKatalog: pakete(),
        catalogVersion: profil.catalogVersion,
      );
      expect(ohne.paketIds, isNot(contains(epicKampf)));
      final mit = schlageProfilVor(
        profil: profil,
        aktuellerPaketKatalog: pakete(),
        catalogVersion: profil.catalogVersion,
        zusaetzlichePaketIds: {epicKampf, 'gibt_es_nicht'},
      );
      expect(mit.paketIds, contains(epicKampf));
      expect(mit.paketIds, isNot(contains('gibt_es_nicht')));
      // Neue Pakete stehen am Ende der Liste.
      expect(mit.pakete.last.paketId, epicKampf);
      expect(mit.paketIds, globalesProfil().paketIds);
    });

    test('Felder einer neueren App-Version bleiben erhalten', () {
      final profil = globalesProfil().copyWith(
        unbekannteFelder: const <String, Object?>{'zukunft': 1},
      );
      final vorschlag = schlageProfilVor(
        profil: profil,
        aktuellerPaketKatalog: pakete(),
        catalogVersion: profil.catalogVersion,
      );
      expect(vorschlag.unbekannteFelder, {'zukunft': 1});
    });

    test('die Katalogversion folgt dem aktuellen Stand', () {
      final profil = globalesProfil().copyWith(
        catalogVersion: 'house_rules_v0',
      );
      final vorschlag = schlageProfilVor(
        profil: profil,
        aktuellerPaketKatalog: pakete(),
        catalogVersion: 'house_rules_v1',
      );
      expect(vorschlag.catalogVersion, 'house_rules_v1');
    });
  });

  group('Pakethinweise', () {
    List<(PaketHinweisArt, String)> arten(HeroRegelProfil profil) => [
      for (final h in paketHinweise(
        profil: profil,
        aktuellerPaketKatalog: pakete(),
      ))
        (h.art, h.paketId),
    ];

    test('Paket fehlt im aktuellen Katalog', () {
      final profil = globalesProfil();
      final manifest = <String, Object?>{
        'id': 'altes_paket',
        'title': 'Altes Paket',
        'patches': <Object?>[],
      };
      final fremd = HeroRegelProfilPaket(
        paketId: 'altes_paket',
        pruefsumme: stableContentHash(manifest),
        manifest: manifest,
      );
      final hinweise = paketHinweise(
        profil: profil.copyWith(pakete: [...profil.pakete, fremd]),
        aktuellerPaketKatalog: pakete(),
      );
      expect(hinweise.map((h) => (h.art, h.paketId)), [
        (PaketHinweisArt.fehlt, 'altes_paket'),
      ]);
      expect(hinweise.single.text, contains('Altes Paket'));
    });

    test('Prüfsumme der Kopie weicht vom aktuellen Paket ab', () {
      expect(arten(veraltet(talentPaket)), [
        (PaketHinweisArt.aktualisiert, talentPaket),
      ]);
    });

    test('Kopie passt nicht zu ihrer Prüfsumme', () {
      final profil = globalesProfil();
      final beschaedigt = profil.copyWith(
        pakete: [
          for (final p in profil.pakete)
            if (p.paketId == talentPaket)
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
      // Die gespeicherte Prüfsumme entspricht noch dem aktuellen Paket; nur
      // die Kopie selbst passt nicht mehr dazu.
      expect(arten(beschaedigt), [
        (PaketHinweisArt.kopieVeraendert, talentPaket),
      ]);
    });

    test('Kopie ist unlesbar', () {
      final profil = globalesProfil();
      final kaputt = profil.copyWith(
        pakete: [
          for (final p in profil.pakete)
            if (p.paketId == talentPaket)
              mitManifest(p, const <String, Object?>{'id': '', 'title': ''})
            else
              p,
        ],
      );
      final hinweise = arten(kaputt);
      expect(hinweise, contains((PaketHinweisArt.unlesbar, talentPaket)));
      expect(hinweise, contains((PaketHinweisArt.aktualisiert, talentPaket)));
    });
  });

  group('Sperrbedingungen von Paketen', () {
    test('ohne ihr Paket sind Einträge gesperrt, auch ohne Profilkopie', () {
      final profil = ohnePaket(globalesProfil(), epicKampf);
      final aufloesung = loeseRegelProfilAuf(
        basisDaten: katalog.runtimeData.baseData,
        profil: profil,
        eigeneEintraege: katalog.runtimeData.customSnapshot,
        bekanntePaketIds: {for (final p in pakete().packs) p.id},
      );
      final sichtbar = [
        for (final section in editableCatalogSections)
          for (final e in aufloesung.runtimeData.effectiveData.entriesFor(
            section,
          ))
            liesQuellschluessel(e),
      ];
      expect(sichtbar, isNot(contains(epicKampf)));
      expect(sichtbar, contains('epic_rules_v1.magic_sf'));
    });

    test('ohne die bekannten Pakete bliebe der Eintrag sichtbar', () {
      // Dokumentiert den Grund für `bekanntePaketIds`: Das Profil kennt nur
      // seine eigenen Pakete.
      final profil = ohnePaket(globalesProfil(), epicKampf);
      final aufloesung = loeseRegelProfilAuf(
        basisDaten: katalog.runtimeData.baseData,
        profil: profil,
        eigeneEintraege: katalog.runtimeData.customSnapshot,
      );
      final sichtbar = [
        for (final section in editableCatalogSections)
          for (final e in aufloesung.runtimeData.effectiveData.entriesFor(
            section,
          ))
            liesQuellschluessel(e),
      ];
      expect(sichtbar, contains(epicKampf));
    });

    test('der Vergleich nennt die ein- und ausgeblendeten Einträge', () {
      final profil = globalesProfil();
      final vergleich = vergleiche(
        profil,
        vorgeschlagen: ohnePaket(profil, epicKampf),
      );
      expect(vergleich.sperren, isNotEmpty);
      for (final sperre in vergleich.sperren) {
        expect(sperre.quelleVorher, epicKampf);
        expect(sperre.quelleNachher, epicKampf);
        expect(sperre.vorherSichtbar, isTrue);
        expect(sperre.nachherSichtbar, isFalse);
      }
      final entfernt = {
        for (final e in vergleich.eintraege)
          if (e.art == EintragsAenderungsart.entfernt) (e.section, e.id),
      };
      for (final sperre in vergleich.sperren) {
        expect(entfernt, contains((sperre.section, sperre.id)));
      }
      // Umgekehrt blendet das Hinzufügen des Pakets sie wieder ein.
      final zurueck = vergleiche(
        ohnePaket(profil, epicKampf),
        vorgeschlagen: profil,
      );
      expect(zurueck.sperren.length, vergleich.sperren.length);
      expect(zurueck.sperren.every((s) => s.nachherSichtbar), isTrue);
    });

    test('ein geänderter sourceKey im Basiskatalog sperrt den Eintrag', () {
      final profil = ohnePaket(globalesProfil(), epicKampf);
      final basis = katalog.runtimeData.baseData;
      final ziel = basis
          .entriesFor(CatalogSectionId.combatSpecialAbilities)
          .firstWhere((e) => liesQuellschluessel(e) == epicKampf);
      final zielId = ziel['id'] as String;
      // Vorheriger Basiskatalog: derselbe Eintrag ohne Paketbindung.
      Map<String, dynamic> ohneQuelle(Map<String, dynamic> e) {
        final kopie = jsonDecode(jsonEncode(e)) as Map<String, dynamic>;
        (kopie['ruleMeta'] as Map<String, dynamic>).remove('sourceKey');
        return kopie;
      }

      final vorher = CatalogSourceData(
        version: basis.version,
        source: basis.source,
        metadata: basis.metadata,
        sections: {
          for (final section in editableCatalogSections)
            section: [
              for (final e in basis.entriesFor(section))
                if (section == CatalogSectionId.combatSpecialAbilities &&
                    e['id'] == zielId)
                  ohneQuelle(e)
                else
                  e,
            ],
        },
        reisebericht: basis.reisebericht,
        catalogSaltV3: basis.catalogSaltV3,
      );
      final vergleich = vergleiche(
        profil,
        vorgeschlagen: profil,
        vorherigeBasis: vorher,
      );
      final sperre = vergleich.sperren.singleWhere((s) => s.id == zielId);
      expect(sperre.quelleVorher, '');
      expect(sperre.quelleNachher, epicKampf);
      expect(sperre.vorherSichtbar, isTrue);
      expect(sperre.nachherSichtbar, isFalse);
    });
  });
}
