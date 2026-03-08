import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';

/// Oeffnet den gemeinsamen Dialog fuer wichtige aktive Zaubereffekte.
Future<void> showActiveSpellEffectsDialog({
  required BuildContext context,
  required String heroId,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return _ActiveSpellEffectsDialog(heroId: heroId);
    },
  );
}

/// Dialog fuer laufend aktivierbare Zaubereffekte wie `Axxeleratus`.
class _ActiveSpellEffectsDialog extends ConsumerWidget {
  const _ActiveSpellEffectsDialog({required this.heroId});

  final String heroId;

  Future<void> _toggleEffect(
    WidgetRef ref,
    String effectId,
    bool value,
  ) async {
    final state = ref.read(heroStateProvider(heroId)).valueOrNull;
    if (state == null) {
      return;
    }
    final updatedState = state.copyWith(
      activeSpellEffects: state.activeSpellEffects.withToggled(effectId, value),
    );
    await ref.read(heroActionsProvider).saveHeroState(heroId, updatedState);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hero = ref.watch(heroByIdProvider(heroId));
    final state = ref.watch(heroStateProvider(heroId)).valueOrNull;

    return AlertDialog(
      key: const ValueKey<String>('active-spell-effects-dialog'),
      title: const Text('Zauber aktivieren'),
      content: SizedBox(
        width: 420,
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
                        onChanged: (value) => _toggleEffect(ref, effect.id, value),
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Schliessen'),
        ),
      ],
    );
  }
}
