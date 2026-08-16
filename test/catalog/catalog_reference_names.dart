/// Gemeinsame Helfer fuer die Katalogtests der Erwerbsvoraussetzungen.
///
/// Eine strukturierte Voraussetzung ist nur so gut wie die Namen, auf die sie
/// zeigt: `TaW Sinnenschaerfe 15` sieht im JSON richtig aus, findet aber nie
/// ein Talent, weil das Talent `Sinnesschaerfe` heisst. Solche Tippfehler
/// faenden sich sonst erst im Betrieb — und dort nur als stillschweigend nicht
/// erfuellte Bedingung. Deshalb loesen die Katalogtests jede Referenz gegen
/// ihren Bezugskatalog auf.
library;

import 'dart:convert';
import 'dart:io';

import 'package:dsa_heldenverwaltung/catalog/special_ability_requirement.dart';
import 'package:dsa_heldenverwaltung/rules/derived/special_ability_variant_rules.dart';

const String _katalogPfad = 'assets/catalogs/house_rules_v1';

/// Liest eine Katalogdatei als Liste von JSON-Objekten.
///
/// Einzelne Katalogdateien beginnen mit einem UTF-8-BOM; `jsonDecode` wuerde
/// daran scheitern, deshalb wird es abgeschnitten.
List<Map<String, dynamic>> ladeKatalogDatei(String dateiname) {
  var text = File('$_katalogPfad/$dateiname').readAsStringSync();
  if (text.startsWith('﻿')) {
    text = text.substring(1);
  }
  return (jsonDecode(text) as List).cast<Map<String, dynamic>>();
}

/// Alle `name`-Werte einer Katalogdatei, normalisiert fuer den Vergleich.
Set<String> normalisierteNamen(String dateiname) {
  return <String>{
    for (final eintrag in ladeKatalogDatei(dateiname))
      normalizeSpecialAbilityName('${eintrag['name'] ?? ''}'),
  }..remove('');
}

/// Talentnamen aus beiden Talentdateien — `catalog.talents` fuehrt sie
/// zusammen, also muss der Test es auch tun.
Set<String> ladeTalentNamen() => <String>{
  ...normalisierteNamen('talente.json'),
  ...normalisierteNamen('waffentalente.json'),
};

/// Namen der Kampftalente; nur auf sie kann eine Waffenmeisterschaft lauten.
Set<String> ladeKampftalentNamen() => <String>{
  for (final eintrag in ladeKatalogDatei('waffentalente.json'))
    if ('${eintrag['group'] ?? ''}' == 'Kampftalent')
      normalizeSpecialAbilityName('${eintrag['name'] ?? ''}'),
}..remove('');

/// Flacht Oder- und Und-Gruppen in eine einzige Liste auf.
Iterable<SpecialAbilityRequirement> alleBedingungenFlach(
  Iterable<SpecialAbilityRequirement> bedingungen,
) sync* {
  for (final bedingung in bedingungen) {
    yield bedingung;
    yield* alleBedingungenFlach(bedingung.bedingungen);
  }
}

/// Gueltige Eigenschaftskuerzel.
const Set<String> gueltigeEigenschaften = <String>{
  'MU',
  'KL',
  'IN',
  'CH',
  'FF',
  'GE',
  'KO',
  'KK',
};

/// Gueltige Kuerzel fuer abgeleitete Kampf-Basiswerte.
const Set<String> gueltigeBasiswerte = <String>{'AT', 'PA', 'FK', 'INI'};
