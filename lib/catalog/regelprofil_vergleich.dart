/// Vergleich zweier Regelprofil-Auflösungen: die Updatevorschau (ARCH-04).
///
/// Rein, ohne Riverpod und ohne Held. Ein Held rechnet mit den Paketkopien
/// seines Profils, bis er ein Update bewusst übernimmt. Dieses Modul beantwortet,
/// was sich im wirksamen Katalog änderte, wenn das Profil auf den aktuellen
/// Paketstand gehoben würde: neue, entfernte und geänderte Einträge je
/// Katalogsektion, Einträge, die ein Paket ein- oder ausblendet
/// (`ruleMeta.sourceKey`), und Hinweise zu den Paketkopien. Was das für einen
/// bestimmten Helden heißt, rechnet `regelprofil_vorschau_rules.dart`.
///
/// Der Basiskatalog ist nicht eingefroren: beide Auflösungen laufen gegen
/// dieselben aktuellen Basisdaten, außer der Aufrufer reicht für die alte Seite
/// [erstelleRegelProfilVergleich] andere `vorherigeBasisDaten`.
library;

import 'package:dsa_heldenverwaltung/catalog/catalog_loader.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_runtime_data.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';
import 'package:dsa_heldenverwaltung/catalog/house_rule_catalog_resolver.dart';
import 'package:dsa_heldenverwaltung/catalog/house_rule_pack.dart';
import 'package:dsa_heldenverwaltung/catalog/regelprofil_aufloesung.dart';
import 'package:dsa_heldenverwaltung/domain/hero_regelprofil.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';

/// Art der Änderung eines Katalogeintrags.
enum EintragsAenderungsart {
  /// Der Eintrag gibt es nur im vorgeschlagenen Stand.
  neu,

  /// Der Eintrag entfällt im vorgeschlagenen Stand.
  entfernt,

  /// Der Eintrag bleibt, mindestens ein Feld ist anders.
  geaendert,
}

/// Ein geändertes Feld eines Katalogeintrags.
class FeldAenderung {
  /// Feld [pfad] (Punktschreibweise, Listen als Ganzes) mit beiden Werten.
  const FeldAenderung({
    required this.pfad,
    required this.vorher,
    required this.nachher,
    this.paketId = '',
  });

  /// Feldpfad wie in Hausregel-Patches, etwa `kosten` oder `ruleMeta.sourceKey`.
  final String pfad;

  /// Wert im bisherigen Stand; `null`, wenn das Feld fehlte.
  final Object? vorher;

  /// Wert im vorgeschlagenen Stand; `null`, wenn das Feld entfällt.
  final Object? nachher;

  /// Paket, das das Feld laut Herkunftsindex setzt; leer, wenn unbekannt.
  final String paketId;
}

/// Änderung an einem Katalogeintrag einer Sektion.
class EintragsAenderung {
  /// Bündelt Sektion, Eintrag und Änderungsart.
  const EintragsAenderung({
    required this.section,
    required this.id,
    required this.name,
    required this.art,
    this.felder = const <FeldAenderung>[],
  });

  /// Katalogsektion des Eintrags.
  final CatalogSectionId section;

  /// Stabile Eintrags-ID.
  final String id;

  /// Anzeigename (im vorgeschlagenen Stand, sonst im bisherigen).
  final String name;

  /// Neu, entfernt oder geändert.
  final EintragsAenderungsart art;

  /// Geänderte Felder; nur bei [EintragsAenderungsart.geaendert] belegt.
  final List<FeldAenderung> felder;
}

/// Ein Basiseintrag, den ein Paket im Vergleich ein- oder ausblendet.
class SperrAenderung {
  /// Bündelt Eintrag, Quelle und beide Sichtbarkeiten.
  const SperrAenderung({
    required this.section,
    required this.id,
    required this.name,
    required this.quelleVorher,
    required this.quelleNachher,
    required this.vorherSichtbar,
    required this.nachherSichtbar,
  });

  /// Katalogsektion des Eintrags.
  final CatalogSectionId section;

  /// Stabile Eintrags-ID.
  final String id;

  /// Anzeigename.
  final String name;

  /// `ruleMeta.sourceKey` im bisherigen Basiskatalog; leer ohne Angabe.
  final String quelleVorher;

  /// `ruleMeta.sourceKey` im vorgeschlagenen Basiskatalog.
  final String quelleNachher;

  /// Ob der Eintrag im bisherigen Stand sichtbar ist.
  final bool vorherSichtbar;

