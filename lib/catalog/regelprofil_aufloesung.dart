/// Auflösung eines Helden-Regelprofils zu einem Regelkatalog (ARCH-04).
///
/// Rein, ohne Riverpod: aus den entschlüsselten Basisdaten, den Paketkopien des
/// Profils und den eigenen Katalogeinträgen entsteht derselbe Katalog, den
/// `rulesCatalogProvider` für den globalen Stand baut – nur mit den Paketen des
/// Helden. Der Basiskatalog bleibt der aktuelle (nicht eingefroren).
library;

import 'package:dsa_heldenverwaltung/catalog/catalog_loader.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_runtime_data.dart';
import 'package:dsa_heldenverwaltung/catalog/house_rule_catalog_resolver.dart';
import 'package:dsa_heldenverwaltung/catalog/house_rule_pack.dart';
import 'package:dsa_heldenverwaltung/catalog/house_rule_provenance.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_regelprofil.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';

/// Stempelt ein Paketmanifest als Profileintrag (Kopie samt Prüfsumme).
HeroRegelProfilPaket stempelRegelprofilPaket(HouseRulePackManifest manifest) {
  final json = Map<String, Object?>.from(manifest.toJson());
  return HeroRegelProfilPaket(
    paketId: manifest.id,
    pruefsumme: stableContentHash(json),
    manifest: json,
  );
}

/// Prüfsumme der aktuellen Fassung eines Pakets, vergleichbar mit
/// [HeroRegelProfilPaket.pruefsumme].
String pruefsummeDesPakets(HouseRulePackManifest manifest) =>
    stableContentHash(Map<String, Object?>.from(manifest.toJson()));

/// Profil aus den **aktiven** Paketen des globalen Stands.
///
/// So übernimmt ein Bestandsheld bei der Migration den Regelsatz, nach dem er
/// bisher gerechnet hat. Reihenfolge und Inhalt folgen [paketKatalog].
HeroRegelProfil regelProfilAusGlobalemStand({
  required String catalogVersion,
  required HouseRulePackCatalog paketKatalog,
  required Set<String> aktivePaketIds,
}) {
  return HeroRegelProfil(
    catalogVersion: catalogVersion,
    pakete: <HeroRegelProfilPaket>[
      for (final paket in paketKatalog.packs)
        if (aktivePaketIds.contains(paket.id)) stempelRegelprofilPaket(paket),
    ],
  );
}

/// Vorgeschlagenes Profil für ein Update (ARCH-04): die Pakete des Helden
/// auf dem aktuellen Stand von [aktuellerPaketKatalog].
///
/// Jedes Profilpaket wird aus dem aktuellen Paket neu gestempelt. Fehlt das
/// Paket im aktuellen Katalog oder ist seine Kopie unlesbar und kein aktuelles
/// Paket da, bleibt die Kopie unverändert (der Held rechnet aus ihr weiter).
/// Pakete, die erst eine neuere App-Version mitbringt, kommen nie von selbst
/// hinzu; wer sie will, nennt sie in [zusaetzlichePaketIds] (unbekannte IDs
/// werden übergangen). Felder einer neueren App-Version bleiben erhalten.
HeroRegelProfil schlageProfilVor({
  required HeroRegelProfil profil,
  required HouseRulePackCatalog aktuellerPaketKatalog,
  required String catalogVersion,
  Set<String> zusaetzlichePaketIds = const <String>{},
}) {
  final pakete = <HeroRegelProfilPaket>[
    for (final paket in profil.pakete)
      switch (aktuellerPaketKatalog.find(paket.paketId)) {
        final aktuell? => stempelRegelprofilPaket(aktuell),
        null => paket,
      },
  ];
  final vorhanden = profil.paketIds;
  for (final id in zusaetzlichePaketIds) {
    final aktuell = aktuellerPaketKatalog.find(id);
    if (aktuell != null && !vorhanden.contains(aktuell.id)) {
      pakete.add(stempelRegelprofilPaket(aktuell));
    }
  }
  return profil.copyWith(catalogVersion: catalogVersion, pakete: pakete);
}

/// Pakete des [aktuellerPaketKatalog], die [profil] noch nicht enthält und die
/// der Nutzer in der Updatevorschau zusätzlich wählen kann (nach Titel
/// sortiert).
List<HouseRulePackManifest> zusatzPaketKandidaten({
  required HeroRegelProfil profil,
  required HouseRulePackCatalog aktuellerPaketKatalog,
}) {
  final vorhanden = profil.paketIds;
  final kandidaten = <HouseRulePackManifest>[
    for (final paket in aktuellerPaketKatalog.packs)
      if (!vorhanden.contains(paket.id)) paket,
  ]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return List<HouseRulePackManifest>.unmodifiable(kandidaten);
}

/// Ergänzt [gewaehlt] um die Elternpakete, die weder im [profil] stehen noch
/// schon gewählt sind: Ein Unterpaket wirkt nur, wenn sein Elternpaket aktiv
/// ist. Unbekannte IDs bleiben unverändert (`schlageProfilVor` übergeht sie).
Set<String> zusatzPaketeMitElternpaketen({
  required Set<String> gewaehlt,
  required HeroRegelProfil profil,
  required HouseRulePackCatalog aktuellerPaketKatalog,
}) {
  final ergebnis = <String>{...gewaehlt};
  final vorhanden = profil.paketIds;
  for (final id in gewaehlt) {
    var paket = aktuellerPaketKatalog.find(id);
    final besucht = <String>{};
    while (paket != null && !paket.isRoot && besucht.add(paket.id)) {
      final elternId = paket.parentPackId.trim();
      if (!vorhanden.contains(elternId)) {
        ergebnis.add(elternId);
      }
      paket = aktuellerPaketKatalog.find(elternId);
    }
  }
  return ergebnis;
}

