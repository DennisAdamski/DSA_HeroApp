import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/string_normalize.dart';

// KK-Schadensbonus: truncate((KK - kkBase) / kkThreshold).
int computeTpKk({
  required int kk,
  required int kkBase,
  required int kkThreshold,
}) {
  final threshold = kkThreshold < 1 ? 1 : kkThreshold;
  return (kk - kkBase) ~/ threshold;
}

// TP-Ausdruck als Wuerfelformel (z. B. "2W6+3").
String buildTpExpression(MainWeaponSlot main, int tpCalc) {
  final count = main.tpDiceCount < 1 ? 1 : main.tpDiceCount;
  if (tpCalc == 0) {
    return '${count}W6';
  }
  final sign = tpCalc > 0 ? '+' : '';
  return '${count}W6$sign$tpCalc';
}

// Prueft ob eine Waffenspezialisierung fuer den gewaehlten Waffentyp vorliegt.
bool hasCombatSpecialization({
  required Map<String, HeroTalentEntry> talents,
  required String talentId,
  required String weaponType,
}) {
  final id = talentId.trim();
  final type = weaponType.trim();
  if (id.isEmpty || type.isEmpty) {
    return false;
  }

  final talentEntry = talents[id];
  if (talentEntry == null) {
    return false;
  }

  final weaponToken = normalizeCombatToken(type);
  if (weaponToken.isEmpty) {
    return false;
  }

  final specs = talentEntry.combatSpecializations.isEmpty
      ? talentEntry.specializations.split(RegExp(r'[\n,;]+'))
      : talentEntry.combatSpecializations;
  for (final raw in specs) {
    final token = normalizeCombatToken(raw);
    if (token.isEmpty) {
      continue;
    }
    if (token == weaponToken) {
      return true;
    }
  }

  return false;
}

// Prueft ob ein Katalogtalent ein Fernkampftalent ist.
bool isRangedCombatTalent(TalentDef? talent) {
  if (talent == null) {
    return false;
  }
  return talent.istFernkampf;
}
