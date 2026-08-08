part of 'package:dsa_heldenverwaltung/ui/screens/hero_overview_tab.dart';

extension _HeroOverviewEpicSection on _HeroOverviewTabState {
  Widget _buildEpicAdvantagesSection(HeroSheet hero) {
    final theme = Theme.of(context);
    final advRuleActive = ref.watch(
      isHouseRuleActiveProvider(EpicRuleKeys.advantages),
    );
    final disadvRuleActive = ref.watch(
      isHouseRuleActiveProvider(EpicRuleKeys.disadvantages),
    );
    final boni = activeEpicMainAttributeBonuses(
      ruleActive: advRuleActive,
      isEpisch: true,
      mainAttributes: hero.epicMainAttributes,
    );
    final hatOffeneBoni = boni.any(
      (bonus) => bonus.umsetzung != EpicBonusUmsetzung.automatisch,
    );
    // Unterscheidet "Regel abgeschaltet" von "Auswahl fehlt" — nur im
    // zweiten Fall braucht der Nutzer eine Handlungsaufforderung.
    final hasMainAttributes = AttributeCode.values.any(
      (code) => isEpicMainAttribute(
        mainAttributes: hero.epicMainAttributes,
        code: code,
      ),
    );

    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurfaceVariant,
    );

    return _SectionCard(
      title: 'Epische Vorteile und Nachteile',
      child: _ResponsiveFieldGrid(
        breakpoint: _standardTwoColumnBreakpoint,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Epische Vorteile', style: labelStyle),
              const SizedBox(height: 4),
              if (boni.isEmpty && !hasMainAttributes)
                Text(
                  'Keine Haupteigenschaften gewählt — über das Stern-Symbol '
                  'in „AP und Level" nachtragen.',
                  key: const ValueKey<String>('overview-epic-missing-main'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                )
              else if (boni.isEmpty)
                Text(
                  'Keine Haupteigenschafts-Boni aktiv.',
                  style: theme.textTheme.bodyMedium,
                )
              else ...[
                for (final bonus in boni)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: _buildEpicBonusLine(bonus),
                  ),
                if (hatOffeneBoni) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Mit „manuell" gekennzeichnete Boni rechnet die App noch '
                    'nicht — sie gelten am Spieltisch.',
                    key: const ValueKey<String>('overview-epic-manual-note'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ],
          ),
          if (disadvRuleActive)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Epische Nachteile', style: labelStyle),
                const SizedBox(height: 4),
                Text(
                  '• +25 % AP-Aufschlag auf alle nicht-epischen Talente, '
                  'Zauber und Eigenschaften',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '• Stufenboni für AsP reduziert '
                  '(Vollzauberer +6, Halbzauberer +1 AsP)',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Rendert einen Bonus als Aufzaehlungszeile mit Umsetzungs-Marker.
  ///
  /// Nur automatisch gerechnete Boni bleiben unmarkiert; alles andere sagt
  /// ausdruecklich, dass die App den Wert nicht selbst anwendet.
  Widget _buildEpicBonusLine(EpicMainAttributeBonus bonus) {
    final theme = Theme.of(context);
    final marker = _epicBonusMarker(bonus.umsetzung);
    final label = '• ${attributeCodeKey(bonus.code)}: ${bonus.text}';
    if (marker == null) {
      return Text(label, style: theme.textTheme.bodyMedium);
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: label),
          TextSpan(
            text: '  ($marker)',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      style: theme.textTheme.bodyMedium,
    );
  }

  /// Kurzmarker fuer den Umsetzungsgrad; `null` bei berechneten Boni.
  String? _epicBonusMarker(EpicBonusUmsetzung umsetzung) {
    return switch (umsetzung) {
      EpicBonusUmsetzung.automatisch => null,
      EpicBonusUmsetzung.hinweis => 'Hinweis in der Kampfvorschau',
      EpicBonusUmsetzung.manuell => 'manuell',
    };
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
    final snapshot = _latestSnapshot;
    final effectiveStart =
        snapshot?.effectiveStartAttributes ?? const Attributes.zero();
    final currentValues = snapshot?.effectiveAttributes ?? hero.attributes;

    final result = await showDialog<EpicActivationResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EpicActivationDialog(
        currentValues: currentValues,
        effectiveStartAttributes: effectiveStart,
      ),
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

  /// Korrigiert einen bereits gesetzten epischen Status.
  ///
  /// Aendert ausschliesslich Haupteigenschaften, Obergrenzen-Bonus und
  /// Policy. `epicStartAp` und `epicUnactivatedTalentIds` bleiben
  /// unangetastet, damit Epos-Level und AU-Deckelung stabil bleiben.
  Future<void> _editEpicStatus(HeroSheet hero) async {
    final snapshot = _latestSnapshot;
    final effectiveStart =
        snapshot?.effectiveStartAttributes ?? const Attributes.zero();
    final currentValues = snapshot?.effectiveAttributes ?? hero.attributes;

    final result = await showDialog<EpicActivationResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EpicActivationDialog(
        currentValues: currentValues,
        effectiveStartAttributes: effectiveStart,
        isEdit: true,
        initialMaxBonus: hero.epicAttributeMaxBonus,
        initialMainAttributes: hero.epicMainAttributes,
        initialPolicy: hero.epicActivationPolicy,
      ),
    );
    if (result == null || !mounted) return;

    final updated = hero.copyWith(
      epicAttributeMaxBonus: result.maxBonus,
      epicMainAttributes: result.mainAttributes,
      epicActivationPolicy: result.policy,
    );
    await ref.read(heroActionsProvider).saveHero(updated);
    if (!mounted) return;
    _latestHero = updated;
    _viewRevision.value++;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Epischer Status aktualisiert')),
    );
  }
}
