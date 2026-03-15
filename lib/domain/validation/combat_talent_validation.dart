import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';

/// Beschreibt ein Validierungsproblem bei der AT/PA-Verteilung eines Kampftalents.
///
/// Wird von [validateCombatTalentDistribution] zurueckgegeben und in der UI
/// als Warnhinweis dargestellt.
class CombatTalentValidationIssue {
  const CombatTalentValidationIssue({
    required this.talentId,
    required this.message,
  });

  final String talentId; // ID des betroffenen Talents
  final String message;  // Beschreibung des Problems (auf Deutsch)
}

/// Prueft, ob eine [TalentDef] ein Kampftalent ist.
///
/// Drei Erkennungsmerkmale werden als OR-Verknuepfung geprueft:
///   1. group == 'Kampftalent' (primaeres Klassifizierungsmerkmal im Katalog)
///   2. weaponCategory ist nicht leer (Waffe hat eine Kategorie)
///   3. type ist 'nahkampf' oder 'fernkampf'
/// Das erlaubt auch Katalogdaten zu erkennen, die nur eines der drei
/// Felder korrekt befuellen.
bool isCombatTalentDef(TalentDef talent) {
  if (talent.group.trim().toLowerCase() == 'kampftalent') {
    return true;
  }
  if (talent.weaponCategory.trim().isNotEmpty) {
    return true;
  }
  final type = talent.type.trim().toLowerCase();
  return type == 'nahkampf' || type == 'fernkampf';
}

/// Bereinigt eine Liste von Talent-IDs: trimmt Leerzeichen, entfernt
/// Leerstrings und Duplikate. Gibt ein unveraenderliches Set zurueck.
Set<String> normalizeHiddenTalentIds(Iterable<String> hiddenTalentIds) {
  final normalized = <String>{};
  for (final id in hiddenTalentIds) {
    final trimmed = id.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    normalized.add(trimmed);
  }
  return normalized;
}

/// Validiert die AT/PA-Verteilung aller Kampftalente eines Helden.
///
/// DSA-Regel: Der Talentwert (TaW) wird auf AT und PA aufgeteilt.
///   - Alle Werte muessen >= 0 sein.
///   - Bei TaW = 0: AT und PA muessen ebenfalls 0 sein.
///   - Nahkampf: AT + PA muss genau TaW ergeben.
///   - Fernkampf: AT = TaW, PA = 0 (kein Paradewert moeglich).
///   - Sonstige Typen (z. B. Gaben): werden als Fehler gemeldet.
///
/// [filter] erlaubt, nur eine Teilmenge der Talente zu pruefen.
/// Gibt eine (moeglicherweise leere) Liste von Problemen zurueck.
List<CombatTalentValidationIssue> validateCombatTalentDistribution({
  required Iterable<TalentDef> talents,
  required Map<String, HeroTalentEntry> talentEntries,
  bool Function(TalentDef talent)? filter,
}) {
  final issues = <CombatTalentValidationIssue>[];
  final filtered = filter == null ? talents : talents.where(filter);
  for (final talent in filtered) {
    final entry = talentEntries[talent.id] ?? const HeroTalentEntry();
    final taw = entry.talentValue ?? 0;
    final at = entry.atValue;
    final pa = entry.paValue;
    final type = talent.type.trim().toLowerCase();

    if (taw < 0 || at < 0 || pa < 0) {
      issues.add(
        CombatTalentValidationIssue(
          talentId: talent.id,
          message:
              'Ungueltige Verteilung bei ${talent.name}: TaW, AT und PA muessen >= 0 sein.',
        ),
      );
      continue;
    }

    if (taw == 0) {
      if (at != 0 || pa != 0) {
        issues.add(
          CombatTalentValidationIssue(
            talentId: talent.id,
            message:
                'Ungueltige Verteilung bei ${talent.name}: Bei TaW 0 muessen AT und PA ebenfalls 0 sein.',
          ),
        );
      }
      continue;
    }

    if (type == 'nahkampf') {
      if (at + pa != taw) {
        issues.add(
          CombatTalentValidationIssue(
            talentId: talent.id,
            message:
                'Ungueltige Verteilung bei ${talent.name}: Bei Nahkampf muss AT + PA = TaW gelten.',
          ),
        );
      }
      continue;
    }

    if (type == 'fernkampf') {
      if (at != taw || pa != 0) {
        issues.add(
          CombatTalentValidationIssue(
            talentId: talent.id,
            message:
                'Ungueltige Verteilung bei ${talent.name}: Bei Fernkampf muss AT = TaW und PA = 0 sein.',
          ),
        );
      }
      continue;
    }

    issues.add(
      CombatTalentValidationIssue(
        talentId: talent.id,
        message:
            'Ungueltiger Talenttyp bei ${talent.name}: "${talent.type}" ist weder Nahkampf noch Fernkampf.',
      ),
    );
  }
  return issues;
}