  /// Ob der Eintrag im vorgeschlagenen Stand sichtbar ist.
  final bool nachherSichtbar;
}

/// Art eines Hinweises zu einer Paketkopie im Profil.
enum PaketHinweisArt {
  /// Das Paket gibt es im aktuellen Paketkatalog nicht mehr.
  fehlt,

  /// Das aktuelle Paket weicht von der Kopie im Profil ab.
  aktualisiert,

  /// Die Kopie passt nicht zu ihrer gespeicherten Prüfsumme.
  kopieVeraendert,

  /// Die Kopie lässt sich nicht als Manifest lesen.
  unlesbar,
}

/// Hinweis zu einer Paketkopie im Profil.
class PaketHinweis {
  /// Hinweis der [art] zu [paketId] mit lesbarem [text].
  const PaketHinweis({
    required this.art,
    required this.paketId,
    required this.text,
  });

  /// Was mit der Kopie ist.
  final PaketHinweisArt art;

  /// Betroffenes Paket.
  final String paketId;

  /// Anzeigetext.
  final String text;
}

/// Ergebnis des Vergleichs zweier Auflösungen.
class RegelProfilVergleich {
  /// Bündelt beide Auflösungen und ihre Unterschiede.
  const RegelProfilVergleich({
    required this.altesProfil,
    required this.neuesProfil,
    required this.alt,
    required this.neu,
    required this.eintraege,
    required this.sperren,
    required this.hinweise,
  });

  /// Profil, nach dem der Held heute rechnet.
  final HeroRegelProfil altesProfil;

  /// Vorgeschlagenes Profil.
  final HeroRegelProfil neuesProfil;

  /// Auflösung des bisherigen Profils.
  final RegelProfilAufloesung alt;

  /// Auflösung des vorgeschlagenen Profils.
  final RegelProfilAufloesung neu;

  /// Geänderte Katalogeinträge, nach Sektion, ID und Art geordnet.
  final List<EintragsAenderung> eintraege;

  /// Durch Pakete ein- oder ausgeblendete Basiseinträge.
  final List<SperrAenderung> sperren;

  /// Hinweise zu den Paketkopien des bisherigen Profils.
  final List<PaketHinweis> hinweise;

  /// Ob das vorgeschlagene Profil vom bisherigen abweicht.
  bool get profilGeaendert => altesProfil != neuesProfil;

  /// Ob nichts zu übernehmen und nichts zu melden ist.
  bool get istLeer =>
      !profilGeaendert &&
      eintraege.isEmpty &&
      sperren.isEmpty &&
      hinweise.isEmpty;
}

/// Hinweise zu den Paketkopien von [profil] gegen den [aktuellerPaketKatalog].
///
/// Reihenfolge: Pakete des Profils, je Paket nach Art. Ein Paket ohne
/// Auffälligkeit erscheint nicht.
List<PaketHinweis> paketHinweise({
  required HeroRegelProfil profil,
  required HouseRulePackCatalog aktuellerPaketKatalog,
}) {
  final hinweise = <PaketHinweis>[];
  for (final paket in profil.pakete) {
    final aktuell = aktuellerPaketKatalog.find(paket.paketId);
    final titel = switch (paket.manifest['title']) {
      final String t when t.trim().isNotEmpty => t.trim(),
      _ => aktuell?.title ?? paket.paketId,
    };
    HouseRulePackManifest? kopie;
    try {
      kopie = HouseRulePackManifest.fromJson(
        Map<String, dynamic>.from(paket.manifest),
      );
    } on FormatException {
      kopie = null;
    }
    if (kopie == null) {
      hinweise.add(
        PaketHinweis(
          art: PaketHinweisArt.unlesbar,
          paketId: paket.paketId,
          text:
              'Die gespeicherte Kopie von „${paket.paketId}“ lässt sich '
              'nicht lesen und wird übersprungen.',
        ),
      );
    }
    if (stableContentHash(Map<String, Object?>.from(paket.manifest)) !=
        paket.pruefsumme) {
      hinweise.add(
        PaketHinweis(
          art: PaketHinweisArt.kopieVeraendert,
          paketId: paket.paketId,
          text:
              'Die gespeicherte Kopie von „$titel“ passt nicht zu ihrer '
              'Prüfsumme.',
        ),
      );
    }
    if (aktuell == null) {
      hinweise.add(
        PaketHinweis(
          art: PaketHinweisArt.fehlt,
          paketId: paket.paketId,
          text:
              'Das Paket „$titel“ gibt es in dieser App-Version nicht mehr. '
              'Der Held rechnet mit seiner gespeicherten Kopie weiter.',
        ),
      );
    } else if (pruefsummeDesPakets(aktuell) != paket.pruefsumme) {
      hinweise.add(
        PaketHinweis(
          art: PaketHinweisArt.aktualisiert,
          paketId: paket.paketId,
          text:
              'Das Paket „$titel“ hat sich geändert. Der Held rechnet noch '
              'mit der alten Fassung.',
        ),
      );
    }
  }
  return List<PaketHinweis>.unmodifiable(hinweise);
}

