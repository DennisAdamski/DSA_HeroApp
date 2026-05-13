import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';

/// Ergebnis einer erkannten benannten Standard-Modifikatorregel.
class StandardStatModifierMatch {
  /// Erstellt ein Parser-Ergebnis fuer einen benannten Vor- oder Nachteil.
  const StandardStatModifierMatch({
    required this.statMods,
    required this.hasAmount,
  });

  /// Der aus dem Namen und Zahlenwert abgeleitete Stat-Modifikator.
  final StatModifiers statMods;

  /// Zeigt, ob der Fragmenttext einen verwertbaren Zahlenwert enthielt.
  final bool hasAmount;
}

class _StandardStatModifierRule {
  const _StandardStatModifierRule({
    required this.aliases,
    required this.statKey,
    required this.sign,
    required this.cap,
    required this.isAdvantage,
  });

  final List<String> aliases;
  final String statKey;
  final int sign;
  final int cap;
  final bool isAdvantage;
}

const List<_StandardStatModifierRule> _standardStatModifierRules =
    <_StandardStatModifierRule>[
      _StandardStatModifierRule(
        aliases: <String>['Hohe Lebenskraft'],
        statKey: 'lep',
        sign: 1,
        cap: 6,
        isAdvantage: true,
      ),
      _StandardStatModifierRule(
        aliases: <String>['Ausdauernd'],
        statKey: 'au',
        sign: 1,
        cap: 6,
        isAdvantage: true,
      ),
      _StandardStatModifierRule(
        aliases: <String>['Astralmacht'],
        statKey: 'asp',
        sign: 1,
        cap: 6,
        isAdvantage: true,
      ),
      _StandardStatModifierRule(
        aliases: <String>['Hohe Magieresistenz'],
        statKey: 'mr',
        sign: 1,
        cap: 3,
        isAdvantage: true,
      ),
      _StandardStatModifierRule(
        aliases: <String>['Niedrige Lebenskraft'],
        statKey: 'lep',
        sign: -1,
        cap: 6,
        isAdvantage: false,
      ),
      _StandardStatModifierRule(
        aliases: <String>['Kurzatmig'],
        statKey: 'au',
        sign: -1,
        cap: 6,
        isAdvantage: false,
      ),
      _StandardStatModifierRule(
        aliases: <String>['Niedrige Astralkraft', 'Niedrige Astralenergie'],
        statKey: 'asp',
        sign: -1,
        cap: 6,
        isAdvantage: false,
      ),
      _StandardStatModifierRule(
        aliases: <String>['Niedrige Magieresistenz'],
        statKey: 'mr',
        sign: -1,
        cap: 3,
        isAdvantage: false,
      ),
    ];

/// Parst benannte Standard-Vor- und Nachteile als Stat-Modifikatoren.
///
/// Zahlen werden als Wirkungspunkte gelesen, nicht als GP. Das Vorzeichen der
/// Wirkung kommt aus dem Namen: `Kurzatmig 2` ergibt also `AU -2`.
StandardStatModifierMatch? parseStandardStatModifierFragment({
  required String fragment,
  required bool allowAdvantages,
  required bool allowDisadvantages,
}) {
  final normalizedFragment = _normalizeFragment(fragment);
  if (normalizedFragment.isEmpty) {
    return null;
  }

  for (final rule in _standardStatModifierRules) {
    if (rule.isAdvantage && !allowAdvantages) {
      continue;
    }
    if (!rule.isAdvantage && !allowDisadvantages) {
      continue;
    }

    for (final alias in rule.aliases) {
      final normalizedAlias = _normalizeFragment(alias);
      final amountText = _amountTextAfterAlias(
        normalizedFragment,
        normalizedAlias,
      );
      if (amountText == null) {
        continue;
      }
      final amount = int.tryParse(amountText);
      if (amount == null) {
        return const StandardStatModifierMatch(
          statMods: StatModifiers(),
          hasAmount: false,
        );
      }
      final cappedAmount = amount.abs().clamp(0, rule.cap).toInt();
      return StandardStatModifierMatch(
        statMods: _statModsForRule(rule, cappedAmount * rule.sign),
        hasAmount: true,
      );
    }
  }

  return null;
}

String? _amountTextAfterAlias(String normalizedFragment, String alias) {
  if (normalizedFragment == alias) {
    return '';
  }
  final prefix = '$alias ';
  if (!normalizedFragment.startsWith(prefix)) {
    return null;
  }
  return normalizedFragment.substring(prefix.length).trim();
}

String _normalizeFragment(String input) {
  var normalized = input
      .toLowerCase()
      .replaceAll(String.fromCharCode(228), 'ae')
      .replaceAll(String.fromCharCode(246), 'oe')
      .replaceAll(String.fromCharCode(252), 'ue')
      .replaceAll(String.fromCharCode(223), 'ss');
  normalized = normalized.replaceAll(RegExp(r'[:()\[\]]'), ' ');
  normalized = normalized.replaceAllMapped(
    RegExp(r'([+-])\s*(\d+)'),
    (match) => ' ${match.group(1)!}${match.group(2)!}',
  );
  normalized = normalized.replaceAll(RegExp(r'[^a-z0-9+\-\s]'), ' ');
  return normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
}

StatModifiers _statModsForRule(_StandardStatModifierRule rule, int amount) {
  return switch (rule.statKey) {
    'lep' => StatModifiers(lep: amount),
    'au' => StatModifiers(au: amount),
    'asp' => StatModifiers(asp: amount),
    'mr' => StatModifiers(mr: amount),
    _ => const StatModifiers(),
  };
}
