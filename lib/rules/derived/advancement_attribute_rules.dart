import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';

import 'attribute_start_rules.dart';
import 'modifier_source_breakdown.dart';

/// Überträgt einen effektiven Steigerungszielwert auf die gespeicherte Rohspalte.
/// Verändert weder AP noch SE; Validierung und Buchung bleiben beim Replay.
HeroSheet applyAdvancementAttributeValue(
  HeroSheet hero,
  AttributeCode code,
  int targetValue,
) {
  final delta = attributeModValue(
    parseStartAttributeModifiers(hero),
    code.name,
  );
  return hero.copyWith(
    attributes: _withAttributeValue(hero.attributes, code, targetValue - delta),
  );
}

// Erhält alle nicht gesteigerten Eigenschaften unverändert.
Attributes _withAttributeValue(
  Attributes attrs,
  AttributeCode code,
  int value,
) => switch (code) {
  AttributeCode.mu => attrs.copyWith(mu: value),
  AttributeCode.kl => attrs.copyWith(kl: value),
  AttributeCode.inn => attrs.copyWith(inn: value),
  AttributeCode.ch => attrs.copyWith(ch: value),
  AttributeCode.ff => attrs.copyWith(ff: value),
  AttributeCode.ge => attrs.copyWith(ge: value),
  AttributeCode.ko => attrs.copyWith(ko: value),
  AttributeCode.kk => attrs.copyWith(kk: value),
};
