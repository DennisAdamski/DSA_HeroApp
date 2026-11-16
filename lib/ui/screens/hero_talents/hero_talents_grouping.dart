part of 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';

extension _HeroTalentsGrouping on _HeroTalentTableTabState {
  /// Kampftalente gehören in den Kampf-Tab (Kampftechniken).
  bool _matchesScope(TalentDef talent) => !isCombatTalentDef(talent);

  String _groupName(TalentDef talent) {
    final group = talent.group.trim();
    if (group.isEmpty) {
      return 'Ohne Gruppe';
    }
    return group;
  }

  int _groupPriority(String group) {
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
    return _normalizeStringList(raw.split(RegExp(r'[\n,;]+')));
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
