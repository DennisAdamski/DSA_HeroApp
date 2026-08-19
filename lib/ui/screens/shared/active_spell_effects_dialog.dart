import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_duration_rules.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/active_spell_effect_tile.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/armatrutz_input_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/attributo_input_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/spell_duration_dialog.dart';

/// Oeffnet den gemeinsamen Dialog fuer wichtige aktive Zaubereffekte.
Future<void> showActiveSpellEffectsDialog({
  required BuildContext context,
  required String heroId,
}) {
  return showAdaptiveDetailSheet<void>(
    context: context,
    builder: (dialogContext) {
      return _ActiveSpellEffectsDialog(heroId: heroId);
    },
  );
}

/// Dialog fuer laufend aktivierbare Zaubereffekte wie `Axxeleratus`,
/// `Attributo` und `Armatrutz`.
///
/// Jeder aktive Effekt kann zusaetzlich eine Wirkungsdauer tragen, die am
/// Spieltisch heruntergezaehlt wird.
class _ActiveSpellEffectsDialog extends ConsumerStatefulWidget {
  const _ActiveSpellEffectsDialog({required this.heroId});

  final String heroId;

  @override
  ConsumerState<_ActiveSpellEffectsDialog> createState() =>
      _ActiveSpellEffectsDialogState();
}

