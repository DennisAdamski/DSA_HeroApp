import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/attributo_input_dialog.dart';

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

/// Dialog fuer laufend aktivierbare Zaubereffekte wie `Axxeleratus` und `Attributo`.
class _ActiveSpellEffectsDialog extends ConsumerStatefulWidget {
  const _ActiveSpellEffectsDialog({required this.heroId});

  final String heroId;

  @override
  ConsumerState<_ActiveSpellEffectsDialog> createState() =>
      _ActiveSpellEffectsDialogState();
}

class _ActiveSpellEffectsDialogState
    extends ConsumerState<_ActiveSpellEffectsDialog> {
  Future<void> _toggleEffect(String effectId, bool value) async {
    final state = ref.read(heroStateProvider(widget.heroId)).valueOrNull;
    if (state == null) {
      return;
    }
    final updatedState = state.copyWith(
      activeSpellEffects: state.activeSpellEffects.withToggled(effectId, value),
    );
    await ref.read(heroActionsProvider).saveHeroState(widget.heroId, updatedState);
  }

  Future<void> _toggleAttributo(bool value) async {
    final state = ref.read(heroStateProvider(widget.heroId)).valueOrNull;
    if (state == null) {
      return;
    }

    if (value) {
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
      await ref.read(heroActionsProvider).saveHeroState(widget.heroId, updatedState);
    } else {
      final updatedState = state.copyWith(
        tempAttributeMods: const AttributeModifiers(),
        activeSpellEffects: state.activeSpellEffects.withToggled(
          activeSpellEffectAttributo,
          false,
        ),
      );
      await ref.read(heroActionsProvider).saveHeroState(widget.heroId, updatedState);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hero = ref.watch(heroByIdProvider(widget.heroId));
    final state = ref.watch(heroStateProvider(widget.heroId)).valueOrNull;

    return AlertDialog(
      key: const ValueKey<String>('active-spell-effects-dialog'),
      title: const Text('Zauber aktivieren'),
      content: SizedBox(
        width: kDialogWidthSmall,
        child: hero == null || state == null
            ? const Text('Held oder Laufzeitzustand konnte nicht geladen werden.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Wichtige laufende Zaubereffekte werden sofort gespeichert und auf die aktuellen Kampf- und Statuswerte angewendet.',
                  ),
                  const SizedBox(height: 12),
                  for (final effect in importantActiveSpellEffects)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: SwitchListTile(
                        key: ValueKey<String>(
                          'active-spell-toggle-${effect.id}',
                        ),
                        title: Text(effect.label),
                        subtitle: Text(effect.description),
                        value: isActiveSpellEffectEnabled(
                          sheet: hero,
                          state: state,
                          effectId: effect.id,
                        ),
                        onChanged: effect.id == activeSpellEffectAttributo
                            ? _toggleAttributo
                            : (v) => _toggleEffect(effect.id, v),
                      ),
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
