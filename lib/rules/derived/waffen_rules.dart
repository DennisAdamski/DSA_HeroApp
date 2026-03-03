import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';

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

  final weaponToken = _normalizeToken(type);
  if (weaponToken.isEmpty) {
    return false;
  }

  final specs = talentEntry.combatSpecializations.isEmpty
      ? talentEntry.specializations.split(RegExp(r'[\n,;]+'))
      : talentEntry.combatSpecializations;
  for (final raw in specs) {
    final token = _normalizeToken(raw);
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
  return _normalizeToken(talent.type) == 'fernkampf';
}

// PA-Bonus durch Nebenhand (Schild, Parierdolch, Linkhand).
int computeOffhandPaBonus({
  required OffhandMode mode,
  required int basePaMod,
  required CombatSpecialRules special,
}) {
  switch (mode) {
    case OffhandMode.none:
      return 0;
    case OffhandMode.linkhand:
      return basePaMod + 1;
    case OffhandMode.shield:
      if (special.schildkampfII) {
        return basePaMod + 5;
      }
      if (special.schildkampfI) {
        return basePaMod + 3;
      }
      if (special.linkhandActive) {
        return basePaMod + 1;
      }
      return basePaMod;
    case OffhandMode.parryWeapon:
      if (special.parierwaffenII) {
        return basePaMod + 2;
      }
      if (special.parierwaffenI) {
        return basePaMod - 1;
      }
      if (special.linkhandActive) {
        return basePaMod - 4;
      }
      return basePaMod;
  }
}

String _normalizeToken(String raw) {
  var value = raw.trim().toLowerCase();
  value = value
      .replaceAll(String.fromCharCode(228), 'ae')
      .replaceAll(String.fromCharCode(246), 'oe')
      .replaceAll(String.fromCharCode(252), 'ue')
      .replaceAll(String.fromCharCode(223), 'ss');
  return value.replaceAll(RegExp(r'[^a-z0-9]+'), '');
}
