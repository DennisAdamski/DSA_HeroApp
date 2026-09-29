import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_state_rules.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/active_spell_effect_tile.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/armatrutz_input_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/attributo_input_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/spell_duration_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/zustand_aendern.dart';

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
  /// Wendet [aenderung] auf den frisch gespeicherten Zustand an.
  ///
  /// Nie den Stand beim Rendern zurückschreiben: sonst gingen Würfe, Wunden
  /// oder Ressourcen verloren, die seit dem Öffnen gespeichert wurden.
  Future<void> _aendere(HeroState Function(HeroState aktuell) aenderung) {
    return aendereZustandMitMeldung(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      was: 'Zaubereffekt',
      aenderung: aenderung,
    );
  }

  /// Liest den aktuellen Laufzeitzustand; `null`, solange er nicht geladen ist.
  HeroState? get _state =>
      ref.read(heroStateProvider(widget.heroId)).valueOrNull;

  Future<void> _toggleEffect(String effectId, bool value) async {
    await _aendere(
      (aktuell) => schalteZaubereffekt(aktuell, effectId, aktiv: value),
    );
  }

  /// Aktiviert den Attributo erst nach Eingabe der Eigenschaftsboni.
  Future<void> _toggleAttributo(bool value) async {
    if (!value) {
      await _toggleEffect(activeSpellEffectAttributo, false);
      return;
    }
    final bonuses = await showAttributoInputDialog(context: context);
    if (bonuses == null || !mounted) {
      return;
    }
    await _aendere((aktuell) => aktiviereAttributo(aktuell, bonuses));
  }

  /// Aktiviert den Armatrutz erst nach Eingabe von RS und Wirkungsdauer.
  Future<void> _toggleArmatrutz(bool value) async {
    if (!value) {
      await _toggleEffect(activeSpellEffectArmatrutz, false);
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
    await _aendere((aktuell) => aktiviereArmatrutz(aktuell, detail));
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
    await _aendere(
      (aktuell) => setzeZaubereffektDauer(aktuell, effect.id, result.duration),
    );
  }

  /// Zieht eine Zeiteinheit von der Restlaufzeit ab bzw. setzt sie zurueck.
  Future<void> _changeRemainingDuration(
    ActiveSpellEffectDefinition effect, {
    required bool reset,
  }) async {
    await _aendere(
      (aktuell) =>
          zaehleZaubereffektDauer(aktuell, effect.id, zuruecksetzen: reset),
    );
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
            ? const Text(
                'Held oder Laufzeitzustand konnte nicht geladen werden.',
              )
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
