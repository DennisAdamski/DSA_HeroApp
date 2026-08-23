import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_fragment_text.dart';

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
  final normalizedFragment = normalizeModifierFragment(fragment);
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
      final normalizedAlias = normalizeModifierFragment(alias);
      final amountText = modifierFragmentRemainderAfterAlias(
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

StatModifiers _statModsForRule(_StandardStatModifierRule rule, int amount) {
  return switch (rule.statKey) {
    'lep' => StatModifiers(lep: amount),
    'au' => StatModifiers(au: amount),
    'asp' => StatModifiers(asp: amount),
    'mr' => StatModifiers(mr: amount),
    _ => const StatModifiers(),
  };
}
