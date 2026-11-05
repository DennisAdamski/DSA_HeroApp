import 'package:dsa_heldenverwaltung/catalog/hero_trait_effect.dart';
import 'package:dsa_heldenverwaltung/catalog/hero_trait_text.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_merkmal.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_attribute_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/attribute_start_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_anzeige_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_wirkung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_zuordnung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_requirement_context.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/rules/derived/resource_activation_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/rest_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wund_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../catalog/catalog_reference_names.dart';

/// Strukturierte Vor- und Nachteile (ARCH-02): Zuordnung der Alttexte,
/// Abweichungen durch aeltere App-Versionen und Wirkung ueber die Katalog-ID.

part 'hero_merkmal_zuordnung_cases.dart';
part 'hero_merkmal_wirkung_cases.dart';
part 'hero_merkmal_bearbeitung_cases.dart';

final vorteile = ladeKatalogDatei('vorteile.json')
    .map(HeroTraitDef.fromJson)
    .toList(growable: false);
final nachteile = ladeKatalogDatei('nachteile.json')
    .map(HeroTraitDef.fromJson)
    .toList(growable: false);
final catalog = RulesCatalog(
  version: 'house_rules_v1',
  source: 'test',
  talents: const [],
  spells: const [],
  weapons: const [],
  advantages: vorteile,
  disadvantages: nachteile,
);
final katalog = MerkmalKatalog.von(catalog);

HeroSheet held({
  String vorteileText = '',
  String nachteileText = '',
  List<HeroMerkmal> vorteilEintraege = const <HeroMerkmal>[],
  List<HeroMerkmal> nachteilEintraege = const <HeroMerkmal>[],
}) {
  return HeroSheet(
    id: 'h',
    name: 'Test',
    level: 1,
    attributes: const Attributes(
      mu: 12,
      kl: 12,
      inn: 12,
      ch: 12,
      ff: 12,
      ge: 12,
      ko: 12,
      kk: 12,
    ),
    vorteileText: vorteileText,
    nachteileText: nachteileText,
    vorteilEintraege: vorteilEintraege,
    nachteilEintraege: nachteilEintraege,
  );
}

void main() {
  _merkmalZuordnung();
  _merkmalWirkung();
  _merkmalBearbeitung();
}
