import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wund_rules.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_overview/stat_modifier_detail_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/wund_ini_dialog.dart';

/// Oeffnet den Wunden-Detail-Dialog als Fullscreen-Dialog.
Future<void> showWundenDetailDialog({
  required BuildContext context,
  required String heroId,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _WundenDetailDialog(heroId: heroId),
  );
}

class _WundenDetailDialog extends ConsumerWidget {
  const _WundenDetailDialog({required this.heroId});

  final String heroId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final computedAsync = ref.watch(heroComputedProvider(heroId));
    final computed = computedAsync.valueOrNull;
    if (computed == null) {
      return const AlertDialog(
        title: Text('Wunden'),
        content: Center(child: CircularProgressIndicator()),
      );
    }

    final hero = computed.hero;
    final heroState = computed.state;
    final wpiZustand = heroState.wpiZustand;
    final wundEffekte = computed.wundEffekte;
    final wundschwelle = computed.wundschwelle;

    Future<void> speichereWundZustand(WundZustand neuerZustand) async {
      await ref.read(heroActionsProvider).saveHeroState(
        heroId,
        heroState.copyWith(wpiZustand: neuerZustand),
      );
    }

    Future<void> wundeHinzufuegen(WundZone zone) async {
      if (wpiZustand.wundenInZone(zone) >= maxWundenProZone) return;
      if (zone == WundZone.kopf) {
        final iniWert = await showWundIniDialog(context);
        if (iniWert == null) return;
        await speichereWundZustand(
          wpiZustand.mitWundeHinzu(zone, iniWuerfelWert: iniWert),
        );
      } else {
        await speichereWundZustand(wpiZustand.mitWundeHinzu(zone));
      }
    }

    Future<void> wundeEntfernen(WundZone zone) async {
      if (wpiZustand.wundenInZone(zone) <= 0) return;
      await speichereWundZustand(wpiZustand.mitWundeEntfernt(zone));
    }

    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('Wunden')),
          Text(
            'WS: $wundschwelle',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          IconButton(
            tooltip: 'Wundschwelle-Modifikatoren',
            icon: const Icon(Icons.settings, size: 20),
            onPressed: () async {
              final currentMods =
                  hero.statModifiers['wundschwelle'] ?? const [];
              final result = await showStatModifierDetailDialog(
                context: context,
                statLabel: 'Wundschwelle',
                namedModifiers: currentMods,
                parsedSources: const [],
                total: wundschwelle,
              );
              if (result != null) {
                final updatedModifiers =
                    Map<String, List<HeroTalentModifier>>.of(
                      hero.statModifiers,
                    );
                if (result.isEmpty) {
                  updatedModifiers.remove('wundschwelle');
                } else {
                  updatedModifiers['wundschwelle'] = result;
                }
                await ref.read(heroActionsProvider).saveHero(
                  hero.copyWith(statModifiers: updatedModifiers),
                );
              }
            },
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Zonenraster
              for (final zone in WundZone.values) ...[
                _ZonenZeile(
                  zone: zone,
                  wunden: wpiZustand.wundenInZone(zone),
                  onHinzufuegen: () => wundeHinzufuegen(zone),
                  onEntfernen: () => wundeEntfernen(zone),
                ),
                if (zone != WundZone.values.last) const SizedBox(height: 4),
              ],

              const Divider(height: 24),

              // Effektezusammenfassung
              _EffekteZusammenfassung(effekte: wundEffekte),

              // Hinweise
              if (wundEffekte.hinweise.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final hinweis in wundEffekte.hinweise)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber,
                          size: 16,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            hinweis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
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

class _ZonenZeile extends StatelessWidget {
  const _ZonenZeile({
    required this.zone,
    required this.wunden,
    required this.onHinzufuegen,
    required this.onEntfernen,
  });

  final WundZone zone;
  final int wunden;
  final VoidCallback onHinzufuegen;
  final VoidCallback onEntfernen;

  @override
  Widget build(BuildContext context) {
    final label = wundZoneLabel[zone] ?? zone.name;
    final istKritisch = wunden >= maxWundenProZone;
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: istKritisch ? Theme.of(context).colorScheme.error : null,
            ),
          ),
        ),
        // Wunden-Pips
        for (var i = 0; i < maxWundenProZone; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              i < wunden ? Icons.circle : Icons.circle_outlined,
              size: 18,
              color: i < wunden
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        const Spacer(),
        SizedBox(
          width: 36,
          height: 36,
          child: IconButton(
            padding: EdgeInsets.zero,
            iconSize: 18,
            tooltip: 'Wunde entfernen',
            onPressed: wunden > 0 ? onEntfernen : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
        ),
        SizedBox(
          width: 36,
          height: 36,
          child: IconButton(
            padding: EdgeInsets.zero,
            iconSize: 18,
            tooltip: 'Wunde hinzufügen',
            onPressed: wunden < maxWundenProZone ? onHinzufuegen : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ),
      ],
    );
  }
}

class _EffekteZusammenfassung extends StatelessWidget {
  const _EffekteZusammenfassung({required this.effekte});

  final WundEffekte effekte;

  @override
  Widget build(BuildContext context) {
    if (effekte.atMalus == 0 &&
        effekte.paMalus == 0 &&
        effekte.fkMalus == 0 &&
        effekte.iniGesamt == 0 &&
        effekte.gsMalus == 0 &&
        effekte.talentProbeMalus == 0) {
      return Text(
        'Keine Wundeffekte aktiv.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    final teile = <String>[];
    if (effekte.atMalus != 0) teile.add('AT ${effekte.atMalus}');
    if (effekte.paMalus != 0) teile.add('PA ${effekte.paMalus}');
    if (effekte.fkMalus != 0) teile.add('FK ${effekte.fkMalus}');
    if (effekte.iniGesamt != 0) teile.add('INI ${effekte.iniGesamt}');
    if (effekte.gsMalus != 0) teile.add('GS ${effekte.gsMalus}');
    if (effekte.talentProbeMalus != 0) {
      teile.add('Proben ${effekte.talentProbeMalus}');
    }
    if (effekte.zauberExtraMalus != 0) {
      teile.add('Zauber extra ${effekte.zauberExtraMalus}');
    }
    return Text(
      teile.join('  '),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.error,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
