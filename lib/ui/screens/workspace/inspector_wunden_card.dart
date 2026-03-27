import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wund_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/wund_ini_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/wund_unterdrueckung_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/wunden_detail_dialog.dart';

/// Einbettbare Wunden-Sektion fuer die Vitalwerte-Card.
///
/// Zeigt eine aufklappbare Zeile mit Gesamtwunden und Wundschwelle;
/// ausgeklappt erscheinen Effekte, Zonenzeilen und ein Detail-Button.
class InspectorWundenSection extends ConsumerStatefulWidget {
  const InspectorWundenSection({
    super.key,
    required this.heroId,
    required this.heroState,
    required this.wundEffekte,
    required this.wundschwelle,
  });

  final String heroId;
  final HeroState heroState;
  final WundEffekte wundEffekte;
  final int wundschwelle;

  @override
  ConsumerState<InspectorWundenSection> createState() =>
      _InspectorWundenSectionState();
}

class _InspectorWundenSectionState
    extends ConsumerState<InspectorWundenSection> {
  bool _expanded = false;

  Future<void> _speichereWundZustand(WundZustand neuerZustand) async {
    await ref.read(heroActionsProvider).saveHeroState(
      widget.heroId,
      widget.heroState.copyWith(wpiZustand: neuerZustand),
    );
  }

  Future<void> _wundeHinzufuegen(WundZone zone) async {
    final zustand = widget.heroState.wpiZustand;
    if (zustand.wundenInZone(zone) >= maxWundenProZone) return;

    WundZustand neuerZustand;
    if (zone == WundZone.kopf) {
      final iniWert = await showWundIniDialog(context);
      if (iniWert == null || !mounted) return;
      neuerZustand = zustand.mitWundeHinzu(zone, iniWuerfelWert: iniWert);
    } else {
      neuerZustand = zustand.mitWundeHinzu(zone);
    }

    await _speichereWundZustand(neuerZustand);

    if (!mounted) return;
    final hero = ref.read(heroByIdProvider(widget.heroId));
    if (hero == null) return;
    final effekte = computeWundEffekte(neuerZustand);
    final unterdruecken = await showWundUnterdrueckungDialog(
      context: context,
      hero: hero,
      wpiZustand: neuerZustand,
      zone: zone,
      wundEffekte: effekte,
    );
    if (unterdruecken == true) {
      final aktUnterdrueckt = neuerZustand.unterdrueckteInZone(zone);
      await _speichereWundZustand(
        neuerZustand.mitUnterdrueckung(zone, aktUnterdrueckt + 1),
      );
    }
  }

  Future<void> _wundeEntfernen(WundZone zone) async {
    final zustand = widget.heroState.wpiZustand;
    if (zustand.wundenInZone(zone) <= 0) return;
    await _speichereWundZustand(zustand.mitWundeEntfernt(zone));
  }

  @override
  Widget build(BuildContext context) {
    final zustand = widget.heroState.wpiZustand;
    final gesamt = zustand.gesamtWunden;
    final hatWunden = gesamt > 0;
    final errorColor = Theme.of(context).colorScheme.error;
    final secondaryColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Zusammenfassungszeile
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: SizedBox(
            height: 32,
            child: Row(
              children: [
                SizedBox(
                  width: 62,
                  child: Text(
                    'Wunden',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: hatWunden ? errorColor : null,
                    ),
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: secondaryColor,
                ),
                const Spacer(),
                if (hatWunden)
                  Text(
                    '$gesamt',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: errorColor,
                    ),
                  ),
                const SizedBox(width: 4),
                Text(
                  'WS ${widget.wundschwelle}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: secondaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Aufgeklappter Bereich
        if (_expanded) ...[
          if (hatWunden) _WundEffekteSubtitle(effekte: widget.wundEffekte),
          for (final zone in WundZone.values)
            _WundZoneCompactRow(
              zone: zone,
              wunden: zustand.wundenInZone(zone),
              unterdrueckte: zustand.unterdrueckteInZone(zone),
              onHinzufuegen: () => _wundeHinzufuegen(zone),
              onEntfernen: () => _wundeEntfernen(zone),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 28,
              height: 28,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 16,
                tooltip: 'Wunden-Details',
                onPressed: () => showWundenDetailDialog(
                  context: context,
                  heroId: widget.heroId,
                ),
                icon: const Icon(Icons.open_in_new),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Kompakte Wunden-Card fuer das Inspector-Panel.
///
/// Zeigt im eingeklappten Zustand nur Titel und Effekt-Zusammenfassung;
/// ausgeklappt erscheinen die 8 Zonenzeilen mit +/- Buttons.
class InspectorWundenCard extends ConsumerWidget {
  const InspectorWundenCard({
    super.key,
    required this.heroId,
    required this.heroState,
    required this.wundEffekte,
    required this.wundschwelle,
  });

  final String heroId;
  final HeroState heroState;
  final WundEffekte wundEffekte;
  final int wundschwelle;

  Future<void> _speichereWundZustand(
    WidgetRef ref,
    WundZustand neuerZustand,
  ) async {
    await ref.read(heroActionsProvider).saveHeroState(
      heroId,
      heroState.copyWith(wpiZustand: neuerZustand),
    );
  }

  Future<void> _wundeHinzufuegen(
    BuildContext context,
    WidgetRef ref,
    WundZone zone,
  ) async {
    final zustand = heroState.wpiZustand;
    if (zustand.wundenInZone(zone) >= maxWundenProZone) return;

    WundZustand neuerZustand;
    if (zone == WundZone.kopf) {
      final iniWert = await showWundIniDialog(context);
      if (iniWert == null || !context.mounted) return;
      neuerZustand = zustand.mitWundeHinzu(zone, iniWuerfelWert: iniWert);
    } else {
      neuerZustand = zustand.mitWundeHinzu(zone);
    }

    await _speichereWundZustand(ref, neuerZustand);

    if (!context.mounted) return;
    final hero = ref.read(heroByIdProvider(heroId));
    if (hero == null) return;
    final effekte = computeWundEffekte(neuerZustand);
    final unterdruecken = await showWundUnterdrueckungDialog(
      context: context,
      hero: hero,
      wpiZustand: neuerZustand,
      zone: zone,
      wundEffekte: effekte,
    );
    if (unterdruecken == true) {
      final aktUnterdrueckt = neuerZustand.unterdrueckteInZone(zone);
      await _speichereWundZustand(
        ref,
        neuerZustand.mitUnterdrueckung(zone, aktUnterdrueckt + 1),
      );
    }
  }

  Future<void> _wundeEntfernen(WidgetRef ref, WundZone zone) async {
    final zustand = heroState.wpiZustand;
    if (zustand.wundenInZone(zone) <= 0) return;
    await _speichereWundZustand(ref, zustand.mitWundeEntfernt(zone));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zustand = heroState.wpiZustand;
    final gesamt = zustand.gesamtWunden;

    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        initiallyExpanded: false,
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Wunden${gesamt > 0 ? ' ($gesamt)' : ''}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Text(
              'WS $wundschwelle',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 28,
              height: 28,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 16,
                tooltip: 'Wunden-Details',
                onPressed: () => showWundenDetailDialog(
                  context: context,
                  heroId: heroId,
                ),
                icon: const Icon(Icons.open_in_new),
              ),
            ),
          ],
        ),
        subtitle: gesamt > 0
            ? _WundEffekteSubtitle(effekte: wundEffekte)
            : null,
        children: [
          for (final zone in WundZone.values)
            _WundZoneCompactRow(
              zone: zone,
              wunden: zustand.wundenInZone(zone),
              unterdrueckte: zustand.unterdrueckteInZone(zone),
              onHinzufuegen: () => _wundeHinzufuegen(context, ref, zone),
              onEntfernen: () => _wundeEntfernen(ref, zone),
            ),
        ],
      ),
    );
  }
}

class _WundEffekteSubtitle extends StatelessWidget {
  const _WundEffekteSubtitle({required this.effekte});

  final WundEffekte effekte;

  @override
  Widget build(BuildContext context) {
    final teile = <String>[];
    if (effekte.atMalus != 0) teile.add('AT ${effekte.atMalus}');
    if (effekte.paMalus != 0) teile.add('PA ${effekte.paMalus}');
    if (effekte.fkMalus != 0) teile.add('FK ${effekte.fkMalus}');
    if (effekte.iniGesamt != 0) teile.add('INI ${effekte.iniGesamt}');
    if (effekte.gsMalus != 0) teile.add('GS ${effekte.gsMalus}');
    if (effekte.talentProbeMalus != 0) {
      teile.add('Proben ${effekte.talentProbeMalus}');
    }
    final children = <Widget>[];
    if (teile.isNotEmpty) {
      children.add(Text(
        teile.join('  '),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.error,
          fontWeight: FontWeight.bold,
        ),
      ));
    }
    if (effekte.unterdrueckteGesamt > 0) {
      children.add(Text(
        '(${effekte.unterdrueckteGesamt} unterdr.)',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ));
    }
    if (effekte.kampfunfaehig) {
      children.add(Text(
        'Kampfunfähig!',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.error,
          fontWeight: FontWeight.bold,
        ),
      ));
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _WundZoneCompactRow extends StatelessWidget {
  const _WundZoneCompactRow({
    required this.zone,
    required this.wunden,
    required this.unterdrueckte,
    required this.onHinzufuegen,
    required this.onEntfernen,
  });

  final WundZone zone;
  final int wunden;
  final int unterdrueckte;
  final VoidCallback onHinzufuegen;
  final VoidCallback onEntfernen;

  @override
  Widget build(BuildContext context) {
    final label = wundZoneLabel[zone] ?? zone.name;
    final kritisch = wunden >= maxWundenProZone;
    final effektive = wunden - unterdrueckte;
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: kritisch ? Theme.of(context).colorScheme.error : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          for (var i = 0; i < maxWundenProZone; i++)
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Icon(
                i < wunden ? Icons.circle : Icons.circle_outlined,
                size: 12,
                color: i < effektive
                    ? Theme.of(context).colorScheme.error
                    : i < wunden
                        ? Colors.amber
                        : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          const Spacer(),
          SizedBox(
            width: 24,
            height: 24,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 14,
              tooltip: 'Wunde entfernen',
              onPressed: wunden > 0 ? onEntfernen : null,
              icon: const Icon(Icons.remove),
            ),
          ),
          SizedBox(
            width: 24,
            height: 24,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 14,
              tooltip: 'Wunde hinzufügen',
              onPressed: wunden < maxWundenProZone ? onHinzufuegen : null,
              icon: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }
}
