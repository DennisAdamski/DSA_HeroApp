import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/spell_duration.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/magic_rules.dart';

/// Stellt die Chipliste laufender Zaubereffekte zusammen.
///
/// Eigene Datei, weil die Zusammenstellung sowohl [active_spell_rules] als
/// auch [combat_rules] und [magic_rules] braucht — `active_spell_rules.dart`
/// selbst wird von beiden importiert und duerfte sie nicht zurueckholen.
///
/// Vorher lag diese Verknuepfung im Inspector-Widget. Seit die Spielansicht
/// dieselben Chips zeigt, haette sie an zwei Stellen gestanden.
List<ActiveSpellEffectChip> buildActiveSpellEffectChips({
  required HeroSheet? sheet,
  required HeroState? state,
  required CombatPreviewStats? combat,
}) {
  if (sheet == null || state == null || combat == null) {
    return const <ActiveSpellEffectChip>[];
  }

  final axxAktiv = isAxxeleratusEffectActive(sheet: sheet, state: state);
  final armatrutzAktiv = isActiveSpellEffectEnabled(
    sheet: sheet,
    state: state,
    effectId: activeSpellEffectArmatrutz,
  );
  final attributoAktiv = isActiveSpellEffectEnabled(
    sheet: sheet,
    state: state,
    effectId: activeSpellEffectAttributo,
  );
  final laufzeiten = <String, SpellDuration?>{
    for (final effekt in importantActiveSpellEffects)
      effekt.id: state.activeSpellEffects.detailFor(effekt.id).duration,
  };

  return describeActiveSpellEffects(
    axxeleratusActive: axxAktiv,
    axxIniBonus: combat.axxIniBonus,
    axxPaBaseBonus: combat.axxPaBaseBonus,
    axxAusweichenBonus: combat.axxAusweichenBonus,
    axxTpBonus: computeAxxeleratusTpBonus(axxeleratusActive: axxAktiv),
    armatrutzActive: armatrutzAktiv,
    armatrutzRsBonus: combat.armatrutzRsBonus,
    attributoActive: attributoAktiv,
    attributoBonusText: describeAttributeModifiers(state.tempAttributeMods),
    durationsByEffectId: laufzeiten,
  );
}

/// Setzt Effektname, Boni und Restlaufzeit zu einer Chip-Beschriftung zusammen.
String describeActiveSpellEffectChip(ActiveSpellEffectChip chip) {
  final teile = <String>[];
  if (chip.bonusText.isNotEmpty) teile.add(chip.bonusText);
  if (chip.durationText.isNotEmpty) teile.add(chip.durationText);
  if (teile.isEmpty) return chip.label;
  return '${chip.label}: ${teile.join(' · ')}';
}
