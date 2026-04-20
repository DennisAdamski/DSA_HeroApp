import 'package:dsa_heldenverwaltung/catalog/catalog_json_helpers.dart';

/// Strukturierte Herkunfts- und Freischaltmetadaten eines Regeleintrags.
class RuleMeta {
  /// Erstellt Metadaten fuer einen katalogisierten Regeleintrag.
  const RuleMeta({
    this.origin = '',
    this.sourceKey = '',
    this.citations = const <RuleCitation>[],
    this.supersedesEntryId = '',
    this.epic,
  });

  /// Herkunftsschicht des Eintrags, z. B. `official` oder `house_rule`.
  final String origin;

  /// Stabiler Schluessel fuer die Quellgruppe oder das Harvest-Artefakt.
  final String sourceKey;

  /// Belege, aus denen der Eintrag oder die Aenderung abgeleitet wurde.
  final List<RuleCitation> citations;

  /// Referenz auf einen offiziell ueberschriebenen Basiseintrag.
  final String supersedesEntryId;

  /// Optionale Metadaten fuer episch freischaltbare Inhalte.
  final EpicRuleMeta? epic;

  /// Gibt an, ob der Eintrag aus einer Hausregel stammt.
  bool get isHouseRule => origin.trim() == 'house_rule';

  /// Deserialisiert die Metadaten tolerant aus JSON.
  factory RuleMeta.fromJson(Map<String, dynamic> json) {
    final rawCitations = readCatalogObjectList(json, 'citations');
    final rawEpic = readCatalogObject(json, 'epic');
    return RuleMeta(
      origin: readCatalogString(json, 'origin', fallback: ''),
      sourceKey: readCatalogString(json, 'sourceKey', fallback: ''),
      citations: rawCitations
          .map((entry) => RuleCitation.fromJson(entry))
          .toList(growable: false),
      supersedesEntryId: readCatalogString(
        json,
        'supersedesEntryId',
        fallback: '',
      ),
      epic: rawEpic == null ? null : EpicRuleMeta.fromJson(rawEpic),
    );
  }

  /// Serialisiert die Metadaten JSON-kompatibel.
  Map<String, dynamic> toJson() {
    return {
      if (origin.isNotEmpty) 'origin': origin,
      if (sourceKey.isNotEmpty) 'sourceKey': sourceKey,
      if (citations.isNotEmpty)
        'citations': citations
            .map((entry) => entry.toJson())
            .toList(growable: false),
      if (supersedesEntryId.isNotEmpty) 'supersedesEntryId': supersedesEntryId,
      if (epic != null) 'epic': epic!.toJson(),
    };
  }
}

/// Zitierbarer Beleg fuer eine Regelableitung oder Katalogaenderung.
class RuleCitation {
  /// Erstellt einen einzelnen Belegeintrag.
  const RuleCitation({this.source = '', this.locator = '', this.excerpt = ''});

  /// Menschlich lesbarer Quellname.
  final String source;

  /// Fundstelle, z. B. Seite, Abschnitt oder Abschnittsnummer.
  final String locator;

  /// Kurzer Auszug oder normalisierte Fundstelle.
  final String excerpt;

  /// Deserialisiert den Belegeintrag tolerant aus JSON.
  factory RuleCitation.fromJson(Map<String, dynamic> json) {
    return RuleCitation(
      source: readCatalogString(json, 'source', fallback: ''),
      locator: readCatalogString(json, 'locator', fallback: ''),
      excerpt: readCatalogString(json, 'excerpt', fallback: ''),
    );
  }

  /// Serialisiert den Belegeintrag JSON-kompatibel.
  Map<String, dynamic> toJson() {
    return {
      if (source.isNotEmpty) 'source': source,
      if (locator.isNotEmpty) 'locator': locator,
      if (excerpt.isNotEmpty) 'excerpt': excerpt,
    };
  }
}

/// Freischaltmetadaten fuer Inhalte, die einen epischen Status erfordern.
class EpicRuleMeta {
  /// Erstellt Metadaten fuer episch freischaltbare Eintraege.
  const EpicRuleMeta({this.requiresOptIn = false, this.eligibleFromLevel = 21});

  /// Ob der Eintrag einen separaten epischen Status voraussetzt.
  final bool requiresOptIn;

  /// Ab welchem Level die spaetere UI den epischen Prozess anbieten darf.
  final int eligibleFromLevel;

  /// Deserialisiert die Freischaltmetadaten tolerant aus JSON.
  factory EpicRuleMeta.fromJson(Map<String, dynamic> json) {
    return EpicRuleMeta(
      requiresOptIn: readCatalogBool(json, 'requiresOptIn', fallback: false),
      eligibleFromLevel: readCatalogInt(
        json,
        'eligibleFromLevel',
        fallback: 21,
      ),
    );
  }

  /// Serialisiert die Freischaltmetadaten JSON-kompatibel.
  Map<String, dynamic> toJson() {
    return {
      if (requiresOptIn) 'requiresOptIn': requiresOptIn,
      if (eligibleFromLevel != 21) 'eligibleFromLevel': eligibleFromLevel,
    };
  }
}
