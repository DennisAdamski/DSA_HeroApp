part of 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';

extension _HeroTalentsGrouping on _HeroTalentTableTabState {
  bool _matchesScope(TalentDef talent) {
    final combat = isCombatTalentDef(talent);
    return widget.scope == _TalentTabScope.combat ? combat : !combat;
  }

  String _groupName(TalentDef talent) {
    if (widget.scope == _TalentTabScope.combat) {
      final type = talent.type.trim();
      if (type.isEmpty) {
        return 'Kampf (ohne Typ)';
      }
      return type;
    }
    final group = talent.group.trim();
    if (group.isEmpty) {
      return 'Ohne Gruppe';
    }
    return group;
  }

  int _groupPriority(String group) {
    if (widget.scope == _TalentTabScope.combat) {
      final normalized = normalizeCombatToken(group);
      if (normalized == 'nahkampf') {
        return 0;
      }
      if (normalized == 'fernkampf') {
        return 1;
      }
      return 99;
    }
    final normalized = normalizeCombatToken(group);
    if (normalized == 'koerperlichetalente' ||
        normalized == 'korperlichetalente') {
      return 0;
    }
    if (normalized == 'gesellschaftlichetalente') {
      return 1;
    }
    if (normalized == 'naturtalente') {
      return 2;
    }
    if (normalized == 'wissenstalente') {
      return 3;
    }
    if (normalized == 'handwerklichetalente') {
      return 4;
    }
    return 99;
  }

  Map<String, List<TalentDef>> _groupTalents(List<TalentDef> talents) {
    final grouped = <String, List<TalentDef>>{};
    for (final talent in talents) {
      final group = _groupName(talent);
      grouped.putIfAbsent(group, () => <TalentDef>[]).add(talent);
    }
    return grouped;
  }

  List<String> _splitSpecializationTokens(String raw) {
    return normalizeStringList(raw.split(RegExp(r'[\n,;]+')));
  }

  List<String> _weaponCategoryOptions(TalentDef talent) {
    return normalizeStringList(talent.weaponCategory.split(RegExp(r'[\n,;]+')));
  }
}
