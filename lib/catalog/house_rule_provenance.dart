import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';
import 'package:dsa_heldenverwaltung/catalog/talent_def.dart';
import 'package:dsa_heldenverwaltung/rules/derived/learning_rules.dart';

/// Herkunftsinformation fuer ein einzelnes durch Hausregeln geaendertes Feld.
class HouseRuleFieldProvenance {
  /// Erstellt eine unveraenderliche Provenienzbeschreibung.
  const HouseRuleFieldProvenance({
    required this.section,
    required this.entryId,
    required this.fieldPath,
    required this.baseValue,
    required this.effectiveValue,
    required this.packId,
    required this.packTitle,
  });

  /// Betroffene Katalogsektion.
  final CatalogSectionId section;

  /// Betroffene Eintrags-ID.
  final String entryId;

  /// Betroffener verschachtelter Feldpfad.
  final String fieldPath;

  /// Urspruenglicher Basiswert vor allen Hausregeln.
  final Object? baseValue;

  /// Wirksamer Wert nach allen Hausregeln.
  final Object? effectiveValue;

  /// Paket-ID der gewinnenden Aenderung.
  final String packId;

  /// Anzeigename des gewinnenden Pakets.
  final String packTitle;
}

/// Index aller bekannten Feld-Provenienzen fuer den Laufzeitkatalog.
class HouseRuleProvenanceIndex {
  /// Erstellt einen unveraenderlichen Provenienzindex.
  const HouseRuleProvenanceIndex({
    this.entries = const <String, HouseRuleFieldProvenance>{},
  });

  /// Interne Indexstruktur.
  final Map<String, HouseRuleFieldProvenance> entries;

  /// Liefert die Provenienz eines Feldes oder `null`, wenn unveraendert.
  HouseRuleFieldProvenance? fieldProvenance({
    required CatalogSectionId section,
    required String entryId,
    required String fieldPath,
  }) {
    return entries[_fieldKey(
      section: section,
      entryId: entryId,
      fieldPath: fieldPath,
    )];
  }

  /// Gibt an, ob der Index keinerlei Provenienz enthaelt.
  bool get isEmpty => entries.isEmpty;

  static String fieldKey({
    required CatalogSectionId section,
    required String entryId,
    required String fieldPath,
  }) {
    return _fieldKey(section: section, entryId: entryId, fieldPath: fieldPath);
  }
}

/// Aufgeloeste Komplexitaetsinformationen fuer ein Talent.
class TalentComplexityResolution {
  /// Erstellt eine strukturierte Komplexitaetsaufloesung.
  const TalentComplexityResolution({
    required this.baseKomplexitaet,
    required this.houseRuleKomplexitaet,
    required this.effectiveKomplexitaet,
    required this.gifted,
    this.packId = '',
    this.packTitle = '',
  });

  /// Offizielle Basiskomplexitaet ohne Hausregeln.
  final String baseKomplexitaet;

  /// Wirksame Basiskomplexitaet nach Hausregel-Patches, vor Begabung.
  final String houseRuleKomplexitaet;

  /// Endgueltige Komplexitaet nach Hausregel und Begabung.
  final String effectiveKomplexitaet;

  /// Ob Begabung den Wert weiter reduziert.
  final bool gifted;

  /// Paket-ID der wirksamen Ueberschreibung.
  final String packId;

  /// Anzeigename des wirksamen Pakets.
  final String packTitle;

  /// Ob eine Hausregel die Basiskomplexitaet ueberschreibt.
  bool get isOverridden =>
      packId.isNotEmpty && baseKomplexitaet != houseRuleKomplexitaet;

  /// Kurzer UI-Hinweis fuer Tabellen und Dialoge.
  String? get houseRuleHint {
    if (!isOverridden) {
      return null;
    }
    return 'Basis: $baseKomplexitaet • Hausregel: $packTitle';
  }
}

/// Kleine Hilfsschicht fuer konsumierende UIs und Regelfunktionen.
class CatalogRuleResolver {
  /// Erstellt einen Resolver ueber einem Provenienzindex.
  const CatalogRuleResolver({
    this.provenanceIndex = const HouseRuleProvenanceIndex(),
  });

  /// Alle bekannten Feld-Provenienzen.
  final HouseRuleProvenanceIndex provenanceIndex;

  /// Loest die wirksame Komplexitaet eines Talents inklusive Begabung auf.
  TalentComplexityResolution resolveTalentComplexity({
    required TalentDef talent,
    required bool gifted,
  }) {
    final section = talent.group.trim() == 'Kampftalent'
        ? CatalogSectionId.combatTalents
        : CatalogSectionId.talents;
    final provenance = provenanceIndex.fieldProvenance(
      section: section,
      entryId: talent.id,
      fieldPath: 'steigerung',
    );
    final baseKomplexitaet = _coerceString(
      provenance?.baseValue,
      fallback: talent.steigerung,
    );
    final houseRuleKomplexitaet = _coerceString(
      provenance?.effectiveValue,
      fallback: talent.steigerung,
    );
    return TalentComplexityResolution(
      baseKomplexitaet: baseKomplexitaet,
      houseRuleKomplexitaet: houseRuleKomplexitaet,
      effectiveKomplexitaet: effectiveTalentLernkomplexitaet(
        basisKomplexitaet: houseRuleKomplexitaet,
        gifted: gifted,
      ),
      gifted: gifted,
      packId: provenance?.packId ?? '',
      packTitle: provenance?.packTitle ?? '',
    );
  }

  /// Liefert die rohe Feld-Provenienz fuer eine Talent-Komplexitaet.
  HouseRuleFieldProvenance? talentComplexityProvenance(TalentDef talent) {
    final section = talent.group.trim() == 'Kampftalent'
        ? CatalogSectionId.combatTalents
        : CatalogSectionId.talents;
    return provenanceIndex.fieldProvenance(
      section: section,
      entryId: talent.id,
      fieldPath: 'steigerung',
    );
  }
}

String _fieldKey({
  required CatalogSectionId section,
  required String entryId,
  required String fieldPath,
}) {
  return '${section.name}::$entryId::$fieldPath';
}

String _coerceString(Object? value, {required String fallback}) {
  final candidate = value?.toString().trim() ?? '';
  if (candidate.isEmpty) {
    return fallback;
  }
  return candidate;
}
