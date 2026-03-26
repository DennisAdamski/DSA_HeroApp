import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';

/// Ressource-Typ fuer den Stepper-Dialog.
enum ResourceType { lep, au, asp, kap }

/// Zeigt einen kompakten Stepper-Dialog zum Anpassen einer Ressource.
Future<void> showResourceStepperDialog({
  required BuildContext context,
  required String heroId,
  required ResourceType resource,
}) {
  return showAdaptiveDetailSheet<void>(
    context: context,
    builder: (_) => _ResourceStepperDialog(heroId: heroId, resource: resource),
  );
}

class _ResourceStepperDialog extends ConsumerWidget {
  const _ResourceStepperDialog({
    required this.heroId,
    required this.resource,
  });

  final String heroId;
  final ResourceType resource;

  String get _label => switch (resource) {
    ResourceType.lep => 'LeP',
    ResourceType.au => 'Au',
    ResourceType.asp => 'AsP',
    ResourceType.kap => 'KaP',
  };

  int _current(HeroState? state) => switch (resource) {
    ResourceType.lep => state?.currentLep ?? 0,
    ResourceType.au => state?.currentAu ?? 0,
    ResourceType.asp => state?.currentAsp ?? 0,
    ResourceType.kap => state?.currentKap ?? 0,
  };

  int _max(DerivedStats? derived) => switch (resource) {
    ResourceType.lep => derived?.maxLep ?? 0,
    ResourceType.au => derived?.maxAu ?? 0,
    ResourceType.asp => derived?.maxAsp ?? 0,
    ResourceType.kap => derived?.maxKap ?? 0,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final computed = ref.watch(heroComputedProvider(heroId)).valueOrNull;
    final state = computed?.state;
    final derived = computed?.derivedStats;
    final current = _current(state);
    final max = _max(derived);
    final isLow = max > 0 && current <= (max / 3).ceil();

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_label anpassen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filled(
                  onPressed: current > 0 && state != null
                      ? () => _save(ref, state, current - 1)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                const SizedBox(width: 16),
                Text(
                  '$current',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: isLow
                        ? Theme.of(context).colorScheme.error
                        : null,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  ' / $max',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 16),
                IconButton.filled(
                  onPressed: current < max && state != null
                      ? () => _save(ref, state, current + 1)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Schließen'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(WidgetRef ref, HeroState state, int newValue) async {
    final updated = switch (resource) {
      ResourceType.lep => state.copyWith(currentLep: newValue),
      ResourceType.au => state.copyWith(currentAu: newValue),
      ResourceType.asp => state.copyWith(currentAsp: newValue),
      ResourceType.kap => state.copyWith(currentKap: newValue),
    };
    await ref.read(heroActionsProvider).saveHeroState(heroId, updated);
  }
}
