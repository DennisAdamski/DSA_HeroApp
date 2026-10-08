part of '../hero_begleiter_tab.dart';

// ---------------------------------------------------------------------------
// Laufende Werte eines Begleiters (LeP, AsP, AuP) – V2
// ---------------------------------------------------------------------------

/// Laufende LeP, AsP und AuP mit ±-Knöpfen für jeden Begleiter.
///
/// Gelesen werden der gespeicherte Bogen (Maximum) und der gespeicherte
/// Zustand (`HeroState.begleiterZustaende`), nie der Editorentwurf. Jeder
/// Knopf meldet nur seinen Schritt; gerechnet wird auf dem gespeicherten Wert
/// (`aendereBegleiterPool`). Ein Begleiter ohne Eintrag ist „voll“.
class _BegleiterLaufwerteSection extends ConsumerWidget {
  const _BegleiterLaufwerteSection({
    required this.heroId,
    required this.companionId,
  });

  final String heroId;
  final String companionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hero = ref.watch(heroByIdProvider(heroId));
    final gespeichert = hero?.companions
        .where((c) => c.id == companionId)
        .firstOrNull;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    if (gespeichert == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader('Laufende Werte'),
          Text(
            'Die laufenden Werte stehen nach dem ersten Speichern des '
            'Begleiters zur Verfügung.',
            style: muted,
          ),
        ],
      );
    }
    final zustand =
        ref.watch(heroStateProvider(heroId)).valueOrNull ??
        const HeroState.empty();
    final pools = <BegleiterPool>[
      for (final pool in BegleiterPool.values)
        if (begleiterPoolMaximum(gespeichert, pool) > 0) pool,
    ];
    return Column(
      key: ValueKey<String>('begleiter-laufwerte-$companionId'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Laufende Werte'),
        if (pools.isEmpty)
          Text('Keine Maximalwerte eingetragen.', style: muted)
        else
          for (final pool in pools)
            _PoolZeile(
              heroId: heroId,
              begleiter: gespeichert,
              pool: pool,
              aktuell: begleiterAktuellerPool(gespeichert, zustand, pool),
              maximum: begleiterPoolMaximum(gespeichert, pool),
            ),
      ],
    );
  }
}

class _PoolZeile extends ConsumerWidget {
  const _PoolZeile({
    required this.heroId,
    required this.begleiter,
    required this.pool,
    required this.aktuell,
    required this.maximum,
  });

  final String heroId;
  final HeroCompanion begleiter;
  final BegleiterPool pool;
  final int aktuell;
  final int maximum;

  void _aendere(BuildContext context, WidgetRef ref, RessourcenAenderung a) {
    unawaited(
      aendereBegleiterPool(
        context: context,
        ref: ref,
        heroId: heroId,
        begleiter: begleiter,
        pool: pool,
        aenderung: a,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final niedrig = aktuell <= 0;
    Widget knopf(int schritt) => TextButton(
      key: ValueKey<String>(
        'begleiter-${pool.name}-${schritt > 0 ? 'plus' : 'minus'}-${schritt.abs()}',
      ),
      style: TextButton.styleFrom(
        minimumSize: const Size(40, 36),
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ),
      onPressed: () =>
          _aendere(context, ref, begleiterPoolSchritt(pool, maximum, schritt)),
      child: Text(schritt > 0 ? '+$schritt' : '−${schritt.abs()}'),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          SizedBox(width: 44, child: Text(pool.kuerzel)),
          SizedBox(
            width: 84,
            child: Text(
              '$aktuell / $maximum',
              key: ValueKey<String>('begleiter-${pool.name}-wert'),
              style: theme.textTheme.titleSmall?.copyWith(
                color: niedrig ? theme.colorScheme.error : null,
              ),
            ),
          ),
          knopf(-5),
          knopf(-1),
          knopf(1),
          knopf(5),
          TextButton(
            key: ValueKey<String>('begleiter-${pool.name}-voll'),
            onPressed: aktuell == maximum
                ? null
                : () => _aendere(
                    context,
                    ref,
                    RessourcenAenderung.setzen(maximum),
                  ),
            child: const Text('Voll'),
          ),
        ],
      ),
    );
  }
}
