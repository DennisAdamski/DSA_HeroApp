import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';

class CombatTalentValidationIssue {
  const CombatTalentValidationIssue({
    required this.talentId,
    required this.message,
  });

  final String talentId;
  final String message;
}

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

List<CombatTalentValidationIssue> validateCombatTalentDistribution({
  required Iterable<TalentDef> talents,
  required Map<String, HeroTalentEntry> talentEntries,
  bool Function(TalentDef talent)? filter,
}) {
  final issues = <CombatTalentValidationIssue>[];
  final filtered = filter == null ? talents : talents.where(filter);
  for (final talent in filtered) {
    final entry = talentEntries[talent.id] ?? const HeroTalentEntry();
    final taw = entry.talentValue;
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
