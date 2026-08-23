/// Benannte Vor- und Nachteile, deren Wirkungsziel eine im Fragment gewaehlte
/// Eigenschaft ist.
///
/// Abgrenzung zu `standard_stat_modifier_rules.dart`: dort ist das Ziel eine
/// Konstante der Regel (`statKey`), hier steht es erst im Text des Helden.
/// Fragmentform ist deshalb `<Name> <Eigenschaft> [<Wert>]`, zum Beispiel
/// `Herausragende Eigenschaft KK 2`.
///
/// Quelle: Wege der Helden S. 253 (Herausragende Eigenschaft).
library;

import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_fragment_text.dart';

/// Ergebnis einer erkannten Eigenschafts-Regel.
class AttributeTraitMatch {
  /// Erstellt ein Parser-Ergebnis fuer einen benannten Eigenschafts-Vorteil.
  const AttributeTraitMatch({
    required this.attributeMods,
    required this.raisesStartValue,
    required this.hasAttribute,
  });

  /// Modifikator auf die im Fragment gewaehlte Eigenschaft.
  final AttributeModifiers attributeMods;

  /// Ob die Regel zusaetzlich den Startwert anhebt — und damit ueber
  /// `ceil(start * 1.5)` auch das Eigenschaftsmaximum.
  final bool raisesStartValue;

  /// Ob im Fragment eine aufloesbare Eigenschaft stand. Ist das nicht der Fall,
  /// gehoert das Fragment in `unknownFragments` statt in die Wirkung.
  final bool hasAttribute;
}

class _AttributeTraitRule {
  const _AttributeTraitRule({
    required this.aliases,
    required this.sign,
    required this.defaultAmount,
    required this.maxAmount,
    required this.raisesStartValue,
    required this.isAdvantage,
  });

  final List<String> aliases;
  final int sign;

  /// Wirkung, wenn im Text keine Zahl steht (`Herausragende Eigenschaft KK`).
  final int defaultAmount;

  /// Obergrenze als Tippfehler-Netz; das Regelwerk kennt keine harte Grenze,
  /// sondern nur den GP-Vorrat.
  final int maxAmount;

  final bool raisesStartValue;
  final bool isAdvantage;
}

const List<_AttributeTraitRule> _attributeTraitRules = <_AttributeTraitRule>[
  _AttributeTraitRule(
    aliases: <String>['Herausragende Eigenschaft'],
    sign: 1,
    defaultAmount: 1,
    maxAmount: 8,
    raisesStartValue: true,
    isAdvantage: true,
  ),
];

/// Erwartet den Resttext hinter dem Alias: Eigenschaft plus optionaler Wert.
final RegExp _remainderPattern = RegExp(r'^([a-z]+)\s*([+-]?\d+)?$');

/// Parst benannte Vor-/Nachteile, deren Ziel eine im Fragment gewaehlte
/// Eigenschaft ist.
///
/// Liefert `null`, wenn kein Alias passt — dann ist ein anderer Parser
/// zustaendig. Passt ein Alias, steht die Eigenschaft aber nicht darin, kommt
/// ein Ergebnis mit `hasAttribute: false` zurueck, damit der Aufrufer das
/// Fragment als unbekannt melden kann statt es still zu verschlucken.
AttributeTraitMatch? parseAttributeTraitFragment({
  required String fragment,
  required bool allowAdvantages,
  required bool allowDisadvantages,
}) {
  final normalizedFragment = normalizeModifierFragment(fragment);
  if (normalizedFragment.isEmpty) {
    return null;
  }

  for (final rule in _attributeTraitRules) {
    if (rule.isAdvantage && !allowAdvantages) {
      continue;
    }
    if (!rule.isAdvantage && !allowDisadvantages) {
      continue;
    }

    for (final alias in rule.aliases) {
      final remainder = modifierFragmentRemainderAfterAlias(
        normalizedFragment,
        normalizeModifierFragment(alias),
      );
      if (remainder == null) {
        continue;
      }

      final match = _remainderPattern.firstMatch(remainder);
      final code = match == null ? null : parseAttributeCode(match.group(1)!);
      if (code == null) {
        return const AttributeTraitMatch(
          attributeMods: AttributeModifiers(),
          raisesStartValue: false,
          hasAttribute: false,
        );
      }

      final rawAmount = int.tryParse(match!.group(2) ?? '');
      final amount = (rawAmount?.abs() ?? rule.defaultAmount).clamp(
        1,
        rule.maxAmount,
      );
      return AttributeTraitMatch(
        attributeMods: attributeModifiersFor(code, amount * rule.sign),
        raisesStartValue: rule.raisesStartValue,
        hasAttribute: true,
      );
    }
  }

  return null;
}

/// Baut einen [AttributeModifiers]-Wert mit genau einer gesetzten Eigenschaft.
AttributeModifiers attributeModifiersFor(AttributeCode code, int amount) {
  return switch (code) {
    AttributeCode.mu => AttributeModifiers(mu: amount),
    AttributeCode.kl => AttributeModifiers(kl: amount),
    AttributeCode.inn => AttributeModifiers(inn: amount),
    AttributeCode.ch => AttributeModifiers(ch: amount),
    AttributeCode.ff => AttributeModifiers(ff: amount),
    AttributeCode.ge => AttributeModifiers(ge: amount),
    AttributeCode.ko => AttributeModifiers(ko: amount),
    AttributeCode.kk => AttributeModifiers(kk: amount),
  };
}
