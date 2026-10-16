import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_regelprofil.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/regelprofil_vorschau_rules.dart';

/// Schreibt die frisch geladene Fassung eines Helden mit geänderter Regel.
///
/// Entspricht dem Tear-off `HeroActions.updateHero`: lädt frisch, wendet die
/// Änderung an, normalisiert und speichert **ein** Dokument. Der Katalog nach
/// der Änderung wird für die Normalisierung mitgegeben.
typedef BogenAendern = Future<HeroSheet> Function(
  String heroId,
  HeroSheet Function(HeroSheet aktuell) aenderung, {
  RulesCatalog? validationCatalog,
});

/// Anwendungsablauf „Regelprofil übernehmen“ (ARCH-04, ARCH-05).
///
/// Setzt das Regelprofil eines Helden auf den Stand einer Vorschau. Ohne
/// Aufruf ändert sich nichts am Helden: Ein App- oder Paketupdate wirkt erst
/// nach dieser Übernahme. Der Held wird frisch geladen; ist sein Profil
/// inzwischen ein anderes als das, auf dem die Vorschau beruht, scheitert der
/// Ablauf mit einem `StateError`, ohne zu schreiben. Fehler werden nicht
/// gefangen, die Oberfläche zeigt sie.
class RegelProfilUebernehmen {
  /// Erzeugt den Ablauf über den frischen Schreibweg des Bogens.
  const RegelProfilUebernehmen({required this.aendere});

  /// Frischer Schreibweg des Bogens.
  final BogenAendern aendere;

  /// Übernimmt [vorschau] für [heroId].
  ///
  /// Der Katalog des neuen Profils kommt aus der Vorschau, damit Speichern und
  /// Anzeige denselben Regelstand benutzen. Gleicht das neue dem gespeicherten
  /// Profil, wird nichts geschrieben. Liefert den gespeicherten Helden.
  Future<HeroSheet> uebernehme({
    required String heroId,
    required RegelProfilVorschau vorschau,
  }) {
    return aendere(
      heroId,
      (aktuell) =>
          uebernehmeRegelProfil(aktuell, von: vorschau.von, auf: vorschau.auf),
      validationCatalog: vorschau.vergleich.neu.katalog,
    );
  }

  /// Setzt das Profil von [heroId] auf [auf], ohne Vorschau.
  ///
  /// Für die Erstübernahme (`von == null`: der Held folgte den globalen
  /// Einstellungen) und Tests. Der Katalog des neuen Profils wird nur
  /// mitgegeben, wenn er bekannt ist.
  Future<HeroSheet> setzeProfil({
    required String heroId,
    required HeroRegelProfil? von,
    required HeroRegelProfil auf,
    RulesCatalog? katalog,
  }) {
    return aendere(
      heroId,
      (aktuell) => uebernehmeRegelProfil(aktuell, von: von, auf: auf),
      validationCatalog: katalog,
    );
  }
}
