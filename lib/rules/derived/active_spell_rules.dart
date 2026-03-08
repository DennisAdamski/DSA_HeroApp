import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';

/// Statische Definition eines wichtigen, laufend aktivierbaren Zaubereffekts.
class ActiveSpellEffectDefinition {
  /// Erstellt eine Anzeige- und Regeldefinition fuer einen Zaubereffekt.
  const ActiveSpellEffectDefinition({
    required this.id,
    required this.label,
    required this.description,
  });

  /// Stabile interne Effekt-ID fuer Persistenz und Regelabfragen.
  final String id;

  /// Sichtbarer Name des Effekts in Buttons und Dialogen.
  final String label;

  /// Kurze Beschreibung fuer die UI.
  final String description;
}

/// Effekt-ID fuer den laufenden Axxeleratus.
const String activeSpellEffectAxxeleratus = 'effect_spell_axxeleratus';

/// Wichtige, direkt im Popup aktivierbare Zaubereffekte.
const List<ActiveSpellEffectDefinition> importantActiveSpellEffects =
    <ActiveSpellEffectDefinition>[
      ActiveSpellEffectDefinition(
        id: activeSpellEffectAxxeleratus,
        label: 'Axxeleratus',
        description:
            'Beschleunigt den Helden und erhoeht Initiative, GS und Nahkampfwerte.',
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
