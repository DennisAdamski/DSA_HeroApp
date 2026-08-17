import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/spell_duration.dart';

/// Statische Definition eines wichtigen, laufend aktivierbaren Zaubereffekts.
class ActiveSpellEffectDefinition {
  /// Erstellt eine Anzeige- und Regeldefinition fuer einen Zaubereffekt.
  const ActiveSpellEffectDefinition({
    required this.id,
    required this.label,
    required this.description,
    this.defaultDurationUnit = SpellDurationUnit.kampfrunden,
  });

  /// Stabile interne Effekt-ID fuer Persistenz und Regelabfragen.
  final String id;

  /// Sichtbarer Name des Effekts in Buttons und Dialogen.
  final String label;

  /// Kurze Beschreibung fuer die UI.
  final String description;

  /// Vorbelegte Zeiteinheit der Wirkungsdauer laut Zauberbeschreibung.
  final SpellDurationUnit defaultDurationUnit;
}

/// Effekt-ID fuer den laufenden Axxeleratus.
const String activeSpellEffectAxxeleratus = 'effect_spell_axxeleratus';

/// Effekt-ID fuer den laufenden Attributo.
const String activeSpellEffectAttributo = 'effect_spell_attributo';

/// Effekt-ID fuer den laufenden Armatrutz.
const String activeSpellEffectArmatrutz = 'effect_spell_armatrutz';

/// Wichtige, direkt im Popup aktivierbare Zaubereffekte.
const List<ActiveSpellEffectDefinition> importantActiveSpellEffects =
    <ActiveSpellEffectDefinition>[
      ActiveSpellEffectDefinition(
        id: activeSpellEffectAxxeleratus,
        label: 'Axxeleratus',
        description:
            'Beschleunigt den Helden und erhöht Initiative, GS und Nahkampfwerte.',
      ),
      ActiveSpellEffectDefinition(
        id: activeSpellEffectAttributo,
        label: 'Attributo',
        description:
            'Erhöht temporär einzelne Eigenschaften des Helden.',
      ),
      ActiveSpellEffectDefinition(
        id: activeSpellEffectArmatrutz,
        label: 'Armatrutz',
        description:
            'Legt eine magische Rüstung auf; der erzauberte RS zählt zusätzlich '
            'zur getragenen Rüstung.',
        // Wirkungsdauer laut Liber Cantiones: maximal eine Spielrunde.
        defaultDurationUnit: SpellDurationUnit.spielrunden,
      ),
    ];

/// Liefert die Definition zu einer Effekt-ID oder `null`, wenn unbekannt.
ActiveSpellEffectDefinition? importantActiveSpellEffectById(String effectId) {
  for (final effect in importantActiveSpellEffects) {
    if (effect.id == effectId) {
      return effect;
    }
  }
  return null;
}

/// Prueft, ob ein wichtiger Zaubereffekt aktuell aktiv ist.
///
/// Fuer `Axxeleratus` bleibt das alte Feld in `combatConfig.specialRules` als
/// Fallback erhalten, damit bestehende Daten und Tests weiter funktionieren.
bool isActiveSpellEffectEnabled({
  required HeroSheet sheet,
  required HeroState state,
  required String effectId,
}) {
  if (state.activeSpellEffects.isActive(effectId)) {
    return true;
  }
  if (effectId == activeSpellEffectAxxeleratus) {
    return sheet.combatConfig.specialRules.axxeleratusActive;
  }
  return false;
}

/// Convenience-Helfer fuer die Axxeleratus-Regeln.
bool isAxxeleratusEffectActive({
  required HeroSheet sheet,
  required HeroState state,
}) {
  return isActiveSpellEffectEnabled(
    sheet: sheet,
    state: state,
    effectId: activeSpellEffectAxxeleratus,
  );
}

/// Liefert die erfasste Wirkungsdauer eines Effekts oder `null`.
SpellDuration? activeSpellEffectDuration({
  required HeroState state,
  required String effectId,
}) {
  return state.activeSpellEffects.detailFor(effectId).duration;
}

/// Fasst die erfassten Werte eines Effekts als Text zusammen.
///
/// Liefert einen leeren String fuer Effekte ohne eigene Zahlenwerte
/// (z. B. `Axxeleratus`), damit die UI die Zeile schlicht weglassen kann.
String describeActiveSpellEffectValue({
  required String effectId,
  required HeroState state,
}) {
  switch (effectId) {
    case activeSpellEffectArmatrutz:
      final rsBonus = state.activeSpellEffects.detailFor(effectId).amount;
      return 'Zusätzlicher RS: $rsBonus';
    case activeSpellEffectAttributo:
      final summary = describeAttributeModifiers(state.tempAttributeMods);
      return summary.isEmpty ? 'Keine Boni erfasst' : 'Boni: $summary';
    default:
      return '';
  }
}

/// Listet gesetzte Eigenschaftsboni als `MU+2 KL+1`-Text auf.
String describeAttributeModifiers(AttributeModifiers mods) {
  final parts = <String>[];
  void add(String label, int value) {
    if (value != 0) {
      parts.add('$label${value > 0 ? '+' : ''}$value');
    }
  }

  add('MU', mods.mu);
  add('KL', mods.kl);
  add('IN', mods.inn);
  add('CH', mods.ch);
  add('FF', mods.ff);
  add('GE', mods.ge);
  add('KO', mods.ko);
  add('KK', mods.kk);
  return parts.join(' ');
}

/// Sammelt alle aktiven Effekte, deren Wirkungsdauer abgelaufen ist.
///
/// Abgelaufene Effekte werden nicht automatisch deaktiviert: Ob ein Zauber
/// wirklich endet, entscheidet die Spielleitung -- die App zeigt den Ablauf
/// deshalb nur an.
List<ActiveSpellEffectDefinition> expiredActiveSpellEffects(HeroState state) {
  final expired = <ActiveSpellEffectDefinition>[];
  for (final effect in importantActiveSpellEffects) {
    if (!state.activeSpellEffects.isActive(effect.id)) {
      continue;
    }
    final duration = state.activeSpellEffects.detailFor(effect.id).duration;
    if (duration?.isExpired ?? false) {
      expired.add(effect);
    }
  }
  return List<ActiveSpellEffectDefinition>.unmodifiable(expired);
}