/// Entfernt [paketId] aus [gewaehlt] samt aller gewählten Unterpakete, die
/// ohne es nicht wirken würden.
Set<String> zusatzPaketAbwaehlen({
  required Set<String> gewaehlt,
  required String paketId,
  required HouseRulePackCatalog aktuellerPaketKatalog,
}) {
  bool haengtAn(String id) {
    final besucht = <String>{};
    var paket = aktuellerPaketKatalog.find(id);
    while (paket != null && !paket.isRoot && besucht.add(paket.id)) {
      final elternId = paket.parentPackId.trim();
      if (elternId == paketId) return true;
      paket = aktuellerPaketKatalog.find(elternId);
    }
    return false;
  }

  return <String>{
    for (final id in gewaehlt)
      if (id != paketId && !haengtAn(id)) id,
  };
}

/// Paketkatalog, der nur aus den Kopien des Profils besteht.
///
/// Kopien, die sich nicht als Manifest lesen lassen, fehlen im Ergebnis und
/// stehen in `issues`.
HouseRulePackCatalog paketKatalogAusProfil(HeroRegelProfil profil) {
  final packs = <HouseRulePackManifest>[];
  final issues = <HouseRulePackIssue>[];
  for (final paket in profil.pakete) {
    try {
      packs.add(
        HouseRulePackManifest.fromJson(
          Map<String, dynamic>.from(paket.manifest),
        ),
      );
    } on FormatException catch (e) {
      issues.add(
        HouseRulePackIssue(
          packId: paket.paketId,
          message: 'Paketkopie im Regelprofil unlesbar: ${e.message}',
        ),
      );
    }
  }
  return HouseRulePackCatalog(packs: packs, issues: issues);
}

/// Ergebnis der Profilauflösung.
class RegelProfilAufloesung {
  /// Bündelt Katalog, wirksame Pakete und Hinweise.
  const RegelProfilAufloesung({
    required this.katalog,
    required this.runtimeData,
    required this.aktivePaketIds,
    required this.bekanntePaketIds,
    required this.hinweise,
  });

  /// Regelkatalog mit den Paketen des Profils.
  final RulesCatalog katalog;

  /// Aufgelöste Katalogdaten (Provenienz, Probleme).
  final CatalogRuntimeData runtimeData;

  /// Pakete, die für den Helden wirken.
  final Set<String> aktivePaketIds;

  /// Pakete, deren Sperrbedingung (`ruleMeta.sourceKey`) galt: die Pakete des
  /// Profils und alle, die die App kennt.
  final Set<String> bekanntePaketIds;

  /// Probleme der Paketkopien und des Resolvers.
  final List<HouseRulePackIssue> hinweise;
}

/// Löst [profil] gegen die [basisDaten] auf.
///
/// [eigeneEintraege] sind die eigenen Katalogeinträge des Nutzers; sie sind
/// kein Paket und gelten für jeden Helden.
///
/// [bekanntePaketIds] sind die Pakete, die die App kennt. Ihre Einträge sind
/// gesperrt, solange das Profil das Paket nicht nennt; ohne Angabe gelten nur
/// die Pakete des Profils als bekannt.
RegelProfilAufloesung loeseRegelProfilAuf({
  required CatalogSourceData basisDaten,
  required HeroRegelProfil profil,
  required CustomCatalogSnapshot eigeneEintraege,
  Set<String> bekanntePaketIds = const <String>{},
  CatalogLoader loader = const CatalogLoader(),
}) {
  final paketKatalog = paketKatalogAusProfil(profil);
  // Das Profil nennt die aktiven Pakete; die Elternkette gilt weiter.
  final aktiv = paketKatalog.resolveActivePackIds(const <String>{});
  final bekannt = Set<String>.unmodifiable(<String>{
    for (final paket in profil.pakete) paket.paketId,
    ...bekanntePaketIds,
  });
  final ergebnis = HouseRuleCatalogResolver.resolve(
    baseData: basisDaten,
    packCatalog: paketKatalog,
    activePackIds: aktiv,
    bekanntePaketIds: bekannt,
  );
  final runtimeData = CatalogRuntimeData.resolve(
    baseData: basisDaten,
    resolvedBaseData: ergebnis.resolvedBaseData,
    customSnapshot: eigeneEintraege,
    packCatalog: paketKatalog,
    activeHouseRulePackIds: aktiv,
    houseRuleProvenanceIndex: ergebnis.provenanceIndex,
    houseRuleIssues: ergebnis.issues,
  );
  final katalog = loader.buildCatalogFromSourceData(
    runtimeData.effectiveData,
    ruleResolver: CatalogRuleResolver(
      provenanceIndex: runtimeData.houseRuleProvenanceIndex,
    ),
  );
  return RegelProfilAufloesung(
    katalog: katalog,
    runtimeData: runtimeData,
    aktivePaketIds: aktiv,
    bekanntePaketIds: bekannt,
    hinweise: List<HouseRulePackIssue>.unmodifiable(<HouseRulePackIssue>[
      ...paketKatalog.issues,
      ...ergebnis.issues,
    ]),
  );
}
