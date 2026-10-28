import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_meta_talent.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/excel_rounding.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ruestung_be_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/talent_value_rules.dart';

/// Prueft, ob eine BE-Regel fuer ein Meta-Talent vom unterstuetzten Format ist.
bool isValidMetaTalentBeRule(String raw) {
  final compact = raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
  if (compact.isEmpty || compact == '-') {
    return true;
  }
  if (RegExp(r'^-\d+$').hasMatch(compact)) {
    return true;
  }
  return RegExp(r'^x\d+$').hasMatch(compact);
}

/// Validiert ein Meta-Talent gegen vorhandene Talent-IDs und Attribute.
List<String> validateHeroMetaTalent({
  required HeroMetaTalent metaTalent,
  required Set<String> allowedTalentIds,
}) {
  final issues = <String>[];
  if (metaTalent.name.trim().isEmpty) {
    issues.add('Name fehlt.');
  }
  if (metaTalent.componentTalentIds.length < 2) {
    issues.add('Mindestens zwei Bestandteile sind erforderlich.');
  }
  final unknownTalentIds = metaTalent.componentTalentIds
      .where((id) => !allowedTalentIds.contains(id))
      .toList(growable: false);
  if (unknownTalentIds.isNotEmpty) {
    issues.add('Unbekannte Talente: ${unknownTalentIds.join(', ')}.');
  }
  if (metaTalent.attributes.length != 3) {
    issues.add('Genau drei Eigenschaften sind erforderlich.');
  }
  final invalidAttributes = metaTalent.attributes
      .where((entry) => parseAttributeCode(entry) == null)
      .toList(growable: false);
  if (invalidAttributes.isNotEmpty) {
    issues.add('Ungueltige Eigenschaften: ${invalidAttributes.join(', ')}.');
  }
  if (!isValidMetaTalentBeRule(metaTalent.be)) {
    issues.add('BE-Regel ist ungueltig.');
  }
  return issues;
}

/// Liefert alle referenzierten Talent-IDs aus einer Meta-Talent-Liste.
Set<String> collectMetaTalentComponentIds(
  Iterable<HeroMetaTalent> metaTalents,
) {
  final ids = <String>{};
  for (final metaTalent in metaTalents) {
    ids.addAll(metaTalent.componentTalentIds);
  }
  return ids;
}

/// Aktiviert alle Talente, die von Meta-Talenten referenziert werden.
Map<String, HeroTalentEntry> activateReferencedMetaTalentComponents({
  required Map<String, HeroTalentEntry> talents,
  required Iterable<HeroMetaTalent> metaTalents,
}) {
  final normalized = Map<String, HeroTalentEntry>.from(talents);
  for (final talentId in collectMetaTalentComponentIds(metaTalents)) {
    normalized.putIfAbsent(talentId, () => const HeroTalentEntry());
  }
  return normalized;
}

/// Mittelwert und Deckel des Roh-TaW eines Meta-Talents.
///
/// Wege des Schwerts Anhang 3: Der Talentwert ist der kaufmaennisch gerundete
/// Mittelwert der Bestandteile, darf aber den doppelten Wert des niedrigsten
/// Bestandteils nicht uebersteigen.
({int mittelwert, int deckel, int wert, bool gedeckelt})
splitMetaTalentBaseTaw({
  required Map<String, HeroTalentEntry> talentEntries,
  required Iterable<String> componentTalentIds,
}) {
  var count = 0;
  var sum = 0;
  int? niedrigster;
  for (final talentId in componentTalentIds) {
    final wert = talentEntries[talentId]?.talentValue ?? 0;
    sum += wert;
    count++;
    if (niedrigster == null || wert < niedrigster) {
      niedrigster = wert;
    }
  }
  if (count == 0 || niedrigster == null) {
    return (mittelwert: 0, deckel: 0, wert: 0, gedeckelt: false);
  }
  final mittelwert = excelRound(sum / count);
  final deckel = 2 * niedrigster;
  final gedeckelt = deckel < mittelwert;
  return (
    mittelwert: mittelwert,
    deckel: deckel,
    wert: gedeckelt ? deckel : mittelwert,
    gedeckelt: gedeckelt,
  );
}

/// Berechnet den Roh-TaW eines Meta-Talents: kaufmaennisch gerundeter
/// Mittelwert, hoechstens das Doppelte des niedrigsten Bestandteils.
int computeMetaTalentBaseTaw({
  required Map<String, HeroTalentEntry> talentEntries,
  required Iterable<String> componentTalentIds,
}) {
  return splitMetaTalentBaseTaw(
    talentEntries: talentEntries,
    componentTalentIds: componentTalentIds,
  ).wert;
}

/// Berechnet den angezeigten TaW eines Meta-Talents inklusive eBE.
int computeMetaTalentComputedTaw({required int baseTaw, required int ebe}) {
  return computeTalentComputedTaw(talentValue: baseTaw, modifier: 0, ebe: ebe);
}

/// Berechnet die eBE eines Meta-Talents anhand seiner BE-Regel.
///
/// [reductionMultiplier] wird unveraendert an [computeTalentEbe]
/// durchgereicht, damit auch Meta-Talente von der epischen
/// KK-Haupteigenschaft profitieren.
int computeMetaTalentEbe({
  required int baseBe,
  required String beRule,
  double reductionMultiplier = 1.0,
}) {
  return computeTalentEbe(
    baseBe: baseBe,
    talentBeRule: beRule,
    reductionMultiplier: reductionMultiplier,
  );
}
