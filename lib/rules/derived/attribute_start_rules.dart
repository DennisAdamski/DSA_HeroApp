import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';

/// Parst ausschliesslich Herkunftsmodifikatoren aus Rasse, Kultur und Profession.
AttributeModifiers parseOriginAttributeModifiers(HeroSheet hero) {
  final parsed = parseModifierTexts(
    rasseModText: hero.background.rasseModText,
    kulturModText: hero.background.kulturModText,
    professionModText: hero.background.professionModText,
    vorteileText: '',
    nachteileText: '',
  );
  return parsed.attributeMods;
}

/// Berechnet die effektiven Starteigenschaften aus Rohstart und Herkunftsmods.
Attributes computeEffectiveStartAttributes(
  Attributes rawStartAttributes,
  AttributeModifiers originAttributeModifiers,
) {
  return applyAttributeModifiers(rawStartAttributes, originAttributeModifiers);
}

/// Berechnet die Eigenschaftsmaxima aus den effektiven Starteigenschaften.
///
/// Die Hausregel lautet `ceil(start * 1.5)`.
/// Epische Charaktere koennen zusaetzlich bis zu 5 Punkte (max. +2 pro Eigenschaft)
/// dauerhaft auf ihre Obergrenzen erhalten ([epicBonus]).
Attributes computeAttributeMaximums(
  Attributes effectiveStartAttributes, {
  Attributes epicBonus = const Attributes.zero(),
}) {
  return Attributes(
    mu: _computeAttributeMaximum(effectiveStartAttributes.mu) + epicBonus.mu,
    kl: _computeAttributeMaximum(effectiveStartAttributes.kl) + epicBonus.kl,
    inn: _computeAttributeMaximum(effectiveStartAttributes.inn) + epicBonus.inn,
    ch: _computeAttributeMaximum(effectiveStartAttributes.ch) + epicBonus.ch,
    ff: _computeAttributeMaximum(effectiveStartAttributes.ff) + epicBonus.ff,
    ge: _computeAttributeMaximum(effectiveStartAttributes.ge) + epicBonus.ge,
    ko: _computeAttributeMaximum(effectiveStartAttributes.ko) + epicBonus.ko,
    kk: _computeAttributeMaximum(effectiveStartAttributes.kk) + epicBonus.kk,
  );
}

int _computeAttributeMaximum(int startValue) {
  return (startValue * 1.5).ceil();
}
