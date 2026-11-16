// Voraussetzungen der Vertrautenbindung (WdZ S. 123).
//
// Die Bindung braucht die magische Sonderfertigkeit Vertrautenbindung; wer den
// Nachteil „Kein Vertrauter“ führt, darf keinen Vertrauten haben. Wie bei allen
// Voraussetzungen der App sperrt das nie: der Dialog zeigt die Hinweise und
// bindet dann nur per Meisterentscheid.

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_wirkung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_requirement_context.dart';
import 'package:dsa_heldenverwaltung/rules/derived/special_ability_chain_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/special_ability_variant_rules.dart'
    show normalizeSpecialAbilityName;

/// Katalog-ID der Sonderfertigkeit Vertrautenbindung.
const String kVertrautenbindungSfId = 'magsf_vertrautenbindung';

/// Katalog-ID des Nachteils „Kein Vertrauter“.
const String kKeinVertrauterId = 'dis_kein_vertrauter';

/// Name der Sonderfertigkeit, falls der Katalog nicht geladen ist.
const String kVertrautenbindungSfName = 'Vertrautenbindung';

/// Hat [held] die Sonderfertigkeit Vertrautenbindung?
///
/// Mit [catalog] zählen Katalogname und `alias_namen` des Eintrags
/// [kVertrautenbindungSfId]; ohne Katalog der Name [kVertrautenbindungSfName].
bool hatVertrautenbindungSf(HeroSheet held, {RulesCatalog? catalog}) {
  final namen = heroSpecialAbilityNames(held, catalog: catalog);
  for (final def in catalog?.magicSpecialAbilities ?? const []) {
    if (def.id == kVertrautenbindungSfId) {
      return istEintragErworben(def, namen);
    }
  }
  final ziel = normalizeSpecialAbilityName(kVertrautenbindungSfName);
  return namen.any((name) => normalizeSpecialAbilityName(name) == ziel);
}

/// Katalog-ID des Vorteils „Machtvoller Vertrauter“.
const String kMachtvollerVertrauterId = 'adv_machtvoller_vertrauter';

/// Führt [held] den Nachteil „Kein Vertrauter“?
///
/// Gelesen werden die wirksamen Nachteile der zentralen Auswertung
/// ([werteMerkmaleAus]); ein frei eingetragener Nachteil zählt über seinen
/// Text.
bool hatNachteilKeinVertrauter(HeroSheet held, {RulesCatalog? catalog}) {
  return werteMerkmaleAus(held, catalog: catalog).abgleich.nachteile.any(
    (m) =>
        m.katalogId == kKeinVertrauterId ||
        (m.katalogId.isEmpty &&
            m.text.toLowerCase().trim().startsWith('kein vertrauter')),
  );
}

/// Führt [held] den Vorteil „Machtvoller Vertrauter“?
///
/// Wie [hatNachteilKeinVertrauter] über die zentrale Auswertung; die
/// Oberfläche entscheidet das nie selbst.
bool hatVorteilMachtvollerVertrauter(HeroSheet held, {RulesCatalog? catalog}) {
  return werteMerkmaleAus(held, catalog: catalog).abgleich.vorteile.any(
    (m) =>
        m.katalogId == kMachtvollerVertrauterId ||
        (m.katalogId.isEmpty &&
            m.text.toLowerCase().trim().startsWith('machtvoller vertrauter')),
  );
}

/// Hinweise, die gegen die Bindung sprechen; leer, wenn alles passt.
///
/// Die Hinweise sperren nie: gebunden wird dann nur per Meisterentscheid.
List<String> vertrautenBindungHinweise(
  HeroSheet held, {
  RulesCatalog? catalog,
}) {
  return <String>[
    if (!hatVertrautenbindungSf(held, catalog: catalog))
      'Die Sonderfertigkeit Vertrautenbindung fehlt.',
    if (hatNachteilKeinVertrauter(held, catalog: catalog))
      'Die Hexe hat den Nachteil „Kein Vertrauter“.',
  ];
}
