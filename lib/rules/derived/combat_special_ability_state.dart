/// Beantwortet, ob eine Kampf-Sonderfertigkeit bei einem Helden aktiv ist.
///
/// Kampf-Sonderfertigkeiten werden auf zwei Wegen gespeichert: Die meisten
/// stehen als Katalog-ID in `CombatSpecialRules.activeCombatSpecialAbilityIds`,
/// einige wenige haben ein eigenes Feld, weil die Kampfberechnung sie direkt
/// braucht (`ausweichenI`, `kampfreflexe`, die Ruestungsgewoehnungs-Stufe).
///
/// Diese Doppelung darf nicht in der UI hocken: Sonst wuesste die
/// Voraussetzungspruefung nichts von den Sonderfeldern und wuerde
/// `Ausweichen II` selbst dann als gesperrt anzeigen, wenn `Ausweichen I`
/// laengst aktiv ist.
library;

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';

/// Ob die Kampf-Sonderfertigkeit mit [id] in [config] aktiv ist.
bool isCombatSpecialAbilityActive(CombatConfig config, String id) {
  final rules = config.specialRules;
  final armor = config.armor;
  return switch (id) {
    'ksf_kampfreflexe' => rules.kampfreflexe,
    'ksf_kampfgespuer' => rules.kampfgespuer,
    'ksf_schnellziehen' => rules.schnellziehen,
    'ksf_ausweichen_i' => rules.ausweichenI,
    'ksf_ausweichen_ii' => rules.ausweichenII,
    'ksf_ausweichen_iii' => rules.ausweichenIII,
    'ksf_linkhand' => rules.linkhandActive,
    'ksf_schildkampf_i' => rules.schildkampfI,
    'ksf_schildkampf_ii' => rules.schildkampfII,
    'ksf_parierwaffen_i' => rules.parierwaffenI,
    'ksf_parierwaffen_ii' => rules.parierwaffenII,
    'ksf_klingentaenzer' => rules.klingentaenzer,
    'ksf_aufmerksamkeit' => rules.aufmerksamkeit,
    'ksf_ruestungsgewoehnung_i' => armor.globalArmorTrainingLevel >= 1,
    'ksf_ruestungsgewoehnung_ii' => armor.globalArmorTrainingLevel >= 2,
    'ksf_ruestungsgewoehnung_iii' => armor.globalArmorTrainingLevel >= 3,
    _ => rules.activeCombatSpecialAbilityIds.contains(id),
  };
}
