part of 'package:dsa_heldenverwaltung/ui/screens/hero_overview_tab.dart';

extension _HeroOverviewEpicSection on _HeroOverviewTabState {
  Widget _buildEpicSection(HeroSheet hero) {
    if (!hero.isEpisch) {
      return _SectionCard(
        title: 'Epischer Status',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: FilledButton.tonal(
            onPressed: () => _activateEpicStatus(hero),
            child: const Text('Epischen Status aktivieren'),
          ),
        ),
      );
    }

    final epicLevel = computeEpicLevel(true, hero.apSpent, hero.epicStartAp);
    final apUntilNext =
        computeApUntilNextEpicLevel(true, hero.apSpent, hero.epicStartAp);
    final bonus = hero.epicAttributeMaxBonus;

    final bonusEntries = <String>[];
    final attrLabels = {
      'mu': 'Mut', 'kl': 'Klugheit', 'inn': 'Intuition', 'ch': 'Charisma',
      'ff': 'Fingerfertigkeit', 'ge': 'Gewandtheit', 'ko': 'Konstitution',
      'kk': 'Körperkraft',
    };
    for (final entry in attrLabels.entries) {
      final val = _attrBonusValue(bonus, entry.key);
      if (val > 0) bonusEntries.add('${entry.value} +$val');
    }

    final theme = Theme.of(context);

    return _SectionCard(
      title: 'Epischer Status',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSingleLineFieldsRow(children: [
            _buildReadOnlyValueField(
              key: const ValueKey<String>('overview-readonly-epic-level'),
              label: 'Epische Stufe',
              value: epicLevel.toString(),
            ),
            _buildReadOnlyValueField(
              key: ValueKey<String>('overview-readonly-epic-ap-until-$epicLevel'),
              label: 'AP bis Epische Stufe ${epicLevel + 1}',
              value: apUntilNext.toString(),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            'Eigenschafts-Obergrenzen-Bonus',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            bonusEntries.isEmpty
                ? 'Kein Obergrenzen-Bonus vergeben'
                : bonusEntries.join(', '),
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  int _attrBonusValue(Attributes bonus, String key) {
    return switch (key) {
      'mu' => bonus.mu,
      'kl' => bonus.kl,
      'inn' => bonus.inn,
      'ch' => bonus.ch,
      'ff' => bonus.ff,
      'ge' => bonus.ge,
      'ko' => bonus.ko,
      'kk' => bonus.kk,
      _ => 0,
    };
  }

  Future<void> _activateEpicStatus(HeroSheet hero) async {
    final result = await showDialog<EpicActivationResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const EpicActivationDialog(),
    );
    if (result == null || !mounted) return;
    final unactivatedTalentIds = <String>{};
    for (final entry in hero.talents.entries) {
      if (entry.value.talentValue == null) {
        unactivatedTalentIds.add(entry.key);
      }
    }
    final updated = hero.copyWith(
      isEpisch: true,
      epicStartAp: hero.apSpent,
      epicAttributeMaxBonus: result.maxBonus,
      epicMainAttributes: result.mainAttributes,
      epicActivationPolicy: result.policy,
      epicUnactivatedTalentIds: Set<String>.unmodifiable(unactivatedTalentIds),
    );
    await ref.read(heroActionsProvider).saveHero(updated);
    if (!mounted) return;
    _latestHero = updated;
    _viewRevision.value++;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Epischer Status aktiviert')),
    );
  }
}
