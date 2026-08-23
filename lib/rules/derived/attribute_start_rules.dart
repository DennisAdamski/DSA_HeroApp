import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_source_breakdown.dart';

/// Alle Modifikatoren, die den Startwert einer Eigenschaft anheben.
///
/// Das sind die Herkunftsmodifikatoren aus Rasse, Kultur und Profession sowie
/// startwerterhoehende Vorteile wie `Herausragende Eigenschaft`. Freie
/// `CODE+N`-Fragmente aus Vor-/Nachteilen bleiben bewusst draussen — die
/// beschreiben laufende Effekte, keine Generierungswerte.
AttributeModifiers parseStartAttributeModifiers(HeroSheet hero) {
  return parseModifierTextsForHero(hero).startAttributeMods;
}

/// Berechnet die effektiven Starteigenschaften aus Rohstart und Herkunftsmods.
Attributes computeEffectiveStartAttributes(
  Attributes rawStartAttributes,
  AttributeModifiers startAttributeModifiers,
) {
  return applyAttributeModifiers(rawStartAttributes, startAttributeModifiers);
}

/// Effektive Starteigenschaften eines Helden — der einzige Einstiegspunkt.
///
/// Die Basis ist fest an [HeroSheet.rawStartAttributes] gebunden. Das ist kein
/// Detail: `HeroSheet.startAttributes` traegt bereits das Ergebnis dieser
/// Rechnung, und wer es erneut modifiziert, addiert die Herkunftsmods ein
/// zweites Mal.
Attributes computeHeroEffectiveStartAttributes(HeroSheet hero) {
  return computeEffectiveStartAttributes(
    hero.rawStartAttributes,
    parseStartAttributeModifiers(hero),
  );
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

/// Eigenschaftsmaxima eines Helden inklusive epischem Obergrenzenbonus.
Attributes computeHeroAttributeMaximums(HeroSheet hero) {
  return computeAttributeMaximums(
    computeHeroEffectiveStartAttributes(hero),
    epicBonus: hero.epicAttributeMaxBonus,
  );
}

int _computeAttributeMaximum(int startValue) {
  return (startValue * 1.5).ceil();
}

/// Schemaversion, ab der `Herausragende Eigenschaft` als Modifikator wirkt.
///
/// Bestandshelden haben den Vorteil bisher nur als wirkungslosen Text getragen
/// und den Punkt meist schon in die Eigenschaft eingerechnet. Statt still
/// umzurechnen zeigt die App einen Hinweis, den der Nutzer quittiert.
const int kAttributeTraitEffectSchemaVersion = 28;

/// Eigenschaftsboni, die durch die Regelaenderung neu wirksam geworden sind.
///
/// Liefert Eintraege der Form `KK +2`. Leer, wenn der Held keinen betroffenen
/// Vorteil traegt oder die Aenderung bereits quittiert hat.
List<String> pendingAttributeTraitNotices(HeroSheet hero) {
  if (hero.schemaVersion >= kAttributeTraitEffectSchemaVersion) {
    return const <String>[];
  }
  // Nur der Vorteilsanteil: Herkunftsmods haben schon vorher gewirkt.
  final mods = parseModifierTexts(
    rasseModText: '',
    kulturModText: '',
    professionModText: '',
    vorteileText: hero.vorteileText,
    nachteileText: '',
  ).startAttributeMods;

  return <String>[
    for (final code in AttributeCode.values)
      if (attributeModValue(mods, code.name) != 0)
        '${attributeCodeKey(code)} '
            '${attributeModValue(mods, code.name) > 0 ? '+' : ''}'
            '${attributeModValue(mods, code.name)}',
  ];
}
