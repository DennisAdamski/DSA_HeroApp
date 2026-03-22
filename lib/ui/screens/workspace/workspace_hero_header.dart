import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_badge.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_metric_tile.dart';

/// Heroischer Workspace-Kopf mit Heldenidentitaet und Kurzstatus.
class WorkspaceHeroHeader extends StatelessWidget {
  /// Erstellt den Header fuer den aktiven Helden und Bereich.
  const WorkspaceHeroHeader({
    super.key,
    required this.hero,
    required this.activeAreaLabel,
    required this.activeAreaHelper,
    this.isCompact = false,
  });

  /// Aktueller Held.
  final HeroSheet hero;

  /// Label des aktiven Workspace-Bereichs.
  final String activeAreaLabel;

  /// Kurzbeschreibung des aktiven Bereichs.
  final String activeAreaHelper;

  /// Aktiviert eine kompaktere Darstellung fuer schmale Layouts.
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final codex = context.codexTheme;
    final theme = Theme.of(context);
    final roleText = _roleText(hero);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        18,
        isCompact ? 14 : 18,
        18,
        isCompact ? 16 : 20,
      ),
      decoration: BoxDecoration(
        gradient: codex.heroGradient,
        border: Border(
          bottom: BorderSide(color: codex.rule.withValues(alpha: 0.85)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useWideLayout = !isCompact && constraints.maxWidth >= 920;
          final useCondensedLayout = isCompact || constraints.maxWidth < 744;
          final summary = Wrap(
            spacing: useCondensedLayout ? 8 : 10,
            runSpacing: useCondensedLayout ? 8 : 10,
            children: [
              CodexMetricTile(
                label: 'Level',
                value: hero.level.toString(),
                icon: Icons.workspace_premium_outlined,
              ),
              if (!useCondensedLayout)
                CodexMetricTile(
                  label: 'AP Gesamt',
                  value: hero.apTotal.toString(),
                  icon: Icons.auto_stories_outlined,
                ),
              CodexMetricTile(
                label: 'AP frei',
                value: hero.apAvailable.toString(),
                icon: Icons.account_balance_wallet_outlined,
                highlight: hero.apAvailable > 0,
              ),
            ],
          );

          final head = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PortraitMedallion(
                heroName: hero.name,
                size: useCondensedLayout ? 72 : 88,
              ),
              SizedBox(width: useCondensedLayout ? 14 : 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hero.name,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      roleText,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFFF4E7CF),
                      ),
                    ),
                    SizedBox(height: useCondensedLayout ? 8 : 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (hero.background.rasse.trim().isNotEmpty)
                          CodexBadge(label: hero.background.rasse),
                        if (hero.background.kultur.trim().isNotEmpty)
                          CodexBadge(label: hero.background.kultur),
                      ],
                    ),
                    if (!useCondensedLayout) ...[
                      const SizedBox(height: 12),
                      Text(
                        activeAreaHelper,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFEADCC5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (useWideLayout) ...[
                const SizedBox(width: 16),
                Opacity(
                  opacity: 0.88,
                  child: Image.asset(
                    'assets/ui/codex/hero_banner_crest.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ],
          );

          if (useWideLayout) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: head),
                const SizedBox(width: 18),
                Expanded(flex: 2, child: summary),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [head, const SizedBox(height: 16), summary],
          );
        },
      ),
    );
  }

  String _roleText(HeroSheet hero) {
    final profession = hero.background.profession.trim();
    final kultur = hero.background.kultur.trim();
    final rasse = hero.background.rasse.trim();
    final parts = <String>[
      if (profession.isNotEmpty) profession,
      if (kultur.isNotEmpty) kultur,
      if (rasse.isNotEmpty) rasse,
    ];
    if (parts.isEmpty) {
      return 'Unbeschriebener Held';
    }
    return parts.join(' | ');
  }
}

class _PortraitMedallion extends StatelessWidget {
  const _PortraitMedallion({required this.heroName, required this.size});

  final String heroName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = heroName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.substring(0, 1).toUpperCase())
        .join();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(
          color: const Color(0xFFD8B985).withValues(alpha: 0.8),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.18,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Image.asset(
                'assets/ui/codex/arcane_seal.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          Center(
            child: Text(
              initials.isEmpty ? '?' : initials,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontFamily: 'Cinzel',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
