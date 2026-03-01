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
      final normalized = _normalizeGroupToken(group);
      if (normalized == 'nahkampf') {
        return 0;
      }
      if (normalized == 'fernkampf') {
        return 1;
      }
      return 99;
    }
    final normalized = _normalizeGroupToken(group);
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

  String _normalizeGroupToken(String raw) {
    var text = raw.toLowerCase().trim();
    text = text
        .replaceAll(String.fromCharCode(228), 'ae')
        .replaceAll(String.fromCharCode(246), 'oe')
        .replaceAll(String.fromCharCode(252), 'ue')
        .replaceAll(String.fromCharCode(223), 'ss');
    return text.replaceAll(RegExp(r'[^a-z]'), '');
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
    return _normalizeStringList(raw.split(RegExp(r'[\n,;]+')));
  }

  List<String> _weaponCategoryOptions(TalentDef talent) {
    return _normalizeStringList(
      talent.weaponCategory.split(RegExp(r'[\n,;]+')),
    );
  }

  List<String> _normalizeStringList(Iterable<String> values) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || seen.contains(trimmed)) {
        continue;
      }
      seen.add(trimmed);
      normalized.add(trimmed);
    }
    return List<String>.unmodifiable(normalized);
  }
}