/// Vergleicht zwei bereits aufgelöste Profile.
///
/// [aktuellerPaketKatalog] liefert nur die Hinweise zu den Kopien des alten
/// Profils; die Einträge stammen aus den Auflösungen.
RegelProfilVergleich vergleicheAufloesungen({
  required HeroRegelProfil altesProfil,
  required HeroRegelProfil neuesProfil,
  required RegelProfilAufloesung alt,
  required RegelProfilAufloesung neu,
  required HouseRulePackCatalog aktuellerPaketKatalog,
}) {
  return RegelProfilVergleich(
    altesProfil: altesProfil,
    neuesProfil: neuesProfil,
    alt: alt,
    neu: neu,
    eintraege: List<EintragsAenderung>.unmodifiable(
      _vergleicheEintraege(alt, neu),
    ),
    sperren: List<SperrAenderung>.unmodifiable(_vergleicheSperren(alt, neu)),
    hinweise: paketHinweise(
      profil: altesProfil,
      aktuellerPaketKatalog: aktuellerPaketKatalog,
    ),
  );
}

/// Löst [profil] und den Vorschlag auf und vergleicht beide.
///
/// Ohne [vorgeschlagen] entsteht der Vorschlag über [schlageProfilVor]
/// (aktuelle Fassung aller Pakete des Profils, dazu [zusaetzlichePaketIds]).
/// [vorherigeBasisDaten] lassen die alte Seite gegen einen anderen
/// Basiskatalog rechnen; ohne Angabe rechnen beide gegen [basisDaten].
RegelProfilVergleich erstelleRegelProfilVergleich({
  required HeroRegelProfil profil,
  required CatalogSourceData basisDaten,
  required CustomCatalogSnapshot eigeneEintraege,
  required HouseRulePackCatalog aktuellerPaketKatalog,
  HeroRegelProfil? vorgeschlagen,
  Set<String> zusaetzlichePaketIds = const <String>{},
  CatalogSourceData? vorherigeBasisDaten,
  CatalogLoader loader = const CatalogLoader(),
}) {
  final neuesProfil =
      vorgeschlagen ??
      schlageProfilVor(
        profil: profil,
        aktuellerPaketKatalog: aktuellerPaketKatalog,
        catalogVersion: basisDaten.version,
        zusaetzlichePaketIds: zusaetzlichePaketIds,
      );
  final bekannt = <String>{for (final p in aktuellerPaketKatalog.packs) p.id};
  RegelProfilAufloesung loese(HeroRegelProfil p, CatalogSourceData daten) =>
      loeseRegelProfilAuf(
        basisDaten: daten,
        profil: p,
        eigeneEintraege: eigeneEintraege,
        bekanntePaketIds: bekannt,
        loader: loader,
      );
  return vergleicheAufloesungen(
    altesProfil: profil,
    neuesProfil: neuesProfil,
    alt: loese(profil, vorherigeBasisDaten ?? basisDaten),
    neu: loese(neuesProfil, basisDaten),
    aktuellerPaketKatalog: aktuellerPaketKatalog,
  );
}

Map<String, Map<String, dynamic>> _nachId(
  List<Map<String, dynamic>> eintraege,
) {
  final result = <String, Map<String, dynamic>>{};
  for (final eintrag in eintraege) {
    final id = (eintrag['id'] as String? ?? '').trim();
    if (id.isNotEmpty) {
      result[id] = eintrag;
    }
  }
  return result;
}