class _ActiveSpellEffectsDialogState
    extends ConsumerState<_ActiveSpellEffectsDialog> {
  /// Speichert einen neuen Laufzeitzustand fuer den Helden.
  Future<void> _save(HeroState updatedState) {
    final actions = ref.read(heroActionsProvider);
    return actions.saveHeroState(widget.heroId, updatedState);
  }

  /// Liest den aktuellen Laufzeitzustand; `null`, solange er nicht geladen ist.
  HeroState? get _state => ref.read(heroStateProvider(widget.heroId)).valueOrNull;

  Future<void> _toggleEffect(String effectId, bool value) async {
    final state = _state;
    if (state == null) {
      return;
    }
    final updatedState = state.copyWith(
      activeSpellEffects: state.activeSpellEffects.withToggled(effectId, value),
    );
    await _save(updatedState);
  }

  /// Aktiviert den Attributo erst nach Eingabe der Eigenschaftsboni.
  Future<void> _toggleAttributo(bool value) async {
    final state = _state;
    if (state == null) {
      return;
    }

    if (!value) {
      final updatedState = state.copyWith(
        tempAttributeMods: const AttributeModifiers(),
        activeSpellEffects: state.activeSpellEffects.withToggled(
          activeSpellEffectAttributo,
          false,
        ),
      );
      await _save(updatedState);
      return;
    }

    final bonuses = await showAttributoInputDialog(context: context);
    if (bonuses == null || !mounted) {
      return;
    }
    final updatedState = state.copyWith(
      tempAttributeMods: bonuses,
      activeSpellEffects: state.activeSpellEffects.withToggled(
        activeSpellEffectAttributo,
        true,
      ),
    );
    await _save(updatedState);
  }

  /// Aktiviert den Armatrutz erst nach Eingabe von RS und Wirkungsdauer.
  Future<void> _toggleArmatrutz(bool value) async {
    final state = _state;
    if (state == null) {
      return;
    }

    if (!value) {
      final effects = state.activeSpellEffects.withToggled(
        activeSpellEffectArmatrutz,
        false,
      );
      await _save(state.copyWith(activeSpellEffects: effects));
      return;
    }

    await _editArmatrutzValues(activateFirst: true);
  }

  /// Fragt RS und Wirkungsdauer des Armatrutz ab und schreibt sie zurueck.
  Future<void> _editArmatrutzValues({bool activateFirst = false}) async {
    final state = _state;
    if (state == null) {
      return;
    }
    final current = state.activeSpellEffects.detailFor(
      activeSpellEffectArmatrutz,
    );
    final detail = await showArmatrutzInputDialog(
      context: context,
      initialDetail: activateFirst ? null : current,
    );
    if (detail == null || !mounted) {
      return;
    }
    final latest = _state;
    if (latest == null) {
      return;
    }
    final effects = latest.activeSpellEffects
        .withToggled(activeSpellEffectArmatrutz, true)
        .withDetail(activeSpellEffectArmatrutz, detail);
    await _save(latest.copyWith(activeSpellEffects: effects));
  }

  /// Fragt die Wirkungsdauer eines beliebigen Effekts ab.
  Future<void> _editDuration(ActiveSpellEffectDefinition effect) async {
    final state = _state;
    if (state == null) {
      return;
    }
    final current = state.activeSpellEffects.detailFor(effect.id);
    final result = await showSpellDurationDialog(
      context: context,
      spellLabel: effect.label,
      initialDuration: current.duration,
      defaultUnit: effect.defaultDurationUnit,
    );
    if (result == null || !mounted) {
      return;
    }
    final latest = _state;
    if (latest == null) {
      return;
    }
    final updatedDetail = result.duration == null
        ? current.copyWith(clearDuration: true)
        : current.copyWith(duration: result.duration);
    final effects = latest.activeSpellEffects.withDetail(
      effect.id,
      updatedDetail,
    );
    await _save(latest.copyWith(activeSpellEffects: effects));
  }

  /// Zieht eine Zeiteinheit von der Restlaufzeit ab bzw. setzt sie zurueck.
  Future<void> _changeRemainingDuration(
    ActiveSpellEffectDefinition effect, {
    required bool reset,
  }) async {
    final state = _state;
    if (state == null) {
      return;
    }
    final current = state.activeSpellEffects.detailFor(effect.id);
    final duration = current.duration;
    if (duration == null) {
      return;
    }
    final nextDuration = reset
        ? resetSpellDuration(duration)
        : advanceSpellDuration(duration);
    final effects = state.activeSpellEffects.withDetail(
      effect.id,
      current.copyWith(duration: nextDuration),
    );
    await _save(state.copyWith(activeSpellEffects: effects));
  }

  /// Ordnet jedem Effekt seine Umschaltlogik zu.
  ValueChanged<bool> _toggleHandlerFor(ActiveSpellEffectDefinition effect) {
    switch (effect.id) {
      case activeSpellEffectAttributo:
        return _toggleAttributo;
      case activeSpellEffectArmatrutz:
        return _toggleArmatrutz;
      default:
        return (value) => _toggleEffect(effect.id, value);
    }
  }

  /// Liefert die effektspezifische Werteingabe, sofern der Effekt eine hat.
  VoidCallback? _valueEditorFor(ActiveSpellEffectDefinition effect) {
    switch (effect.id) {
      case activeSpellEffectArmatrutz:
        return _editArmatrutzValues;
      case activeSpellEffectAttributo:
        return () => _toggleAttributo(true);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hero = ref.watch(heroByIdProvider(widget.heroId));
    final state = ref.watch(heroStateProvider(widget.heroId)).valueOrNull;
    final isLoaded = hero != null && state != null;

    return AlertDialog(
      key: const ValueKey<String>('active-spell-effects-dialog'),
      title: const Text('Zauber aktivieren'),
      content: SizedBox(
        width: kDialogWidthSmall,
        child: !isLoaded
            ? const Text('Held oder Laufzeitzustand konnte nicht geladen werden.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Wichtige laufende Zaubereffekte werden sofort gespeichert '
                    'und auf die aktuellen Kampf- und Statuswerte angewendet. '
                    'Die Wirkungsdauer ist optional und läuft nie automatisch ab.',
                  ),
                  const SizedBox(height: kDialogFieldSpacing),
                  for (final effect in importantActiveSpellEffects)
                    ActiveSpellEffectTile(
                      effect: effect,
                      isActive: isActiveSpellEffectEnabled(
                        sheet: hero,
                        state: state,
                        effectId: effect.id,
                      ),
                      duration: state.activeSpellEffects
                          .detailFor(effect.id)
                          .duration,
                      valueText: describeActiveSpellEffectValue(
                        effectId: effect.id,
                        state: state,
                      ),
                      onToggled: _toggleHandlerFor(effect),
                      onEditValue: _valueEditorFor(effect),
                      onEditDuration: () => _editDuration(effect),
                      onAdvanceDuration: () =>
                          _changeRemainingDuration(effect, reset: false),
                      onResetDuration: () =>
                          _changeRemainingDuration(effect, reset: true),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
      ],
    );
  }
}