List<EintragsAenderung> _vergleicheEintraege(
  RegelProfilAufloesung alt,
  RegelProfilAufloesung neu,
) {
  final ergebnis = <EintragsAenderung>[];
  for (final section in editableCatalogSections) {
    final vorher = _nachId(alt.runtimeData.effectiveData.entriesFor(section));
    final nachher = _nachId(neu.runtimeData.effectiveData.entriesFor(section));
    final ids = <String>{...vorher.keys, ...nachher.keys}.toList()..sort();
    for (final id in ids) {
      final a = vorher[id];
      final n = nachher[id];
      if (a == null || n == null) {
        ergebnis.add(
          EintragsAenderung(
            section: section,
            id: id,
            name: catalogEntryDisplayName((n ?? a)!),
            art: a == null
                ? EintragsAenderungsart.neu
                : EintragsAenderungsart.entfernt,
          ),
        );
        continue;
      }
      final felder = <FeldAenderung>[];
      _vergleicheFelder('', a, n, felder);
      if (felder.isEmpty) {
        continue;
      }
      ergebnis.add(
        EintragsAenderung(
          section: section,
          id: id,
          name: catalogEntryDisplayName(n),
          art: EintragsAenderungsart.geaendert,
          felder: List<FeldAenderung>.unmodifiable([
            for (final feld in felder)
              FeldAenderung(
                pfad: feld.pfad,
                vorher: feld.vorher,
                nachher: feld.nachher,
                paketId:
                    _ursache(neu, section, id, feld.pfad) ??
                    _ursache(alt, section, id, feld.pfad) ??
                    '',
              ),
          ]),
        ),
      );
    }
  }
  return ergebnis;
}

// Paket, das laut Herkunftsindex das Feld oder ein umschließendes Feld setzt.
String? _ursache(
  RegelProfilAufloesung aufloesung,
  CatalogSectionId section,
  String id,
  String pfad,
) {
  final segmente = pfad.split('.');
  for (var laenge = segmente.length; laenge > 0; laenge--) {
    final herkunft = aufloesung.runtimeData.houseRuleProvenanceIndex
        .fieldProvenance(
          section: section,
          entryId: id,
          fieldPath: segmente.take(laenge).join('.'),
        );
    if (herkunft != null) {
      return herkunft.packId;
    }
  }
  return null;
}

void _vergleicheFelder(
  String pfad,
  Object? vorher,
  Object? nachher,
  List<FeldAenderung> ergebnis,
) {
  if (vorher is Map && nachher is Map) {
    final schluessel = <String>{
      ...vorher.keys.cast<String>(),
      ...nachher.keys.cast<String>(),
    }.toList()..sort();
    for (final key in schluessel) {
      _vergleicheFelder(
        pfad.isEmpty ? key : '$pfad.$key',
        vorher[key],
        nachher[key],
        ergebnis,
      );
    }
    return;
  }
  if (!_tiefGleich(vorher, nachher)) {
    ergebnis.add(FeldAenderung(pfad: pfad, vorher: vorher, nachher: nachher));
  }
}

bool _tiefGleich(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) {
      return false;
    }
    for (final key in a.keys) {
      if (!b.containsKey(key) || !_tiefGleich(a[key], b[key])) {
        return false;
      }
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (!_tiefGleich(a[i], b[i])) {
        return false;
      }
    }
    return true;
  }
  return a == b;
}

List<SperrAenderung> _vergleicheSperren(
  RegelProfilAufloesung alt,
  RegelProfilAufloesung neu,
) {
  final ergebnis = <SperrAenderung>[];
  for (final section in editableCatalogSections) {
    final vorher = _nachId(alt.runtimeData.baseData.entriesFor(section));
    final nachher = _nachId(neu.runtimeData.baseData.entriesFor(section));
    final ids = <String>{...vorher.keys, ...nachher.keys}.toList()..sort();
    for (final id in ids) {
      final a = vorher[id];
      final n = nachher[id];
      if (a == null || n == null) {
        continue;
      }
      final quelleVorher = liesQuellschluessel(a);
      final quelleNachher = liesQuellschluessel(n);
      if (quelleVorher.isEmpty && quelleNachher.isEmpty) {
        continue;
      }
      final vorherSichtbar = !istEintragDurchPaketGesperrt(
        entry: a,
        bekanntePaketIds: alt.bekanntePaketIds,
        aktivePaketIds: alt.aktivePaketIds,
      );
      final nachherSichtbar = !istEintragDurchPaketGesperrt(
        entry: n,
        bekanntePaketIds: neu.bekanntePaketIds,
        aktivePaketIds: neu.aktivePaketIds,
      );
      if (vorherSichtbar == nachherSichtbar) {
        continue;
      }
      ergebnis.add(
        SperrAenderung(
          section: section,
          id: id,
          name: catalogEntryDisplayName(n),
          quelleVorher: quelleVorher,
          quelleNachher: quelleNachher,
          vorherSichtbar: vorherSichtbar,
          nachherSichtbar: nachherSichtbar,
        ),
      );
    }
  }
  return ergebnis;
}
